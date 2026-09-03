import 'dart:convert';
import 'package:autex/models/resultado_assinatura.dart';
import 'package:autex/services/api_client.dart';
import 'package:autex/services/logger_service.dart';

class PagamentoService {
  static Future<Map<String, dynamic>> salvarDadosCobranca({
    required String token,
    String? cpf,
    required String telefone,
    required Map<String, String> endereco,
    String? empresaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/pagamentos/dados-cobranca',
        token: token,
        body: {
          if (cpf != null) 'cpf': cpf,
          'telefone': telefone,
          'endereco': endereco,
          if (empresaId != null) 'empresaId': empresaId,
        },
      );
      loggerService.d('salvarDadosCobranca → ${response.statusCode}');
      if (_ok(response.statusCode)) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return _erro(response.body);
    } catch (e) {
      loggerService.e('salvarDadosCobranca erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> criarSetupIntent({
    required String token,
    String? empresaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/pagamentos/setup-intent',
        token: token,
        body: {if (empresaId != null) 'empresaId': empresaId},
      );
      loggerService.d('criarSetupIntent → ${response.statusCode}');
      if (_ok(response.statusCode)) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return _erro(response.body);
    } catch (e) {
      loggerService.e('criarSetupIntent erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// `intervalo` passou a ser obrigatório no backend (MENSAL | TRIMESTRAL |
  /// SEMESTRAL | ANUAL). Hoje só MENSAL está ativo; os outros devolvem 404
  /// "Combinação de plano e intervalo indisponível" até serem ligados por
  /// UPDATE em plano_preco.
  static Future<Map<String, dynamic>> assinar({
    required String token,
    required String planoId,
    required String intervalo,
    required String metodoPagamento,
    String? paymentMethodId,
    String? setupIntentId,
    String? empresaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/pagamentos/assinar',
        token: token,
        body: {
          'planoId': planoId,
          'intervalo': intervalo,
          'metodoPagamento': metodoPagamento,
          if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
          if (setupIntentId != null) 'setupIntentId': setupIntentId,
          if (empresaId != null) 'empresaId': empresaId,
        },
      );
      loggerService.d('assinar → ${response.statusCode}');

      if (_ok(response.statusCode)) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'resultado': ResultadoAssinatura.deJson(json)};
      }
      return _erro(response.body);
    } catch (e) {
      loggerService.e('assinar erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// Polling da tela "aguardando pagamento".
  ///
  /// Pix compensa em segundos: sem isto o cliente paga, volta pro app e
  /// nada acontece. Boleto leva dias — ali o polling não ajuda, o que vale
  /// é o cliente sair e voltar depois.
  static Future<Map<String, dynamic>> consultarStatus({
    required String token,
    String? empresaId,
  }) async {
    try {
      final path = empresaId != null
          ? '/pagamentos/status?empresaId=$empresaId'
          : '/pagamentos/status';
      final response = await ApiClient.get(path, token: token);

      if (_ok(response.statusCode)) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'status': StatusPagamento.deJson(json)};
      }
      return _erro(response.body);
    } catch (e) {
      loggerService.e('consultarStatus erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  /// Abandona uma cobrança PENDENTE para liberar nova tentativa com outro
  /// método. O backend recusa com PAGAMENTO_JA_CONFIRMADO se o dinheiro já
  /// entrou — nesse caso a assinatura vai ativar sozinha pelo webhook.
  static Future<Map<String, dynamic>> cancelarPendente({
    required String token,
    String? empresaId,
  }) async {
    try {
      final path = empresaId != null
          ? '/pagamentos/pendente?empresaId=$empresaId'
          : '/pagamentos/pendente';
      final response = await ApiClient.delete(path, token: token);
      loggerService.d('cancelarPendente → ${response.statusCode}');
      if (_ok(response.statusCode)) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return _erro(response.body);
    } catch (e) {
      loggerService.e('cancelarPendente erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> cancelar({
    required String token,
    String? empresaId,
  }) async {
    try {
      final path = empresaId != null
          ? '/pagamentos/cancelar?empresaId=$empresaId'
          : '/pagamentos/cancelar';
      final response = await ApiClient.delete(path, token: token);
      loggerService.d('cancelar → ${response.statusCode}');
      if (_ok(response.statusCode)) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return _erro(response.body);
    } catch (e) {
      loggerService.e('cancelar erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // ─────────────────────────── Internos ───────────────────────────

  static bool _ok(int status) => status == 200 || status == 201;

  /// A versão anterior extraía SÓ `message` e descartava o resto.
  ///
  /// O backend agora manda erro estruturado — em PAGAMENTO_EM_ABERTO vêm
  /// `assinaturaId`, `urlFatura` e `expiraEm`, que são o que permite reabrir
  /// o boleto existente em vez de mostrar "erro, tente novamente". Sem
  /// preservar esses campos, o cliente fica sem saída.
  static Map<String, dynamic> _erro(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return {
        'success': false,
        'message': json['message']?.toString() ?? 'Erro desconhecido',
        'codigo': json['codigo']?.toString(),
        'erro': json, // payload completo, pra quem precisar dos extras
      };
    } catch (_) {
      return {
        'success': false,
        'message': body.isNotEmpty ? body : 'Erro desconhecido',
      };
    }
  }
  // ─────────────────────────── Renovação ───────────────────────────
//
// Adicionar ao PagamentoService (lib/services/payment/pagamento_service.dart),
// junto dos outros métodos estáticos.

  /// Renova a assinatura atual antes do vencimento.
  ///
  /// Plano e intervalo vêm da assinatura existente — o cliente está renovando
  /// o que já tem. Só o método pode mudar: é assim que se troca de boleto
  /// para cartão sem cancelar nada.
  static Future<Map<String, dynamic>> renovar({
    required String token,
    required String metodoPagamento,
    String? paymentMethodId,
    String? setupIntentId,
    String? empresaId,
  }) async {
    try {
      final response = await ApiClient.post(
        '/pagamentos/renovar',
        token: token,
        body: {
          'metodoPagamento': metodoPagamento,
          if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
          if (setupIntentId != null) 'setupIntentId': setupIntentId,
          if (empresaId != null) 'empresaId': empresaId,
        },
      );
      loggerService.d('renovar → ${response.statusCode}');

      if (_ok(response.statusCode)) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'resultado': ResultadoAssinatura.deJson(json)};
      }
      return _erro(response.body);
    } catch (e) {
      loggerService.e('renovar erro: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}