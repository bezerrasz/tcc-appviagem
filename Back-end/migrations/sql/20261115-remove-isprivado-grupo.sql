-- ============================================================================
-- Remove a distincao grupo publico/privado (equivalente SQL da migration
-- 20261115120000-remove-isprivado-from-grupo). MySQL.
-- Todo grupo passa a ser privado: so entra quem um admin adicionar.
-- A coluna nunca controlou acesso, apenas o rotulo exibido no app.
-- ============================================================================

ALTER TABLE `grupo`
  DROP COLUMN `isPrivado`;

-- ----------------------------------------------------------------------------
-- Rollback (apenas se precisar desfazer). Todos voltam como privados.
-- ----------------------------------------------------------------------------
-- ALTER TABLE `grupo`
--   ADD COLUMN `isPrivado` TINYINT(1) NOT NULL DEFAULT 1;
