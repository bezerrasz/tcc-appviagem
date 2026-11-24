'use strict';

const { Router } = require('express');
const usuarioController = require('../controllers/usuario_controller');
const authenticate = require('../middlewares/authenticate');
const { receberFoto } = require('../utils/foto_perfil');

const router = Router();

router.get('/usuarios', authenticate, usuarioController.buscar);
router.post('/usuarios', usuarioController.registrar);
router.patch('/usuarios/me', authenticate, usuarioController.atualizarMe);
// Foto de perfil: multipart/form-data com a imagem no campo "foto".
router.put('/usuarios/me/foto', authenticate, receberFoto, usuarioController.atualizarFoto);

module.exports = router;
