import 'package:test_tcc/domain/entities/resumo_financeiro.dart';
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
    String? chavePix,
  });

  Future<ResumoFinanceiro> financeiro();

  Future<User> atualizarFoto({
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  });
}
