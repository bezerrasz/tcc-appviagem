import 'package:test_tcc/data/datasources/auth_remote_datasource.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remote;

  const AuthRepositoryImpl(this.remote);

  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) {
    return remote.login(identifier: identifier, password: password);
  }

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String cpf,
    required DateTime dataNascimento,
    required TipoUsuario tipo,
  }) {
    return remote.register(
      name: name,
      email: email,
      password: password,
      cpf: cpf,
      dataNascimento: dataNascimento,
      tipo: tipo,
    );
  }

  @override
  Future<User> atualizarPerfil({
    String? email,
    DateTime? dataNascimento,
    double? valor,
  }) {
    return remote.atualizarPerfil(
      email: email,
      dataNascimento: dataNascimento,
      valor: valor,
    );
  }

  @override
  Future<User> atualizarFoto({
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  }) {
    return remote.atualizarFoto(
      bytes: bytes,
      nomeArquivo: nomeArquivo,
      mimeType: mimeType,
    );
  }
}
