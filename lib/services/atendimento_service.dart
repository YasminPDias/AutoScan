import 'dart:convert';
import 'api_client.dart';
import 'logger_service.dart';

class AtendimentoService {
  /// GET /atendentes/online
  static Future<Map<String, dynamic>> listarAtendentesOnline({required String token}) async {
    try {
      final response = await ApiClient.get('/atendentes/online', token: token);
      loggerService.d('listarAtendentesOnline status -> ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return {'success': true, 'total': data.length, 'atendentes': data};
        } else if (data is Map<String, dynamic>) {
          final list = (data['atendentes'] ?? data['data']) as List? ?? [];
          return {'success': true, 'total': list.length, 'atendentes': list};
        }
        return {'success': true, 'total': 0, 'atendentes': []};
      }
      return {'success': false, 'total': 0, 'atendentes': []};
    } catch (e) {
      loggerService.e('listarAtendentesOnline erro: $e');
      return {'success': false, 'total': 0, 'atendentes': []};
    }
  }
}
