import 'package:autex/screens/payment/assinatura_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:autex/models/resultado_assinatura.dart';
import 'package:autex/screens/payment/aguardando_payment_screen.dart';
import 'package:autex/screens/payment/stripe_web.dart';
import 'package:autex/services/auth_storage.dart';
import 'package:autex/services/payment/pagamento_service.dart';
import 'package:autex/theme/app_colors.dart';

/// Tela de renovação.
///
/// Separada da tela de assinatura de propósito: os dados de cobrança já estão
/// salvos, então pedir CPF e endereço de novo seria atrito puro. Aqui é só
/// escolher o método e confirmar.
///
/// O vencimento é SOMADO ao atual pelo backend — renovar cedo não custa dias.
class RenovacaoScreen extends StatefulWidget {
  const RenovacaoScreen({super.key, this.empresaId});

  final String? empresaId;

  @override
  State<RenovacaoScreen> createState() => _RenovacaoScreenState();
}

class _RenovacaoScreenState extends State<RenovacaoScreen> {
  /// Pix segue fora enquanto a conta Stripe não é habilitada.
  static const _metodosDisponiveis = [
    MetodoPagamento.cartao,
    MetodoPagamento.boleto,
  ];

  MetodoPagamento? _metodo;
  bool _isSubmitting = false;

  String? _clientSecret;
  String? _paymentMethodId;
  String? _setupIntentIdConfirmado;
  CardFieldInputDetails? _card;
  final _nomeCartaoController = TextEditingController();
  final _cardFormController = CardFormEditController();

  @override
  void dispose() {
    _nomeCartaoController.dispose();
    _cardFormController.dispose();
    super.dispose();
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primaryRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selecionarMetodo(MetodoPagamento m) async {
    setState(() => _metodo = m);
    if (m != MetodoPagamento.cartao || _clientSecret != null) return;

    final token = await AuthStorage.getToken();
    if (!mounted || token == null) return;

    final res = await PagamentoService.criarSetupIntent(
      token: token,
      empresaId: widget.empresaId,
    );
    if (!mounted) return;

    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      final pk = data['publishableKey']?.toString();
      final cs = data['clientSecret']?.toString();
      if (pk == null || cs == null) {
        _mostrarErro('Resposta inválida do servidor de pagamento');
        return;
      }
      Stripe.publishableKey = pk;
      if (!kIsWeb) await Stripe.instance.applySettings();
      setState(() => _clientSecret = cs);
    } else {
      _mostrarErro(res['message']?.toString() ?? 'Erro ao iniciar pagamento');
    }
  }

