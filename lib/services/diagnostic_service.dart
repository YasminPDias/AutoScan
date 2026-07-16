import 'dart:convert';
import 'api_client.dart';
import 'logger_service.dart';

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
    loggerService.d(
      'Iniciando diagnóstico para: $marcaVeiculo $modeloVeiculo ($anoVeiculo) '
      '- Código ODB2: $codigoODB2',
    );

    final response = await ApiClient.post(
      '/diagnostico-ia/processar',
      token: token,
      body: {
        'codigoODB2': codigoODB2,
        'marcaVeiculo': marcaVeiculo,
        'modeloVeiculo': modeloVeiculo,
        'anoVeiculo': anoVeiculo,
        'sintomas': sintomas,
        'tipoSolicitante': tipoSolicitante,
        'urgencia': urgencia,
        'usuarioId': usuarioId,
      },
    );

    loggerService.d('Resposta de diagnóstico - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      loggerService.i('Diagnóstico processado com sucesso');
      return {'success': true, 'data': data};
    } else {
      loggerService.w(
        'Falha ao processar diagnóstico - Status: ${response.statusCode}',
      );
      String message =
          'Erro ao processar diagnóstico. (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          message = data['message'] ?? data['error'] ?? message;
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          message = '${response.statusCode}: ${response.body}';
        }
      }
      return {'success': false, 'message': message};
    }
  }

  // GET /diagnostico-ia/historico — todos os diagnósticos (ADMIN/ASSISTENTE)
  static Future<Map<String, dynamic>> buscarTodoHistorico({
    required String token,
  }) async {
    loggerService.d('Buscando todo o histórico de diagnósticos (admin)');

    final response = await ApiClient.get(
      '/diagnostico-ia/historico',
      token: token,
    );

    loggerService.d('Resposta todo histórico - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is List) return {'success': true, 'data': data};
      return {'success': true, 'data': [data]};
    }
    return {'success': false, 'message': 'Status: ${response.statusCode}'};
  }

  static Future<Map<String, dynamic>> buscarMeuHistorico({
    required String token,
  }) async {
    loggerService.d('Buscando histórico de diagnósticos');

    final response = await ApiClient.get(
      '/diagnostico-ia/historico/me',
      token: token,
    );

    loggerService.d('Resposta de histórico - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      loggerService.i('Histórico de diagnósticos carregado com sucesso');
      if (data is List) return {'success': true, 'data': data};
      return {'success': true, 'data': [data]};
    } else {
      loggerService.w(
        'Falha ao buscar histórico - Status: ${response.statusCode}',
      );
      String message = 'Erro ao buscar histórico. (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          message = data['message'] ?? data['error'] ?? message;
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          message = '${response.statusCode}: ${response.body}';
        }
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
    loggerService.d('Atualizando diagnóstico: $diagnosticoId');

    final response = await ApiClient.put(
      '/diagnostico-ia/$diagnosticoId',
      token: token,
      body: {
        'diagnostico': diagnostico,
        'status': status,
        'dadosParaDiagnosticoId': dadosParaDiagnosticoId,
      },
    );

    loggerService.d('Resposta de atualização - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return {'success': true, 'data': data};
    } else {
      String message =
          'Erro ao atualizar diagnóstico. (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          message = data['message'] ?? data['error'] ?? message;
        }
      } catch (_) {
        if (response.body.isNotEmpty) {
          message = '${response.statusCode}: ${response.body}';
        }
      }
      return {'success': false, 'message': message};
    }
  }
}