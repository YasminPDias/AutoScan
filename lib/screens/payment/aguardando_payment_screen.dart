import 'dart:async';
import 'package:autex/models/resultado_assinatura.dart';
import 'package:autex/services/auth_storage.dart';
import 'package:autex/services/payment/pagamento_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';

/// Tela de "falta pagar".
///
/// Fecha com `true` quando o pagamento é confirmado — a tela de pagamento
/// usa isso para seguir adiante.
class AguardandoPagamentoScreen extends StatefulWidget {
  const AguardandoPagamentoScreen({
    super.key,
    required this.resultado,
    this.empresaId,
  });

  final ResultadoAssinatura resultado;
  final String? empresaId;

  @override
  State<AguardandoPagamentoScreen> createState() => _AguardandoPagamentoScreenState();
}

class _AguardandoPagamentoScreenState extends State<AguardandoPagamentoScreen> {
  Timer? _polling;
  Timer? _contador;
  Duration? _restante;
  bool _verificando = false;
  bool _copiado = false;

  ResultadoAssinatura get r => widget.resultado;
  bool get _ehPix => r.metodoPagamento == MetodoPagamento.pix;

  @override
  void initState() {
    super.initState();
    _iniciarContador();
    _iniciarPolling();
  }

  @override
  void dispose() {
    // Sem isto os timers continuam rodando depois da tela fechar e o
    // setState dispara em widget desmontado.
    _polling?.cancel();
    _contador?.cancel();
    super.dispose();
  }

  void _iniciarContador() {
    final expira = r.expiraEm;
    if (expira == null) return;

    void tick() {
      final falta = expira.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _restante = falta.isNegative ? Duration.zero : falta);
      if (falta.isNegative) _contador?.cancel();
    }

    tick();
    _contador = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Pix compensa em segundos, então vale checar de perto. Boleto leva dias:
  /// o polling só serve para o caso de o cliente ficar com a tela aberta
  /// enquanto paga, e um intervalo maior evita torrar bateria à toa.
  void _iniciarPolling() {
    final intervalo = _ehPix ? const Duration(seconds: 3) : const Duration(seconds: 15);
    _polling = Timer.periodic(intervalo, (_) => _verificar(silencioso: true));
  }

  Future<void> _verificar({bool silencioso = false}) async {
    if (_verificando) return;
    _verificando = true;

    try {
      final token = await AuthStorage.getToken();
      if (token == null || !mounted) return;

      final res = await PagamentoService.consultarStatus(
        token: token,
        empresaId: widget.empresaId,
      );
      if (!mounted) return;

      if (res['success'] == true) {
        final status = res['status'] as StatusPagamento;
        if (status.temAcesso) {
          _polling?.cancel();
          _contador?.cancel();
          Navigator.pop(context, true);
          return;
        }
        if (!silencioso) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ainda não identificamos o pagamento'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      _verificando = false;
    }
  }

  Future<void> _copiar(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    setState(() => _copiado = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado — cole no app do seu banco'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  Future<void> _abrirLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatarRestante(Duration d) {
    if (d.inHours >= 24) return 'Vence em ${d.inDays} dia${d.inDays > 1 ? 's' : ''}';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? 'Expira em $h:$m:$s' : 'Expira em $m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final expirou = _restante == Duration.zero;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_ehPix ? 'Pague com PIX' : 'Seu boleto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCabecalho(expirou),
                const SizedBox(height: 24),
                if (expirou) _buildExpirado() else ..._buildConteudo(),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Continuar depois',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCabecalho(bool expirou) {
    return Column(
      children: [
        Icon(
          expirou ? Icons.error_outline : Icons.schedule,
          color: expirou ? AppColors.primaryRed : const Color(0xFFF9A825),
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          expirou
              ? 'Esta cobrança expirou'
              : _ehPix
                  ? 'Falta pagar o PIX'
                  : 'Falta pagar o boleto',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        if (!expirou && _restante != null) ...[
          const SizedBox(height: 6),
          Text(_formatarRestante(_restante!),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildExpirado() {
    return Column(
      children: [
        const Text(
          'Volte à tela anterior e gere uma nova cobrança.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, false),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Gerar nova cobrança',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  List<Widget> _buildConteudo() {
    final codigo = _ehPix ? r.pix?.copiaECola : r.boleto?.linhaDigitavel;
    final link = r.linkCobranca;

    return [
      if (codigo != null) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_ehPix ? 'PIX copia e cola' : 'Linha digitável',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              SelectableText(
                codigo,
                maxLines: 3,
                style: const TextStyle(fontSize: 13, height: 1.4, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // O botão de copiar é o que converte no celular. QR code na tela do
        // próprio aparelho é inútil: o cliente não tem como escanear.
        ElevatedButton.icon(
          onPressed: () => _copiar(codigo),
          icon: Icon(_copiado ? Icons.check : Icons.copy, color: Colors.white),
          label: Text(_copiado ? 'Copiado!' : 'Copiar código',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _copiado ? const Color(0xFF388E3C) : AppColors.primaryRed,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
      if (link != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _abrirLink(link),
          icon: const Icon(Icons.open_in_new, color: AppColors.primaryRed),
          label: Text(_ehPix ? 'Abrir instruções' : 'Abrir boleto em PDF',
              style: const TextStyle(color: AppColors.primaryRed)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primaryRed),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 10),
          Text(
            _ehPix
                ? 'Aguardando confirmação...'
                : 'Boletos compensam em até 2 dias úteis',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => _verificar(),
        child: const Text('Já paguei, verificar agora',
            style: TextStyle(color: AppColors.primaryRed)),
      ),
    ];
  }
}