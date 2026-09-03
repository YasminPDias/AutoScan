import 'package:autex/models/resultado_assinatura.dart';
import 'package:autex/screens/payment/aguardando_payment_screen.dart';
import 'package:autex/screens/plans/beneficios_plano.dart';
import 'package:autex/screens/payment/stripe_web.dart';
import 'package:autex/services/empresa/plano_service.dart';
import 'package:autex/services/payment/cobranca_utils.dart';
import 'package:autex/services/payment/pagamento_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../models/plano_model.dart';

enum _EscolhaPendente { voltar, ver, trocar }

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  /// Pix está fora enquanto a conta Stripe não é habilitada (invite-only para
  /// contas brasileiras). O backend aceita os três — quando liberar, basta
  /// devolver MetodoPagamento.pix a esta lista.
  static const _metodosDisponiveis = [
    MetodoPagamento.cartao,
    MetodoPagamento.boleto,
  ];

  /// TODO: quando a tela de seleção de plano oferecer período, receber via
  /// route args. Hoje MENSAL é o único intervalo ativo em plano_preco.
  static const _intervalo = 'MENSAL';

  String? _planoId;
  String? _planoNome;
  String? _empresaId;
  PlanoModel? _plano;
  bool _argsLidos = false;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  bool _buscandoCep = false;

  MetodoPagamento? _metodoPagamento;
  String? _clientSecret;
  String? _paymentMethodId;
  String? _setupIntentIdConfirmado;
  CardFieldInputDetails? _card;
  final _nomeCartaoController = TextEditingController();
  final _cardFormController = CardFormEditController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLidos) return;
    _argsLidos = true;

    // Volta de um redirect de 3DS (a página recarregou) — retoma direto para
    // finalizar a assinatura, sem passar pelo formulário de novo.
    if (kIsWeb) {
      final query = Uri.base.queryParameters;
      if (query.containsKey('setup_intent') && query.containsKey('redirect_status')) {
        _retomarAposRedirect(query);
        return;
      }
    }

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
    setState(() => _isLoading = false);

    try {
      final result = await PlanoService.listarTodos();
      if (result['success'] == true) {
        final planos = result['data'] as List<PlanoModel>;
        _plano = planos.where((p) => p.id == _planoId).firstOrNull;
      }
    } catch (_) {
      // best-effort — sem card de benefícios não impede a assinatura
    }
    if (mounted) setState(() {});
  }

  Future<void> _retomarAposRedirect(Map<String, String> query) async {
    final status = query['redirect_status'];
    final setupIntentId = query['setup_intent'];
    final contexto = lerContextoRedirect();

    _planoId = contexto?['planoId'];
    _planoNome = contexto?['planoNome'];
    _empresaId = contexto?['empresaId'];
    _metodoPagamento = MetodoPagamento.cartao; // só cartão passa por redirect

    if (status != 'succeeded' || setupIntentId == null || _planoId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = status == 'succeeded'
            ? 'Não foi possível retomar automaticamente. Selecione o plano novamente.'
            : 'A confirmação do cartão não foi concluída. Tente novamente.';
      });
      return;
    }

    setState(() => _isLoading = false);
    await _enviarAssinatura(setupIntentId: setupIntentId);
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _telefoneController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
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

  Future<void> _buscarCep() async {
    setState(() => _buscandoCep = true);
    final resultado = await EnderecoService.buscarPorCep(_cepController.text);
    if (!mounted) return;
    setState(() {
      _buscandoCep = false;
      if (resultado != null) {
        _logradouroController.text = resultado['logradouro'] ?? '';
        _bairroController.text = resultado['bairro'] ?? '';
        _cidadeController.text = resultado['cidade'] ?? '';
        _estadoController.text = resultado['estado'] ?? '';
      }
    });
  }

  // ───────────── Seleção do método: dispara o setup-intent já ─────────────

  Future<void> _selecionarMetodo(MetodoPagamento metodo) async {
    setState(() => _metodoPagamento = metodo);
    if (metodo != MetodoPagamento.cartao || _clientSecret != null) return;

    final token = await AuthStorage.getToken();
    if (!mounted || token == null) return;

    final result = await PagamentoService.criarSetupIntent(token: token, empresaId: _empresaId);
    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      final publishableKey = data['publishableKey']?.toString();
      final clientSecret = data['clientSecret']?.toString();
      if (publishableKey == null || clientSecret == null) {
        _mostrarErro('Resposta inválida do servidor de pagamento');
        return;
      }
      Stripe.publishableKey = publishableKey;
      if (!kIsWeb) await Stripe.instance.applySettings();
      setState(() => _clientSecret = clientSecret);
    } else {
      _mostrarErro(result['message']?.toString() ?? 'Erro ao iniciar pagamento com cartão');
    }
  }

  // ──────────────────────────── Submit ────────────────────────────

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) {
      _mostrarErro('Revise os campos destacados em vermelho');
      return;
    }
    if (_metodoPagamento == null) {
      _mostrarErro('Selecione a forma de pagamento');
      return;
    }
    if (_metodoPagamento == MetodoPagamento.cartao) {
      if (_clientSecret == null) {
        _mostrarErro('Aguarde o campo de cartão carregar');
        return;
      }
      if (_card == null || !_card!.complete) {
        _mostrarErro('Preencha os dados do cartão');
        return;
      }
      if (_nomeCartaoController.text.trim().isEmpty) {
        _mostrarErro('Informe o nome impresso no cartão');
        return;
      }
    }

    final token = await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() => _isSubmitting = true);

    final dadosResult = await PagamentoService.salvarDadosCobranca(
      token: token,
      cpf: _empresaId == null ? _cpfController.text.replaceAll(RegExp(r'\D'), '') : null,
      telefone: _telefoneController.text.replaceAll(RegExp(r'\D'), ''),
      endereco: {
        'cep': _cepController.text.replaceAll(RegExp(r'\D'), ''),
        'logradouro': _logradouroController.text.trim(),
        'numero': _numeroController.text.trim(),
        'complemento': _complementoController.text.trim(),
        'bairro': _bairroController.text.trim(),
        'cidade': _cidadeController.text.trim(),
        'estado': _estadoController.text.trim().toUpperCase(),
      },
      empresaId: _empresaId,
    );

    if (!mounted) return;
    if (dadosResult['success'] != true) {
      setState(() => _isSubmitting = false);
      _mostrarErro(dadosResult['message'] ?? 'Erro ao salvar dados de cobrança');
      return;
    }

    if (_metodoPagamento == MetodoPagamento.cartao) {
      await _confirmarCartao();
    } else {
      await _enviarAssinatura();
    }
  }

  Future<void> _confirmarCartao() async {
    if (_paymentMethodId != null || _setupIntentIdConfirmado != null) {
      return _enviarAssinatura(
        paymentMethodId: _paymentMethodId,
        setupIntentId: _setupIntentIdConfirmado,
      );
    }

    if (kIsWeb) {
      try {
        // Com CardField não há redirect: o 3DS do SetupIntent resolve em
        // modal sobre a página. Por isso sumiram o salvarContextoRedirect e
        // o returnUrl — o estado da tela nunca se perde.
        await confirmWebSetupIntent(clientSecret: _clientSecret!);
        _setupIntentIdConfirmado = _clientSecret!.split('_secret_').first;
        await _enviarAssinatura(setupIntentId: _setupIntentIdConfirmado);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _mostrarErro('Erro ao processar o cartão: $e');
      }
      return;
    }

    try {
      final email = await AuthStorage.getUserEmail();
      final setupIntent = await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: _clientSecret!,
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(name: _nomeCartaoController.text.trim(), email: email),
          ),
        ),
      );
      _paymentMethodId = setupIntent.paymentMethodId;
      await _enviarAssinatura(paymentMethodId: _paymentMethodId);
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

  Future<void> _enviarAssinatura({String? paymentMethodId, String? setupIntentId}) async {
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
        intervalo: _intervalo,
        metodoPagamento: _metodoPagamento!.valorApi,
        paymentMethodId: paymentMethodId,
        setupIntentId: setupIntentId,
        empresaId: _empresaId,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        setState(() => _isSubmitting = false);
        await _tratarErroAssinatura(result);
        return;
      }

      await _tratarResultado(result['resultado'] as ResultadoAssinatura);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _mostrarErro('Erro ao confirmar assinatura: $e');
    }
  }

  /// Os quatro estados.
  ///
  /// A versão anterior só distinguia "tem urlFatura ou não" e mandava o cartão
  /// para /home mesmo com o 3DS pendente — o cliente saía achando que tinha
  /// assinado, sem acesso e sem aviso.
  Future<void> _tratarResultado(ResultadoAssinatura r) async {
    // 1. Pago e liberado
    if (r.liberado) {
      _irParaProximaTela();
      return;
    }

    // 2. Cartão precisa de 3DS
    if (r.precisaConfirmarCartao) {
      await _confirmarAcaoCartao(r);
      return;
    }

    // 3. Pix/boleto aguardando compensação
    if (r.aguardandoPagamento) {
      setState(() => _isSubmitting = false);
      await _abrirTelaAguardando(r);
      return;
    }

    // 4. Estado inesperado — não manda o cliente adiante achando que pagou
    setState(() => _isSubmitting = false);
    _mostrarErro('Não foi possível concluir o pagamento. Tente novamente.');
  }

  /// Confirma o pagamento e apresenta o 3DS quando o emissor pedir.
  ///
  /// É confirmPayment, NÃO handleNextAction. O Stripe distingue dois modos:
  ///
  ///   confirmation_method 'manual'    → servidor confirma, cliente só trata
  ///                                     a ação: handleNextAction
  ///   confirmation_method 'automatic' → cliente confirma E trata a ação numa
  ///                                     chamada só: confirmPayment
  ///
  /// A subscription cria o intent como 'automatic', e não dá para mudar isso
  /// depois. Por isso o handleNextAction recusava com "does not require manual
  /// server-side confirmation".
  ///
  /// O payment method já está anexado ao intent, então confirmar pelo client
  /// secret basta — sem reenviar dados do cartão.
