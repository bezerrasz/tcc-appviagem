import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:test_tcc/core/config/api_config.dart';
import 'package:test_tcc/data/datasources/chat_remote_datasource.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';
import 'package:test_tcc/domain/entities/carona_resumo.dart';
import 'package:test_tcc/domain/entities/mensagem.dart';

/// Conexão Socket.IO para o tempo-real do chat. Uma conexão por vez (entra
/// na sala de um grupo e emite as mensagens novas que chegam pelo socket).
///
/// Os pacotes são Dart puro (sem plugin nativo), então funcionam mesmo sem o
/// Dev Mode do Windows habilitado.
class ChatSocketService {
  final TokenStorage _tokenStorage;

  io.Socket? _socket;
  StreamController<Mensagem>? _controller;
  StreamController<CaronaResumo>? _caronaController;

  ChatSocketService({required TokenStorage tokenStorage})
    : _tokenStorage = tokenStorage;

  /// Caronas atualizadas (ex: aceitas) na sala conectada. Disponível após
  /// [conectar]; o controller da tela escuta para atualizar os cards.
  Stream<CaronaResumo> get caronaUpdates {
    final c = _caronaController ??= StreamController<CaronaResumo>.broadcast();
    return c.stream;
  }

  /// Conecta, entra na sala `grupo:<idGrupo>` e devolve o stream de mensagens
  /// novas. Erros de conexão não derrubam o app — o chat continua via REST.
  Stream<Mensagem> conectar(int idGrupo) {
    desconectar();

    final controller = StreamController<Mensagem>.broadcast();
    _controller = controller;
    final caronaController = StreamController<CaronaResumo>.broadcast();
    _caronaController = caronaController;

    final token = _tokenStorage.read() ?? '';
    final socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder()
          // Começa em polling e faz upgrade pra websocket. NÃO forçar só
          // websocket: se o upgrade falhar (proxy/firewall/rede do celular) a
          // conexão morre em silêncio enquanto o REST segue ok — e o chat
          // deixa de ser tempo-real sem aviso.
          .setTransports(['polling', 'websocket'])
          // Conexão própria (não multiplexar). Sem isto, como o SessionSocket
          // já conecta na MESMA URL/namespace, o lookup do socket.io devolveria
          // o socket dele (já conectado) — o onConnect abaixo nunca dispararia,
          // o 'grupo:entrar' nunca seria emitido e nada de tempo-real chegaria.
          .enableForceNew()
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'ngrok-skip-browser-warning': 'true'})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _log('conectado, entrando no grupo $idGrupo');
      socket.emit('grupo:entrar', idGrupo);
    });

    // Falhas de socket eram silenciosas: sem isto, "não é tempo real" não dá
    // nenhuma pista. Logado só em debug.
    socket.onConnectError((e) => _log('connect_error: $e'));
    socket.onError((e) => _log('error: $e'));
    socket.onDisconnect((reason) => _log('desconectado: $reason'));

    socket.on('mensagem:nova', (data) {
      if (data is Map && !controller.isClosed) {
        controller.add(mensagemFromJson(Map<String, dynamic>.from(data)));
      }
    });

    socket.on('carona:atualizada', (data) {
      if (data is Map && !caronaController.isClosed) {
        caronaController.add(caronaFromJson(Map<String, dynamic>.from(data)));
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
    _caronaController?.close();
    _caronaController = null;
  }

  void _log(String msg) {
    if (kDebugMode) developer.log(msg, name: 'ChatSocket');
  }
}
