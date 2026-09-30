import 'package:dio/dio.dart';
import 'package:test_tcc/core/config/api_config.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/domain/failures/auth_failure.dart';

class AuthRemoteDatasource {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  AuthRemoteDatasource({required TokenStorage tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              headers: {
              'ngrok-skip-browser-warning': 'true',
              },
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokenStorage.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'identificador': identifier, 'senha': password},
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final u = data['usuario'] as Map<String, dynamic>;

      _tokenStorage.save(token);

      return _userFromJson(u);
    } on DioException catch (e) {
      throw _mapLoginError(e);
    }
  }

  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String cpf,
    required DateTime dataNascimento,
    required TipoUsuario tipo,
  }) async {
    try {
      final response = await _dio.post(
        '/usuarios',
        data: {
          'nome': name,
          'email': email,
          'senha': password,
          'cpf': cpf,
          'dataNascimento':
              dataNascimento.toIso8601String().substring(0, 10),
          'tipo': tipo.name,
        },
      );
      return _userFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapRegisterError(e);
    }
  }

  /// Atualiza o próprio perfil (e-mail, data de nascimento e/ou saldo). Envia
  /// só os campos informados. Retorna o usuário com os dados atualizados.
  Future<User> atualizarPerfil({
    String? email,
    DateTime? dataNascimento,
    double? valor,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (email != null) data['email'] = email;
      if (dataNascimento != null) {
        data['dataNascimento'] =
            dataNascimento.toIso8601String().substring(0, 10);
      }
      if (valor != null) data['valor'] = valor;
      final response = await _dio.patch('/usuarios/me', data: data);
      return _userFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapRegisterError(e);
    }
  }

  /// O backend devolve o usuário no mesmo formato no login, no cadastro e na
  /// edição de perfil.
  User _userFromJson(Map<String, dynamic> u) {
    return User(
      idUsuario: u['idUsuario'] as int,
      name: u['nome'] as String,
      email: u['email'] as String,
      dataNascimento: DateTime.parse(u['dataNascimento'] as String),
      tipo: TipoUsuario.values.firstWhere((t) => t.name == u['tipo']),
      valor: (u['valor'] as num?)?.toDouble() ?? 0,
    );
  }

  AuthFailure _mapLoginError(DioException e) {
    if (e.response?.statusCode == 401) {
      return const InvalidCredentialsFailure();
    }
    return const RegistrationFailure(
        'Nao foi possivel conectar ao servidor. Verifique sua conexao.');
  }

  AuthFailure _mapRegisterError(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['error'] == 'CONFLICT') {
      final campo = (body['details'] as Map?)?['campo'];
      if (campo == 'email') return const EmailInUseFailure();
      if (campo == 'cpf') return const CpfInUseFailure();
      if (campo == 'nome') return const NameInUseFailure();
    }
    if (body is Map && body['error'] == 'VALIDATION') {
      // 'details' so vem quando o erro e campo a campo; validacao de regra
      // unica vem so em 'message'. Sem esse fallback o usuario recebe um
      // "Dados invalidos." generico que nao diz o que fazer.
      final details = body['details'];
      if (details is Map && details.isNotEmpty) {
        return RegistrationFailure(details.values.first.toString());
      }
      final msg = body['message'];
      return RegistrationFailure(
          msg is String && msg.isNotEmpty ? msg : 'Dados invalidos.');
    }
    return const RegistrationFailure(
        'Nao foi possivel conectar ao servidor. Verifique sua conexao.');
  }
}
