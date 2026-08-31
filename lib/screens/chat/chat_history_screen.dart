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
  // aba "Meus atendimentos"
  bool _isLoading = true;
  String? _errorMessage;
  List<ConversaModel> _conversas = [];
  int _paginaAtual = 1;
  int _totalPaginas = 1;
  static const int _porPagina = 10;

  String _tipoFila = 'DIAGNOSTICO';
  bool _initializedArgs = false;

  @override
  void initState() {
    super.initState();
    socketService.onConversaAtualizada = _aoAtualizarConversa;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      _initializedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final tipoArg = args?['tipo']?.toString();
      if (tipoArg == 'ESQUEMA_ELETRICO') {
        _tipoFila = 'ESQUEMA_ELETRICO';
      } else {
        _tipoFila = 'DIAGNOSTICO';
      }
      _carregarConversas();
    }
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
    final tipo = data['tipo']?.toString();
    if (conversaId == null) return;
    if (tipo != null) ChatReadTracker.registrarTipo(conversaId, tipo);
    setState(() {
      _conversas = _conversas.map((conv) {
        if (conv.id != conversaId) return conv;
        final preview = data['preview']?.toString() ?? '';
        final createdAt = DateTime.tryParse(data['createdAt']?.toString() ?? '');
        final ultimaMensagem = preview.isNotEmpty && createdAt != null
            ? UltimaMensagem(id: '', conteudo: preview, tipo: 'TEXTO', createdAt: createdAt)
            : conv.ultimaMensagem;
        return ConversaModel(
          id: conv.id, aiDiagnosticoId: conv.aiDiagnosticoId,
          status: conv.status, clienteNome: conv.clienteNome,
          clienteId: conv.clienteId, atendenteNome: conv.atendenteNome,
          atendenteId: conv.atendenteId, createdAt: conv.createdAt,
          ultimaMensagem: ultimaMensagem,
          tipo: conv.tipo,
        );
      }).toList();
      ChatReadTracker.incrementar(conversaId);
    });
  }

  Future<void> _carregarConversas({int pagina = 1}) async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() { _isLoading = false; _errorMessage = 'Sessão expirada.'; });
        return;
      }
      final result = await ChatService.buscarMinhasConversas(
        token: token, pagina: pagina, porPagina: _porPagina,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final listaCompleta = (result['data'] as List<ConversaModel>);
        ChatReadTracker.registrarTipos(listaCompleta);
        final lista = listaCompleta.where((c) {
          final s = c.status?.toUpperCase() ?? '';
          final matchTipo = c.tipo == _tipoFila;
          return matchTipo && s != 'ENCERRADA' && s != 'CONCLUIDA' && s != 'FECHADA';
        }).toList();

        final naoLidasResult = await ChatService.buscarNaoLidas(token: token);
        if (naoLidasResult['success'] == true && mounted) {
          ChatReadTracker.popularDoBackend(
              (naoLidasResult['data'] as List).cast<Map<String, dynamic>>());
        }

        final activeIds = lista.map((c) => c.id).toSet();
        ChatReadTracker.manterApenasPorTipo(activeIds, _tipoFila);

        setState(() {
          _conversas = lista;
          _paginaAtual = result['pagina'] ?? pagina;
          _totalPaginas = result['totalPaginas'] ?? 1;
          _isLoading = false;
        });
      } else {
        setState(() { _isLoading = false; _errorMessage = result['message']?.toString() ?? 'Erro ao carregar.'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Erro de conexão: $e'; });
    }
  }

  void _abrirConversa(String conversaId) async {
    ChatReadTracker.markRead(conversaId);
    setState(() {});
    await Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'conversaId': conversaId,
        'disponivel': false,
      },
    );
    if (mounted) {
      await _carregarConversas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/chat-history',
      title: '',
      showAppBar: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop ? null : AppBar(
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
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                context.isDesktop ? 40 : 20, context.isDesktop ? 32 : 16,
                context.isDesktop ? 40 : 20, context.isDesktop ? 20 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                ],
              ),
            ),
            Expanded(
              child: _buildAbaConversas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbaConversas() {
    if (_isLoading) return _buildLoading('Carregando atendimentos...');
    return RefreshIndicator(
      onRefresh: () => _carregarConversas(pagina: _paginaAtual),
      color: AppColors.primaryRed,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_errorMessage != null) _buildErrorBanner(_errorMessage!, () => _carregarConversas())
          else if (_conversas.isEmpty) _buildEmpty('Nenhum atendimento encontrado', 'Os chats iniciados pelos clientes aparecerão aqui.')
          else ...[
            _buildLista(_conversas),
            if (_totalPaginas > 1) ...[
              const SizedBox(height: 24),
              _buildPaginacao(),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _buildPaginacao() {
    final paginas = <int>[];

    // sempre mostra no máximo 5 páginas centradas na atual
    int inicio = (_paginaAtual - 2).clamp(1, _totalPaginas);
    int fim = (inicio + 4).clamp(1, _totalPaginas);
    inicio = (fim - 4).clamp(1, _totalPaginas);

    for (int i = inicio; i <= fim; i++) {
      paginas.add(i);
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // botão anterior
          _buildBotaoPagina(
            icon: Icons.chevron_left,
            onTap: _paginaAtual > 1
                ? () => _carregarConversas(pagina: _paginaAtual - 1)
                : null,
          ),
          const SizedBox(width: 4),

          // páginas numeradas
          ...paginas.map((p) {
            final isAtual = p == _paginaAtual;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: isAtual ? null : () => _carregarConversas(pagina: p),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isAtual ? AppColors.primaryRed : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isAtual
                        ? null
                        : Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      '$p',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isAtual ? FontWeight.w700 : FontWeight.normal,
                        color: isAtual ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(width: 4),
          // botão próximo
          _buildBotaoPagina(
            icon: Icons.chevron_right,
            onTap: _paginaAtual < _totalPaginas
                ? () => _carregarConversas(pagina: _paginaAtual + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoPagina({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap != null ? AppColors.border : AppColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? AppColors.textSecondary : AppColors.textLight,
        ),
      ),
    );
  }

  Widget _buildLoading(String texto) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(color: AppColors.primaryRed),
      const SizedBox(height: 16),
      Text(texto, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
    ]));
  }

  Widget _buildHeader() {
    final totalNaoLidas = _conversas.where((c) => ChatReadTracker.hasUnread(c.id)).length;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Icon(Icons.support_agent, color: AppColors.primaryRed, size: 28),
      const SizedBox(width: 12),
      const Text('Atendimentos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      const SizedBox(width: 12),
      if (totalNaoLidas > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(20)),
          child: Text('$totalNaoLidas nova${totalNaoLidas != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      const Spacer(),
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () async {
          await _carregarConversas();
        },
        tooltip: 'Atualizar', color: AppColors.textSecondary,
      ),
    ]);
  }

  Widget _buildErrorBanner(String mensagem, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(mensagem, style: const TextStyle(fontSize: 13, color: AppColors.primaryRed))),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ]),
    );
  }

  Widget _buildEmpty(String titulo, String subtitulo) {
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(color: AppColors.lightRed, shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.primaryRed),
        ),
        const SizedBox(height: 20),
        Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text(subtitulo, style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
      ]),
    ));
  }

  Widget _buildLista(List<ConversaModel> lista) {
    final total = lista.length;
    if (context.isDesktop) {
      final metade = (total / 2).ceil();
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: List.generate(metade, (i) => _buildItemConversa(lista[i], i + 1)))),
        const SizedBox(width: 16),
        Expanded(child: Column(children: List.generate(total - metade, (i) => _buildItemConversa(lista[metade + i], metade + i + 1)))),
      ]);
    }
    return Column(children: List.generate(total, (i) => _buildItemConversa(lista[i], i + 1)));
  }

  Widget _buildItemConversa(ConversaModel conv, int numero) {
    final temNaoLida = ChatReadTracker.hasUnread(conv.id);
    final ultima = conv.ultimaMensagem;
    final nomeCliente = conv.clienteNome;
    final accentColors = [AppColors.primaryRed, const Color(0xFF1976D2), const Color(0xFF388E3C), const Color(0xFFF57C00), const Color(0xFF7B1FA2)];
    final accentColor = accentColors[(numero - 1) % accentColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: temNaoLida ? AppColors.primaryRed.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: temNaoLida ? AppColors.primaryRed.withValues(alpha: 0.35) : AppColors.border,
          width: temNaoLida ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _abrirConversa(conv.id),
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // barra lateral
            Container(
              width: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), bottomLeft: Radius.circular(11)),
                border: Border(right: BorderSide(color: accentColor.withValues(alpha: 0.2))),
              ),
              child: Center(child: Text('#$numero', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accentColor))),
            ),
            // conteúdo
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    const Icon(Icons.person_outline, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Expanded(child: Text(
                      nomeCliente ?? 'Sem identificação',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: temNaoLida ? FontWeight.w700 : FontWeight.w600,
                        color: nomeCliente != null ? AppColors.textPrimary : AppColors.textLight,
                        fontStyle: nomeCliente != null ? FontStyle.normal : FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )),
                    if (conv.tipo == 'ESQUEMA_ELETRICO') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF90CAF9)),
                        ),
                        child: const Text(
                          'Esquema',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ],
                    if (temNaoLida) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Nova mensagem', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ] else if (conv.status != null) ...[
                      const SizedBox(width: 8),
                      _buildBadgeStatus(conv.status!),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  if (ultima != null)
                    Text(
                      ultima.remetenteId != conv.clienteId && ultima.remetenteNome != null
                          ? '${ultima.remetenteNome}: ${ultima.preview}' : ultima.preview,
                      style: TextStyle(fontSize: 12, color: temNaoLida ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: temNaoLida ? FontWeight.w500 : FontWeight.normal, height: 1.4),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    )
                  else
                    const Text('Nenhuma mensagem ainda.', style: TextStyle(fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.chat_bubble_outline, size: 11, color: accentColor.withValues(alpha: 0.7)),
                    if (ultima != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.access_time, size: 11, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Text(_formatarData(ultima.createdAt.toIso8601String()),
                          style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                    ],
                  ]),
                ]),
              ),
            ),
            // ação direita
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (temNaoLida) ...[
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle)),
                    const SizedBox(height: 6),
                  ],
                  const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBadgeStatus(String status) {
    Color cor;
    String label;
    switch (status.toUpperCase()) {
      case 'AGUARDANDO': cor = AppColors.statusPending; label = 'Aguardando'; break;
      case 'EM_ATENDIMENTO': cor = const Color(0xFF1976D2); label = 'Em atendimento'; break;
      case 'ENCERRADA':
      case 'CONCLUIDA': cor = AppColors.textLight; label = 'Encerrada'; break;
      default: cor = AppColors.statusPending; label = status;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 7, color: cor),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor)),
    ]);
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
    } catch (_) { return isoDate; }
  }
}