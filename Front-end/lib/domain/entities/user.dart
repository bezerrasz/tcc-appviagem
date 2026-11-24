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

  /// Saldo em reais. Não há transação bancária: o próprio usuário informa
  /// quanto tem, pela tela Início.
  final double valor;

  /// Nome do arquivo da foto de perfil no servidor
  /// (`<idUsuario>-<ms>.<ext>`). Nulo quando o usuário não enviou foto.
  final String? fotoPerfil;

  const User({
    required this.idUsuario,
    required this.name,
    required this.email,
    required this.dataNascimento,
    required this.tipo,
    required this.valor,
    this.fotoPerfil,
  });
}
