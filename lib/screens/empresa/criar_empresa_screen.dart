import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../../services/empresa/empresa_service.dart';

class CriarEmpresaScreen extends StatefulWidget {
  const CriarEmpresaScreen({super.key});

  @override
  State<CriarEmpresaScreen> createState() => _CriarEmpresaScreenState();
}

class _CriarEmpresaScreenState extends State<CriarEmpresaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _razaoSocialController = TextEditingController();
  final _nomeFantasiaController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();

  bool _isLoading = false;
  String? _planoId;
  String? _planoNome;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _planoId = args?['planoId']?.toString();
    _planoNome = args?['planoNome']?.toString();
  }

  @override
  void dispose() {
    _razaoSocialController.dispose();
    _nomeFantasiaController.dispose();
    _cnpjController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final token = await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final result = await EmpresaService.criar(
      token: token,
      razaoSocial: _razaoSocialController.text.trim(),
      nomeFantasia: _nomeFantasiaController.text.trim(),
      cnpj: _cnpjController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      emailContato: _emailController.text.trim(),
      telefone: _telefoneController.text.trim(),
      cidade: _cidadeController.text.trim(),
      estado: _estadoController.text.trim().toUpperCase(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final empresaId = (result['data'] as Map<String, dynamic>)['id']?.toString();

      if (empresaId != null) {
        await AuthStorage.saveUser(isEmpresaAdmin: true);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Empresa cadastrada com sucesso!'),
          backgroundColor: Color(0xFF388E3C),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // segue pro pagamento pra ativar a assinatura da empresa
      Navigator.pushReplacementNamed(
        context,
        '/pagamento',
        arguments: {
          'planoId': _planoId,
          'planoNome': _planoNome,
          'empresaId': empresaId,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erro ao cadastrar empresa'),
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
        title: const Text('Cadastrar Empresa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_planoNome != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business, color: AppColors.primaryRed),
                          const SizedBox(width: 12),
                          Text(
                            'Plano selecionado: $_planoNome',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    'Dados da empresa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildCampo(
                    controller: _razaoSocialController,
                    label: 'Razão Social *',
                    hint: 'Ex: Oficina Silva LTDA',
                    validator: (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  _buildCampo(
                    controller: _nomeFantasiaController,
                    label: 'Nome Fantasia',
                    hint: 'Ex: Oficina Silva',
                  ),
                  _buildCampo(
                    controller: _cnpjController,
                    label: 'CNPJ *',
                    hint: '00.000.000/0000-00',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Campo obrigatório';
                      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length != 14) return 'CNPJ inválido';
                      return null;
                    },
                  ),
                  _buildCampo(
                    controller: _emailController,
                    label: 'Email de contato *',
                    hint: 'contato@empresa.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Campo obrigatório';
                      if (!v.contains('@')) return 'Email inválido';
                      return null;
                    },
                  ),
                  _buildCampo(
                    controller: _telefoneController,
                    label: 'Telefone',
                    hint: '(00) 00000-0000',
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Localização',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildCampo(
                          controller: _cidadeController,
                          label: 'Cidade *',
                          hint: 'Ex: Belo Horizonte',
                          validator: (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCampo(
                          controller: _estadoController,
                          label: 'Estado *',
                          hint: 'MG',
                          maxLength: 2,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obrigatório';
                            if (v.length != 2) return 'Sigla';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Cadastrar empresa',
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
        ),
      ),
    );
  }

  Widget _buildCampo({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
          ),
        ),
        validator: validator,
      ),
    );
  }
}