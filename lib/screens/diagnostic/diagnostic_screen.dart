import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../widgets_defaults/custom_button.dart';
import '../../widgets_defaults/custom_text_field.dart';
import '../../services/diagnostic_service.dart';
import '../../services/auth_storage.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String userType = 'MECANICO';
  bool roadAssistance = false;
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();

  Future<void> _submitDiagnostic() async {
    // Validate fields
    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Informe o código OBD2.');
      return;
    }
    if (_brandController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Informe a marca do veículo.');
      return;
    }
    if (_modelController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Informe o modelo do veículo.');
      return;
    }
    if (_yearController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Informe o ano do veículo.');
      return;
    }
    final ano = int.tryParse(_yearController.text.trim());
    if (ano == null) {
      setState(() => _errorMessage = 'Ano inválido. Informe um número.');
      return;
    }
    if (_symptomsController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Descreva os sintomas observados.');
      return;
    }

    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = 'Sessão expirada. Faça login novamente.');
      return;
    }

    final userId = await AuthStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      setState(() => _errorMessage = 'ID do usuário não encontrado. Faça login novamente.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await DiagnosticService.processarDiagnostico(
        token: token,
        codigoODB2: _codeController.text.trim(),
        marcaVeiculo: _brandController.text.trim(),
        modeloVeiculo: _modelController.text.trim(),
        anoVeiculo: ano,
        sintomas: _symptomsController.text.trim(),
        tipoSolicitante: userType,
        urgencia: roadAssistance,
        usuarioId: userId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        Navigator.pushReplacementNamed(
          context,
          '/diagnostic-result',
          arguments: data,
        );
      } else {
        setState(() => _errorMessage = result['message'] ?? 'Erro ao processar diagnóstico.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Erro de conexão: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/diagnostic',
      title: '',
      showAppBar: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop
            ? null
            : AppBar(
                title: const Text('Diagnóstico'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.person),
                    onPressed: () {},
                  ),
                ],
              ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
          child: context.isDesktop
              ? _buildDesktopLayout()
              : _buildMobileLayout(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Novo Diagnóstico',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 32),
        if (_errorMessage != null) ...[
          _buildErrorBanner(),
          const SizedBox(height: 16),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _buildCodeCard(),
                  const SizedBox(height: 20),
                  _buildVehicleCard(),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  color: AppColors.primaryRed,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Processando diagnóstico com IA...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : CustomButton(
                          text: 'Gerar Diagnóstico',
                          onPressed: _submitDiagnostic,
                        ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildPreviewCard(),
                  const SizedBox(height: 20),
                  _buildTipsCard(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.textSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Preencha os dados do Veículo para o diagnóstico',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(),
        ],
        const SizedBox(height: 24),
        _buildCodeCard(),
        const SizedBox(height: 16),
        _buildVehicleCard(),
        const SizedBox(height: 16),
        _buildInfoCard(),
        const SizedBox(height: 24),
        _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.primaryRed,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Processando diagnóstico com IA...',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : CustomButton(
                text: 'Gerar diagnóstico',
                onPressed: _submitDiagnostic,
              ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.primaryRed),
            onPressed: () => setState(() => _errorMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    Icons.code,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Dados do Código',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Código OBD2 *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _codeController,
              hintText: 'Ex: P0301',
              icon: Icons.qr_code,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    Icons.directions_car,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
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
            context.isDesktop
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Marca *',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CustomTextField(
                                  controller: _brandController,
                                  hintText: 'Ex: Toyota',
                                  icon: Icons.business,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Modelo *',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CustomTextField(
                                  controller: _modelController,
                                  hintText: 'Ex: Corolla',
                                  icon: Icons.car_rental,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ano *',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CustomTextField(
                                  controller: _yearController,
                                  hintText: 'Ex: 2020',
                                  icon: Icons.calendar_today,
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const Text(
                        'Marca *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _brandController,
                        hintText: '',
                        icon: Icons.directions_car,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Modelo *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _modelController,
                        hintText: '',
                        icon: Icons.directions_car,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ano *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _yearController,
                        hintText: '',
                        icon: Icons.calendar_today,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    Icons.description,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Informações Adicionais',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Sintomas Observados *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _symptomsController,
              maxLines: 3,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Descreva os sintomas observados...',
                filled: true,
                fillColor: AppColors.cardWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tipo de Usuário *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Mecânico'),
                    value: 'MECANICO',
                    groupValue: userType,
                    activeColor: AppColors.primaryRed,
                    onChanged: (value) {
                      setState(() {
                        userType = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Proprietário'),
                    value: 'PROPRIETARIO',
                    groupValue: userType,
                    activeColor: AppColors.primaryRed,
                    onChanged: (value) {
                      setState(() {
                        userType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text(
                'Socorro na Estrada',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Marque se estiver precisando de ajuda urgente',
                style: TextStyle(fontSize: 12),
              ),
              value: roadAssistance,
              activeColor: AppColors.primaryRed,
              onChanged: (value) {
                setState(() {
                  roadAssistance = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final hasData = _codeController.text.isNotEmpty ||
        _brandController.text.isNotEmpty ||
        _modelController.text.isNotEmpty;

    return Card(
      color: AppColors.lightRed,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.preview, color: AppColors.primaryRed, size: 20),
                SizedBox(width: 8),
                Text(
                  'Resumo do Diagnóstico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasData) ...[
              if (_codeController.text.isNotEmpty)
                _buildPreviewItem('Código', _codeController.text),
              if (_brandController.text.isNotEmpty && _modelController.text.isNotEmpty)
                _buildPreviewItem(
                  'Veículo',
                  '${_brandController.text} ${_modelController.text}${_yearController.text.isNotEmpty ? ' ${_yearController.text}' : ''}',
                ),
              _buildPreviewItem(
                'Usuário',
                userType == 'MECANICO' ? 'Mecânico' : 'Proprietário',
              ),
              _buildPreviewItem(
                'Urgência',
                roadAssistance ? 'URGENTE' : 'Normal',
                isUrgent: roadAssistance,
              ),
            ] else
              const Text(
                'Preencha os campos para ver o resumo',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value, {bool isUrgent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isUrgent ? AppColors.statusUrgent : AppColors.textSecondary,
                fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primaryRed, size: 20),
                SizedBox(width: 8),
                Text(
                  'Dicas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem('Informe o código OBD2 completo'),
            _buildTipItem('Descreva os sintomas detalhadamente'),
            _buildTipItem('Verifique se há códigos relacionados'),
            _buildTipItem('Consulte o manual do veículo'),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primaryRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
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

  @override
  void dispose() {
    _codeController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }
}
