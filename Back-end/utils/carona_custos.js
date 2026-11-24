'use strict';

const security = require('../config/security');

// Custos de uma viagem e o rateio entre os ocupantes.
//
// - Combustivel: usa o consumoMedio (km/L) real do veiculo cadastrado pelo
//   motorista (com fallback seguro caso o carro tenha sido removido).
// - Manutencao veicular (taxa): R$ 0,10/km (T_km da formula do TCC), destinada
//   integralmente ao motorista pelo desgaste do veiculo.
// - Taxa do app (taxaApp): definida automaticamente apos informar a distancia
//   e o valor do litro, com base no valor total da viagem a ratear
//   (combustivel + manutencao): R$ 5,00 se superar R$ 20,00; R$ 2,50 caso
//   contrario — diluida no total da viagem e repassada ao Pix da plataforma.

// Arredonda para centavos (evita 0.30000000000000004 no JSON).
function centavos(valor) {
  return Math.round(valor * 100) / 100;
}

// Retorna null enquanto km/valor do litro nao foram informados: sem os dois
// nao ha total de viagem nem taxa da plataforma vinculada.
function calcularCustos({ kmRodados, valorLitro, passageiros, consumoMedio }) {
  if (kmRodados == null || valorLitro == null) return null;

  // DECIMAL chega como string do MySQL.
  const km = Number(kmRodados);
  const litro = Number(valorLitro);
  if (!Number.isFinite(km) || !Number.isFinite(litro)) return null;

  const cmInformado = Number(consumoMedio);
  const cm = Number.isFinite(cmInformado) && cmInformado > 0
    ? cmInformado
    : security.CARONA_CONSUMO_MEDIO_KM_L;

  const litros = km / cm;
  const combustivel = centavos(litros * litro);
  // Manutencao veicular por km (fica com o motorista).
  const taxa = centavos(km * security.CARONA_TAXA_POR_KM);
  const custoVeiculo = centavos(combustivel + taxa);

  const qtd = Math.max(Number(passageiros) || 0, 0);
  // Faixa da taxa da plataforma definida sobre o valor total da viagem a
  // ratear (combustivel + manutencao), independente da quantidade de ocupantes.
  const taxaApp = custoVeiculo > security.CARONA_TAXA_APP_LIMIAR_RATEIO
    ? security.CARONA_TAXA_APP_PADRAO
    : security.CARONA_TAXA_APP_REDUZIDA;

  const total = centavos(custoVeiculo + taxaApp);

  return {
    kmRodados: km,
    valorLitro: litro,
    consumoMedio: centavos(cm),
    litros: centavos(litros),
    combustivel,
    taxaPorKm: security.CARONA_TAXA_POR_KM,
    taxa,
    custoVeiculo,
    taxaApp,
    chavePixApp: security.APP_PIX_CHAVE || null,
    recebedorApp: security.APP_PIX_RECEBEDOR,
    total,
    passageiros: qtd,
    // Sem passageiro aprovado (qtd <= 1 significa apenas o motorista) ainda nao
    // ha divisao de cobranca.
    valorPorPassageiro: qtd > 0 ? centavos(total / qtd) : null,
  };
}

module.exports = { calcularCustos };
