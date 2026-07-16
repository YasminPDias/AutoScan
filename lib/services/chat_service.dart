import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_client.dart';
import 'logger_service.dart';
class ChatService {
  // POST /conversas — cria uma conversa ligada a um diagnóstico
  static Future<Map<String, dynamic>> criarConversa({
    required String token,
    required String aiDiagnosticoId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/conversas',
        token: token,
        body: {'aiDiagnosticoId': aiDiagnosticoId},
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
      final response = await ApiClient.get('/conversas/cliente/me', token: token);

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
      final response = await ApiClient.get('/conversas', token: token);

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
      final response = await ApiClient.get('/conversas/abertas', token: token);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data is List ? data : [data]};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas/{id} — conversa por ID
  static Future<Map<String, dynamic>> buscarConversa({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response = await ApiClient.get('/conversas/$conversaId', token: token);

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
      final response = await ApiClient.get(
        '/chat/diagnostico/$conversaId',
        token: token,
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

  // POST /chat/upload-arquivo — multipart, fica com http direto (ApiClient não cobre)
  static Future<Map<String, dynamic>> uploadArquivo({
    required String token,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/chat/upload-arquivo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes('arquivo', bytes, filename: fileName),
      );

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      loggerService.d('uploadArquivo → ${streamed.statusCode}');

      if (streamed.statusCode == 201 || streamed.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(body)};
      }
      return {'success': false, 'message': _extractError(body)};
    } catch (e) {
      loggerService.e('uploadArquivo erro: $e');
      return {'success': false, 'message': 'Erro ao enviar arquivo: $e'};
    }
  }

  // POST /chat/enviar — enviar mensagem
  static Future<Map<String, dynamic>> enviarMensagem({
    required String token,
    required String conversaId,
    String conteudo = '',
    String tipo = 'TEXTO',
    String? midiaUrl,
    String? usuarioId,
  }) async {
    try {
      final body = <String, dynamic>{
        'conversaId': conversaId,
        'conteudo': conteudo,
        'tipo': tipo,
      };
      if (midiaUrl != null) body['midiaUrl'] = midiaUrl;
      if (usuarioId != null && usuarioId.isNotEmpty) body['usuarioId'] = usuarioId;

      final response = await ApiClient.post(
        '/chat/enviar',
        token: token,
        body: body,
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
      final response = await ApiClient.patch(
        '/conversas/$conversaId',
        token: token,
        body: {'status': 'ENCERRADA'},
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

  // GET /conversas/nao-lidas — contagem real de não lidas por conversa
  static Future<Map<String, dynamic>> buscarNaoLidas({
    required String token,
  }) async {
    try {
      final response = await ApiClient.get('/conversas/nao-lidas', token: token);

      loggerService.d('buscarNaoLidas → ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data is List ? data : <dynamic>[],
        };
      }
      return {'success': false, 'data': <dynamic>[]};
    } catch (e) {
      loggerService.e('buscarNaoLidas erro: $e');
      return {'success': false, 'data': <dynamic>[]};
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