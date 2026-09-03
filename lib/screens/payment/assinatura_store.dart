import 'package:flutter/foundation.dart';

import 'package:autex/models/resultado_assinatura.dart';
import 'package:autex/services/auth_storage.dart';
import 'package:autex/services/payment/pagamento_service.dart';

/// Estado global da assinatura do usuário.
///
/// Singleton com ValueNotifier em vez de um pacote de state management: o app
/// não usa nenhum hoje, e uma dependência nova para um único estado não se
/// paga. Qualquer tela escuta com ValueListenableBuilder.
///
/// Carregado no login e no boot; recarregado depois de pagar.
class AssinaturaStore {
  AssinaturaStore._();
  static final instancia = AssinaturaStore._();

  final ValueNotifier<StatusPagamento?> status = ValueNotifier(null);
  final ValueNotifier<bool> carregando = ValueNotifier(false);

  StatusPagamento? get atual => status.value;

  bool get temAcesso => status.value?.temAcesso ?? false;
  String? get planoChave => status.value?.planoChave;


  /// Dias até o vencimento. Negativo se já venceu, null se não há assinatura.
  int? get diasParaVencer {
    final v = status.value?.proximoVencimento;
    if (v == null) return null;
    return v.difference(DateTime.now()).inDays;
  }

  /// Mostra o aviso de renovação.
  ///
  /// Só para quem NÃO renova sozinho: cartão recorrente se vira, e avisar
  /// nesse caso só gera confusão ("preciso fazer algo?" — não precisa).
  bool get precisaRenovar {
    final s = status.value;
    if (s == null || !s.temAcesso) return false;
    if (s.metodoPagamento == MetodoPagamento.cartao && !s.cancelamentoAgendado) {
      return false; // renova automático
    }
    final dias = diasParaVencer;
    return dias != null && dias <= 7;
  }

  Future<void> carregar({String? empresaId}) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      limpar();
      return;
    }

    carregando.value = true;
    try {
      final res = await PagamentoService.consultarStatus(
        token: token,
        empresaId: empresaId,
      );
      if (res['success'] == true) {
        status.value = res['status'] as StatusPagamento;
      } else {
        // Falha de rede não deve derrubar o app inteiro — o guard do backend
        // continua sendo a fonte de verdade sobre acesso.
        status.value = null;
      }
    } finally {
      carregando.value = false;
    }
  }

  /// Chamar depois de pagar: o webhook pode levar segundos, então vale
  /// recarregar em vez de confiar no estado antigo.
  Future<void> recarregar({String? empresaId}) => carregar(empresaId: empresaId);

  void limpar() {
    status.value = null;
  }
}