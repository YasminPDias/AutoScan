import 'dart:convert';
import '../api_client.dart';
import '../logger_service.dart';

class EmpresaService {
  static Future<Map<String, dynamic>> criar({
    required String token,
    required String razaoSocial,
    String? nomeFantasia,
    required String cnpj,
    required String emailContato,
    String? telefone,
    required String cidade,
    required String estado,
  }) async {
    try {
      final response = await ApiClient.post(
        '/empresa',
        token: token,
        body: {
          'razaoSocial': razaoSocial,
          if (nomeFantasia != null && nomeFantasia.isNotEmpty)
            'nomeFantasia': nomeFantasia,
          'cnpj': cnpj,
          'emailContato': emailContato,
          if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
          'cidade': cidade,
          'estado': estado,
        },
      );

      loggerService.d('criarEmpresa → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {
        'success': false,
        'message': _extractError(response.body),
      };
    } catch (e) {
      loggerService.e('criarEmpresa erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // endpoint temporário de teste — remove quando Stripe estiver integrado
  static Future<Map<String, dynamic>> ativarTeste({
    required String token,
    required String empresaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/empresa/$empresaId/ativar-teste',
        token: token,
      );

      loggerService.d('ativarTeste → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('ativarTeste erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> buscarMinhaEmpresa({
    required String token,
  }) async {
    try {
      final response = await ApiClient.get('/empresa/minha', token: token);

      loggerService.d('buscarMinhaEmpresa → ${response.statusCode}');

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      if (response.statusCode == 404) {
        return {'success': false, 'semEmpresa': true};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('buscarMinhaEmpresa erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// GET /empresa — [ADMIN] Lista todas as empresas cadastradas no sistema
  static Future<Map<String, dynamic>> listarTodas({
    required String token,
  }) async {
    try {
      final response = await ApiClient.get('/empresa', token: token);

      loggerService.d('listarTodasEmpresas → ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data is List ? data : [data]};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('listarTodasEmpresas erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> listarMembros({
    required String token,
    required String empresaId,
  }) async {
    try {
      final response = await ApiClient.get(
        '/empresa/$empresaId/membros',
        token: token,
      );

      loggerService.d('listarMembros → ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data is List ? data : []};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('listarMembros erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> adicionarFuncionario({
    required String token,
    required String empresaId,
    required String nome,
    required String sobrenome,
    required String email,
    required String telefone,
    required String senha,
    required String papel,
  }) async {
    try {
      final response = await ApiClient.post(
        '/empresa/$empresaId/funcionarios',
        token: token,
        body: {
          'nome': nome,
          'sobrenome': sobrenome,
          'email': email,
          'telefone': telefone,
          'senha': senha,
          'papel': papel,
        },
      );

      loggerService.d('adicionarFuncionario → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('adicionarFuncionario erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<bool> removerFuncionario({
    required String token,
    required String empresaId,
    required String funcionarioId,
  }) async {
    try {
      final response = await ApiClient.delete(
        '/empresa/$empresaId/funcionarios/$funcionarioId',
        token: token,
      );
      return response.statusCode == 200;
    } catch (e) {
      loggerService.e('removerFuncionario erro: $e');
      return false;
    }
  }

  /// PATCH /empresa/{empresaId}/funcionarios/{funcionarioId}/papel
  static Future<Map<String, dynamic>> alterarPapelFuncionario({
    required String token,
    required String empresaId,
    required String funcionarioId,
    required String novoPapel,
  }) async {
    try {
      final response = await ApiClient.patch(
        '/empresa/$empresaId/funcionarios/$funcionarioId/papel',
        token: token,
        body: {'papel': novoPapel},
      );

      loggerService.d('alterarPapelFuncionario → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('alterarPapelFuncionario erro: $e');
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