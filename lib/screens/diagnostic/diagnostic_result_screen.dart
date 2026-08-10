import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/diagnostic_service.dart';
import '../../services/auth_storage.dart';

class DiagnosticResultScreen extends StatefulWidget {
  const DiagnosticResultScreen({super.key});

  @override
  State<DiagnosticResultScreen> createState() => _DiagnosticResultScreenState();
}

class _DiagnosticResultScreenState extends State<DiagnosticResultScreen> {
  // ---------------------------------------------------------------------------
  // Regex de parsing (estáticas: compiladas uma única vez)
  // ---------------------------------------------------------------------------

  /// Cabeçalho em negrito. Aceita: **Título**, **Título:**, ## **Título**
  static final RegExp _kHeaderBold =
      RegExp(r'^\s*#{0,6}\s*\*{1,2}\s*([^*\n]+?)\s*:?\s*\*{1,2}\s*:?\s*$');

  /// Cabeçalho markdown puro: ## Título
  static final RegExp _kHeaderHash = RegExp(r'^\s*#{1,6}\s+([^#\n]+?)\s*:?\s*$');

  /// Lista numerada: "1. texto" ou "1) texto"
  static final RegExp _kNumbered = RegExp(r'^\s*(\d+)[.)]\s+(.+)$');

  /// Bullet: "* texto", "- texto", "• texto" (indentação opcional)
  static final RegExp _kBullet = RegExp(r'^(\s*)[*\-•]\s+(.+)$');

