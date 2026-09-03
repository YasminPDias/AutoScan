import 'package:autex/screens/payment/assinatura_store.dart';


/// Quais planos liberam cada recurso.
///
/// ESTE MAPA É ESPELHO DO BACKEND, não a fonte de verdade. O que impede
/// acesso de verdade é o @ExigePlano() nas rotas — aqui só escondemos o que
/// o servidor recusaria, para o cliente não clicar e levar 403.
///
/// Se divergir do backend, o sintoma é feio nos dois sentidos: recurso
/// visível que dá erro ao clicar, ou recurso pago escondido de quem pagou.
/// Ao mudar um dos lados, mude o outro.
class Recursos {
  Recursos._();

  static const diagnosticoIlimitado = 'diagnostico_ilimitado';
  static const esquemaEletrico = 'esquema_eletrico';
  static const assessoriaOnline = 'assessoria_online';
  static const precificacaoMO = 'precificacao_mo';
  static const academy = 'academy';
  static const gestaoEquipe = 'gestao_equipe';

  static const Map<String, List<String>> _planosPor = {
    diagnosticoIlimitado: ['PRO', 'PREMIUM', 'EMPRESARIAL'],
    esquemaEletrico: ['PREMIUM', 'EMPRESARIAL'],
    assessoriaOnline: ['PREMIUM', 'EMPRESARIAL'],
    precificacaoMO: ['PREMIUM', 'EMPRESARIAL'],
    academy: ['PREMIUM', 'EMPRESARIAL'],
    gestaoEquipe: ['EMPRESARIAL'],
  };

  /// Se o usuário atual pode ver o recurso.
  ///
  /// Exige assinatura viva E plano suficiente: quem tem PREMIUM vencido não
  /// deve continuar vendo o que pagou mês passado.
  static bool libera(String recurso) {
    final store = AssinaturaStore.instancia;
    if (!store.temAcesso) return false;

    final chave = store.planoChave;
    if (chave == null) return false;

    return _planosPor[recurso]?.contains(chave) ?? false;
  }

  /// Menor plano que libera o recurso — para a mensagem de upgrade, quando
  /// houver. Assume a ordem FREE < PRO < PREMIUM < EMPRESARIAL.
  static String? planoMinimo(String recurso) {
    const ordem = ['FREE', 'PRO', 'PREMIUM', 'EMPRESARIAL'];
    final planos = _planosPor[recurso];
    if (planos == null || planos.isEmpty) return null;

    planos.sort((a, b) => ordem.indexOf(a).compareTo(ordem.indexOf(b)));
    return planos.first;
  }
}
