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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.iconBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: const Icon(
                  Icons.build_circle,
                  color: AppColors.textPrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      vehicle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  _getStatusText(),
                  style: const TextStyle(
                    fontSize: 11,
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
