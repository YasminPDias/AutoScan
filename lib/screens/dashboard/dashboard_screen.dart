import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../widgets_defaults/stat_card.dart';
import '../../widgets_defaults/diagnostic_item.dart';
import '../../services/auth_storage.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = 'Usuário';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await AuthStorage.getUserName();
    if (!mounted) return;
    setState(() {
      _userName = (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : 'Usuário';
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/dashboard',
      title: 'Dashboard',
      showAppBar: !context.isDesktop,
      child: Container(
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '| Visão Geral',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: context.isDesktop ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: context.isDesktop ? 20 : 12,
                crossAxisSpacing: context.isDesktop ? 20 : 12,
                childAspectRatio: context.isDesktop ? 1.4 : 1.2,
                children: const [
                  StatCard(
                    icon: Icons.assessment,
                    value: '65',
                    label: 'Total Diagnóstico',
                  ),
                  StatCard(
                    icon: Icons.more_horiz,
                    value: '23',
                    label: 'Pendentes',
                  ),
                  StatCard(
                    icon: Icons.check_circle,
                    value: '104',
                    label: 'Resolvidos',
                  ),
                  StatCard(
                    icon: Icons.people,
                    value: '50',
                    label: 'Usuários Ativos',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                '| Casos em Abertos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              DiagnosticItem(
                code: 'Código: P0301',
                vehicle: 'Toyota Corolla 2020\nUsuário: $_userName',
                date: 'Há 18 min',
                status: DiagnosticStatus.urgent,
                onTap: () {},
              ),
              DiagnosticItem(
                code: 'Código: P0420',
                vehicle: 'Ford Fiesta 2018\nUsuário: $_userName',
                date: 'Há 1 hora',
                status: DiagnosticStatus.pending,
                onTap: () {},
              ),
              DiagnosticItem(
                code: 'Código: P0301',
                vehicle: 'Toyota Corolla 2020\nUsuário: $_userName',
                date: 'Há 18 min',
                status: DiagnosticStatus.resolved,
                onTap: () {},
              ),
              const SizedBox(height: 32),
              const Text(
                '| Diagnóstico por Dia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildBarChart(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final data = [
      {'day': 'Seg', 'value': 12},
      {'day': 'Ter', 'value': 18},
      {'day': 'Qua', 'value': 15},
      {'day': 'Qui', 'value': 22},
      {'day': 'Sex', 'value': 20},
      {'day': 'Sáb', 'value': 8},
      {'day': 'Dom', 'value': 5},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: data.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      item['day'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: (item['value'] as int) / 25,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${item['value']}',
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
      ),
    );
  }
}
