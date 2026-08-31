import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {

  static String get baseUrl {
    if (kIsWeb) return 'https://teste.autex.app.br/api';
    if (Platform.isAndroid) return 'https://teste.autex.app.br/api';
    return 'https://teste.autex.app.br/api';
  }

  static String get wsUrl => baseUrl.replaceAll('/api', '');
  static const String vapidKey = 'BJAn7uwVYhyHfSmU79psUKSqPWDhc3vFdpYSfarWBlaFl6YEOYmKxjSM158yPKGpdgClMWJSDULI8iB1YGT0k9s';
}