import 'package:flutter/material.dart';
import 'package:flutter_stripe_web/flutter_stripe_web.dart';

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
    return PaymentElement(
      clientSecret: clientSecret,
      onCardChanged: onCardChanged,
    );
  }
}

Future<void> confirmWebSetupElement({required String returnUrl}) async {
  await WebStripe.instance.confirmSetupElement(
    ConfirmSetupElementOptions(
      confirmParams: ConfirmSetupParams(
        return_url: returnUrl,
      ),
    ),
  );
}
