import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/esquema_service.dart';
import '../../services/auth_storage.dart';

class MinhasSolicitacoesScreen extends StatefulWidget {
  const MinhasSolicitacoesScreen({super.key});

  @override
  State<MinhasSolicitacoesScreen> createState() => _MinhasSolicitacoesScreenState();
}

class _MinhasSolicitacoesScreenState extends State<MinhasSolicitacoesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _solicitacoes = [];
  String? _token;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _carregarSolicitacoes();
  }

  Future<void> _carregarSolicitacoes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _token = await AuthStorage.getToken();
      _userRole = await AuthStorage.getUserRole();

      final role = _userRole?.trim().toUpperCase() ?? '';
      if (role == 'ADMIN' || role == 'ASSISTENTE') {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      if (_token == null || _token!.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Sessão expirada. Faça login novamente.';
          });
        }
        return;
      }

      final res = await EsquemaService.listarMinhas(token: _token!);

      if (!mounted) return;

      if (res['success'] == true) {
        setState(() {
          _solicitacoes = res['data'] as List<dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['message']?.toString() ?? 'Erro ao carregar solicitações.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro de conexão: $e';
        });
      }
    }
  }

  void _abrirConversa(String conversaId) {
    if (conversaId.isEmpty) return;
    Navigator.pushNamed(context, '/chat', arguments: {'conversaId': conversaId});
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toUpperCase()) {
      case 'AGUARDANDO':
      case 'PENDENTE':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'AGUARDANDO';
        break;
      case 'EM_ATENDIMENTO':
      case 'EM_ANALISE':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        label = 'EM ATENDIMENTO';
        break;
      case 'ENCERRADA':
      case 'CONCLUIDA':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'CONCLUÍDA';
        break;
      default:
        bg = const Color(0xFFF5F5F5);
        fg = const Color(0xFF616161);
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instabilidade no Serviço',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage ?? 'Erro desconhecido',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _carregarSolicitacoes,
            child: const Text('Tentar de Novo'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppColors.lightRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.electrical_services_outlined,
                size: 44,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum esquema elétrico solicitado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Quando você solicitar diagramas ou esquemas elétricos,\neles serão exibidos nesta lista.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/solicitar-esquema'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Solicitar Novo Esquema',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final isDesktop = context.isDesktop;

    return isDesktop
        ? GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 2.8,
            ),
            itemCount: _solicitacoes.length,
            itemBuilder: (context, index) => _buildCard(_solicitacoes[index]),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _solicitacoes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildCard(_solicitacoes[index]),
          );
  }

  Widget _buildCard(dynamic item) {
    final conversaId = item['conversaId']?.toString() ?? '';
    final marca = item['marca']?.toString() ?? '';
    final modelo = item['modelo']?.toString() ?? '';
    final anoModelo = item['anoModelo']?.toString() ?? '';
    final motor = item['motor']?.toString() ?? '';
    final injecao = item['injecao']?.toString() ?? '';
    final observacao = item['observacao']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'AGUARDANDO';
    final atendenteNome = item['atendenteNome']?.toString();
    final createdAtStr = item['createdAt']?.toString() ?? '';

    final tituloVeiculo = '$marca $modelo ($anoModelo)'.trim();
    
    DateTime? dataCriacao;
    if (createdAtStr.isNotEmpty) {
      dataCriacao = DateTime.tryParse(createdAtStr);
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _abrirConversa(conversaId),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.lightRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.electrical_services_outlined,
                      color: AppColors.primaryRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tituloVeiculo,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (motor.isNotEmpty || injecao.isNotEmpty)
                          Text(
                            [
                              if (motor.isNotEmpty) 'Motor: $motor',
                              if (injecao.isNotEmpty) 'Injeção: $injecao',
                            ].join('  •  '),
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
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              if (observacao.isNotEmpty) ...[
                Text(
                  observacao,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.support_agent_outlined,
                    size: 14,
                    color: atendenteNome != null ? AppColors.primaryRed : AppColors.textLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    atendenteNome != null ? 'Com: $atendenteNome' : 'Aguardando Atendente',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: atendenteNome != null ? FontWeight.bold : FontWeight.normal,
                      color: atendenteNome != null ? AppColors.textPrimary : AppColors.textLight,
                    ),
                  ),
                  const Spacer(),
                  if (dataCriacao != null) ...[
                    const Icon(Icons.access_time, size: 13, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      '${dataCriacao.day.toString().padLeft(2, '0')}/${dataCriacao.month.toString().padLeft(2, '0')} às ${dataCriacao.hour.toString().padLeft(2, '0')}:${dataCriacao.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistenteState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_outlined,
                size: 44,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Painel do Atendente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Como atendente ou administrador, você não cria solicitações de esquemas elétricos.\n\nPara visualizar e responder aos chamados e dúvidas de clientes, acesse a fila de Atendimentos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/chat-history'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.support_agent, color: Colors.white),
              label: const Text(
                'Ir para Atendimentos',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _userRole?.trim().toUpperCase() ?? '';
    final isAssistenteOrAdmin = role == 'ADMIN' || role == 'ASSISTENTE';

    return DesktopLayout(
      currentRoute: '/minhas-solicitacoes',
      title: context.isDesktop ? '' : 'Esquemas Elétricos',
      showAppBar: !context.isDesktop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: isAssistenteOrAdmin
            ? null
            : FloatingActionButton(
                onPressed: () => Navigator.pushNamed(context, '/solicitar-esquema'),
                backgroundColor: AppColors.primaryRed,
                tooltip: 'Solicitar esquema',
                child: const Icon(Icons.add, color: Colors.white),
              ),
        body: Container(
          color: AppColors.background,
          child: RefreshIndicator(
            onRefresh: _carregarSolicitacoes,
            color: AppColors.primaryRed,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.isDesktop ? 32 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (context.isDesktop) ...[
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isAssistenteOrAdmin
                              ? 'Esquemas Elétricos'
                              : 'Minhas Solicitações de Esquemas Elétricos',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _carregarSolicitacoes,
                          tooltip: 'Atualizar lista',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                  if (isAssistenteOrAdmin)
                    _buildAssistenteState()
                  else ...[
                    if (_errorMessage != null) _buildErrorBanner(),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 120),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primaryRed),
                        ),
                      )
                    else if (_solicitacoes.isEmpty && _errorMessage == null)
                      _buildEmptyState()
                    else
                      _buildList(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
