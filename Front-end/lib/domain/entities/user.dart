enum TipoUsuario { passageiro, motorista, ambos }

extension TipoUsuarioLabel on TipoUsuario {
  String get label => switch (this) {
        TipoUsuario.passageiro => 'Passageiro',
        TipoUsuario.motorista => 'Motorista',
        TipoUsuario.ambos => 'Passageiro e Motorista',
      };
}

/// Identidade do usuário autenticado. NÃO carrega senha — isso é credencial,
/// não dado de perfil; trafega só nas chamadas de auth.
class User {
  final int idUsuario;
  final String name;
  final String email;
  final DateTime dataNascimento;
  final TipoUsuario tipo;

  /// Total já pago como passageiro e total já recebido como motorista. Só
  /// mudam quando um comprovante Pix é importado (não são editáveis).
  final double saldoPago;
  final double saldoRecebido;

  /// Chave Pix do motorista, mostrada aos passageiros quando a carona termina.
  final String? chavePix;

  /// Nome do arquivo da foto de perfil no servidor
  /// (`<idUsuario>-<ms>.<ext>`). Nulo quando o usuário não enviou foto.
  final String? fotoPerfil;

  const User({
    required this.idUsuario,
    required this.name,
    required this.email,
    required this.dataNascimento,
    required this.tipo,
    this.saldoPago = 0,
    this.saldoRecebido = 0,
    this.chavePix,
    this.fotoPerfil,
  });

  /// Passageiro paga caronas; motorista recebe. "Ambos" faz os dois.
  bool get pagaCaronas =>
      tipo == TipoUsuario.passageiro || tipo == TipoUsuario.ambos;
  bool get recebeCaronas =>
      tipo == TipoUsuario.motorista || tipo == TipoUsuario.ambos;
}
