'use strict';

const db = require('../../models');
const AppError = require('../../utils/app_error');
const security = require('../../config/security');
const { ensureMembro } = require('../../utils/membership');
const { calcularCustos } = require('../../utils/carona_custos');
const {
  montarPayload,
  includeMensagem,
  includeCaronaResumo,
  caronaPayload,
} = require('../../utils/mensagem_payload');

const STATUS = security.CARONA_STATUS;
const PSTATUS = security.CARONA_PASSAGEIRO_STATUS;

function parseIdGrupo(req) {
  const idGrupo = Number(req.params.idGrupo);
  if (!Number.isInteger(idGrupo) || idGrupo <= 0) {
    throw AppError.validation('Grupo invalido.');
  }
  return idGrupo;
}

function parseIdCarona(req) {
  const idCarona = Number(req.params.idCarona);
  if (!Number.isInteger(idCarona) || idCarona <= 0) {
    throw AppError.validation('Carona invalida.');
  }
  return idCarona;
}

function parseIdPassageiro(req) {
  const id = Number(req.params.idPassageiro);
  if (!Number.isInteger(id) || id <= 0) {
    throw AppError.validation('Passageiro invalido.');
  }
  return id;
}

// Numero decimal vindo do body, em centavos. Null quando ausente/invalido.
function parseDecimal(valor) {
  if (valor === null || valor === undefined || valor === '') return null;
  const n = Number(valor);
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : null;
}

function tratarErro(res, err, tag) {
  if (err instanceof AppError) {
    return res.status(err.httpStatus).json({
      error: err.type,
      message: err.message,
      details: err.details,
    });
  }
  console.error(tag, err);
  return res.status(500).json({
    error: 'INTERNAL',
    message: 'Erro interno ao processar carona.',
  });
}

// Carona ativa por id, ou 404. Sem includes (uso em mutacoes simples).
async function buscarCarona(idCarona) {
  const carona = await db.Carona.findOne({ where: { idCarona, ativo: true } });
  if (!carona) {
    throw AppError.notFound('Carona nao encontrada.');
  }
  return carona;
}

const includeDetalhe = () => [
  { model: db.Grupo, as: 'grupo', attributes: ['idGrupo', 'nome'] },
  { model: db.Usuario, as: 'motorista', attributes: ['idUsuario', 'nome'] },
  {
    model: db.Carro,
    as: 'carro',
    attributes: ['idCarro', 'marca', 'modelo', 'anoFabricacao', 'cor', 'placa', 'capacidade'],
  },
  {
    model: db.CaronaUsuario,
    as: 'passageiros',
    include: [
      { model: db.Usuario, as: 'passageiro', attributes: ['idUsuario', 'nome'] },
    ],
  },
];

// Monta o JSON de detalhe (motorista, carro, vagas, passageiros com status e
// os custos/rateio da viagem).
function montarDetalhe(carona) {
  const lugares = carona.carro
    ? Math.max(carona.carro.capacidade - 1, 0)
    : null;
  const passageiros = (carona.passageiros || []).map((p) => ({
    idUsuario: p.passageiro ? p.passageiro.idUsuario : p.idPassageiro,
    nome: p.passageiro ? p.passageiro.nome : null,
    status: p.status,
  }));
  const ocupadas = passageiros.filter((p) => p.status === PSTATUS.APROVADO).length;
  // O rateio e sobre os passageiros aprovados (quem de fato foi de carona).
  const custos = calcularCustos({
    kmRodados: carona.kmRodados,
    valorLitro: carona.valorLitro,
    passageiros: ocupadas + 1, // motorista incluso
  });

  return {
    idCarona: carona.idCarona,
    idGrupo: carona.idGrupo,
    grupoNome: carona.grupo ? carona.grupo.nome : null,
    status: carona.status,
    data: carona.data,
    destino: carona.destino,
    lugares,
    ocupadas,
    motorista: carona.motorista
      ? { idUsuario: carona.motorista.idUsuario, nome: carona.motorista.nome }
      : null,
    carro: carona.carro
      ? {
          idCarro: carona.carro.idCarro,
          marca: carona.carro.marca,
          modelo: carona.carro.modelo,
          anoFabricacao: carona.carro.anoFabricacao,
          cor: carona.carro.cor,
          placa: carona.carro.placa,
          capacidade: carona.carro.capacidade,
        }
      : null,
    passageiros,
    // Null enquanto o motorista nao informar km + valor do litro.
    custos,
  };
}