  /// Negrito inline
  static final RegExp _kBold = RegExp(r'\*\*([^*]+)\*\*');

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _isUpdating = false;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _sections = const [];
  String _diagnosticoRaw = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data != null) return;

    _data = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _diagnosticoRaw =
        _data?['diagnostico']?.toString() ?? 'Sem diagnóstico disponível.';
    _sections = _parseDiagnosticSections(_diagnosticoRaw);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = _data;

    if (data == null) {
      return const DesktopLayout(
        currentRoute: '/diagnostic-result',
        title: '',
        showAppBar: false,
        child: Center(child: Text('Nenhum dado disponível.')),
      );
    }

    final diagnostico = _diagnosticoRaw;
    final status = data['status']?.toString() ?? 'CONCLUIDO';
    final dadosVeiculo =
        data['dadosParaDiagnostico'] as Map<String, dynamic>? ?? const {};
    final createdAt = data['createdAt']?.toString() ?? '';
    final codigo = dadosVeiculo['codigoODB2']?.toString() ?? '';
    final marca = dadosVeiculo['marcaVeiculo']?.toString() ?? '';
    final modelo = dadosVeiculo['modeloVeiculo']?.toString() ?? '';
    final ano = dadosVeiculo['anoVeiculo']?.toString() ?? '';
    final sintomas = dadosVeiculo['sintomas']?.toString() ?? '';

    return DesktopLayout(
      currentRoute: '/diagnostic-result',
      title: '',
      showAppBar: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop
            ? null
            : AppBar(
                title: const Text('Resultado'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/home');
                    }
                  },
                ),
              ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
          child: context.isDesktop
              ? _buildDesktopLayout(
                  context,
                  diagnostico,
                  status,
                  codigo,
                  marca,
                  modelo,
                  ano,
                  sintomas,
                  createdAt,
                )
              : _buildMobileLayout(
                  context,
                  diagnostico,
                  status,
                  codigo,
                  marca,
                  modelo,
                  ano,
                  sintomas,
                  createdAt,
                ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    String diagnostico,
    String status,
    String codigo,
    String marca,
    String modelo,
    String ano,
    String sintomas,
    String createdAt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resultado do Diagnóstico',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _buildStatusBanner(status),
                  const SizedBox(height: 20),
                  _buildDiagnosticCard(diagnostico),
                  const SizedBox(height: 24),
                  _buildActionButtons(context, _data!),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: _buildVehicleInfoCard(
                codigo,
                marca,
                modelo,
                ano,
                sintomas,
                createdAt,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    String diagnostico,
    String status,
    String codigo,
    String marca,
    String modelo,
    String ano,
    String sintomas,
    String createdAt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusBanner(status),
        const SizedBox(height: 16),
        _buildVehicleInfoCard(codigo, marca, modelo, ano, sintomas, createdAt),
        const SizedBox(height: 16),
        _buildDiagnosticCard(diagnostico),
        const SizedBox(height: 24),
        _buildActionButtons(context, _data!),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  Widget _buildStatusBanner(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case 'CONCLUIDO':
        bgColor = AppColors.statusResolved;
        textColor = Colors.white;
        icon = Icons.check_circle;
        label = 'Diagnóstico Concluído';
        break;
      case 'EM_ANALISE':
        bgColor = AppColors.statusPending;
        textColor = Colors.black87;
        icon = Icons.hourglass_top;
        label = 'Em Análise';
        break;
      case 'PENDENTE':
        bgColor = AppColors.statusPending;
        textColor = Colors.black87;
        icon = Icons.schedule;
        label = 'Pendente';
        break;
      case 'INCONCLUSIVO':
        bgColor = AppColors.statusUrgent;
        textColor = Colors.white;
        icon = Icons.help_outline;
        label = 'Inconclusivo';
        break;
      default:
        bgColor = AppColors.statusResolved;
        textColor = Colors.white;
        icon = Icons.check_circle;
        label = 'Concluído';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card do diagnóstico
  // ---------------------------------------------------------------------------

  Widget _buildDiagnosticCard(String diagnostico) {
    final sections = _sections;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.lightRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Diagnóstico da IA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (sections.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.iconBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  diagnostico,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              )
            else
              ...sections.map(_buildDiagnosticSection),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Parser
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _sectionStyle(String title) {
    final t = title.toLowerCase();

    if (t.contains('risco') || t.contains('gravidade')) {
      return {'icon': Icons.warning_amber, 'color': const Color(0xFFFFA000)};
    }
    if (t.contains('diagn')) {
      return {'icon': Icons.medical_information, 'color': AppColors.primaryRed};
    }
    if (t.contains('causa') || t.contains('poss')) {
      return {'icon': Icons.search, 'color': const Color(0xFFE64A19)};
    }
    if (t.contains('recomend') ||
        t.contains('procedimento') ||
        t.contains('repar')) {
      return {'icon': Icons.build, 'color': const Color(0xFF1976D2)};
    }
    return {'icon': Icons.info_outline, 'color': const Color(0xFF7B1FA2)};
  }

  /// Divide o texto em seções delimitadas por cabeçalho.
  ///
  /// Conteúdo anterior ao primeiro cabeçalho é preservado como seção sem
  /// título (em vez de descartado). Se nenhum cabeçalho for reconhecido,
  /// retorna lista vazia para acionar o fallback de texto cru.
  static List<Map<String, dynamic>> _parseDiagnosticSections(String text) {
    final sections = <Map<String, dynamic>>[];
    final buffer = <String>[];
    String? currentTitle;

    void flush() {
      final content = buffer.join('\n').trim();
      buffer.clear();
      if (currentTitle == null && content.isEmpty) return;
      final title = currentTitle ?? '';
      sections.add({
        'title': title,
        'content': content,
        ..._sectionStyle(title),
      });
    }

    for (final line in text.split('\n')) {
      final m = _kHeaderBold.firstMatch(line) ?? _kHeaderHash.firstMatch(line);
      if (m != null) {
        flush();
        currentTitle = m.group(1)!.trim();
      } else {
        buffer.add(line);
      }
    }
    flush();

    final semCabecalho =
        sections.length == 1 && (sections.first['title'] as String).isEmpty;
    return semCabecalho ? const [] : sections;
  }

  Widget _buildDiagnosticSection(Map<String, dynamic> section) {
    final title = section['title'] as String;
    final content = section['content'] as String;
    final icon = section['icon'] as IconData;
    final color = section['color'] as Color;
    final isRisco = title.toLowerCase().contains('risco');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                if (isRisco) _buildRiskBadge(content),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildMarkdownContent(content, color),
        ],
      ),
    );
  }

  /// Renderiza listas numeradas, bullets e negrito inline.
  Widget _buildMarkdownContent(String content, Color accentColor) {
    final widgets = <Widget>[];

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;

      // 1. Bullet (indentação opcional)
      final bulletMatch = _kBullet.firstMatch(line);
      if (bulletMatch != null) {
        final indentLen = bulletMatch.group(1)!.length;
        final leftPad = indentLen >= 5 ? 32.0 : 16.0;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: leftPad, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildRichText(bulletMatch.group(2)!, 13)),
              ],
            ),
          ),
        );
        continue;
      }

      // 2. Lista numerada
      final numberedMatch = _kNumbered.firstMatch(line);
      if (numberedMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${numberedMatch.group(1)}.  ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    fontSize: 14,
                  ),
                ),
                Expanded(child: _buildRichText(numberedMatch.group(2)!, 14)),
              ],
            ),
          ),
        );
        continue;
      }

      // 3. Parágrafo
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildRichText(line.trim(), 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Converte **bold** em TextSpan negrito.
  Widget _buildRichText(String text, double fontSize) {
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in _kBold.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  /// Avalia apenas a primeira linha não-vazia para evitar falso positivo
  /// causado por palavras como "alto" no texto de justificativa.
  Widget _buildRiskBadge(String content) {
    final firstLine = content
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
        .replaceAll('*', '')
        .toLowerCase();

    Color badgeColor;
    String label;

    if (firstLine.contains('crític') || firstLine.contains('critic')) {
      badgeColor = AppColors.statusUrgent;
      label = 'Crítico';
    } else if (firstLine.contains('médio a alto') ||
        firstLine.contains('medio a alto')) {
      badgeColor = const Color(0xFFE64A19);
      label = 'Médio-Alto';
    } else if (firstLine.contains('alto') || firstLine.contains('grave')) {
      badgeColor = AppColors.statusUrgent;
      label = 'Alto';
    } else if (firstLine.contains('médio') ||
        firstLine.contains('medio') ||
        firstLine.contains('moderado')) {
      badgeColor = AppColors.statusPending;
      label = 'Médio';
    } else {
      badgeColor = AppColors.statusResolved;
      label = 'Baixo';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dados do veículo
  // ---------------------------------------------------------------------------

  Widget _buildVehicleInfoCard(
    String codigo,
    String marca,
    String modelo,
    String ano,
    String sintomas,
    String createdAt,
  ) {
    return Card(
      color: AppColors.lightRed,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Dados do Veículo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (codigo.isNotEmpty) _buildInfoRow('Código OBD2', codigo),
            if (marca.isNotEmpty || modelo.isNotEmpty)
              _buildInfoRow('Veículo', '$marca $modelo'.trim()),
            if (ano.isNotEmpty) _buildInfoRow('Ano', ano),
            if (sintomas.isNotEmpty) _buildInfoRow('Sintomas', sintomas),
            if (createdAt.isNotEmpty)
              _buildInfoRow('Data', _formatDate(createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/${dt.year} $h:$min';
    } catch (_) {
      return isoDate;
    }
  }

  // ---------------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------------

  Future<void> _marcarComoConcluido(Map<String, dynamic> data) async {
    setState(() => _isUpdating = true);

    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão expirada. Faça login novamente.'),
          ),
        );
        setState(() => _isUpdating = false);
        return;
      }

      final diagnosticoId = data['id']?.toString() ?? '';
      final diagnosticoTexto = data['diagnostico']?.toString() ?? '';
      final dadosVeiculo =
          data['dadosParaDiagnostico'] as Map<String, dynamic>? ?? const {};
      final dadosId = dadosVeiculo['id']?.toString() ?? '';

      if (diagnosticoId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID do diagnóstico não encontrado.')),
        );
        setState(() => _isUpdating = false);
        return;
      }

      final result = await DiagnosticService.atualizarDiagnostico(
        token: token,
        diagnosticoId: diagnosticoId,
        diagnostico: diagnosticoTexto,
        status: 'CONCLUIDO',
        dadosParaDiagnosticoId: dadosId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Diagnóstico marcado como concluído!',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.statusResolved,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ??
                'Erro ao atualizar status.'),
            backgroundColor: AppColors.statusUrgent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.statusUrgent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> data) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUpdating ? null : () => _marcarComoConcluido(data),
            icon: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, color: Colors.white),
            label: Text(
              _isUpdating
                  ? 'Atualizando...'
                  : 'Funcionou! Resolveu meu problema',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusResolved,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isUpdating
                ? null
                : () {
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: {
                        'diagnosticoId': data['id']?.toString() ?? '',
                        'diagnosticoTexto': _diagnosticoRaw,
                      },
                    );
                  },
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.primaryRed,
            ),
            label: const Text(
              'Continuar no Chat',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryRed,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryRed, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}