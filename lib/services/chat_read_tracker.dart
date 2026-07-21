import 'package:flutter/foundation.dart';
import 'chat_service.dart';

/// Rastreador de mensagens não lidas por conversa.
///
/// Cache em memória da contagem real que vem do backend
/// (GET /conversas/nao-lidas), atualizada:
///   - ao realizar login ou iniciar o app (ChatReadTracker.carregarDaApi)
///   - ao abrir a lista (ChatHistoryScreen._carregarConversas)
///   - em tempo real via evento conversaAtualizada/novoChamado (socket)
///   - ao abrir uma conversa (zera localmente)
///
/// O [notifier] permite que widgets (ex: AppSidebar) se reconstruam
/// automaticamente via ValueListenableBuilder quando o tracker muda,
/// sem precisar de setState ou callbacks manuais.
class ChatReadTracker {
  // conversaId -> quantidade de mensagens não lidas
  static final Map<String, int> _naoLidas = {};

  /// Escuta esse notifier pra reconstruir automaticamente quando o badge muda.
  /// Valor = total de conversas com pelo menos uma mensagem não lida.
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void _notificar() {
    notifier.value = totalUnread;
  }

  /// Busca as mensagens/conversas não lidas da API (GET /conversas/nao-lidas)
  /// e atualiza o badge automaticamente.
  static Future<void> carregarDaApi(String token) async {
    try {
      final res = await ChatService.buscarNaoLidas(token: token);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
            .toList();
        popularDoBackend(list);
      }
    } catch (_) {}
  }

  /// Substitui o mapa inteiro com os dados vindos do backend.
  /// Chama isso logo após carregar a lista de conversas.
  static void popularDoBackend(List<Map<String, dynamic>> dados) {
    _naoLidas.clear();
    for (final item in dados) {
      final id = (item['conversaId'] ?? item['id'] ?? item['_id'])?.toString();
      final count = int.tryParse(
            (item['naoLidas'] ?? item['count'] ?? item['total'] ?? item['unread'] ?? '0')
                .toString(),
          ) ??
          0;
      if (id != null && count > 0) {
        _naoLidas[id] = count;
      }
    }
    _notificar();
  }

  /// Chamado quando chega evento de socket (nova mensagem ou novo chamado) —
  /// incrementa sem precisar rebater na API.
  static void incrementar(String conversaId) {
    _naoLidas[conversaId] = (_naoLidas[conversaId] ?? 0) + 1;
    _notificar();
  }

  /// Chamado ao abrir uma conversa — zera localmente na hora (UX imediata).
  static void markRead(String conversaId) {
    _naoLidas.remove(conversaId);
    _notificar();
  }

  /// Tem mensagens não lidas nessa conversa?
  static bool hasUnread(String conversaId) {
    return (_naoLidas[conversaId] ?? 0) > 0;
  }

  /// Total de conversas com pelo menos uma não lida (pra badge do sidebar).
  static int get totalUnread => _naoLidas.values.where((n) => n > 0).length;

  /// Contagem exata de não lidas numa conversa específica.
  static int countFor(String conversaId) => _naoLidas[conversaId] ?? 0;
}