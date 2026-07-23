import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/auth_storage.dart';
import '../../services/empresa/empresa_service.dart';

class EmpresaFuncionariosScreen extends StatefulWidget {
  const EmpresaFuncionariosScreen({super.key});

  @override
  State<EmpresaFuncionariosScreen> createState() => _EmpresaFuncionariosScreenState();
}

class _EmpresaFuncionariosScreenState extends State<EmpresaFuncionariosScreen> {
  List<Map<String, dynamic>> _membros = [];
  bool _isLoading = true;
  String? _empresaId;
  String? _empresaNome;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _empresaId = args?['empresaId']?.toString();
    _empresaNome = args?['empresaNome']?.toString();
    _carregarMembros();
  }

  Future<void> _carregarMembros() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final token = await AuthStorage.getToken();
    if (token == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (_empresaId == null) {
      final minhaEmpresaRes = await EmpresaService.buscarMinhaEmpresa(token: token);
      if (!mounted) return;

      if (minhaEmpresaRes['semEmpresa'] == true) {
        Navigator.pushReplacementNamed(context, '/empresa/criar');
        return;
      } else if (minhaEmpresaRes['success'] == true && minhaEmpresaRes['data'] != null) {
        final data = minhaEmpresaRes['data'];
        final empresaData = data['empresa'] ?? data;
        _empresaId = empresaData['_id']?.toString() ?? empresaData['id']?.toString();
        _empresaNome = empresaData['razaoSocial']?.toString() ?? empresaData['nomeFantasia']?.toString();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = minhaEmpresaRes['message']?.toString() ?? 'Empresa não encontrada';
        });
        return;
      }
    }

    if (_empresaId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Empresa não encontrada';
      });
      return;
    }

    final result = await EmpresaService.listarMembros(
      token: token, empresaId: _empresaId!,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _membros = (result['data'] as List).cast<Map<String, dynamic>>();
      } else {
        _errorMessage = result['message']?.toString();
      }
    });
  }

  void _abrirModalAdicionarFuncionario() {
    if (_empresaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID da empresa não carregado. Tente recarregar a página.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ModalAdicionarFuncionario(
        empresaId: _empresaId!,
        onSucesso: _carregarMembros,
      ),
    );
  }

  Future<void> _removerFuncionario(String funcionarioId, String nome) async {
    if (_empresaId == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover funcionário'),
        content: Text('Deseja remover $nome da empresa? A conta dele será desativada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final token = await AuthStorage.getToken();
    if (token == null) return;

    final ok = await EmpresaService.removerFuncionario(
      token: token, empresaId: _empresaId!, funcionarioId: funcionarioId,
    );

    if (!mounted) return;
    if (ok) {
      _carregarMembros();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Funcionário removido'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao remover funcionário'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/empresa/funcionarios',
      title: 'Funcionários',
      showAppBar: !context.isDesktop,
      child: Container(
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _empresaNome ?? 'Minha Empresa',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${_membros.length} funcionário${_membros.length != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _abrirModalAdicionarFuncionario,
                    icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
                    label: const Text('Adicionar funcionário', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
              else if (_errorMessage != null)
                _buildErro()
              else if (_membros.isEmpty)
                _buildVazio()
              else
                _buildLista(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 48),
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(onPressed: _carregarMembros, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline, size: 40, color: AppColors.primaryRed),
            ),
            const SizedBox(height: 20),
            const Text('Nenhum funcionário cadastrado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('Clique em "Adicionar funcionário" para começar',
                style: TextStyle(fontSize: 14, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildLista() {
    return Column(
      children: _membros.map((membro) {
        final usuario = membro['usuario'] as Map<String, dynamic>? ?? membro;
        final id = usuario['id']?.toString() ?? '';
        final nome = '${usuario['nome'] ?? ''} ${usuario['sobrenome'] ?? ''}'.trim();
        final email = usuario['email']?.toString() ?? '';
        final papel = membro['papel']?.toString() ?? 'FUNCIONARIO_EMPRESA';
        // agora o backend retorna ADMIN_EMPRESA ou FUNCIONARIO_EMPRESA
        final isAdmin = papel == 'ADMIN_EMPRESA';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isAdmin
                      ? AppColors.primaryRed.withValues(alpha: 0.1)
                      : AppColors.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAdmin ? Icons.admin_panel_settings : Icons.person,
                  color: isAdmin ? AppColors.primaryRed : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(nome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? AppColors.primaryRed.withValues(alpha: 0.1)
                                : AppColors.iconBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isAdmin ? 'Admin' : 'Membro',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isAdmin ? AppColors.primaryRed : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (!isAdmin)
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined, color: AppColors.textLight),
                  tooltip: 'Remover funcionário',
                  onPressed: () => _removerFuncionario(id, nome),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Modal de adicionar funcionário ────────────────────────────────────────────

class _ModalAdicionarFuncionario extends StatefulWidget {
  final String empresaId;
  final VoidCallback onSucesso;

  const _ModalAdicionarFuncionario({
    required this.empresaId,
    required this.onSucesso,
  });

  @override
  State<_ModalAdicionarFuncionario> createState() => _ModalAdicionarFuncionarioState();
}

class _ModalAdicionarFuncionarioState extends State<_ModalAdicionarFuncionario> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();

  // valores agora batem com o enum do backend
  String _papel = 'FUNCIONARIO_EMPRESA';
  bool _isLoading = false;
  bool _senhaVisivel = false;

  @override
  void initState() {
    super.initState();
    _gerarSenha();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _gerarSenha() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#';
    final rand = Random.secure();
    final senha = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
    _senhaController.text = senha;
  }

  void _copiarSenha() {
    Clipboard.setData(ClipboardData(text: _senhaController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Senha copiada para a área de transferência'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final token = await AuthStorage.getToken();
    if (token == null) return;

    final result = await EmpresaService.adicionarFuncionario(
      token: token,
      empresaId: widget.empresaId,
      nome: _nomeController.text.trim(),
      sobrenome: _sobrenomeController.text.trim(),
      email: _emailController.text.trim(),
      telefone: _telefoneController.text.trim(),
      senha: _senhaController.text,
      papel: _papel,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pop(context);
      widget.onSucesso();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Funcionário adicionado com sucesso!'),
          backgroundColor: Color(0xFF388E3C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erro ao adicionar funcionário'),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Adicionar funcionário',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: _buildCampo(_nomeController, 'Nome *',
                        validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCampo(_sobrenomeController, 'Sobrenome *',
                        validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null)),
                  ],
                ),
                _buildCampo(_emailController, 'Email *',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obrigatório';
                      if (!v.contains('@')) return 'Email inválido';
                      return null;
                    }),
                _buildCampo(_telefoneController, 'Telefone',
                    keyboardType: TextInputType.phone),

                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _senhaController,
                    obscureText: !_senhaVisivel,
                    decoration: InputDecoration(
                      labelText: 'Senha *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                            tooltip: 'Mostrar/ocultar senha',
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: AppColors.primaryRed),
                            onPressed: _copiarSenha,
                            tooltip: 'Copiar senha',
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                            onPressed: () => setState(_gerarSenha),
                            tooltip: 'Gerar nova senha',
                          ),
                        ],
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.iconBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Papel na empresa',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPapelOption(
                              'FUNCIONARIO_EMPRESA', 'Membro', 'Usa o sistema normalmente'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPapelOption(
                              'ADMIN_EMPRESA', 'Admin', 'Gerencia funcionários'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF856404), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Copie a senha antes de salvar — ela não será mostrada novamente.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Adicionar funcionário',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampo(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
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

  Widget _buildPapelOption(String valor, String titulo, String descricao) {
    final selected = _papel == valor;
    return GestureDetector(
      onTap: () => setState(() => _papel = valor),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryRed.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primaryRed : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primaryRed : AppColors.textLight,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected ? AppColors.primaryRed : AppColors.textPrimary,
                    )),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(descricao,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}