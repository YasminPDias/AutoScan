import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../layouts/desktop_layout.dart';
import '../utils/responsive.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String userType = 'mecanico';
  bool roadAssistance = false;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();

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
        // Header
        const Text(
          'Novo Diagnóstico',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 32),
        
        // 2 Column Layout
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column - Form
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
                  CustomButton(
                    text: 'Gerar Diagnóstico',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            
            // Right Column - Preview & Tips
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
        // Info banner
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
        const SizedBox(height: 24),
        
        _buildCodeCard(),
        const SizedBox(height: 16),
        _buildVehicleCard(),
        const SizedBox(height: 16),
        _buildInfoCard(),
        const SizedBox(height: 24),
        
        CustomButton(
          text: 'Gerar diagnóstico',
          onPressed: () {},
        ),
      ],
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
            
            // Grid 2x2 for desktop
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
                    value: 'mecanico',
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
                    value: 'proprietario',
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
                userType == 'mecanico' ? 'Mecânico' : 'Proprietário',
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
