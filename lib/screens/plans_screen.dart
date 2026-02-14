import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../layouts/desktop_layout.dart';
import '../utils/responsive.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  int selectedPlan = 1; // 0: Basic, 1: Professional, 2: Enterprise

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/plans',
      title: 'Planos e Assinaturas',
      showAppBar: !context.isDesktop,
      child: Container(
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Center(
                child: Column(
                  children: [
                    Text(
                      'Escolha o Plano Ideal',
                      style: TextStyle(
                        fontSize: context.isDesktop ? 32 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecione o plano que melhor atende suas necessidades',
                      style: TextStyle(
                        fontSize: context.isDesktop ? 16 : 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // Plans cards
              context.isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildPlanCard(
                            index: 0,
                            title: 'Básico',
                            price: 'R\$ 29,90',
                            period: '/mês',
                            features: [
                              '5 diagnósticos por mês',
                              'Chat com IA',
                              'Histórico de 30 dias',
                              'Suporte por email',
                            ],
                            isPopular: false,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Transform.scale(
                            scale: 1.05,
                            child: _buildPlanCard(
                              index: 1,
                              title: 'Profissional',
                              price: 'R\$ 59,90',
                              period: '/mês',
                              features: [
                                'Diagnósticos ilimitados',
                                'Chat com IA e mecânicos',
                                'Histórico completo',
                                'Suporte prioritário',
                                'Relatórios detalhados',
                              ],
                              isPopular: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildPlanCard(
                            index: 2,
                            title: 'Empresarial',
                            price: 'R\$ 149,90',
                            period: '/mês',
                            features: [
                              'Tudo do Profissional',
                              'Múltiplos usuários',
                              'API de integração',
                              'Suporte 24/7',
                              'Gerente de conta dedicado',
                            ],
                            isPopular: false,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildPlanCard(
                          index: 0,
                          title: 'Básico',
                          price: 'R\$ 29,90',
                          period: '/mês',
                          features: [
                            '5 diagnósticos por mês',
                            'Chat com IA',
                            'Histórico de 30 dias',
                            'Suporte por email',
                          ],
                          isPopular: false,
                        ),
                        const SizedBox(height: 16),
                        _buildPlanCard(
                          index: 1,
                          title: 'Profissional',
                          price: 'R\$ 59,90',
                          period: '/mês',
                          features: [
                            'Diagnósticos ilimitados',
                            'Chat com IA e mecânicos',
                            'Histórico completo',
                            'Suporte prioritário',
                            'Relatórios detalhados',
                          ],
                          isPopular: true,
                        ),
                        const SizedBox(height: 16),
                        _buildPlanCard(
                          index: 2,
                          title: 'Empresarial',
                          price: 'R\$ 149,90',
                          period: '/mês',
                          features: [
                            'Tudo do Profissional',
                            'Múltiplos usuários',
                            'API de integração',
                            'Suporte 24/7',
                            'Gerente de conta dedicado',
                          ],
                          isPopular: false,
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required bool isPopular,
  }) {
    final isSelected = selectedPlan == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlan = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isPopular || isSelected)
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with popular badge
            if (isPopular)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: const Text(
                  'MAIS POPULAR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          period,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Features list
                  ...features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 24),
                  
                  // Select button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedPlan = index;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? AppColors.primaryRed
                            : Colors.white,
                        foregroundColor: isSelected
                            ? Colors.white
                            : AppColors.primaryRed,
                        side: BorderSide(
                          color: AppColors.primaryRed,
                          width: isSelected ? 0 : 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.check, size: 20),
                            ),
                          Text(
                            isSelected ? 'Selecionado' : 'Selecionar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
