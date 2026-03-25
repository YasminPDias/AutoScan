import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:typed_data';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _funcaoController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedFuncao;
  Uint8List? _fotoPerfilBytes;
  String? _fotoPerfilBase64;
  String? _fotoPerfilNome;
  String? _fotoErro;
  final List<String> _funcoes = ['ADMIN', 'ASSISTENTE', 'CLIENTE'];
  static const int _maxFotoSize = 1048576; // 1MB em bytes (foi 5MB)
  static const List<String> _fotoFormatos = ['jpg', 'jpeg', 'png'];

  // Comprime uma imagem para reduzir o tamanho do payload
  Future<Uint8List> _comprimirImagem(Uint8List imageBytes) async {
    try {
      img.Image? img_original = img.decodeImage(imageBytes);
      if (img_original == null) return imageBytes;

      // Reduz para máximo 512x512
      img.Image img_redimensionada = img.copyResize(
        img_original,
        width: img_original.width > 512 ? 512 : img_original.width,
        height: img_original.height > 512 ? 512 : img_original.height,
        interpolation: img.Interpolation.average,
      );

      // Codifica como JPEG com qualidade 60% para máxima compressão
      Uint8List comprimida = Uint8List.fromList(
        img.encodeJpg(img_redimensionada, quality: 60),
      );

      return comprimida;
    } catch (e) {
      // Se houver erro, retorna a imagem original
      return imageBytes;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _telefoneController.dispose();
    _funcaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarFoto() async {
    try {
      final FilePickerResult? resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _fotoFormatos,
        withData: true,
      );

      if (resultado == null || resultado.files.isEmpty) return;

      final PlatformFile arquivo = resultado.files.first;
      final String ext = (arquivo.extension ?? '').toLowerCase();
      if (!_fotoFormatos.contains(ext)) {
        setState(() => _fotoErro = 'Formato inválido. Use JPG, JPEG ou PNG.');
        return;
      }

      final int tamanho = arquivo.size;
      if (tamanho > _maxFotoSize) {
        setState(() => _fotoErro = 'Arquivo muito grande. Máximo 1MB.');
        return;
      }

      var bytes = arquivo.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(
          () => _fotoErro = 'Não foi possível ler a imagem selecionada.',
        );
        return;
      }

      // Comprime a imagem para reduzir o tamanho
      bytes = await _comprimirImagem(bytes);

      final String base64String = base64Encode(bytes);
      final String fileName = (arquivo.name.trim().isNotEmpty)
          ? arquivo.name.trim()
          : 'perfil.$ext';

      setState(() {
        _fotoPerfilBytes = bytes;
        _fotoPerfilBase64 = base64String;
        _fotoPerfilNome = fileName;
        _fotoErro = null;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _fotoErro = 'Erro ao selecionar foto.');
    }
  }

  Future<void> _register() async {
    final nome = _nomeController.text.trim();
    final sobrenome = _sobrenomeController.text.trim();
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    final confirmarSenha = _confirmarSenhaController.text;
    final telefone = _telefoneController.text.trim();
    final funcao = _selectedFuncao;

    if (nome.isEmpty ||
        sobrenome.isEmpty ||
        email.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty ||
        telefone.isEmpty) {
      setState(() => _errorMessage = 'Preencha todos os campos obrigatórios.');
      return;
    }

    if (senha != confirmarSenha) {
      setState(() => _errorMessage = 'As senhas não coincidem.');
      return;
    }

    if (senha.length < 6) {
      setState(
        () => _errorMessage = 'A senha deve ter pelo menos 6 caracteres.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var result = await AuthService.registrar(
        nome: nome,
        sobrenome: sobrenome,
        email: email,
        senha: senha,
        confirmarSenha: confirmarSenha,
        telefone: telefone,
        funcao: funcao ?? 'CLIENTE',
        fotoPerfil: _fotoPerfilBase64,
        fotoPerfilArquivoBytes: _fotoPerfilBytes,
        fotoPerfilArquivoNome: _fotoPerfilNome,
      );

      if (!mounted) return;

      // Se falhar por payload muito grande, tenta novamente sem foto
      if (result['success'] != true &&
          result['message'] != null &&
          result['message'].toString().toLowerCase().contains('entity')) {
        result = await AuthService.registrar(
          nome: nome,
          sobrenome: sobrenome,
          email: email,
          senha: senha,
          confirmarSenha: confirmarSenha,
          telefone: telefone,
          funcao: funcao ?? 'CLIENTE',
          fotoPerfil: null,
          fotoPerfilArquivoBytes: null,
          fotoPerfilArquivoNome: null,
        );
      }

      if (!mounted) return;

      if (result['success'] == true) {
        await AuthStorage.saveUser(
          name: '$nome $sobrenome'.trim(),
          email: email,
          profilePhoto: _fotoPerfilBase64,
          role: funcao ?? 'CLIENTE',
          phone: telefone,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso! Faça seu login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(
          () => _errorMessage = result['message'] ?? 'Erro ao criar conta.',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erro de conexão. Tente novamente.');
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
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AutoScan',
                      style: TextStyle(
                        fontSize: 28,
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
                    const SizedBox(height: 24),
                    const Text(
                      'Criar Conta Nova',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _isLoading ? null : _selecionarFoto,
                      child: Column(
                        children: [
                          if (_fotoPerfilBytes != null)
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundImage: MemoryImage(
                                    _fotoPerfilBytes!,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _fotoPerfilBytes = null;
                                      _fotoPerfilBase64 = null;
                                      _fotoPerfilNome = null;
                                      _fotoErro = null;
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryRed,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.textSecondary,
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              padding: const EdgeInsets.all(24),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 32,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            'Foto de Perfil (Opcional)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_fotoErro != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _fotoErro!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nomeController,
                            decoration: const InputDecoration(
                              hintText: 'Nome',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _sobrenomeController,
                            decoration: const InputDecoration(
                              hintText: 'Sobrenome',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmarSenhaController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        hintText: 'Confirmar Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _telefoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Telefone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedFuncao,
                      hint: const Text('Selecionar Função'),
                      items: _funcoes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedFuncao = newValue;
                        });
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.work_outline),
                      ),
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
                            color: AppColors.primaryRed.withValues(alpha: 0.3),
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
                        onPressed: _isLoading ? null : _register,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Cadastrar'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Já tem uma conta?',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Fazer Login',
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
    );
  }
}
