'use strict';

const { Router } = require('express');
const caronaController = require('../../controllers/carona/carona_controller');
const authenticate = require('../../middlewares/authenticate');
const { receberComprovante } = require('../../utils/comprovante');

const router = Router();

// Motorista anuncia uma carona no grupo.
router.post('/grupos/:idGrupo/caronas', authenticate, caronaController.anunciar);

router.get('/caronas', authenticate, caronaController.listar);
router.get('/caronas/:idCarona', authenticate, caronaController.detalhe);

// Passageiro pede para entrar / cancela o proprio pedido.
router.post('/caronas/:idCarona/pedir', authenticate, caronaController.pedir);
router.delete('/caronas/:idCarona/pedir', authenticate, caronaController.cancelarPedido);

// Motorista decide um pedido (aprovar/recusar).
router.patch(
  '/caronas/:idCarona/passageiros/:idPassageiro',
  authenticate,
  caronaController.decidir,
);

// Motorista informa km rodados + valor do litro (base do rateio da viagem).
router.patch('/caronas/:idCarona/custos', authenticate, caronaController.atualizarCustos);

// Motorista conclui/cancela a carona.
router.patch('/caronas/:idCarona/concluir', authenticate, caronaController.concluir);
router.patch('/caronas/:idCarona/cancelar', authenticate, caronaController.cancelar);

// Pagamento via Pix (feito por fora do app). O passageiro aprovado importa o
// comprovante depois da carona concluida (multipart, campo "comprovante"); o
// motorista e o proprio passageiro podem ver o arquivo.
router.post(
  '/caronas/:idCarona/comprovante',
  authenticate,
  receberComprovante,
  caronaController.enviarComprovante,
);
router.get(
  '/caronas/:idCarona/passageiros/:idPassageiro/comprovante',
  authenticate,
  caronaController.verComprovante,
);

module.exports = router;