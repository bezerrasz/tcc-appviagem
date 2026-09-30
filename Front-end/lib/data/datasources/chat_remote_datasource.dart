import 'package:dio/dio.dart';
import 'package:test_tcc/core/config/api_config.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';
import 'package:test_tcc/domain/entities/carona_resumo.dart';
import 'package:test_tcc/domain/entities/membro_grupo.dart';
import 'package:test_tcc/domain/entities/mensagem.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/domain/entities/usuario_resumo.dart';
import 'package:test_tcc/domain/failures/grupo_failure.dart';

/// Acesso REST ao chat e aos membros de um grupo. O tempo-real (mensagens
/// novas) vem pelo [ChatSocketService]; aqui ficam histórico, membros e envio.
class ChatRemoteDatasource {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  ChatRemoteDatasource({required TokenStorage tokenStorage, Dio? dio})
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

  Future<List<MembroGrupo>> listarMembros(int idGrupo) async {
    try {
      final response = await _dio.get('/grupos/$idGrupo/membros');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => _membroFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Mensagem>> listarMensagens(int idGrupo) async {
    try {
      final response = await _dio.get('/grupos/$idGrupo/mensagens');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => mensagemFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Mensagem> enviar(int idGrupo, String conteudo) async {
    try {
      final response = await _dio.post(
        '/grupos/$idGrupo/mensagens',
        data: {'conteudo': conteudo},
      );
      return mensagemFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Motorista anuncia uma carona no grupo (com destino opcional). O backend
  /// cria a carona aberta e posta o card no chat; retorna a mensagem-card.
  Future<Mensagem> anunciarCarona(int idGrupo, {String? destino}) async {
    try {
      final response = await _dio.post(
        '/grupos/$idGrupo/caronas',
        data: {if (destino != null && destino.isNotEmpty) 'destino': destino},
      );
      return mensagemFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<UsuarioResumo>> buscarUsuarios(String termo) async {
    try {
      final response = await _dio.get(
        '/usuarios',
        queryParameters: {'busca': termo},
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => _usuarioFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<MembroGrupo> adicionarMembro(int idGrupo, int idUsuario) async {
    try {
      final response = await _dio.post(
        '/grupos/$idGrupo/membros',
        data: {'idUsuario': idUsuario},
      );
      return _membroFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  UsuarioResumo _usuarioFromJson(Map<String, dynamic> j) {
    return UsuarioResumo(
      idUsuario: j['idUsuario'] as int,
      nome: j['nome'] as String,
      email: j['email'] as String,
      tipo: TipoUsuario.values.firstWhere(
        (t) => t.name == j['tipo'],
        orElse: () => TipoUsuario.passageiro,
      ),
    );
  }

  MembroGrupo _membroFromJson(Map<String, dynamic> j) {
    return MembroGrupo(
      idUsuario: j['idUsuario'] as int,
      nome: j['nome'] as String,
      tipo: TipoUsuario.values.firstWhere(
        (t) => t.name == j['tipo'],
        orElse: () => TipoUsuario.passageiro,
      ),
      isAdm: j['isAdm'] == true || j['isAdm'] == 1,
    );
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
    // Para erros de regra (FORBIDDEN/NOT_FOUND/CONFLICT) a mensagem do backend
    // já é amigável e específica do contexto (membro, carona...). Usamos ela.
    if (body is Map &&
        (body['error'] == 'FORBIDDEN' ||
            body['error'] == 'NOT_FOUND' ||
            body['error'] == 'CONFLICT')) {
      final msg = body['message'];
      return GrupoOperationFailure(
        msg is String && msg.isNotEmpty ? msg : 'Operação não permitida.',
      );
    }
    return const GrupoOperationFailure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.');
  }
}

/// Converte o payload de mensagem do backend (REST e socket usam o mesmo
/// formato) em [Mensagem]. Exposto fora da classe para o socket reaproveitar.
Mensagem mensagemFromJson(Map<String, dynamic> j) {
  final caronaJson = j['carona'];
  return Mensagem(
    idMensagem: j['idMensagem'] as int,
    idGrupo: j['idGrupo'] as int,
    idAutor: j['idAutor'] as int,
    autorNome: (j['autorNome'] as String?) ?? 'Usuário',
    conteudo: j['conteudo'] as String,
    dataEnvio: DateTime.parse(j['dataEnvio'] as String).toLocal(),
    tipo: j['tipo'] == 'CARONA' ? TipoMensagem.carona : TipoMensagem.texto,
    carona: caronaJson is Map
        ? caronaFromJson(Map<String, dynamic>.from(caronaJson))
        : null,
  );
}

/// Converte o payload de carona (REST e socket usam o mesmo formato) em
/// [CaronaResumo]. Exposto fora da classe para o socket reaproveitar.
CaronaResumo caronaFromJson(Map<String, dynamic> j) {
  return CaronaResumo(
    idCarona: j['idCarona'] as int,
    status: statusCaronaFromString(j['status']),
    idMotorista: j['idMotorista'] as int?,
    motoristaNome: j['motoristaNome'] as String?,
    destino: j['destino'] as String?,
    lugares: (j['lugares'] as num?)?.toInt(),
    ocupadas: (j['ocupadas'] as num?)?.toInt() ?? 0,
    pendentes: (j['pendentes'] as num?)?.toInt() ?? 0,
    data: DateTime.parse(j['data'] as String).toLocal(),
  );
}
