import 'dart:async';

import 'package:flutter/foundation.dart';
// Infra de sessão (socket): a lista de grupos é também alimentada em tempo
// real quando o usuário é adicionado a um grupo por outra pessoa.
import 'package:test_tcc/data/datasources/session_socket_service.dart';
import 'package:test_tcc/domain/entities/grupo.dart';
import 'package:test_tcc/domain/failures/grupo_failure.dart';
import 'package:test_tcc/domain/usecases/criar_grupo_usecase.dart';
import 'package:test_tcc/domain/usecases/listar_grupos_usecase.dart';

/// Dono da lista de grupos do usuário. As telas observam este controller
/// em vez de fazer setState + chamada de usecase espalhados.
class GrupoController extends ChangeNotifier {
  final ListarGruposUseCase _listar;
  final CriarGrupoUseCase _criar;
  final SessionSocketService _sessionSocket;

  GrupoController({
    required ListarGruposUseCase listar,
    required CriarGrupoUseCase criar,
    required SessionSocketService sessionSocket,
  })  : _listar = listar,
        _criar = criar,
        _sessionSocket = sessionSocket;

  StreamSubscription<Grupo>? _sessionSub;

  List<Grupo> _grupos = const [];
  bool _loading = false;
  String? _error;
  bool _carregouUmaVez = false;

  List<Grupo> get grupos => _grupos;
  bool get loading => _loading;
  String? get error => _error;
  bool get carregouUmaVez => _carregouUmaVez;

  Future<void> carregar() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _grupos = await _listar();
    } on GrupoFailure catch (f) {
      _error = f.message;
    } finally {
      _loading = false;
      _carregouUmaVez = true;
      notifyListeners();
    }
  }

  /// Cria o grupo e o coloca no topo da lista.
  /// Repassa [GrupoFailure] para a tela exibir o erro no formulário.
  Future<Grupo> criar({required String nome}) async {
    final grupo = await _criar(nome: nome);
    _grupos = [grupo, ..._grupos];
    notifyListeners();
    return grupo;
  }

  /// Liga o realtime de sessão: passa a receber, ao vivo, grupos em que o
  /// usuário foi adicionado por outra pessoa. Chamar ao entrar na área
  /// autenticada (HomeShell).
  void iniciarSessaoRealtime() {
    _sessionSub?.cancel();
    _sessionSub = _sessionSocket.conectar().listen(
      _aoSerAdicionado,
      onError: (_) {},
    );
  }

  void encerrarSessaoRealtime() {
    _sessionSub?.cancel();
    _sessionSub = null;
    _sessionSocket.desconectar();
  }

  void _aoSerAdicionado(Grupo grupo) {
    if (_grupos.any((g) => g.idGrupo == grupo.idGrupo)) return; // dedupe
    _grupos = [grupo, ..._grupos];
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _sessionSocket.desconectar();
    super.dispose();
  }
}
