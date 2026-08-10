import 'dart:convert';
import 'api_client.dart';
import 'logger_service.dart';

class ConversaService {
  /// GET /conversas/nao-lidas
  static Future<int> contarNaoLidas({required String token}) async {
    try {
      final response = await ApiClient.get('/conversas/nao-lidas', token: token);
      loggerService.d('contarNaoLidas status -> ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final count = data['total'] ?? data['naoLidas'] ?? data['count'] ?? data['totalNaoLidas'] ?? 0;
          return count is int ? count : int.tryParse(count.toString()) ?? 0;
        } else if (data is int) {
          return data;
        }
      }
      return 0;
    } catch (e) {
      loggerService.e('contarNaoLidas erro: $e');
      return 0;
    }
  }
}
