'use strict';

const db = require('../../models');
const AppError = require('../../utils/app_error');
const security = require('../../config/security');
const { ensureMembro } = require('../../utils/membership');
const { calcularCustos } = require('../../utils/carona_custos');
const comprovante = require('../../utils/comprovante');
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
  { model: db.Usuario, as: 'motorista', attributes: ['idUsuario', 'nome', 'chavePix'] },
  {
    model: db.Carro,
    as: 'carro',
    attributes: ['idCarro', 'marca', 'modelo', 'anoFabricacao', 'cor', 'placa', 'capacidade', 'consumoMedio'],
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
// os custos/rateio da viagem) do ponto de vista de [idViewer]:
//   - o pagamento de cada passageiro (valor devido, aguardando confirmacao ou
//     pago) so aparece para o motorista e para o proprio passageiro;
//   - a chave Pix do motorista aparece para ele e para os passageiros aprovados
//     enquanto a carona nao estiver cancelada.
function montarDetalhe(carona, idViewer) {
  const lugares = carona.carro
    ? Math.max(carona.carro.capacidade - 1, 0)
    : null;
  const souMotorista = carona.idMotorista === idViewer;
  const passageiros = (carona.passageiros || []).map((p) => {
    const idUsuario = p.passageiro ? p.passageiro.idUsuario : p.idPassageiro;
    const item = {
      idUsuario,
      nome: p.passageiro ? p.passageiro.nome : null,
      status: p.status,
      pagamento: null,
    };
    const valorDevido = p.valorDevido != null ? Number(p.valorDevido) : 0;
    if ((souMotorista || idUsuario === idViewer) && valorDevido > 0) {
      item.pagamento = {
        valor: valorDevido,
        pago: p.dataPagamento != null,
        dataPagamento: p.dataPagamento,
        temComprovante: Boolean(p.comprovante),
      };
    }
    return item;
  });
  const souAprovado = passageiros.some(
    (p) => p.idUsuario === idViewer && p.status === PSTATUS.APROVADO,
  );
  const veChavePix = carona.status !== STATUS.CANCELADA && (souMotorista || souAprovado);
  const ocupadas = passageiros.filter((p) => p.status === PSTATUS.APROVADO).length;
  // O rateio usa o consumoMedio real do veiculo e divide entre ocupantes
  // confirmados (passageiros aprovados + motorista).
  const custos = calcularCustos({
    kmRodados: carona.kmRodados,
    valorLitro: carona.valorLitro,
    passageiros: ocupadas + 1, // motorista incluso
    consumoMedio: carona.carro ? carona.carro.consumoMedio : null,
  });

  // Se a carona ja foi concluida, garante que o valor por pessoa exibido no
  // resumo nao divirja do valorDevido fixado na tabela carona_usuario (caso o
  // veiculo tenha sido editado ou removido posteriormente).
  if (carona.status === STATUS.CONCLUIDA && custos && ocupadas > 0) {
    const valorFixado = (carona.passageiros || [])
      .filter((p) => p.status === PSTATUS.APROVADO && p.valorDevido != null)
      .map((p) => Number(p.valorDevido))
      .find((v) => Number.isFinite(v) && v > 0);
    if (valorFixado != null) {
      custos.valorPorPassageiro = valorFixado;
    }
  }

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
      ? {
          idUsuario: carona.motorista.idUsuario,
          nome: carona.motorista.nome,
          chavePix: veChavePix ? carona.motorista.chavePix : null,
        }
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
          consumoMedio: Number(carona.carro.consumoMedio) || null,
        }
      : null,
    passageiros,
    // Null enquanto o motorista nao informar km + valor do litro.
    custos,
  };
}

// Recarrega a carona completa e responde 200 com o detalhe, do ponto de vista
// do usuario autenticado.
async function responderDetalhe(req, res, idCarona) {
  const completa = await db.Carona.findByPk(idCarona, {
    include: includeDetalhe(),
  });
  return res.status(200).json(montarDetalhe(completa, req.user.idUsuario));
}

// Recarrega o resumo da carona e emite carona:atualizada tanto para a sala do
// grupo (cards do chat) quanto para as salas individuais dos participantes
// (tela de detalhes e listagem "Minhas caronas").
async function emitirAtualizacao(req, idCarona, idGrupo, idsUsuariosExtras = []) {
  const io = req.app.get('io');
  if (!io) return;
  const resumo = await db.Carona.findByPk(idCarona, {
    include: includeCaronaResumo(db),
  });
  if (!resumo) return;
  const payload = caronaPayload(resumo);
  io.to(`grupo:${idGrupo}`).emit('carona:atualizada', payload);
  const destinatarios = new Set(
    [
      resumo.idMotorista,
      ...(resumo.passageiros || []).map((p) => p.idPassageiro),
      ...idsUsuariosExtras,
    ].filter(Boolean),
  );
  for (const uid of destinatarios) {
    io.to(`user:${uid}`).emit('carona:atualizada', payload);
  }
}

