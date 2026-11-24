import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:test_tcc/data/datasources/session_socket_service.dart';
import 'package:test_tcc/domain/entities/resumo_financeiro.dart';
import 'package:test_tcc/domain/failures/auth_failure.dart';
import 'package:test_tcc/domain/repositories/auth_repository.dart';

/// Saldos (pago/recebido) e valores a receber do usuário, exibidos na tela
/// Início. Recarrega ao abrir a aba e, ao vivo, quando o servidor avisa pelo
/// socket de sessão que algo mudou (carona concluída, comprovante importado).
class FinanceiroController extends ChangeNotifier {
  final AuthRepository _repo;
  StreamSubscription<void>? _avisos;

  FinanceiroController({
    required AuthRepository repo,
    required SessionSocketService sessionSocket,
  }) : _repo = repo {
    _avisos = sessionSocket.financeiroAtualizado.listen((_) => carregar());
  }

  ResumoFinanceiro? _resumo;
  bool _loading = false;
  String? _error;

  ResumoFinanceiro? get resumo => _resumo;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> carregar() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _resumo = await _repo.financeiro();
    } on AuthFailure catch (f) {
      _error = f.message;
    } catch (_) {
      _error = 'Não foi possível carregar seus saldos.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Esquece os dados do usuário anterior (logout).
  void limpar() {
    _resumo = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _avisos?.cancel();
    super.dispose();
  }
}
