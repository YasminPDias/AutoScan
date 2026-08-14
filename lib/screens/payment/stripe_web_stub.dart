import 'package:flutter/widgets.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show CardFieldInputDetails;

class WebPaymentElement extends StatelessWidget {
  const WebPaymentElement({
    super.key,
    required this.clientSecret,
    required this.onCardChanged,
  });

  final String clientSecret;
  final void Function(CardFieldInputDetails?) onCardChanged; 

  @override
  Widget build(BuildContext context) =>
      throw UnsupportedError('WebPaymentElement só roda em Flutter web');
}

Future<void> confirmWebSetupElement({required String returnUrl}) {
  throw UnsupportedError('confirmWebSetupElement só roda em Flutter web');
}

void salvarContextoRedirect(Map<String, String> dados) {
  throw UnsupportedError('salvarContextoRedirect só roda em Flutter web');
}

Map<String, String>? lerContextoRedirect() {
  throw UnsupportedError('lerContextoRedirect só roda em Flutter web');
}