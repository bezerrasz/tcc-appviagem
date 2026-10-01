'use strict';

const db = require('../../models');
const AppError = require('../../utils/app_error');
const security = require('../../config/security');

function parseIdCarro(req) {
  const idCarro = Number(req.params.idCarro);
  if (!Number.isInteger(idCarro) || idCarro <= 0) {
    throw AppError.validation('Carro invalido.');
  }
  return idCarro;
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
    message: 'Erro interno ao processar carro.',
  });
}

// Normaliza e valida os campos do carro. Lanca AppError.validation com o mapa
// de erros por campo (mesmo formato do cadastro de usuario).
function validarCarro(input) {
  const erros = {};
  const marca = (input.marca || '').trim();
  const modelo = (input.modelo || '').trim();
  const cor = (input.cor || '').trim();
  const placa = (input.placa || '').replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
  const ano = Number(input.anoFabricacao);
  const anoMax = new Date().getFullYear() + 1;
  const capacidade = Number(input.capacidade);
  const consumoMedio = Number(input.consumoMedio);

  if (marca.length < security.CARRO_TEXTO_MIN) {
    erros.marca = `Marca deve ter ao menos ${security.CARRO_TEXTO_MIN} caracteres.`;
  }
  if (modelo.length < security.CARRO_TEXTO_MIN) {
    erros.modelo = `Modelo deve ter ao menos ${security.CARRO_TEXTO_MIN} caracteres.`;
  }
  if (cor.length < security.CARRO_TEXTO_MIN) {
    erros.cor = `Cor deve ter ao menos ${security.CARRO_TEXTO_MIN} caracteres.`;
  }
  if (!Number.isInteger(ano) || ano < security.CARRO_ANO_MIN || ano > anoMax) {
    erros.anoFabricacao = `Ano deve estar entre ${security.CARRO_ANO_MIN} e ${anoMax}.`;
  }
  if (!security.CARRO_PLACA_REGEX.test(placa)) {
    erros.placa = 'Placa invalida. Use o formato ABC1234 ou ABC1D23.';
  }
  if (!Number.isInteger(capacidade) || capacidade < security.CARRO_CAPACIDADE_MIN) {
    erros.capacidade = `Capacidade deve ser de ao menos ${security.CARRO_CAPACIDADE_MIN} (motorista incluso).`;
  }
  if (!Number.isFinite(consumoMedio) || consumoMedio <= 0) {
    erros.consumoMedio = `Consumo medio deve ser um numero positivo.`;
  }
  
  if (Object.keys(erros).length > 0) {
    throw AppError.validation('Dados invalidos.', erros);
  }

  return { marca, modelo, cor, placa, anoFabricacao: ano, capacidade, consumoMedio};
}

function carroPayload(carro) {
  return {
    idCarro: carro.idCarro,
    marca: carro.marca,
    modelo: carro.modelo,
    anoFabricacao: carro.anoFabricacao,
    cor: carro.cor,
    placa: carro.placa,
    capacidade: carro.capacidade,
    consumoMedio: Number(carro.consumoMedio) || 0, // A conversão mágica acontece aqui!
    ativo: carro.ativo,
  };
}

// Carro do usuario logado, ou 404 se nao existir/nao for dele.
async function buscarMeuCarro(idUsuario, idCarro) {
  const carro = await db.Carro.findOne({ where: { idCarro, idUsuario } });
  if (!carro) {
    throw AppError.notFound('Carro nao encontrado.');
  }
  return carro;
}

async function listar(req, res) {
  try {
    const carros = await db.Carro.findAll({
      where: { idUsuario: req.user.idUsuario },
      order: [['ativo', 'DESC'], ['idCarro', 'DESC']],
    });
    return res.status(200).json(carros.map(carroPayload));
  } catch (err) {
    return tratarErro(res, err, '[carro_controller.listar]');
  }
}

