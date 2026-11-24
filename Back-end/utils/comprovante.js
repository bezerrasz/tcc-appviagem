'use strict';

const crypto = require('crypto');
const security = require('../config/security');
const upload = require('./upload');

// Pasta dos comprovantes Pix (uploads/comprovantes). Nao e servida
// estaticamente: o arquivo so sai pela rota que confere se quem pede e o
// motorista da carona ou o proprio passageiro.
const PASTA = upload.pastaDeUploads('comprovantes');

// Recebe o comprovante no campo "comprovante" e grava como
// <idCarona>-<idPassageiro>-<ms desde a epoca Unix>-<aleatorio>.<ext>. O
// sufixo aleatorio evita que dois envios no mesmo milissegundo (clique duplo)
// gravem no mesmo arquivo: o envio recusado apagaria o do envio aceito.
const receberComprovante = upload.criarUpload({
  pasta: PASTA,
  campo: 'comprovante',
  tipos: security.COMPROVANTE_TIPOS,
  tamanhoMax: security.COMPROVANTE_TAMANHO_MAX,
  nomeArquivo: (req, ext) => `${Number(req.params.idCarona)}-${req.user.idUsuario}-${Date.now()}-${crypto.randomBytes(4).toString('hex')}${ext}`,
  mensagemTipo: 'Formato invalido. Envie uma imagem (JPG, PNG, WEBP) ou um PDF.',
});

module.exports = {
  PASTA,
  receberComprovante,
  assinaturaValida: upload.assinaturaValida,
  caminho: (nomeArquivo) => upload.caminhoSeguro(PASTA, nomeArquivo),
  remover: (nomeArquivo) => upload.removerArquivo(PASTA, nomeArquivo),
};
