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

  Future<bool> checarPermissao() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      loggerService.w('Erro ao checar permissão de notificação: $e');
      return false;
    }
  }

  Future<bool> solicitarPermissao() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        await inicializar();
      }
      return granted;
    } catch (e) {
      loggerService.w('Erro ao solicitar permissão de notificação: $e');
      return false;
    }
  }

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
    final conversaId = message.data['conversaId'] as String?;
    final titulo = message.data['titulo'] as String?;
    final corpo = message.data['corpo'] as String?;

    if (conversaId != null) {
      ChatReadTracker.incrementar(conversaId);
    }

    if (titulo == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    _mostrarNotificacaoOverlay(
      context: context,
      titulo: titulo,
      corpo: corpo,
      conversaId: conversaId,
    );
  }

  void _mostrarNotificacaoOverlay({
    required BuildContext context,
    required String titulo,
    String? corpo,
    String? conversaId,
  }) {
    scaffoldMessengerKey.currentState?.clearSnackBars();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        // duração generosa — o X fecha antes se o usuário quiser
        duration: const Duration(seconds: 6),
        // padding zero pra o widget customizado preencher tudo
        padding: EdgeInsets.zero,
        // fundo transparente — a cor vem do Container interno
        backgroundColor: Colors.transparent,
        // sem sombra própria do SnackBar — a do Container já faz isso
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16,
        ),
        content: _AutexToastContent(
          titulo: titulo,
          corpo: corpo,
          conversaId: conversaId,
          onVerPressed: conversaId != null
              ? () {
                  scaffoldMessengerKey.currentState?.clearSnackBars();
                  navigatorKey.currentState?.pushNamed(
                    '/chat',
                    arguments: {'conversaId': conversaId},
                  );
                }
              : null,
          onDismiss: () => scaffoldMessengerKey.currentState?.clearSnackBars(),
        ),
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

/// Conteúdo do toast de notificação no estilo Autex.
/// Usado dentro de um SnackBar customizado — fundo branco,
/// borda esquerda vermelha, ícone de chat, botão "Ver" e X pra fechar.
class _AutexToastContent extends StatelessWidget {
  final String titulo;
  final String? corpo;
  final String? conversaId;
  final VoidCallback? onVerPressed;
  final VoidCallback onDismiss;

  const _AutexToastContent({
    required this.titulo,
    this.corpo,
    this.conversaId,
    this.onVerPressed,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // barra vermelha esquerda
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFDC143C),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // ícone
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC143C).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFFDC143C),
                  size: 18,
                ),
              ),
            ),
            // texto
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 14, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (corpo != null && corpo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        corpo!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (onVerPressed != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onVerPressed,
                        child: const Text(
                          'Ver conversa →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC143C),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // botão fechar
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: GestureDetector(
                onTap: onDismiss,
                child: const Icon(
                  Icons.close,
                  size: 32,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}