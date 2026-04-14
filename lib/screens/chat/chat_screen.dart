import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/chat_service.dart';
import '../../services/auth_storage.dart';
import '../../services/logger_service.dart';
import '../../services/websocket_service.dart';
import '../../services/chat_read_tracker.dart';
import '../../models/mensagem_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRealtimeService _realtimeService = ChatRealtimeService();

  List<MensagemModel> _mensagens = [];
  bool _initialized = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isEncerrandoConversa = false;
  String? _conversaId;
  String? _errorMessage;
  String? _myUserId;
  String? _myUserName;
  String? _myRole;
  String? _token;
  String _conversaStatus = '';

  bool get _isEncerrada =>
      _conversaStatus == 'ENCERRADA' ||
      _conversaStatus == 'FECHADA' ||
      _conversaStatus == 'CONCLUIDA';

  bool get _isCliente {
    final role = (_myRole ?? '').toUpperCase();
    return role != 'ADMIN' && role != 'ASSISTENTE';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _inicializar();
    }
  }

  Future<void> _inicializar() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final diagnosticoId = args?['diagnosticoId'] as String?;
    final diagnosticoTexto = args?['diagnosticoTexto'] as String?;
    final conversaIdArg = args?['conversaId'] as String?;

    _myUserId = await AuthStorage.getUserId();
    _myUserName = await AuthStorage.getUserName();
    _myRole = await AuthStorage.getUserRole();
    _token = await AuthStorage.getToken();

    if (_token == null || _token!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sessão expirada. Faça login novamente.';
        });
      }
      return;
    }

    String? conversaId = conversaIdArg;

    // Aberto sem contexto (ex: clique direto no menu) → redireciona para histórico
    if (conversaId == null && diagnosticoId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/history');
      }
      return;
    }

    if (conversaId == null && diagnosticoId != null) {
      conversaId = await _encontrarOuCriarConversa(
        token: _token!,
        diagnosticoId: diagnosticoId,
        diagnosticoTexto: diagnosticoTexto,
      );
    }

    if (conversaId == null || conversaId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Não foi possível iniciar o chat. Tente novamente.';
        });
      }
      return;
    }

    _conversaId = conversaId;
    ChatReadTracker.markRead(conversaId); // marca como lida ao abrir

    // Carrega status da conversa
    final convResult = await ChatService.buscarConversa(
      token: _token!,
      conversaId: conversaId,
    );
    if (convResult['success'] == true && mounted) {
      final data = convResult['data'] as Map<String, dynamic>;
      setState(() {
        _conversaStatus = data['status']?.toString() ?? '';
      });
    }

    await _carregarMensagens();

    // Inicia serviço de tempo real (WebSocket + polling fallback)
    _realtimeService.start(
      token: _token!,
      conversaId: conversaId,
      onFetch: () async {
        final result = await ChatService.buscarMensagens(
          token: _token!,
          conversaId: conversaId!,
        );
        if (result['success'] == true) {
          return (result['data'] as List).cast<Map<String, dynamic>>();
        }
        return [];
      },
      onUpdate: (rawList) {
        final novas = rawList
            .map((j) => MensagemModel.fromJson(j))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        if (mounted && _mensagensAlteradas(novas)) {
          setState(() => _mensagens = novas);
          _scrollToBottom();
        }
      },
      onWsMessage: (json) {
        // Evento de nova mensagem via WebSocket
        if (json['conteudo'] != null || json['content'] != null) {
          try {
            final msg = MensagemModel.fromJson(json);
            if (mounted && !_mensagens.any((m) => m.id == msg.id)) {
              setState(() => _mensagens.add(msg));
              _scrollToBottom();
            }
          } catch (_) {}
        }
      },
    );
  }

  /// Verifica se a lista de mensagens mudou (evita rebuilds desnecessários).
  bool _mensagensAlteradas(List<MensagemModel> novas) {
    final confirmadas = _mensagens.where((m) => !m.isPending).toList();
    if (novas.length != confirmadas.length) return true;
    if (novas.isEmpty) return false;
    return novas.last.id != confirmadas.lastOrNull?.id;
  }

  /// Busca conversa existente para o diagnóstico ou cria uma nova.
  Future<String?> _encontrarOuCriarConversa({
    required String token,
    required String diagnosticoId,
    String? diagnosticoTexto,
  }) async {
    // 1. Verificar conversas existentes do cliente
    final minhasResult = await ChatService.buscarMinhasConversas(token: token);
    if (minhasResult['success'] == true) {
      final lista = minhasResult['data'] as List;
      for (final item in lista) {
        final conv = item as Map<String, dynamic>;
        if (conv['aiDiagnosticoId']?.toString() == diagnosticoId) {
          loggerService.d('Conversa existente: ${conv['id']}');
          return conv['id']?.toString();
        }
      }
    }

    // 2. Criar nova conversa
    final createResult = await ChatService.criarConversa(
      token: token,
      aiDiagnosticoId: diagnosticoId,
    );

    if (createResult['success'] != true) {
      loggerService.e('Falha ao criar conversa: ${createResult['message']}');
      return null;
    }

    final convId =
        (createResult['data'] as Map<String, dynamic>)['id']?.toString();

    // 3. Enviar primeira mensagem com o texto do diagnóstico
    if (convId != null &&
        diagnosticoTexto != null &&
        diagnosticoTexto.isNotEmpty) {
      await ChatService.enviarMensagem(
        token: token,
        conversaId: convId,
        conteudo: diagnosticoTexto,
      );
    }

    return convId;
  }

  Future<void> _carregarMensagens() async {
    if (_conversaId == null || _token == null) return;

    final result = await ChatService.buscarMensagens(
      token: _token!,
      conversaId: _conversaId!,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final lista = (result['data'] as List)
          .map((j) => MensagemModel.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        _mensagens = lista;
        _isLoading = false;
      });
      _scrollToBottom();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message']?.toString();
      });
    }
  }

  Future<void> _enviarMensagem() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty || _conversaId == null || _isSending || _token == null) {
      return;
    }

    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final msgPendente = MensagemModel(
      id: tempId,
      tipo: 'TEXTO',
      conteudo: texto,
      createdAt: DateTime.now(),
      isPending: true,
    );

    setState(() {
      _mensagens.add(msgPendente);
      _isSending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    final result = await ChatService.enviarMensagem(
      token: _token!,
      conversaId: _conversaId!,
      conteudo: texto,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final msgConfirmada = MensagemModel.fromJson(
        result['data'] as Map<String, dynamic>,
      );
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        _mensagens.add(msgConfirmada);
        _isSending = false;
      });
    } else {
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erro ao enviar mensagem.'),
          backgroundColor: AppColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _scrollToBottom();
  }

  Future<void> _encerrarConversa() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar conversa'),
        content: const Text(
          'Deseja encerrar esta conversa e marcar o problema como resolvido?\n\nApós encerrado, não será possível enviar novas mensagens.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
            ),
            child: const Text(
              'Problema resolvido',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || _conversaId == null || _token == null) return;

    setState(() => _isEncerrandoConversa = true);

    final result = await ChatService.encerrarConversa(
      token: _token!,
      conversaId: _conversaId!,
    );

    if (!mounted) return;
    setState(() => _isEncerrandoConversa = false);

    if (result['success'] == true) {
      setState(() => _conversaStatus = 'ENCERRADA');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erro ao encerrar conversa.'),
          backgroundColor: AppColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMinhaMensagem(MensagemModel msg) {
    if (msg.isPending) return true;
    if (_myUserId == null || _myUserId!.isEmpty) return false;
    return msg.usuario?.id == _myUserId;
  }

  String _formatarHora(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/chat',
      title: context.isDesktop ? 'Chat' : '',
      showAppBar: !context.isDesktop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop
            ? null
 
            : AppBar(
                title: const Text('Chat'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed),
              )
            : _errorMessage != null
                ? _buildErro()
                : Column(
                    children: [
                      Expanded(child: _buildListaMensagens()),
                      if (_isEncerrada)
                        _buildBannerEncerrada()
                      else
                        _buildBarraInput(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.primaryRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
              ),
              child: const Text(
                'Voltar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaMensagens() {
    if (_mensagens.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma mensagem ainda.',
          style: TextStyle(color: AppColors.textLight),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
      itemCount: _mensagens.length,
      itemBuilder: (context, index) => _buildBolhaMensagem(_mensagens[index]),
    );
  }

  Widget _buildBolhaMensagem(MensagemModel msg) {
    final isMeu = _isMinhaMensagem(msg);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMeu ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMeu) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: AppColors.iconBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.support_agent,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMeu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Nome do remetente
                if (!isMeu && msg.usuario != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      msg.usuario!.nome,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (isMeu && _myUserName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 4),
                    child: Text(
                      _myUserName!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                // Bolha da mensagem
                Opacity(
                  opacity: msg.isPending ? 0.55 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMeu
                          ? AppColors.lightRed
                          : AppColors.cardWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(isMeu ? 12 : 2),
                        bottomRight: Radius.circular(isMeu ? 2 : 12),
                      ),
                      border: Border.all(
                        color: isMeu
                            ? AppColors.primaryRed.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      msg.conteudo,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                // Hora
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatarHora(msg.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (msg.isPending) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.access_time,
                          size: 10,
                          color: AppColors.textLight,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMeu) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 0, top: 4),
              decoration: const BoxDecoration(
                color: AppColors.primaryRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBannerEncerrada() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        border: Border(top: BorderSide(color: Color(0xFF388E3C), width: 1)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF388E3C), size: 18),
            SizedBox(width: 8),
            Text(
              'Problema resolvido — conversa encerrada',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF388E3C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraInput() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.isDesktop ? 20 : 16,
        vertical: context.isDesktop ? 16 : 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.isDesktop ? 1200 : double.infinity,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Campo de texto
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.iconBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escreva uma mensagem...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _enviarMensagem(),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botão "Problema resolvido" — apenas para clientes
              if (_isCliente)
                Tooltip(
                  message: 'Problema resolvido — encerrar conversa',
                  child: _isEncerrandoConversa
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF388E3C),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF388E3C)),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFF388E3C),
                            ),
                            onPressed: _encerrarConversa,
                            tooltip: '',
                          ),
                        ),
                ),
              if (_isCliente) const SizedBox(width: 4),
              // Botão enviar
              _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: _enviarMensagem,
                      color: AppColors.primaryRed,
                      tooltip: 'Enviar',
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _realtimeService.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
