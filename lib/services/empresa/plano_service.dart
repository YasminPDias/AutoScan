import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/plano_model.dart';
import '../api_config.dart';
import '../logger_service.dart';

class PlanoService {
  // público — não precisa de token
  static Future<Map<String, dynamic>> listarTodos() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/planos'),
        headers: {'Content-Type': 'application/json'},
      );

      loggerService.d('listarPlanos → ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = (data as List)
            .map((j) => PlanoModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return {'success': true, 'data': lista};
      }
      return {'success': false, 'message': 'Erro ao carregar planos'};
    } catch (e) {
      loggerService.e('listarPlanos erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}