'use strict';

const fs = require('fs');
const path = require('path');
const multer = require('multer');
const AppError = require('./app_error');
const security = require('../config/security');

// Pasta das fotos de perfil. Caminho absoluto (relativo ao Back-end, nao ao
// diretorio de onde o node foi iniciado) e criada no boot se nao existir.
const PASTA = path.resolve(__dirname, '..', 'uploads', 'profilePictures');
fs.mkdirSync(PASTA, { recursive: true });

// Nome do arquivo: <idUsuario>-<ms desde a epoca Unix>.<ext>. O timestamp
// muda a cada envio, entao a URL nova nunca bate com uma versao em cache.
const upload = multer({
  storage: multer.diskStorage({
    destination: PASTA,
    filename: (req, file, cb) => {
      const ext = security.FOTO_PERFIL_TIPOS[file.mimetype];
      cb(null, `${req.user.idUsuario}-${Date.now()}${ext}`);
    },
  }),
  limits: { fileSize: security.FOTO_PERFIL_TAMANHO_MAX, files: 1 },
  fileFilter: (req, file, cb) => {
    if (!security.FOTO_PERFIL_TIPOS[file.mimetype]) {
      return cb(AppError.validation('Formato invalido. Envie uma imagem JPG, PNG ou WEBP.'));
    }
    return cb(null, true);
  },
}).single('foto');

// Middleware de upload. Erros do multer (formato, tamanho, campo errado) viram
// 400 no formato padrao da API, em vez da pagina HTML de erro do Express.
function receberFoto(req, res, next) {
  upload(req, res, (err) => {
    if (!err) return next();
    let erro = err;
    if (!(err instanceof AppError)) {
      const mb = security.FOTO_PERFIL_TAMANHO_MAX / (1024 * 1024);
      erro = AppError.validation(err.code === 'LIMIT_FILE_SIZE'
        ? `A imagem deve ter no maximo ${mb} MB.`
        : 'Nao foi possivel receber a imagem.');
    }
    return res.status(erro.httpStatus).json({
      error: erro.type,
      message: erro.message,
      details: erro.details,
    });
  });
}

// O mimetype vem do cliente e pode mentir: confere a assinatura (magic bytes)
// do arquivo gravado. JPEG FF D8 FF; PNG 89 50 4E 47; WEBP "RIFF"...."WEBP".
async function assinaturaValida(caminho, mimetype) {
  const fh = await fs.promises.open(caminho, 'r');
  try {
    const { buffer } = await fh.read(Buffer.alloc(12), 0, 12, 0);
    if (mimetype === 'image/jpeg') {
      return buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
    }
    if (mimetype === 'image/png') {
      return buffer.subarray(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47]));
    }
    if (mimetype === 'image/webp') {
      return buffer.toString('ascii', 0, 4) === 'RIFF'
        && buffer.toString('ascii', 8, 12) === 'WEBP';
    }
    return false;
  } finally {
    await fh.close();
  }
}

// Remove um arquivo da pasta de fotos. So aceita o nome simples (sem barras),
// para que um valor estranho no banco nunca apague algo fora da pasta.
async function remover(nomeArquivo) {
  if (!nomeArquivo || path.basename(nomeArquivo) !== nomeArquivo) return;
  await fs.promises.unlink(path.join(PASTA, nomeArquivo)).catch(() => {});
}

module.exports = { PASTA, receberFoto, assinaturaValida, remover };