// Motorista anuncia uma carona no grupo. Cria a carona ja com motorista e carro
// ativo (status 'aberta') e posta um card no chat. Tudo numa transacao.
async function anunciar(req, res) {
  let t;
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

    t = await db.sequelize.transaction();

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
    if (t && !t.finished) await t.rollback().catch(() => {});
    return tratarErro(res, err, '[carona_controller.anunciar]');
  }

  // Broadcast do card e atualizacao da lista do motorista so apos o commit.
  const io = req.app.get('io');
  if (io) {
    io.to(`grupo:${idGrupo}`).emit('mensagem:nova', payload);
    if (payload.carona) {
      io.to(`user:${req.user.idUsuario}`).emit('carona:atualizada', payload.carona);
    }
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
    return await responderDetalhe(req, res, idCarona);
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

    await emitirAtualizacao(req, idCarona, carona.idGrupo, [req.user.idUsuario]);
    return await responderDetalhe(req, res, idCarona);
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.cancelarPedido]');
  }
}

// Motorista aprova ou recusa o pedido de um passageiro. Aprovar respeita o
// limite de vagas (capacidade do carro - 1). Body: { acao: 'aprovar'|'recusar' }.
async function decidir(req, res) {
  let idGrupoCarona = null;
  let t;

  try {
    const idCarona = parseIdCarona(req);
    const idPassageiro = parseIdPassageiro(req);
    const acao = req.body.acao;
    if (acao !== 'aprovar' && acao !== 'recusar') {
      throw AppError.validation("Acao invalida. Use 'aprovar' ou 'recusar'.");
    }

    // 1. Iniciamos a transação dentro do try para garantir rollback/tratamento
    t = await db.sequelize.transaction();

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
    return await responderDetalhe(req, res, idCarona);
    
  } catch (err) {
    // 5. Se algo quebrou ou deu lotado, desfazemos tudo e destrancamos a tabela
    if (t && !t.finished) {
      await t.rollback().catch(() => {});
    }
    return tratarErro(res, err, '[carona_controller.decidir]');
  }
}

// Passageiro importa o comprovante do Pix feito por fora do app. So depois da
// carona concluida, so passageiro aprovado e uma unica vez. Numa transacao (com
// o vinculo travado contra envio duplo): grava o comprovante e deixa o
// pagamento aguardando a confirmacao do motorista (dataPagamento nula).
async function enviarComprovante(req, res) {
  const arquivo = req.file;
  let t;
  let idCarona;
  let carona;
  try {
    idCarona = parseIdCarona(req);
    if (!arquivo) {
      throw AppError.validation('Envie o comprovante no campo "comprovante".');
    }
    if (!(await comprovante.assinaturaValida(arquivo.path, arquivo.mimetype))) {
      throw AppError.validation('O arquivo enviado nao e uma imagem ou PDF valido.');
    }

    carona = await buscarCarona(idCarona);
    await ensureMembro(req.user.idUsuario, carona.idGrupo);
    if (carona.status !== STATUS.CONCLUIDA) {
      throw AppError.conflict(
        'O comprovante so pode ser enviado depois que a carona for concluida.',
      );
    }

    t = await db.sequelize.transaction();

    const vinculo = await db.CaronaUsuario.findOne({
      where: { idCarona, idPassageiro: req.user.idUsuario },
      transaction: t,
      lock: t.LOCK.UPDATE,
    });
    if (!vinculo || vinculo.status !== PSTATUS.APROVADO) {
      throw AppError.forbidden('Apenas passageiros aprovados pagam por esta carona.');
    }
    const valor = Number(vinculo.valorDevido);
    if (!(valor > 0)) {
      throw AppError.conflict('Nao ha valor a pagar nesta carona.');
    }
    if (vinculo.dataPagamento) {
      throw AppError.conflict('O pagamento desta carona ja foi confirmado.');
    }
    if (vinculo.comprovante) {
      throw AppError.conflict(
        'O comprovante ja foi enviado. Aguarde a confirmacao do motorista.',
      );
    }

    await vinculo.update(
      { comprovante: arquivo.filename },
      { transaction: t },
    );

    await t.commit();
  } catch (err) {
    if (t && !t.finished) await t.rollback().catch(() => {});
    // Arquivo recebido mas nao aproveitado (invalido, duplicado, erro).
    if (arquivo) await comprovante.remover(arquivo.filename);
    return tratarErro(res, err, '[carona_controller.enviarComprovante]');
  }

  try {
    await emitirAtualizacao(req, idCarona, carona.idGrupo);
    return await responderDetalhe(req, res, idCarona);
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.enviarComprovante]');
  }
}

