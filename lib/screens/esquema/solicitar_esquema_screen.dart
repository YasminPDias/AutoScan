import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/esquema_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_storage.dart';
import '../../services/logger_service.dart';

class SolicitarEsquemaScreen extends StatefulWidget {
  const SolicitarEsquemaScreen({super.key});

  @override
  State<SolicitarEsquemaScreen> createState() => _SolicitarEsquemaScreenState();
}

class _SolicitarEsquemaScreenState extends State<SolicitarEsquemaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anoController = TextEditingController();
  final _motorController = TextEditingController();
  final _injecaoController = TextEditingController();
  final _observacaoController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // Lista de imagens selecionadas (como bytes para funcionar no Web também!)
  final List<Uint8List> _fotosBytes = [];
  final List<String> _fotosNomes = [];

  bool _isSubmitting = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _motorController.dispose();
    _injecaoController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _escolherOrigemImagem() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryRed),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryRed),
              title: const Text('Galeria de Fotos'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (origem == null) return;
    await _selecionarFoto(origem);
  }

  Future<void> _selecionarFoto(ImageSource origem) async {
    try {
      final XFile? escolhida = await _imagePicker.pickImage(
        source: origem,
        maxWidth: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (escolhida == null) return;

      Uint8List bytes;
      try {
        bytes = await _comprimir(escolhida);
      } catch (e) {
        loggerService.e('Falha ao comprimir imagem: $e');
        _mostrarErro('Não foi possível processar a imagem.');
        return;
      }

      if (bytes.length > 15 * 1024 * 1024) {
        _mostrarErro('Imagem muito grande. Máximo: 15 MB.');
        return;
      }

      setState(() {
        _fotosBytes.add(bytes);
        _fotosNomes.add(escolhida.name);
      });
    } catch (e) {
      loggerService.e('Erro ao selecionar foto: $e');
      _mostrarErro('Erro ao carregar a foto selecionada.');
    }
  }

  Future<Uint8List> _comprimir(XFile arquivo) async {
    if (kIsWeb) return arquivo.readAsBytes();

    final resultado = await FlutterImageCompress.compressWithFile(
      arquivo.path,
      minWidth: 1600,
      minHeight: 1600,
      quality: 85,
      autoCorrectionAngle: true,
      format: CompressFormat.jpeg,
    );

    return resultado ?? await arquivo.readAsBytes();
  }

  void _removerFoto(int index) {
    setState(() {
      _fotosBytes.removeAt(index);
      _fotosNomes.removeAt(index);
    });
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: AppColors.statusUrgent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      _mostrarErro('Sessão expirada. Faça login novamente.');
      return;
    }

    final marca = _marcaController.text.trim();
    final modelo = _modeloController.text.trim();
    final anoModelo = int.tryParse(_anoController.text.trim()) ?? 0;
    final motor = _motorController.text.trim();
    final injecao = _injecaoController.text.trim();
    final observacao = _observacaoController.text.trim();

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Enviando solicitação...';
    });

    try {
      final res = await EsquemaService.criarSolicitacao(
        token: token,
        marca: marca,
        modelo: modelo,
        anoModelo: anoModelo,
        motor: motor,
        injecao: injecao,
        observacao: observacao,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final conversaId = res['conversaId']?.toString() ?? '';

        if (_fotosBytes.isNotEmpty) {
          for (int i = 0; i < _fotosBytes.length; i++) {
            setState(() {
              _statusMessage = 'Enviando foto ${i + 1} de ${_fotosBytes.length}...';
            });

            final bytes = _fotosBytes[i];
            final resultMidia = await ChatService.enviarMidia(
              token: token,
              conversaId: conversaId,
              tipo: 'IMAGEM',
              bytes: bytes,
              fileName: '${_uuid.v4()}.jpg',
              contentType: 'image/jpeg',
              clientMessageId: _uuid.v4(),
            );

            if (resultMidia['success'] != true) {
              loggerService.w('Falha ao enviar foto ${i + 1} de ${_fotosBytes.length}: ${resultMidia['message']}');
            }
          }
        }

        if (mounted) {
          setState(() => _isSubmitting = false);
          Navigator.pushReplacementNamed(
            context,
            '/chat',
            arguments: {'conversaId': conversaId},
          );
        }
      } else {
        setState(() => _isSubmitting = false);
        _mostrarErro(res['message'] ?? 'Erro ao criar solicitação.');
      }
    } catch (e) {
      loggerService.e('Erro ao enviar solicitação: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        _mostrarErro('Erro de conexão: $e');
      }
    }
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primaryRed),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final isDesktop = context.isDesktop;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 28 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dados do Veículo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _marcaController,
                          decoration: InputDecoration(
                            labelText: 'Marca *',
                            hintText: 'Ex: Volkswagen',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Marca é obrigatória';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _modeloController,
                          decoration: InputDecoration(
                            labelText: 'Modelo *',
                            hintText: 'Ex: Gol G6',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Modelo é obrigatório';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _anoController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Ano Modelo *',
                            hintText: 'Ex: 2015',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ano é obrigatório';
                            }
                            final ano = int.tryParse(value.trim());
                            if (ano == null || ano < 1900 || ano > 2100) {
                              return 'Ano inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _motorController,
                          decoration: InputDecoration(
                            labelText: 'Motor (Opcional)',
                            hintText: 'Ex: 1.6 8V',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _injecaoController,
                    decoration: InputDecoration(
                      labelText: 'Injeção (Opcional)',
                      hintText: 'Ex: Bosch ME17.5.26',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _observacaoController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Observação (Opcional)',
                      hintText: 'Ex: Chicote da bobina rompido, preciso do diagrama dos pinos da ECU.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 28 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Fotos e Documentos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _escolherOrigemImagem,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: const Text('Adicionar Foto'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_fotosBytes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: AppColors.iconBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border, style: BorderStyle.none),
                      ),
                      child: const Center(
                        child: Text(
                          'Nenhuma foto anexada',
                          style: TextStyle(color: AppColors.textLight, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(_fotosBytes.length, (index) {
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                                image: DecorationImage(
                                  image: MemoryImage(_fotosBytes[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removerFoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submeter,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Enviar Solicitação',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/solicitar-esquema',
      title: context.isDesktop ? '' : 'Solicitar Esquema',
      showAppBar: !context.isDesktop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop
            ? null
            : AppBar(
                title: const Text('Solicitar Esquema'),
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
              ),
        body: Stack(
          children: [
            Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.isDesktop ? 32 : 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (context.isDesktop) ...[
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Nova Solicitação de Esquema Elétrico',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                        _buildForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isSubmitting) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }
}
