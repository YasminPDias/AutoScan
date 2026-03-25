import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'logger_service.dart';

class AuthService {
  static String _pickString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

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
      String id = '';
      String fotoPerfil = '';
      String funcao = '';
      String telefone = '';
      String memberSince = '';

      if (decoded is String) {
        token = decoded;
      } else if (decoded is Map<String, dynamic>) {
        token = _pickString(decoded, [
          'token',
          'access_token',
          'accessToken',
          'jwt',
        ]);

        final dynamic nested =
            decoded['usuario'] ?? decoded['user'] ?? decoded['data'];
        Map<String, dynamic> userMap = <String, dynamic>{};
        if (nested is Map<String, dynamic>) {
          userMap = nested;
        }

        nome = _pickString(userMap, ['nome', 'name', 'firstName']);
        if (nome.isEmpty) {
          nome = _pickString(decoded, ['nome', 'name', 'firstName']);
        }

        sobrenome = _pickString(userMap, ['sobrenome', 'lastName', 'surname']);
        if (sobrenome.isEmpty) {
          sobrenome = _pickString(decoded, [
            'sobrenome',
            'lastName',
            'surname',
          ]);
        }

        final mappedEmail = _pickString(userMap, ['email', 'mail']);
        userEmail = mappedEmail.isNotEmpty
            ? mappedEmail
            : _pickString(decoded, ['email', 'mail']);
        if (userEmail.isEmpty) userEmail = email;

        id = _pickString(userMap, ['id', 'usuarioId', 'userId', 'sub']);
        if (id.isEmpty) {
          id = _pickString(decoded, ['id', 'usuarioId', 'userId', 'sub']);
        }

        fotoPerfil = _pickString(userMap, [
          'fotoPerfil',
          'profilePhoto',
          'avatar',
          'picture',
        ]);
        if (fotoPerfil.isEmpty) {
          fotoPerfil = _pickString(decoded, [
            'fotoPerfil',
            'profilePhoto',
            'avatar',
            'picture',
          ]);
        }

        funcao = _pickString(userMap, ['funcao', 'role', 'perfil']);
        if (funcao.isEmpty) {
          funcao = _pickString(decoded, ['funcao', 'role', 'perfil']);
        }

        telefone = _pickString(userMap, ['telefone', 'phone', 'celular']);
        if (telefone.isEmpty) {
          telefone = _pickString(decoded, ['telefone', 'phone', 'celular']);
        }

        memberSince = _pickString(userMap, [
          'createdAt',
          'dataCriacao',
          'created_at',
          'membroDesde',
        ]);
        if (memberSince.isEmpty) {
          memberSince = _pickString(decoded, [
            'createdAt',
            'dataCriacao',
            'created_at',
            'membroDesde',
          ]);
        }
      }

