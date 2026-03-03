import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'logger_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    loggerService.d('Iniciando login para email: $email');
    
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'senha': senha}),
    );

    loggerService.d('Resposta de login - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body.trim();
      }

      String token = '';
      String nome = '';
      String sobrenome = '';
      String userEmail = email;

      if (decoded is String) {
        token = decoded;
      } else if (decoded is Map<String, dynamic>) {
        token = decoded['token'] ??
            decoded['access_token'] ??
            decoded['accessToken'] ??
            decoded['jwt'] ??
            '';
        nome = decoded['nome'] ?? decoded['name'] ?? '';
        sobrenome = decoded['sobrenome'] ?? decoded['lastName'] ?? decoded['surname'] ?? '';
        userEmail = decoded['email'] ?? email;
      }

      loggerService.i('Login realizado com sucesso para: $userEmail');
      return {
        'success': true,
        'token': token,
        'nome': nome,
        'sobrenome': sobrenome,
        'email': userEmail,
      };
    } else {
      loggerService.w('Falha no login para $email - Status: ${response.statusCode}');
      String message = 'Credenciais inválidas.';
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          message = data['message'] ?? data['error'] ?? message;
        }
      } catch (_) {
        if (response.body.isNotEmpty) message = response.body;
      }
      return {'success': false, 'message': message};
    }
  }

  static Future<Map<String, dynamic>> registrar({
    required String nome,
    required String sobrenome,
    required String email,
    required String senha,
    required String confirmarSenha,
  }) async {
    loggerService.d('Iniciando registro de novo usuário: $email');
    
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/registrar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nome': nome,
        'sobrenome': sobrenome,
        'email': email,
        'senha': senha,
        'confirmarSenha': confirmarSenha,
      }),
    );

    loggerService.d('Resposta de registro - Status: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'success': true};
    } else {
      String message = 'Erro ao criar conta. (${response.statusCode})';
      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          message = data['message'] ?? data['error'] ?? message;
        } else if (data is String) {
          message = data;
        }
      } catch (_) {
        if (response.body.isNotEmpty) message = '${response.statusCode}: ${response.body}';
      }
      return {'success': false, 'message': message};
    }
  }
}