// Recarrega a carona completa e responde 200 com o detalhe.
async function responderDetalhe(res, idCarona) {
  const completa = await db.Carona.findByPk(idCarona, {
    include: includeDetalhe(),
  });
  return res.status(200).json(montarDetalhe(completa));
}

// Recarrega o resumo da carona e emite carona:atualizada pra sala do grupo,
// para os cards do chat refletirem vagas/pedidos/status ao vivo.
async function emitirAtualizacao(req, idCarona, idGrupo) {
  const io = req.app.get('io');
  if (!io) return;
  const resumo = await db.Carona.findByPk(idCarona, {
    include: includeCaronaResumo(db),
  });
  io.to(`grupo:${idGrupo}`).emit('carona:atualizada', caronaPayload(resumo));
}

// Motorista anuncia uma carona no grupo. Cria a carona ja com motorista e carro
// ativo (status 'aberta') e posta um card no chat. Tudo numa transacao.
async function anunciar(req, res) {
  const t = await db.sequelize.transaction();
  let payload;
  let idGrupo;
  try {
    idGrupo = parseIdGrupo(req);
    await ensureMembro(req.user.idUsuario, idGrupo);

    if (!security.CARONA_TIPOS_MOTORISTA.includes(req.user.tipo)) {
      throw AppError.forbidden('Apenas motoristas podem anunciar caronas.');
    }

    // Destino opcional, mas se vier precisa ter tamanho minimo.
    const destino = (req.body.destino || '').trim();
    if (destino && destino.length < security.CARONA_DESTINO_MIN) {
      throw AppError.validation('Destino invalido.', {
        destino: `Destino deve ter ao menos ${security.CARONA_DESTINO_MIN} caracteres.`,
      });
    }
    if (destino.length > security.CARONA_DESTINO_MAX) {
      throw AppError.validation('Destino invalido.', {
        destino: `Destino deve ter no maximo ${security.CARONA_DESTINO_MAX} caracteres.`,
      });
    }

    // Carro ativo do motorista: define a capacidade (vagas) e e atrelado.
    const carro = await db.Carro.findOne({
      where: { idUsuario: req.user.idUsuario, ativo: true },
    });
    if (!carro) {
      throw AppError.validation(security.CARRO_OBRIGATORIO_MSG);
    }

    const carona = await db.Carona.create(
      {
        idGrupo,
        idMotorista: req.user.idUsuario,
        idCarro: carro.idCarro,
        destino: destino || null,
        status: STATUS.ABERTA,
      },
      { transaction: t },
    );

    const conteudo = destino
      ? `Vai sair: ${destino}`
      : security.CARONA_MENSAGEM_PADRAO;
    const nova = await db.Mensagem.create(
      {
        idGrupo,
        idUsuario: req.user.idUsuario,
        tipo: security.MENSAGEM_TIPO.CARONA,
        idCarona: carona.idCarona,
        conteudo,
      },
      { transaction: t },
    );

    const msg = await db.Mensagem.findByPk(nova.idMensagem, {
      include: includeMensagem(db),
      transaction: t,
    });
    payload = montarPayload(msg);

    await t.commit();
  } catch (err) {
    await t.rollback().catch(() => {});
    return tratarErro(res, err, '[carona_controller.anunciar]');
  }

  // Broadcast do card so apos o commit.
  const io = req.app.get('io');
  if (io) {
    io.to(`grupo:${idGrupo}`).emit('mensagem:nova', payload);
  }

  return res.status(201).json(payload);
}

