import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../widgets_defaults/diagnostic_item.dart';
import '../../services/auth_storage.dart';
import '../../services/diagnostic_service.dart';
import '../../services/chat_service.dart';
import '../../services/dashboard_service.dart';

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

  // Listas
  List<Map<String, dynamic>> _casosAbertos = [];
  Map<String, int> _porDia = {};
  bool _mostrarTodosCasos = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  bool get _isAdminOrAssistente {
    final role = _userRole.toUpperCase();
    return role == 'ADMIN' || role == 'ASSISTENTE';
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

    // Carrega resumo do dashboard, histórico semanal, histórico de diagnósticos e conversas em paralelo
    final futures = <Future>[
      DashboardService.buscarResumoDiagnosticos(token: token),
      DashboardService.buscarHistoricoSemanal(token: token),
      isAdmin
          ? DiagnosticService.buscarTodoHistorico(token: token)
          : DiagnosticService.buscarMeuHistorico(token: token),
      if (isAdmin) ChatService.buscarTodasConversas(token: token),
    ];

    final results = await Future.wait(futures);
    if (!mounted) return;

    final summaryResult = results[0] as Map<String, dynamic>;
    final histResult = results[1] as Map<String, dynamic>;
    final diagResult = results[2] as Map<String, dynamic>;

    // Estatísticas da API
    int total = 0;
    int pendentes = 0;
    int resolvidos = 0;
    int emAberto = 0;

    if (summaryResult['success'] == true && summaryResult['data'] != null) {
      final data = summaryResult['data'] as Map<String, dynamic>;
      total = int.tryParse(data['total']?.toString() ?? '0') ?? 0;
      pendentes = int.tryParse(data['pendentes']?.toString() ?? '0') ?? 0;
      resolvidos = int.tryParse(data['resolvidos']?.toString() ?? '0') ?? 0;
      emAberto = int.tryParse(data['emAberto']?.toString() ?? '0') ?? 0;
    }

    // Histórico por dia (últimos 7 dias) da API
    final Map<String, int> porDia = {};
    final hoje = DateTime.now();
    // Inicializa com zero os últimos 7 dias por segurança
    for (int i = 6; i >= 0; i--) {
      final dia = hoje.subtract(Duration(days: i));
      final key = _diaKey(dia);
      porDia[key] = 0;
    }

    if (histResult['success'] == true && histResult['data'] != null) {
      final List rawList = histResult['data'] as List;
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final dataStr = item['data']?.toString() ?? '';
          final totalVal = int.tryParse(item['total']?.toString() ?? '0') ?? 0;
          if (dataStr.isNotEmpty) {
            porDia[dataStr] = totalVal;
          }
        }
      }
    }

    // Diagnósticos para extrair a lista física de casos em aberto
    final List<Map<String, dynamic>> diagnosticos = [];
    if (diagResult['success'] == true && diagResult['data'] != null) {
      final rawList = diagResult['data'] as List;
      for (final item in rawList) {
        if (item is Map<String, dynamic>) diagnosticos.add(item);
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

    // Casos em aberto para listagem (status diferente de CONCLUIDO)
    final List<Map<String, dynamic>> casosAbertos = [];
    for (final item in diagnosticos) {
      final status = item['status']?.toString() ?? '';
      if (status != 'CONCLUIDO') {
        casosAbertos.add(item);
      }
    }

    // Ordena casos abertos por data decrescente e limita a 5
    casosAbertos.sort((a, b) {
      final da = a['createdAt']?.toString() ?? '';
      final db = b['createdAt']?.toString() ?? '';
      return db.compareTo(da);
    });

    if (mounted) {
      setState(() {
        _totalDiagnosticos = total;
        _pendentes = pendentes;
        _resolvidos = resolvidos;
        _emAberto = emAberto;
        _conversasAbertas = conversasAbertas;
        _casosAbertos = casosAbertos;
        _porDia = porDia;
        _isLoading = false;
      });
    }
  }

  String _diaKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _diaLabel(String key) {
    try {
      final parts = key.split('-');
      final dt = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      const dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
      return '${dias[dt.weekday % 7]} ${dt.day}/${dt.month}';
    } catch (_) {
      return key;
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
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
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primaryRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
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
      _StatData(
        icon: Icons.assessment_outlined,
        value: '$_totalDiagnosticos',
        label: 'Total Diagnósticos',
        color: AppColors.primaryRed,
      ),
      _StatData(
        icon: Icons.hourglass_empty_outlined,
        value: '$_pendentes',
        label: 'Pendentes',
        color: const Color(0xFFE65100),
      ),
      _StatData(
        icon: Icons.check_circle_outline,
        value: '$_resolvidos',
        label: 'Resolvidos',
        color: const Color(0xFF388E3C),
      ),
      _StatData(
        icon: Icons.warning_amber_outlined,
        value: '$_emAberto',
        label: 'Casos em Aberto',
        color: const Color(0xFFF9A825),
      ),
      if (_isAdminOrAssistente)
        _StatData(
          icon: Icons.chat_outlined,
          value: '$_conversasAbertas',
          label: 'Conversas Abertas',
          color: const Color(0xFF1976D2),
        ),
    ];

    final crossCount = context.isDesktop ? 5 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: context.isDesktop ? 12 : 12,
        crossAxisSpacing: context.isDesktop ? 12 : 12,
        childAspectRatio: context.isDesktop ? 1.35 : 1.3,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: 18, color: data.color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: context.isDesktop ? 22 : 28,
                  fontWeight: FontWeight.bold,
                  color: data.color,
                ),
              ),
              Text(
                data.label,
                style: TextStyle(
                  fontSize: context.isDesktop ? 11 : 12,
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
    if (_casosAbertos.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: const Color(0xFF388E3C).withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text(
              'Nenhum caso em aberto',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
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
        ...listaExibicao.map((item) {
          final dados = item['dadosParaDiagnostico'] as Map<String, dynamic>? ?? {};
          final codigo = dados['codigoODB2']?.toString() ?? '';
          final marca = dados['marcaVeiculo']?.toString() ?? '';
          final modelo = dados['modeloVeiculo']?.toString() ?? '';
          final ano = dados['anoVeiculo']?.toString() ?? '';
          final createdAt = item['createdAt']?.toString() ?? '';
          final status = item['status']?.toString() ?? 'PENDENTE';
          final usuario = item['usuario'] as Map<String, dynamic>?;
          final nomeUsuario = usuario?['nome']?.toString() ?? '';

          DiagnosticStatus diagStatus;
          switch (status) {
            case 'CONCLUIDO':
              diagStatus = DiagnosticStatus.resolved;
              break;
            case 'INCONCLUSIVO':
              diagStatus = DiagnosticStatus.urgent;
              break;
            default:
              diagStatus = DiagnosticStatus.pending;
          }

          final vehicleLabel = [marca, modelo, ano].where((s) => s.isNotEmpty).join(' ');
          final displayVehicle = nomeUsuario.isNotEmpty
              ? '$vehicleLabel\nCliente: $nomeUsuario'
              : vehicleLabel;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DiagnosticItem(
              code: codigo.isNotEmpty ? 'Código: $codigo' : 'Sem código',
              vehicle: displayVehicle,
              date: _formatDate(createdAt),
              status: diagStatus,
              onTap: () => _abrirChatDoCaso(item),
            ),
          );
        }).toList(),
        if (temMais)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _mostrarTodosCasos = !_mostrarTodosCasos;
                  });
                },
                icon: Icon(
                  _mostrarTodosCasos ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.primaryRed,
                ),
                label: Text(
                  _mostrarTodosCasos
                      ? 'Ver Menos'
                      : 'Ver Mais (${_casosAbertos.length - limite} restante${(_casosAbertos.length - limite) > 1 ? 's' : ''})',
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Sem dados disponíveis',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : Column(
              children: entries.map((entry) {
                final frac = maxVal > 0 ? entry.value / maxVal : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          _diaLabel(entry.key),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: frac.clamp(0.0, 1.0),
                              child: Container(
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${entry.value}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
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

  const _StatData({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}
