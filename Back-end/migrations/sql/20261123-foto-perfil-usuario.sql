-- ============================================================================
-- usuario.fotoPerfil (equivalente SQL da migration
-- 20261123120000-add-foto-perfil-to-usuario). MySQL.
-- Nome do arquivo da foto de perfil, salvo em uploads/profilePictures/ no
-- formato <idUsuario>-<ms desde a epoca Unix>.<ext>. Nulo = sem foto.
-- ============================================================================

ALTER TABLE `usuario`
  ADD COLUMN `fotoPerfil` VARCHAR(255) NULL;

-- ----------------------------------------------------------------------------
-- Rollback (apenas se precisar desfazer).
-- ----------------------------------------------------------------------------
-- ALTER TABLE `usuario` DROP COLUMN `fotoPerfil`;
