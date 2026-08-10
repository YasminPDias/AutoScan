import 'package:flutter/material.dart';

class WebPaymentElement extends StatelessWidget {
  final String clientSecret;
  final dynamic onCardChanged;

  const WebPaymentElement({
    Key? key,
    required this.clientSecret,
    this.onCardChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

Future<void> confirmWebSetupElement({required String returnUrl}) async {
  // Stub para mobile. A implementação real fica no stripe_web_impl.dart
}
