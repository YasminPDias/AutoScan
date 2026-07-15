/// Rastreador de mensagens não lidas por conversa.
///
/// Antes: comparava timestamps localmente (heurística — não sabia quem
/// mandou, nem se foi lida em outro dispositivo).
///
/// Agora: cache em memória da contagem real que vem do backend
/// (GET /conversas/nao-lidas), atualizada:
///   - ao abrir a lista (ChatHistoryScreen._carregarConversas)
///   - em tempo real via evento conversaAtualizada (nova mensagem chega)
///   - ao abrir uma conversa (zera localmente + confirma no backend)
class ChatReadTracker {
  // conversaId -> quantidade de mensagens não lidas
  static final Map<String, int> _naoLidas = {};

  /// Substitui o mapa inteiro com os dados vindos do backend.
  /// Chama isso logo após carregar a lista de conversas.
  static void popularDoBackend(List<Map<String, dynamic>> dados) {
    _naoLidas.clear();
    for (final item in dados) {
      final id = item['conversaId']?.toString();
      final count = int.tryParse(item['naoLidas']?.toString() ?? '0') ?? 0;
      if (id != null && count > 0) {
        _naoLidas[id] = count;
      }
    }
  }

  /// Chamado quando o evento conversaAtualizada chega via socket —
  /// incrementa sem precisar rebater na API.
  static void incrementar(String conversaId) {
    _naoLidas[conversaId] = (_naoLidas[conversaId] ?? 0) + 1;
  }

  /// Chamado ao abrir uma conversa — zera localmente na hora (UX imediata).
  static void markRead(String conversaId) {
    _naoLidas.remove(conversaId);
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