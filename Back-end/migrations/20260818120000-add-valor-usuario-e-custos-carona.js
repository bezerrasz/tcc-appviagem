'use strict';

// Equivalente Sequelize de migrations/sql/20260818-valor-usuario-e-custos-carona.sql,
// que tinha sido aplicado so via SQL: bancos criados com db:migrate ficavam sem
// estas colunas e toda consulta de carona falhava ("Unknown column 'kmRodados'").
// Idempotente: so adiciona o que falta, para nao quebrar em bancos onde o
// script SQL ja foi rodado manualmente.
const COLUNAS = [
  ['usuario', 'valor', (S) => ({ type: S.DECIMAL(10, 2), allowNull: false, defaultValue: 0 })],
  ['carona', 'kmRodados', (S) => ({ type: S.DECIMAL(8, 2), allowNull: true })],
  ['carona', 'valorLitro', (S) => ({ type: S.DECIMAL(6, 2), allowNull: true })],
];

module.exports = {
  async up(queryInterface, Sequelize) {
    for (const [tabela, coluna, def] of COLUNAS) {
      const existentes = await queryInterface.describeTable(tabela);
      if (!existentes[coluna]) {
        await queryInterface.addColumn(tabela, coluna, def(Sequelize));
      }
    }
  },

  async down(queryInterface) {
    for (const [tabela, coluna] of [...COLUNAS].reverse()) {
      const existentes = await queryInterface.describeTable(tabela);
      if (existentes[coluna]) {
        await queryInterface.removeColumn(tabela, coluna);
      }
    }
  },
};
