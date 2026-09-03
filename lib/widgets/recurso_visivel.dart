import 'package:flutter/material.dart';

import 'package:autex/models/resultado_assinatura.dart';
import 'package:autex/screens/payment/assinatura_store.dart';
import 'package:autex/services/payment/recursos.dart';

/// Mostra o filho apenas se o plano do usuário liberar o recurso.
///
/// Escuta o AssinaturaStore: quando o cliente assina ou faz upgrade, o
/// recurso aparece sem precisar reabrir o app.
///
/// ⚠️ Isto é UX, não segurança. Quem impede acesso de verdade é o
/// @ExigePlano() no backend — esconder aqui só evita que o cliente clique
/// e leve 403.
class RecursoVisivel extends StatelessWidget {
  const RecursoVisivel({
    super.key,
    required this.recurso,
    required this.child,
    this.substituto,
  });

  final String recurso;
  final Widget child;

  /// O que mostrar no lugar. Por padrão, nada.
  final Widget? substituto;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StatusPagamento?>(
      valueListenable: AssinaturaStore.instancia.status,
      builder: (context, _, __) {
        if (!Recursos.libera(recurso)) {
          return substituto ?? const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}
