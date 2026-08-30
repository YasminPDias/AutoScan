import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_client.dart';
import 'logger_service.dart';
import '../models/conversa_model.dart';

class ChatService {
  /// Mensagem genérica na UI. A exception crua vaza URL assinada, host interno
  /// e stack — vai só para o logger.
  static const _erroConexao = 'Falha de conexão. Verifique sua internet.';
  static const _semAcesso = 'Você não tem acesso a esta conversa.';

  // ─── conversas ─────────────────────────────────────────────────────────────

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
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('criarConversa erro: $e');
      return {'success': false, 'message': _erroConexao};
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
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('buscarMinhasConversas erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

  /// GET /conversas
  ///
  /// ATENÇÃO: passou a exigir ADMIN ou ASSISTENTE. Uma tela de CLIENTE que
  /// chame isto recebe 403 — use `buscarMinhasConversas`.
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
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('buscarTodasConversas erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

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
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('buscarConversasAbertas erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

  static Future<Map<String, dynamic>> buscarConversa({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response =
          await ApiClient.get('/conversas/$conversaId', token: token);
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('buscarConversa erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

  static Future<Map<String, dynamic>> buscarConversaPorDiagnosticoId({
    required String token,
    required String diagnosticoId,
  }) async {
    try {
      final response = await ApiClient.get(
        '/conversas/diagnostico/$diagnosticoId',
        token: token,
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('buscarConversaPorDiagnosticoId erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

  static Future<Map<String, dynamic>> encerrarConversa({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/conversas/$conversaId/encerrar',
        token: token,
      );
      loggerService.d('encerrarConversa → ${response.statusCode}');
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return {'success': true};
      }
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('encerrarConversa erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

  static Future<Map<String, dynamic>> buscarNaoLidas({
    required String token,
  }) async {
    try {
      final response = await ApiClient.get('/conversas/nao-lidas', token: token);
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

  static Future<Map<String, dynamic>> buscarConversasDisponiveis({
    required String token,
    String tipo = 'DIAGNOSTICO',
    int pagina = 1,
    int porPagina = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/conversas/disponiveis?tipo=$tipo&pagina=$pagina&porPagina=$porPagina',
        token: token,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = data is List ? data : (data['dados'] as List? ?? []);
        return {'success': true, 'data': lista};
      }
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('buscarConversasDisponiveis erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

  static Future<Map<String, dynamic>> reivindicarConversa({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/conversas/$conversaId/reivindicar',
        token: token,
      );
      loggerService.d('reivindicarConversa → ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('reivindicarConversa erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

  // ─── mensagens ─────────────────────────────────────────────────────────────

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
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('buscarMensagens erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

  /// POST /chat/enviar
  ///
  /// `usuarioId` não existe mais no corpo — o backend usa o id do token.
  /// `clientMessageId` torna o retry idempotente: reenviar com o mesmo id
  /// devolve a mensagem já criada em vez de duplicar.
  static Future<Map<String, dynamic>> enviarMensagem({
    required String token,
    required String conversaId,
    String conteudo = '',
    String tipo = 'TEXTO',
    String? midiaRef,
    String? clientMessageId,
  }) async {
    try {
      final body = <String, dynamic>{
        'conversaId': conversaId,
        'conteudo': conteudo,
        'tipo': tipo,
        // O campo do DTO ainda se chama midiaUrl, mas o valor é a referência.
        if (midiaRef != null) 'midiaUrl': midiaRef,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
      };

      final response =
          await ApiClient.post('/chat/enviar', token: token, body: body);
      loggerService.d('enviarMensagem → ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return _falha(response.statusCode, response.body);
    } catch (e) {
      loggerService.e('enviarMensagem erro: $e');
      return {'success': false, 'message': _erroConexao};
    }
  }

  /// POST /chat/mensagem-midia
  ///
  /// Upload e criação da mensagem em UMA requisição. Substitui o par
  /// `uploadArquivo` + `enviarMensagem`, que deixava blob órfão quando o
  /// segundo passo falhava e permitia ao cliente escolher qualquer string
  /// como referência de mídia.
  ///
  /// Devolve a mensagem já criada, com `midiaUrl` assinada.
  static Future<Map<String, dynamic>> enviarMidia({
    required String token,
    required String conversaId,
    required String tipo, // IMAGEM | AUDIO | DOCUMENTO
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String? clientMessageId,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        ApiClient.uri('/chat/mensagem-midia'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['conversaId'] = conversaId;
      request.fields['tipo'] = tipo;
      if (clientMessageId != null) {
        request.fields['clientMessageId'] = clientMessageId;
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'arquivo',
          bytes,
          filename: fileName,
          // Informativo: o backend detecta o tipo por assinatura binária.
          contentType: MediaType.parse(contentType),
        ),
      );

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      loggerService.d('enviarMidia → ${streamed.statusCode}');

      await ApiClient.tratarExpiracao(streamed.statusCode, body);

      if (streamed.statusCode == 201 || streamed.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(body)};
      }
      return _falha(streamed.statusCode, body);
    } catch (e) {
      loggerService.e('enviarMidia erro: $e');
      return {'success': false, 'message': 'Falha ao enviar o arquivo.'};
    }
  }

  /// POST /chat/midias/urls
  ///
  /// Renova URLs assinadas de mídias já conhecidas. O SAS expira em 10 min
  /// (imagem/documento) e 30 min (áudio); a URL fica congelada na memória do
  /// app enquanto a tela estiver aberta.
  ///
  /// O backend só devolve referências de conversas em que o usuário participa —
  /// uma referência sem acesso simplesmente não aparece no resultado.
  static Future<Map<String, String>> resolverUrlsMidia({
    required String token,
    required List<String> referencias,
  }) async {
    if (referencias.isEmpty) return const {};

    try {
      final response = await ApiClient.post(
        '/chat/midias/urls',
        token: token,
        body: {'referencias': referencias},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        loggerService.w('resolverUrlsMidia → ${response.statusCode}');
        return const {};
      }

      final lista = jsonDecode(response.body) as List;
      return {
        for (final item in lista)
          (item as Map<String, dynamic>)['referencia'].toString():
              item['url'].toString(),
      };
    } catch (e) {
      loggerService.e('resolverUrlsMidia erro: $e');
      return const {};
    }
  }

  /// @deprecated Use [enviarMidia].
  ///
  /// Mantido enquanto outras telas ainda dependem do upload isolado.
  static Future<Map<String, dynamic>> uploadArquivo({
    required String token,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        ApiClient.uri('/chat/upload-arquivo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'arquivo',
          bytes,
          filename: fileName,
          contentType:
              contentType != null ? MediaType.parse(contentType) : null,
        ),
      );

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      await ApiClient.tratarExpiracao(streamed.statusCode, body);

      if (streamed.statusCode == 201 || streamed.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final referencia =
            data['referencia']?.toString() ?? data['url']?.toString();
        return {'success': true, 'referencia': referencia, 'data': data};
      }
      return _falha(streamed.statusCode, body);
    } catch (e) {
      loggerService.e('uploadArquivo erro: $e');
      return {'success': false, 'message': 'Falha ao enviar o arquivo.'};
    }
  }

  // ─── internos ──────────────────────────────────────────────────────────────

  /// 403 agora acontece de verdade: `assertParticipante` no backend.
  /// Distinguir de erro de rede evita o usuário ficar tentando de novo.
  static Map<String, dynamic> _falha(int statusCode, String body) {
    if (statusCode == 403) {
      return {'success': false, 'statusCode': 403, 'message': _semAcesso};
    }
    return {
      'success': false,
      'statusCode': statusCode,
      'message': _extractError(body),
    };
  }

  static String _extractError(String body) {
    try {
      final json = jsonDecode(body);
      return json['message']?.toString() ??
          json['error']?.toString() ??
          'Não foi possível completar a operação.';
    } catch (_) {
      return 'Não foi possível completar a operação.';
    }
  }
}