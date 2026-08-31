import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_storage.dart';
import 'logger_service.dart';
import 'push_service.dart';
import 'socket_service.dart';

/// Cliente HTTP centralizado que intercepta 401 e executa logout automático.
///
/// Uso:
///   final response = await ApiClient.get('/conversas', token: token);
///   final response = await ApiClient.post('/dispositivos', token: token, body: {...});
///
/// Para requisições que não passam por estes helpers (multipart, por exemplo),
/// chame `ApiClient.tratarExpiracao(statusCode, body)` manualmente.
class ApiClient {
  static final _navigatorKey = navigatorKey; // vem do push_service.dart

  // ─── GET ──────────────────────────────────────────────────────────────────

  static Future<http.Response> get(
    String path, {
    required String token,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await http.get(
      _uri(path),
      headers: _headers(token, extraHeaders),
    );
    await tratarExpiracao(response.statusCode, response.body);
    return response;
  }

  // ─── POST ─────────────────────────────────────────────────────────────────

  static Future<http.Response> post(
    String path, {
    required String token,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await http.post(
      _uri(path),
      headers: _headers(token, extraHeaders),
      body: body != null ? jsonEncode(body) : null,
    );
    await tratarExpiracao(response.statusCode, response.body);
    return response;
  }

  // ─── PUT ──────────────────────────────────────────────────────────────────

  static Future<http.Response> put(
    String path, {
    required String token,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await http.put(
      _uri(path),
      headers: _headers(token, extraHeaders),
      body: body != null ? jsonEncode(body) : null,
    );
    await tratarExpiracao(response.statusCode, response.body);
    return response;
  }

  // ─── PATCH ────────────────────────────────────────────────────────────────

  static Future<http.Response> patch(
    String path, {
    required String token,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await http.patch(
      _uri(path),
      headers: _headers(token, extraHeaders),
      body: body != null ? jsonEncode(body) : null,
    );
    await tratarExpiracao(response.statusCode, response.body);
    return response;
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────

  static Future<http.Response> delete(
    String path, {
    required String token,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await http.delete(
      _uri(path),
      headers: _headers(token, extraHeaders),
      body: body != null ? jsonEncode(body) : null,
    );
    await tratarExpiracao(response.statusCode, response.body);
    return response;
  }

  // ─── Internos ─────────────────────────────────────────────────────────────

  static Uri uri(String path) => _uri(path);

  static Uri _uri(String path) {
    // suporta tanto '/conversas' quanto 'conversas' (com ou sem barra inicial)
    final clean = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${_baseUrl()}$clean');
  }

  static String _baseUrl() => ApiConfig.baseUrl;

  static Map<String, String> _headers(String token, Map<String, String>? extra) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  /// Publico: o upload multipart nao passa pelos helpers acima e precisa
  /// chamar isto direto. Antes de o endpoint ganhar AuthGuard, um token
  /// expirado no upload virava "Erro ao enviar imagem" sem redirect.
  static Future<void> tratarExpiracao(int statusCode, String body) async {
    if (statusCode != 401) return;

    loggerService.w('JWT expirado detectado — executando logout automático');

    String mensagem = 'Sua sessão foi encerrada. Faça login novamente.';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        mensagem = decoded['message'].toString();
      }
    } catch (_) {}

    try {
      await pushService.desregistrar();
    } catch (_) {}

    socketService.desconectar();
    await AuthStorage.clear();

    final context = _navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
        arguments: {'mensagemErro': mensagem},
      );
    }
  }
}