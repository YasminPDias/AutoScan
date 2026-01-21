import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/diagnostic_item.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Histórico'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
        ],
      ),
    );
  }
}
