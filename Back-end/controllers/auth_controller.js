'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../models');
const AppError = require('../utils/app_error');
const jwtConfig = require('../config/jwt');
const security = require('../config/security');

const CREDENCIAIS_INVALIDAS = 'Usuario ou senha invalidos.';
const USUARIO_INATIVO = 'Usuario inativo. Contate o administrador.';

// O usuario pode logar pelo email OU pelo nome. Decidimos pelo formato:
// se parece email, busca por email (normalizado); senao, busca por nome
// (case-insensitive). Assim nunca ha ambiguidade entre os dois campos.
function buscarPorIdentificador(identificador) {
  const valor = identificador.trim();
  if (security.EMAIL_REGEX.test(valor)) {
    return db.Usuario.findOne({ where: { email: valor.toLowerCase() } });
  }
  return db.Usuario.findOne({
    where: db.sequelize.where(
      db.sequelize.fn('LOWER', db.sequelize.col('nome')),
      valor.toLowerCase(),
    ),
  });
}

async function login(req, res) {
  try {
    // Aceita `identificador` (email ou nome); mantem `email` por compat.
    const identificador = req.body.identificador || req.body.email;
    const { senha } = req.body;
    if (!identificador || !senha) {
      throw AppError.validation(CREDENCIAIS_INVALIDAS);
    }

    const usuario = await buscarPorIdentificador(identificador);

    // Mesma mensagem pra "nao existe" e "senha errada" (evita enumeration).
    if (!usuario) {
      throw AppError.validation(CREDENCIAIS_INVALIDAS);
    }

    const senhaCorreta = await bcrypt.compare(senha, usuario.senhaHash);
    if (!senhaCorreta) {
      throw AppError.validation(CREDENCIAIS_INVALIDAS);
    }

    if (!usuario.ativo) {
      throw AppError.validation(USUARIO_INATIVO);
    }

    const token = jwt.sign(
      {
        sub: usuario.idUsuario,
        tipo: usuario.tipo,
        email: usuario.email,
      },
      jwtConfig.secret,
      { expiresIn: jwtConfig.expiresIn },
    );

    return res.status(200).json({
      token,
      usuario: {
        idUsuario: usuario.idUsuario,
        nome: usuario.nome,
        email: usuario.email,
        tipo: usuario.tipo,
        dataNascimento: usuario.dataNascimento,
        dataCadastro: usuario.dataCadastro,
        ativo: usuario.ativo,
        valor: Number(usuario.valor),
        fotoPerfil: usuario.fotoPerfil,
      },
    });
  } catch (err) {
    if (err instanceof AppError) {
      return res.status(401).json({
        error: 'UNAUTHENTICATED',
        message: err.message,
      });
    }
    console.error('[auth_controller.login]', err);
    return res.status(500).json({
      error: 'INTERNAL',
      message: 'Erro interno ao autenticar.',
    });
  }
}

function me(req, res) {
  return res.status(200).json({ user: req.user });
}

module.exports = { login, me };