Future<void> _confirmarAcaoCartao(ResultadoAssinatura r) async {
  try {
    if (kIsWeb) {
      await confirmWebPayment(clientSecret: r.clientSecret!);
    } else {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: r.clientSecret!,
      );
    }

    if (!mounted) return;

    // Cartão confirma na hora — diferente de boleto, não há o que aguardar.
    // Mas quem grava ATIVA no banco é o webhook, que leva alguns segundos.
    // Então: consulta o status por alguns ciclos antes de seguir.
    await _aguardarAtivacao();
  } on StripeException catch (e) {
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _mostrarErro(e.error.localizedMessage ?? 'Não foi possível confirmar o cartão');
  } catch (e) {
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _mostrarErro('Não foi possível confirmar o cartão: $e');
  }
}

/// Espera o webhook ativar a assinatura, mantendo o spinner do botão.
///
/// Não abre a tela de "falta pagar": ela é para boleto, e mostrar isso a
/// quem acabou de passar o cartão confunde.
Future<void> _aguardarAtivacao() async {
  final token = await AuthStorage.getToken();
  if (!mounted || token == null) return;

  for (var tentativa = 0; tentativa < 10; tentativa++) {
    final res = await PagamentoService.consultarStatus(
      token: token,
      empresaId: _empresaId,
    );
    if (!mounted) return;

    if (res['success'] == true) {
      final status = res['status'] as StatusPagamento;
      if (status.temAcesso) {
        _irParaProximaTela();
        return;
      }
    }
    await Future.delayed(const Duration(seconds: 2));
  }

  // 20s sem confirmar: o pagamento provavelmente entrou, mas o webhook
  // atrasou. Segue adiante — o guard nega se não tiver ativado mesmo.
  if (mounted) _irParaProximaTela();
}
  /// PAGAMENTO_EM_ABERTO não é erro de verdade: o cliente já tem uma cobrança
  /// válida. O backend bloqueia qualquer método novo enquanto ela existir —
  /// se deixasse passar, daria pra ficar com boleto e cartão abertos ao mesmo
  /// tempo e pagar os dois.
  Future<void> _tratarErroAssinatura(Map<String, dynamic> result) async {
    if (result['codigo'] != 'PAGAMENTO_EM_ABERTO') {
      _mostrarErro(result['message']?.toString() ?? 'Erro ao confirmar assinatura');
      return;
    }

    final erro = result['erro'] as Map<String, dynamic>?;
    final metodoPendente = MetodoPagamentoX.deApi(erro?['metodoPagamento']?.toString());

    // Trocou de método: escolheu cartão e existe um boleto em aberto. Jogar
    // direto na tela de boleto é confuso — ele não pediu isso e não entende
    // por que caiu ali. Explica e deixa decidir.
    if (metodoPendente != null && metodoPendente != _metodoPagamento) {
      final escolha = await _perguntarSobrePendente(metodoPendente, erro);
      if (escolha == null || escolha == _EscolhaPendente.voltar) return;

      if (escolha == _EscolhaPendente.trocar) {
        await _cancelarPendenteERepetir();
        return;
      }
    }

    await _abrirTelaAguardando(
      ResultadoAssinatura(
        assinaturaId: erro?['assinaturaId']?.toString() ?? '',
        status: StatusAssinatura.pendente,
        metodoPagamento: metodoPendente ?? _metodoPagamento,
        urlFatura: erro?['urlFatura']?.toString(),
        boleto: metodoPendente == MetodoPagamento.boleto
            ? DadosBoleto(
                pdfUrl: erro?['urlFatura']?.toString(),
                vencimento: DateTime.tryParse(erro?['expiraEm']?.toString() ?? ''),
              )
            : null,
      ),
    );
  }

  Future<_EscolhaPendente?> _perguntarSobrePendente(
    MetodoPagamento metodoPendente,
    Map<String, dynamic>? erro,
  ) {
    final expira = DateTime.tryParse(erro?['expiraEm']?.toString() ?? '');
    final nome = metodoPendente.label;
    final novo = _metodoPagamento?.label ?? 'outro método';
    final podeTrocar = metodoPendente != MetodoPagamento.boleto;

    return showDialog<_EscolhaPendente>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Você já tem um $nome em aberto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              podeTrocar
                  ? 'Só é possível ter uma cobrança por vez. Você pode ver o '
                      '$nome atual ou cancelá-lo para pagar com $novo.'
                  : 'Boletos já emitidos não podem ser cancelados. Pague este '
                      'boleto ou aguarde o vencimento para escolher outro método.',
              style: const TextStyle(height: 1.4),
            ),
            if (expira != null) ...[
              const SizedBox(height: 12),
              Text('O $nome vence em ${_formatarData(expira)}.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _EscolhaPendente.voltar),
            child: const Text('Voltar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _EscolhaPendente.ver),
            child: Text('Ver $nome', style: const TextStyle(color: AppColors.textSecondary)),
          ),
          // Boleto emitido não pode ser cancelado — é regra da rede, o
          // documento está na praça. Oferecer o botão só pra ele falhar
          // seria pior que não oferecer.
          if (podeTrocar)
            TextButton(
              onPressed: () => Navigator.pop(ctx, _EscolhaPendente.trocar),
              child: Text('Cancelar e pagar com $novo',
                  style: const TextStyle(
                      color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  /// Cancela a cobrança pendente e refaz a assinatura com o método escolhido.
  ///
  /// Reaproveita o payment method que já foi coletado — o cliente não precisa
  /// digitar o cartão de novo.
  Future<void> _cancelarPendenteERepetir() async {
    final token = await AuthStorage.getToken();
    if (!mounted || token == null) return;

    setState(() => _isSubmitting = true);

    final res = await PagamentoService.cancelarPendente(
      token: token,
      empresaId: _empresaId,
    );
    if (!mounted) return;

    if (res['success'] != true) {
      setState(() => _isSubmitting = false);

      // O dinheiro entrou entre o clique e o cancelamento. A assinatura vai
      // ativar sozinha pelo webhook — mandar pra tela de espera é o certo.
      if (res['codigo'] == 'BOLETO_NAO_CANCELAVEL') {
        _mostrarErro(res['message']?.toString() ??
            'Boletos emitidos não podem ser cancelados');
        return;
      }

      if (res['codigo'] == 'PAGAMENTO_JA_CONFIRMADO') {
        _mostrarErro('Seu pagamento anterior foi confirmado. Verificando...');
        await _abrirTelaAguardando(ResultadoAssinatura(
          assinaturaId: '',
          status: StatusAssinatura.pendente,
          metodoPagamento: _metodoPagamento,
        ));
        return;
      }

      _mostrarErro(res['message']?.toString() ?? 'Não foi possível cancelar a cobrança');
      return;
    }

    await _enviarAssinatura(
      paymentMethodId: _paymentMethodId,
      setupIntentId: _setupIntentIdConfirmado,
    );
  }

  String _formatarData(DateTime d) {
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final hora = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dia/$mes às $hora:$min';
  }

  Future<void> _abrirTelaAguardando(ResultadoAssinatura r) async {
    final liberou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AguardandoPagamentoScreen(resultado: r, empresaId: _empresaId),
      ),
    );
    if (!mounted) return;
    if (liberou == true) _irParaProximaTela();
  }

  void _irParaProximaTela() {
    if (_empresaId != null) {
      Navigator.pushReplacementNamed(context, '/empresa/funcionarios',
          arguments: {'empresaId': _empresaId});
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // ──────────────────────────── build ────────────────────────────

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
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final formWidget = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _buildFormContent(),
        );

        if (isDesktop && _plano != null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                formWidget,
                const SizedBox(width: 48),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: _buildBeneficiosCard(),
                ),
              ],
            ),
          );
        }

        // No mobile o card vai ACIMA do formulário. Antes ele só existia no
        // desktop, então quem estava no celular decidia pagar sem ver o que
        // estava comprando — justamente na tela mais decisiva do funil.
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_plano != null) ...[
                    _buildBeneficiosCard(),
                    const SizedBox(height: 24),
                  ],
                  _buildFormContent(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_planoNome != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
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
                    child: Text('Plano selecionado: $_planoNome',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
                  ),
                ],
              ),
            ),
          const Text('Dados de cobrança',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (_empresaId == null) ...[
            TextFormField(
              controller: _cpfController,
              decoration: const InputDecoration(labelText: 'CPF', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [MaskTextInputFormatter('000.000.000-00')],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o CPF';
                if (!CpfValidator.isValid(v)) return 'CPF inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _telefoneController,
            decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
            keyboardType: TextInputType.phone,
            inputFormatters: [MaskTextInputFormatter('(00) 00000-0000')],
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return digits.length < 10 ? 'Telefone inválido' : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cepController,
            decoration: InputDecoration(
              labelText: 'CEP',
              border: const OutlineInputBorder(),
              suffixIcon: _buscandoCep
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [MaskTextInputFormatter('00000-000')],
            onChanged: (v) {
              if (v.replaceAll(RegExp(r'\D'), '').length == 8) _buscarCep();
            },
            validator: (v) =>
                (v ?? '').replaceAll(RegExp(r'\D'), '').length != 8 ? 'CEP inválido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _logradouroController,
            decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.isEmpty) ? 'Informe o endereço' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _numeroController,
                  decoration:
                      const InputDecoration(labelText: 'Número', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _complementoController,
                  decoration: const InputDecoration(
                      labelText: 'Complemento (opcional)', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bairroController,
            decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.isEmpty) ? 'Informe o bairro' : null,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _cidadeController,
                  decoration:
                      const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _estadoController,
                  decoration: const InputDecoration(
                      labelText: 'UF', border: OutlineInputBorder(), counterText: ''),
                  maxLength: 2,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  validator: (v) => (v == null || v.length != 2) ? 'UF' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Forma de pagamento',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: _metodosDisponiveis.map((m) {
              final selecionado = _metodoPagamento == m;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: _isSubmitting ? null : () => _selecionarMetodo(m),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: selecionado ? AppColors.primaryRed.withValues(alpha: 0.1) : null,
                        border: Border.all(
                          color: selecionado ? AppColors.primaryRed : AppColors.divider,
                          width: selecionado ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(m.icone,
                              color:
                                  selecionado ? AppColors.primaryRed : AppColors.textSecondary),
                          const SizedBox(height: 8),
                          Text(m.label,
                              style: TextStyle(
                                color:
                                    selecionado ? AppColors.primaryRed : AppColors.textSecondary,
                                fontWeight: selecionado ? FontWeight.w600 : FontWeight.normal,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_metodoPagamento == MetodoPagamento.cartao) _buildCartaoForm(),
          if (_metodoPagamento == MetodoPagamento.pix)
            _buildAviso('Depois de confirmar, você recebe o código PIX. '
                'O acesso libera assim que o pagamento cair.'),
          if (_metodoPagamento == MetodoPagamento.boleto)
            _buildAviso('Depois de confirmar, você recebe o boleto. '
                'O acesso libera após a compensação — até 2 dias úteis.'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _confirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirmar assinatura',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiosCard() {
    if (_plano == null) return const SizedBox.shrink();

    final itens = BeneficiosPlano.itens(_plano!.chave);
    final heranca = BeneficiosPlano.textoHeranca(_plano!.chave);

    // Sem chave (plano gravado antes da coluna existir) o card não tem o que
    // mostrar. Melhor sumir do que exibir um bloco vazio com título.
    if (itens.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Benefícios do plano',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),

          // Vem do banco, não do texto fixo: se o limite mudar, o card
          // acompanha sem deploy.
          _buildFeature(_plano!.limiteTexto),

          if (heranca != null) ...[
            const SizedBox(height: 4),
            Text(heranca,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 12),
          ],

          ...itens.map(_buildFeature),

          if (_plano!.maxUsuarios != null)
            _buildFeature(BeneficiosPlano.limiteUsuarios(_plano!.maxUsuarios!)),
        ],
      ),
    );
  }

  Widget _buildFeature(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(texto,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildCartaoForm() {
    // Antes: spinner infinito se o setup-intent falhasse. O snackbar aparecia
    // e sumia, e o formulário ficava travado sem explicação.
    if (_clientSecret == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primaryRed),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _selecionarMetodo(MetodoPagamento.cartao),
              child: const Text('Demorando? Toque para tentar de novo',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nomeCartaoController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
              labelText: 'Nome impresso no cartão', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        if (kIsWeb)
          WebPaymentElement(
            clientSecret: _clientSecret!,
            onCardChanged: (details) => setState(() => _card = details),
          )
        else
          CardFormField(
            // Sem isto o seletor vem "United States" por padrão.
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
            onCardChanged: (details) => setState(() => _card = details),
          ),
        const SizedBox(height: 8),
        const Text('Seus dados de pagamento são processados com segurança pelo Stripe.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildAviso(String texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.divider.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: const TextStyle(color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}