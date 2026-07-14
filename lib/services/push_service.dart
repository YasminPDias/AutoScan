import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_storage.dart';
import 'chat_read_tracker.dart';
import 'logger_service.dart';

/// Usado tanto pro MaterialApp (navigatorKey:) quanto pro deep-link ao tocar
/// numa notificação — mora aqui porque só é usado por causa do push.
final navigatorKey = GlobalKey<NavigatorState>();

/// Pra mostrar SnackBar de fora de qualquer tela específica (ex: push
/// chegando em foreground enquanto o usuário está em outra tela).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// precisa estar fora de qualquer classe: roda em isolate separado
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // apenas garante que o app "acorde" pra entregar o push; navegação real
  // acontece em onMessageOpenedApp / getInitialMessage quando o usuário toca
}

class PushService {
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  PushService._internal();

  String? _tokenAtual;

  Future<void> inicializar() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      loggerService.w('Permissão de notificação não concedida: $e');
      // segue sem push — isso nunca deve travar login ou qualquer outro fluxo
    }

    try {
      final token = kIsWeb
          ? await FirebaseMessaging.instance.getToken(vapidKey: ApiConfig.vapidKey)
          : await FirebaseMessaging.instance.getToken();
      _tokenAtual = token;
      if (token != null) await _registrarTokenNoBackend(token);
      FirebaseMessaging.instance.onTokenRefresh.listen((novoToken) {
        _tokenAtual = novoToken;
        _registrarTokenNoBackend(novoToken);
      });
    } catch (e) {
      loggerService.w('Não foi possível obter/registrar o token FCM: $e');
    }

    // app em foreground: o socket só atualiza quem está DENTRO daquela
    // conversa (entrarChat) — quem está em outra tela não recebe nada por
    // ali, então aqui é onde avisamos visualmente
    FirebaseMessaging.onMessage.listen((message) {
      loggerService.i('Push recebido em foreground: ${message.data}');
      _tratarPushEmForeground(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_tratarToque);

    final mensagemInicial = await FirebaseMessaging.instance.getInitialMessage();
    if (mensagemInicial != null) _tratarToque(mensagemInicial);
  }

  void _tratarPushEmForeground(RemoteMessage message) {
    final tipo = message.data['tipo'];
    final conversaId = message.data['conversaId'] as String?;

    if (tipo == 'nova_mensagem' && conversaId != null) {
      // atualiza o rastreador de não lidas — qualquer tela de lista que
      // já use ChatReadTracker.hasUnread() reflete isso automaticamente
      ChatReadTracker.updateLatest(conversaId, DateTime.now());
    }

    final titulo = message.data['titulo'] as String?;
    final corpo = message.data['corpo'] as String?;
    if (titulo == null) return;

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(corpo != null && corpo.isNotEmpty ? '$titulo: $corpo' : titulo),
        behavior: SnackBarBehavior.floating,
        action: conversaId != null
            ? SnackBarAction(
                label: 'Ver',
                onPressed: () => navigatorKey.currentState
                    ?.pushNamed('/chat', arguments: {'conversaId': conversaId}),
              )
            : null,
      ),
    );
  }

  void _tratarToque(RemoteMessage message) {
    final conversaId = message.data['conversaId'];
    if (conversaId != null) {
      navigatorKey.currentState?.pushNamed('/chat', arguments: {'conversaId': conversaId});
    }
  }

  /// Chama isso no logout, ANTES de limpar o token de autenticação salvo
  /// (o DELETE precisa do Bearer ainda válido). Remove o token desse
  /// dispositivo do backend e invalida ele no Firebase também, pra esse
  /// aparelho parar de receber push dessa conta a partir de agora.
  Future<void> desregistrar() async {
    if (_tokenAtual == null) return;

    try {
      final authToken = await AuthStorage.getToken();
      if (authToken != null) {
        await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/dispositivos'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({'fcmToken': _tokenAtual}),
        );
      }
      await FirebaseMessaging.instance.deleteToken();
      _tokenAtual = null;
    } catch (e) {
      loggerService.w('Falha ao desregistrar token no logout: $e');
    }
  }

  Future<void> _registrarTokenNoBackend(String token) async {
    final authToken = await AuthStorage.getToken();
    if (authToken == null) return; // ainda não logado — tenta de novo após login

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dispositivos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'fcmToken': token,
          'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
        }),
      );
      loggerService.d('Registro de device token → ${response.statusCode}');
    } catch (e) {
      loggerService.w('Falha ao registrar device token: $e');
    }
  }
}

final pushService = PushService();