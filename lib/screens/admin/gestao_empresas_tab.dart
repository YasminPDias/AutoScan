import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive.dart';
import '../../services/auth_storage.dart';
import '../../services/empresa/empresa_service.dart';

class GestaoEmpresasTab extends StatefulWidget {
  const GestaoEmpresasTab({super.key});

  @override
  State<GestaoEmpresasTab> createState() => _GestaoEmpresasTabState();
}

class _GestaoEmpresasTabState extends State<GestaoEmpresasTab> {
  List<dynamic> _empresas = [];
  List<dynamic> _empresasFiltradas = [];
  bool _isLoading = true;
  String? _token;
  String _searchQuery = '';
  String? _errorMessage;

  int _pagina = 1;
  int _porPagina = 10;
  int _total = 0;
  int _totalPaginas = 1;

  @override
  void initState() {
    super.initState();
    _carregarEmpresas();
  }

  Future<void> _carregarEmpresas({int? novaPagina}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (novaPagina != null) {
        _pagina = novaPagina;
      }
    });

    _token = await AuthStorage.getToken();
    if (_token == null || _token!.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    final res = await EmpresaService.listarTodas(
      token: _token!,
      pagina: _pagina,
      porPagina: _porPagina,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final data = res['data'];
      List list = [];
      if (data is Map && data.containsKey('dados')) {
        list = data['dados'] as List;
        _total = data['total'] as int? ?? 0;
        _pagina = data['pagina'] as int? ?? 1;
        _totalPaginas = data['totalPaginas'] as int? ?? 1;
      } else if (data is List) {
        list = data;
        _total = list.length;
        _totalPaginas = 1;
        _pagina = 1;
      }
      
      setState(() {
        _empresas = list;
        _filtrarEmpresas(_searchQuery);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['message']?.toString() ?? 'Erro ao carregar empresas.';
      });
    }
  }

  void _filtrarEmpresas(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _empresasFiltradas = List.from(_empresas);
    } else {
      final q = query.toLowerCase().trim();
      _empresasFiltradas = _empresas.where((e) {
        final razao = (e['razaoSocial'] ?? '').toString().toLowerCase();
        final fantasia = (e['nomeFantasia'] ?? '').toString().toLowerCase();
        final cnpj = (e['cnpj'] ?? '').toString().toLowerCase();
        final email = (e['emailContato'] ?? '').toString().toLowerCase();
        final cidade = (e['cidade'] ?? '').toString().toLowerCase();
        return razao.contains(q) ||
            fantasia.contains(q) ||
            cnpj.contains(q) ||
            email.contains(q) ||
            cidade.contains(q);
      }).toList();
    }
  }

  void _abrirModalMembros(Map<String, dynamic> empresa) {
    final empresaId = empresa['_id']?.toString() ?? empresa['id']?.toString() ?? '';
    final razaoSocial = empresa['razaoSocial']?.toString() ?? empresa['nomeFantasia']?.toString() ?? 'Empresa';

    showDialog(
      context: context,
      builder: (ctx) => _ModalMembrosEmpresa(
        token: _token!,
        empresaId: empresaId,
        razaoSocial: razaoSocial,
        empresaData: empresa,
      ),
    );
  }

  void _abrirModalCriarEmpresa() {
    final razaoCtrl = TextEditingController();
    final fantasiaCtrl = TextEditingController();
    final cnpjCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final cidadeCtrl = TextEditingController();
    final estadoCtrl = TextEditingController();
    bool enviando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_business, color: AppColors.primaryRed),
                SizedBox(width: 8),
                Text('Cadastrar Nova Empresa'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: razaoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Razão Social *',
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fantasiaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome Fantasia',
                        prefixIcon: Icon(Icons.store),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cnpjCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'CNPJ *',
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail de Contato *',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telefoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefone',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cidadeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Cidade *',
                              prefixIcon: Icon(Icons.location_city),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: estadoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'UF *',
                              prefixIcon: Icon(Icons.map),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: enviando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: enviando
                    ? null
                    : () async {
                        if (razaoCtrl.text.trim().isEmpty ||
                            cnpjCtrl.text.trim().isEmpty ||
                            emailCtrl.text.trim().isEmpty ||
                            cidadeCtrl.text.trim().isEmpty ||
                            estadoCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Preencha os campos obrigatórios (*).'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        setModalState(() => enviando = true);

                        final res = await EmpresaService.criar(
                          token: _token!,
                          razaoSocial: razaoCtrl.text.trim(),
                          nomeFantasia: fantasiaCtrl.text.trim(),
                          cnpj: cnpjCtrl.text.trim(),
                          emailContato: emailCtrl.text.trim(),
                          telefone: telefoneCtrl.text.trim(),
                          cidade: cidadeCtrl.text.trim(),
                          estado: estadoCtrl.text.trim(),
                        );

                        if (!mounted) return;

                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          _carregarEmpresas();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Empresa cadastrada com sucesso!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          setModalState(() => enviando = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Erro ao cadastrar empresa.'),
                              backgroundColor: AppColors.statusUrgent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
                child: enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Cadastrar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirModalCriarEmpresa,
        backgroundColor: AppColors.primaryRed,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('Nova Empresa', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(context.isDesktop ? 24 : 16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      setState(() => _filtrarEmpresas(val));
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por razão social, fantasia, CNPJ, e-mail ou cidade...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _carregarEmpresas,
                  tooltip: 'Atualizar lista de empresas',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryRed),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 48),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _carregarEmpresas,
                              child: const Text('Tentar Novamente'),
                            ),
                          ],
                        ),
                      )
                    : _empresasFiltradas.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhuma empresa encontrada.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.all(context.isDesktop ? 24 : 16),
                            itemCount: _empresasFiltradas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final emp = _empresasFiltradas[index] as Map<String, dynamic>;
                              final razaoSocial = emp['razaoSocial']?.toString() ?? 'Sem Razão Social';
                              final nomeFantasia = emp['nomeFantasia']?.toString() ?? '';
                              final cnpj = emp['cnpj']?.toString() ?? 'Sem CNPJ';
                              final email = emp['emailContato']?.toString() ?? '';
                              final telefone = emp['telefone']?.toString() ?? '';
                              final cidade = emp['cidade']?.toString() ?? '';
                              final estado = emp['estado']?.toString() ?? '';
                              final ativo = emp['ativo'] == true;
                              final plano = emp['plano'] as Map<String, dynamic>?;
                              final nomePlano = plano?['nome']?.toString() ?? '';

                              final localizacao = [cidade, estado].where((s) => s.isNotEmpty).join(' / ');

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryRed.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.business,
                                              color: AppColors.primaryRed,
                                              size: 26,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        razaoSocial,
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: ativo
                                                            ? const Color(0xFFE8F5E9)
                                                            : const Color(0xFFFFF3E0),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        ativo ? 'Ativa' : 'Pendente / Teste',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: ativo
                                                              ? const Color(0xFF2E7D32)
                                                              : const Color(0xFFE65100),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (nomeFantasia.isNotEmpty && nomeFantasia != razaoSocial)
                                                  Text(
                                                    'Fantasia: $nomeFantasia',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: AppColors.textSecondary,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(height: 1),
                                      ),
                                      Wrap(
                                        spacing: 24,
                                        runSpacing: 8,
                                        children: [
                                          _buildInfoItem(Icons.badge_outlined, 'CNPJ', cnpj),
                                          if (email.isNotEmpty)
                                            _buildInfoItem(Icons.email_outlined, 'Contato', email),
                                          if (telefone.isNotEmpty)
                                            _buildInfoItem(Icons.phone_outlined, 'Telefone', telefone),
                                          if (localizacao.isNotEmpty)
                                            _buildInfoItem(Icons.location_on_outlined, 'Localização', localizacao),
                                          if (nomePlano.isNotEmpty)
                                            _buildInfoItem(Icons.card_membership_outlined, 'Plano', nomePlano),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _abrirModalMembros(emp),
                                            icon: const Icon(Icons.people, size: 18),
                                            label: const Text('Ver Funcionários / Membros'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.primaryRed,
                                              side: const BorderSide(color: AppColors.primaryRed),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          if (!_isLoading && _totalPaginas > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _pagina > 1 ? () => _carregarEmpresas(novaPagina: _pagina - 1) : null,
                  ),
                  const SizedBox(width: 16),
                  Text('Página $_pagina de $_totalPaginas', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _pagina < _totalPaginas ? () => _carregarEmpresas(novaPagina: _pagina + 1) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            children: [
              TextSpan(text: '$label: ', style: const TextStyle(color: AppColors.textSecondary)),
              TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Modal de Membros / Funcionários da Empresa ───────────────────────────────

class _ModalMembrosEmpresa extends StatefulWidget {
  final String token;
  final String empresaId;
  final String razaoSocial;
  final Map<String, dynamic> empresaData;

  const _ModalMembrosEmpresa({
    required this.token,
    required this.empresaId,
    required this.razaoSocial,
    required this.empresaData,
  });

  @override
  State<_ModalMembrosEmpresa> createState() => _ModalMembrosEmpresaState();
}

class _ModalMembrosEmpresaState extends State<_ModalMembrosEmpresa> {
  List<Map<String, dynamic>> _membros = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _carregarMembros();
  }

  Future<void> _carregarMembros() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await EmpresaService.listarMembros(
      token: widget.token,
      empresaId: widget.empresaId,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final list = (res['data'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _membros = list;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['message']?.toString() ?? 'Erro ao carregar membros.';
      });
    }
  }

  void _abrirModalAdicionarFuncionario() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ModalAdicionarFuncionarioDialog(
        empresaId: widget.empresaId,
        token: widget.token,
        onSucesso: _carregarMembros,
      ),
    );
  }

  Future<void> _removerFuncionario(String funcionarioId, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover funcionário'),
        content: Text('Deseja remover "$nome" da empresa? A conta dele será desativada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final ok = await EmpresaService.removerFuncionario(
      token: widget.token,
      empresaId: widget.empresaId,
      funcionarioId: funcionarioId,
    );

    if (!mounted) return;
    if (ok) {
      _carregarMembros();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Funcionário removido com sucesso.'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao remover funcionário.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _alterarPapel(String funcionarioId, String novoPapel) async {
    final result = await EmpresaService.alterarPapelFuncionario(
      token: widget.token,
      empresaId: widget.empresaId,
      funcionarioId: funcionarioId,
      novoPapel: novoPapel,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Papel do funcionário alterado para $novoPapel com sucesso!'),
          backgroundColor: const Color(0xFF388E3C),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _carregarMembros();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erro ao alterar papel do funcionário.'),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 600),
        child: Column(
          children: [
            // Cabeçalho do modal
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people, color: AppColors.primaryRed),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Funcionários / Membros',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.razaoSocial,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _abrirModalAdicionarFuncionario,
                    icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
                    label: const Text('Adicionar', style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Corpo com a lista
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 12),
                              TextButton(onPressed: _carregarMembros, child: const Text('Tentar Novamente')),
                            ],
                          ),
                        )
                      : _membros.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Nenhum funcionário cadastrado nesta empresa.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _membros.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final membro = _membros[index];
                                final usuario = membro['usuario'] as Map<String, dynamic>? ?? membro;
                                final id = usuario['id']?.toString() ?? usuario['_id']?.toString() ?? '';
                                final nome = '${usuario['nome'] ?? ''} ${usuario['sobrenome'] ?? ''}'.trim();
                                final email = usuario['email']?.toString() ?? '';
                                final telefone = usuario['telefone']?.toString() ?? '';
                                final papel = membro['papel']?.toString() ?? 'MEMBRO';
                                final isAdmin = papel == 'ADMIN';

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isAdmin
                                            ? AppColors.primaryRed.withValues(alpha: 0.1)
                                            : AppColors.iconBackground,
                                        child: Icon(
                                          isAdmin ? Icons.admin_panel_settings : Icons.person,
                                          color: isAdmin ? AppColors.primaryRed : AppColors.textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  nome.isNotEmpty ? nome : 'Sem Nome',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                const SizedBox(width: 8),
                                                PopupMenuButton<String>(
                                                  tooltip: 'Alterar Papel',
                                                  onSelected: (novoPapel) => _alterarPapel(id, novoPapel),
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(
                                                      value: isAdmin ? 'MEMBRO' : 'ADMIN',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            isAdmin ? Icons.person : Icons.admin_panel_settings,
                                                            size: 18,
                                                            color: AppColors.primaryRed,
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(isAdmin ? 'Mudar para Membro' : 'Promover a Admin'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isAdmin
                                                          ? AppColors.primaryRed.withValues(alpha: 0.1)
                                                          : AppColors.iconBackground,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          isAdmin ? 'Admin' : 'Membro',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: isAdmin ? AppColors.primaryRed : AppColors.textSecondary,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Icon(
                                                          Icons.arrow_drop_down,
                                                          size: 16,
                                                          color: isAdmin ? AppColors.primaryRed : AppColors.textSecondary,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text('E-mail: $email', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                            if (telefone.isNotEmpty)
                                              Text('Telefone: $telefone', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      if (!isAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.person_remove_outlined, color: AppColors.primaryRed, size: 20),
                                          tooltip: 'Remover funcionário',
                                          onPressed: () => _removerFuncionario(id, nome),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal para Adicionar Funcionário na Empresa Selecionada ──────────────────

class _ModalAdicionarFuncionarioDialog extends StatefulWidget {
  final String empresaId;
  final String token;
  final VoidCallback onSucesso;

  const _ModalAdicionarFuncionarioDialog({
    required this.empresaId,
    required this.token,
    required this.onSucesso,
  });

  @override
  State<_ModalAdicionarFuncionarioDialog> createState() => _ModalAdicionarFuncionarioDialogState();
}

class _ModalAdicionarFuncionarioDialogState extends State<_ModalAdicionarFuncionarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _sobrenomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  String _papel = 'MEMBRO';
  bool _isLoading = false;
  bool _senhaVisivel = false;

  @override
  void initState() {
    super.initState();
    _gerarSenha();
  }

  void _gerarSenha() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#';
    final rand = Random.secure();
    final senha = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
    _senhaCtrl.text = senha;
  }

  void _copiarSenha() {
    Clipboard.setData(ClipboardData(text: _senhaCtrl.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Senha copiada para a área de transferência'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await EmpresaService.adicionarFuncionario(
      token: widget.token,
      empresaId: widget.empresaId,
      nome: _nomeCtrl.text.trim(),
      sobrenome: _sobrenomeCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      telefone: _telefoneCtrl.text.trim(),
      senha: _senhaCtrl.text,
      papel: _papel,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pop(context);
      widget.onSucesso();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Funcionário adicionado com sucesso!'),
          backgroundColor: Color(0xFF388E3C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erro ao adicionar funcionário'),
          backgroundColor: AppColors.primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Adicionar Funcionário',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(labelText: 'Nome *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sobrenomeCtrl,
                        decoration: const InputDecoration(labelText: 'Sobrenome *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obrigatório';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _senhaCtrl,
                  obscureText: !_senhaVisivel,
                  decoration: InputDecoration(
                    labelText: 'Senha temporária *',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: AppColors.primaryRed),
                          onPressed: _copiarSenha,
                        ),
                      ],
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _papel,
                  decoration: const InputDecoration(labelText: 'Papel na empresa *'),
                  items: const [
                    DropdownMenuItem(value: 'MEMBRO', child: Text('Membro')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _papel = v);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Adicionar Funcionário',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
