import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../widgets_defaults/diagnostic_item.dart';
import '../../services/diagnostic_service.dart';
import '../../services/auth_storage.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _diagnosticItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sessão expirada. Faça login novamente.';
        });
        return;
      }

      final result = await DiagnosticService.buscarMeuHistorico(token: token);

      if (!mounted) return;

      if (result['success'] == true) {
        final List data = result['data'] as List;
        setState(() {
          _diagnosticItems = data.map((item) {
            final dados = item['dadosParaDiagnostico'] as Map<String, dynamic>? ?? {};
            final codigo = dados['codigoODB2'] ?? '';
            final marca = dados['marcaVeiculo'] ?? '';
            final modelo = dados['modeloVeiculo'] ?? '';
            final ano = dados['anoVeiculo']?.toString() ?? '';
            final createdAt = item['createdAt'] ?? '';
            final status = item['status'] ?? 'PENDENTE';

            DiagnosticStatus diagStatus;
            switch (status) {
              case 'CONCLUIDO':
                diagStatus = DiagnosticStatus.resolved;
                break;
              case 'PENDENTE':
              case 'EM_ANALISE':
                diagStatus = DiagnosticStatus.pending;
                break;
              case 'INCONCLUSIVO':
                diagStatus = DiagnosticStatus.urgent;
                break;
              default:
                diagStatus = DiagnosticStatus.pending;
            }

            return {
              'code': codigo,
              'vehicle': '$marca $modelo $ano'.trim(),
              'date': _formatDate(createdAt),
              'status': diagStatus,
              'fullData': item,
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'] ?? 'Erro ao carregar histórico.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro de conexão: $e';
      });
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/history',
      title: '',
      showAppBar: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop
            ? null
            : AppBar(
                title: const Text('Histórico'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryRed),
                    SizedBox(height: 16),
                    Text(
                      'Carregando histórico...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadHistory,
                color: AppColors.primaryRed,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Histórico Completo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadHistory,
                            tooltip: 'Atualizar',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryRed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.primaryRed, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _loadHistory,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else if (_diagnosticItems.isEmpty) ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 64,
                                  color: AppColors.textLight,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Nenhum diagnóstico encontrado',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Seus diagnósticos aparecerão aqui após serem processados.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/diagnostic');
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Novo Diagnóstico'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          '${_diagnosticItems.length} diagnóstico(s) encontrado(s)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        context.isDesktop
                            ? GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 4.0,
                                ),
                                itemCount: _diagnosticItems.length,
                                itemBuilder: (context, index) {
                                  final item = _diagnosticItems[index];
                                  return DiagnosticItem(
                                    code: 'Código: ${item['code']}',
                                    vehicle: item['vehicle'] as String,
                                    date: item['date'] as String,
                                    status: item['status'] as DiagnosticStatus,
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/diagnostic-result',
                                        arguments: item['fullData'],
                                      );
                                    },
                                  );
                                },
                              )
                            : Column(
                                children: _diagnosticItems.map((item) {
                                  return DiagnosticItem(
                                    code: 'Código: ${item['code']}',
                                    vehicle: item['vehicle'] as String,
                                    date: item['date'] as String,
                                    status: item['status'] as DiagnosticStatus,
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/diagnostic-result',
                                        arguments: item['fullData'],
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
