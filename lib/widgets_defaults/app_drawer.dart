import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../services/api_config.dart';
import 'network_avatar_image.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _userName = 'Usuário';
  String _userEmail = '';
  String _userRole = '';
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoUrl;
  bool _photoLoadFailed = false;

  bool get _isAdminOrAssistente {
    final role = _userRole.toUpperCase();
    return role == 'ADMIN' || role == 'ASSISTENTE';
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
        radius: 40,
        backgroundImage: MemoryImage(_profilePhotoBytes!),
      );
    }
    if (!_photoLoadFailed &&
        _profilePhotoUrl != null &&
        _profilePhotoUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 80,
          height: 80,
          child: NetworkAvatarImage(
            imageUrl: _profilePhotoUrl!,
            fit: BoxFit.cover,
            fallback: Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: const Icon(
                Icons.person,
                size: 48,
                color: AppColors.primaryRed,
              ),
            ),
          ),
        ),
      );
    }
    return const CircleAvatar(
      radius: 40,
      backgroundColor: Colors.white,
      child: Icon(Icons.person, size: 48, color: AppColors.primaryRed),
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

    Uint8List? photoBytes;
    String? photoUrl;
    if (photo != null && photo.trim().isNotEmpty) {
      final normalized = photo.trim();
      photoUrl = _resolvePhotoUrl(normalized);
      photoBytes = photoUrl == null ? _decodePhotoBytes(normalized) : null;
    }

    if (mounted) {
      setState(() {
        _userName = name ?? 'Usuário';
        _userEmail = email ?? '';
        _userRole = role ?? '';
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
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(color: AppColors.primaryRed),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(child: _buildAvatar()),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _userEmail,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                  leading: const Icon(Icons.person),
                  title: const Text('Perfil'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Painel Administrativo'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/dashboard');
                  },
                ),
                if (_isAdminOrAssistente)
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Atendimentos'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/chat-history');
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app),
                  title: const Text('Sair'),
                  onTap: () async {
                    await AuthStorage.clear();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
