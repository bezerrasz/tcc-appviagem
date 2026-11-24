import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:test_tcc/core/config/api_config.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';
import 'package:test_tcc/domain/entities/carona_detalhe.dart';
import 'package:test_tcc/domain/entities/carona_item.dart';
import 'package:test_tcc/domain/entities/carona_resumo.dart';
import 'package:test_tcc/domain/failures/grupo_failure.dart';

/// Acesso REST às caronas do usuário (lista + detalhe).
class CaronaRemoteDatasource {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  CaronaRemoteDatasource({required TokenStorage tokenStorage, Dio? dio})
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

  Future<List<CaronaItem>> listarMinhas() async {
    try {
      final response = await _dio.get('/caronas');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => _itemFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CaronaDetalhe> detalhe(int idCarona) async {
    try {
      final response = await _dio.get('/caronas/$idCarona');
      return _detalheFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Passageiro pede para entrar na carona. Retorna o detalhe atualizado.
  Future<CaronaDetalhe> pedir(int idCarona) async {
    try {
      final response = await _dio.post('/caronas/$idCarona/pedir');
      return _detalheFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Passageiro cancela o próprio pedido. Retorna o detalhe atualizado.
  Future<CaronaDetalhe> cancelarPedido(int idCarona) async {
    try {
      final response = await _dio.delete('/caronas/$idCarona/pedir');
      return _detalheFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Motorista aprova/recusa o pedido de um passageiro. Retorna o detalhe.
  Future<CaronaDetalhe> decidir({
    required int idCarona,
    required int idPassageiro,
    required bool aprovar,
  }) async {
    try {
      final response = await _dio.patch(
        '/caronas/$idCarona/passageiros/$idPassageiro',
        data: {'acao': aprovar ? 'aprovar' : 'recusar'},
      );
      return _detalheFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Motorista informa km rodados + valor do litro (base do rateio da viagem).
  /// Retorna o detalhe com os custos recalculados.
  Future<CaronaDetalhe> atualizarCustos({
    required int idCarona,
    required double kmRodados,
    required double valorLitro,
  }) async {
    try {
      final response = await _dio.patch(
        '/caronas/$idCarona/custos',
        data: {'kmRodados': kmRodados, 'valorLitro': valorLitro},
      );
      return _detalheFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Conclui a carona (só motorista). Retorna o detalhe completo: na
  /// conclusão o valor de cada passageiro é fixado e a chave Pix liberada.
  Future<CaronaDetalhe> concluir(int idCarona) async {
    try {
      final response = await _dio.patch('/caronas/$idCarona/concluir');
      return _detalheFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Passageiro importa o comprovante do Pix (imagem ou PDF). O backend dá a
  /// pendência como paga e atualiza os saldos. Retorna o detalhe atualizado.
  Future<CaronaDetalhe> enviarComprovante({
    required int idCarona,
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  }) async {
    try {
      final form = FormData.fromMap({
        'comprovante': MultipartFile.fromBytes(
          bytes,
          filename: nomeArquivo,
          contentType: DioMediaType.parse(mimeType),
        ),
      });
      final response = await _dio.post(
        '/caronas/$idCarona/comprovante',
        data: form,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return _detalheFromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Baixa o comprovante de um passageiro (motorista ou o próprio passageiro).
  Future<({Uint8List bytes, String contentType})> baixarComprovante({
    required int idCarona,
    required int idPassageiro,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        '/caronas/$idCarona/passageiros/$idPassageiro/comprovante',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      return (
        bytes: Uint8List.fromList(response.data ?? const []),
        contentType:
            response.headers.value('content-type') ?? 'application/octet-stream',
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Cancela a carona (só motorista). Retorna o novo status.
  Future<StatusCarona> cancelar(int idCarona) =>
      _patchStatus('/caronas/$idCarona/cancelar');

  Future<StatusCarona> _patchStatus(String path) async {
    try {
      final response = await _dio.patch(path);
      final data = response.data as Map<String, dynamic>;
      return statusCaronaFromString(data['status']);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  CaronaItem _itemFromJson(Map<String, dynamic> j) {
    return CaronaItem(
      idCarona: j['idCarona'] as int,
      idGrupo: j['idGrupo'] as int,
      grupoNome: (j['grupoNome'] as String?) ?? 'Grupo',
      status: statusCaronaFromString(j['status']),
      data: DateTime.parse(j['data'] as String).toLocal(),
      papel: j['papel'] == 'motorista'
          ? PapelCarona.motorista
          : PapelCarona.passageiro,
      motoristaNome: j['motoristaNome'] as String?,
      destino: j['destino'] as String?,
      lugares: (j['lugares'] as num?)?.toInt(),
      ocupadas: (j['ocupadas'] as num?)?.toInt() ?? 0,
      meuStatus: j['meuStatus'] == null
          ? null
          : statusPassageiroFromString(j['meuStatus']),
    );
  }

  CaronaDetalhe _detalheFromJson(Map<String, dynamic> j) {
    final motorista = j['motorista'];
    final carro = j['carro'];
    final passageiros = (j['passageiros'] as List<dynamic>? ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .map((p) => PassageiroCarona(
              idUsuario: p['idUsuario'] as int,
              nome: (p['nome'] as String?) ?? 'Usuário',
              status: statusPassageiroFromString(p['status']),
              pagamento: _pagamentoFromJson(p['pagamento']),
            ))
        .toList(growable: false);
    return CaronaDetalhe(
      idCarona: j['idCarona'] as int,
      idGrupo: j['idGrupo'] as int,
      grupoNome: (j['grupoNome'] as String?) ?? 'Grupo',
      status: statusCaronaFromString(j['status']),
      data: DateTime.parse(j['data'] as String).toLocal(),
      destino: j['destino'] as String?,
      idMotorista: motorista is Map ? motorista['idUsuario'] as int? : null,
      motoristaNome: motorista is Map ? motorista['nome'] as String? : null,
      chavePixMotorista:
          motorista is Map ? motorista['chavePix'] as String? : null,
      carro: carro is Map
          ? CarroCarona(
              idCarro: carro['idCarro'] as int,
              marca: carro['marca'] as String,
              modelo: carro['modelo'] as String,
              anoFabricacao: carro['anoFabricacao'] as int,
              cor: carro['cor'] as String,
              placa: carro['placa'] as String,
              capacidade: (carro['capacidade'] as num?)?.toInt() ?? 0,
            )
          : null,
      lugares: (j['lugares'] as num?)?.toInt(),
      ocupadas: (j['ocupadas'] as num?)?.toInt() ?? 0,
      passageiros: passageiros,
      custos: _custosFromJson(j['custos']),
    );
  }

  PagamentoPassageiro? _pagamentoFromJson(Object? raw) {
    if (raw is! Map) return null;
    final data = raw['dataPagamento'] as String?;
    return PagamentoPassageiro(
      valor: (raw['valor'] as num?)?.toDouble() ?? 0,
      pago: raw['pago'] == true,
      dataPagamento: data == null ? null : DateTime.parse(data).toLocal(),
      temComprovante: raw['temComprovante'] == true,
    );
  }

  /// Null quando o motorista ainda não informou km + valor do litro.
  CustosCarona? _custosFromJson(Object? raw) {
    if (raw is! Map) return null;
    double num0(String campo) => (raw[campo] as num?)?.toDouble() ?? 0;
    return CustosCarona(
      kmRodados: num0('kmRodados'),
      valorLitro: num0('valorLitro'),
      consumoMedio: num0('consumoMedio'),
      litros: num0('litros'),
      combustivel: num0('combustivel'),
      taxaPorKm: num0('taxaPorKm'),
      taxa: num0('taxa'),
      total: num0('total'),
      passageiros: (raw['passageiros'] as num?)?.toInt() ?? 0,
      valorPorPassageiro: (raw['valorPorPassageiro'] as num?)?.toDouble(),
    );
  }

  GrupoFailure _mapError(DioException e) {
    final body = e.response?.data;
    if (body is Map &&
        (body['error'] == 'FORBIDDEN' ||
            body['error'] == 'NOT_FOUND' ||
            body['error'] == 'CONFLICT' ||
            body['error'] == 'VALIDATION')) {
      final msg = body['message'];
      return GrupoOperationFailure(
        msg is String && msg.isNotEmpty ? msg : 'Operação não permitida.',
      );
    }
    return const GrupoOperationFailure(
        'Não foi possível conectar ao servidor. Verifique sua conexão.');
  }
}
