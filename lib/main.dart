import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login/login_screen.dart';
import 'screens/register/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/diagnostic/diagnostic_screen.dart';
import 'screens/diagnostic/diagnostic_result_screen.dart';
import 'screens/plans/plans_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_history_screen.dart';
import 'services/auth_storage.dart';
import 'services/logger_service.dart';
import 'services/socket_service.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStorage.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  logN.i('App iniciado');

  final loggedIn = await AuthStorage.isLoggedIn();

  if (loggedIn) {
    // app reaberto com sessão já ativa (não passou pela tela de login agora) —
    // conecta direto, sem esperar a ação de login.
    // TODO: ajusta 'getToken' pro método real de pegar o token no AuthStorage
    final token = await AuthStorage.getToken();
    if (token != null) {
      socketService.conectar(token);
      await pushService.inicializar();
    }
  }

  // Web: se a página foi aberta a partir de um clique em notificação (o
  // service worker abriu essa URL com ?conversaId=...), captura aqui — isso
  // não passa pelo onMessageOpenedApp/getInitialMessage do Dart, que só
  // funcionam pra clique com o app já rodando.
  final conversaIdDaUrl = kIsWeb ? Uri.base.queryParameters['conversaId'] : null;

  runApp(AutexApp(initialRoute: loggedIn ? '/home' : '/login'));

  if (loggedIn && conversaIdDaUrl != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState
          ?.pushNamed('/chat', arguments: {'conversaId': conversaIdDaUrl});
    });
  }
}

class AutexApp extends StatelessWidget {
  final String initialRoute;
  const AutexApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Autex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/history': (context) => const HistoryScreen(),
        '/diagnostic': (context) => const DiagnosticScreen(),
        '/diagnostic-result': (context) => const DiagnosticResultScreen(),
        '/plans': (context) => const PlansScreen(),
        '/chat': (context) => const ChatScreen(),
        '/chat-history': (context) => const ChatHistoryScreen(),
      },
    );
  }
}