import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/chat_service.dart';
import '../../services/auth_storage.dart';
import '../../services/chat_read_tracker.dart';
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

  // Dados carregados em background por conversa
  final Map<String, String> _clienteNomes = {};
  final Map<String, String> _previews = {};
  final Map<String, DateTime> _ultimasMensagens = {};
  final Map<String, bool> _loadingPreview = {};

  @override
  void initState() {
    super.initState();
    _carregarConversas();
  }

  Future<void> _carregarConversas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _clienteNomes.clear();
      _previews.clear();
      _ultimasMensagens.clear();
      _loadingPreview.clear();
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

      final result = await ChatService.buscarTodasConversas(token: token);
      if (!mounted) return;

      if (result['success'] == true) {
        final lista = (result['data'] as List)
            .map((j) => ConversaModel.fromJson(j as Map<String, dynamic>))
            .toList();
        setState(() {
          _conversas = lista;
          _isLoading = false;
        });

        for (final conv in lista) {
          _carregarPreview(token, conv.id);
        }
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

  Future<void> _carregarPreview(String token, String conversaId) async {
    if (!mounted) return;
    setState(() => _loadingPreview[conversaId] = true);

    try {
      final result = await ChatService.buscarMensagens(
        token: token,
        conversaId: conversaId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final msgs = result['data'] as List;
        if (msgs.isNotEmpty) {
          final sorted = List<Map<String, dynamic>>.from(
            msgs.map((m) => m as Map<String, dynamic>),
          )..sort((a, b) {
              final da = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                  DateTime(2000);
              final db = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                  DateTime(2000);
              return da.compareTo(db);
            });

          // Nome do cliente = remetente da primeira mensagem
          final primeira = sorted.first;
          final usuario =
              primeira['usuario'] as Map<String, dynamic>?;
          if (usuario != null) {
            final n = usuario['nome']?.toString() ?? '';
            final s = usuario['sobrenome']?.toString() ??
                usuario['lastName']?.toString() ??
                '';
            final nome = '$n $s'.trim();
            if (nome.isNotEmpty && mounted) {
              setState(() => _clienteNomes[conversaId] = nome);
            }
          }

          // Preview = ÚLTIMA mensagem (mais recente)
          final ultima = sorted.last;
          final conteudo = ultima['conteudo']?.toString() ?? '';
          final preview =
              conteudo.length > 90 ? '${conteudo.substring(0, 90)}…' : conteudo;

          // Timestamp da última mensagem para rastrear não lidas
          final ultimaAt = DateTime.tryParse(
                  ultima['createdAt']?.toString() ?? '') ??
              DateTime.now();

          if (mounted) {
            setState(() {
              if (preview.isNotEmpty) _previews[conversaId] = preview;
              _ultimasMensagens[conversaId] = ultimaAt;
              _loadingPreview[conversaId] = false;
            });

            // Atualiza o tracker global de não lidas
            ChatReadTracker.updateLatest(conversaId, ultimaAt);
          }
        } else {
          if (mounted) setState(() => _loadingPreview[conversaId] = false);
        }
      } else {
        if (mounted) setState(() => _loadingPreview[conversaId] = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPreview[conversaId] = false);
    }
  }

  void _abrirConversa(String conversaId) {
    ChatReadTracker.markRead(conversaId);
    setState(() {}); // atualiza badge imediatamente
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
                  onPressed: () => Navigator.pop(context),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
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
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Badge de não lidas no header
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
          const Icon(
              Icons.error_outline, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.primaryRed),
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
                (i) => _buildItemConversa(
                    _conversas[metade + i], metade + i + 1),
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
    final isLoadingPreview = _loadingPreview[conv.id] ?? false;
    final nomeCliente = _clienteNomes[conv.id];
    final preview = _previews[conv.id];
    final ultimaAt = _ultimasMensagens[conv.id];
    final temNaoLida = ChatReadTracker.hasUnread(conv.id);

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
                    right: BorderSide(
                        color: accentColor.withValues(alpha: 0.2)),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome + badge de não lida
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_outline,
                              size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: isLoadingPreview && nomeCliente == null
                                ? _buildSkeletonLine(
                                    width: 140, height: 13)
                                : Text(
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

                      // Preview da última mensagem
                      if (isLoadingPreview && preview == null)
                        _buildSkeletonLine(width: double.infinity, height: 11)
                      else if (preview != null)
                        Text(
                          preview,
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
                          Text(
                            _formatarId(conv.id),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (ultimaAt != null) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.access_time,
                                size: 11, color: AppColors.textLight),
                            const SizedBox(width: 3),
                            Text(
                              _formatarData(ultimaAt.toIso8601String()),
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

              // Indicador de não lida (ponto) + seta
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

  Widget _buildSkeletonLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.iconBackground,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildBadgeStatus(String status) {
    Color cor;
    String label;
    switch (status.toUpperCase()) {
      case 'ABERTA':
      case 'OPEN':
      case 'ATIVA':
        cor = AppColors.statusResolved;
        label = 'Aberta';
        break;
      case 'FECHADA':
      case 'CLOSED':
      case 'ENCERRADA':
        cor = AppColors.textLight;
        label = 'Fechada';
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
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: cor),
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
      if (dt.year == hoje.year &&
          dt.month == hoje.month &&
          dt.day == hoje.day) {
        return 'Hoje ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (dt.year == ontem.year &&
          dt.month == ontem.month &&
          dt.day == ontem.day) {
        return 'Ontem ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
