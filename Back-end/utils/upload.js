'use strict';

const fs = require('fs');
const path = require('path');
const multer = require('multer');
const AppError = require('./app_error');

// Assinatura (magic bytes) de cada formato aceito. O mimetype vem do cliente e
// pode mentir; a assinatura e conferida no arquivo ja gravado.
const ASSINATURAS = {
  'image/jpeg': (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff,
  'image/png': (b) => b.subarray(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47])),
  'image/webp': (b) => b.toString('ascii', 0, 4) === 'RIFF'
    && b.toString('ascii', 8, 12) === 'WEBP',
  'application/pdf': (b) => b.toString('ascii', 0, 5) === '%PDF-',
};

const UPLOADS = path.resolve(__dirname, '..', 'uploads');

// Pasta dentro de uploads/, criada se nao existir. Caminho absoluto, para nao
// depender do diretorio de onde o node foi iniciado.
function pastaDeUploads(nome) {
  const pasta = path.join(UPLOADS, nome);
  fs.mkdirSync(pasta, { recursive: true });
  return pasta;
}

// Middleware que recebe um arquivo (multipart) no campo [campo] e grava em
// [pasta] com o nome devolvido por nomeArquivo(req, ext). Erros do multer
// (formato, tamanho) viram 400 no formato padrao da API.
function criarUpload({ pasta, campo, tipos, tamanhoMax, nomeArquivo, mensagemTipo }) {
  const upload = multer({
    storage: multer.diskStorage({
      destination: pasta,
      filename: (req, file, cb) => cb(null, nomeArquivo(req, tipos[file.mimetype])),
    }),
    limits: { fileSize: tamanhoMax, files: 1 },
    fileFilter: (req, file, cb) => {
      if (!tipos[file.mimetype]) return cb(AppError.validation(mensagemTipo));
      return cb(null, true);
    },
  }).single(campo);

  return (req, res, next) => {
    upload(req, res, (err) => {
      if (!err) return next();
      let erro = err;
      if (!(err instanceof AppError)) {
        const mb = tamanhoMax / (1024 * 1024);
        erro = AppError.validation(err.code === 'LIMIT_FILE_SIZE'
          ? `O arquivo deve ter no maximo ${mb} MB.`
          : 'Nao foi possivel receber o arquivo.');
      }
      return res.status(erro.httpStatus).json({
        error: erro.type,
        message: erro.message,
        details: erro.details,
      });
    });
  };
}

async function assinaturaValida(caminho, mimetype) {
  const confere = ASSINATURAS[mimetype];
  if (!confere) return false;
  const fh = await fs.promises.open(caminho, 'r');
  try {
    const { buffer } = await fh.read(Buffer.alloc(12), 0, 12, 0);
    return confere(buffer);
  } finally {
    await fh.close();
  }
}

// Caminho de um arquivo na pasta, so para nomes simples (sem barras): um valor
// estranho no banco nunca aponta para fora da pasta. Null se o nome e invalido.
function caminhoSeguro(pasta, nomeArquivo) {
  if (!nomeArquivo || path.basename(nomeArquivo) !== nomeArquivo) return null;
  return path.join(pasta, nomeArquivo);
}

async function removerArquivo(pasta, nomeArquivo) {
  const caminho = caminhoSeguro(pasta, nomeArquivo);
  if (caminho) await fs.promises.unlink(caminho).catch(() => {});
}

module.exports = {
  pastaDeUploads,
  criarUpload,
  assinaturaValida,
  caminhoSeguro,
  removerArquivo,
};
