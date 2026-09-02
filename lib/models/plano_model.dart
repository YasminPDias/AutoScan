class PlanoModel {
  final String id;
  final String nome;

  /// Tier do plano — FREE | PRO | PREMIUM | EMPRESARIAL.
  ///
  /// Diferente de `tipo`, que só diz quem pode comprar (INDIVIDUAL vs
  /// EMPRESARIAL) e não separa PRO de PREMIUM. É por esta chave que o card
  /// de benefícios resolve os textos.
  ///
  /// Nullable porque a coluna é nova: plano gravado antes da migration pode
  /// não ter. O card degrada para lista vazia em vez de quebrar.
  final String? chave;

  final String tipo; // INDIVIDUAL | EMPRESARIAL
  final int maxDiagnosticosPeriodo;
  final String periodoDiagnostico; // SEMANA | MES
  final int? maxUsuarios;
  final double precoMensal;
  final bool ativo;

  PlanoModel({
    required this.id,
    required this.nome,
    this.chave,
    required this.tipo,
    required this.maxDiagnosticosPeriodo,
    required this.periodoDiagnostico,
    this.maxUsuarios,
    required this.precoMensal,
    required this.ativo,
  });

  factory PlanoModel.fromJson(Map<String, dynamic> json) {
    return PlanoModel(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      chave: json['chave']?.toString(),
      tipo: json['tipo']?.toString() ?? 'INDIVIDUAL',
      maxDiagnosticosPeriodo:
          int.tryParse(json['maxDiagnosticosPeriodo']?.toString() ?? '0') ?? 0,
      periodoDiagnostico: json['periodoDiagnostico']?.toString() ?? 'MES',
      maxUsuarios: json['maxUsuarios'] != null
          ? int.tryParse(json['maxUsuarios'].toString())
          : null,
      precoMensal: double.tryParse(json['precoMensal']?.toString() ?? '0') ?? 0,
      ativo: json['ativo'] == true,
    );
  }

  bool get isEmpresarial => tipo == 'EMPRESARIAL';
  bool get isFree => precoMensal == 0;
  bool get isDiagnosticoIlimitado => maxDiagnosticosPeriodo >= 999999;

  String get limiteTexto {
    if (isDiagnosticoIlimitado) return 'Diagnósticos ilimitados';
    final periodo = periodoDiagnostico == 'SEMANA' ? 'semana' : 'mês';
    return '$maxDiagnosticosPeriodo diagnósticos por $periodo';
  }

  String get precoTexto {
    if (isFree) return 'Grátis';
    return 'R\$ ${precoMensal.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}