import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/auth_storage.dart';
import '../../services/diagnostic_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/chat_service.dart';

class DashboardScreen extends StatefulWidget {
  final bool isEmbedded;
  const DashboardScreen({super.key, this.isEmbedded = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String _userRole = '';

  // Stats
  int _totalDiagnosticos = 0;
  int _pendentes = 0;
  int _resolvidos = 0;
  int _emAberto = 0;
  int _conversasAbertas = 0;

  bool get _isAdminOrAssistente {
    final role = _userRole.toUpperCase();
    return role == 'ADMIN' || role == 'ASSISTENTE';
  }

  // Casos em aberto — paginação no servidor
  List<Map<String, dynamic>> _casosAbertos = [];
  bool _isLoadingCasos = false;
  int _paginaCasos = 1;
  int _totalPaginasCasos = 1;
  static const int _porPaginaCasos = 10;

  Map<String, int> _porDia = {};
  bool _mostrarTodosCasos = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _isLoading = true);

    final token = await AuthStorage.getToken();
    final role = await AuthStorage.getUserRole();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _userRole = role ?? '');

    final isAdmin =
        (role ?? '').toUpperCase() == 'ADMIN' ||
        (role ?? '').toUpperCase() == 'ASSISTENTE';

    final results = await Future.wait([
      DashboardService.buscarResumoDiagnosticos(token: token),
      DashboardService.buscarHistoricoSemanal(token: token),
      DiagnosticService.buscarDiagnosticosAbertosAdmin(token: token, pagina: 1, porPagina: _porPaginaCasos),
      if (isAdmin) ChatService.buscarTodasConversas(token: token),
    ]);

    if (!mounted) return;

    // stats
    final summaryResult = results[0] as Map<String, dynamic>;
    if (summaryResult['success'] == true && summaryResult['data'] != null) {
      final data = summaryResult['data'] as Map<String, dynamic>;
      _totalDiagnosticos = int.tryParse(data['total']?.toString() ?? '0') ?? 0;
      _pendentes = int.tryParse(data['pendentes']?.toString() ?? '0') ?? 0;
      _resolvidos = int.tryParse(data['resolvidos']?.toString() ?? '0') ?? 0;
      _emAberto = int.tryParse(data['emAberto']?.toString() ?? '0') ?? 0;
    }

    // gráfico semanal
    final Map<String, int> porDia = {};
    final hoje = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final dia = hoje.subtract(Duration(days: i));
      porDia[_diaKey(dia)] = 0;
    }
    final histResult = results[1] as Map<String, dynamic>;
    if (histResult['success'] == true && histResult['data'] != null) {
      for (final item in histResult['data'] as List) {
        if (item is Map<String, dynamic>) {
          final dataStr = item['data']?.toString() ?? '';
          final val = int.tryParse(item['total']?.toString() ?? '0') ?? 0;
          if (dataStr.isNotEmpty) porDia[dataStr] = val;
        }
      }
    }

    // casos em aberto (primeira página)
    final casosResult = results[2] as Map<String, dynamic>;
    final List<Map<String, dynamic>> casos = [];
    int totalPaginas = 1;
    if (casosResult['success'] == true) {
      final data = casosResult['data'];
      if (data is Map) {
        final lista = data['dados'] as List? ?? [];
        for (final item in lista) {
          if (item is Map<String, dynamic>) casos.add(item);
        }
        totalPaginas = int.tryParse(data['totalPaginas']?.toString() ?? '1') ?? 1;
      }
    }

    // Conta conversas abertas (admin)
    int conversasAbertas = 0;
    if (isAdmin && results.length > 3) {
      final convResult = results[3] as Map<String, dynamic>;
      if (convResult['success'] == true && convResult['data'] != null) {
        final convList = convResult['data'] as List;
        conversasAbertas = convList.where((c) {
          final status = (c as Map<String, dynamic>)['status']?.toString() ?? '';
          return status != 'ENCERRADA' && status != 'FECHADA' && status != 'CONCLUIDA';
        }).length;
      }
    }

    if (mounted) {
      setState(() {
        _porDia = porDia;
        _casosAbertos = casos;
        _paginaCasos = 1;
        _totalPaginasCasos = totalPaginas;
        _conversasAbertas = conversasAbertas;
        _isLoading = false;
      });
    }
  }

