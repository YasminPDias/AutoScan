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
///
/// ATENÇÃO ao ciclo de vida: o socket é um SINGLETON que vive enquanto o app
/// vive. Todo listener registrado aqui precisa ser removido em [stop] com a
/// MESMA referência de função — `socket.off('connect')` sem referência
/// removeria também os handlers do SocketService.
class ChatRealtimeService {
  String? _conversaId;
  Timer? _pollingTimer;

  /// Barreira de ciclo de vida.
  ///
  /// Sem isto, um callback assíncrono agendado antes do [stop] continua
  /// executando depois — e o polling volta a rodar para uma conversa que o
  /// usuário já fechou.
  bool _ativo = false;

  bool _wsConnected = false;

  Function(dynamic)? _novaMensagemListener;
  Function(dynamic)? _mensagensLidasListener;
  Function(dynamic)? _connectListener;
  Function(dynamic)? _disconnectListener;

  void Function(Map<String, dynamic>)? _onWsMessageCallback;
  void Function(String leitorId)? _onMensagensLidasCallback;

  bool get isWsConnected => _wsConnected;
  bool get isAtivo => _ativo;

  Future<void> start({
    required String token,
    required String conversaId,
    required Future<List<Map<String, dynamic>>> Function() onFetch,
    required void Function(List<Map<String, dynamic>>) onUpdate,
    void Function(Map<String, dynamic>)? onWsMessage,
    void Function(String leitorId)? onMensagensLidas,
  }) async {
    // Entrar num chat sem ter saído do anterior duplicaria listeners e timers.
    if (_ativo) stop();

    _ativo = true;
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
    _wsConnected = socket.connected;

    if (_wsConnected) {
      loggerService.i('Entrou na sala $conversaId (WS já conectado)');
    } else {
      loggerService.w('WS ainda conectando — polling ativo como fallback');
      _startPolling(onFetch, onUpdate);
    }

    _novaMensagemListener = (data) => _handleNovaMensagem(data);
    socket.on('novaMensagem', _novaMensagemListener!);

    _mensagensLidasListener = (data) => _handleMensagensLidas(data);
    socket.on('mensagensLidas', _mensagensLidasListener!);

    // Guardar a referência é o que permite remover em stop().
    // Antes, estes dois handlers ficavam registrados para sempre no socket
    // singleton: ao sair do chat, o próximo `disconnect` reiniciava o polling
    // de uma conversa que ninguém estava vendo — e cada chat aberto somava mais
    // um handler, então mais um timer.
    _connectListener = (_) {
      if (!_ativo) return;
      _wsConnected = true;
      _pollingTimer?.cancel();
      loggerService.i('WebSocket conectado (conversa $conversaId)');
      // socket.io não lembra salas entre reconexões
      socketService.socket?.emit('entrarChat', conversaId);
    };
    socket.on('connect', _connectListener!);

    _disconnectListener = (_) {
      if (!_ativo) return;
      _wsConnected = false;
      loggerService.w('WebSocket desconectado — polling retomado');
      _startPolling(onFetch, onUpdate);
    };
    socket.on('disconnect', _disconnectListener!);
  }

  void _handleNovaMensagem(dynamic data) {
    if (!_ativo || data is! Map) return;
    final mensagem = Map<String, dynamic>.from(data);

    final conversaDaMensagem =
        mensagem['conversaId'] ?? mensagem['conversa']?['id'];
    if (conversaDaMensagem != null && conversaDaMensagem != _conversaId) {
      return;
    }

    _onWsMessageCallback?.call(mensagem);
  }

  void _handleMensagensLidas(dynamic data) {
    if (!_ativo || data is! Map) return;
    final payload = Map<String, dynamic>.from(data);
    if (payload['conversaId'] != _conversaId) return;

    final leitorId = payload['leitorId'] as String?;
    if (leitorId != null) _onMensagensLidasCallback?.call(leitorId);
  }

  void _startPolling(
    Future<List<Map<String, dynamic>>> Function() onFetch,
    void Function(List<Map<String, dynamic>>) onUpdate,
  ) {
    if (!_ativo) return;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // Duas checagens de _ativo: o stop() pode acontecer entre o disparo do
      // timer e o retorno do await.
      if (!_ativo || _wsConnected) {
        timer.cancel();
        return;
      }

      try {
        final msgs = await onFetch();
        if (!_ativo) return;
        onUpdate(msgs);
      } catch (e) {
        loggerService.w('polling falhou: $e');
      }
    });
  }

  void stop() {
    _ativo = false;

    _pollingTimer?.cancel();
    _pollingTimer = null;

    final socket = socketService.socket;
    if (socket != null) {
      if (_conversaId != null) {
        socket.emit('sairChat', _conversaId);
      }

      // Sempre com a referência: `socket.off('connect')` sem ela removeria
      // também os handlers de sessão do SocketService.
      if (_novaMensagemListener != null) {
        socket.off('novaMensagem', _novaMensagemListener);
      }
      if (_mensagensLidasListener != null) {
        socket.off('mensagensLidas', _mensagensLidasListener);
      }
      if (_connectListener != null) {
        socket.off('connect', _connectListener);
      }
      if (_disconnectListener != null) {
        socket.off('disconnect', _disconnectListener);
      }
    }

    _novaMensagemListener = null;
    _mensagensLidasListener = null;
    _connectListener = null;
    _disconnectListener = null;
    _onWsMessageCallback = null;
    _onMensagensLidasCallback = null;

    _wsConnected = false;
    _conversaId = null;

    loggerService.d('ChatRealtimeService parado');
  }
}
