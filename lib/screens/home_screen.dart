import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/feature_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AutoScan'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bem-vindo ao AutoScan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sistema Profissional de Diagnóstico\nAutomotivo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Resources section
            const Text(
              'Recursos Principais',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            FeatureCard(
              icon: Icons.analytics,
              title: 'Diagnósticos Inteligente',
              description: 'Analise completa e precisa do seu veículo com tecnologia avançada',
              onTap: () {
                Navigator.pushNamed(context, '/diagnostic');
              },
            ),
            const SizedBox(height: 12),
            
            FeatureCard(
              icon: Icons.chat,
              title: 'Chat com Especialista',
              description: 'Tire suas dúvidas com IA ou abra um chamado e aguarde um mecânico especializado',
              onTap: () {
                Navigator.pushNamed(context, '/chat');
              },
            ),
            const SizedBox(height: 12),
            
            FeatureCard(
              icon: Icons.edit_document,
              title: 'Planos e Assinaturas',
              description: 'Conheça nossos planos e fique por dentro de todas as funcionalidades',
              onTap: () {
                Navigator.pushNamed(context, '/plans');
              },
            ),
          ],
        ),
      ),
    );
  }
}
