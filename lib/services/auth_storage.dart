import 'package:flutter/foundation.dart';

class AuthStorage {
  static final Map<String, String> _mem = {};

  static void _set(String key, String value) {
    _mem[key] = value;
    if (kIsWeb) _webSet(key, value);
  }

  static String? _get(String key) {
    if (_mem.containsKey(key)) return _mem[key];
    if (kIsWeb) {
      final v = _webGet(key);
      if (v != null) _mem[key] = v;
      return v;
    }
    return null;
  }

  static void _remove(String key) {
    _mem.remove(key);
    if (kIsWeb) _webRemove(key);
  }

  static void _webSet(String key, String value) {
    try {
      final storage = _getLocalStorage();
      if (storage != null) {
        (storage as dynamic)[key] = value;
      }
    } catch (_) {}
  }

  static String? _webGet(String key) {
    try {
      final storage = _getLocalStorage();
      if (storage != null) {
        return (storage as dynamic)[key] as String?;
      }
    } catch (_) {}
    return null;
  }

  static void _webRemove(String key) {
    try {
      final storage = _getLocalStorage();
      if (storage != null) {
        (storage as dynamic).removeItem(key);
      }
    } catch (_) {}
  }

  static dynamic _getLocalStorage() {
    try {
      return (Uri.base.toString().isNotEmpty)
          ? _jsLocalStorage()
          : null;
    } catch (_) {
      return null;
    }
  }

  static dynamic _jsLocalStorage() {
    try {
      return _LocalStorage._instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    _set('auth_token', token);
  }

  static Future<String?> getToken() async {
    return _get('auth_token');
  }

  static Future<void> saveUser({String? id, String? name, String? email}) async {
    if (id != null) _set('user_id', id);
    if (name != null) _set('user_name', name);
    if (email != null) _set('user_email', email);
  }

  static Future<String?> getUserName() async {
    return _get('user_name');
  }

  static Future<String?> getUserEmail() async {
    return _get('user_email');
  }

  static Future<void> clear() async {
    _remove('auth_token');
    _remove('user_id');
    _remove('user_name');
    _remove('user_email');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

class _LocalStorage {
  static dynamic get _instance {
    try {
      return _getWindow();
    } catch (_) {
      return null;
    }
  }

  static dynamic _getWindow() {
    return null;
  }
}
