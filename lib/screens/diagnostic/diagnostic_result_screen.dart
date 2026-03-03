import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/diagnostic_service.dart';
import '../../services/auth_storage.dart';
import '../../services/logger_service.dart';

class DiagnosticResultScreen extends StatefulWidget {
  const DiagnosticResultScreen({super.key});

  @override
  State<DiagnosticResultScreen> createState() => _DiagnosticResultScreenState();
}

class _DiagnosticResultScreenState extends State<DiagnosticResultScreen> {
  bool _isUpdating = false;
  Map<String, dynamic>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    if (data == null) {
      return DesktopLayout(
        currentRoute: '/diagnostic-result',
        title: '',
        showAppBar: false,
        child: const Center(child: Text('Nenhum dado disponível.')),
      );
    }

    final diagnostico = data['diagnostico'] ?? 'Sem diagnóstico disponível.';
    final status = data['status'] ?? 'CONCLUIDO';
    final dadosVeiculo =
        data['dadosParaDiagnostico'] as Map<String, dynamic>? ?? {};
    final createdAt = data['createdAt'] ?? '';

    final codigo = dadosVeiculo['codigoODB2'] ?? '';
    final marca = dadosVeiculo['marcaVeiculo'] ?? '';
    final modelo = dadosVeiculo['modeloVeiculo'] ?? '';
    final ano = dadosVeiculo['anoVeiculo']?.toString() ?? '';
    final sintomas = dadosVeiculo['sintomas'] ?? '';

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
                  onPressed: () => Navigator.pop(context),
                ),
              ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
          child: context.isDesktop
              ? _buildDesktopLayout(context, diagnostico, status, codigo,
                  marca, modelo, ano, sintomas, createdAt)
              : _buildMobileLayout(context, diagnostico, status, codigo, marca,
                  modelo, ano, sintomas, createdAt),
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
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Voltar',
            ),
            const SizedBox(width: 8),
            const Text(
              'Resultado do Diagnóstico',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
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
                  codigo, marca, modelo, ano, sintomas, createdAt),
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

  Widget _buildDiagnosticCard(String diagnostico) {
    final sections = _parseDiagnosticSections(diagnostico);
    // DEBUG temporário — remover depois
    loggerService.d('DIAGNÓSTICO RAW (primeiros 200 chars): ${diagnostico.substring(0, diagnostico.length.clamp(0, 200))}');
    loggerService.d('SEÇÕES ENCONTRADAS: ${sections.length}');

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
              ...sections.map((section) => _buildDiagnosticSection(section)),
          ],
        ),
      ),
    );
  }

  /// Detecta seções  **Título**.
  List<Map<String, dynamic>> _parseDiagnosticSections(String text) {
    Map<String, dynamic> _sectionStyle(String title) {
      final t = title.toLowerCase();
      if (t.contains('diagn')) {
        return {'icon': Icons.medical_information, 'color': AppColors.primaryRed};
      } else if (t.contains('causa') || t.contains('poss')) {
        return {'icon': Icons.search, 'color': const Color(0xFFE64A19)};
      } else if (t.contains('recomend')) {
        return {'icon': Icons.build, 'color': const Color(0xFF1976D2)};
      // } 
      // else if (t.contains('risco')) {
      //   return {'icon': Icons.warning_amber, 'color': const Color(0xFFFFA000)};
      } else {
        return {'icon': Icons.info_outline, 'color': const Color(0xFF7B1FA2)};
      }
    }

    // Reconhece uma linha que é APENAS **Título** (sem ':' no final)
    final headerLine = RegExp(r'^\s*\*\*([^*:][^*]*[^*:]?)\*\*\s*$');

    final lines = text.split('\n');
    final List<Map<String, dynamic>> sections = [];
    String? currentTitle;
    Map<String, dynamic>? currentStyle;
    final List<String> currentLines = [];

    void flush() {
      if (currentTitle != null) {
        sections.add({
          'title': currentTitle!,
          'content': currentLines.join('\n').trim(),
          ...currentStyle!,
        });
        currentLines.clear();
      }
    }

    for (final line in lines) {
      final m = headerLine.firstMatch(line);
      if (m != null) {
        flush();
        currentTitle = m.group(1)!.trim();
        currentStyle = _sectionStyle(currentTitle!);
      } else if (currentTitle != null) {
        currentLines.add(line);
      }
    }
    flush();

    loggerService.d('SEÇÕES: ${sections.map((s) => s["title"]).toList()}');
    return sections;
  }

  Widget _buildDiagnosticSection(Map<String, dynamic> section) {
    final title = section['title'] as String;
    final content = section['content'] as String;
    final icon = section['icon'] as IconData;
    final color = section['color'] as Color;

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
            //  if (title == 'Nível de Risco') _buildRiskBadge(content),
            ],
          ),
          const SizedBox(height: 12),
          _buildMarkdownContent(content, color),
        ],
      ),
    );
  }

  /// Renderiza conteúdo com listas numeradas, sub-bullets (*) e negrito (**).
  Widget _buildMarkdownContent(String content, Color accentColor) {
    final lines = content.split('\n');
    final List<Widget> widgets = [];

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;

      // 1. Lista numerada: "1.  texto"
      final numberedMatch =
          RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(line.trim());
      if (numberedMatch != null) {
        final number = numberedMatch.group(1)!;
        final itemText = numberedMatch.group(2)!;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number.  ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  fontSize: 14,
                ),
              ),
              Expanded(child: _buildRichText(itemText, 14)),
            ],
          ),
        ));
        continue;
      }

      // 2. Sub-bullet indentado: "    *   texto"
      final bulletMatch = RegExp(r'^(\s+)\*\s+(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        final indentLen = bulletMatch.group(1)!.length;
        final bulletText = bulletMatch.group(2)!;
        final leftPad = indentLen <= 4 ? 16.0 : 32.0;
        widgets.add(Padding(
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
              Expanded(child: _buildRichText(bulletText, 13)),
            ],
          ),
        ));
        continue;
      }

      // 3. Parágrafo normal
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _buildRichText(line.trim(), 14),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Converte **bold** em TextSpan negrito
  Widget _buildRichText(String text, double fontSize) {
    final boldPattern = RegExp(r'\*\*([^*]+)\*\*');
    final List<TextSpan> spans = [];
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
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

  Widget _buildRiskBadge(String content) {
    final lower = content.toLowerCase();
    Color badgeColor;
    String label;

    if (lower.contains('médio a alto') || lower.contains('medio a alto')) {
      badgeColor = const Color(0xFFE64A19);
      label = 'Médio-Alto';
    } else if (lower.contains('alto') ||
        lower.contains('crítico') ||
        lower.contains('grave')) {
      badgeColor = AppColors.statusUrgent;
      label = 'Alto';
    } else if (lower.contains('médio') || lower.contains('moderado')) {
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
                Icon(Icons.directions_car, color: AppColors.primaryRed, size: 20),
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
            if (createdAt.isNotEmpty) _buildInfoRow('Data', _formatDate(createdAt)),
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
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _marcarComoConcluido(Map<String, dynamic> data) async {
    setState(() => _isUpdating = true);

    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
        );
        setState(() => _isUpdating = false);
        return;
      }

      final diagnosticoId = data['id']?.toString() ?? '';
      final diagnosticoTexto = data['diagnostico'] ?? '';
      final dadosVeiculo = data['dadosParaDiagnostico'] as Map<String, dynamic>? ?? {};
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
            content: Text(result['message'] ?? 'Erro ao atualizar status.'),
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
    final diagnostico = data['diagnostico'] ?? '';

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
              _isUpdating ? 'Atualizando...' : 'Funcionou! Resolveu meu problema',
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
            onPressed: _isUpdating ? null : () {
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {'diagnostico': diagnostico},
              );
            },
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primaryRed),
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
