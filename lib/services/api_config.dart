import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  static const String _host = 'http://187.127.27.216:3001';

  // Base HTTP da API.
  static String get baseUrl {
    if (kIsWeb) return _host;
    if (Platform.isAndroid) return _host;
    return _host;
  }

  // Socket.io usa o host raiz, sem /api.
  static String get wsUrl => _host;

  // Console do Firebase → Configurações do projeto → Cloud Messaging →
  // Configuração da Web → Certificados Web Push → Gerar par de chaves.
  // Só é usada na plataforma web (getToken ignora isso em Android/iOS).
  static const String vapidKey = 'BJAn7uwVYhyHfSmU79psUKSqPWDhc3vFdpYSfarWBlaFl6YEOYmKxjSM158yPKGpdgClMWJSDULI8iB1YGT0k9s';
}