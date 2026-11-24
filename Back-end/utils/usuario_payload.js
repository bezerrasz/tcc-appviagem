'use strict';

// Formato do proprio usuario devolvido ao app (login, cadastro, edicao de
// perfil e foto). Unico lugar que monta esse JSON, para as rotas nao
// divergirem. DECIMAL chega como string do MySQL; Number() converte.
function usuarioPayload(usuario) {
  return {
    idUsuario: usuario.idUsuario,
    nome: usuario.nome,
    email: usuario.email,
    tipo: usuario.tipo,
    dataNascimento: usuario.dataNascimento,
    dataCadastro: usuario.dataCadastro,
    ativo: usuario.ativo,
    saldoPago: Number(usuario.saldoPago) || 0,
    saldoRecebido: Number(usuario.saldoRecebido) || 0,
    chavePix: usuario.chavePix,
    fotoPerfil: usuario.fotoPerfil,
  };
}

module.exports = { usuarioPayload };
