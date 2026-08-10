import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'api_config.dart';
import 'logger_service.dart';

/// Serviço responsável pelo Módulo de Gestão Administrativa de Usuários (/usuario).
class UserService {
  /// GET /usuario — Buscar todos os usuários
  static Future<Map<String, dynamic>> buscarUsuarios({
    required String token,
  }) async {
    try {
      loggerService.d('UserService.buscarUsuarios — Solicitando lista de usuários');
      final response = await ApiClient.get('/usuario', token: token);

      loggerService.d('UserService.buscarUsuarios → Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data is List ? data : [data],
        };
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('UserService.buscarUsuarios erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// GET /usuario/{id} — Buscar usuário por ID (ADMIN)
  static Future<Map<String, dynamic>> buscarUsuarioPorId({
    required String token,
    required String id,
  }) async {
    try {
      loggerService.d('UserService.buscarUsuarioPorId — ID: $id');
      final response = await ApiClient.get('/usuario/$id', token: token);

      loggerService.d('UserService.buscarUsuarioPorId → Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('UserService.buscarUsuarioPorId erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// POST /usuario — Criar novo usuário via painel admin
  static Future<Map<String, dynamic>> criarUsuario({
    required String token,
    required String nome,
    required String sobrenome,
    required String email,
    required String senha,
    required String funcao, // 'ADMIN' | 'ASSISTENTE' | 'CLIENTE'
    required String telefone,
    String? fotoPerfil,
    List<int>? fotoPerfilArquivoBytes,
    String? fotoPerfilArquivoNome,
  }) async {
    try {
      loggerService.d('UserService.criarUsuario — Email: $email, Função: $funcao');

      final endpoint = Uri.parse('${ApiConfig.baseUrl}/usuario');
      final hasArquivo = fotoPerfilArquivoBytes != null && fotoPerfilArquivoBytes.isNotEmpty;

      if (hasArquivo) {
        final request = http.MultipartRequest('POST', endpoint)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['nome'] = nome
          ..fields['sobrenome'] = sobrenome
          ..fields['email'] = email
          ..fields['senha'] = senha
          ..fields['funcao'] = funcao
          ..fields['telefone'] = telefone;

        request.files.add(
          http.MultipartFile.fromBytes(
            'fotoPerfilArquivo',
            fotoPerfilArquivoBytes,
            filename: (fotoPerfilArquivoNome != null && fotoPerfilArquivoNome.trim().isNotEmpty)
                ? fotoPerfilArquivoNome.trim()
                : 'perfil.jpg',
          ),
        );

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);

        loggerService.d('UserService.criarUsuario (multipart) → Status: ${response.statusCode}');

        if (response.statusCode == 201 || response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {'success': true, 'data': data};
        }
        return {'success': false, 'message': _extractError(response.body)};
      } else {
        final Map<String, dynamic> body = {
          'nome': nome,
          'sobrenome': sobrenome,
          'email': email,
          'senha': senha,
          'funcao': funcao,
          'telefone': telefone,
        };
        if (fotoPerfil != null && fotoPerfil.isNotEmpty) {
          body['fotoPerfil'] = fotoPerfil;
        }

        final response = await ApiClient.post(
          '/usuario',
          token: token,
          body: body,
        );

        loggerService.d('UserService.criarUsuario → Status: ${response.statusCode}');

        if (response.statusCode == 201 || response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {'success': true, 'data': data};
        }
        return {'success': false, 'message': _extractError(response.body)};
      }
    } catch (e) {
      loggerService.e('UserService.criarUsuario erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// PUT /usuario/{id} — Atualizar usuário existente por ID
  static Future<Map<String, dynamic>> atualizarUsuario({
    required String token,
    required String id,
    required String nome,
    required String sobrenome,
    required String email,
    required String senha,
    required String funcao, // 'ADMIN' | 'ASSISTENTE' | 'CLIENTE'
    required String telefone,
    String? fotoPerfil,
    List<int>? fotoPerfilArquivoBytes,
    String? fotoPerfilArquivoNome,
  }) async {
    try {
      loggerService.d('UserService.atualizarUsuario — ID: $id, Email: $email');

      final endpoint = Uri.parse('${ApiConfig.baseUrl}/usuario/$id');
      final hasArquivo = fotoPerfilArquivoBytes != null && fotoPerfilArquivoBytes.isNotEmpty;

      if (hasArquivo) {
        final request = http.MultipartRequest('PUT', endpoint)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['nome'] = nome
          ..fields['sobrenome'] = sobrenome
          ..fields['email'] = email
          ..fields['senha'] = senha
          ..fields['funcao'] = funcao
          ..fields['telefone'] = telefone;

        request.files.add(
          http.MultipartFile.fromBytes(
            'fotoPerfilArquivo',
            fotoPerfilArquivoBytes,
            filename: (fotoPerfilArquivoNome != null && fotoPerfilArquivoNome.trim().isNotEmpty)
                ? fotoPerfilArquivoNome.trim()
                : 'perfil.jpg',
          ),
        );

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);

        loggerService.d('UserService.atualizarUsuario (multipart) → Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {'success': true, 'data': data};
        }
        return {'success': false, 'message': _extractError(response.body)};
      } else {
        final Map<String, dynamic> body = {
          'nome': nome,
          'sobrenome': sobrenome,
          'email': email,
          'senha': senha,
          'funcao': funcao,
          'telefone': telefone,
        };
        if (fotoPerfil != null && fotoPerfil.isNotEmpty) {
          body['fotoPerfil'] = fotoPerfil;
        }

        final response = await ApiClient.put(
          '/usuario/$id',
          token: token,
          body: body,
        );

        loggerService.d('UserService.atualizarUsuario → Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {'success': true, 'data': data};
        }
        return {'success': false, 'message': _extractError(response.body)};
      }
    } catch (e) {
      loggerService.e('UserService.atualizarUsuario erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// DELETE /usuario/{id} — Deletar/desativar usuário por ID
  static Future<Map<String, dynamic>> deletarUsuario({
    required String token,
    required String id,
  }) async {
    try {
      loggerService.d('UserService.deletarUsuario — ID: $id');
      final response = await ApiClient.delete('/usuario/$id', token: token);

      loggerService.d('UserService.deletarUsuario → Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Usuário deletado com sucesso.'};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('UserService.deletarUsuario erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// POST /usuario/{id}/ativar — Reativar usuário inativo por ID
  static Future<Map<String, dynamic>> reativarUsuario({
    required String token,
    required String id,
  }) async {
    try {
      loggerService.d('UserService.reativarUsuario — ID: $id');
      final response = await ApiClient.post('/usuario/$id/ativar', token: token);

      loggerService.d('UserService.reativarUsuario → Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Usuário ativado com sucesso.'};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('UserService.reativarUsuario erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// GET /usuario/clientes — Buscar todos os usuários com função CLIENTE (ADMIN)
  static Future<Map<String, dynamic>> buscarClientes({
    required String token,
  }) async {
    try {
      loggerService.d('UserService.buscarClientes — Solicitando lista de clientes');
      final response = await ApiClient.get('/usuario/clientes', token: token);

      loggerService.d('UserService.buscarClientes → Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data is List ? data : [data],
        };
      }
      // Fallback para filtrar buscarUsuarios caso a rota específica falhe
      final fallback = await buscarUsuarios(token: token);
      if (fallback['success'] == true) {
        final list = (fallback['data'] as List)
            .where((u) => u['funcao']?.toString().toUpperCase() == 'CLIENTE')
            .toList();
        return {'success': true, 'data': list};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('UserService.buscarClientes erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// GET /usuario/admin-assistentes — Buscar usuários ADMIN e ASSISTENTE (ADMIN)
  static Future<Map<String, dynamic>> buscarAdminAssistentes({
    required String token,
  }) async {
    try {
      loggerService.d('UserService.buscarAdminAssistentes — Solicitando lista de admins e assistentes');
      final response = await ApiClient.get('/usuario/admin-assistentes', token: token);

      loggerService.d('UserService.buscarAdminAssistentes → Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data is List ? data : [data],
        };
      }
      // Fallback para filtrar buscarUsuarios caso a rota específica falhe
      final fallback = await buscarUsuarios(token: token);
      if (fallback['success'] == true) {
        final list = (fallback['data'] as List).where((u) {
          final funcao = u['funcao']?.toString().toUpperCase() ?? '';
          return funcao == 'ADMIN' || funcao == 'ASSISTENTE';
        }).toList();
        return {'success': true, 'data': list};
      }
      return {'success': false, 'message': _extractError(response.body)};
    } catch (e) {
      loggerService.e('UserService.buscarAdminAssistentes erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
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
