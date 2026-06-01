import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStorage.init();

  logN.i('App iniciado');

  final loggedIn = await AuthStorage.isLoggedIn();
  runApp(AutexApp(initialRoute: loggedIn ? '/home' : '/login'));
}

class AutexApp extends StatelessWidget {
  final String initialRoute;
  const AutexApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
