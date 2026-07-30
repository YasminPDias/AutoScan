import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_client.dart';
import 'logger_service.dart';
import '../models/conversa_model.dart';

class ChatService {
  static Future<Map<String, dynamic>> criarConversa({
    required String token,
    required String aiDiagnosticoId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/conversas', token: token,
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

  // GET /conversas/atendente/me
  static Future<Map<String, dynamic>> buscarMinhasConversas({
    required String token,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    try {
      final response = await ApiClient.get(
        '/conversas/atendente/me?pagina=$pagina&porPagina=$porPagina',
        token: token,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return {'success': true, 'data': data, 'pagina': 1, 'totalPaginas': 1};
        }
        // resposta paginada { dados: [...], total, pagina, totalPaginas }
        final lista = (data['dados'] as List? ?? [])
            .map((j) => ConversaModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': lista,
          'pagina': data['pagina'] ?? pagina,
          'totalPaginas': data['totalPaginas'] ?? 1,
        };
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('buscarMinhasConversas erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas
  static Future<Map<String, dynamic>> buscarTodasConversas({
    required String token,
  }) async {
    try {
      final response = await ApiClient.get('/conversas', token: token);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = data is List ? data : (data['dados'] as List? ?? []);
        return {'success': true, 'data': lista};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('buscarTodasConversas erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas/abertas
  static Future<Map<String, dynamic>> buscarConversasAbertas({
    required String token,
  }) async {
    try {
      final response = await ApiClient.get('/conversas/abertas', token: token);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = data is List ? data : (data['dados'] as List? ?? []);
        return {'success': true, 'data': lista};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('buscarConversasAbertas erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas/{id}
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
      loggerService.e('buscarConversa erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas/diagnostico/:id
  static Future<Map<String, dynamic>> buscarConversaPorDiagnosticoId({
    required String token,
    required String diagnosticoId,
  }) async {
    try {
      final response = await ApiClient.get(
        '/conversas/diagnostico/$diagnosticoId', token: token,
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('buscarConversaPorDiagnosticoId erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /chat/diagnostico/{conversaId}
  static Future<Map<String, dynamic>> buscarMensagens({
    required String token,
    required String conversaId,
    int pagina = 1,
    int porPagina = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/chat/diagnostico/$conversaId?pagina=$pagina&porPagina=$porPagina',
        token: token,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // retorna o objeto paginado inteiro — o caller decide o que fazer
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('buscarMensagens erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // POST /chat/upload-arquivo
  static Future<Map<String, dynamic>> uploadArquivo({
    required String token,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST', Uri.parse('${ApiConfig.baseUrl}/chat/upload-arquivo'),
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

  // POST /chat/enviar
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

      final response = await ApiClient.post('/chat/enviar', token: token, body: body);
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

  // POST /conversas/{id}/encerrar
  static Future<Map<String, dynamic>> encerrarConversa({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/conversas/$conversaId/encerrar', token: token,
      );
      loggerService.d('encerrarConversa → ${response.statusCode}');
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return {'success': true};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('encerrarConversa erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // GET /conversas/nao-lidas
  static Future<Map<String, dynamic>> buscarNaoLidas({
    required String token,
  }) async {
    try {
      final response = await ApiClient.get('/conversas/nao-lidas', token: token);
      loggerService.d('buscarNaoLidas → ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data is List ? data : <dynamic>[]};
      }
      return {'success': false, 'data': <dynamic>[]};
    } catch (e) {
      loggerService.e('buscarNaoLidas erro: $e');
      return {'success': false, 'data': <dynamic>[]};
    }
  }

  // GET /conversas/disponiveis
  static Future<Map<String, dynamic>> buscarConversasDisponiveis({
    required String token,
    int pagina = 1,
    int porPagina = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/conversas/disponiveis?pagina=$pagina&porPagina=$porPagina',
        token: token,
      );
      loggerService.d('buscarConversasDisponiveis → ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = data is List ? data : (data['dados'] as List? ?? []);
        return {'success': true, 'data': lista};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('buscarConversasDisponiveis erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // POST /conversas/{id}/reivindicar
  static Future<Map<String, dynamic>> reivindicarConversa({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/conversas/$conversaId/reivindicar', token: token,
      );
      loggerService.d('reivindicarConversa → ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('reivindicarConversa erro: $e');
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