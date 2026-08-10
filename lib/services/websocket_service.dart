import 'dart:async';
import 'socket_service.dart';
import 'logger_service.dart';

/// Serviço de tempo real para o chat.
///
/// Reaproveita a conexão Socket.io compartilhada (SocketService) em vez de
/// abrir uma conexão própria — só entra/sai da sala da conversa específica.
///
/// Estratégia dual:
///   1. Entra na sala via Socket.io compartilhado.
///   2. Se o WS não estiver conectado ainda, polling HTTP de 5s mantém
///      atualizado ATÉ o WS conectar.
///   3. Quando o WS confirma conexão, o polling é cancelado imediatamente.
///   4. Se o WS cair durante o uso, o polling retoma como fallback.
class ChatRealtimeService {
  String? _conversaId;
  Timer? _pollingTimer;
  void Function(Map<String, dynamic>)? _onWsMessageCallback;
  void Function(String leitorId)? _onMensagensLidasCallback;
  bool _wsConnected = false;
  Function(dynamic)? _novaMensagemListener;
  Function(dynamic)? _mensagensLidasListener;

  bool get isWsConnected => _wsConnected;

  Future<void> start({
    required String token,
    required String conversaId,
    required Future<List<Map<String, dynamic>>> Function() onFetch,
    required void Function(List<Map<String, dynamic>>) onUpdate,
    void Function(Map<String, dynamic>)? onWsMessage,
    void Function(String leitorId)? onMensagensLidas,
  }) async {
    _conversaId = conversaId;
    _onWsMessageCallback = onWsMessage;
    _onMensagensLidasCallback = onMensagensLidas;

    socketService.conectar(token);
    final socket = socketService.socket;

    if (socket == null) {
      loggerService.w('Socket indisponível — polling ativo');
      _startPolling(onFetch, onUpdate);
      return;
    }

    socket.emit('entrarChat', conversaId);
    loggerService.d('[ChatRealtime] emitindo entrarChat: $conversaId, socket conectado: ${socket.connected}');

    _wsConnected = socket.connected;

    if (_wsConnected) {
      // WS já conectado — não precisa de polling
      loggerService.i('Entrou na sala $conversaId (WS já conectado)');
    } else {
      // WS ainda conectando — polling como fallback até conectar
      loggerService.w('WS ainda conectando — polling ativo como fallback');
      _startPolling(onFetch, onUpdate);
    }

    _novaMensagemListener = (data) => _handleNovaMensagem(data);
    socket.on('novaMensagem', _novaMensagemListener!);

    _mensagensLidasListener = (data) => _handleMensagensLidas(data);
    socket.on('mensagensLidas', _mensagensLidasListener!);

    socket.on('connect', (_) {
      _wsConnected = true;
      _pollingTimer?.cancel(); // WS conectou — para o polling imediatamente
      loggerService.i('WebSocket conectado (conversa $conversaId)');
      // reenvia entrarChat: socket.io não lembra salas entre reconexões
      socket.emit('entrarChat', conversaId);
    });

    socket.on('disconnect', (_) {
      _wsConnected = false;
      // WS caiu — retoma polling como fallback
      loggerService.w('WebSocket desconectado — polling retomado');
      _startPolling(onFetch, onUpdate);
    });
  }

  void _handleNovaMensagem(dynamic data) {
    if (data is! Map) return;
    final mensagem = Map<String, dynamic>.from(data);

    final conversaDaMensagem =
        mensagem['conversaId'] ?? mensagem['conversa']?['id'];
    if (conversaDaMensagem != null && conversaDaMensagem != _conversaId) {
      return;
    }

    _onWsMessageCallback?.call(mensagem);
  }

  void _handleMensagensLidas(dynamic data) {
    if (data is! Map) return;
    final payload = Map<String, dynamic>.from(data);
    if (payload['conversaId'] != _conversaId) return;

    final leitorId = payload['leitorId'] as String?;
    if (leitorId != null) _onMensagensLidasCallback?.call(leitorId);
  }

  void _startPolling(
    Future<List<Map<String, dynamic>>> Function() onFetch,
    void Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_wsConnected) {
        // WS voltou — cancela o polling
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
    final socket = socketService.socket;
    if (socket != null && _conversaId != null) {
      socket.emit('sairChat', _conversaId);
      if (_novaMensagemListener != null) {
        socket.off('novaMensagem', _novaMensagemListener);
      }
      if (_mensagensLidasListener != null) {
        socket.off('mensagensLidas', _mensagensLidasListener);
      }
    }
    _wsConnected = false;
    loggerService.d('ChatRealtimeService parado');
  }
}