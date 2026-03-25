import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/app_colors.dart';
import '../../utils/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _extractJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];

      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _errorMessage = 'Preencha todos os campos.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService.login(email: email, senha: senha);

      if (!mounted) return;

      if (result['success'] == true) {
        final token = result['token'] ?? '';
        if (token.isNotEmpty) {
          await AuthStorage.saveToken(token);
        }

        final jwtPayload = token.isNotEmpty ? _extractJwtPayload(token) : null;

        String nome = (result['nome'] ?? '').toString().trim();
        String sobrenome = (result['sobrenome'] ?? '').toString().trim();

        if (nome.isEmpty) {
          nome =
              (jwtPayload?['nome'] ??
                      jwtPayload?['name'] ??
                      jwtPayload?['given_name'] ??
                      '')
                  .toString()
                  .trim();
        }
        if (sobrenome.isEmpty) {
          sobrenome =
              (jwtPayload?['sobrenome'] ??
                      jwtPayload?['family_name'] ??
                      jwtPayload?['surname'] ??
                      '')
                  .toString()
                  .trim();
        }

        String userEmail = (result['email'] ?? '').toString().trim();
        if (userEmail.isEmpty) {
          userEmail = (jwtPayload?['email'] ?? jwtPayload?['mail'] ?? '')
              .toString()
              .trim();
        }
        if (userEmail.isEmpty) userEmail = email;

        String? userId = (result['id'] ?? result['userId'])?.toString();
        if (userId == null || userId.trim().isEmpty) {
          userId =
              (jwtPayload?['sub'] ?? jwtPayload?['id'] ?? jwtPayload?['userId'])
                  ?.toString();
        }

        String? fotoPerfil = (result['fotoPerfil'] ?? '').toString().trim();
        if (fotoPerfil.isEmpty) {
          final claimPhoto =
              (jwtPayload?['fotoPerfil'] ??
                      jwtPayload?['picture'] ??
                      jwtPayload?['avatar'])
                  ?.toString();
          fotoPerfil = claimPhoto == null || claimPhoto.trim().isEmpty
              ? null
              : claimPhoto.trim();
        }

        String userRole = (result['funcao'] ?? '').toString().trim();
        if (userRole.isEmpty) {
          userRole =
              (jwtPayload?['funcao'] ??
                      jwtPayload?['role'] ??
                      jwtPayload?['perfil'] ??
                      '')
                  .toString()
                  .trim();
        }

        String userPhone = (result['telefone'] ?? '').toString().trim();
        if (userPhone.isEmpty) {
          userPhone =
              (jwtPayload?['telefone'] ??
                      jwtPayload?['phone'] ??
                      jwtPayload?['celular'] ??
                      '')
                  .toString()
                  .trim();
        }

        String userMemberSince = (result['memberSince'] ?? '')
            .toString()
            .trim();
        if (userMemberSince.isEmpty) {
          userMemberSince =
              (jwtPayload?['createdAt'] ??
                      jwtPayload?['dataCriacao'] ??
                      jwtPayload?['created_at'] ??
                      '')
                  .toString()
                  .trim();
        }

        // Busca dados completos do usuário (incluindo foto) quando login não retorna tudo
        if (token.isNotEmpty) {
          final fullProfile = await AuthService.buscarPerfilCompleto(
            token: token,
            userId: userId,
            email: userEmail,
          );

          if (fullProfile['success'] == true) {
            final fullNome = (fullProfile['nome'] ?? '').toString().trim();
            final fullSobrenome = (fullProfile['sobrenome'] ?? '')
                .toString()
                .trim();
            final mergedName = [
              if (fullNome.isNotEmpty) fullNome,
              if (fullSobrenome.isNotEmpty) fullSobrenome,
            ].join(' ').trim();

            if (mergedName.isNotEmpty) {
              nome = fullNome;
              sobrenome = fullSobrenome;
            }

            final fullEmail = (fullProfile['email'] ?? '').toString().trim();
            if (fullEmail.isNotEmpty) userEmail = fullEmail;

            final fullId = (fullProfile['id'] ?? '').toString().trim();
            if (fullId.isNotEmpty) userId = fullId;

            final fullPhoto = (fullProfile['fotoPerfil'] ?? '')
                .toString()
                .trim();
            if (fullPhoto.isNotEmpty) fotoPerfil = fullPhoto;

            final fullRole = (fullProfile['funcao'] ?? '').toString().trim();
            if (fullRole.isNotEmpty) userRole = fullRole;

            final fullPhone = (fullProfile['telefone'] ?? '').toString().trim();
            if (fullPhone.isNotEmpty) userPhone = fullPhone;

            final fullMemberSince = (fullProfile['memberSince'] ?? '')
                .toString()
                .trim();
            if (fullMemberSince.isNotEmpty) userMemberSince = fullMemberSince;
          }
        }

        final resolvedFullName = [
          nome,
          sobrenome,
        ].where((s) => s.toString().trim().isNotEmpty).join(' ').trim();

        final currentName = await AuthStorage.getUserName();
        final currentEmail = await AuthStorage.getUserEmail();
        final currentPhoto = await AuthStorage.getUserProfilePhoto();
        final isSameUser =
            currentEmail != null && currentEmail.trim() == userEmail.trim();

        await AuthStorage.saveUser(
          id: userId,
          name: resolvedFullName.isNotEmpty
              ? resolvedFullName
              : (isSameUser &&
                        currentName != null &&
                        currentName.trim().isNotEmpty
                    ? currentName
                    : null),
          email: userEmail,
          profilePhoto: fotoPerfil ?? (isSameUser ? currentPhoto : null),
          role: userRole.isNotEmpty ? userRole : null,
          phone: userPhone.isNotEmpty ? userPhone : null,
          memberSince: userMemberSince.isNotEmpty ? userMemberSince : null,
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(
          () => _errorMessage = result['message'] ?? 'Credenciais inválidas.',
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.toLowerCase().contains('xmlhttprequest') ||
          msg.toLowerCase().contains('cors') ||
          msg.toLowerCase().contains('failed to fetch')) {
        setState(
          () => _errorMessage =
              'Erro de CORS: o servidor precisa permitir requisições web. Execute o app como Windows (flutter run -d windows).',
        );
      } else {
        setState(() => _errorMessage = 'Erro: $msg');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.isDesktop ? 450 : double.infinity,
              ),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(context.isDesktop ? 48 : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: context.isDesktop ? 140 : 120,
                        height: context.isDesktop ? 140 : 120,
                        decoration: BoxDecoration(
                          color: AppColors.iconBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Icon(
                          Icons.directions_car,
                          size: context.isDesktop ? 72 : 64,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'AutoScan',
                        style: TextStyle(
                          fontSize: context.isDesktop ? 32 : 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Diagnóstico Inteligentes de Veículos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _senhaController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primaryRed.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.primaryRed,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Não tem uma conta?',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text(
                              'Cadastrar-se',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
