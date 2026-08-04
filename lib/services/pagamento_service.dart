import 'dart:convert';
import 'api_client.dart';
import 'logger_service.dart';

class PagamentoService {
  static Future<Map<String, dynamic>> criarSetupIntent({
    required String token,
    String? empresaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/pagamentos/setup-intent',
        token: token,
        body: {
          if (empresaId != null) 'empresaId': empresaId,
        },
      );

      loggerService.d('criarSetupIntent → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('criarSetupIntent erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> assinar({
    required String token,
    required String planoId,
    required String paymentMethodId,
    String? empresaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/pagamentos/assinar',
        token: token,
        body: {
          'planoId': planoId,
          'paymentMethodId': paymentMethodId,
          if (empresaId != null) 'empresaId': empresaId,
        },
      );

      loggerService.d('assinar → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('assinar erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> cancelar({required String token}) async {
    try {
      final response = await ApiClient.delete('/pagamentos/cancelar', token: token);

      loggerService.d('cancelarAssinatura → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('cancelarAssinatura erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static String _extractError(String body) {
    try {
      final json = jsonDecode(body);
      return json['message']?.toString() ?? 'Erro desconhecido';
    } catch (_) {
      return body.isNotEmpty ? body : 'Erro desconhecido';
    }
  }
}
