import 'package:autex/services/empresa/plano_service.dart';
import 'package:autex/services/payment/cobranca_utils.dart';
import 'package:autex/services/payment/pagamento_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../models/plano_model.dart';

enum MetodoPagamento { cartao, pix, boleto }

extension on MetodoPagamento {
  String get valorApi => switch (this) {
        MetodoPagamento.cartao => 'CARTAO',
        MetodoPagamento.pix => 'PIX',
        MetodoPagamento.boleto => 'BOLETO',
      };
  String get label => switch (this) {
        MetodoPagamento.cartao => 'Cartão',
        MetodoPagamento.pix => 'PIX',
        MetodoPagamento.boleto => 'Boleto',
      };
  IconData get icone => switch (this) {
        MetodoPagamento.cartao => Icons.credit_card,
        MetodoPagamento.pix => Icons.qr_code,
        MetodoPagamento.boleto => Icons.receipt_long,
      };
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _planoId;
  String? _planoNome;
  String? _empresaId;
  PlanoModel? _plano;
  bool _argsLidos = false;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _concluido = false;
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
  CardFieldInputDetails? _card;
  final _nomeCartaoController = TextEditingController();

  String? _urlFatura;

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
    setState(() => _isLoading = false);

    // busca os benefícios do plano em segundo plano — não atrasa o
    // formulário aparecendo, só faz o card de benefícios surgir depois
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
    super.dispose();
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primaryRed, behavior: SnackBarBehavior.floating),
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

  // ---------------- Seleção do método: dispara setup-intent já ----------------

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

  // ---------------- Submit único ----------------

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
    if (_paymentMethodId != null) {
      return _enviarAssinatura(paymentMethodId: _paymentMethodId);
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

  Future<void> _enviarAssinatura({String? paymentMethodId}) async {
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
        metodoPagamento: _metodoPagamento!.valorApi,
        paymentMethodId: paymentMethodId,
        empresaId: _empresaId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>?;
        final urlFatura = data?['urlFatura']?.toString();

        if (_metodoPagamento != MetodoPagamento.cartao && urlFatura != null) {
          setState(() {
            _isSubmitting = false;
            _urlFatura = urlFatura;
            _concluido = true;
          });
        } else {
          _irParaProximaTela();
        }
      } else {
        setState(() => _isSubmitting = false);
        _mostrarErro(result['message'] ?? 'Erro ao confirmar assinatura');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _mostrarErro('Erro ao confirmar assinatura: $e');
    }
  }

  void _irParaProximaTela() {
    if (_empresaId != null) {
      Navigator.pushReplacementNamed(context, '/empresa/funcionarios', arguments: {'empresaId': _empresaId});
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _abrirFatura() async {
    if (_urlFatura == null) return;
    final uri = Uri.parse(_urlFatura!);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pagamento'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
          : _errorMessage != null
              ? _buildErro()
              : _concluido
                  ? _buildConcluido()
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
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(child: formWidget),
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
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryRed)),
                        ),
                      ],
                    ),
                  ),
                const Text('Dados de cobrança',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [MaskTextInputFormatter('00000-000')],
                  onChanged: (v) {
                    if (v.replaceAll(RegExp(r'\D'), '').length == 8) _buscarCep();
                  },
                  validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length != 8 ? 'CEP inválido' : null,
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
                        decoration: const InputDecoration(labelText: 'Número', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _complementoController,
                        decoration:
                            const InputDecoration(labelText: 'Complemento (opcional)', border: OutlineInputBorder()),
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
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cidadeController,
                        decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _estadoController,
                        decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder()),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                Row(
                  children: MetodoPagamento.values.map((m) {
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
                                Icon(m.icone, color: selecionado ? AppColors.primaryRed : AppColors.textSecondary),
                                const SizedBox(height: 8),
                                Text(m.label,
                                    style: TextStyle(
                                      color: selecionado ? AppColors.primaryRed : AppColors.textSecondary,
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
                  _buildAvisoPixBoleto('Depois de confirmar, você recebe um QR code PIX. O acesso libera assim que o pagamento cair.'),
                if (_metodoPagamento == MetodoPagamento.boleto)
                  _buildAvisoPixBoleto('Depois de confirmar, você recebe um boleto. O acesso libera após a compensação — até 2 dias úteis.'),
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
                            height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Confirmar assinatura',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBeneficiosCard() {
    if (_plano == null) return const SizedBox.shrink();

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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Benefícios do plano',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildFeature(_plano!.limiteTexto),
          _buildFeature('Chat com especialista'),
          _buildFeature('Histórico completo'),
          if (!_plano!.isFree) _buildFeature('Suporte prioritário'),
          if (_plano!.isEmpresarial && _plano!.maxUsuarios != null)
            _buildFeature('Até ${_plano!.maxUsuarios} usuários'),
          if (_plano!.isEmpresarial) _buildFeature('Gerenciamento de equipe'),
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
            child: Text(texto, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildCartaoForm() {
    if (_clientSecret == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nomeCartaoController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Nome impresso no cartão', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CardField(onCardChanged: (details) => setState(() => _card = details)),
        ),
        const SizedBox(height: 8),
        const Text('Seus dados de pagamento são processados com segurança pelo Stripe.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildAvisoPixBoleto(String texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.divider.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
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

  Widget _buildConcluido() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF388E3C), size: 56),
            const SizedBox(height: 16),
            Text(
              _metodoPagamento == MetodoPagamento.pix
                  ? 'Falta pagar o PIX pra ativar sua assinatura'
                  : 'Falta pagar o boleto pra ativar sua assinatura',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            if (_urlFatura != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _abrirFatura,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Abrir ${_metodoPagamento == MetodoPagamento.pix ? "PIX" : "boleto"}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _irParaProximaTela,
              child: const Text('Continuar depois', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}