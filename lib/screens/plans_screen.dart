import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String selectedPlan = 'professional'; // Default selected plan

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Escolha seu plano'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Desconto!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Desbloqueie todo o potencial do AutoScan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Basic plan
            _buildPlanCard(
              planId: 'basic',
              title: 'Básico',
              price: 'R\$ 29,90',
              period: '/mês',
              features: [
                '10 diagnósticos por mês',
                'Histórico de 30 dias',
                'Suporte por email',
                'Acesso ao chat básico',
              ],
            ),
            const SizedBox(height: 16),
            
            // Professional plan (default selected)
            _buildPlanCard(
              planId: 'professional',
              title: 'Profissional',
              price: 'R\$ 59,90',
              period: '/mês',
              features: [
                'Diagnósticos ilimitados',
                'Histórico completo',
                'Suporte prioritário 24/7',
                'Chat avançado com IA',
                'Relatórios detalhados',
                'Etiquetas de dados',
              ],
            ),
            const SizedBox(height: 16),
            
            // Enterprise plan
            _buildPlanCard(
              planId: 'enterprise',
              title: 'Enterprise',
              price: 'R\$ 149,90',
              period: '/mês',
              features: [
                'Tudo do Profissional',
                'Múltiplos usuários (até 10)',
                'API de integração',
                'Dashboard administrativo',
                'Consultoria técnica',
                'SLA garantido',
                'Backup automático',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String planId,
    required String title,
    required String price,
    required String period,
    required List<String> features,
  }) {
    final bool isSelected = selectedPlan == planId;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlan = planId;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          color: AppColors.cardWhite,
        ),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primaryRed : AppColors.textPrimary,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    Text(
                      period,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check,
                            size: 20,
                            color: isSelected ? AppColors.primaryRed : AppColors.textSecondary,
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle subscription
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? AppColors.primaryRed
                          : AppColors.cardWhite,
                      foregroundColor: isSelected
                          ? Colors.white
                          : AppColors.primaryRed,
                      side: isSelected
                          ? null
                          : const BorderSide(color: AppColors.primaryRed),
                    ),
                    child: const Text('Assinar já!'),
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
