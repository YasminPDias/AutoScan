import 'dart:async';
import 'socket_service.dart';
import 'logger_service.dart';

/// Serviço de tempo real para o chat.
///
/// Reaproveita a conexão Socket.io compartilhada (SocketService) em vez de
/// abrir uma conexão própria — só entra/sai da sala da conversa específica.
/// Mantém a mesma API pública de antes (start/stop/isWsConnected), então
/// quem já chama esse serviço não precisa mudar nada.
///
/// Estratégia dual, igual antes:
///   1. Entra na sala via Socket.io compartilhado.
///   2. Se não conectar (ou cair), polling HTTP de 5s mantém atualizado.
///   3. Quando o WS confirma conexão, o polling é pausado.
class ChatRealtimeService {
  String? _conversaId;
  Timer? _pollingTimer;
  void Function(Map<String, dynamic>)? _onWsMessageCallback;
  void Function(String leitorId)? _onMensagensLidasCallback;
  bool _wsConnected = false;
  Function(dynamic)? _novaMensagemListener;
  Function(dynamic)? _mensagensLidasListener;

  bool get isWsConnected => _wsConnected;

  /// Inicia o serviço para a [conversaId] informada.
  ///
  /// - [token]: JWT do usuário (usado só se a conexão compartilhada ainda
  ///   não existir — se já conectada, é reaproveitada como está).
  /// - [onFetch]: função que busca a lista de mensagens via HTTP.
  /// - [onUpdate]: callback chamado com a lista atualizada a cada poll.
  /// - [onWsMessage]: callback opcional para mensagens recebidas via WS.
  /// - [onMensagensLidas]: callback opcional, chamado com o id de quem leu,
  ///   toda vez que o outro participante visualiza as mensagens dessa conversa.
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

    // idempotente: se a conexão compartilhada já existe, não abre outra
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
      loggerService.i('Entrou na sala da conversa $conversaId (WS já conectado)');
    }

    _novaMensagemListener = (data) => _handleNovaMensagem(data);
    socket.on('novaMensagem', _novaMensagemListener!);

    _mensagensLidasListener = (data) => _handleMensagensLidas(data);
    socket.on('mensagensLidas', _mensagensLidasListener!);

    socket.on('connect', (_) {
      _wsConnected = true;
      _pollingTimer?.cancel();
      loggerService.i('WebSocket conectado (conversa $conversaId)');
      // reenvia entrarChat: se a conexão caiu e reconectou, a sala precisa
      // ser reafirmada (socket.io não lembra salas entre reconexões) — isso
      // também refaz o "catch up" de mensagens lidas no backend
      socket.emit('entrarChat', conversaId);
    });

    socket.on('disconnect', (_) {
      _wsConnected = false;
      _startPolling(onFetch, onUpdate);
    });

    _startPolling(onFetch, onUpdate);
  }

  void _handleNovaMensagem(dynamic data) {
    if (data is! Map) return;
    final mensagem = Map<String, dynamic>.from(data);

    // TODO: confirma o campo real no MensagemRespostaDTO — chutei os dois
    // formatos mais prováveis (nested ou flat). Necessário porque a conexão
    // agora é compartilhada: sem esse filtro, uma 2ª conversa aberta ao
    // mesmo tempo receberia mensagens uma da outra.
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