import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppSidebar extends StatelessWidget {
  final String currentRoute;
  
  const AppSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo section
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    size: 28,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AutoScan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(
                  context,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  route: '/home',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  route: '/dashboard',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics,
                  label: 'Diagnóstico',
                  route: '/diagnostic',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.chat_outlined,
                  activeIcon: Icons.chat,
                  label: 'Chat',
                  route: '/chat',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: 'Histórico',
                  route: '/history',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.description_outlined,
                  activeIcon: Icons.description,
                  label: 'Planos',
                  route: '/plans',
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildNavItem(
                  context,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Perfil',
                  route: '/profile',
                ),
              ],
            ),
          ),
          
          // User profile section at bottom
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryRed,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Yasmin Dias',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Proprietário',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  tooltip: 'Sair',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
  }) {
    final isActive = currentRoute == route;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isActive) {
              Navigator.pushReplacementNamed(context, route);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? AppColors.lightRed : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 22,
                  color: isActive ? AppColors.primaryRed : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? AppColors.primaryRed : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