// Passageiro pede para entrar numa carona aberta. Cria (ou revive, se antes
// recusado) o vinculo como 'pendente'. Nao ocupa vaga ate o motorista aprovar.
async function pedir(req, res) {
  try {
    const idCarona = parseIdCarona(req);
    const carona = await buscarCarona(idCarona);
    await ensureMembro(req.user.idUsuario, carona.idGrupo);

    if (carona.status !== STATUS.ABERTA) {
      throw AppError.conflict('Esta carona nao esta aberta para pedidos.');
    }
    if (carona.idMotorista === req.user.idUsuario) {
      throw AppError.forbidden('Voce e o motorista desta carona.');
    }

    const existente = await db.CaronaUsuario.findOne({
      where: { idCarona, idPassageiro: req.user.idUsuario },
    });
    if (existente) {
      if (existente.status !== PSTATUS.RECUSADO) {
        throw AppError.conflict('Voce ja pediu esta carona.');
      }
      existente.status = PSTATUS.PENDENTE;
      await existente.save();
    } else {
      await db.CaronaUsuario.create({
        idCarona,
        idPassageiro: req.user.idUsuario,
        status: PSTATUS.PENDENTE,
      });
    }

    await emitirAtualizacao(req, idCarona, carona.idGrupo);
    return await responderDetalhe(res, idCarona);
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.pedir]');
  }
}

// Passageiro cancela o proprio pedido (remove o vinculo). Pode reenviar depois.
async function cancelarPedido(req, res) {
  try {
    const idCarona = parseIdCarona(req);
    const carona = await buscarCarona(idCarona);
    await ensureMembro(req.user.idUsuario, carona.idGrupo);

    // Trava de Segurança: Bloqueia o cancelamento se a carona não estiver ABERTA
    if (carona.status !== STATUS.ABERTA) {
      throw AppError.conflict('Não é possível cancelar o pedido. Esta carona já foi concluída ou cancelada.');
    }

    const vinculo = await db.CaronaUsuario.findOne({
      where: { idCarona, idPassageiro: req.user.idUsuario },
    });
    
    if (!vinculo) {
      throw AppError.notFound('Voce nao tem um pedido nesta carona.');
    }
    
    // Se a carona está aberta, o cancelamento é permitido
    await vinculo.destroy();

    await emitirAtualizacao(req, idCarona, carona.idGrupo);
    return await responderDetalhe(res, idCarona);
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.cancelarPedido]');
  }
}

// Motorista aprova ou recusa o pedido de um passageiro. Aprovar respeita o
// limite de vagas (capacidade do carro - 1). Body: { acao: 'aprovar'|'recusar' }.
async function decidir(req, res) {
  let idGrupoCarona = null;
  // 1. Iniciamos a transação para agrupar as operações
  const t = await db.sequelize.transaction();
  
  try {
    const idCarona = parseIdCarona(req);
    const idPassageiro = parseIdPassageiro(req);
    const acao = req.body.acao;
    if (acao !== 'aprovar' && acao !== 'recusar') {
      throw AppError.validation("Acao invalida. Use 'aprovar' ou 'recusar'.");
    }

    const carona = await db.Carona.findOne({
      where: { idCarona, ativo: true },
      include: [
        { model: db.Carro, as: 'carro', attributes: ['idCarro', 'capacidade'] },
        { model: db.CaronaUsuario, as: 'passageiros', attributes: ['idPivot', 'idPassageiro', 'status'] },
      ],
      transaction: t,
      lock: t.LOCK.UPDATE, // 🔒 2. AQUI ESTÁ O CADEADO! Bloqueia a linha da carona contra concorrência
    });

    if (!carona) {
      throw AppError.notFound('Carona nao encontrada.');
    }

    // Guarda o ID para o WebSocket usar depois da transação
    idGrupoCarona = carona.idGrupo; 
    await ensureMembro(req.user.idUsuario, idGrupoCarona);

    if (carona.idMotorista !== req.user.idUsuario) {
      throw AppError.forbidden('Apenas o motorista decide os pedidos.');
    }
    if (carona.status !== STATUS.ABERTA) {
      throw AppError.conflict('Esta carona nao esta mais aberta.');
    }

    const vinculo = (carona.passageiros || []).find(
      (p) => p.idPassageiro === idPassageiro,
    );
    if (!vinculo) {
      throw AppError.notFound('Pedido nao encontrado.');
    }

    if (acao === 'aprovar') {
      if (vinculo.status !== PSTATUS.APROVADO) {
        const lugares = carona.carro
          ? Math.max(carona.carro.capacidade - 1, 0)
          : 0;
        const aprovados = (carona.passageiros || []).filter(
          (p) => p.status === PSTATUS.APROVADO,
        ).length;
        
        if (aprovados >= lugares) {
          throw AppError.conflict(security.CARONA_LOTADA_MSG);
        }
      }
      
      // 3. Atualizamos a tabela pivô DENTRO da transação
      await db.CaronaUsuario.update(
        { status: PSTATUS.APROVADO },
        { where: { idPivot: vinculo.idPivot }, transaction: t },
      );
    } else {
      await db.CaronaUsuario.update(
        { status: PSTATUS.RECUSADO },
        { where: { idPivot: vinculo.idPivot }, transaction: t },
      );
    }

    // 4. Se tudo deu certo, liberamos o cadeado e confirmamos no MySQL
    await t.commit(); 
    
    // Disparamos o WebSockets FORA da transação (para não prender o banco enquanto envia dados de rede)
    await emitirAtualizacao(req, idCarona, idGrupoCarona);
    return await responderDetalhe(res, idCarona);
    
  } catch (err) {
    // 5. Se algo quebrou ou deu lotado, desfazemos tudo e destrancamos a tabela
    if (!t.finished) {
      await t.rollback().catch(() => {});
    }
    return tratarErro(res, err, '[carona_controller.decidir]');
  }
}

