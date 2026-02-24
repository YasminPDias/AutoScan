import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl =
      'https://sassoficina-gfb6gwfphefacta6.canadacentral-01.azurewebsites.net';

  static Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'senha': senha}),
    );

    // dev.log('LOGIN status: ${response.statusCode}');
    // dev.log('LOGIN body: ${response.body}');

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

      return {
        'success': true,
        'token': token,
        'nome': nome,
        'sobrenome': sobrenome,
        'email': userEmail,
      };
    } else {
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
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/registrar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nome': nome,
        'sobrenome': sobrenome,
        'email': email,
        'senha': senha,
        'confirmarSenha': confirmarSenha,
      }),
    );

    dev.log('REGISTER status: ${response.statusCode}');
    dev.log('REGISTER body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'success': true};
    } else if (response.statusCode == 200) {
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
