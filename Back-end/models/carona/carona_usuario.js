'use strict';

const security = require('../../config/security');

module.exports = (sequelize, DataTypes) => {
  const CaronaUsuario = sequelize.define(
    'CaronaUsuario',
    {
      idPivot: {
        type: DataTypes.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      idCarona: {
        type: DataTypes.INTEGER,
        allowNull: false,
      },
      idPassageiro: {
        type: DataTypes.INTEGER,
        allowNull: false,
      },
      // Pedido do passageiro: pendente -> aprovado/recusado (decisao do motorista).
      status: {
        type: DataTypes.ENUM(...Object.values(security.CARONA_PASSAGEIRO_STATUS)),
        allowNull: false,
        defaultValue: security.CARONA_PASSAGEIRO_STATUS.PENDENTE,
      },
      // Nula no pedido; so faz sentido quando houver rota definida.
      // Pagamento (so para aprovados de caronas concluidas). valorDevido e o
      // rateio fixado na conclusao; dataPagamento nula = pendente.
      valorDevido: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: true,
      },
      // Nome do arquivo do comprovante Pix em uploads/comprovantes/.
      comprovante: {
        type: DataTypes.STRING(255),
        allowNull: true,
      },
      dataPagamento: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      distancia: {
        type: DataTypes.FLOAT,
        allowNull: true,
      },
    },
    {
      tableName: 'carona_usuario',
      timestamps: false,
    },
  );

  CaronaUsuario.associate = (models) => {
    CaronaUsuario.belongsTo(models.Carona, { foreignKey: 'idCarona', as: 'carona' });
    CaronaUsuario.belongsTo(models.Usuario, {
      foreignKey: 'idPassageiro',
      as: 'passageiro',
    });
  };

  return CaronaUsuario;
};
