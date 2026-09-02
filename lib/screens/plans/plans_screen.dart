import 'package:autex/screens/plans/beneficios_plano.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../models/plano_model.dart';
import '../../services/empresa/plano_service.dart';
import '../../services/auth_storage.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<PlanoModel> _planos = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _planoSelecionadoId;
  String? _assinaturaAtualNome; // nome do plano que o usuário já tem

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await PlanoService.listarTodos();
    if (!mounted) return;

    if (result['success'] == true) {
      final planos = result['data'] as List<PlanoModel>;
      setState(() {
        _planos = planos;
        _isLoading = false;
        if (planos.isNotEmpty) _planoSelecionadoId = planos.first.id;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message']?.toString();
      });
    }
  }

  void _selecionarPlano(PlanoModel plano) {
    if (!mounted) return;
    setState(() => _planoSelecionadoId = plano.id);
  }

  Future<void> _assinar(PlanoModel plano) async {
    if (plano.isFree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você já está no plano Free+'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final token = await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (plano.isEmpresarial) {
      Navigator.pushNamed(
        context,
        '/empresa/criar',
        arguments: {'planoId': plano.id, 'planoNome': plano.nome},
      );
    } else {
      Navigator.pushNamed(
        context,
        '/pagamento',
        arguments: {'planoId': plano.id, 'planoNome': plano.nome},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/plans',
      title: 'Planos e Assinaturas',
      showAppBar: !context.isDesktop,
      child: Container(
        color: AppColors.background,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
            : _errorMessage != null
                ? _buildErro()
                : SingleChildScrollView(
                    padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Escolha o Plano Ideal',
                                style: TextStyle(
                                  fontSize: context.isDesktop ? 32 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Selecione o plano que melhor atende suas necessidades',
                                style: TextStyle(
                                  fontSize: context.isDesktop ? 16 : 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        context.isDesktop ? _buildCardsDesktop() : _buildCardsMobile(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 48),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _carregar,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            child: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsDesktop() {
    // IntrinsicHeight: agora que cada plano tem um número diferente de
    // benefícios, sem isto os cards ficam com alturas distintas e os botões
    // desalinhados — o que atrapalha justamente a comparação.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _planos.asMap().entries.map((entry) {
          final plano = entry.value;
          final isPopular = !plano.isFree && !plano.isEmpresarial;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: entry.key < _planos.length - 1 ? 20 : 0),
              child: isPopular
                  ? Transform.scale(scale: 1.05, child: _buildCard(plano, isPopular))
                  : _buildCard(plano, isPopular),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardsMobile() {
    return Column(
      children: _planos.asMap().entries.map((entry) {
        final plano = entry.value;
        final isPopular = !plano.isFree && !plano.isEmpresarial;
        return Padding(
          padding: EdgeInsets.only(bottom: entry.key < _planos.length - 1 ? 16 : 0),
          child: _buildCard(plano, isPopular),
        );
      }).toList(),
    );
  }

  Widget _buildCard(PlanoModel plano, bool isPopular) {
    final isSelected = _planoSelecionadoId == plano.id;
    final isAtual = _assinaturaAtualNome == plano.nome;

    return GestureDetector(
      onTap: () => _selecionarPlano(plano),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isPopular || isSelected)
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plano.nome,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isAtual) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Atual',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plano.precoTexto,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        if (!plano.isFree)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('/mês',
                                style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Limite vem do banco: se mudar, o card acompanha sem deploy.
                    _buildFeature(plano.limiteTexto),

                    // itensCompletos, não `itens`: aqui os cards ficam lado a
                    // lado e o cliente compara. Com herança implícita ("Tudo
                    // do Pro, mais:"), o PREMIUM pareceria ter MENOS que o
                    // PRO — na tela de pagamento aquilo funciona porque a
                    // escolha já foi feita.
                    ...BeneficiosPlano.itensCompletos(plano.chave).map(_buildFeature),

                    if (plano.maxUsuarios != null)
                      _buildFeature(BeneficiosPlano.limiteUsuarios(plano.maxUsuarios!)),

                    // Empurra o botão pro rodapé — com listas de tamanhos
                    // diferentes, os botões ficam alinhados entre os cards.
                    const Spacer(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isSelected ? () => _assinar(plano) : () => _selecionarPlano(plano),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? AppColors.primaryRed : Colors.white,
                          foregroundColor: isSelected ? Colors.white : AppColors.primaryRed,
                          side: BorderSide(
                            color: AppColors.primaryRed,
                            width: isSelected ? 0 : 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.arrow_forward, size: 20),
                              ),
                            Flexible(
                              child: Text(
                                isAtual
                                    ? 'Plano atual'
                                    : isSelected
                                        ? plano.isFree
                                            ? 'Usar grátis'
                                            : plano.isEmpresarial
                                                ? 'Cadastrar empresa'
                                                : 'Assinar agora'
                                        : 'Selecionar',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}