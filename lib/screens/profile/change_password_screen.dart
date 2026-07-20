import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/auth_storage.dart';
import '../../services/auth_service.dart';
import '../../services/logger_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarNovaSenhaController = TextEditingController();

  bool _obscureSenhaAtual = true;
  bool _obscureNovaSenha = true;
  bool _obscureConfirmarNovaSenha = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarNovaSenhaController.dispose();
    super.dispose();
  }

  Future<void> _alterarSenha() async {
    if (!_formKey.currentState!.validate()) return;

    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.alterarSenha(
        token: token,
        senhaAtual: _senhaAtualController.text,
        novaSenha: _novaSenhaController.text,
        confirmarNovaSenha: _confirmarNovaSenhaController.text,
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Senha alterada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Erro ao alterar senha'),
              backgroundColor: AppColors.primaryRed,
            ),
          );
        }
      }
    } catch (e) {
      loggerService.e('Erro ao alterar senha: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar senha: $e'),
            backgroundColor: AppColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/change-password',
      title: 'Alterar Senha',
      showAppBar: !context.isDesktop,
      child: Container(
        color: AppColors.background,
        child: context.isDesktop
            ? _buildDesktopLayout(context)
            : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Center(
        child: SizedBox(
          width: 500,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: _buildFormContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Alterar Senha',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 48), // espaçador para alinhar o título
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildFormContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Segurança da Conta',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escolha uma senha forte para manter sua conta protegida.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _senhaAtualController,
            enabled: !_isLoading,
            obscureText: _obscureSenhaAtual,
            decoration: InputDecoration(
              labelText: 'Senha Atual',
              hintText: 'Digite sua senha atual',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.lock_open),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSenhaAtual
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() => _obscureSenhaAtual = !_obscureSenhaAtual);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Senha atual é obrigatória';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _novaSenhaController,
            enabled: !_isLoading,
            obscureText: _obscureNovaSenha,
            decoration: InputDecoration(
              labelText: 'Nova Senha',
              hintText: 'Digite a nova senha',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNovaSenha
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() => _obscureNovaSenha = !_obscureNovaSenha);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nova senha é obrigatória';
              }
              if (value.length < 6) {
                return 'A nova senha deve ter pelo menos 6 caracteres';
              }
              if (value == _senhaAtualController.text) {
                return 'A nova senha deve ser diferente da atual';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _confirmarNovaSenhaController,
            enabled: !_isLoading,
            obscureText: _obscureConfirmarNovaSenha,
            decoration: InputDecoration(
              labelText: 'Confirmar Nova Senha',
              hintText: 'Confirme a nova senha',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmarNovaSenha
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() =>
                      _obscureConfirmarNovaSenha = !_obscureConfirmarNovaSenha);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirmação de nova senha é obrigatória';
              }
              if (value != _novaSenhaController.text) {
                return 'As senhas não coincidem';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _alterarSenha,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Salvar Senha'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
