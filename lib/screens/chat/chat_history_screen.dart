import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/chat_service.dart';
import '../../services/auth_storage.dart';
import '../../services/chat_read_tracker.dart';
import '../../services/socket_service.dart';
import '../../models/conversa_model.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ConversaModel> _conversas = [];

  @override
  void initState() {
    super.initState();
    _carregarConversas();
    socketService.onConversaAtualizada = _aoAtualizarConversa;
  }

  @override
  void dispose() {
    if (socketService.onConversaAtualizada == _aoAtualizarConversa) {
      socketService.onConversaAtualizada = null;
    }
    super.dispose();
  }

  void _aoAtualizarConversa(Map<String, dynamic> data) {
    if (!mounted) return;
    final conversaId = data['conversaId']?.toString();
    if (conversaId == null) return;

    setState(() {
      // atualiza o preview na lista em tempo real sem rebater na API
      _conversas = _conversas.map((conv) {
        if (conv.id != conversaId) return conv;
        final preview = data['preview']?.toString() ?? '';
        final createdAt = DateTime.tryParse(data['createdAt']?.toString() ?? '');
        final ultimaMensagem = preview.isNotEmpty && createdAt != null
            ? UltimaMensagem(
                id: '',
                conteudo: preview,
                tipo: 'TEXTO',
                createdAt: createdAt,
              )
            : conv.ultimaMensagem;
        return ConversaModel(
          id: conv.id,
          aiDiagnosticoId: conv.aiDiagnosticoId,
          status: conv.status,
          clienteNome: conv.clienteNome,
          clienteId: conv.clienteId,
          atendenteNome: conv.atendenteNome,
          atendenteId: conv.atendenteId,
          createdAt: conv.createdAt,
          ultimaMensagem: ultimaMensagem,
        );
      }).toList();
      ChatReadTracker.incrementar(conversaId);
    });
  }

  Future<void> _carregarConversas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Sessão expirada. Faça login novamente.';
          });
        }
        return;
      }

      final result = await ChatService.buscarMinhasConversas(token: token);
      if (!mounted) return;

      if (result['success'] == true) {
        final lista = (result['data'] as List)
            .map((j) => ConversaModel.fromJson(j as Map<String, dynamic>))
            .toList();

        // popula o tracker com dados reais do backend (uma só requisição)
        final naoLidasResult = await ChatService.buscarNaoLidas(token: token);
        if (naoLidasResult['success'] == true) {
          ChatReadTracker.popularDoBackend(
            (naoLidasResult['data'] as List).cast<Map<String, dynamic>>(),
          );
        }

        setState(() {
          _conversas = lista;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              result['message']?.toString() ?? 'Erro ao carregar conversas.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro de conexão: $e';
        });
      }
    }
  }

  void _abrirConversa(String conversaId) {
    ChatReadTracker.markRead(conversaId);
    setState(() {});
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {'conversaId': conversaId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/chat-history',
      title: '',
      showAppBar: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop
            ? null
            : AppBar(
                title: const Text('Atendimentos'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/home');
                    }
                  },
                ),
              ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryRed),
                    SizedBox(height: 16),
                    Text(
                      'Carregando atendimentos...',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _carregarConversas,
                color: AppColors.primaryRed,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      if (_errorMessage != null)
                        _buildErrorBanner()
                      else if (_conversas.isEmpty)
                        _buildEmpty()
                      else
                        _buildLista(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalNaoLidas = _conversas
        .where((c) => ChatReadTracker.hasUnread(c.id))
        .length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.support_agent, color: AppColors.primaryRed, size: 28),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Atendimentos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${_conversas.length} conversa${_conversas.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(width: 12),
        if (totalNaoLidas > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$totalNaoLidas nova${totalNaoLidas != 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _carregarConversas,
          tooltip: 'Atualizar',
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 13, color: AppColors.primaryRed),
            ),
          ),
          TextButton(
            onPressed: _carregarConversas,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.lightRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nenhum atendimento encontrado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Os chats iniciados pelos clientes aparecerão aqui.',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista() {
    final total = _conversas.length;

    if (context.isDesktop) {
      final metade = (total / 2).ceil();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: List.generate(
                metade,
                (i) => _buildItemConversa(_conversas[i], i + 1),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: List.generate(
                total - metade,
                (i) => _buildItemConversa(_conversas[metade + i], metade + i + 1),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: List.generate(
        total,
        (i) => _buildItemConversa(_conversas[i], i + 1),
      ),
    );
  }

  Widget _buildItemConversa(ConversaModel conv, int numero) {
    final temNaoLida = ChatReadTracker.hasUnread(conv.id);
    final ultima = conv.ultimaMensagem;
    final nomeCliente = conv.clienteNome;

    final accentColors = [
      AppColors.primaryRed,
      const Color(0xFF1976D2),
      const Color(0xFF388E3C),
      const Color(0xFFF57C00),
      const Color(0xFF7B1FA2),
    ];
    final accentColor = accentColors[(numero - 1) % accentColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: temNaoLida
            ? AppColors.primaryRed.withValues(alpha: 0.03)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: temNaoLida
              ? AppColors.primaryRed.withValues(alpha: 0.35)
              : AppColors.border,
          width: temNaoLida ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _abrirConversa(conv.id),
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra lateral com número
              Container(
                width: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                  border: Border(
                    right: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                  ),
                ),
                child: Center(
                  child: Text(
                    '#$numero',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ),
              ),

              // Conteúdo principal
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome + badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_outline,
                              size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              nomeCliente ?? 'Sem identificação',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: temNaoLida
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: nomeCliente != null
                                    ? AppColors.textPrimary
                                    : AppColors.textLight,
                                fontStyle: nomeCliente != null
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (temNaoLida) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Nova mensagem',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ] else if (conv.status != null) ...[
                            const SizedBox(width: 8),
                            _buildBadgeStatus(conv.status!),
                          ],
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Preview da última mensagem — vem direto do model, sem request extra
                      if (ultima != null)
                        Text(
                          // mostra quem mandou se não for o cliente
                          ultima.remetenteId != conv.clienteId && ultima.remetenteNome != null
                              ? '${ultima.remetenteNome}: ${ultima.preview}'
                              : ultima.preview,
                          style: TextStyle(
                            fontSize: 12,
                            color: temNaoLida
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: temNaoLida
                                ? FontWeight.w500
                                : FontWeight.normal,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        const Text(
                          'Nenhuma mensagem ainda.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                      const SizedBox(height: 8),

                      // ID + timestamp
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 11,
                            color: accentColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          if (ultima != null) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.access_time,
                                size: 11, color: AppColors.textLight),
                            const SizedBox(width: 3),
                            Text(
                              _formatarData(ultima.createdAt.toIso8601String()),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Indicador de não lida + seta
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (temNaoLida) ...[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    const Icon(Icons.chevron_right,
                        color: AppColors.textLight, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeStatus(String status) {
    Color cor;
    String label;
    switch (status.toUpperCase()) {
      case 'AGUARDANDO':
        cor = AppColors.statusPending;
        label = 'Aguardando';
        break;
      case 'EM_ATENDIMENTO':
        cor = const Color(0xFF1976D2);
        label = 'Em atendimento';
        break;
      case 'ENCERRADA':
      case 'CONCLUIDA':
        cor = AppColors.textLight;
        label = 'Encerrada';
        break;
      default:
        cor = AppColors.statusPending;
        label = status;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 7, color: cor),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor),
        ),
      ],
    );
  }

  String _formatarId(String id) {
    if (id.length <= 12) return id;
    final clean = id.replaceAll('-', '');
    return '${clean.substring(0, 6)}…${clean.substring(clean.length - 4)}';
  }

  String _formatarData(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final hoje = DateTime.now();
      final ontem = hoje.subtract(const Duration(days: 1));
      if (dt.year == hoje.year && dt.month == hoje.month && dt.day == hoje.day) {
        return 'Hoje ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (dt.year == ontem.year && dt.month == ontem.month && dt.day == ontem.day) {
        return 'Ontem ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}