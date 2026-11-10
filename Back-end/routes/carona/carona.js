'use strict';

const { Router } = require('express');
const multer = require('multer');
const caronaController = require('../../controllers/carona/carona_controller');
const authenticate = require('../../middlewares/authenticate');

const router = Router();
const upload = multer({ dest: 'uploads/comprovantes/' });

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

// Rotas PIX (Atualizadas)
router.post('/caronas/:idCarona/pix', authenticate, upload.single('comprovante'), caronaController.enviarComprovante);
router.post('/caronas/:idCarona/pix/confirmar/:idPassageiro', authenticate, caronaController.confirmarPagamentoPix);

module.exports = router;