// Fluxo compartilhado de revisao de comprovante pelo motorista (confirmar
// recebimento ou recusar comprovante invalido para permitir reenvio).
async function processarRevisaoComprovante(
  req,
  res,
  tag,
  { acaoMensagem, msgSemComprovante, exigirValor },
  onVinculo,
) {
  let t;
  let idCarona;
  let idPassageiro;
  let carona;
  let posCommit;
  try {
    idCarona = parseIdCarona(req);
    idPassageiro = parseIdPassageiro(req);
    carona = await buscarCarona(idCarona);
    await ensureMembro(req.user.idUsuario, carona.idGrupo);

    if (carona.idMotorista !== req.user.idUsuario) {
      throw AppError.forbidden(acaoMensagem);
    }
    if (carona.status !== STATUS.CONCLUIDA) {
      throw AppError.conflict(
        'Os comprovantes so podem ser avaliados apos a conclusao da carona.',
      );
    }

    t = await db.sequelize.transaction();

    const vinculo = await db.CaronaUsuario.findOne({
      where: { idCarona, idPassageiro },
      transaction: t,
      lock: t.LOCK.UPDATE,
    });
    if (!vinculo || vinculo.status !== PSTATUS.APROVADO) {
      throw AppError.notFound('Passageiro aprovado nao encontrado nesta carona.');
    }
    const valor = Number(vinculo.valorDevido);
    if (exigirValor && !(valor > 0)) {
      throw AppError.conflict('Nao ha valor a receber deste passageiro.');
    }
    if (vinculo.dataPagamento) {
      throw AppError.conflict('Este pagamento ja foi confirmado.');
    }
    if (!vinculo.comprovante) {
      throw AppError.conflict(msgSemComprovante);
    }

    posCommit = await onVinculo({ t, carona, vinculo, idPassageiro, valor });
    await t.commit();
  } catch (err) {
    if (t && !t.finished) await t.rollback().catch(() => {});
    return tratarErro(res, err, tag);
  }

  try {
    if (typeof posCommit === 'function') {
      await posCommit();
    }
    await emitirAtualizacao(req, idCarona, carona.idGrupo);
    return await responderDetalhe(req, res, idCarona);
  } catch (err) {
    return tratarErro(res, err, tag);
  }
}

// Motorista confirma o recebimento do Pix apos conferir o comprovante enviado
// pelo passageiro. Numa transacao atomica (com o vinculo travado contra
// confirmacao dupla): registra dataPagamento e soma o valor devido ao
// saldoPago do passageiro e ao saldoRecebido do motorista.
async function confirmarPagamento(req, res) {
  return processarRevisaoComprovante(
    req,
    res,
    '[carona_controller.confirmarPagamento]',
    {
      acaoMensagem: 'Apenas o motorista pode confirmar o recebimento do Pix.',
      msgSemComprovante: 'O passageiro ainda nao importou o comprovante do Pix.',
      exigirValor: true,
    },
    async ({ t, carona, vinculo, idPassageiro, valor }) => {
      await vinculo.update(
        { dataPagamento: new Date() },
        { transaction: t },
      );
      await db.Usuario.increment(
        { saldoPago: valor },
        { where: { idUsuario: idPassageiro }, transaction: t },
      );
      await db.Usuario.increment(
        { saldoRecebido: valor },
        { where: { idUsuario: carona.idMotorista }, transaction: t },
      );
      return () => {
        const io = req.app.get('io');
        if (io) {
          io.to(`user:${idPassageiro}`).emit('financeiro:atualizado', {});
          io.to(`user:${carona.idMotorista}`).emit('financeiro:atualizado', {});
        }
      };
    },
  );
}

// Motorista recusa um comprovante errado/ilegivel enviado pelo passageiro,
// limpando o registro para destravar um novo upload via Pix.
async function recusarComprovante(req, res) {
  return processarRevisaoComprovante(
    req,
    res,
    '[carona_controller.recusarComprovante]',
    {
      acaoMensagem: 'Apenas o motorista pode recusar o comprovante.',
      msgSemComprovante: 'Nao ha comprovante pendente para recusar.',
      exigirValor: false,
    },
    async ({ t, vinculo }) => {
      const arquivoAntigo = vinculo.comprovante;
      await vinculo.update({ comprovante: null }, { transaction: t });
      return () => comprovante.remover(arquivoAntigo);
    },
  );
}

