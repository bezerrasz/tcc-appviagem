import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:test_tcc/core/config/app_constants.dart';
import 'package:test_tcc/data/datasources/session_socket_service.dart';
import 'package:test_tcc/domain/entities/carona_detalhe.dart';
import 'package:test_tcc/domain/entities/carona_resumo.dart';
import 'package:test_tcc/domain/failures/grupo_failure.dart';
import 'package:test_tcc/domain/repositories/carona_repository.dart';

/// Estado da tela de detalhe de uma carona. No novo fluxo o motorista anuncia
/// e os passageiros pedem para entrar; o motorista aprova/recusa cada pedido
/// (respeitando capacidade-1) e conclui/cancela a viagem. Escuta eventos
/// WebSocket da carona para manter custos, vagas e pagamentos sincronizados.
class CaronaDetalheController extends ChangeNotifier {
  final CaronaRepository _repo;
  final int idCarona;
  final int currentUserId;
  StreamSubscription<int>? _avisos;

  CaronaDetalheController({
    required CaronaRepository repo,
    required this.idCarona,
    required this.currentUserId,
    SessionSocketService? sessionSocket,
  }) : _repo = repo {
    _avisos = sessionSocket?.caronaAtualizada
        .where((id) => id == idCarona)
        .listen((_) => _recarregarSilencioso());
  }

  CaronaDetalhe? _detalhe;
  bool _loading = false;
  bool _agindo = false;
  bool _recarregandoSilencioso = false;
  bool _atualizacaoPendente = false;
  bool _disposed = false;
  // Passageiros com decisão ou revisão de pagamento em andamento.
  final Set<int> _decidindo = {};
  final Set<int> _confirmandoPagamento = {};
  final Set<int> _recusandoComprovante = {};
  String? _error;

  CaronaDetalhe? get detalhe => _detalhe;
  bool get loading => _loading;
  bool get agindo => _agindo;
  String? get error => _error;

  bool estaDecidindo(int idPassageiro) => _decidindo.contains(idPassageiro);
  bool estaConfirmandoPagamento(int idPassageiro) =>
      _confirmandoPagamento.contains(idPassageiro);
  bool estaRecusandoComprovante(int idPassageiro) =>
      _recusandoComprovante.contains(idPassageiro);
  bool estaProcessandoPagamento(int idPassageiro) =>
      estaConfirmandoPagamento(idPassageiro) ||
      estaRecusandoComprovante(idPassageiro);

  bool get souMotorista => _detalhe?.idMotorista == currentUserId;

  /// Status do meu pedido como passageiro (null se não pedi / sou o motorista).
  StatusPassageiro? get meuStatus {
    final d = _detalhe;
    if (d == null) return null;
    for (final p in d.passageiros) {
      if (p.idUsuario == currentUserId) return p.status;
    }
    return null;
  }

  /// Posso pedir: carona aberta, não sou o motorista e ainda não tenho pedido
  /// ativo (sem pedido, ou um anterior recusado que posso reenviar).
  bool get podePedir {
    final d = _detalhe;
    if (d == null || souMotorista) return false;
    if (d.status != StatusCarona.aberta) return false;
    final s = meuStatus;
    return s == null || s == StatusPassageiro.recusado;
  }

  /// Posso cancelar meu pedido: tenho pedido pendente ou aprovado, carona aberta.
  bool get podeCancelarPedido {
    final d = _detalhe;
    if (d == null || souMotorista) return false;
    if (d.status != StatusCarona.aberta) return false;
    final s = meuStatus;
    return s == StatusPassageiro.pendente || s == StatusPassageiro.aprovado;
  }

  bool get _aberta => _detalhe?.status == StatusCarona.aberta;

  /// Só o motorista informa os custos, e só enquanto a carona está aberta.
  bool get podeEditarCustos => _aberta && souMotorista;

  /// Só o motorista conclui, e só enquanto a carona está aberta.
  bool get podeConcluir => _aberta && souMotorista;

  /// Só o motorista cancela a carona, enquanto aberta.
  bool get podeCancelar => _aberta && souMotorista;

