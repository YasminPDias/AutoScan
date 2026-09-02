import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static final Map<String, dynamic> _mem = {};
  static SharedPreferences? _prefs;

  static const _keys = [
    'auth_token',
    'user_id',
    'user_name',
    'user_email',
    'user_profile_photo',
    'user_role',
    'user_phone',
    'user_member_since',
    'user_is_empresa_admin',
  ];

  /// Chama uma vez em main() antes de runApp.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    for (final key in _keys) {
      if (key == 'user_is_empresa_admin') {
        final val = _prefs!.getBool(key);
        if (val != null) _mem[key] = val;
      } else {
        final val = _prefs!.getString(key);
        if (val != null) _mem[key] = val;
      }
    }
  }

  static void _set(String key, String value) {
    _mem[key] = value;
    _prefs?.setString(key, value);
  }

  static void _setBool(String key, bool value) {
    _mem[key] = value;
    _prefs?.setBool(key, value);
  }

  static dynamic _get(String key) {
    return _mem[key] ?? _prefs?.get(key);
  }

  static void _remove(String key) {
    _mem.remove(key);
    _prefs?.remove(key);
  }

  static Future<void> saveToken(String token) async {
    _set('auth_token', token);
  }

  static Future<String?> getToken() async {
    return _get('auth_token') as String?;
  }

  static Future<void> saveUser({
    String? id,
    String? name,
    String? email,
    String? profilePhoto,
    String? role,
    String? phone,
    String? memberSince,
    bool? isEmpresaAdmin,
  }) async {
    if (id != null) _set('user_id', id);
    if (name != null) _set('user_name', name);
    if (email != null) _set('user_email', email);
    if (profilePhoto != null) _set('user_profile_photo', profilePhoto);
    if (role != null) _set('user_role', role);
    if (phone != null) _set('user_phone', phone);
    if (memberSince != null) _set('user_member_since', memberSince);
    if (isEmpresaAdmin != null) _setBool('user_is_empresa_admin', isEmpresaAdmin);
  }

  static Map<String, dynamic>? _getJwtPayload() {
    final token = _get('auth_token') as String?;
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getUserName() async => _get('user_name') as String?;
  static Future<String?> getUserEmail() async => _get('user_email') as String?;
  static Future<String?> getUserId() async {
    final payload = _getJwtPayload();
    if (payload != null && payload['sub'] != null) {
      return payload['sub'].toString();
    }
    if (payload != null && payload['id'] != null) {
      return payload['id'].toString();
    }
    return _get('user_id') as String?;
  }

  static Future<String?> getUserProfilePhoto() async => _get('user_profile_photo') as String?;

  /// Retorna o role decodificando diretamente do JWT token assinado (impede alteração manual no LocalStorage)
  static Future<String?> getUserRole() async {
    final payload = _getJwtPayload();
    if (payload != null) {
      if (payload['funcao'] != null && payload['funcao'].toString().trim().isNotEmpty) {
        return payload['funcao'].toString().trim();
      }
      if (payload['role'] != null && payload['role'].toString().trim().isNotEmpty) {
        return payload['role'].toString().trim();
      }
      if (payload['papel'] != null && payload['papel'].toString().trim().isNotEmpty) {
        return payload['papel'].toString().trim();
      }
      if (payload['perfil'] != null && payload['perfil'].toString().trim().isNotEmpty) {
        return payload['perfil'].toString().trim();
      }
    }
    final storedRole = _get('user_role') as String?;
    return storedRole?.trim();
  }

  static Future<String?> getUserPhone() async => _get('user_phone') as String?;
  static Future<String?> getUserMemberSince() async => _get('user_member_since') as String?;

  /// Retorna se é admin da empresa verificando o JWT token assinado
  static Future<bool> isEmpresaAdmin() async {
    final payload = _getJwtPayload();
    if (payload != null && payload['isEmpresaAdmin'] != null) {
      return payload['isEmpresaAdmin'] == true;
    }
    final role = await getUserRole();
    if (role != null) {
      final rUpper = role.trim().toUpperCase();
      if ( rUpper == 'EMPRESA_ADMIN' || rUpper == 'ADMIN_EMPRESA') {
        return true;
      }
    }
    return _get('user_is_empresa_admin') == true;
  }

  static Future<void> clear() async {
    for (final key in _keys) {
      _remove(key);
    }
  }

  /// Retorna true se há token salvo E ele ainda não expirou.
  static Future<bool> isLoggedIn() async {
    final token = _get('auth_token') as String?;
    if (token == null || token.isEmpty) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      final exp = payload['exp'];
      if (exp != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(
          (exp as int) * 1000,
          isUtc: true,
        );
        if (DateTime.now().toUtc().isAfter(expiry)) {
          await clear();
          return false;
        }
      }
    } catch (_) {
      // Token mal formado → trata como inválido
      await clear();
      return false;
    }

    return true;
  }
}
