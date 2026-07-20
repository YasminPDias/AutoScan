import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/auth_storage.dart';
import '../../services/auth_service.dart';
import '../../services/logger_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _telefoneController = TextEditingController();

  Uint8List? _newProfilePhotoBytes;
  String? _newProfilePhotoPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final nome = await AuthStorage.getUserName() ?? '';
    final phone = await AuthStorage.getUserPhone() ?? '';

    // Dividir nome em nome e sobrenome
    final parts = nome.split(' ');
    final firstName = parts.isNotEmpty ? parts[0] : '';
    final lastName = parts.length > 1 ? parts.skip(1).join(' ') : '';

    if (mounted) {
      setState(() {
        _nomeController.text = firstName;
        _sobrenomeController.text = lastName;
        _telefoneController.text = phone;
      });
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          // Comprimir imagem se necessário
          final image = img.decodeImage(bytes);
          if (image != null) {
            final resized = img.copyResize(image, width: 300, height: 300);
            final compressed = img.encodeJpg(resized, quality: 80);

            if (mounted) {
              setState(() {
                _newProfilePhotoBytes = Uint8List.fromList(compressed);
                _newProfilePhotoPath = result.files.first.name;
              });
            }
          }
        }
      }
    } catch (e) {
      loggerService.e('Erro ao selecionar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar foto: $e')),
        );
      }
    }
  }

  Future<void> _atualizarPerfil() async {
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
      final result = await AuthService.atualizarPerfil(
        token: token,
        nome: _nomeController.text.trim(),
        sobrenome: _sobrenomeController.text.trim(),
        telefone: _telefoneController.text.trim(),
        fotoPerfilArquivoBytes: _newProfilePhotoBytes,
        fotoPerfilArquivoNome: _newProfilePhotoPath,
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil atualizado com sucesso!')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Erro ao atualizar perfil',
              ),
            ),
          );
        }
      }
    } catch (e) {
      loggerService.e('Erro ao atualizar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/edit-profile',
      title: 'Editar Perfil',
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
          width: 600,
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
                  'Editar Perfil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 48),
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
            'Foto de Perfil',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                if (_newProfilePhotoBytes != null)
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: MemoryImage(_newProfilePhotoBytes!),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _newProfilePhotoBytes = null;
                              _newProfilePhotoPath = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryRed.withOpacity(0.1),
                      border: Border.all(
                        color: AppColors.primaryRed,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.primaryRed,
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickProfilePhoto,
                  icon: const Icon(Icons.image),
                  label: const Text('Selecionar Foto'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Informações Pessoais',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nomeController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Nome',
              hintText: 'Seu nome',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nome é obrigatório';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sobrenomeController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Sobrenome',
              hintText: 'Seu sobrenome',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Sobrenome é obrigatório';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _telefoneController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Telefone',
              hintText: '(XX) XXXXX-XXXX',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Telefone é obrigatório';
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
                  onPressed: _isLoading ? null : _atualizarPerfil,
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
                      : const Text('Salvar Alterações'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