  Future<void> iniciar() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _detalhe = await _repo.detalhe(idCarona);
    } on GrupoFailure catch (f) {
      _error = f.message;
    } catch (_) {
      _error = 'Não foi possível carregar a carona.';
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _recarregarSilencioso() async {
    if (_disposed || _loading) return;
    if (_recarregandoSilencioso) {
      _atualizacaoPendente = true;
      return;
    }
    _recarregandoSilencioso = true;
    try {
      do {
        _atualizacaoPendente = false;
        final novo = await _repo.detalhe(idCarona);
        if (_disposed) return;
        _detalhe = novo;
        _error = null;
        notifyListeners();
      } while (_atualizacaoPendente && !_disposed);
    } catch (_) {
      // Falha silenciosa no tempo-real mantém o estado exibido.
    } finally {
      _recarregandoSilencioso = false;
    }
  }

  /// Passageiro pede para entrar.
  Future<bool> pedir() => _mutarDetalhe(() => _repo.pedir(idCarona));

  /// Passageiro cancela o próprio pedido.
  Future<bool> cancelarPedido() =>
      _mutarDetalhe(() => _repo.cancelarPedido(idCarona));

  /// Motorista aprova/recusa um passageiro. Mantém um spinner por linha.
  Future<bool> decidir({required int idPassageiro, required bool aprovar}) =>
      _executarAcaoPassageiro(
        emAndamento: _decidindo,
        idPassageiro: idPassageiro,
        acao: () => _repo.decidir(
          idCarona: idCarona,
          idPassageiro: idPassageiro,
          aprovar: aprovar,
        ),
        erroPadrao: 'Não foi possível decidir o pedido.',
      );

  /// Motorista informa km rodados e valor do litro; o backend devolve o
  /// detalhe já com o total da viagem e o rateio por passageiro.
  Future<bool> atualizarCustos({
    required double kmRodados,
    required double valorLitro,
  }) =>
      _mutarDetalhe(() => _repo.atualizarCustos(
            idCarona: idCarona,
            kmRodados: kmRodados,
            valorLitro: valorLitro,
          ));

  /// Conclui: o backend fixa o valor de cada passageiro e libera a chave Pix,
  /// por isso o detalhe inteiro é recarregado (não só o status).
  Future<bool> concluir() => _mutarDetalhe(() => _repo.concluir(idCarona));
  Future<bool> cancelar() => _agirStatus(() => _repo.cancelar(idCarona));

  /// Meu vínculo nesta carona como passageiro (null se não pedi / sou o
  /// motorista).
  PassageiroCarona? get meuVinculo {
    final d = _detalhe;
    if (d == null) return null;
    for (final p in d.passageiros) {
      if (p.idUsuario == currentUserId) return p;
    }
    return null;
  }

  /// Posso importar o comprovante: carona concluída, fui aprovado, tenho
  /// valor a pagar e ainda não enviei o comprovante.
  bool get podeEnviarComprovante {
    final pg = meuVinculo?.pagamento;
    return _detalhe?.status == StatusCarona.concluida &&
        meuStatus == StatusPassageiro.aprovado &&
        pg != null &&
        !pg.pago &&
        !pg.temComprovante &&
        pg.valor > 0;
  }

  /// Envia o comprovante do Pix (imagem ou PDF até 5 MB). O formato vem da
  /// assinatura do arquivo, não da extensão.
  Future<bool> enviarComprovante(List<int> bytes) async {
    if (bytes.length > AppConstants.comprovanteTamanhoMax) {
      _error = 'O comprovante deve ter no máximo 5 MB.';
      notifyListeners();
      return false;
    }
    final tipo = _tipoComprovante(bytes);
    if (tipo == null) {
      _error = 'Formato inválido. Envie uma imagem (JPG, PNG, WEBP) ou PDF.';
      notifyListeners();
      return false;
    }
    return _mutarDetalhe(() => _repo.enviarComprovante(
          idCarona: idCarona,
          bytes: bytes,
          nomeArquivo: 'comprovante${tipo.ext}',
          mimeType: tipo.mime,
        ));
  }

  /// Motorista confirma o recebimento do Pix de um passageiro que já enviou o
  /// comprovante, liberando a atualização atômica dos saldos.
  Future<bool> confirmarPagamento(int idPassageiro) {
    if (estaProcessandoPagamento(idPassageiro)) return Future.value(false);
    return _executarAcaoPassageiro(
      emAndamento: _confirmandoPagamento,
      idPassageiro: idPassageiro,
      acao: () => _repo.confirmarPagamento(
        idCarona: idCarona,
        idPassageiro: idPassageiro,
      ),
      erroPadrao: 'Não foi possível confirmar o pagamento.',
    );
  }

  /// Motorista recusa um comprovante errado/ilegível para destravar novo upload.
  Future<bool> recusarComprovante(int idPassageiro) {
    if (estaProcessandoPagamento(idPassageiro)) return Future.value(false);
    return _executarAcaoPassageiro(
      emAndamento: _recusandoComprovante,
      idPassageiro: idPassageiro,
      acao: () => _repo.recusarComprovante(
        idCarona: idCarona,
        idPassageiro: idPassageiro,
      ),
      erroPadrao: 'Não foi possível recusar o comprovante.',
    );
  }

  Future<bool> _executarAcaoPassageiro({
    required Set<int> emAndamento,
    required int idPassageiro,
    required Future<CaronaDetalhe> Function() acao,
    required String erroPadrao,
  }) async {
    if (emAndamento.contains(idPassageiro)) return false;
    emAndamento.add(idPassageiro);
    notifyListeners();
    try {
      _detalhe = await acao();
      _error = null;
      return true;
    } on GrupoFailure catch (f) {
      _error = f.message;
      return false;
    } catch (_) {
      _error = erroPadrao;
      return false;
    } finally {
      emAndamento.remove(idPassageiro);
      if (!_disposed) notifyListeners();
    }
  }

  /// Baixa o comprovante de um passageiro. Null em falha ([error] explica).
  Future<({Uint8List bytes, String contentType})?> baixarComprovante(
    int idPassageiro,
  ) async {
    try {
      final arquivo = await _repo.baixarComprovante(
        idCarona: idCarona,
        idPassageiro: idPassageiro,
      );
      _error = null;
      return arquivo;
    } on GrupoFailure catch (f) {
      _error = f.message;
      return null;
    } catch (_) {
      _error = 'Não foi possível abrir o comprovante.';
      return null;
    }
  }

  /// JPEG FF D8 FF; PNG 89 50 4E 47; WEBP "RIFF"...."WEBP"; PDF "%PDF-".
  ({String mime, String ext})? _tipoComprovante(List<int> b) {
    String ascii(int ini, int fim) =>
        b.length >= fim ? String.fromCharCodes(b.sublist(ini, fim)) : '';
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return (mime: 'image/jpeg', ext: '.jpg');
    }
    if (b.length >= 4 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return (mime: 'image/png', ext: '.png');
    }
    if (ascii(0, 4) == 'RIFF' && ascii(8, 12) == 'WEBP') {
      return (mime: 'image/webp', ext: '.webp');
    }
    if (ascii(0, 5) == '%PDF-') {
      return (mime: 'application/pdf', ext: '.pdf');
    }
    return null;
  }

  // Ação que devolve o detalhe atualizado (pedir, custos, concluir,
  // comprovante...). Usa o flag
  // global [agindo] para desabilitar a barra de ações enquanto roda.
  Future<bool> _mutarDetalhe(Future<CaronaDetalhe> Function() acao) async {
    if (_agindo) return false;
    _agindo = true;
    notifyListeners();
    try {
      _detalhe = await acao();
      _error = null;
      return true;
    } on GrupoFailure catch (f) {
      _error = f.message;
      return false;
    } catch (_) {
      _error = 'Não foi possível concluir a ação.';
      return false;
    } finally {
      _agindo = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Ação que devolve só o novo status (concluir/cancelar).
  Future<bool> _agirStatus(Future<StatusCarona> Function() acao) async {
    if (_agindo || _detalhe == null) return false;
    _agindo = true;
    notifyListeners();
    try {
      final novoStatus = await acao();
      _detalhe = _detalhe!.copyWith(status: novoStatus);
      _error = null;
      return true;
    } on GrupoFailure catch (f) {
      _error = f.message;
      return false;
    } catch (_) {
      _error = 'Não foi possível concluir a ação.';
      return false;
    } finally {
      _agindo = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _avisos?.cancel();
    super.dispose();
  }
}
