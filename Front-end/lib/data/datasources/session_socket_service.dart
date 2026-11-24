import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:test_tcc/core/config/api_config.dart';
import 'package:test_tcc/data/datasources/grupo_remote_datasource.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';
import 'package:test_tcc/domain/entities/grupo.dart';

/// Socket de SESSÃO: vive enquanto o usuário está logado (conecta ao entrar
/// no app autenticado, desconecta no logout) — diferente do socket de chat,
/// que é por grupo.
///
/// O servidor coloca este socket na sala `user:<id>` no handshake, então
/// recebemos eventos direcionados só a este usuário (ex: foi adicionado a um
/// grupo) sem precisar estar na sala daquele grupo.
class SessionSocketService {
  final TokenStorage _tokenStorage;

  io.Socket? _socket;
  StreamController<Grupo>? _controller;

  // Avisos de que os saldos/pendências do usuário mudaram (carona concluída ou
  // comprovante importado). Stream de vida longa: quem escuta não precisa se
  // reinscrever a cada (re)conexão.
  final StreamController<void> _financeiro = StreamController<void>.broadcast();
  // IDs de caronas atualizadas em tempo real para manter a tela de detalhes e
  // a listagem "Minhas caronas" sincronizadas sem recarga manual.
  final StreamController<int> _caronaAtualizada =
      StreamController<int>.broadcast();

  SessionSocketService({required TokenStorage tokenStorage})
    : _tokenStorage = tokenStorage;

  Stream<void> get financeiroAtualizado => _financeiro.stream;
  Stream<int> get caronaAtualizada => _caronaAtualizada.stream;

  /// Conecta e devolve o stream de grupos em que o usuário foi adicionado.
  Stream<Grupo> conectar() {
    desconectar();

    final controller = StreamController<Grupo>.broadcast();
    _controller = controller;

    final token = _tokenStorage.read() ?? '';
    final socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder()
          // Polling com upgrade pra websocket (ver nota no ChatSocketService):
          // forçar só websocket derruba o tempo-real em silêncio em redes que
          // bloqueiam o upgrade.
          .setTransports(['polling', 'websocket'])
          // Conexão própria (não multiplexar) para não colidir com o socket de
          // chat, que conecta na mesma URL/namespace. Ver nota no ChatSocket.
          .enableForceNew()
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'ngrok-skip-browser-warning': 'true'})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) => _log('conectado (sessão)'));
    socket.onConnectError((e) => _log('connect_error: $e'));
    socket.onError((e) => _log('error: $e'));
    socket.onDisconnect((reason) => _log('desconectado: $reason'));

    socket.on('grupo:adicionado', (data) {
      if (data is Map && !controller.isClosed) {
        controller.add(grupoFromJson(Map<String, dynamic>.from(data)));
      }
    });

    socket.on('financeiro:atualizado', (_) => _financeiro.add(null));

    socket.on('carona:atualizada', (data) {
      if (data is Map) {
        final rawId = data['idCarona'];
        final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
        if (id != null && !_caronaAtualizada.isClosed) {
          _caronaAtualizada.add(id);
        }
      }
    });

    socket.connect();
    return controller.stream;
  }

  void desconectar() {
    final socket = _socket;
    if (socket != null) {
      socket.clearListeners();
      socket.dispose();
      _socket = null;
    }
    _controller?.close();
    _controller = null;
  }

  void _log(String msg) {
    if (kDebugMode) developer.log(msg, name: 'SessionSocket');
  }
}
