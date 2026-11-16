'use strict';

// Fim da distincao grupo publico/privado: todo grupo e privado (so entra quem
// um admin adicionar). A coluna nunca controlou acesso, so o rotulo na tela.
module.exports = {
  async up(queryInterface) {
    await queryInterface.removeColumn('grupo', 'isPrivado');
  },

  async down(queryInterface, Sequelize) {
    // Ao desfazer, todos voltam como privados (unico comportamento real).
    await queryInterface.addColumn('grupo', 'isPrivado', {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    });
  },
};
