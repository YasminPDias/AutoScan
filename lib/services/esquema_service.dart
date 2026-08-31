import 'dart:convert';
import 'api_client.dart';
import 'logger_service.dart';

class EsquemaService {
  /// POST /solicitacoes-esquema — Solicitar esquema elétrico
  static Future<Map<String, dynamic>> criarSolicitacao({
    required String token,
    required String marca,
    required String modelo,
    required int anoModelo,
    String? motor,
    String? injecao,
    String? observacao,
  }) async {
    loggerService.d(
      'Iniciando solicitação de esquema elétrico para: $marca $modelo ($anoModelo)',
    );

    try {
      final response = await ApiClient.post(
        '/solicitacoes-esquema',
        token: token,
        body: {
          'marca': marca,
          'modelo': modelo,
          'anoModelo': anoModelo,
          if (motor != null && motor.isNotEmpty) 'motor': motor,
          if (injecao != null && injecao.isNotEmpty) 'injecao': injecao,
          if (observacao != null && observacao.isNotEmpty) 'observacao': observacao,
        },
      );

      loggerService.d('Resposta criarSolicitacao - Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'conversaId': data['conversaId']};
      } else {
        return {
          'success': false,
          'message': _extractError(response.body, response.statusCode),
        };
      }
    } catch (e) {
      loggerService.e('criarSolicitacao erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// GET /solicitacoes-esquema/minhas — Listar minhas solicitações de esquema
  static Future<Map<String, dynamic>> listarMinhas({
    required String token,
    int pagina = 1,
    int porPagina = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/solicitacoes-esquema/minhas?pagina=$pagina&porPagina=$porPagina',
        token: token,
      );

      loggerService.d('Resposta listarMinhas - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['dados'] as List? ?? []);
        return {
          'success': true,
          'data': list,
          'pagina': data is Map ? (data['pagina'] ?? pagina) : pagina,
          'totalPaginas': data is Map ? (data['totalPaginas'] ?? 1) : 1,
        };
      } else {
        return {
          'success': false,
          'message': _extractError(response.body, response.statusCode),
        };
      }
    } catch (e) {
      loggerService.e('listarMinhas erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// GET /solicitacoes-esquema/{conversaId} — Detalhe da solicitação
  static Future<Map<String, dynamic>> obterDetalhe({
    required String token,
    required String conversaId,
  }) async {
    try {
      final response = await ApiClient.get(
        '/solicitacoes-esquema/$conversaId',
        token: token,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'statusCode': response.statusCode};
    } catch (e) {
      loggerService.e('obterDetalhe erro: $e');
      return {'success': false};
    }
  }

  static String _extractError(String body, int statusCode) {
    try {
      final json = jsonDecode(body);
      return json['message']?.toString() ??
          json['error']?.toString() ??
          'Erro ao processar requisição ($statusCode).';
    } catch (_) {
      return body.isNotEmpty ? body : 'Erro ao processar requisição ($statusCode).';
    }
  }
}