// Motorista informa os custos da viagem: km rodados e o valor pago no litro.
// Editavel enquanto a carona esta aberta; os dois vem juntos, porque o total da
// viagem so existe com ambos. Devolve o detalhe com o rateio recalculado.
async function atualizarCustos(req, res) {
  try {
    const idCarona = parseIdCarona(req);
    const carona = await buscarCarona(idCarona);
    await ensureMembro(req.user.idUsuario, carona.idGrupo);

    if (carona.idMotorista !== req.user.idUsuario) {
      throw AppError.forbidden(
        'Apenas o motorista pode informar os custos da viagem.',
      );
    }
    if (carona.status !== STATUS.ABERTA) {
      throw AppError.conflict(
        'Os custos so podem ser informados enquanto a carona esta aberta.',
      );
    }

    const erros = {};
    const km = parseDecimal(req.body.kmRodados);
    const litro = parseDecimal(req.body.valorLitro);

    if (km === null || km < security.CARONA_KM_MIN || km > security.CARONA_KM_MAX) {
      erros.kmRodados = `Km rodados deve estar entre ${security.CARONA_KM_MIN} e ${security.CARONA_KM_MAX}.`;
    }
    if (
      litro === null
      || litro < security.CARONA_VALOR_LITRO_MIN
      || litro > security.CARONA_VALOR_LITRO_MAX
    ) {
      erros.valorLitro = `Valor do litro deve estar entre ${security.CARONA_VALOR_LITRO_MIN} e ${security.CARONA_VALOR_LITRO_MAX}.`;
    }
    if (Object.keys(erros).length > 0) {
      throw AppError.validation('Dados invalidos.', erros);
    }

    await carona.update({ kmRodados: km, valorLitro: litro });

    await emitirAtualizacao(req, idCarona, carona.idGrupo);
    return await responderDetalhe(res, idCarona);
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.atualizarCustos]');
  }
}

// So o motorista conclui, e somente enquanto a carona esta 'aberta'.
async function concluir(req, res) {
  try {
    const idCarona = parseIdCarona(req);
    const carona = await buscarCarona(idCarona);
    await ensureMembro(req.user.idUsuario, carona.idGrupo);

    if (carona.idMotorista !== req.user.idUsuario) {
      throw AppError.forbidden('Apenas o motorista pode concluir a carona.');
    }
    if (carona.status !== STATUS.ABERTA) {
      throw AppError.conflict('So caronas abertas podem ser concluidas.');
    }

    carona.status = STATUS.CONCLUIDA;
    await carona.save();

    await emitirAtualizacao(req, idCarona, carona.idGrupo);
    return await responderDetalhe(res, idCarona);
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.concluir]');
  }
}