// Devolve o arquivo do comprovante de um passageiro. So o motorista da carona
// e o proprio passageiro podem ver.
async function verComprovante(req, res) {
  try {
    const idCarona = parseIdCarona(req);
    const idPassageiro = parseIdPassageiro(req);
    const carona = await buscarCarona(idCarona);
    await ensureMembro(req.user.idUsuario, carona.idGrupo);

    const meuId = req.user.idUsuario;
    if (meuId !== carona.idMotorista && meuId !== idPassageiro) {
      throw AppError.forbidden(
        'Apenas o motorista e o proprio passageiro podem ver o comprovante.',
      );
    }

    const vinculo = await db.CaronaUsuario.findOne({
      where: { idCarona, idPassageiro },
      attributes: ['comprovante'],
    });
    const caminho = vinculo && comprovante.caminho(vinculo.comprovante);
    if (!caminho) {
      throw AppError.notFound('Comprovante nao encontrado.');
    }

    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'private, no-store');
    return res.sendFile(caminho, (err) => {
      if (err && !res.headersSent) {
        res.status(404).json({ error: 'NOT_FOUND', message: 'Comprovante nao encontrado.' });
      }
    });
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.verComprovante]');
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
    return await responderDetalhe(req, res, idCarona);
  } catch (err) {
    return tratarErro(res, err, '[carona_controller.atualizarCustos]');
  }
}

// So o motorista conclui, somente enquanto a carona esta 'aberta' e depois de
// informar os custos. Na conclusao o rateio e fixado: cada passageiro aprovado
// passa a dever valorDevido (pendente ate importar o comprovante Pix). Tudo
// numa transacao com a carona travada, para nao concluir duas vezes nem
// aprovar alguem no meio do calculo.
async function concluir(req, res) {
  let t;
  let idCarona;
  let carona;
  try {
    idCarona = parseIdCarona(req);
    t = await db.sequelize.transaction();

    carona = await db.Carona.findOne({
      where: { idCarona, ativo: true },
      transaction: t,
      lock: t.LOCK.UPDATE,
    });
    if (!carona) {
      throw AppError.notFound('Carona nao encontrada.');
    }
    await ensureMembro(req.user.idUsuario, carona.idGrupo);

    if (carona.idMotorista !== req.user.idUsuario) {
      throw AppError.forbidden('Apenas o motorista pode concluir a carona.');
    }
    if (carona.status !== STATUS.ABERTA) {
      throw AppError.conflict('So caronas abertas podem ser concluidas.');
    }
    if (carona.kmRodados == null || carona.valorLitro == null) {
      throw AppError.validation(security.CARONA_CUSTOS_OBRIGATORIOS_MSG);
    }

    const aprovados = await db.CaronaUsuario.count({
      where: { idCarona, status: PSTATUS.APROVADO },
      transaction: t,
    });
    if (aprovados > 0) {
      const carro = carona.idCarro
        ? await db.Carro.findByPk(carona.idCarro, {
            attributes: ['consumoMedio'],
            transaction: t,
          })
        : null;
      // Mesmo calculo exibido no detalhe: total / (aprovados + motorista),
      // usando o consumoMedio real do veiculo cadastrado.
      const custos = calcularCustos({
        kmRodados: carona.kmRodados,
        valorLitro: carona.valorLitro,
        passageiros: aprovados + 1,
        consumoMedio: carro ? carro.consumoMedio : null,
      });
      if (custos && custos.valorPorPassageiro > 0) {
        await db.CaronaUsuario.update(
          { valorDevido: custos.valorPorPassageiro },
          { where: { idCarona, status: PSTATUS.APROVADO }, transaction: t },
        );
      }
    }

    // Pedidos ainda nao avaliados nao podem continuar "pendentes" numa carona
    // ja encerrada.
    await db.CaronaUsuario.update(
      { status: PSTATUS.RECUSADO },
      { where: { idCarona, status: PSTATUS.PENDENTE }, transaction: t },
    );

    carona.status = STATUS.CONCLUIDA;
    await carona.save({ transaction: t });
    await t.commit();
  } catch (err) {
    if (t && !t.finished) await t.rollback().catch(() => {});
    return tratarErro(res, err, '[carona_controller.concluir]');
  }

  try {
    await emitirAtualizacao(req, idCarona, carona.idGrupo);
    // O motorista passa a ter valores a receber.
    const io = req.app.get('io');
    if (io) io.to(`user:${carona.idMotorista}`).emit('financeiro:atualizado', {});
    return await responderDetalhe(req, res, idCarona);
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
    return await responderDetalhe(req, res, idCarona);
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

    return res.status(200).json(montarDetalhe(carona, req.user.idUsuario));
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
  enviarComprovante,
  confirmarPagamento,
  recusarComprovante,
  verComprovante,
};