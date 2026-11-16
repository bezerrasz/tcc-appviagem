'use strict';

module.exports = (sequelize, DataTypes) => {
  const Grupo = sequelize.define(
    'Grupo',
    {
      idGrupo: {
        type: DataTypes.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      idUsuarioCriado: {
        type: DataTypes.INTEGER,
        allowNull: false,
      },
      nome: {
        type: DataTypes.STRING(120),
        allowNull: false,
      },
      dataCriacao: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      ativo: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      },
    },
    {
      tableName: 'grupo',
      timestamps: false,
    },
  );

  Grupo.associate = (models) => {
    Grupo.belongsTo(models.Usuario, {
      foreignKey: 'idUsuarioCriado',
      as: 'criador',
    });
    Grupo.hasMany(models.GrupoUsuario, {
      foreignKey: 'idGrupo',
      as: 'membros',
    });
    Grupo.hasMany(models.Mensagem, {
      foreignKey: 'idGrupo',
      as: 'mensagens',
    });
    Grupo.belongsToMany(models.Usuario, {
      through: models.GrupoUsuario,
      foreignKey: 'idGrupo',
      otherKey: 'idUsuario',
      as: 'usuarios',
    });
  };

  return Grupo;
};
