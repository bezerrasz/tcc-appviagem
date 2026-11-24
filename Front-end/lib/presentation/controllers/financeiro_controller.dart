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
  int _geracao = 0;

  ResumoFinanceiro? get resumo => _resumo;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> carregar() async {
    if (_loading) return;
    final geracaoAtual = ++_geracao;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final novoResumo = await _repo.financeiro();
      if (geracaoAtual != _geracao) return;
      _resumo = novoResumo;
    } on AuthFailure catch (f) {
      if (geracaoAtual != _geracao) return;
      _error = f.message;
    } catch (_) {
      if (geracaoAtual != _geracao) return;
      _error = 'Não foi possível carregar seus saldos.';
    } finally {
      if (geracaoAtual == _geracao) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Esquece os dados do usuário anterior (logout). Não notifica por padrão
  /// para poder ser chamado com segurança no `dispose()` do `HomeShell`
  /// enquanto a árvore de widgets está bloqueada.
  void limpar({bool notificar = false}) {
    _geracao++;
    _resumo = null;
    _error = null;
    _loading = false;
    if (notificar) notifyListeners();
  }

  @override
  void dispose() {
    _geracao++;
    _avisos?.cancel();
    super.dispose();
  }
}
