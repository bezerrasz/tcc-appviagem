import 'package:test_tcc/domain/entities/user.dart';

abstract class AuthRepository {
  Future<User> login({required String identifier, required String password});

  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String cpf,
    required DateTime dataNascimento,
    required TipoUsuario tipo,
  });

  Future<User> atualizarPerfil({
    String? email,
    DateTime? dataNascimento,
    double? valor,
  });

  Future<User> atualizarFoto({
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  });
}
