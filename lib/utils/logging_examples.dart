/// Template para integração do LoggerService em novos widgets/serviços
///
/// IMPORTANTE: Este arquivo contém exemplos de código comentados
/// e não é executável diretamente. Use-o como referência para integrar
/// o LoggerService em seus próprios arquivos.
///
/// Para usar: Copie os exemplos e adapte para seus próprios serviços e widgets.

// ignore_for_file: unused_element, unused_import, invalid_use_of_visible_for_testing_member

/*
// ============================================================================
// EXEMPLO 1: Integração em um Serviço
// ============================================================================

import 'package:autoscan/services/logger_service.dart';

class ExampleService {
  /// Realiza uma operação exemplo com logging
  Future<void> performOperation(String id) async {
    try {
      // Log de início
      loggerService.d('Iniciando operação com ID: $id');

      // Simulando uma operação assíncrona
      await Future.delayed(const Duration(seconds: 1));

      // Log de sucesso
      loggerService.i('Operação concluída com sucesso para ID: $id');
    } on FormatException catch (e, s) {
      // Log de erro específico
      loggerService.w(
        'Erro de formato ao processar ID: $id',
        error: e,
        stackTrace: s,
      );
    } catch (e, s) {
      // Log de erro genérico
      loggerService.e(
        'Erro crítico na operação',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Retorna dados com logging
  Future<Map<String, dynamic>> fetchData(String endpoint) async {
    try {
      loggerService.v('Requisitando: $endpoint');

      // Simular requisição
      await Future.delayed(const Duration(milliseconds: 500));

      final data = {'status': 'ok', 'data': []};

      loggerService.d('Dados recebidos do endpoint: $endpoint');
      return data;
    } catch (e, s) {
      loggerService.e(
        'Falha ao buscar dados de $endpoint',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }
}

// ============================================================================
// EXEMPLO 2: Integração em um Widget/Screen
// ============================================================================

import 'package:flutter/material.dart';
import 'package:autoscan/services/logger_service.dart';

class ExampleWidgetScreen extends StatefulWidget {
  const ExampleWidgetScreen({super.key});

  @override
  State<ExampleWidgetScreen> createState() => _ExampleWidgetScreenState();
}

class _ExampleWidgetScreenState extends State<ExampleWidgetScreen> {
  final _service = ExampleService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    loggerService.d('ExampleWidgetScreen.initState() chamado');
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      loggerService.d('Carregando dados iniciais...');

      setState(() => _isLoading = true);

      await _service.performOperation('initial');

      loggerService.i('Dados iniciais carregados com sucesso');
    } catch (e, s) {
      loggerService.e(
        'Erro ao carregar dados iniciais',
        error: e,
        stackTrace: s,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar dados')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleButtonPress() {
    loggerService.d('Botão pressionado');
    _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    loggerService.v('ExampleWidgetScreen.build() chamado');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exemplo de Integração'),
        onWillPop: () {
          loggerService.d('Saindo de ExampleWidgetScreen');
          return Future.value(true);
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Exemplo de Integração do Logger'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleButtonPress,
                    child: const Text('Carregar Dados'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    loggerService.d('ExampleWidgetScreen.dispose() chamado');
    super.dispose();
  }
}

// ============================================================================
// EXEMPLO 3: Padrão de Try-Catch com Logging
// ============================================================================

Future<T> safeExecute<T>(
  Future<T> Function() operation,
  String operationName,
) async {
  try {
    loggerService.d('Iniciando: $operationName');
    final result = await operation();
    loggerService.i('Sucesso: $operationName');
    return result;
  } catch (e, s) {
    loggerService.e(
      'Falha em: $operationName',
      error: e,
      stackTrace: s,
    );
    rethrow;
  }
}

// Uso:
// final result = await safeExecute(
//   () => _service.fetchData('/api/data'),
//   'Buscar dados da API',
// );

// ============================================================================
// EXEMPLO 4: Logging de Eventos de Negócio
// ============================================================================

class BusinessEventLogger {
  static void logUserLogin(String userId) {
    loggerService.i('Usuário fez login: $userId');
  }

  static void logUserLogout(String userId) {
    loggerService.i('Usuário fez logout: $userId');
  }

  static void logDiagnosticStarted(String diagnosticId, String vehicleId) {
    loggerService.i(
      'Diagnóstico iniciado - ID: $diagnosticId, Veículo: $vehicleId',
    );
  }

  static void logDiagnosticCompleted(
    String diagnosticId,
    String result,
  ) {
    loggerService.i(
      'Diagnóstico concluído - ID: $diagnosticId, Resultado: $result',
    );
  }

  static void logPaymentProcessed(String paymentId, double amount) {
    loggerService.i(
      'Pagamento processado - ID: $paymentId, Valor: R\$ $amount',
    );
  }

  static void logErrorOccurred(String context, String message) {
    loggerService.e(
      'Erro em $context: $message',
    );
  }
}

// Uso:
// BusinessEventLogger.logUserLogin('user123');
// BusinessEventLogger.logDiagnosticStarted('diag456', 'vehicle789');

// ============================================================================
// EXEMPLO 5: Logging com Context
// ============================================================================

class ContextualLogger {
  final String _context;

  ContextualLogger(this._context);

  void debug(String message) {
    loggerService.d('[$_context] $message');
  }

  void info(String message) {
    loggerService.i('[$_context] $message');
  }

  void warning(String message) {
    loggerService.w('[$_context] $message');
  }

  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    loggerService.e(
      '[$_context] $message',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

// Uso:
// final logger = ContextualLogger('DiagnosticScreen');
// logger.debug('Iniciando diagnóstico');
// logger.info('Diagnóstico completado');

// ============================================================================
// EXEMPLO 6: Integração com Stream
// ============================================================================

Stream<String> exampleStreamWithLogging() async* {
  try {
    loggerService.d('Iniciando stream');

    for (int i = 0; i < 5; i++) {
      loggerService.v('Emitindo item $i');
      yield 'Item $i';
      await Future.delayed(const Duration(seconds: 1));
    }

    loggerService.i('Stream concluído');
  } catch (e, s) {
    loggerService.e('Erro no stream', error: e, stackTrace: s);
  }
}

// ============================================================================
// EXEMPLO 7: Validação com Logging
// ============================================================================

bool validateEmail(String email) {
  loggerService.v('Validando email: $email');

  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  final isValid = regex.hasMatch(email);

  if (isValid) {
    loggerService.d('Email válido: $email');
  } else {
    loggerService.w('Email inválido: $email');
  }

  return isValid;
}
*/

// Este arquivo existe apenas para documentação e exemplos.
// Não contém código executável real.
