import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String userType = 'mecanico';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Diagnóstico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textSecondary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Preencha os dados do Veículo para o diagnóstico',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Form fields
            const Text(
              'Código OBD2 *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const CustomTextField(
              hintText: '',
              icon: Icons.code,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Marca *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const CustomTextField(
              hintText: '',
              icon: Icons.directions_car,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Modelo *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const CustomTextField(
              hintText: '',
              icon: Icons.directions_car,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Ano *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const CustomTextField(
              hintText: '',
              icon: Icons.calendar_today,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Sintomas Observados *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '',
                filled: true,
                fillColor: AppColors.cardWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Tipo de Usuário *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            
            // Radio buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Mecânico'),
                      value: 'mecanico',
                      groupValue: userType,
                      activeColor: AppColors.primaryRed,
                      onChanged: (value) {
                        setState(() {
                          userType = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Proprietário'),
                      value: 'proprietario',
                      groupValue: userType,
                      activeColor: AppColors.primaryRed,
                      onChanged: (value) {
                        setState(() {
                          userType = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Checkbox
            Card(
              child: CheckboxListTile(
                title: const Text(
                  'Socorro na Estrada',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Se marque se estiver na estrada e estiver precisando de ajuda urgente',
                  style: TextStyle(fontSize: 12),
                ),
                value: false,
                activeColor: AppColors.primaryRed,
                onChanged: (value) {},
              ),
            ),
            const SizedBox(height: 24),
            
            // Submit button
            CustomButton(
              text: 'Gerar diagnóstico',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
