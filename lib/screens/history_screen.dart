import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../layouts/desktop_layout.dart';
import '../utils/responsive.dart';
import '../widgets/diagnostic_item.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final diagnosticItems = [
      {'code': 'P0301', 'vehicle': 'Toyota Corolla 2020', 'date': '10/10/2026', 'status': DiagnosticStatus.resolved},
      {'code': 'P0420', 'vehicle': 'Ford Fiesta 2018', 'date': '09/10/2026', 'status': DiagnosticStatus.pending},
      {'code': 'P0171', 'vehicle': 'Honda Civic 2019', 'date': '08/10/2026', 'status': DiagnosticStatus.resolved},
      {'code': 'P0128', 'vehicle': 'Chevrolet Onix 2021', 'date': '07/10/2026', 'status': DiagnosticStatus.urgent},
      {'code': 'P0442', 'vehicle': 'Volkswagen Gol 2020', 'date': '06/10/2026', 'status': DiagnosticStatus.resolved},
      {'code': 'P0300', 'vehicle': 'Fiat Argo 2022', 'date': '05/10/2026', 'status': DiagnosticStatus.pending},
      {'code': 'P0455', 'vehicle': 'Hyundai HB20 2021', 'date': '04/10/2026', 'status': DiagnosticStatus.resolved},
      {'code': 'P0401', 'vehicle': 'Nissan Kicks 2020', 'date': '03/10/2026', 'status': DiagnosticStatus.resolved},
      {'code': 'P0507', 'vehicle': 'Renault Kwid 2019', 'date': '02/10/2026', 'status': DiagnosticStatus.pending},
      {'code': 'P0340', 'vehicle': 'Jeep Compass 2021', 'date': '01/10/2026', 'status': DiagnosticStatus.resolved},
    ];

    return DesktopLayout(
      currentRoute: '/history',
      title: '',
      showAppBar: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop
            ? null
            : AppBar(
                title: const Text('Histórico'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Voltar',
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Histórico Completo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Items in 2 columns on desktop, 1 column on mobile
              context.isDesktop
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 4.0,
                      ),
                      itemCount: diagnosticItems.length,
                      itemBuilder: (context, index) {
                        final item = diagnosticItems[index];
                        return DiagnosticItem(
                          code: 'Código: ${item['code']}',
                          vehicle: item['vehicle'] as String,
                          date: item['date'] as String,
                          status: item['status'] as DiagnosticStatus,
                          onTap: () {},
                        );
                      },
                    )
                  : Column(
                      children: diagnosticItems.map((item) {
                        return DiagnosticItem(
                          code: 'Código: ${item['code']}',
                          vehicle: item['vehicle'] as String,
                          date: item['date'] as String,
                          status: item['status'] as DiagnosticStatus,
                          onTap: () {},
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