Future<void> _irParaPaginaCasos(int pagina) async {
    if (_isLoadingCasos) return;
    setState(() => _isLoadingCasos = true);

    final token = await AuthStorage.getToken();
    if (token == null) { setState(() => _isLoadingCasos = false); return; }

    final result = await DiagnosticService.buscarDiagnosticosAbertosAdmin(
      token: token, pagina: pagina, porPagina: _porPaginaCasos,
    );

    if (!mounted) return;

    // ← usa == true em vez de is bool pra evitar null
    if (result['success'] == true) {
      final data = result['data'];
      final lista = <Map<String, dynamic>>[];
      int totalPaginas = _totalPaginasCasos;
      if (data is Map) {
        for (final item in (data['dados'] as List? ?? [])) {
          if (item is Map<String, dynamic>) lista.add(item);
        }
        totalPaginas = int.tryParse(data['totalPaginas']?.toString() ?? '1') ?? 1;
      }
      setState(() {
        _casosAbertos = lista;
        _paginaCasos = pagina;
        _totalPaginasCasos = totalPaginas;
        _isLoadingCasos = false;
      });
    } else {
      setState(() => _isLoadingCasos = false);
    }
  }

  String _diaKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _diaLabel(String key) {
    try {
      final parts = key.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
      return '${dias[dt.weekday % 7]} ${dt.day}/${dt.month}';
    } catch (_) { return key; }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return isoDate; }
  }

  void _abrirChatDoCaso(Map<String, dynamic> item) {
    final diagnosticoId = item['id']?.toString() ?? item['_id']?.toString();
    final conversa = item['conversa'] as Map<String, dynamic>?;
    final conversaId = conversa?['id']?.toString() ?? conversa?['_id']?.toString();

    if (conversaId != null && conversaId.isNotEmpty) {
      Navigator.pushNamed(context, '/chat', arguments: {'conversaId': conversaId});
    } else if (diagnosticoId != null && diagnosticoId.isNotEmpty) {
      final diagnosticoTexto = item['diagnostico']?.toString() ?? item['resultadoIA']?.toString();
      Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'diagnosticoId': diagnosticoId,
          'diagnosticoTexto': diagnosticoTexto,
        },
      );
    } else {
      Navigator.pushNamed(context, '/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Container(
      color: AppColors.background,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            )
          : RefreshIndicator(
              onRefresh: _carregar,
              color: AppColors.primaryRed,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Visão Geral'),
                    const SizedBox(height: 16),
                    _buildStatGrid(context),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Casos em Aberto'),
                    const SizedBox(height: 16),
                    _buildCasosAbertos(context),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Diagnósticos — Últimos 7 Dias'),
                    const SizedBox(height: 16),
                    _buildBarChart(),
                  ],
                ),
              ),
            ),
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return DesktopLayout(
      currentRoute: '/dashboard',
      title: 'Dashboard',
      showAppBar: !context.isDesktop,
      child: bodyContent,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: _carregar,
          color: AppColors.textSecondary,
          tooltip: 'Atualizar',
        ),
      ],
    );
  }

  Widget _buildStatGrid(BuildContext context) {
    final cards = [
      _StatData(icon: Icons.assessment_outlined, value: '$_totalDiagnosticos', label: 'Total Diagnósticos', color: AppColors.primaryRed),
      _StatData(icon: Icons.hourglass_empty_outlined, value: '$_pendentes', label: 'Pendentes', color: const Color(0xFFE65100)),
      _StatData(icon: Icons.check_circle_outline, value: '$_resolvidos', label: 'Resolvidos', color: const Color(0xFF388E3C)),
      _StatData(icon: Icons.warning_amber_outlined, value: '$_emAberto', label: 'Casos em Aberto', color: const Color(0xFFF9A825)),
      if (_isAdminOrAssistente)
        _StatData(icon: Icons.chat_outlined, value: '$_conversasAbertas', label: 'Conversas Abertas', color: const Color(0xFF1976D2)),
    ];

    final crossCount = _isAdminOrAssistente ? (context.isDesktop ? 5 : 2) : (context.isDesktop ? 4 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: context.isDesktop ? 20 : 12,
        crossAxisSpacing: context.isDesktop ? 20 : 12,
        childAspectRatio: _isAdminOrAssistente
            ? (context.isDesktop ? 1.35 : 1.3)
            : (context.isDesktop ? 1.6 : 1.3),
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => _buildStatCard(cards[i]),
    );
  }

  Widget _buildStatCard(_StatData data) {
    return Container(
      padding: EdgeInsets.all(context.isDesktop ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: data.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(data.icon, size: 20, color: data.color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: _isAdminOrAssistente ? (context.isDesktop ? 22 : 28) : 28,
                  fontWeight: FontWeight.bold,
                  color: data.color,
                ),
              ),
              Text(
                data.label,
                style: TextStyle(
                  fontSize: _isAdminOrAssistente ? (context.isDesktop ? 11 : 12) : 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCasosAbertos(BuildContext context) {
    if (_casosAbertos.isEmpty && !_isLoadingCasos) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: const Color(0xFF388E3C).withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('Nenhum caso em aberto', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    const int limite = 4;
    final bool temMais = _casosAbertos.length > limite;
    final listaExibicao = (_mostrarTodosCasos || !temMais)
        ? _casosAbertos
        : _casosAbertos.take(limite).toList();

    return Column(
      children: [
        if (_isLoadingCasos)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
          )
        else
          ..._casosAbertos.map((item) => _buildCasoItem(context, item)),

        if (_totalPaginasCasos > 1) ...[
          const SizedBox(height: 16),
          _buildPaginacao(),
        ],
      ],
    );
  }

  Widget _buildCasoItem(BuildContext context, Map<String, dynamic> item) {
    final dados = item['dadosParaDiagnostico'] as Map<String, dynamic>? ?? {};
    final codigo = dados['codigoODB2']?.toString() ?? '';
    final marca = dados['marcaVeiculo']?.toString() ?? '';
    final modelo = dados['modeloVeiculo']?.toString() ?? '';
    final ano = dados['anoVeiculo']?.toString() ?? '';
    final createdAt = item['createdAt']?.toString() ?? '';
    final usuario = item['usuario'] as Map<String, dynamic>?;
    final nomeCliente = [
      usuario?['nome']?.toString() ?? '',
      usuario?['sobrenome']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    final conversa = item['conversa'] as Map<String, dynamic>?;
    final conversaStatus = conversa?['status']?.toString();
    final atendenteNome = conversa?['atendenteNome']?.toString();
    final conversaId = conversa?['id']?.toString();

    if (!context.isDesktop) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: ODB2 and Vehicle
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    codigo.isNotEmpty ? codigo.toUpperCase() : 'S/C',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [marca, modelo, ano].where((s) => s.isNotEmpty).join(' '),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Client and Date
            Row(
              children: [
                const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    nomeCliente.isNotEmpty ? nomeCliente : 'Sem identificação',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 13, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            // Status and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: conversaStatus != null
                        ? _buildBadgeConversa(conversaStatus, atendenteNome)
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Sem atendente',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF9A825),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                if (conversaId != null)
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/chat', arguments: {'conversaId': conversaId}),
                    icon: const Icon(Icons.chat_bubble_outline, size: 14),
                    label: const Text('Ver chat', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: AppColors.primaryRed.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/diagnostic-result', arguments: item),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('Ver diagnóstico', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: AppColors.border.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // código ODB2
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              codigo.isNotEmpty ? codigo.toUpperCase() : 'S/C',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryRed),
            ),
          ),
          const SizedBox(width: 12),

          // info principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // veículo
                Text(
                  [marca, modelo, ano].where((s) => s.isNotEmpty).join(' '),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),

                // cliente
                Row(children: [
                  const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    nomeCliente.isNotEmpty ? nomeCliente : 'Sem identificação',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ]),
                const SizedBox(height: 4),

                // data
                Row(children: [
                  const Icon(Icons.access_time, size: 13, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(_formatDate(createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                ]),
              ],
            ),
          ),

          // status da conversa
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (conversaStatus != null)
                _buildBadgeConversa(conversaStatus, atendenteNome)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Sem atendente',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF9A825)),
                  ),
                ),
              const SizedBox(height: 8),
              // botão de ação
              if (conversaId != null)
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/chat', arguments: {'conversaId': conversaId}),
                  icon: const Icon(Icons.chat_bubble_outline, size: 14),
                  label: const Text('Ver chat', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/diagnostic-result', arguments: item),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('Ver diagnóstico', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeConversa(String status, String? atendente) {
    Color cor;
    String label;
    switch (status.toUpperCase()) {
      case 'EM_ATENDIMENTO':
        cor = const Color(0xFF1976D2);
        label = atendente != null ? 'Em atendimento\n$atendente' : 'Em atendimento';
        break;
      case 'AGUARDANDO':
        cor = const Color(0xFFF9A825);
        label = 'Aguardando';
        break;
      default:
        cor = AppColors.textLight;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.end,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor, height: 1.4),
      ),
    );
  }

  Widget _buildPaginacao() {
    final paginas = <int>[];
    int inicio = (_paginaCasos - 2).clamp(1, _totalPaginasCasos);
    int fim = (inicio + 4).clamp(1, _totalPaginasCasos);
    inicio = (fim - 4).clamp(1, _totalPaginasCasos);
    for (int i = inicio; i <= fim; i++) paginas.add(i);

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBotaoPagina(
            icon: Icons.chevron_left,
            onTap: _paginaCasos > 1 ? () => _irParaPaginaCasos(_paginaCasos - 1) : null,
          ),
          const SizedBox(width: 4),
          ...paginas.map((p) {
            final isAtual = p == _paginaCasos;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: isAtual ? null : () => _irParaPaginaCasos(p),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isAtual ? AppColors.primaryRed : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isAtual ? null : Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text('$p', style: TextStyle(
                      fontSize: 13,
                      fontWeight: isAtual ? FontWeight.w700 : FontWeight.normal,
                      color: isAtual ? Colors.white : AppColors.textSecondary,
                    )),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          _buildBotaoPagina(
            icon: Icons.chevron_right,
            onTap: _paginaCasos < _totalPaginasCasos ? () => _irParaPaginaCasos(_paginaCasos + 1) : null,
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
        width: 36, height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap != null ? AppColors.border : AppColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Icon(icon, size: 20, color: onTap != null ? AppColors.textSecondary : AppColors.textLight),
      ),
    );
  }

  Widget _buildBarChart() {
    final entries = _porDia.entries.toList();
    final maxVal = entries.fold<int>(1, (m, e) => e.value > m ? e.value : m);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: entries.isEmpty
          ? const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Sem dados disponíveis', style: TextStyle(color: AppColors.textSecondary)),
            ))
          : Column(
              children: entries.map((entry) {
                final frac = maxVal > 0 ? entry.value / maxVal : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(_diaLabel(entry.key), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(height: 22, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
                            FractionallySizedBox(
                              widthFactor: frac.clamp(0.0, 1.0),
                              child: Container(height: 22, decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(4))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 24,
                        child: Text('${entry.value}', textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatData({required this.icon, required this.value, required this.label, required this.color});
}