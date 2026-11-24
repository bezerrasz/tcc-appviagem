'use strict';

// Foto de perfil do usuario. Guarda so o nome do arquivo, que fica em
// uploads/profilePictures/ no formato <idUsuario>-<ms desde a epoca Unix>.<ext>.
// Nulo enquanto o usuario nao enviou foto.
module.exports = {
  async up(queryInterface, Sequelize) {
    const colunas = await queryInterface.describeTable('usuario');
    if (!colunas.fotoPerfil) {
      await queryInterface.addColumn('usuario', 'fotoPerfil', {
        type: Sequelize.STRING(255),
        allowNull: true,
      });
    }
  },

  async down(queryInterface) {
    const colunas = await queryInterface.describeTable('usuario');
    if (colunas.fotoPerfil) {
      await queryInterface.removeColumn('usuario', 'fotoPerfil');
    }
  },
};
