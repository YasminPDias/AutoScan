import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/diagnostic_item.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with user info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Yasmin Dias',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'yasmindias001@gmail.com',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account info
                    const Text(
                      'Informação da Conta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildInfoCard(
                      icon: Icons.business_center,
                      label: 'Tipo de Conta',
                      value: 'Proprietário',
                      valueColor: AppColors.primaryRed,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.calendar_today,
                      label: 'Membro desde',
                      value: 'Janeiro 2026',
                      valueColor: AppColors.primaryRed,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.assessment,
                      label: 'Total Diagnóstico',
                      value: '50',
                      valueColor: AppColors.primaryRed,
                    ),
                    const SizedBox(height: 24),
                    
                    // Recent history
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Histórico Recente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/history');
                          },
                          child: const Text(
                            'Ver mais',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    DiagnosticItem(
                      code: 'Código: P0301',
                      vehicle: 'Toyota Corolla 2020',
                      date: '10/10/2026',
                      status: DiagnosticStatus.resolved,
                    ),
                    DiagnosticItem(
                      code: 'Código: P0301',
                      vehicle: 'Toyota Corolla 2020',
                      date: '10/10/2026',
                      status: DiagnosticStatus.pending,
                    ),
                    DiagnosticItem(
                      code: 'Código: P0301',
                      vehicle: 'Toyota Corolla 2020',
                      date: '10/10/2026',
                      status: DiagnosticStatus.resolved,
                    ),
                    const SizedBox(height: 24),
                    
                    // Account settings
                    const Text(
                      'Configurações da Conta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildSettingItem(
                      icon: Icons.notifications,
                      title: 'Notificações',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {},
                        activeColor: AppColors.primaryRed,
                      ),
                    ),
                    _buildSettingItem(
                      icon: Icons.lock,
                      title: 'Alterar Senha',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      icon: Icons.help,
                      title: 'Ajuda e Suporte',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      icon: Icons.info,
                      title: 'Sobre o App',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),
                    
                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryRed,
                          side: const BorderSide(color: AppColors.primaryRed, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Sair da Conta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textPrimary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
