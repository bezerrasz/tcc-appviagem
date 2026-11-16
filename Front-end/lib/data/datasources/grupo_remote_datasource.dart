import 'package:dio/dio.dart';
import 'package:test_tcc/core/config/api_config.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';
import 'package:test_tcc/domain/entities/grupo.dart';
import 'package:test_tcc/domain/failures/grupo_failure.dart';

class GrupoRemoteDatasource {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  GrupoRemoteDatasource({required TokenStorage tokenStorage, Dio? dio})
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

  Future<Grupo> criar({required String nome}) async {
    try {
      final response = await _dio.post(
        '/grupos',
        data: {'nome': nome},
      );
      return grupoFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Grupo>> listarMeus() async {
    try {
      final response = await _dio.get('/grupos');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => grupoFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  GrupoFailure _mapError(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['error'] == 'VALIDATION') {
      // 'details' so vem quando o erro e campo a campo. Validacao de regra
      // unica (ex: carro obrigatorio) vem so em 'message' — usar ela evita
      // mostrar um "Dados inválidos." generico que nao diz o que fazer.
      final details = body['details'];
      if (details is Map && details.isNotEmpty) {
        return GrupoOperationFailure(details.values.first.toString());
      }
      final msg = body['message'];
      return GrupoOperationFailure(
          msg is String && msg.isNotEmpty ? msg : 'Dados inválidos.');
    }
    return const GrupoOperationFailure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.');
  }
}

// MySQL pode devolver BOOLEAN como 0/1; normaliza pra bool.
bool _asBoolGrupo(dynamic v) => v == true || v == 1;

/// Converte o payload de grupo (REST e socket usam o mesmo formato) em [Grupo].
Grupo grupoFromJson(Map<String, dynamic> j) {
  return Grupo(
    idGrupo: j['idGrupo'] as int,
    nome: j['nome'] as String,
    isAdm: _asBoolGrupo(j['isAdm']),
  );
}