  Future<void> _confirmar() async {
    if (_metodo == null) {
      _mostrarErro('Selecione a forma de pagamento');
      return;
    }
    if (_metodo == MetodoPagamento.cartao) {
      if (_clientSecret == null) {
        _mostrarErro('Aguarde o campo de cartão carregar');
        return;
      }
      if (_card == null || !_card!.complete) {
        _mostrarErro('Preencha os dados do cartão');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    if (_metodo == MetodoPagamento.cartao) {
      await _coletarCartao();
    } else {
      await _enviar();
    }
  }

  Future<void> _coletarCartao() async {
    if (_paymentMethodId != null || _setupIntentIdConfirmado != null) {
      return _enviar();
    }

    try {
      if (kIsWeb) {
        await confirmWebSetupIntent(clientSecret: _clientSecret!);
        _setupIntentIdConfirmado = _clientSecret!.split('_secret_').first;
      } else {
        final email = await AuthStorage.getUserEmail();
        final si = await Stripe.instance.confirmSetupIntent(
          paymentIntentClientSecret: _clientSecret!,
          params: PaymentMethodParams.card(
            paymentMethodData: PaymentMethodData(
              billingDetails: BillingDetails(
                name: _nomeCartaoController.text.trim(),
                email: email,
              ),
            ),
          ),
        );
        _paymentMethodId = si.paymentMethodId;
      }
      await _enviar();
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _mostrarErro(e.error.localizedMessage ?? 'Erro ao processar o cartão');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _mostrarErro('Erro ao processar o cartão: $e');
    }
  }

  Future<void> _enviar() async {
    final token = await AuthStorage.getToken();
    if (!mounted || token == null) return;

    final res = await PagamentoService.renovar(
      token: token,
      metodoPagamento: _metodo!.valorApi,
      paymentMethodId: _paymentMethodId,
      setupIntentId: _setupIntentIdConfirmado,
      empresaId: widget.empresaId,
    );
    if (!mounted) return;

    if (res['success'] != true) {
      setState(() => _isSubmitting = false);

      // O backend recusa renovação manual de cartão recorrente: ele já
      // renova sozinho, e cobrar de novo duplicaria o período.
      if (res['codigo'] == 'RENOVACAO_AUTOMATICA') {
        _mostrarErro('Sua assinatura já renova automaticamente no cartão');
        Navigator.pop(context);
        return;
      }

      _mostrarErro(res['message']?.toString() ?? 'Não foi possível renovar');
      return;
    }

    final r = res['resultado'] as ResultadoAssinatura;

    // Cartão sem 3DS confirma na hora.
    if (r.liberado || (!r.precisaConfirmarCartao && !r.aguardandoPagamento)) {
      await AssinaturaStore.instancia.recarregar(empresaId: widget.empresaId);
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    }

    if (r.precisaConfirmarCartao) {
      await _confirmar3DS(r);
      return;
    }

    // Boleto: mostra o documento e volta quando compensar.
    setState(() => _isSubmitting = false);
    final liberou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AguardandoPagamentoScreen(
          resultado: r,
          empresaId: widget.empresaId,
        ),
      ),
    );
    if (!mounted) return;
    if (liberou == true) {
      await AssinaturaStore.instancia.recarregar(empresaId: widget.empresaId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _confirmar3DS(ResultadoAssinatura r) async {
    try {
      if (kIsWeb) {
        await confirmWebPayment(clientSecret: r.clientSecret!);
      } else {
        await Stripe.instance.confirmPayment(
          paymentIntentClientSecret: r.clientSecret!,
        );
      }
      if (!mounted) return;
      await AssinaturaStore.instancia.recarregar(empresaId: widget.empresaId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _mostrarErro('Não foi possível confirmar o cartão: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AssinaturaStore.instancia;
    final venc = store.atual?.proximoVencimento;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Renovar assinatura')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (venc != null) _buildResumo(venc),
                const SizedBox(height: 24),
                const Text(
                  'Forma de pagamento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: _metodosDisponiveis.map(_buildCardMetodo).toList()),
                const SizedBox(height: 16),
                if (_metodo == MetodoPagamento.cartao) _buildCartaoForm(),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Renovar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResumo(DateTime venc) {
    final dias = venc.difference(DateTime.now()).inDays;
    final d = venc.day.toString().padLeft(2, '0');
    final m = venc.month.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dias <= 0
                ? 'Sua assinatura venceu em $d/$m'
                : 'Sua assinatura vence em $d/$m',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(height: 6),
          // Tirar o medo de renovar cedo: os dias restantes não somem.
          const Text(
            'O novo período é somado ao atual — você não perde os dias '
            'que já pagou.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMetodo(MetodoPagamento m) {
    final sel = _metodo == m;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: _isSubmitting ? null : () => _selecionarMetodo(m),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryRed.withValues(alpha: 0.1) : null,
              border: Border.all(
                color: sel ? AppColors.primaryRed : AppColors.divider,
                width: sel ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  m.icone,
                  color: sel ? AppColors.primaryRed : AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  m.label,
                  style: TextStyle(
                    color: sel ? AppColors.primaryRed : AppColors.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartaoForm() {
    if (_clientSecret == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!kIsWeb) ...[
          TextField(
            controller: _nomeCartaoController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome impresso no cartão',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (kIsWeb)
          WebPaymentElement(
            clientSecret: _clientSecret!,
            onCardChanged: (d) => setState(() => _card = d),
          )
        else
          CardFormField(
            countryCode: 'BR',
            controller: _cardFormController,
            enablePostalCode: false,
            style: CardFormStyle(
              borderColor: AppColors.divider,
              borderRadius: 12,
              borderWidth: 1,
              textColor: AppColors.textPrimary,
              placeholderColor: AppColors.textSecondary,
              cursorColor: AppColors.primaryRed,
            ),
            onCardChanged: (d) => setState(() => _card = d),
          ),
      ],
    );
  }
}