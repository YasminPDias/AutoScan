/// Rastreia mensagens não lidas por conversa (em memória durante a sessão).
///
/// Uso:
///   - [updateLatest]: chamado ao carregar preview de mensagens
///   - [markRead]: chamado ao abrir um chat
///   - [hasUnread]: verifica se há mensagens novas não lidas
///   - [totalUnread]: total de conversas com mensagens não lidas
class ChatReadTracker {
  ChatReadTracker._();

  // conversaId → timestamp da última mensagem conhecida
  static final Map<String, DateTime> _latestMessage = {};

  // conversaId → timestamp da última vez que o usuário abriu o chat
  static final Map<String, DateTime> _lastRead = {};

  /// Atualiza o timestamp da mensagem mais recente para uma conversa.
  static void updateLatest(String conversaId, DateTime messageTime) {
    final current = _latestMessage[conversaId];
    if (current == null || messageTime.isAfter(current)) {
      _latestMessage[conversaId] = messageTime;
    }
  }

  /// Marca a conversa como lida agora.
  static void markRead(String conversaId) {
    _lastRead[conversaId] = DateTime.now();
  }

  /// Retorna true se há mensagens mais novas do que a última leitura.
  static bool hasUnread(String conversaId) {
    final latest = _latestMessage[conversaId];
    if (latest == null) return false;
    final read = _lastRead[conversaId];
    if (read == null) return true; // nunca aberto
    return latest.isAfter(read);
  }

  /// Número de conversas com mensagens não lidas.
  static int get totalUnread =>
      _latestMessage.keys.where((id) => hasUnread(id)).length;

  /// Limpa todos os dados (ex: ao fazer logout).
  static void clear() {
    _latestMessage.clear();
    _lastRead.clear();
  }
}
