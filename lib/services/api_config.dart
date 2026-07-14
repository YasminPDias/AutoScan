import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConfig {
  // Emulador Android: 10.0.2.2 é obrigatório (localhost ali é o próprio emulador).
  // Dispositivo físico (Android ou iOS): nem isso funciona — troca manualmente
  // pelo IP da sua máquina na rede local (ex: 192.168.0.x), ou pelo domínio
  // real quando for testar contra a VPS/produção.
  static String get baseUrl {
    if (kIsWeb) return 'http://187.127.27.216:3001';
    if (Platform.isAndroid) return 'http://187.127.27.216:3001';
    return 'http://187.127.27.216:3001'; // iOS simulator
  }

  // o cliente socket.io usa esse mesmo host (ele mesmo cuida do protocolo)
  static String get wsUrl => baseUrl;

  // Console do Firebase → Configurações do projeto → Cloud Messaging →
  // Configuração da Web → Certificados Web Push → Gerar par de chaves.
  // Só é usada na plataforma web (getToken ignora isso em Android/iOS).
  static const String vapidKey = 'BJAn7uwVYhyHfSmU79psUKSqPWDhc3vFdpYSfarWBlaFl6YEOYmKxjSM158yPKGpdgClMWJSDULI8iB1YGT0k9s';
}