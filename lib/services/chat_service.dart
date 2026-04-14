import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'logger_service.dart';

class ChatService {
  // POST /conversas — cria uma conversa ligada a um diagnóstico
  static Future<Map<String, dynamic>> criarConversa({
    required String token,
    required String aiDiagnosticoId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/conversas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'aiDiagnosticoId': aiDiagnosticoId}),
      );

      loggerService.d('criarConversa → ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('criarConversa erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas/cliente/me — conversas do cliente logado
  static Future<Map<String, dynamic>> buscarMinhasConversas({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/conversas/cliente/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data is List ? data : [data]};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas — todas as conversas (ADMIN / ASSISTENTE)
  static Future<Map<String, dynamic>> buscarTodasConversas({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/conversas'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data is List ? data : [data]};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas/abertas — conversas abertas (ADMIN)
  static Future<Map<String, dynamic>> buscarConversasAbertas({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/conversas/abertas'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data is List ? data : [data]};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas/{id} — conversa por ID (ADMIN)
  static Future<Map<String, dynamic>> buscarConversa({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/conversas/$conversaId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /chat/diagnostico/{conversaId} — mensagens da conversa
  static Future<Map<String, dynamic>> buscarMensagens({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/diagnostico/$conversaId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data is List ? data : [data]};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // POST /chat/enviar — enviar mensagem
  static Future<Map<String, dynamic>> enviarMensagem({
    required String token,
    required String conversaId,
    required String conteudo,
    String tipo = 'TEXTO',
    String? midiaUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'conversaId': conversaId,
        'conteudo': conteudo,
        'tipo': tipo,
      };
      if (midiaUrl != null) body['midiaUrl'] = midiaUrl;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat/enviar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      loggerService.d('enviarMensagem → ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('enviarMensagem erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // PATCH /conversas/{id} — encerra a conversa como resolvida
  static Future<Map<String, dynamic>> encerrarConversa({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/conversas/$conversaId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': 'ENCERRADA'}),
      );

      loggerService.d('encerrarConversa → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        final body =
            response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
        return {'success': true, 'data': body};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('encerrarConversa erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static String _extractError(String body) {
    try {
      final json = jsonDecode(body);
      return json['message']?.toString() ??
          json['error']?.toString() ??
          'Erro desconhecido';
    } catch (_) {
      return body.isNotEmpty ? body : 'Erro desconhecido';
    }
  }
}
