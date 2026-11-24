'use strict';

// Saldos separados e pagamento da carona via Pix com comprovante.
//
// usuario:
//   - saldoPago:     total que o usuario ja pagou como passageiro
//   - saldoRecebido: total que o usuario ja recebeu como motorista
//   - chavePix:      chave Pix do motorista, mostrada aos passageiros quando a
//                    carona e concluida
//   - valor (saldo unico editavel) deixa de existir
//
// carona_usuario (um passageiro numa carona):
//   - valorDevido:   rateio fixado na conclusao da carona (so aprovados)
//   - comprovante:   nome do arquivo em uploads/comprovantes/
//   - dataPagamento: quando o comprovante foi importado; nulo = pendente
//
// Idempotente: so adiciona/remove o que precisa, para nao quebrar em bancos
// onde o script SQL equivalente ja foi aplicado.
const NOVAS = [
  ['usuario', 'saldoPago', (S) => ({ type: S.DECIMAL(10, 2), allowNull: false, defaultValue: 0 })],
  ['usuario', 'saldoRecebido', (S) => ({ type: S.DECIMAL(10, 2), allowNull: false, defaultValue: 0 })],
  ['usuario', 'chavePix', (S) => ({ type: S.STRING(77), allowNull: true })],
  ['carona_usuario', 'valorDevido', (S) => ({ type: S.DECIMAL(10, 2), allowNull: true })],
  ['carona_usuario', 'comprovante', (S) => ({ type: S.STRING(255), allowNull: true })],
  ['carona_usuario', 'dataPagamento', (S) => ({ type: S.DATE, allowNull: true })],
];

async function colunas(queryInterface, tabela) {
  return queryInterface.describeTable(tabela);
}

module.exports = {
  async up(queryInterface, Sequelize) {
    for (const [tabela, coluna, def] of NOVAS) {
      if (!(await colunas(queryInterface, tabela))[coluna]) {
        await queryInterface.addColumn(tabela, coluna, def(Sequelize));
      }
    }
    if ((await colunas(queryInterface, 'usuario')).valor) {
      await queryInterface.removeColumn('usuario', 'valor');
    }
  },

  async down(queryInterface, Sequelize) {
    if (!(await colunas(queryInterface, 'usuario')).valor) {
      await queryInterface.addColumn('usuario', 'valor', {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
        defaultValue: 0,
      });
    }
    for (const [tabela, coluna] of [...NOVAS].reverse()) {
      if ((await colunas(queryInterface, tabela))[coluna]) {
        await queryInterface.removeColumn(tabela, coluna);
      }
    }
  },
};
