import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show CardFieldInputDetails;
import 'package:flutter_stripe_web/flutter_stripe_web.dart';
import 'package:web/web.dart' as web;

class WebPaymentElement extends StatelessWidget {
  const WebPaymentElement({
    super.key,
    required this.clientSecret,
    required this.onCardChanged,
  });

  final String clientSecret;
  final void Function(CardFieldInputDetails?) onCardChanged;

  @override
  Widget build(BuildContext context) {
    return PaymentElement(
      clientSecret: clientSecret,
      enablePostalCode: false,
      onCardChanged: onCardChanged,
    );
  }
}

Future<void> confirmWebSetupElement({required String returnUrl}) {
  return WebStripe.instance.confirmSetupElement(
    ConfirmSetupElementOptions(
      confirmParams: ConfirmSetupParams(return_url: returnUrl),
      redirect: SetupConfirmationRedirect.ifRequired,
    ),
  );
}

// Sobrevive ao reload que o redirect de 3DS causa (mesma aba), some
// sozinho quando a aba fecha — não deixa contexto de pagamento pendente
// acumulando indefinidamente.
void salvarContextoRedirect(Map<String, String> dados) {
  web.window.sessionStorage.setItem('pagamento_redirect_ctx', jsonEncode(dados));
}

Map<String, String>? lerContextoRedirect() {
  final raw = web.window.sessionStorage.getItem('pagamento_redirect_ctx');
  web.window.sessionStorage.removeItem('pagamento_redirect_ctx');
  if (raw == null) return null;
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return decoded.map((k, v) => MapEntry(k, v.toString()));
}