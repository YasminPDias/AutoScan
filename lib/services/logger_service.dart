import 'package:logger/logger.dart';

/// Serviço centralizado de logging para a aplicação AutoScan
///
/// Exemplo de uso:
/// ```dart
/// import 'package:autoscan/services/logger_service.dart';
///
/// loggerService.d('Mensagem de debug');
/// loggerService.i('Informação');
/// loggerService.w('Aviso');
/// loggerService.e('Erro', error: Exception('Algo deu errado'));
/// ```

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  late Logger _logger;

  LoggerService._internal() {
    _initializeLogger();
  }

  factory LoggerService() {
    return _instance;
  }

  /// Inicializa o logger com configurações padrão
  void _initializeLogger() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
      ),
      level: Level.debug,
      filter: ProductionFilter(),
    );
  }

  /// Log de nível verbose
  void v(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.v(message, error: error, stackTrace: stackTrace);
  }

  /// Log de nível debug
  void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log de nível info
  void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log de nível warning
  void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log de nível error
  void e(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log de nível wtf (What a Terrible Failure)
  void wtf(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.wtf(message, error: error, stackTrace: stackTrace);
  }

  /// Muda o nível de logging (útil para diferentes ambientes)
  void setLevel(Level level) {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
      ),
      level: level,
      filter: ProductionFilter(),
    );
  }

  /// Fecha o logger e libera recursos
  void close() {
    _logger.close();
  }
}

/// Instância global do serviço de logging
final loggerService = LoggerService();

/// Aliases curtos para uso rápido
final logN = loggerService; // Usar: logN.d(), logN.w(), logN.e(), etc
final log = loggerService; // Alternativa: log.d(), log.w(), log.e(), etc
