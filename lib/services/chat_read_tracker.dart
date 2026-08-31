import 'package:flutter/foundation.dart';
import 'chat_service.dart';
import 'esquema_service.dart';

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

  static final Map<String, String> _conversaTipos = {};

  // Conversas que foram lidas pelo usuário na sessão atual para evitar
  // que estados desatualizados do backend as marquem como não lidas de novo
  static final Set<String> _lidasNaSessao = {};

  // ID da conversa que o usuário está visualizando no momento.
  // Impede que eventos em tempo real marquem a conversa ativa como não lida.
  static String? _conversaAbertaId;

  static int _meusAtendimentosCount = 0;
  static bool get temMeusAtendimentos => _meusAtendimentosCount > 0;

  static void setMeusAtendimentosCount(int count) {
    _meusAtendimentosCount = count;
    _notificar();
  }

  static void limpar() {
    _naoLidas.clear();
    _conversaTipos.clear();
    _lidasNaSessao.clear();
    _conversaAbertaId = null;
    _meusAtendimentosCount = 0;
    _notificar();
  }

  /// Define qual conversa está aberta na tela do usuário.
  static void setConversaAberta(String? conversaId) {
    _conversaAbertaId = conversaId;
    if (conversaId != null) {
      markRead(conversaId);
    }
  }

  static void registrarTipo(String conversaId, String tipo) {
    _conversaTipos[conversaId] = tipo.trim().toUpperCase();
    _notificar();
  }

  static void registrarTipos(Iterable<dynamic> conversas) {
    for (final c in conversas) {
      final id = c is Map
          ? (c['conversaId'] ?? c['id'] ?? c['_id'] ?? c['conversa']?['id'])?.toString()
          : c.id?.toString();
      var tipo = c is Map
          ? (c['tipo'] ?? c['conversa']?['tipo'])?.toString()
          : c.tipo?.toString();

      if (c is Map && (tipo == null || tipo.isEmpty)) {
        if (c.containsKey('solicitacaoEsquema') || c.containsKey('marca') || c.containsKey('injecao')) {
          tipo = 'ESQUEMA_ELETRICO';
        }
      }

      if (id != null && id.isNotEmpty) {
        final finalTipo = (tipo != null && tipo.isNotEmpty) ? tipo.trim().toUpperCase() : 'DIAGNOSTICO';
        _conversaTipos[id] = finalTipo;
      }
    }
    _notificar();
  }

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
      final convsRes = await ChatService.buscarMinhasConversas(token: token, pagina: 1, porPagina: 50);
      if (convsRes['success'] == true && convsRes['data'] is List) {
        final lista = convsRes['data'] as List;
        registrarTipos(lista);
        final ativas = lista.where((c) {
          final status = c is Map
              ? (c['status']?.toString() ?? '')
              : (c.status?.toString() ?? '');
          final statusUpper = status.toUpperCase();
          return statusUpper != 'ENCERRADA' && statusUpper != 'FECHADA' && statusUpper != 'CONCLUIDA';
        }).length;
        setMeusAtendimentosCount(ativas);
      }

      final esqDispRes = await ChatService.buscarConversasDisponiveis(token: token, tipo: 'ESQUEMA_ELETRICO', pagina: 1, porPagina: 50);
      if (esqDispRes['success'] == true && esqDispRes['data'] is List) {
        registrarTipos(esqDispRes['data'] as List);
      }

      final esqMinhasRes = await EsquemaService.listarMinhas(token: token, pagina: 1, porPagina: 50);
      if (esqMinhasRes['success'] == true && esqMinhasRes['data'] is List) {
        registrarTipos(esqMinhasRes['data'] as List);
      }

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
    final Map<String, int> novosNaoLidos = {};
    for (final item in dados) {
      final id = (item['conversaId'] ?? item['id'] ?? item['_id'])?.toString();
      final count = int.tryParse(
            (item['naoLidas'] ?? item['count'] ?? item['total'] ?? item['unread'] ?? '0')
                .toString(),
          ) ??
          0;
      if (id != null && count > 0) {
        novosNaoLidos[id] = count;

        final tipo = item['tipo']?.toString() ?? item['conversa']?['tipo']?.toString();
        if (tipo != null && tipo.isNotEmpty) {
          _conversaTipos[id] = tipo.trim().toUpperCase();
        }
      }
    }

    _lidasNaSessao.removeWhere((id) => !novosNaoLidos.containsKey(id));

    _naoLidas.clear();
    novosNaoLidos.forEach((id, count) {
      // Se a conversa foi lida nesta sessão ou está aberta no momento, ignora o estado desatualizado do backend
      if (_lidasNaSessao.contains(id) || _conversaAbertaId == id) {
        return;
      }
      _naoLidas[id] = count;
    });
    _notificar();
  }

  /// Chamado quando chega evento de socket (nova mensagem ou novo chamado) —
  /// incrementa sem precisar rebater na API.
  static void incrementar(String conversaId) {
    // Se a conversa está aberta pelo usuário neste exato momento, não faz nada
    if (_conversaAbertaId == conversaId) {
      return;
    }
    // Nova mensagem recebida anula a leitura da sessão para esta conversa
    _lidasNaSessao.remove(conversaId);
    _naoLidas[conversaId] = (_naoLidas[conversaId] ?? 0) + 1;
    _notificar();
  }

  /// Chamado ao abrir uma conversa — zera localmente na hora (UX imediata).
  static void markRead(String conversaId) {
    _lidasNaSessao.add(conversaId);
    _naoLidas.remove(conversaId);
    _notificar();
  }

  /// Mantém apenas as contagens das conversas ativas/disponíveis fornecidas.
  static void manterApenas(Set<String> ids) {
    _naoLidas.removeWhere((key, _) => !ids.contains(key));
    _notificar();
  }

  static void manterApenasPorTipo(Set<String> ids, String tipo) {
    final tipoUpper = tipo.trim().toUpperCase();
    _naoLidas.removeWhere((key, _) {
      final itemTipo = _conversaTipos[key] ?? 'DIAGNOSTICO';
      if (itemTipo == tipoUpper) {
        return !ids.contains(key);
      }
      return false;
    });
    _notificar();
  }

  /// Tem mensagens não lidas nessa conversa?
  static bool hasUnread(String conversaId) {
    return (_naoLidas[conversaId] ?? 0) > 0;
  }

  /// Total de conversas com pelo menos uma não lida (pra badge do sidebar).
  static int get totalUnread => _naoLidas.values.where((n) => n > 0).length;

  static int get totalDiagnosticoUnread {
    return _naoLidas.entries.where((entry) {
      final tipo = _conversaTipos[entry.key] ?? 'DIAGNOSTICO';
      return tipo == 'DIAGNOSTICO' && entry.value > 0;
    }).length;
  }

  static int get totalEsquemaUnread {
    return _naoLidas.entries.where((entry) {
      final tipo = _conversaTipos[entry.key] ?? 'DIAGNOSTICO';
      return tipo == 'ESQUEMA_ELETRICO' && entry.value > 0;
    }).length;
  }

  /// Contagem exata de não lidas numa conversa específica.
  static int countFor(String conversaId) => _naoLidas[conversaId] ?? 0;
}