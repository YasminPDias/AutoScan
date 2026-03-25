import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../widgets_defaults/diagnostic_item.dart';
import '../../services/auth_storage.dart';
import '../../services/diagnostic_service.dart';
import '../../services/api_config.dart';
import '../../widgets_defaults/network_avatar_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Usuário';
  String _userEmail = '';
  String _userRole = '';
  String _userPhone = '';
  String _memberSince = '';
  String _totalDiagnostics = '--';
  List<Map<String, dynamic>> _recentDiagnostics = [];
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoUrl;
  bool _photoLoadFailed = false;

  String _formatRole(String role) {
    final normalized = role.trim().toUpperCase();
    switch (normalized) {
      case 'ADMIN':
        return 'Administrador';
      case 'ASSISTENTE':
        return 'Assistente';
      case 'CLIENTE':
        return 'Cliente';
      case 'MECANICO':
        return 'Mecânico';
      default:
        return role.trim().isNotEmpty ? role : 'Não informado';
    }
  }

  String _formatDateShort(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate.trim().isNotEmpty ? isoDate : 'Não informado';
    }
  }

  String _formatMemberSince(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Não informado';
    try {
      final dt = DateTime.parse(value);
      const meses = [
        'Janeiro',
        'Fevereiro',
        'Março',
        'Abril',
        'Maio',
        'Junho',
        'Julho',
        'Agosto',
        'Setembro',
        'Outubro',
        'Novembro',
        'Dezembro',
      ];
      return '${meses[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return value;
    }
  }

  DiagnosticStatus _mapStatus(dynamic rawStatus) {
    final status = rawStatus?.toString().toUpperCase() ?? '';
    switch (status) {
      case 'CONCLUIDO':
        return DiagnosticStatus.resolved;
      case 'INCONCLUSIVO':
        return DiagnosticStatus.urgent;
      case 'PENDENTE':
      case 'EM_ANALISE':
      default:
        return DiagnosticStatus.pending;
    }
  }

  Future<void> _loadRecentDiagnostics() async {
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) return;

    final result = await DiagnosticService.buscarMeuHistorico(token: token);
    if (result['success'] != true) return;

    final List data = result['data'] as List;
    final recent = data.take(3).map((item) {
      final map = item as Map<String, dynamic>;
      final dados = map['dadosParaDiagnostico'] as Map<String, dynamic>? ?? {};
      final codigo = (dados['codigoODB2'] ?? '').toString();
      final marca = (dados['marcaVeiculo'] ?? '').toString();
      final modelo = (dados['modeloVeiculo'] ?? '').toString();
      final ano = (dados['anoVeiculo'] ?? '').toString();
      final createdAt = (map['createdAt'] ?? '').toString();

      return {
        'code': codigo.isNotEmpty ? 'Código: $codigo' : 'Código: -',
        'vehicle': '$marca $modelo $ano'.trim().isEmpty
            ? 'Veículo não informado'
            : '$marca $modelo $ano'.trim(),
        'date': _formatDateShort(createdAt),
        'status': _mapStatus(map['status']),
      };
    }).toList();

    if (!mounted) return;
    setState(() {
      _totalDiagnostics = data.length.toString();
      _recentDiagnostics = recent;
    });
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
    final phone = await AuthStorage.getUserPhone();
    final memberSince = await AuthStorage.getUserMemberSince();

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
        _userPhone = phone ?? '';
        _memberSince = memberSince ?? '';
        _profilePhotoBytes = photoBytes;
        _profilePhotoUrl = photoUrl;
        _photoLoadFailed = false;
      });
    }

    await _loadRecentDiagnostics();
  }

  Widget _buildProfileAvatar({required double radius}) {
    if (_profilePhotoBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(_profilePhotoBytes!),
      );
    }
    if (!_photoLoadFailed &&
        _profilePhotoUrl != null &&
        _profilePhotoUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: NetworkAvatarImage(
            imageUrl: _profilePhotoUrl!,
            fit: BoxFit.cover,
            fallback: Container(
              color: AppColors.primaryRed,
              alignment: Alignment.center,
              child: Icon(
                Icons.person,
                size: radius * 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryRed,
      child: Icon(Icons.person, size: radius * 1.2, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/profile',
      title: 'Perfil',
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
      padding: const EdgeInsets.all(40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        _buildProfileAvatar(radius: 80),
                        const SizedBox(height: 24),
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        if (_userEmail.isNotEmpty)
                          Text(
                            _userEmail,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.edit, size: 20),
                            label: const Text('Editar Perfil'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
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
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRed,
                              side: const BorderSide(
                                color: AppColors.primaryRed,
                                width: 2,
                              ),
                            ),
                            icon: const Icon(Icons.logout, size: 20),
                            label: const Text('Sair da Conta'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informação da Conta',
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
                      child: _buildInfoCard(
                        icon: Icons.business_center,
                        label: 'Tipo de Conta',
                        value: _formatRole(_userRole),
                        valueColor: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.phone,
                        label: 'Telefone',
                        value: _userPhone.isNotEmpty
                            ? _userPhone
                            : 'Não informado',
                        valueColor: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.assessment,
                        label: 'Total Diagnóstico',
                        value: _totalDiagnostics,
                        valueColor: AppColors.primaryRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  icon: Icons.calendar_today,
                  label: 'Membro desde',
                  value: _formatMemberSince(_memberSince),
                  valueColor: AppColors.primaryRed,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Histórico Recente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/history');
                      },
                      child: const Text('Ver mais'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_recentDiagnostics.isEmpty)
                  const Text(
                    'Nenhum diagnóstico recente.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ..._recentDiagnostics.map(
                    (item) => DiagnosticItem(
                      code: item['code'] as String,
                      vehicle: item['vehicle'] as String,
                      date: item['date'] as String,
                      status: item['status'] as DiagnosticStatus,
                    ),
                  ),
                const SizedBox(height: 32),
                const Text(
                  'Configurações da Conta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  icon: Icons.notifications,
                  title: 'Notificações',
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {},
                    activeColor: AppColors.primaryRed,
                  ),
                ),
                _buildSettingItem(
                  icon: Icons.lock,
                  title: 'Alterar Senha',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _buildSettingItem(
                  icon: Icons.help,
                  title: 'Ajuda e Suporte',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _buildSettingItem(
                  icon: Icons.info,
                  title: 'Sobre o App',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProfileAvatar(radius: 50),
                const SizedBox(height: 16),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_userEmail.isNotEmpty)
                  Text(
                    _userEmail,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informação da Conta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  icon: Icons.business_center,
                  label: 'Tipo de Conta',
                  value: _formatRole(_userRole),
                  valueColor: AppColors.primaryRed,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.phone,
                  label: 'Telefone',
                  value: _userPhone.isNotEmpty ? _userPhone : 'Não informado',
                  valueColor: AppColors.primaryRed,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.assessment,
                  label: 'Total Diagnóstico',
                  value: _totalDiagnostics,
                  valueColor: AppColors.primaryRed,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.calendar_today,
                  label: 'Membro desde',
                  value: _formatMemberSince(_memberSince),
                  valueColor: AppColors.primaryRed,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Histórico Recente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/history');
                      },
                      child: const Text(
                        'Ver mais',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_recentDiagnostics.isEmpty)
                  const Text(
                    'Nenhum diagnóstico recente.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ..._recentDiagnostics.map(
                    (item) => DiagnosticItem(
                      code: item['code'] as String,
                      vehicle: item['vehicle'] as String,
                      date: item['date'] as String,
                      status: item['status'] as DiagnosticStatus,
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Configurações da Conta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  icon: Icons.notifications,
                  title: 'Notificações',
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {},
                    activeColor: AppColors.primaryRed,
                  ),
                ),
                _buildSettingItem(
                  icon: Icons.lock,
                  title: 'Alterar Senha',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _buildSettingItem(
                  icon: Icons.help,
                  title: 'Ajuda e Suporte',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _buildSettingItem(
                  icon: Icons.info,
                  title: 'Sobre o App',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      side: const BorderSide(
                        color: AppColors.primaryRed,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sair da Conta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textPrimary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
