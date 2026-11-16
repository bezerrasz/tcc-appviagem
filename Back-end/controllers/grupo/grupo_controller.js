'use strict';

const db = require('../../models');
const AppError = require('../../utils/app_error');
const security = require('../../config/security');
const { ensureMembro } = require('../../utils/membership');

function validarNome(nome) {
  if (!nome || nome.trim().length < security.GRUPO_NOME_TAMANHO_MIN) {
    throw AppError.validation('Dados invalidos.', {
      nome: `Nome do grupo deve ter ao menos ${security.GRUPO_NOME_TAMANHO_MIN} caracteres.`,
    });
  }
}

async function criar(req, res) {
  try {
    const { nome } = req.body;
    validarNome(nome);

    // idUsuarioCriado vem do token (req.user), nunca do corpo.
    const idUsuarioCriado = req.user.idUsuario;

    // Cria o grupo e ja registra o criador como membro admin (atomico).
    const grupo = await db.sequelize.transaction(async (t) => {
      const novo = await db.Grupo.create(
        { idUsuarioCriado, nome: nome.trim() },
        { transaction: t },
      );
      await db.GrupoUsuario.create(
        { idGrupo: novo.idGrupo, idUsuario: idUsuarioCriado, isAdm: true },
        { transaction: t },
      );
      return novo;
    });

    return res.status(201).json({
      idGrupo: grupo.idGrupo,
      nome: grupo.nome,
      dataCriacao: grupo.dataCriacao,
      ativo: grupo.ativo,
      isAdm: true,
    });
  } catch (err) {
    if (err instanceof AppError) {
      const status = err.type === 'CONFLICT' ? 409 : 400;
      return res.status(status).json({
        error: err.type,
        message: err.message,
        details: err.details,
      });
    }
    console.error('[grupo_controller.criar]', err);
    return res.status(500).json({
      error: 'INTERNAL',
      message: 'Erro interno ao criar grupo.',
    });
  }
}

async function listar(req, res) {
  try {
    // Grupos ativos em que o usuario autenticado e membro.
    const membros = await db.GrupoUsuario.findAll({
      where: { idUsuario: req.user.idUsuario },
      include: [{ model: db.Grupo, as: 'grupo', where: { ativo: true } }],
      order: [[{ model: db.Grupo, as: 'grupo' }, 'dataCriacao', 'DESC']],
    });

    const grupos = membros.map((m) => ({
      idGrupo: m.grupo.idGrupo,
      nome: m.grupo.nome,
      dataCriacao: m.grupo.dataCriacao,
      isAdm: m.isAdm,
    }));

    return res.status(200).json(grupos);
  } catch (err) {
    console.error('[grupo_controller.listar]', err);
    return res.status(500).json({
      error: 'INTERNAL',
      message: 'Erro interno ao listar grupos.',
    });
  }
}

async function listarMembros(req, res) {
  try {
    const idGrupo = Number(req.params.idGrupo);
    if (!Number.isInteger(idGrupo) || idGrupo <= 0) {
      throw AppError.validation('Grupo invalido.');
    }
    await ensureMembro(req.user.idUsuario, idGrupo);

    const membros = await db.GrupoUsuario.findAll({
      where: { idGrupo },
      include: [{ model: db.Usuario, as: 'usuario', attributes: ['idUsuario', 'nome', 'tipo'] }],
      order: [['isAdm', 'DESC'], [{ model: db.Usuario, as: 'usuario' }, 'nome', 'ASC']],
    });

    const lista = membros.map((m) => ({
      idUsuario: m.usuario.idUsuario,
      nome: m.usuario.nome,
      tipo: m.usuario.tipo,
      isAdm: m.isAdm,
    }));

    return res.status(200).json(lista);
  } catch (err) {
    if (err instanceof AppError) {
      return res.status(err.httpStatus).json({
        error: err.type,
        message: err.message,
        details: err.details,
      });
    }
    console.error('[grupo_controller.listarMembros]', err);
    return res.status(500).json({
      error: 'INTERNAL',
      message: 'Erro interno ao listar membros.',
    });
  }
}

async function adicionarMembro(req, res) {
  try {
    const idGrupo = Number(req.params.idGrupo);
    if (!Number.isInteger(idGrupo) || idGrupo <= 0) {
      throw AppError.validation('Grupo invalido.');
    }

    // Precisa ser membro E admin do grupo.
    const vinculo = await ensureMembro(req.user.idUsuario, idGrupo);
    if (!vinculo.isAdm) {
      throw AppError.forbidden('Apenas administradores podem adicionar membros.');
    }

    const idUsuario = Number(req.body.idUsuario);
    if (!Number.isInteger(idUsuario) || idUsuario <= 0) {
      throw AppError.validation('Usuario invalido.', {
        idUsuario: 'Informe um usuario valido.',
      });
    }

    const usuario = await db.Usuario.findOne({ where: { idUsuario, ativo: true } });
    if (!usuario) {
      throw AppError.notFound('Usuario nao encontrado.');
    }

    const jaMembro = await db.GrupoUsuario.findOne({ where: { idGrupo, idUsuario } });
    if (jaMembro) {
      throw AppError.conflict('Usuario ja e membro do grupo.', { campo: 'idUsuario' });
    }

    await db.GrupoUsuario.create({ idGrupo, idUsuario, isAdm: false });

    // Notifica em tempo real o proprio usuario adicionado (sala user:<id>),
    // pra lista "Meus grupos" dele atualizar sem refresh. Ele nao precisa
    // estar na sala do grupo. isAdm: false (entrou como membro comum).
    const grupo = await db.Grupo.findByPk(idGrupo);
    const io = req.app.get('io');
    if (io && grupo) {
      io.to(`user:${idUsuario}`).emit('grupo:adicionado', {
        idGrupo: grupo.idGrupo,
        nome: grupo.nome,
        dataCriacao: grupo.dataCriacao,
        isAdm: false,
      });
    }

    return res.status(201).json({
      idUsuario: usuario.idUsuario,
      nome: usuario.nome,
      tipo: usuario.tipo,
      isAdm: false,
    });
  } catch (err) {
    if (err instanceof AppError) {
      return res.status(err.httpStatus).json({
        error: err.type,
        message: err.message,
        details: err.details,
      });
    }
    if (err.name === 'SequelizeUniqueConstraintError') {
      return res.status(409).json({
        error: 'CONFLICT',
        message: 'Usuario ja e membro do grupo.',
        details: { campo: 'idUsuario' },
      });
    }
    console.error('[grupo_controller.adicionarMembro]', err);
    return res.status(500).json({
      error: 'INTERNAL',
      message: 'Erro interno ao adicionar membro.',
    });
  }
}

module.exports = { criar, listar, listarMembros, adicionarMembro };
