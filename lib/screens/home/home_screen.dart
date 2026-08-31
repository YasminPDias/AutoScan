import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/auth_storage.dart';
import '../../services/diagnostic_service.dart';
import '../../services/logger_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  String _userRole = '';
  List<dynamic> _chamadosAbertos = [];
  bool _isLoadingChamados = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _carregarChamadosAbertos();
  }

  Future<void> _loadUserData() async {
    final name = await AuthStorage.getUserName();
    final role = await AuthStorage.getUserRole();
    if (!mounted) return;
    setState(() {
      _userName = name?.trim() ?? '';
      _userRole = role?.trim() ?? '';
    });
  }

  Future<void> _carregarChamadosAbertos() async {
    setState(() => _isLoadingChamados = true);
    _token = await AuthStorage.getToken();

    if (_token == null || _token!.isEmpty) {
      if (mounted) setState(() => _isLoadingChamados = false);
      return;
    }

    try {
      final res = await DiagnosticService.buscarMeusDiagnosticosAbertos(token: _token!);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _chamadosAbertos = (res['data'] as List).cast<dynamic>();
          _isLoadingChamados = false;
        });
      } else {
        setState(() => _isLoadingChamados = false);
      }
    } catch (e) {
      loggerService.e('Erro ao carregar chamados em aberto na Home: $e');
      if (mounted) setState(() => _isLoadingChamados = false);
    }
  }

  String get _welcomeTitle {
    if (_userName.isEmpty) return 'Bem-vindo ao AutoScan';
    final firstName = _userName.split(' ').first.trim();
    return firstName.isEmpty ? 'Bem-vindo ao AutoScan' : 'Bem-vindo, $firstName';
  }

  void _abrirSuporteEsquema(BuildContext context) {
    final role = _userRole.trim().toUpperCase();
    if (role == 'ADMIN' || role == 'ASSISTENTE') {
      Navigator.pushNamed(
        context,
        '/chat-history',
        arguments: const {'tipo': 'ESQUEMA_ELETRICO'},
      );
    } else {
      Navigator.pushNamed(context, '/minhas-solicitacoes');
    }
  }

  void _abrirChatDoChamado(Map<String, dynamic> item) {
    final diagnosticoId = item['id']?.toString();
    final conversa = item['conversa'] as Map<String, dynamic>?;
    final conversaId = conversa?['id']?.toString();

    if (conversaId != null && conversaId.isNotEmpty) {
      Navigator.pushNamed(context, '/chat', arguments: {'conversaId': conversaId});
    } else if (diagnosticoId != null && diagnosticoId.isNotEmpty) {
      final diagnosticoTexto = item['diagnostico']?.toString();
      Navigator.pushNamed(context, '/chat', arguments: {
        'diagnosticoId': diagnosticoId,
        'diagnosticoTexto': diagnosticoTexto,
      });
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFFF3E0);
    Color fg = const Color(0xFFE65100);
    String label = 'PENDENTE';

    switch (status.toUpperCase()) {
      case 'EM_ANALISE':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        label = 'EM ANÁLISE';
        break;
      case 'PENDENTE':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        label = 'PENDENTE';
        break;
      case 'CONCLUIDO':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'CONCLUÍDO';
        break;
      default:
        label = status;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildChamadosAbertosSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 24,
              decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Chamados & Conversas em Aberto',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _carregarChamadosAbertos,
              tooltip: 'Atualizar chamados',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingChamados)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            ),
          )
        else if (_chamadosAbertos.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.lightRed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle_outline, color: AppColors.primaryRed, size: 26),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nenhum chamado em aberto no momento',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Precisa de ajuda com o seu veículo? Inicie um novo diagnóstico inteligente.',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/diagnostic'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Novo Diagnóstico', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chamadosAbertos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _chamadosAbertos[index] as Map<String, dynamic>;
              final status = item['status']?.toString() ?? 'PENDENTE';
              final dados = item['dadosParaDiagnostico'] as Map<String, dynamic>? ?? {};
              final veiculo = '${dados['marcaVeiculo'] ?? ''} ${dados['modeloVeiculo'] ?? ''}'.trim();
              final ano = dados['anoVeiculo']?.toString() ?? '';
              final sintomas = dados['sintomas']?.toString() ?? 'Sem descrição de sintomas';
              final codObd = dados['codigoODB2']?.toString() ?? '';

              final tituloVeiculo = veiculo.isNotEmpty ? (ano.isNotEmpty ? '$veiculo ($ano)' : veiculo) : 'Veículo não informado';
              final isDesktop = context.isDesktop;

              return Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: InkWell(
                  onTap: () => _abrirChatDoChamado(item),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 20 : 16),
                    child: isDesktop
                        ? Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.forum_outlined, color: Color(0xFF1976D2), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          tituloVeiculo,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        _buildStatusBadge(status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      codObd.isNotEmpty
                                          ? 'Código OBD: $codObd  •  Sintomas: $sintomas'
                                          : 'Sintomas: $sintomas',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: () => _abrirChatDoChamado(item),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1976D2),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.chat_bubble, size: 16, color: Colors.white),
                                label: const Text('Abrir Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.forum_outlined, color: Color(0xFF1976D2), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              tituloVeiculo,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            _buildStatusBadge(status),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          codObd.isNotEmpty
                                              ? 'Código OBD: $codObd | Sintomas: $sintomas'
                                              : 'Sintomas: $sintomas',
                                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _abrirChatDoChamado(item),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1976D2),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.chat_bubble, size: 16, color: Colors.white),
                                  label: const Text('Abrir Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/home',
      title: context.isDesktop ? '' : 'Home',
      showAppBar: !context.isDesktop,
      child: Container(
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.isDesktop ? 32 : 20),
          child: context.isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryRed, Color(0xFFB71C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primaryRed.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.directions_car_rounded, size: 70, color: Colors.white),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _welcomeTitle,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sistema Profissional de Diagnóstico Automotivo',
                          style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.95), fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildStatBadge('1000+', 'Diagnósticos'),
                            const SizedBox(width: 24),
                            _buildStatBadge('24/7', 'Suporte'),
                            const SizedBox(width: 24),
                            _buildStatBadge('IA', 'Avançada'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildChamadosAbertosSection(context),
        const SizedBox(height: 40),
        Row(
          children: [
            Container(width: 4, height: 24, decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            const Text('Recursos Principais', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 28),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.4,
          children: [
            _buildEnhancedFeatureCard(icon: Icons.analytics_outlined, title: 'Diagnóstico Inteligente', description: 'Análise completa e precisa do seu veículo', color: AppColors.primaryRed, onTap: () => Navigator.pushNamed(context, '/diagnostic')),
            _buildEnhancedFeatureCard(icon: Icons.electrical_services_outlined, title: 'Suporte a Esquema Elétrico', description: 'Solicite diagramas ou suporte para esquema elétrico', color: const Color(0xFFFF8F00), onTap: () => _abrirSuporteEsquema(context)),
            _buildEnhancedFeatureCard(icon: Icons.description_outlined, title: 'Planos e Assinaturas', description: 'Conheça nossos planos', color: const Color(0xFF388E3C), onTap: () => Navigator.pushNamed(context, '/plans')),
            _buildEnhancedFeatureCard(icon: Icons.history, title: 'Histórico Completo', description: 'Acesse todos os diagnósticos', color: const Color(0xFFE64A19), onTap: () => Navigator.pushNamed(context, '/history')),
            if (_userRole.trim().toUpperCase() == 'ADMIN') ...[
              _buildEnhancedFeatureCard(
                icon: Icons.trending_up,
                title: 'Relatórios Detalhados',
                description: 'Análises e estatísticas',
                color: const Color(0xFF00796B),
                onTap: () => Navigator.pushNamed(context, '/admin/users'),
              ),
              _buildEnhancedFeatureCard(
                icon: Icons.manage_accounts_outlined,
                title: 'Gestão do Sistema',
                description: 'Painel administrativo',
                color: const Color(0xFFE53935),
                onTap: () => Navigator.pushNamed(context, '/admin/users'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final role = _userRole.trim().toUpperCase();
    final isAdmin = role == 'ADMIN';
    final isAssistente = role == 'ASSISTENTE';
    final isAdminEmpresa = role == 'ADMIN_EMPRESA';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                ),
                child: const Icon(Icons.directions_car, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                _welcomeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sistema Profissional de Diagnóstico Automotivo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildChamadosAbertosSection(context),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primaryRed, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            const Text('Recursos Principais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 16),
        _buildEnhancedFeatureCard(
          icon: Icons.analytics_outlined,
          title: 'Diagnóstico Inteligente',
          description: 'Análise completa e precisa do seu veículo com tecnologia avançada',
          color: AppColors.primaryRed,
          onTap: () => Navigator.pushNamed(context, '/diagnostic'),
        ),
        const SizedBox(height: 12),
        _buildEnhancedFeatureCard(
          icon: Icons.electrical_services_outlined,
          title: 'Suporte a Esquema Elétrico',
          description: 'Solicite o diagrama ou suporte técnico',
          color: const Color(0xFFFF8F00),
          onTap: () => _abrirSuporteEsquema(context),
        ),
        const SizedBox(height: 12),
        _buildEnhancedFeatureCard(
          icon: Icons.history,
          title: 'Histórico Completo',
          description: 'Acesse todos os diagnósticos',
          color: const Color(0xFFE64A19),
          onTap: () => Navigator.pushNamed(context, '/history'),
        ),
        const SizedBox(height: 12),
        _buildEnhancedFeatureCard(
          icon: Icons.description_outlined,
          title: 'Planos e Assinaturas',
          description: 'Conheça nossos planos',
          color: const Color(0xFF388E3C),
          onTap: () => Navigator.pushNamed(context, '/plans'),
        ),
        if (isAdmin || isAssistente) ...[
          const SizedBox(height: 12),
          _buildEnhancedFeatureCard(
            icon: Icons.support_agent_outlined,
            title: 'Atendimentos',
            description: 'Gerenciar chamados em aberto',
            color: const Color(0xFF1976D2),
            onTap: () => Navigator.pushNamed(context, '/chat-history'),
          ),
        ],
        if (isAdminEmpresa) ...[
          const SizedBox(height: 12),
          _buildEnhancedFeatureCard(
            icon: Icons.business_outlined,
            title: 'Minha Empresa',
            description: 'Gerenciar funcionários e dados',
            color: const Color(0xFF7B1FA2),
            onTap: () => Navigator.pushNamed(context, '/empresa/funcionarios'),
          ),
        ],
        if (isAdmin) ...[
          const SizedBox(height: 12),
          _buildEnhancedFeatureCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Gestão do Sistema',
            description: 'Painel administrativo',
            color: const Color(0xFFE53935),
            onTap: () => Navigator.pushNamed(context, '/admin/users'),
          ),
        ],
      ],
    );
  }

  Widget _buildStatBadge(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _buildEnhancedFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
