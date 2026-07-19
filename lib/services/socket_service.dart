import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_config.dart';
import 'auth_storage.dart';
import 'logger_service.dart';
import 'push_service.dart' show navigatorKey;

/// Conexão Socket.io única, compartilhada pelo app inteiro.
///
/// Conecta uma vez (no login, ou no boot se já havia sessão) e persiste
/// durante toda a sessão do app — diferente do antigo ChatRealtimeService,
/// que abria uma conexão nova por conversa. Isso é necessário porque os
/// eventos de fila (novoChamado, chamadoDisponivel) precisam chegar mesmo
/// com nenhum chat aberto na tela.
///
/// O ChatRealtimeService reaproveita essa mesma conexão pra entrar/sair de
/// salas de conversa específicas, em vez de abrir a própria.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  IO.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  // callbacks pros eventos de fila — a tela que for exibir isso registra aqui
  void Function(Map<String, dynamic>)? onNovoChamado;
  void Function(Map<String, dynamic>)? onChamadoDisponivel;
  void Function(Map<String, dynamic>)? onConversaReivindicada;

  // callback pra listas/históricos de chat atualizarem sem precisar estar
  // com aquela conversa especificamente aberta (entrarChat)
  void Function(Map<String, dynamic>)? onConversaAtualizada;

  void conectar(String token) {
    if (_socket != null && _socket!.connected) return; // já conectado

    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/chatws')
          .setAuth({'token': token})
          .build(),
    );

    _socket!.on('connect', (_) => loggerService.i('Socket conectado'));
    _socket!.on('disconnect', (_) => loggerService.w('Socket desconectado'));
    _socket!.on('connect_error', (e) {
      loggerService.e('Erro de conexão do socket: $e');

      // se o erro for de sessão encerrada (token inválido ou expirado no Redis),
      // redireciona pro login — mesmo caminho que o ApiClient usa no 401
      final mensagem = e?.toString() ?? '';
      if (mensagem.contains('Sessão encerrada') ||
          mensagem.contains('Token inválido') ||
          mensagem.contains('Token não fornecido')) {
        _redirecionarParaLogin(mensagem);
      }
    });

    // backend emite isso antes de desconectar forçadamente quando um novo
    // login acontece em outro dispositivo — faz logout automático aqui
    _socket!.on('sessaoEncerrada', (data) {
      loggerService.w('Sessão encerrada remotamente: $data');
      _fazerLogoutAutomatico();
    });

    _socket!.on('novoChamado', (data) {
      loggerService.i('novoChamado recebido');
      if (data is Map) onNovoChamado?.call(Map<String, dynamic>.from(data));
    });
    _socket!.on('chamadoDisponivel', (data) {
      loggerService.i('chamadoDisponivel recebido');
      if (data is Map) onChamadoDisponivel?.call(Map<String, dynamic>.from(data));
    });
    _socket!.on('conversaReivindicada', (data) {
      loggerService.i('conversaReivindicada recebido');
      if (data is Map) onConversaReivindicada?.call(Map<String, dynamic>.from(data));
    });
    _socket!.on('conversaAtualizada', (data) {
      if (data is Map) onConversaAtualizada?.call(Map<String, dynamic>.from(data));
    });
  }

  void desconectar() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  Future<void> _redirecionarParaLogin([String? motivo]) async {
    desconectar();
    await AuthStorage.clear();
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
        arguments: {
          'mensagemErro': motivo?.isNotEmpty == true
              ? motivo
              : 'Sua sessão foi encerrada. Faça login novamente.',
        },
      );
    }
  }

  // mantido por compatibilidade — agora delega pro _redirecionarParaLogin
  Future<void> _fazerLogoutAutomatico() => _redirecionarParaLogin();
}

final socketService = SocketService();