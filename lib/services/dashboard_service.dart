import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'logger_service.dart';

class DashboardService {
  static Future<Map<String, dynamic>> buscarResumoDiagnosticos({
    required String token,
  }) async {
    loggerService.d('Buscando resumo de diagnósticos para o dashboard');

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dashboard/diagnosticos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      loggerService.d('Resposta resumo dashboard - Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': 'Status: ${response.statusCode}'};
    } catch (e) {
      loggerService.e('Erro ao buscar resumo do dashboard: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> buscarHistoricoSemanal({
    required String token,
  }) async {
    loggerService.d('Buscando histórico semanal para o dashboard');

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dashboard/diagnosticos/historico'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      loggerService.d('Resposta histórico semanal - Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': 'Status: ${response.statusCode}'};
    } catch (e) {
      loggerService.e('Erro ao buscar histórico semanal do dashboard: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
