'use strict';

const bcrypt = require('bcryptjs');
const db = require('../models');
const AppError = require('../utils/app_error');
const security = require('../config/security');
const fotoPerfil = require('../utils/foto_perfil');

const TIPOS_VALIDOS = db.Usuario.rawAttributes.tipo.values;

// Formato do usuario devolvido ao app (perfil proprio).
function usuarioPayload(usuario) {
  return {
    idUsuario: usuario.idUsuario,
    nome: usuario.nome,
    email: usuario.email,
    tipo: usuario.tipo,
    dataNascimento: usuario.dataNascimento,
    valor: Number(usuario.valor),
    fotoPerfil: usuario.fotoPerfil,
  };
}

function validar(input) {
  const erros = {};

  if (!input.nome || input.nome.trim().length < security.NOME_TAMANHO_MIN) {
    erros.nome = `Nome deve ter ao menos ${security.NOME_TAMANHO_MIN} caracteres.`;
  }

  if (!input.email || !security.EMAIL_REGEX.test(input.email)) {
    erros.email = 'E-mail invalido.';
  }

  if (!input.senha || input.senha.length < security.SENHA_TAMANHO_MIN) {
    erros.senha = `Senha deve ter ao menos ${security.SENHA_TAMANHO_MIN} caracteres.`;
  }

  const cpfDigitos = (input.cpf || '').replace(/\D/g, '');
  if (cpfDigitos.length !== security.CPF_TAMANHO) {
    erros.cpf = `CPF deve ter ${security.CPF_TAMANHO} digitos.`;
  }

  const dataNasc = input.dataNascimento ? new Date(input.dataNascimento) : null;
  if (!dataNasc || Number.isNaN(dataNasc.getTime())) {
    erros.dataNascimento = 'Data de nascimento invalida.';
  } else {
    const hoje = new Date();
    const idade = hoje.getFullYear() - dataNasc.getFullYear()
      - (hoje < new Date(hoje.getFullYear(), dataNasc.getMonth(), dataNasc.getDate()) ? 1 : 0);
    if (idade < security.IDADE_MINIMA) {
      erros.dataNascimento = `Usuario deve ter no minimo ${security.IDADE_MINIMA} anos.`;
    }
  }

  if (!TIPOS_VALIDOS.includes(input.tipo)) {
    erros.tipo = `Tipo deve ser um de: ${TIPOS_VALIDOS.join(', ')}.`;
  }

  if (Object.keys(erros).length > 0) {
    throw AppError.validation('Dados invalidos.', erros);
  }

  return { cpfDigitos };
}

