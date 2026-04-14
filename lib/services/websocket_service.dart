import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';
import 'logger_service.dart';

/// Serviço de tempo real para o chat.
///
/// Estratégia dual:
///   1. Tenta conectar via WebSocket ao servidor.
///   2. Se a conexão falhar ou o servidor não suportar WS nesse path,
///      polling HTTP de 5 s mantém as mensagens atualizadas.
///   3. Quando o WS conecta com sucesso o polling é pausado automaticamente.
class ChatRealtimeService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pollingTimer;
  Timer? _pingTimer;
  bool _wsConnected = false;

  bool get isWsConnected => _wsConnected;

  /// Inicia o serviço para a [conversaId] informada.
  ///
  /// - [token]: JWT do usuário.
  /// - [onFetch]: função que busca a lista de mensagens via HTTP.
  /// - [onUpdate]: callback chamado com a lista atualizada a cada poll.
  /// - [onWsMessage]: callback opcional para mensagens recebidas via WS.
  Future<void> start({
    required String token,
    required String conversaId,
    required Future<List<Map<String, dynamic>>> Function() onFetch,
    required void Function(List<Map<String, dynamic>>) onUpdate,
    void Function(Map<String, dynamic>)? onWsMessage,
  }) async {
    _tryWebSocket(token, conversaId, onWsMessage);
    _startPolling(onFetch, onUpdate);
  }

  void _tryWebSocket(
    String token,
    String conversaId,
    void Function(Map<String, dynamic>)? onWsMessage,
  ) {
    try {
      // Tenta raw WebSocket. Se o servidor usar Socket.IO,
      // a conexão será recusada e o polling continuará ativo.
      final uri = Uri.parse(
        '${ApiConfig.wsUrl}/chat?token=$token&conversaId=$conversaId',
      );

      _channel = WebSocketChannel.connect(uri);

      _channel!.ready.timeout(const Duration(seconds: 6)).then((_) {
        _wsConnected = true;
        _pollingTimer?.cancel();
        loggerService.i('WebSocket conectado (conversa $conversaId)');

        _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
          if (_wsConnected) {
            try {
              _channel?.sink.add(jsonEncode({'event': 'ping'}));
            } catch (_) {}
          }
        });
      }).catchError((e) {
        loggerService.w('WebSocket indisponível — polling ativo: $e');
        _wsConnected = false;
      });

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String);
            if (decoded is Map<String, dynamic>) {
              onWsMessage?.call(decoded);
            }
          } catch (_) {}
        },
        onError: (e) {
          loggerService.w('Erro no stream WS: $e');
          _wsConnected = false;
        },
        onDone: () {
          loggerService.d('WebSocket stream encerrado');
          _wsConnected = false;
        },
        cancelOnError: true,
      );
    } catch (e) {
      loggerService.w('Não foi possível inicializar WebSocket: $e');
    }
  }

  void _startPolling(
    Future<List<Map<String, dynamic>>> Function() onFetch,
    void Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_wsConnected) {
        _pollingTimer?.cancel();
        return;
      }
      try {
        final msgs = await onFetch();
        onUpdate(msgs);
      } catch (_) {}
    });
  }

  void stop() {
    _pollingTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _wsConnected = false;
    loggerService.d('ChatRealtimeService parado');
  }
}
