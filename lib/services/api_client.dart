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
/// Usa isso em vez de `http.get`/`http.post` direto nos services — assim
/// a lógica de "JWT expirou → desregistra push → desconecta socket → limpa
/// sessão → vai pro login" fica num único lugar, sem precisar checar 401
/// em cada método de cada service.
///
/// Uso:
///   final response = await ApiClient.get('/conversas', token: token);
///   final response = await ApiClient.post('/dispositivos', token: token, body: {...});
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
    await _checarExpiracao(response, token);
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
    await _checarExpiracao(response, token);
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
    await _checarExpiracao(response, token);
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
    await _checarExpiracao(response, token);
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
    await _checarExpiracao(response, token);
    return response;
  }

  // ─── Internos ─────────────────────────────────────────────────────────────

  static Uri _uri(String path) {
    // suporta tanto '/conversas' quanto 'conversas' (com ou sem barra inicial)
    final clean = path.startsWith('/') ? path : '/$path';
    // ApiConfig.baseUrl vem de api_config.dart
    return Uri.parse('${_baseUrl()}$clean');
  }

  static String _baseUrl() {
    return ApiConfig.baseUrl;
  }

  static Map<String, String> _headers(
    String token,
    Map<String, String>? extra,
  ) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  static Future<void> _checarExpiracao(
    http.Response response,
    String tokenUsado,
  ) async {
    if (response.statusCode != 401) return;

    loggerService.w('JWT expirado detectado — executando logout automático');

    // lê a mensagem de erro do backend antes de limpar tudo
    String mensagem = 'Sua sessão foi encerrada. Faça login novamente.';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        mensagem = body['message'].toString();
      }
    } catch (_) {}

    try {
      await pushService.desregistrar();
    } catch (_) {}

    socketService.desconectar();
    await AuthStorage.clear();

    final context = _navigatorKey.currentContext;
    if (context != null && context.mounted) {
      // navega pro login passando a mensagem como argumento
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
        arguments: {'mensagemErro': mensagem},
      );
    }
  }
}