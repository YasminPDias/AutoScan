import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login/login_screen.dart';
import 'screens/register/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/diagnostic/diagnostic_screen.dart';
import 'screens/plans/plans_screen.dart';
import 'screens/chat/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutoScanApp());
}

class AutoScanApp extends StatelessWidget {
  const AutoScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/history': (context) => const HistoryScreen(),
        '/diagnostic': (context) => const DiagnosticScreen(),
        '/plans': (context) => const PlansScreen(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
