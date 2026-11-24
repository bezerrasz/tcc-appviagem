-- ============================================================================
-- Saldos separados e pagamento da carona via Pix com comprovante
-- (equivalente SQL da migration 20261123130000-saldos-e-pagamento-carona).
-- MySQL. Aplicar nesta ordem.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- usuario.saldoPago / usuario.saldoRecebido / usuario.chavePix
-- saldoPago: total pago como passageiro. saldoRecebido: total recebido como
-- motorista. Ambos so mudam quando um comprovante Pix e importado.
-- chavePix: mostrada aos passageiros aprovados quando a carona e concluida
-- (77 = tamanho maximo de uma chave Pix, que e o de e-mail).
-- ----------------------------------------------------------------------------
ALTER TABLE `usuario`
  ADD COLUMN `saldoPago`     DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  ADD COLUMN `saldoRecebido` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  ADD COLUMN `chavePix`      VARCHAR(77) NULL;

-- ----------------------------------------------------------------------------
-- usuario.valor (saldo unico, editado manualmente) deixa de existir.
-- ----------------------------------------------------------------------------
ALTER TABLE `usuario`
  DROP COLUMN `valor`;

-- ----------------------------------------------------------------------------
-- carona_usuario.valorDevido / comprovante / dataPagamento
-- valorDevido: rateio fixado ao concluir a carona (so passageiros aprovados).
-- comprovante: nome do arquivo em uploads/comprovantes/.
-- dataPagamento: quando o comprovante foi importado. Nulo = pagamento pendente.
-- ----------------------------------------------------------------------------
ALTER TABLE `carona_usuario`
  ADD COLUMN `valorDevido`   DECIMAL(10, 2) NULL,
  ADD COLUMN `comprovante`   VARCHAR(255) NULL,
  ADD COLUMN `dataPagamento` DATETIME NULL;

-- ----------------------------------------------------------------------------
-- Rollback (executar de tras para frente, apenas se precisar desfazer).
-- O valor antigo de usuario.valor NAO e recuperado.
-- ----------------------------------------------------------------------------
-- ALTER TABLE `carona_usuario`
--   DROP COLUMN `dataPagamento`, DROP COLUMN `comprovante`, DROP COLUMN `valorDevido`;
-- ALTER TABLE `usuario` ADD COLUMN `valor` DECIMAL(10, 2) NOT NULL DEFAULT 0.00;
-- ALTER TABLE `usuario`
--   DROP COLUMN `chavePix`, DROP COLUMN `saldoRecebido`, DROP COLUMN `saldoPago`;
