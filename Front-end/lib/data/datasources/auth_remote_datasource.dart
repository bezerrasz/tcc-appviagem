import 'package:dio/dio.dart';
import 'package:test_tcc/core/config/api_config.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';
import 'package:test_tcc/domain/entities/resumo_financeiro.dart';
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

  /// Atualiza o próprio perfil (e-mail, data de nascimento e/ou chave Pix).
  /// Envia só os campos informados (chave Pix vazia remove a chave). Retorna o
  /// usuário com os dados atualizados.
  Future<User> atualizarPerfil({
    String? email,
    DateTime? dataNascimento,
    String? chavePix,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (email != null) data['email'] = email;
      if (dataNascimento != null) {
        data['dataNascimento'] =
            dataNascimento.toIso8601String().substring(0, 10);
      }
      if (chavePix != null) data['chavePix'] = chavePix;
      final response = await _dio.patch('/usuarios/me', data: data);
      return _userFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapAuthRequestError(e);
    }
  }

  /// Envia a nova foto de perfil (multipart, campo "foto"). O backend salva o
  /// arquivo como `<idUsuario>-<ms>.<ext>` e devolve o usuário atualizado.
  Future<User> atualizarFoto({
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  }) async {
    try {
      final form = FormData.fromMap({
        'foto': MultipartFile.fromBytes(
          bytes,
          filename: nomeArquivo,
          contentType: DioMediaType.parse(mimeType),
        ),
      });
      final response = await _dio.put(
        '/usuarios/me/foto',
        data: form,
        // Upload de imagem pode levar mais que os 8s padrão em rede lenta.
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return _userFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapAuthRequestError(e);
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
      saldoPago: (u['saldoPago'] as num?)?.toDouble() ?? 0,
      saldoRecebido: (u['saldoRecebido'] as num?)?.toDouble() ?? 0,
      chavePix: u['chavePix'] as String?,
      fotoPerfil: u['fotoPerfil'] as String?,
    );
  }

  /// Saldos pago/recebido e os pagamentos pendentes das caronas que o usuário
  /// conduziu (tela Início).
  Future<ResumoFinanceiro> financeiro() async {
    try {
      final response = await _dio.get('/usuarios/me/financeiro');
      final j = response.data as Map<String, dynamic>;
      double n(Object? v) => (v as num?)?.toDouble() ?? 0;
      return ResumoFinanceiro(
        saldoPago: n(j['saldoPago']),
        saldoRecebido: n(j['saldoRecebido']),
        totalAReceber: n(j['totalAReceber']),
        totalGeral: n(j['totalGeral']),
        aReceber: (j['aReceber'] as List<dynamic>? ?? const [])
            .map((e) => e as Map<String, dynamic>)
            .map((i) => ValorAReceber(
                  idCarona: i['idCarona'] as int,
                  data: DateTime.parse(i['data'] as String).toLocal(),
                  destino: i['destino'] as String?,
                  grupoNome: i['grupoNome'] as String?,
                  idPassageiro: i['idPassageiro'] as int,
                  passageiroNome:
                      (i['passageiroNome'] as String?) ?? 'Passageiro',
                  valor: n(i['valor']),
                ))
            .toList(growable: false),
      );
    } on DioException catch (e) {
      throw _mapAuthRequestError(e);
    }
  }

  AuthFailure _mapLoginError(DioException e) {
    if (e.response?.statusCode == 401) {
      return const InvalidCredentialsFailure();
    }
    return const RegistrationFailure(
        'Nao foi possivel conectar ao servidor. Verifique sua conexao.');
  }

  AuthFailure _mapAuthRequestError(DioException e) {
    final body = e.response?.data;
    if (body is Map &&
        (body['error'] == 'CONFLICT' || body['error'] == 'VALIDATION')) {
      return _mapRegisterError(e);
    }
    if (e.response?.statusCode == 401) {
      final msg = body is Map ? body['message'] : null;
      return RegistrationFailure(
        msg is String && msg.isNotEmpty
            ? msg
            : 'Sessão expirada. Faça login novamente.',
      );
    }
    if (body is Map) {
      final msg = body['message'];
      if (msg is String && msg.isNotEmpty) {
        return RegistrationFailure(msg);
      }
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
