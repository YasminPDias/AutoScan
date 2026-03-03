import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'api_config.dart';

class DiagnosticService {
  static Future<Map<String, dynamic>> processarDiagnostico({
    required String token,
    required String codigoODB2,
    required String marcaVeiculo,
    required String modeloVeiculo,
    required int anoVeiculo,
    required String sintomas,
    required String tipoSolicitante,
    required bool urgencia,
    required String usuarioId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/diagnostico-ia/processar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'codigoODB2': codigoODB2,
        'marcaVeiculo': marcaVeiculo,
        'modeloVeiculo': modeloVeiculo,
        'anoVeiculo': anoVeiculo,
        'sintomas': sintomas,
        'tipoSolicitante': tipoSolicitante,
        'urgencia': urgencia,
        'usuarioId': usuarioId,
      }),
    );

    dev.log('DIAGNOSTICO status: ${response.statusCode}');
    dev.log('DIAGNOSTICO body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return {'success': true, 'data': data};
    } else {
      String message = 'Erro ao processar diagnóstico. (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          message = data['message'] ?? data['error'] ?? message;
        }
      } catch (_) {
        if (response.body.isNotEmpty) message = '${response.statusCode}: ${response.body}';
      }
      return {'success': false, 'message': message};
    }
  }

  static Future<Map<String, dynamic>> buscarMeuHistorico({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/diagnostico-ia/historico/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    dev.log('HISTORICO status: ${response.statusCode}');
    dev.log('HISTORICO body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return {'success': true, 'data': data};
      }
      return {'success': true, 'data': [data]};
    } else {
      String message = 'Erro ao buscar histórico. (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          message = data['message'] ?? data['error'] ?? message;
        }
      } catch (_) {
        if (response.body.isNotEmpty) message = '${response.statusCode}: ${response.body}';
      }
      return {'success': false, 'message': message};
    }
  }

  static Future<Map<String, dynamic>> atualizarDiagnostico({
    required String token,
    required String diagnosticoId,
    required String diagnostico,
    required String status,
    required String dadosParaDiagnosticoId,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/diagnostico-ia/$diagnosticoId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'diagnostico': diagnostico,
        'status': status,
        'dadosParaDiagnosticoId': dadosParaDiagnosticoId,
      }),
    );

    dev.log('ATUALIZAR DIAGNOSTICO status: ${response.statusCode}');
    dev.log('ATUALIZAR DIAGNOSTICO body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return {'success': true, 'data': data};
    } else {
      String message = 'Erro ao atualizar diagnóstico. (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          message = data['message'] ?? data['error'] ?? message;
        }
      } catch (_) {
        if (response.body.isNotEmpty) message = '${response.statusCode}: ${response.body}';
      }
      return {'success': false, 'message': message};
    }
  }
}
