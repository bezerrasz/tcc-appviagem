'use strict';

// Consumo medio do carro (km/L), adicionado ao model Carro no commit c5b0cf3
// sem migration: bancos criados com db:migrate ficavam sem a coluna e toda
// consulta de carro falhava ("Unknown column 'consumoMedio'"), inclusive o
// anuncio de carona. Idempotente: so adiciona se faltar, para nao quebrar em
// bancos onde a coluna ja foi criada manualmente.
module.exports = {
  async up(queryInterface, Sequelize) {
    const colunas = await queryInterface.describeTable('carro');
    if (!colunas.consumoMedio) {
      await queryInterface.addColumn('carro', 'consumoMedio', {
        type: Sequelize.FLOAT,
        allowNull: false,
        defaultValue: 10.0,
      });
    }
  },

  async down(queryInterface) {
    const colunas = await queryInterface.describeTable('carro');
    if (colunas.consumoMedio) {
      await queryInterface.removeColumn('carro', 'consumoMedio');
    }
  },
};
