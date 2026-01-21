import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/history_screen.dart';
import 'screens/diagnostic_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/chat_screen.dart';

void main() {
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
