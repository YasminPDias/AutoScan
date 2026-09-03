import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show CardField, CardFieldInputDetails;
import 'package:flutter_stripe_web/flutter_stripe_web.dart';
import 'package:web/web.dart' as web;

/// CardField em vez de PaymentElement.
///
/// O CardField confirma via `confirmCardSetup` (API antiga, específica de
/// cartão), que resolve o 3DS em modal sobre a página. O PaymentElement usa
/// a API genérica e herda o modelo de redirect mesmo quando cartão não
/// precisaria.
///
/// Custo: campos numa linha só (número, validade e CVC juntos), em vez de
/// separados.
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
    return CardField(
      enablePostalCode: false,
      onCardChanged: onCardChanged,
    );
  }
}

/// Confirma o SetupIntent (coleta do cartão) sobre o CardField montado.
///
/// Recebe o clientSecret porque o CardField, diferente do PaymentElement,
/// não guarda o intent internamente — ele é só o campo de entrada.
Future<void> confirmWebSetupIntent({required String clientSecret}) {
  return WebStripe.instance.confirmSetupIntent(
    clientSecret,
    const PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
    null,
  );
}
/// Confirma o PaymentIntent da primeira fatura da assinatura.
///
/// ⚠️ ESTE É O PONTO EM DÚVIDA. O CardField coletou o cartão para o
/// SetupIntent; aqui precisamos confirmar OUTRO intent (o pi_ criado pela
/// subscription). Se o SDK amarrar o campo ao primeiro intent, isto falha
/// com "client_secret associated with a SetupIntent" — o mesmo erro do
/// PaymentElement, e a opção C não resolve.
Future<void> confirmWebPayment({required String clientSecret}) {
  return WebStripe.instance.confirmPayment(
    clientSecret,
    const PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
  );
}

// Sobrevive ao reload que um eventual redirect cause (mesma aba), some
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