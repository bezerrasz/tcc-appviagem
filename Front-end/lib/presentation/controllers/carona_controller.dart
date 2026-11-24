import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:test_tcc/data/datasources/session_socket_service.dart';
import 'package:test_tcc/domain/entities/carona_item.dart';
import 'package:test_tcc/domain/failures/grupo_failure.dart';
import 'package:test_tcc/domain/repositories/carona_repository.dart';

/// Dono da lista "Minhas caronas". As telas observam este controller e
/// recebem atualizações em tempo real via WebSocket de sessão.
class CaronaController extends ChangeNotifier {
  final CaronaRepository _repo;
  StreamSubscription<int>? _avisos;

  CaronaController(this._repo, {SessionSocketService? sessionSocket}) {
    _avisos = sessionSocket?.caronaAtualizada.listen(
      (_) => _recarregarSilencioso(),
    );
  }

  List<CaronaItem> _caronas = const [];
  bool _loading = false;
  bool _atualizandoSilencioso = false;
  bool _disposed = false;
  String? _error;
  bool _carregouUmaVez = false;

  List<CaronaItem> get caronas => _caronas;
  bool get loading => _loading;
  String? get error => _error;
  bool get carregouUmaVez => _carregouUmaVez;

  Future<void> carregar() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _caronas = await _repo.listarMinhas();
    } on GrupoFailure catch (f) {
      _error = f.message;
    } catch (_) {
      _error = 'Não foi possível carregar suas caronas.';
    } finally {
      _loading = false;
      _carregouUmaVez = true;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _recarregarSilencioso() async {
    if (_disposed || !_carregouUmaVez || _loading || _atualizandoSilencioso) {
      return;
    }
    _atualizandoSilencioso = true;
    try {
      final lista = await _repo.listarMinhas();
      if (_disposed) return;
      _caronas = lista;
      _error = null;
      notifyListeners();
    } catch (_) {
      // Falha silenciosa em tempo real mantém a lista já carregada.
    } finally {
      _atualizandoSilencioso = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _avisos?.cancel();
    super.dispose();
  }
}
