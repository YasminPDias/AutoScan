import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum DiagnosticStatus { resolved, pending, urgent }

class DiagnosticItem extends StatelessWidget {
  final String code;
  final String vehicle;
  final String date;
  final DiagnosticStatus status;
  final VoidCallback? onTap;

  const DiagnosticItem({
    super.key,
    required this.code,
    required this.vehicle,
    required this.date,
    required this.status,
    this.onTap,
  });

  Color _getStatusColor() {
    switch (status) {
      case DiagnosticStatus.resolved:
        return AppColors.statusResolved;
      case DiagnosticStatus.pending:
        return AppColors.statusPending;
      case DiagnosticStatus.urgent:
        return AppColors.statusUrgent;
    }
  }

  String _getStatusText() {
    switch (status) {
      case DiagnosticStatus.resolved:
        return 'Resolvido';
      case DiagnosticStatus.pending:
        return 'Pendente';
      case DiagnosticStatus.urgent:
        return 'Urgente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                  Icons.build_circle,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
