-- ============================================================================
-- carro.consumoMedio (equivalente SQL da migration
-- 20260916120000-add-consumo-medio-to-carro). MySQL.
-- Consumo medio do carro em km/L, informado no cadastro do veiculo.
-- Carros ja cadastrados recebem 10 km/L (mesmo default do model).
-- So aplicar se a coluna ainda nao existir no banco.
-- ============================================================================

ALTER TABLE `carro`
  ADD COLUMN `consumoMedio` FLOAT NOT NULL DEFAULT 10;

-- ----------------------------------------------------------------------------
-- Rollback (apenas se precisar desfazer).
-- ----------------------------------------------------------------------------
-- ALTER TABLE `carro` DROP COLUMN `consumoMedio`;
