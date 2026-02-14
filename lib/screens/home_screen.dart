import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../layouts/desktop_layout.dart';
import '../utils/responsive.dart';
import '../widgets/feature_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/home',
      title: context.isDesktop ? '' : 'Home',
      showAppBar: !context.isDesktop,
      child: Container(
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
          child: context.isDesktop
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context),
        ),
      ),
    );
  }

  // Desktop layout with enhanced design
  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced Hero Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(56),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primaryRed,
                Color(0xFFB71C1C), // Darker red
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon with glassmorphism effect
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  size: 70,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bem-vindo ao AutoScan',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sistema Profissional de Diagnóstico Automotivo',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildStatBadge('1000+', 'Diagnósticos'),
                        const SizedBox(width: 24),
                        _buildStatBadge('24/7', 'Suporte'),
                        const SizedBox(width: 24),
                        _buildStatBadge('IA', 'Avançada'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        
        // Section title
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Recursos Principais',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Feature cards grid
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 1.3,
          children: [
            _buildEnhancedFeatureCard(
              icon: Icons.analytics_outlined,
              title: 'Diagnósticos Inteligente',
              description: 'Análise completa e precisa do seu veículo',
              color: AppColors.primaryRed,
              onTap: () => Navigator.pushNamed(context, '/diagnostic'),
            ),
            _buildEnhancedFeatureCard(
              icon: Icons.chat_bubble_outline,
              title: 'Chat com Especialista',
              description: 'Tire dúvidas com IA e mecânicos',
              color: const Color(0xFF1976D2),
              onTap: () => Navigator.pushNamed(context, '/chat'),
            ),
            _buildEnhancedFeatureCard(
              icon: Icons.description_outlined,
              title: 'Planos e Assinaturas',
              description: 'Conheça nossos planos',
              color: const Color(0xFF388E3C),
              onTap: () => Navigator.pushNamed(context, '/plans'),
            ),
            _buildEnhancedFeatureCard(
              icon: Icons.history,
              title: 'Histórico Completo',
              description: 'Acesse todos os diagnósticos',
              color: const Color(0xFFE64A19),
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
            _buildEnhancedFeatureCard(
              icon: Icons.support_agent,
              title: 'Suporte 24/7',
              description: 'Assistência sempre disponível',
              color: const Color(0xFF7B1FA2),
              onTap: () => Navigator.pushNamed(context, '/chat'),
            ),
            _buildEnhancedFeatureCard(
              icon: Icons.trending_up,
              title: 'Relatórios Detalhados',
              description: 'Análises e estatísticas',
              color: const Color(0xFF00796B),
              onTap: () => Navigator.pushNamed(context, '/dashboard'),
            ),
          ],
        ),
      ],
    );
  }

  // Original simple mobile layout
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Red banner - centered content
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.primaryRed,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.directions_car,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bem-vindo ao AutoScan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sistema Profissional de Diagnóstico Automotivo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Section title
        const Text(
          'Recursos Principais',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        // Feature cards
        FeatureCard(
          icon: Icons.analytics_outlined,
          title: 'Diagnósticos Inteligente',
          description: 'Análise completa e precisa do seu veículo com tecnologia avançada',
          onTap: () => Navigator.pushNamed(context, '/diagnostic'),
        ),

        const SizedBox(height: 20),
        FeatureCard(
          icon: Icons.chat_bubble_outline,
          title: 'Chat com Especialista',
          description: 'Tire suas dúvidas com IA ou abra um chamado e aguarde um mecânico especializado',
          onTap: () => Navigator.pushNamed(context, '/chat'),
        ),
        const SizedBox(height: 20),
        FeatureCard(
          icon: Icons.description_outlined,
          title: 'Planos e Assinaturas',
          description: 'Conheça nossos planos e fique por dentro de todas as funcionalidades',
          onTap: () => Navigator.pushNamed(context, '/plans'),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
