import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../theme/app_colors.dart';
import '../services/auth_storage.dart';
import '../services/api_config.dart';
import 'network_avatar_image.dart';

class AppSidebar extends StatefulWidget {
  final String currentRoute;

  const AppSidebar({super.key, required this.currentRoute});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  String _userName = '';
  String _userEmail = '';
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoUrl;
  bool _photoLoadFailed = false;

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
        radius: 20,
        backgroundImage: MemoryImage(_profilePhotoBytes!),
      );
    }
    if (!_photoLoadFailed &&
        _profilePhotoUrl != null &&
        _profilePhotoUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 40,
          height: 40,
          child: NetworkAvatarImage(
            imageUrl: _profilePhotoUrl!,
            fit: BoxFit.cover,
            fallback: Container(
              color: AppColors.primaryRed,
              alignment: Alignment.center,
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ),
        ),
      );
    }
    return const CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primaryRed,
      child: Icon(Icons.person, color: Colors.white, size: 24),
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
        _profilePhotoBytes = photoBytes;
        _profilePhotoUrl = photoUrl;
        _photoLoadFailed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    size: 28,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AutoScan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(
                  context,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  route: '/home',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  route: '/dashboard',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics,
                  label: 'Diagnóstico',
                  route: '/diagnostic',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.chat_outlined,
                  activeIcon: Icons.chat,
                  label: 'Chat',
                  route: '/chat',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: 'Histórico',
                  route: '/history',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.description_outlined,
                  activeIcon: Icons.description,
                  label: 'Planos',
                  route: '/plans',
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildNavItem(
                  context,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Perfil',
                  route: '/profile',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _userName.isNotEmpty ? _userName : 'Usuário',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_userEmail.isNotEmpty)
                        Text(
                          _userEmail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () async {
                    await AuthStorage.clear();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    }
                  },
                  tooltip: 'Sair',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
  }) {
    final isActive = widget.currentRoute == route;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isActive) {
              Navigator.pushReplacementNamed(context, route);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? AppColors.lightRed : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 22,
                  color: isActive
                      ? AppColors.primaryRed
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? AppColors.primaryRed
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