// So o motorista cancela a carona, enquanto ela esta 'aberta'.
async function cancelar(req, res) {
  try {
    const idCarona = parseIdCarona(req);
    const carona = await buscarCarona(idCarona);
    await ensureMembro(req.user.idUsuario, carona.idGrupo);

    if (carona.idMotorista !== req.user.idUsuario) {
      throw AppError.forbidden('Apenas o motorista pode cancelar a carona.');
    }
    if (carona.status !== STATUS.ABERTA) {
      throw AppError.conflict('Esta carona nao pode mais ser cancelada.');
    }

    carona.status = STATUS.CANCELADA;
    await carona.save();

    await emitirAtualizacao(req, idCarona, carona.idGrupo);
    return await responderDetalhe(res, idCarona);
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.cancelar]');
  }
}

// Lista as caronas em que o usuario participa: como motorista (anunciou) OU
// como passageiro (pediu/entrou). Resumo por carona, mais recentes primeiro.
async function listar(req, res) {
  try {
    const meuId = req.user.idUsuario;
    const { Op } = db.Sequelize;

    const vinculos = await db.CaronaUsuario.findAll({
      where: { idPassageiro: meuId },
      attributes: ['idCarona', 'status'],
    });
    const statusPorCarona = new Map(
      vinculos.map((v) => [v.idCarona, v.status]),
    );
    const idsComoPassageiro = vinculos.map((v) => v.idCarona);

    const ondeParticipa = [{ idMotorista: meuId }];
    if (idsComoPassageiro.length) {
      ondeParticipa.push({ idCarona: { [Op.in]: idsComoPassageiro } });
    }

    const caronas = await db.Carona.findAll({
      where: { ativo: true, [Op.or]: ondeParticipa },
      include: [
        { model: db.Grupo, as: 'grupo', attributes: ['idGrupo', 'nome'] },
        { model: db.Usuario, as: 'motorista', attributes: ['idUsuario', 'nome'] },
        { model: db.Carro, as: 'carro', attributes: ['idCarro', 'capacidade'] },
        { model: db.CaronaUsuario, as: 'passageiros', attributes: ['idPivot', 'status'] },
      ],
      order: [['data', 'DESC'], ['idCarona', 'DESC']],
    });

    const lista = caronas.map((c) => {
      const ehMotorista = c.idMotorista === meuId;
      const lugares = c.carro ? Math.max(c.carro.capacidade - 1, 0) : null;
      const aprovados = (c.passageiros || []).filter(
        (p) => p.status === PSTATUS.APROVADO,
      ).length;
      return {
        idCarona: c.idCarona,
        idGrupo: c.idGrupo,
        grupoNome: c.grupo ? c.grupo.nome : null,
        status: c.status,
        data: c.data,
        destino: c.destino,
        papel: ehMotorista ? 'motorista' : 'passageiro',
        motoristaNome: c.motorista ? c.motorista.nome : null,
        lugares,
        ocupadas: aprovados,
        // Status do meu pedido (so faz sentido quando sou passageiro).
        meuStatus: ehMotorista ? null : statusPorCarona.get(c.idCarona) || null,
      };
    });

    return res.status(200).json(lista);
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.listar]');
  }
}

// Detalhe de uma carona: motorista + carro + passageiros (com status). So
// membro do grupo pode ver.
async function detalhe(req, res) {
  try {
    const idCarona = parseIdCarona(req);

    const carona = await db.Carona.findOne({
      where: { idCarona, ativo: true },
      include: includeDetalhe(),
    });
    if (!carona) {
      throw AppError.notFound('Carona nao encontrada.');
    }

    await ensureMembro(req.user.idUsuario, carona.idGrupo);

    return res.status(200).json(montarDetalhe(carona));
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.detalhe]');
  }
}

module.exports = {
  anunciar,
  pedir,
  cancelarPedido,
  decidir,
  atualizarCustos,
  concluir,
  cancelar,
  listar,
  detalhe,
};
