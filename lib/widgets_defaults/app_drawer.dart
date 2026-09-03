import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../services/chat_read_tracker.dart';
import 'network_avatar_image.dart';
import '../services/payment/recursos.dart';
import '../widgets/recurso_visivel.dart';

class AppDrawer extends StatefulWidget {
  final String? currentRoute;
  const AppDrawer({super.key, this.currentRoute});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _userName = 'Usuário';
  String _userEmail = '';
  String _userRole = '';
  bool _isEmpresaAdmin = false;
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoUrl;
  bool _photoLoadFailed = false;

  bool get _isAdminOrAssistente {
    final role = _userRole.trim().toUpperCase();
    return role == 'ADMIN' || role == 'ASSISTENTE';
  }

  bool get _deveExibirAtendimentos {
    final role = _userRole.trim().toUpperCase();
    if (role == 'ASSISTENTE') return true;
    if (role == 'ADMIN') return ChatReadTracker.temMeusAtendimentos;
    return false;
  }

  Uint8List? _decodePhotoBytes(String rawPhoto) {
    try {
      final normalized = rawPhoto.trim();
      if (normalized.isEmpty) return null;

      final commaIndex = normalized.indexOf(',');
      final base64Part = normalized.startsWith('data:image') && commaIndex > -1
          ? normalized.substring(commaIndex + 1)
          : normalized;

      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  String? _resolvePhotoUrl(String rawPhoto) {
    final normalized = rawPhoto.trim();
    if (normalized.isEmpty) return null;
    final lower = normalized.toLowerCase();

    final looksLikeImageFile =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    final looksRelativePath =
        normalized.startsWith('/') ||
        normalized.startsWith('uploads/') ||
        normalized.startsWith('images/') ||
        normalized.startsWith('storage/') ||
        normalized.contains('/uploads/') ||
        normalized.contains('/images/');

    if (looksLikeImageFile && !normalized.contains('/')) {
      return '${ApiConfig.baseUrl}/uploads/$normalized';
    }

    if (!looksRelativePath) return null;
    if (normalized.startsWith('/')) {
      return '${ApiConfig.baseUrl}$normalized';
    }

    return '${ApiConfig.baseUrl}/$normalized';
  }

  Widget _buildAvatar() {
    if (_profilePhotoBytes != null) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: MemoryImage(_profilePhotoBytes!),
      );
    }
    if (!_photoLoadFailed &&
        _profilePhotoUrl != null &&
        _profilePhotoUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 44,
          height: 44,
          child: NetworkAvatarImage(
            imageUrl: _profilePhotoUrl!,
            fit: BoxFit.cover,
            fallback: Container(
              color: AppColors.primaryRed,
              alignment: Alignment.center,
              child: const Icon(
                Icons.person,
                size: 24,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    return const CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primaryRed,
      child: Icon(Icons.person, size: 24, color: Colors.white),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await AuthStorage.getUserName();
    final email = await AuthStorage.getUserEmail();
    final photo = await AuthStorage.getUserProfilePhoto();
    final role = await AuthStorage.getUserRole();
    final isEmpAdmin = await AuthStorage.isEmpresaAdmin();

    Uint8List? photoBytes;
    String? photoUrl;
    if (photo != null && photo.trim().isNotEmpty) {
      final normalized = photo.trim();
      photoUrl = _resolvePhotoUrl(normalized);
      photoBytes = photoUrl == null ? _decodePhotoBytes(normalized) : null;
    }

    if (mounted) {
      print('DEBUG APP_DRAWER: name="$name", role="$role", isEmpAdmin=$isEmpAdmin');
      setState(() {
        _userName = name ?? 'Usuário';
        _userEmail = email ?? '';
        _userRole = role ?? '';
        _isEmpresaAdmin = isEmpAdmin;
        _profilePhotoBytes = photoBytes;
        _profilePhotoUrl = photoUrl;
        _photoLoadFailed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryRed, Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'lib/assets/Logo Autex.png',
                      width: 110,
                      fit: BoxFit.contain,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userEmail,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Início'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('Diagnóstico'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/diagnostic');
                  },
                ),
                if (!_isAdminOrAssistente)
                  RecursoVisivel(
                    recurso: Recursos.esquemaEletrico,
                    child: ListTile(
                      leading: const Icon(Icons.electrical_services_outlined),
                      title: const Text('Esquema Elétrico'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/minhas-solicitacoes');
                      },
                    ),
                  ),
                if (widget.currentRoute == '/chat')
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: const Text('Chat'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/chat');
                    },
                  ),
                if (_deveExibirAtendimentos) ...[
                  ValueListenableBuilder<int>(
                    valueListenable: ChatReadTracker.notifier,
                    builder: (context, _, __) {
                      final diagCount = ChatReadTracker.totalDiagnosticoUnread;
                      final esqCount = ChatReadTracker.totalEsquemaUnread;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.support_agent),
                            title: Row(
                              children: [
                                const Text('Atend. Diagnósticos'),
                                if (diagCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryRed,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$diagCount',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushReplacementNamed(
                                context,
                                '/chat-history',
                                arguments: const {'tipo': 'DIAGNOSTICO'},
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.electrical_services),
                            title: Row(
                              children: [
                                const Text('Atend. Esquemas'),
                                if (esqCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryRed,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$esqCount',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushReplacementNamed(
                                context,
                                '/chat-history',
                                arguments: const {'tipo': 'ESQUEMA_ELETRICO'},
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
                if (_isEmpresaAdmin || _userRole.trim().toUpperCase() == 'ADMIN_EMPRESA')
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: const Text('Empresa'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/empresa/funcionarios');
                    },
                  ),
                if (_userRole.trim().toUpperCase() == 'ADMIN')
                  ListTile(
                    leading: const Icon(Icons.manage_accounts),
                    title: const Text('Gestão do Sistema'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/admin/users');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Histórico'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/history');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Planos'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/plans');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Perfil'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/profile');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app),
                  title: const Text('Sair'),
                  onTap: () => AuthService.logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
