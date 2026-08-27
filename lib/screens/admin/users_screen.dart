import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/user_service.dart';
import '../../services/auth_storage.dart';
import '../../services/logger_service.dart';
import '../../utils/validators.dart';
import '../dashboard/dashboard_screen.dart';
import '../empresa/empresa_funcionario_screen.dart';
import 'gestao_empresas_tab.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> _usuarios = [];
  List<dynamic> _usuariosFiltrados = [];
  bool _isLoading = true;
  String? _token;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    setState(() => _isLoading = true);
    _token = await AuthStorage.getToken();

    if (_token == null || _token!.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    final result = await UserService.buscarUsuarios(token: _token!);

    if (!mounted) return;

    if (result['success'] == true) {
      final list = (result['data'] as List).cast<dynamic>();
      setState(() {
        _usuarios = list;
        _filtrarUsuarios(_searchQuery);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erro ao carregar usuários.'),
          backgroundColor: AppColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _filtrarUsuarios(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _usuariosFiltrados = List.from(_usuarios);
    } else {
      final q = query.toLowerCase().trim();
      _usuariosFiltrados = _usuarios.where((u) {
        final nome = '${u['nome'] ?? ''} ${u['sobrenome'] ?? ''}'.toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final funcao = (u['funcao'] ?? '').toString().toLowerCase();
        return nome.contains(q) || email.contains(q) || funcao.contains(q);
      }).toList();
    }
  }

  void _abrirDialogCriar({String funcaoPadrao = 'CLIENTE'}) {
    final nomeCtrl = TextEditingController();
    final sobrenomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    String funcaoSelecionada = funcaoPadrao;
    bool enviando = false;
    bool senhaVisivel = false;

    // Gerar senha inicial temporária
    void gerarSenha() {
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#';
      final rand = Random.secure();
      final senha = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
      senhaCtrl.text = senha;
    }

    gerarSenha(); // Executa para criar a senha inicial

    void copiarSenha(BuildContext ctx) {
      Clipboard.setData(ClipboardData(text: senhaCtrl.text));
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Senha copiada para a área de transferência'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add, color: AppColors.primaryRed),
                SizedBox(width: 8),
                Text('Criar Novo Usuário'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome *',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sobrenomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sobrenome *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail *',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: senhaCtrl,
                      obscureText: !senhaVisivel,
                      decoration: InputDecoration(
                        labelText: 'Senha Temporária *',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(senhaVisivel ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setModalState(() => senhaVisivel = !senhaVisivel),
                              tooltip: 'Mostrar/ocultar senha',
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () => copiarSenha(context),
                              tooltip: 'Copiar senha',
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => setModalState(gerarSenha),
                              tooltip: 'Gerar nova senha',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telefoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefone *',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: funcaoSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Função / Perfil *',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CLIENTE', child: Text('Cliente')),
                        DropdownMenuItem(value: 'ASSISTENTE', child: Text('Assistente')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => funcaoSelecionada = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Copie a senha antes de salvar — ela não será mostrada novamente.',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
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
                        if (nomeCtrl.text.trim().isEmpty ||
                            sobrenomeCtrl.text.trim().isEmpty ||
                            emailCtrl.text.trim().isEmpty ||
                            senhaCtrl.text.trim().isEmpty ||
                            telefoneCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Preencha todos os campos obrigatórios.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final emailErro = Validators.validateEmail(emailCtrl.text.trim());
                        if (emailErro != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(emailErro),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        setModalState(() => enviando = true);

                        final res = await UserService.criarUsuario(
                          token: _token!,
                          nome: nomeCtrl.text.trim(),
                          sobrenome: sobrenomeCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          senha: senhaCtrl.text.trim(),
                          funcao: funcaoSelecionada,
                          telefone: telefoneCtrl.text.trim(),
                        );

                        if (!mounted) return;

                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          _carregarUsuarios();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Usuário criado com sucesso!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          setModalState(() => enviando = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Erro ao criar usuário.'),
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
                    : const Text('Criar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirDialogEditar(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    final nomeCtrl = TextEditingController(text: user['nome']?.toString() ?? '');
    final sobrenomeCtrl = TextEditingController(text: user['sobrenome']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: user['email']?.toString() ?? '');
    final senhaCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController(text: user['telefone']?.toString() ?? '');
    String funcaoSelecionada = (user['funcao']?.toString() ?? 'CLIENTE').toUpperCase();
    if (!['ADMIN', 'ASSISTENTE', 'CLIENTE'].contains(funcaoSelecionada)) {
      funcaoSelecionada = 'CLIENTE';
    }
    bool enviando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, color: AppColors.primaryRed),
                SizedBox(width: 8),
                Text('Editar Usuário'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome *',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sobrenomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sobrenome *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail *',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: telefoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefone *',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: funcaoSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Função / Perfil *',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CLIENTE', child: Text('Cliente')),
                        DropdownMenuItem(value: 'ASSISTENTE', child: Text('Assistente')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => funcaoSelecionada = val);
                      },
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
                        if (nomeCtrl.text.trim().isEmpty ||
                            sobrenomeCtrl.text.trim().isEmpty ||
                            emailCtrl.text.trim().isEmpty ||
                            telefoneCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Preencha todos os campos obrigatórios.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final emailErro = Validators.validateEmail(emailCtrl.text.trim());
                        if (emailErro != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(emailErro),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        setModalState(() => enviando = true);

                        final res = await UserService.atualizarUsuario(
                          token: _token!,
                          id: id,
                          nome: nomeCtrl.text.trim(),
                          sobrenome: sobrenomeCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          senha: senhaCtrl.text.trim(),
                          funcao: funcaoSelecionada,
                          telefone: telefoneCtrl.text.trim(),
                        );

                        if (!mounted) return;

                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          _carregarUsuarios();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Usuário atualizado com sucesso!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          setModalState(() => enviando = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Erro ao atualizar usuário.'),
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
                    : const Text('Salvar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmarDeletar(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    final nome = '${user['nome'] ?? ''} ${user['sobrenome'] ?? ''}'.trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar Usuário'),
        content: Text('Tem certeza que deseja excluir o usuário "$nome"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await UserService.deletarUsuario(token: _token!, id: id);
              if (!mounted) return;

              if (res['success'] == true) {
                _carregarUsuarios();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Usuário excluído/desativado com sucesso!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Erro ao excluir usuário.'),
                    backgroundColor: AppColors.statusUrgent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmarReativar(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    final nome = '${user['nome'] ?? ''} ${user['sobrenome'] ?? ''}'.trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reativar Usuário'),
        content: Text('Deseja reativar a conta do usuário "$nome"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await UserService.reativarUsuario(token: _token!, id: id);
              if (!mounted) return;

              if (res['success'] == true) {
                _carregarUsuarios();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Usuário reativado com sucesso!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Erro ao reativar usuário.'),
                    backgroundColor: AppColors.statusUrgent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Reativar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg = AppColors.lightRed;
    Color fg = AppColors.primaryRed;
    String label = role;

    switch (role.toUpperCase()) {
      case 'ADMIN':
        bg = const Color(0xFFEDE7F6);
        fg = const Color(0xFF673AB7);
        label = 'ADMINISTRADOR';
        break;
      case 'ASSISTENTE':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1976D2);
        label = 'ASSISTENTE';
        break;
      case 'CLIENTE':
        bg = const Color(0xFFF5F5F5);
        fg = const Color(0xFF616161);
        label = 'CLIENTE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildAbaUsuarios({required bool apenasClientes, required String funcaoCriarPadrao}) {
    final listaExibicao = _usuariosFiltrados.where((u) {
      final funcao = (u['funcao'] ?? 'CLIENTE').toString().toUpperCase();
      if (apenasClientes) {
        return funcao == 'CLIENTE';
      } else {
        return funcao == 'ADMIN' || funcao == 'ASSISTENTE';
      }
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirDialogCriar(funcaoPadrao: funcaoCriarPadrao),
        backgroundColor: AppColors.primaryRed,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text(
          apenasClientes ? 'Novo Cliente' : 'Novo Assistente / Admin',
          style: const TextStyle(color: Colors.white),
        ),
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
                      setState(() => _filtrarUsuarios(val));
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome, email ou telefone...',
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
                  onPressed: _carregarUsuarios,
                  tooltip: 'Atualizar lista',
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
                : listaExibicao.isEmpty
                    ? Center(
                        child: Text(
                          apenasClientes
                              ? 'Nenhum cliente encontrado.'
                              : 'Nenhum assistente ou admin encontrado.',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(context.isDesktop ? 24 : 16),
                        itemCount: listaExibicao.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = listaExibicao[index] as Map<String, dynamic>;
                          final nome = '${user['nome'] ?? ''} ${user['sobrenome'] ?? ''}'.trim();
                          final email = user['email'] ?? '';
                          final telefone = user['telefone'] ?? '';
                          final funcao = user['funcao'] ?? 'CLIENTE';
                          final status = user['status']?.toString().toUpperCase();
                          final isAtivo = status != 'INATIVO' && status != 'DESATIVADO';

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppColors.divider),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.lightRed,
                                child: Text(
                                  nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: context.isDesktop
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nome.isNotEmpty ? nome : 'Sem Nome',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildRoleBadge(funcao.toString()),
                                      ],
                                    )
                                  : Text(
                                      nome.isNotEmpty ? nome : 'Sem Nome',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!context.isDesktop) ...[
                                      const SizedBox(height: 2),
                                      _buildRoleBadge(funcao.toString()),
                                      const SizedBox(height: 6),
                                    ],
                                    Text('E-mail: $email', style: const TextStyle(fontSize: 13)),
                                    if (telefone.isNotEmpty)
                                      Text('Telefone: $telefone', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _abrirDialogEditar(user),
                                    tooltip: 'Editar Usuário',
                                  ),
                                  if (isAtivo)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: AppColors.primaryRed),
                                      onPressed: () => _confirmarDeletar(user),
                                      tooltip: 'Deletar / Desativar Usuário',
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(Icons.restore, color: Colors.green),
                                      onPressed: () => _confirmarReativar(user),
                                      tooltip: 'Reativar Usuário',
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: DesktopLayout(
        currentRoute: '/admin/users',
        title: 'Gestão do Sistema',
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: AppColors.primaryRed,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primaryRed,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: Icon(Icons.dashboard_outlined),
                    text: 'Dashboard',
                  ),
                  Tab(
                    icon: Icon(Icons.people_outline),
                    text: 'Clientes',
                  ),
                  Tab(
                    icon: Icon(Icons.business_outlined),
                    text: 'Empresa',
                  ),
                  Tab(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    text: 'Assistentes & Admins',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  // Aba 1: Dashboard Integrado
                  const DashboardScreen(isEmbedded: true),

                  // Aba 2: Clientes
                  _buildAbaUsuarios(apenasClientes: true, funcaoCriarPadrao: 'CLIENTE'),

                  // Aba 3: Empresa / Funcionários
                  const GestaoEmpresasTab(),

                  // Aba 4: Assistentes & Admins
                  _buildAbaUsuarios(apenasClientes: false, funcaoCriarPadrao: 'ASSISTENTE'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