async function registrar(req, res) {
  try {
    const input = req.body;
    const { cpfDigitos } = validar(input);
    const email = input.email.trim().toLowerCase();
    const nome = input.nome.trim();

    const [emailExistente, cpfExistente, nomeExistente] = await Promise.all([
      db.Usuario.findOne({ where: { email } }),
      db.Usuario.findOne({ where: { cpf: cpfDigitos } }),
      db.Usuario.findOne({
        where: db.sequelize.where(
          db.sequelize.fn('LOWER', db.sequelize.col('nome')),
          nome.toLowerCase(),
        ),
      }),
    ]);
    if (emailExistente) {
      throw AppError.conflict('E-mail ja cadastrado.', { campo: 'email' });
    }
    if (cpfExistente) {
      throw AppError.conflict('CPF ja cadastrado.', { campo: 'cpf' });
    }
    if (nomeExistente) {
      throw AppError.conflict('Nome ja cadastrado.', { campo: 'nome' });
    }

    const senhaHash = await bcrypt.hash(input.senha, security.BCRYPT_COST);

    const usuario = await db.Usuario.create({
      nome: input.nome.trim(),
      email,
      senhaHash,
      dataNascimento: input.dataNascimento,
      cpf: cpfDigitos,
      tipo: input.tipo,
    });

    return res.status(201).json({
      idUsuario: usuario.idUsuario,
      nome: usuario.nome,
      email: usuario.email,
      tipo: usuario.tipo,
      dataNascimento: usuario.dataNascimento,
      dataCadastro: usuario.dataCadastro,
      ativo: usuario.ativo,
      valor: Number(usuario.valor),
      fotoPerfil: usuario.fotoPerfil,
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
    if (err.name === 'SequelizeUniqueConstraintError') {
      const campo = err.errors?.[0]?.path || 'campo';
      return res.status(409).json({
        error: 'CONFLICT',
        message: `${campo} ja cadastrado.`,
        details: { campo },
      });
    }
    console.error('[usuario_controller.registrar]', err);
    return res.status(500).json({
      error: 'INTERNAL',
      message: 'Erro interno ao registrar usuario.',
    });
  }
}

// Calcula a idade em anos a partir de uma data de nascimento.
function idadeEm(dataNasc) {
  const hoje = new Date();
  return hoje.getFullYear() - dataNasc.getFullYear()
    - (hoje < new Date(hoje.getFullYear(), dataNasc.getMonth(), dataNasc.getDate()) ? 1 : 0);
}

// Atualiza o proprio perfil: e-mail e data de nascimento (tela de perfil) e o
// saldo (tela Inicio). Aceita atualizacao parcial (um campo por vez).
async function atualizarMe(req, res) {
  try {
    const idUsuario = req.user.idUsuario;
    const usuario = await db.Usuario.findByPk(idUsuario);
    if (!usuario) {
      throw AppError.notFound('Usuario nao encontrado.');
    }

    const erros = {};
    const mudancas = {};

    if (req.body.email !== undefined) {
      const email = (req.body.email || '').trim().toLowerCase();
      if (!security.EMAIL_REGEX.test(email)) {
        erros.email = 'E-mail invalido.';
      } else if (email !== usuario.email) {
        const existente = await db.Usuario.findOne({ where: { email } });
        if (existente) {
          throw AppError.conflict('E-mail ja cadastrado.', { campo: 'email' });
        }
        mudancas.email = email;
      }
    }

    if (req.body.dataNascimento !== undefined) {
      const data = req.body.dataNascimento ? new Date(req.body.dataNascimento) : null;
      if (!data || Number.isNaN(data.getTime())) {
        erros.dataNascimento = 'Data de nascimento invalida.';
      } else if (idadeEm(data) < security.IDADE_MINIMA) {
        erros.dataNascimento = `Usuario deve ter no minimo ${security.IDADE_MINIMA} anos.`;
      } else {
        mudancas.dataNascimento = req.body.dataNascimento;
      }
    }

    // Saldo: o usuario simplesmente informa quanto tem (sem transacao
    // bancaria), entao a unica regra e a faixa aceita.
    if (req.body.valor !== undefined) {
      const valor = Number(req.body.valor);
      if (
        !Number.isFinite(valor)
        || valor < security.SALDO_MIN
        || valor > security.SALDO_MAX
      ) {
        erros.valor = `Valor deve estar entre ${security.SALDO_MIN} e ${security.SALDO_MAX}.`;
      } else {
        mudancas.valor = Math.round(valor * 100) / 100;
      }
    }

    if (Object.keys(erros).length > 0) {
      throw AppError.validation('Dados invalidos.', erros);
    }

    if (Object.keys(mudancas).length > 0) {
      await usuario.update(mudancas);
    }

    return res.status(200).json(usuarioPayload(usuario));
  } catch (err) {
    if (err instanceof AppError) {
      return res.status(err.httpStatus).json({
        error: err.type,
        message: err.message,
        details: err.details,
      });
    }
    console.error('[usuario_controller.atualizarMe]', err);
    return res.status(500).json({
      error: 'INTERNAL',
      message: 'Erro interno ao atualizar perfil.',
    });
  }
}

// Busca usuarios por nome ou email (para adicionar a um grupo).
// Exige um termo minimo pra nao despejar a base inteira.
async function buscar(req, res) {
  try {
    const termo = (req.query.busca || '').trim();
    if (termo.length < security.BUSCA_TAMANHO_MIN) {
      return res.status(200).json([]);
    }

    const { Op } = db.Sequelize;
    const like = `%${termo}%`;
    
    const usuarios = await db.Usuario.findAll({
      where: {
        ativo: true,
        [Op.or]: [
          { nome: { [Op.like]: like } },
          { email: { [Op.like]: like } },
        ],
      },
      attributes: ['idUsuario', 'nome', 'email', 'tipo'],
      order: [['nome', 'ASC']],
      limit: 20,
    });

    // Função de máscara de privacidade (LGPD)
    const mascararEmail = (email) => {
      if (!email || !email.includes('@')) return email;
      const [usuario, dominio] = email.split('@');
      // Mostra as 3 primeiras letras (ou só a 1ª se for um nome muito curto)
      const parteVisivel = usuario.length > 3 ? usuario.substring(0, 3) : usuario.charAt(0);
      return `${parteVisivel}***@${dominio}`;
    };

    return res.status(200).json(
      usuarios.map((u) => ({
        idUsuario: u.idUsuario,
        nome: u.nome,
        email: mascararEmail(u.email), // Agora o dado trafega protegido pela rede
        tipo: u.tipo,
      })),
    );
  } catch (err) {
    console.error('[usuario_controller.buscar]', err);
    return res.status(500).json({
      error: 'INTERNAL',
      message: 'Erro interno ao buscar usuarios.',
    });
  }
}

// Troca a foto de perfil do proprio usuario. O arquivo ja foi gravado pelo
// middleware receberFoto em uploads/profilePictures/<id>-<ms>.<ext>; aqui ele
// e validado, o nome vai para usuario.fotoPerfil e a foto anterior e apagada.
async function atualizarFoto(req, res) {
  const arquivo = req.file;
  try {
    if (!arquivo) {
      throw AppError.validation('Envie a imagem no campo "foto".');
    }
    if (!(await fotoPerfil.assinaturaValida(arquivo.path, arquivo.mimetype))) {
      throw AppError.validation('O arquivo enviado nao e uma imagem valida.');
    }

    const usuario = await db.Usuario.findByPk(req.user.idUsuario);
    if (!usuario) {
      throw AppError.notFound('Usuario nao encontrado.');
    }

    const anterior = usuario.fotoPerfil;
    await usuario.update({ fotoPerfil: arquivo.filename });
    // So apaga a antiga depois de gravar a nova no banco: se o update falhar,
    // o usuario continua com a foto que tinha.
    await fotoPerfil.remover(anterior);

    return res.status(200).json(usuarioPayload(usuario));
  } catch (err) {
    // Arquivo recebido mas nao aproveitado (invalido ou erro no banco).
    if (arquivo) await fotoPerfil.remover(arquivo.filename);
    if (err instanceof AppError) {
      return res.status(err.httpStatus).json({
        error: err.type,
        message: err.message,
        details: err.details,
      });
    }
    console.error('[usuario_controller.atualizarFoto]', err);
    return res.status(500).json({
      error: 'INTERNAL',
      message: 'Erro interno ao atualizar a foto de perfil.',
    });
  }
}

module.exports = { registrar, buscar, atualizarMe, atualizarFoto };
