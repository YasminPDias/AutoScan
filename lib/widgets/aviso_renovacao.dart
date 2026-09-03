import 'package:autex/screens/payment/assinatura_store.dart';
import 'package:flutter/material.dart';

import 'package:autex/models/resultado_assinatura.dart';

import 'package:autex/theme/app_colors.dart';

/// Aviso de vencimento próximo.
///
/// Pix e boleto NÃO renovam sozinhos: sem este aviso, o cliente que pagou
/// boleto simplesmente perde o acesso na data e só descobre quando tenta usar.
///
/// ⚠️ Alcança apenas quem abrir o app. Quem pagou e não voltou continua sem
/// aviso — o furo que o e-mail fecha depois.
class AvisoRenovacao extends StatelessWidget {
  const AvisoRenovacao({super.key, this.onRenovar});

  /// Normalmente navega para a tela de renovação.
  final VoidCallback? onRenovar;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StatusPagamento?>(
      valueListenable: AssinaturaStore.instancia.status,
      builder: (context, _, __) {
        final store = AssinaturaStore.instancia;
        if (!store.precisaRenovar) return const SizedBox.shrink();

        final dias = store.diasParaVencer ?? 0;
        final urgente = dias <= 2;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: urgente
                ? AppColors.primaryRed.withValues(alpha: 0.08)
                : const Color(0xFFF9A825).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: urgente
                  ? AppColors.primaryRed.withValues(alpha: 0.4)
                  : const Color(0xFFF9A825).withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                urgente ? Icons.error_outline : Icons.schedule,
                color: urgente ? AppColors.primaryRed : const Color(0xFFF9A825),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titulo(dias),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gere uma nova cobrança para não perder o acesso.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onRenovar,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Renovar agora',
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _titulo(int dias) {
    if (dias <= 0) return 'Sua assinatura vence hoje';
    if (dias == 1) return 'Sua assinatura vence amanhã';
    return 'Sua assinatura vence em $dias dias';
  }
}