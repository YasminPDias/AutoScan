import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/pagamento_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _planoId;
  String? _planoNome;
  String? _empresaId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _clientSecret;
  String? _paymentMethodId;
  CardFieldInputDetails? _card;
  bool _argsLidos = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLidos) return;
    _argsLidos = true;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _planoId = args?['planoId']?.toString();
    _planoNome = args?['planoNome']?.toString();
    _empresaId = args?['empresaId']?.toString();
    _iniciar();
  }

  Future<void> _iniciar() async {
    if (_planoId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Plano não informado';
      });
      return;
    }
    final token = await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final result = await PagamentoService.criarSetupIntent(
      token: token,
      empresaId: _empresaId,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      final publishableKey = data['publishableKey']?.toString();
      final clientSecret = data['clientSecret']?.toString();
      if (publishableKey == null || clientSecret == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Resposta inválida do servidor de pagamento';
        });
        return;
      }
      Stripe.publishableKey = publishableKey;
      if (!kIsWeb) {
        await Stripe.instance.applySettings();
      }
      setState(() {
        _clientSecret = clientSecret;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message']?.toString();
      });
    }
  }

  Future<void> _confirmarAssinatura() async {
    if (_clientSecret == null || _planoId == null) return;

    // Se o cartão já foi confirmado numa tentativa anterior (ex: falha de
    // rede no envio pro backend), pula direto pro reenvio — SetupIntent já
    // confirmado não pode ser reconfirmado.
    if (_paymentMethodId != null) {
      return _enviarAssinatura(_paymentMethodId!);
    }

    if (_card == null || !_card!.complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha os dados do cartão'),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final nome = await AuthStorage.getUserName();
      final email = await AuthStorage.getUserEmail();
      final setupIntent = await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: _clientSecret!,
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(name: nome, email: email),
          ),
        ),
      );

      _paymentMethodId = setupIntent.paymentMethodId;
      await _enviarAssinatura(_paymentMethodId!);
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.error.localizedMessage ?? 'Erro ao processar o cartão'),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar o cartão: $e'),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _enviarAssinatura(String paymentMethodId) async {
    final token = await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await PagamentoService.assinar(
        token: token,
        planoId: _planoId!,
        paymentMethodId: paymentMethodId,
        empresaId: _empresaId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assinatura confirmada com sucesso!'),
            backgroundColor: Color(0xFF388E3C),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (_empresaId != null) {
          Navigator.pushReplacementNamed(
            context,
            '/empresa/funcionarios',
            arguments: {'empresaId': _empresaId},
          );
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() => _isSubmitting = false);
        // _paymentMethodId permanece setado — retry vai direto pro backend,
        // sem pedir o cartão de novo.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Erro ao confirmar assinatura'),
            backgroundColor: AppColors.primaryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao confirmar assinatura: $e'),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pagamento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
          : _errorMessage != null
              ? _buildErro()
              : _buildFormulario(),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _iniciar();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
              child: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_planoNome != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: AppColors.primaryRed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Plano selecionado: $_planoNome',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Dados do cartão',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CardField(
                  onCardChanged: (details) => setState(() => _card = details),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Seus dados de pagamento são processados com segurança pelo Stripe.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirmarAssinatura,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Confirmar assinatura',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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