      loggerService.i('Login realizado com sucesso para: $userEmail');
      return {
        'success': true,
        'token': token,
        'id': id,
        'nome': nome,
        'sobrenome': sobrenome,
        'email': userEmail,
        'fotoPerfil': fotoPerfil,
        'funcao': funcao,
        'telefone': telefone,
        'memberSince': memberSince,
      };
    } else {
      loggerService.w(
        'Falha no login para $email - Status: ${response.statusCode}',
      );
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

  static Map<String, dynamic> _normalizeUserPayload(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return {
        'id': '',
        'nome': '',
        'sobrenome': '',
        'email': '',
        'fotoPerfil': '',
        'funcao': '',
        'telefone': '',
        'memberSince': '',
      };
    }

    final nested = raw['usuario'] ?? raw['user'] ?? raw['data'];
    final userMap = nested is Map<String, dynamic>
        ? nested
        : <String, dynamic>{};

    final id =
        _pickString(userMap, ['id', 'usuarioId', 'userId', 'sub']).isNotEmpty
        ? _pickString(userMap, ['id', 'usuarioId', 'userId', 'sub'])
        : _pickString(raw, ['id', 'usuarioId', 'userId', 'sub']);

    final nome = _pickString(userMap, ['nome', 'name', 'firstName']).isNotEmpty
        ? _pickString(userMap, ['nome', 'name', 'firstName'])
        : _pickString(raw, ['nome', 'name', 'firstName']);

    final sobrenome =
        _pickString(userMap, ['sobrenome', 'lastName', 'surname']).isNotEmpty
        ? _pickString(userMap, ['sobrenome', 'lastName', 'surname'])
        : _pickString(raw, ['sobrenome', 'lastName', 'surname']);

    final email = _pickString(userMap, ['email', 'mail']).isNotEmpty
        ? _pickString(userMap, ['email', 'mail'])
        : _pickString(raw, ['email', 'mail']);

    final fotoPerfil =
        _pickString(userMap, [
          'fotoPerfil',
          'profilePhoto',
          'avatar',
          'picture',
        ]).isNotEmpty
        ? _pickString(userMap, [
            'fotoPerfil',
            'profilePhoto',
            'avatar',
            'picture',
          ])
        : _pickString(raw, ['fotoPerfil', 'profilePhoto', 'avatar', 'picture']);

    final funcao = _pickString(userMap, ['funcao', 'role', 'perfil']).isNotEmpty
        ? _pickString(userMap, ['funcao', 'role', 'perfil'])
        : _pickString(raw, ['funcao', 'role', 'perfil']);

    final telefone =
        _pickString(userMap, ['telefone', 'phone', 'celular']).isNotEmpty
        ? _pickString(userMap, ['telefone', 'phone', 'celular'])
        : _pickString(raw, ['telefone', 'phone', 'celular']);

    final memberSince =
        _pickString(userMap, [
          'createdAt',
          'dataCriacao',
          'created_at',
          'membroDesde',
        ]).isNotEmpty
        ? _pickString(userMap, [
            'createdAt',
            'dataCriacao',
            'created_at',
            'membroDesde',
          ])
        : _pickString(raw, [
            'createdAt',
            'dataCriacao',
            'created_at',
            'membroDesde',
          ]);

    return {
      'id': id,
      'nome': nome,
      'sobrenome': sobrenome,
      'email': email,
      'fotoPerfil': fotoPerfil,
      'funcao': funcao,
      'telefone': telefone,
      'memberSince': memberSince,
    };
  }

  static Future<Map<String, dynamic>> buscarPerfilCompleto({
    required String token,
    String? userId,
    String? email,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final endpoints = <String>[];
    if (userId != null && userId.trim().isNotEmpty) {
      endpoints.add('${ApiConfig.baseUrl}/usuario/${userId.trim()}');
    }
    endpoints.add('${ApiConfig.baseUrl}/usuario');

    for (final endpoint in endpoints) {
      try {
        final response = await http.get(Uri.parse(endpoint), headers: headers);
        logN.w(
          '[buscarPerfilCompleto] GET $endpoint -> ${response.statusCode} | body: ${response.body}',
        );
        if (response.statusCode != 200 && response.statusCode != 201) {
          continue;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final normalized = _normalizeUserPayload(decoded);
          logN.w(
            '[buscarPerfilCompleto] fotoPerfil normalizado (map): ${normalized['fotoPerfil']}',
          );
          if (normalized['email'].toString().isEmpty && email != null) {
            normalized['email'] = email;
          }
          return {'success': true, ...normalized};
        }

        if (decoded is List) {
          Map<String, dynamic>? matched;
          if (userId != null && userId.trim().isNotEmpty) {
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                final normalized = _normalizeUserPayload(item);
                if (normalized['id'].toString().trim() == userId.trim()) {
                  matched = normalized;
                  break;
                }
              }
            }
          }

          if (matched == null && email != null && email.trim().isNotEmpty) {
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                final normalized = _normalizeUserPayload(item);
                if (normalized['email'].toString().toLowerCase().trim() ==
                    email.toLowerCase().trim()) {
                  matched = normalized;
                  break;
                }
              }
            }
          }

          if (matched != null) {
            logN.w(
              '[buscarPerfilCompleto] fotoPerfil normalizado (list): ${matched['fotoPerfil']}',
            );
            return {'success': true, ...matched};
          }
        }
      } catch (_) {
        continue;
      }
    }

    return {'success': false};
  }

  static Future<Map<String, dynamic>> registrar({
    required String nome,
    required String sobrenome,
    required String email,
    required String senha,
    required String confirmarSenha,
    required String telefone,
    String? funcao,
    String? fotoPerfil,
    List<int>? fotoPerfilArquivoBytes,
    String? fotoPerfilArquivoNome,
  }) async {
    loggerService.d('Iniciando registro de novo usuário: $email');

    final endpoint = Uri.parse('${ApiConfig.baseUrl}/auth/registrar');
    http.Response? response;

    final hasArquivo =
        fotoPerfilArquivoBytes != null && fotoPerfilArquivoBytes.isNotEmpty;

    if (hasArquivo) {
      final request = http.MultipartRequest('POST', endpoint)
        ..fields['nome'] = nome
        ..fields['sobrenome'] = sobrenome
        ..fields['email'] = email
        ..fields['senha'] = senha
        ..fields['confirmarSenha'] = confirmarSenha
        ..fields['telefone'] = telefone;

      request.files.add(
        http.MultipartFile.fromBytes(
          'fotoPerfilArquivo',
          fotoPerfilArquivoBytes,
          filename:
              (fotoPerfilArquivoNome != null &&
                  fotoPerfilArquivoNome.trim().isNotEmpty)
              ? fotoPerfilArquivoNome.trim()
              : 'perfil.jpg',
        ),
      );

      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } else {
      final Map<String, dynamic> body = {
        'nome': nome,
        'sobrenome': sobrenome,
        'email': email,
        'senha': senha,
        'confirmarSenha': confirmarSenha,
        'telefone': telefone,
      };

      if (fotoPerfil != null && fotoPerfil.isNotEmpty) {
        body['fotoPerfil'] = 'data:image/jpeg;base64,$fotoPerfil';
      }

      response = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    }

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
        if (response.body.isNotEmpty) {
          message = '${response.statusCode}: ${response.body}';
        }
      }
      return {'success': false, 'message': message};
    }
  }
}
