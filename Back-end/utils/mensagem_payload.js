'use strict';

const security = require('../config/security');

// Formato unico de mensagem usado pelo REST e pelo broadcast do socket, tanto
// para texto quanto para anuncio de carona, pra que o app tenha um parser so.

// Numero de vagas (passageiros) de uma carona = capacidade do carro - 1.
function lugaresDaCarona(carona) {
  if (!carona.carro || carona.carro.capacidade == null) return null;
  return Math.max(carona.carro.capacidade - 1, 0);
}

// Conta passageiros por status (aprovado = ocupa vaga; pendente = aguardando).
function contarPassageiros(carona, status) {
  const lista = carona.passageiros || [];
  return lista.filter((p) => p.status === status).length;
}

function caronaPayload(carona) {
  if (!carona) return null;
  const S = security.CARONA_PASSAGEIRO_STATUS;
  return {
    idCarona: carona.idCarona,
    status: carona.status,
    idMotorista: carona.idMotorista,
    motoristaNome: carona.motorista ? carona.motorista.nome : null,
    destino: carona.destino,
    lugares: lugaresDaCarona(carona),
    ocupadas: contarPassageiros(carona, S.APROVADO),
    pendentes: contarPassageiros(carona, S.PENDENTE),
    data: carona.data,
  };
}

function montarPayload(msg) {
  return {
    idMensagem: msg.idMensagem,
    idGrupo: msg.idGrupo,
    idAutor: msg.idUsuario,
    autorNome: msg.autor ? msg.autor.nome : null,
    conteudo: msg.conteudo,
    dataEnvio: msg.dataEnvio,
    tipo: msg.tipo,
    carona: caronaPayload(msg.carona),
  };
}

// Include reaproveitado nas consultas que devolvem mensagens completas.
// A carona traz motorista (nome), carro (capacidade -> vagas) e os passageiros
// (para contar os aprovados), tudo que o card precisa exibir.
function includeMensagem(db) {
  return [
    { model: db.Usuario, as: 'autor', attributes: ['idUsuario', 'nome'] },
    {
      model: db.Carona,
      as: 'carona',
      include: [
        { model: db.Usuario, as: 'motorista', attributes: ['idUsuario', 'nome'] },
        { model: db.Carro, as: 'carro', attributes: ['idCarro', 'capacidade'] },
        { model: db.CaronaUsuario, as: 'passageiros', attributes: ['idPivot', 'status'] },
      ],
    },
  ];
}

// Include para carregar uma carona "crua" (sem mensagem) com tudo que o
// caronaPayload precisa. Usado nos broadcasts de carona:atualizada.
function includeCaronaResumo(db) {
  return [
    { model: db.Usuario, as: 'motorista', attributes: ['idUsuario', 'nome'] },
    { model: db.Carro, as: 'carro', attributes: ['idCarro', 'capacidade'] },
    {
      model: db.CaronaUsuario,
      as: 'passageiros',
      attributes: ['idPivot', 'idPassageiro', 'status'],
    },
  ];
}

module.exports = {
  montarPayload,
  includeMensagem,
  includeCaronaResumo,
  caronaPayload,
};
