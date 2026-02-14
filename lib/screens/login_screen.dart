import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../utils/responsive.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.isDesktop ? 450 : double.infinity,
              ),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(context.isDesktop ? 48 : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: context.isDesktop ? 140 : 120,
                        height: context.isDesktop ? 140 : 120,
                        decoration: BoxDecoration(
                          color: AppColors.iconBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Icon(
                          Icons.directions_car,
                          size: context.isDesktop ? 72 : 64,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Title
                      Text(
                        'AutoScan',
                        style: TextStyle(
                          fontSize: context.isDesktop ? 32 : 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Diagnóstico Inteligentes de Veículos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Username field
                      const CustomTextField(
                        hintText: 'Username',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      
                      // Password field
                      const CustomTextField(
                        hintText: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      
                      // Login button
                      CustomButton(
                        text: 'Login',
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Register link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Não tem uma conta?',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text(
                              'Cadastrar-se',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
