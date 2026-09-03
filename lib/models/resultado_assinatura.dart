import 'package:flutter/material.dart';

// ─────────────────────────────── Enums ───────────────────────────────

/// Movido do payment_screen: agora o model também precisa dele.
enum MetodoPagamento { cartao, pix, boleto }

extension MetodoPagamentoX on MetodoPagamento {
  String get valorApi => switch (this) {
        MetodoPagamento.cartao => 'CARTAO',
        MetodoPagamento.pix => 'PIX',
        MetodoPagamento.boleto => 'BOLETO',
      };

  String get label => switch (this) {
        MetodoPagamento.cartao => 'Cartão',
        MetodoPagamento.pix => 'PIX',
        MetodoPagamento.boleto => 'Boleto',
      };

  IconData get icone => switch (this) {
        MetodoPagamento.cartao => Icons.credit_card,
        MetodoPagamento.pix => Icons.qr_code,
        MetodoPagamento.boleto => Icons.receipt_long,
      };

  static MetodoPagamento? deApi(String? v) => switch (v) {
        'CARTAO' => MetodoPagamento.cartao,
        'PIX' => MetodoPagamento.pix,
        'BOLETO' => MetodoPagamento.boleto,
        _ => null,
      };
}

enum StatusAssinatura { ativa, pendente, inadimplente, cancelada, desconhecido }

extension StatusAssinaturaX on StatusAssinatura {
  static StatusAssinatura deApi(String? v) => switch (v) {
        'ATIVA' => StatusAssinatura.ativa,
        'PENDENTE' => StatusAssinatura.pendente,
        'INADIMPLENTE' => StatusAssinatura.inadimplente,
        'CANCELADA' => StatusAssinatura.cancelada,
        _ => StatusAssinatura.desconhecido,
      };
}

// ────────────────────────── Dados por método ──────────────────────────

class DadosPix {
  /// String EMV — o "copia e cola". É ISTO que converte no celular; QR code
  /// na tela do próprio aparelho é inútil, o cliente não tem como escanear.
  final String copiaECola;
  final String? qrCodeUrlPng;
  final String? instrucoesUrl;
  final DateTime? expiraEm;

  const DadosPix({
    required this.copiaECola,
    this.qrCodeUrlPng,
    this.instrucoesUrl,
    this.expiraEm,
  });

  static DadosPix? deJson(Map<String, dynamic>? j) {
    if (j == null || j['copiaECola'] == null) return null;
    return DadosPix(
      copiaECola: j['copiaECola'].toString(),
      qrCodeUrlPng: j['qrCodeUrlPng']?.toString(),
      instrucoesUrl: j['instrucoesUrl']?.toString(),
      expiraEm: DateTime.tryParse(j['expiraEm']?.toString() ?? ''),
    );
  }
}

class DadosBoleto {
  final String? linhaDigitavel;
  final String? pdfUrl;
  final DateTime? vencimento;

  const DadosBoleto({this.linhaDigitavel, this.pdfUrl, this.vencimento});

  static DadosBoleto? deJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return DadosBoleto(
      linhaDigitavel: j['linhaDigitavel']?.toString(),
      pdfUrl: j['pdfUrl']?.toString(),
      vencimento: DateTime.tryParse(j['vencimento']?.toString() ?? ''),
    );
  }
}

// ─────────────────────── Resposta do /assinar ───────────────────────

class ResultadoAssinatura {
  final String assinaturaId;
  final StatusAssinatura status;
  final MetodoPagamento? metodoPagamento;

  /// Cartão parado em 3DS. Antes o backend nem devolvia isso, e o app
  /// mandava o cliente pra /home achando que tinha assinado.
  final bool requerAcao;
  final String? clientSecret;

  final DadosPix? pix;
  final DadosBoleto? boleto;
  final String? urlFatura;

  const ResultadoAssinatura({
    required this.assinaturaId,
    required this.status,
    this.metodoPagamento,
    this.requerAcao = false,
    this.clientSecret,
    this.pix,
    this.boleto,
    this.urlFatura,
  });

  factory ResultadoAssinatura.deJson(Map<String, dynamic> j) {
    return ResultadoAssinatura(
      assinaturaId: j['assinaturaId']?.toString() ?? '',
      status: StatusAssinaturaX.deApi(j['status']?.toString()),
      metodoPagamento: MetodoPagamentoX.deApi(j['metodoPagamento']?.toString()),
      requerAcao: j['requerAcao'] == true,
      clientSecret: j['clientSecret']?.toString(),
      pix: DadosPix.deJson(j['pix'] as Map<String, dynamic>?),
      boleto: DadosBoleto.deJson(j['boleto'] as Map<String, dynamic>?),
      urlFatura: j['urlFatura']?.toString(),
    );
  }

  // ── Os quatro estados que a tela precisa distinguir ──
  //
  // A versão anterior só sabia "tem urlFatura ou não", e por isso mandava
  // o cartão pra /home mesmo sem o 3DS concluído.

  bool get liberado => status == StatusAssinatura.ativa;
  bool get precisaConfirmarCartao => requerAcao && clientSecret != null;
  bool get aguardandoPagamento =>
      status == StatusAssinatura.pendente && (pix != null || boleto != null);

  /// Link pra reabrir a cobrança: PDF do boleto ou instruções do Pix.
  String? get linkCobranca => boleto?.pdfUrl ?? pix?.instrucoesUrl ?? urlFatura;

  DateTime? get expiraEm => boleto?.vencimento ?? pix?.expiraEm;
}

// ─────────────────────── Resposta do /status ───────────────────────

class StatusPagamento {
  final String? assinaturaId;
  final StatusAssinatura status;
  final bool temAcesso;
  final String? planoChave;          // ← novo
  final MetodoPagamento? metodoPagamento;
  final DateTime? proximoVencimento;
  final bool cancelamentoAgendado;
  final String? urlFatura;

  const StatusPagamento({
    this.assinaturaId,
    required this.status,
    required this.temAcesso,
    this.planoChave,                 // ← novo
    this.metodoPagamento,
    this.proximoVencimento,
    this.cancelamentoAgendado = false,
    this.urlFatura,
  });

  factory StatusPagamento.deJson(Map<String, dynamic> j) {
    return StatusPagamento(
      assinaturaId: j['assinaturaId']?.toString(),
      status: StatusAssinaturaX.deApi(j['status']?.toString()),
      temAcesso: j['temAcesso'] == true,
      planoChave: j['planoChave']?.toString(),        // ← novo
      metodoPagamento: MetodoPagamentoX.deApi(j['metodoPagamento']?.toString()),
      proximoVencimento: DateTime.tryParse(j['proximoVencimento']?.toString() ?? ''),
      cancelamentoAgendado: j['cancelamentoAgendado'] == true,
      urlFatura: j['urlFatura']?.toString(),
    );
  }
}