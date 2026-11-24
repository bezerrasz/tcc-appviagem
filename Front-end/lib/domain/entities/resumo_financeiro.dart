/// Um pagamento ainda não feito por um passageiro, numa carona concluída que
/// o usuário conduziu.
class ValorAReceber {
  final int idCarona;
  final DateTime data;
  final String? destino;
  final String? grupoNome;
  final int idPassageiro;
  final String passageiroNome;
  final double valor;

  const ValorAReceber({
    required this.idCarona,
    required this.data,
    required this.destino,
    required this.grupoNome,
    required this.idPassageiro,
    required this.passageiroNome,
    required this.valor,
  });
}

/// Situação financeira do usuário (tela Início).
class ResumoFinanceiro {
  /// Total já pago como passageiro.
  final double saldoPago;

  /// Total já recebido como motorista.
  final double saldoRecebido;

  /// Pagamentos pendentes, por passageiro e carona.
  final List<ValorAReceber> aReceber;

  /// Soma dos pendentes.
  final double totalAReceber;

  /// saldoRecebido + totalAReceber.
  final double totalGeral;

  const ResumoFinanceiro({
    required this.saldoPago,
    required this.saldoRecebido,
    required this.aReceber,
    required this.totalAReceber,
    required this.totalGeral,
  });
}