// Cria um carro do usuario. Se for o primeiro (nenhum ativo ainda), ja entra
// como ativo para que o usuario possa aceitar caronas sem um passo extra.
async function criar(req, res) {
  const t = await db.sequelize.transaction();
  try {
    const dados = validarCarro(req.body);
    const idUsuario = req.user.idUsuario;

    // 1. O CADEADO MESTRE: Tranca o registro do motorista
    // Impede que duas requisições simultâneas tentem criar carros ao mesmo tempo
    await db.Usuario.findOne({
      where: { idUsuario },
      attributes: ['idUsuario'],
      transaction: t,
      lock: t.LOCK.UPDATE,
    });

    // 2. Agora olhamos o status dos carros sabendo que ninguém vai mexer neles
    const temAtivo = await db.Carro.findOne({
      where: { idUsuario, ativo: true },
      transaction: t,
    });

    // 3. Cria o carro dentro do ambiente seguro
    const carro = await db.Carro.create({
      ...dados,
      idUsuario,
      ativo: !temAtivo,
    }, { transaction: t });

    await t.commit();
    return res.status(201).json(carroPayload(carro));
  } catch (err) {
    if (!t.finished) {
      await t.rollback().catch(() => {});
    }
    return tratarErro(res, err, '[carro_controller.criar]');
  }
}

async function atualizar(req, res) {
  try {
    const idCarro = parseIdCarro(req);
    const carro = await buscarMeuCarro(req.user.idUsuario, idCarro);
    const dados = validarCarro(req.body);

    carro.marca = dados.marca;
    carro.modelo = dados.modelo;
    carro.cor = dados.cor;
    carro.placa = dados.placa;
    carro.anoFabricacao = dados.anoFabricacao;
    carro.capacidade = dados.capacidade;
    carro.consumoMedio = dados.consumoMedio;
    await carro.save();

    return res.status(200).json(carroPayload(carro));
  } catch (err) {
    return tratarErro(res, err, '[carro_controller.atualizar]');
  }
}

// Exclui um carro. A FK carona.idCarro tem ON DELETE SET NULL, entao o
// historico das caronas e preservado (apenas perde a referencia ao carro).
async function excluir(req, res) {
  try {
    const idCarro = parseIdCarro(req);
    const carro = await buscarMeuCarro(req.user.idUsuario, idCarro);
    await carro.destroy();
    return res.status(204).send();
  } catch (err) {
    return tratarErro(res, err, '[carro_controller.excluir]');
  }
}

// Seleciona o carro ativo: zera os demais do usuario e ativa este. Transacao
// para manter o invariante "no maximo um ativo por usuario".
async function ativar(req, res) {
  const t = await db.sequelize.transaction();
  try {
    const idCarro = parseIdCarro(req);
    const idUsuario = req.user.idUsuario;

    // 1. O CADEADO MESTRE: Tranca o registro do motorista. 
    // Qualquer requisição simultânea desse usuário vai ter que esperar na fila.
    await db.Usuario.findOne({
      where: { idUsuario },
      attributes: ['idUsuario'],
      transaction: t,
      lock: t.LOCK.UPDATE,
    });

    const carro = await db.Carro.findOne({
      where: { idCarro, idUsuario },
      transaction: t,
    });
    
    if (!carro) {
      throw AppError.notFound('Carro nao encontrado.');
    }

    // 2. Agora podemos desativar todos com segurança, sem medo de concorrência
    await db.Carro.update(
      { ativo: false },
      { where: { idUsuario }, transaction: t },
    );
    
    // 3. E ativamos apenas o escolhido
    carro.ativo = true;
    await carro.save({ transaction: t });

    await t.commit();
    return res.status(200).json(carroPayload(carro));
  } catch (err) {
    if (!t.finished) {
      await t.rollback().catch(() => {});
    }
    return tratarErro(res, err, '[carro_controller.ativar]');
  }
}

module.exports = { listar, criar, atualizar, excluir, ativar };
