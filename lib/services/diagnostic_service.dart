import 'dart:convert';
import 'api_client.dart';
import 'logger_service.dart';

class DiagnosticService {
  /// POST /diagnostico-ia/processar — Salvar dados e processar diagnóstico com IA
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

  /// POST /diagnostico-ia — Criar novo diagnóstico sem passar pelo fluxo de IA (AIDiagnosticoCriacaoDTO)
  static Future<Map<String, dynamic>> criarDiagnosticoManual({
    required String token,
    required String diagnostico,
    required String status, // PENDENTE, EM_ANALISE, CONCLUIDO, INCONCLUSIVO
    required String dadosParaDiagnosticoId,
  }) async {
    loggerService.d('Criando diagnóstico manual');

    final response = await ApiClient.post(
      '/diagnostico-ia',
      token: token,
      body: {
        'diagnostico': diagnostico,
        'status': status,
        'dadosParaDiagnosticoId': dadosParaDiagnosticoId,
      },
    );

    loggerService.d('Resposta criar diagnóstico - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return {'success': true, 'data': data};
    }
    return {'success': false, 'message': _extractError(response.body)};
  }

  /// GET /diagnostico-ia — todos os diagnósticos (ADMIN/ASSISTENTE)
  static Future<Map<String, dynamic>> buscarTodoHistorico({
    required String token,
  }) async {
    loggerService.d('Buscando todo o histórico de diagnósticos (admin)');

    // Tenta primeiro /diagnostico-ia (conforme Swagger) e depois /diagnostico-ia/historico como fallback
    var response = await ApiClient.get('/diagnostico-ia', token: token);
    if (response.statusCode != 200 && response.statusCode != 201) {
      response = await ApiClient.get('/diagnostico-ia/historico', token: token);
    }

    loggerService.d('Resposta todo histórico - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is List) return {'success': true, 'data': data};
      return {'success': true, 'data': [data]};
    }
    return {'success': false, 'message': 'Status: ${response.statusCode}'};
  }

  /// GET /diagnostico-ia/historico/me — histórico do usuário autenticado
  static Future<Map<String, dynamic>> buscarMeuHistorico({
    required String token,
  }) async {
    loggerService.d('Buscando histórico de diagnósticos do usuário');

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
      return {'success': false, 'message': _extractError(response.body)};
    }
  }

  /// GET /diagnostico-ia/historico/usuario/{usuarioId} — buscar histórico de um usuário específico (ADMIN)
  static Future<Map<String, dynamic>> buscarHistoricoPorUsuario({
    required String token,
    required String usuarioId,
  }) async {
    loggerService.d('Buscando histórico para usuário: $usuarioId');

    final response = await ApiClient.get(
      '/diagnostico-ia/historico/usuario/$usuarioId',
      token: token,
    );

    loggerService.d('Resposta histórico por usuário - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is List) return {'success': true, 'data': data};
      return {'success': true, 'data': [data]};
    }
    return {'success': false, 'message': _extractError(response.body)};
  }

  /// GET /diagnostico-ia/abertos/me — Buscar diagnósticos em aberto (PENDENTE ou EM_ANALISE) do usuário logado
  static Future<Map<String, dynamic>> buscarMeusDiagnosticosAbertos({
    required String token,
  }) async {
    loggerService.d('Buscando diagnósticos em aberto do usuário');

    final response = await ApiClient.get(
      '/diagnostico-ia/abertos/me',
      token: token,
    );

    loggerService.d('Resposta diagnósticos em aberto - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is List) return {'success': true, 'data': data};
      return {'success': true, 'data': [data]};
    }
    return {'success': false, 'message': _extractError(response.body)};
  }

  /// GET /diagnostico-ia/{id} — Buscar diagnóstico por ID
  static Future<Map<String, dynamic>> buscarDiagnosticoPorId({
    required String token,
    required String diagnosticoId,
  }) async {
    loggerService.d('Buscando diagnóstico por ID: $diagnosticoId');

    final response = await ApiClient.get(
      '/diagnostico-ia/$diagnosticoId',
      token: token,
    );

    loggerService.d('Resposta buscar por ID - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return {'success': true, 'data': data};
    }
    return {'success': false, 'message': _extractError(response.body)};
  }

  /// PUT /diagnostico-ia/{id} — Atualizar diagnóstico existente
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
      return {'success': false, 'message': _extractError(response.body)};
    }
  }

  /// DELETE /diagnostico-ia/{id} — Deletar diagnóstico por ID
  static Future<Map<String, dynamic>> deletarDiagnostico({
    required String token,
    required String diagnosticoId,
  }) async {
    loggerService.d('Deletando diagnóstico: $diagnosticoId');

    final response = await ApiClient.delete(
      '/diagnostico-ia/$diagnosticoId',
      token: token,
    );

    loggerService.d('Resposta deletar diagnóstico - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      return {'success': true, 'message': 'Diagnóstico deletado com sucesso.'};
    }
    return {'success': false, 'message': _extractError(response.body)};
  }

  static String _extractError(String body) {
    try {
      final json = jsonDecode(body);
      return json['message']?.toString() ?? json['error']?.toString() ?? 'Erro desconhecido';
    } catch (_) {
      return body.isNotEmpty ? body : 'Erro desconhecido';
    }
  }
}