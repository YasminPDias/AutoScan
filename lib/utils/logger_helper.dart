/// Documentação e exemplos de uso do LoggerService
///
/// Este arquivo serve como referência para usar o sistema de logging
/// em toda a aplicação AutoScan.
///
/// EXEMPLOS DE USO:
/// ================
///
/// 1. Import básico:
/// ```dart
/// import 'package:autoscan/services/logger_service.dart';
/// ```
///
/// 2. Log de diferentes níveis:
/// ```dart
/// // Debug - informações úteis para desenvolvimento
/// loggerService.d('Iniciando carregamento dos dados');
///
/// // Info - informações relevantes da aplicação
/// loggerService.i('Usuário realizou login com sucesso');
///
/// // Warning - situações incomuns que merecem atenção
/// loggerService.w('Requisição demorou mais que o esperado');
///
/// // Error - erros que impedem funcionamento normal
/// loggerService.e('Falha ao carregar diagnósticos', 
///   error: exception, 
///   stackTrace: stackTrace
/// );
///
/// // Verbose - informações detalhadas de debug
/// loggerService.v('Valor da variável: ${variable}');
///
/// // WTF - situações críticas
/// loggerService.wtf('Estado da aplicação foi comprometido');
/// ```
///
/// 3. Em um serviço:
/// ```dart
/// import 'package:autoscan/services/logger_service.dart';
/// import 'package:autoscan/services/api_service.dart';
///
/// class DiagnosticService {
///   final ApiService _apiService = ApiService();
///
///   Future<void> runDiagnostic(String vehicleId) async {
///     try {
///       loggerService.d('Iniciando diagnóstico para veículo: $vehicleId');
///       
///       final result = await _apiService.getDiagnostic(vehicleId);
///       
///       loggerService.i('Diagnóstico concluído com sucesso');
///       return result;
///     } catch (e, s) {
///       loggerService.e(
///         'Erro ao executar diagnóstico',
///         error: e,
///         stackTrace: s,
///       );
///       rethrow;
///     }
///   }
/// }
/// ```
///
/// 4. Em um Widget/Tela:
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:autoscan/services/logger_service.dart';
///
/// class DashboardScreen extends StatefulWidget {
///   const DashboardScreen({super.key});
///
///   @override
///   State<DashboardScreen> createState() => _DashboardScreenState();
/// }
///
/// class _DashboardScreenState extends State<DashboardScreen> {
///   @override
///   void initState() {
///     super.initState();
///     loggerService.d('DashboardScreen inicializado');
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: const Text('Dashboard')),
///       body: Center(
///         child: ElevatedButton(
///           onPressed: () {
///             loggerService.i('Botão pressionado no Dashboard');
///           },
///           child: const Text('Pressione-me'),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// NÍVEIS DE LOG EXPLICADOS:
/// ========================
/// 
/// Level.verbose (V) - Mais detalhado, apenas para desenvolvimento
/// Level.debug (D)   - Informações de debug úteis
/// Level.info (I)    - Informações importantes da aplicação
/// Level.warning (W) - Situações incomuns mas não críticas
/// Level.error (E)   - Erros que precisam de atenção
/// Level.wtf (WTF)   - O que é um falha terrível
/// Level.nothing     - Desabilita logging
///
/// CONFIGURAÇÕES:
/// ==============
///
/// Para mudar o nível de logging em tempo de execução:
/// ```dart
/// import 'package:logger/logger.dart';
/// import 'package:autoscan/services/logger_service.dart';
///
/// // Somente logs de nível INFO e acima
/// loggerService.setLevel(Level.info);
/// ```
///
/// BOAS PRÁTICAS:
/// ==============
///
/// ✓ Use mensagens descritivas e contextualizadas
/// ✓ Sempre capture erros com stackTrace
/// ✓ Use o nível apropriado para cada situação
/// ✓ Não logue dados sensíveis (senhas, tokens, PII)
/// ✓ Não use print(), use loggerService em vez disso
/// ✓ Logue eventos importantes do ciclo de vida
/// ✓ Logue transições entre estados
/// ✓ Capture stack traces completos de erros
///
/// ✗ Evite logs excessivos em loops
/// ✗ Evite logs muito verbosos em produção
/// ✗ Não ignore erros sem logs
/// ✗ Não use concatenação com operadores em logs críticos

// Arquivo de referência - Nenhuma implementação aqui
// Este arquivo é apenas para documentação
