'use strict';

const security = require('../config/security');
const upload = require('./upload');

// Pasta das fotos de perfil (uploads/profilePictures), criada no boot.
const PASTA = upload.pastaDeUploads('profilePictures');

// Recebe a foto no campo "foto" e grava como <idUsuario>-<ms desde a epoca
// Unix>.<ext>. O timestamp muda a cada envio, entao a URL nova nunca bate com
// uma versao em cache.
const receberFoto = upload.criarUpload({
  pasta: PASTA,
  campo: 'foto',
  tipos: security.FOTO_PERFIL_TIPOS,
  tamanhoMax: security.FOTO_PERFIL_TAMANHO_MAX,
  nomeArquivo: (req, ext) => `${req.user.idUsuario}-${Date.now()}${ext}`,
  mensagemTipo: 'Formato invalido. Envie uma imagem JPG, PNG ou WEBP.',
});

module.exports = {
  PASTA,
  receberFoto,
  assinaturaValida: upload.assinaturaValida,
  remover: (nomeArquivo) => upload.removerArquivo(PASTA, nomeArquivo),
};
