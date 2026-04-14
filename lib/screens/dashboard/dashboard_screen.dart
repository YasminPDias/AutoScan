import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../widgets_defaults/diagnostic_item.dart';
import '../../services/auth_storage.dart';
import '../../services/diagnostic_service.dart';
import '../../services/chat_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
  int _inconclusivos = 0;
  int _conversasAbertas = 0;

  // Listas
  List<Map<String, dynamic>> _casosAbertos = [];
  Map<String, int> _porDia = {};

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

    // Carrega diagnósticos e conversas em paralelo
    final futures = <Future>[
      isAdmin
          ? DiagnosticService.buscarTodoHistorico(token: token)
          : DiagnosticService.buscarMeuHistorico(token: token),
      if (isAdmin) ChatService.buscarTodasConversas(token: token),
    ];

    final results = await Future.wait(futures);
    if (!mounted) return;

    final diagResult = results[0] as Map<String, dynamic>;
    final List<Map<String, dynamic>> diagnosticos = [];

    if (diagResult['success'] == true) {
      final rawList = diagResult['data'] as List;
      for (final item in rawList) {
        if (item is Map<String, dynamic>) diagnosticos.add(item);
      }
    }

    // Conta conversas abertas (admin)
    int conversasAbertas = 0;
    if (isAdmin && results.length > 1) {
      final convResult = results[1] as Map<String, dynamic>;
      if (convResult['success'] == true) {
        final convList = convResult['data'] as List;
        conversasAbertas = convList.where((c) {
          final status = (c as Map<String, dynamic>)['status']?.toString() ?? '';
          return status != 'ENCERRADA' && status != 'FECHADA' && status != 'CONCLUIDA';
        }).length;
      }
    }

    // Estatísticas
    int total = diagnosticos.length;
    int pendentes = 0;
    int resolvidos = 0;
    int inconclusivos = 0;
    final List<Map<String, dynamic>> casosAbertos = [];
    final Map<String, int> porDia = {};

    final hoje = DateTime.now();
    // Inicializa os últimos 7 dias com zero
    for (int i = 6; i >= 0; i--) {
      final dia = hoje.subtract(Duration(days: i));
      final key = _diaKey(dia);
      porDia[key] = 0;
    }

    for (final item in diagnosticos) {
      final status = item['status']?.toString() ?? '';
      final createdAt = item['createdAt']?.toString() ?? '';

      switch (status) {
        case 'CONCLUIDO':
          resolvidos++;
          break;
        case 'INCONCLUSIVO':
          inconclusivos++;
          casosAbertos.add(item);
          break;
        case 'PENDENTE':
        case 'EM_ANALISE':
        default:
          if (status.isNotEmpty) pendentes++;
          casosAbertos.add(item);
      }

      // Agrupa por dia (últimos 7 dias)
      if (createdAt.isNotEmpty) {
        try {
          final dt = DateTime.parse(createdAt);
          final key = _diaKey(dt);
          if (porDia.containsKey(key)) {
            porDia[key] = (porDia[key] ?? 0) + 1;
          }
        } catch (_) {}
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
        _inconclusivos = inconclusivos;
        _conversasAbertas = conversasAbertas;
        _casosAbertos = casosAbertos.take(5).toList();
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

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/dashboard',
      title: 'Dashboard',
      showAppBar: !context.isDesktop,
      child: Container(
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
      ),
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
        value: '$_inconclusivos',
        label: 'Inconclusivos',
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

    final crossCount = context.isDesktop ? 4 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: context.isDesktop ? 20 : 12,
        crossAxisSpacing: context.isDesktop ? 20 : 12,
        childAspectRatio: context.isDesktop ? 1.6 : 1.3,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => _buildStatCard(cards[i]),
    );
  }

  Widget _buildStatCard(_StatData data) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: 20, color: data.color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: data.color,
                ),
              ),
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
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

    return Column(
      children: _casosAbertos.map((item) {
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
            onTap: () => Navigator.pushNamed(
              context,
              '/diagnostic-result',
              arguments: item,
            ),
          ),
        );
      }).toList(),
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
