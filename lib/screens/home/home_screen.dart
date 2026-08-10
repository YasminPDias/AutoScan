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

  void _abrirChatDoChamado(Map<String, dynamic> item) {
    final diagnosticoId = item['id']?.toString();
    final conversa = item['conversa'] as Map<String, dynamic>?;
    final conversaId = conversa?['id']?.toString();

    if (conversaId != null && conversaId.isNotEmpty) {
      Navigator.pushNamed(context, '/chat', arguments: {'conversaId': conversaId});
    } else if (diagnosticoId != null && diagnosticoId.isNotEmpty) {
      final diagnosticoTexto = item['diagnostico']?.toString();
      Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'diagnosticoId': diagnosticoId,
          'diagnosticoTexto': diagnosticoTexto,
        },
      );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildChamadosAbertosSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Chamados & Conversas em Aberto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.primaryRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nenhum chamado em aberto',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Precisa de suporte com um veículo? Inicie um novo diagnóstico.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/diagnostic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Diagnóstico', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
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

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: Color(0xFF1976D2),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tituloVeiculo,
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
                            codObd.isNotEmpty ? 'Código OBD: $codObd | $sintomas' : sintomas,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusBadge(status),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () => _abrirChatDoChamado(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1976D2),
                            side: const BorderSide(color: Color(0xFF1976D2)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.forum, size: 14),
                          label: const Text('Abrir Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
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
          padding: EdgeInsets.all(context.isDesktop ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner Empresarial
              _buildHeroBanner(context),
              const SizedBox(height: 24),

              // Seção de Chamados Abertos
              _buildChamadosAbertosSection(context),
              const SizedBox(height: 28),

              // Seção de Recursos Principais
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recursos & Ações Rápidas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildQuickActionsGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    final isDesktop = context.isDesktop;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 36 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryRed, Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.directions_car,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _welcomeTitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 26 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AutoScan • Sistema Profissional de Diagnóstico Automotivo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildFeatureChip(Icons.memory, 'Diagnóstico IA'),
              _buildFeatureChip(Icons.speed, 'Leitura OBD2'),
              _buildFeatureChip(Icons.support_agent, 'Suporte Especializado'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final isDesktop = context.isDesktop;
    final crossCount = isDesktop ? 3 : 2;

    final actions = [
      _ActionCardData(
        icon: Icons.analytics_outlined,
        title: 'Novo Diagnóstico',
        description: 'Análise inteligente via OBD2',
        color: AppColors.primaryRed,
        route: '/diagnostic',
      ),
      _ActionCardData(
        icon: Icons.chat_bubble_outline,
        title: 'Atendimento & Suporte',
        description: 'Conversar com IA ou Especialista',
        color: const Color(0xFF1976D2),
        route: '/history',
      ),
      _ActionCardData(
        icon: Icons.history,
        title: 'Histórico',
        description: 'Ver diagnósticos anteriores',
        color: const Color(0xFFE64A19),
        route: '/history',
      ),
      _ActionCardData(
        icon: Icons.description_outlined,
        title: 'Planos & Assinaturas',
        description: 'Gerenciar seu plano de uso',
        color: const Color(0xFF388E3C),
        route: '/plans',
      ),
      if (_userRole.toUpperCase() == 'ADMIN')
        _ActionCardData(
          icon: Icons.manage_accounts_outlined,
          title: 'Gestão do Sistema',
          description: 'Painel administrativo',
          color: const Color(0xFF7B1FA2),
          route: '/admin/users',
        ),
      _ActionCardData(
        icon: Icons.person_outline,
        title: 'Meu Perfil',
        description: 'Dados da conta e dados cadastrais',
        color: const Color(0xFF00796B),
        route: '/profile',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isDesktop ? 2.8 : 1.9,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final item = actions[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, item.route),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, size: 22, color: item.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionCardData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String route;

  const _ActionCardData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.route,
  });
}
