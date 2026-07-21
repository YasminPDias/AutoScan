import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/chat_service.dart';
import '../../services/auth_storage.dart';
import '../../services/logger_service.dart';
import '../../services/websocket_service.dart';
import '../../services/web_audio_recorder.dart';
import '../../services/chat_read_tracker.dart';
import '../../services/api_config.dart';
import '../../models/mensagem_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRealtimeService _realtimeService = ChatRealtimeService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final WebAudioRecorder _webAudioRecorder = WebAudioRecorder();

  List<MensagemModel> _mensagens = [];
  bool _initialized = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;
  bool _isRecordingAudio = false;
  bool _isUploadingAudio = false;
  bool _isEncerrandoConversa = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  String? _conversaId;
  String? _errorMessage;
  String? _myUserId;
  String? _myUserName;
  String? _myRole;
  String? _token;
  String _conversaStatus = '';

  bool get _isEncerrada =>
      _conversaStatus == 'ENCERRADA' ||
      _conversaStatus == 'FECHADA' ||
      _conversaStatus == 'CONCLUIDA';

  bool get _isCliente {
    final role = (_myRole ?? '').toUpperCase();
    return role != 'ADMIN' && role != 'ASSISTENTE';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _inicializar();
    }
  }

  Future<void> _inicializar() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final diagnosticoId = args?['diagnosticoId'] as String?;
    final diagnosticoTexto = args?['diagnosticoTexto'] as String?;
    final conversaIdArg = args?['conversaId'] as String?;

    _myUserId = await AuthStorage.getUserId();
    _myUserName = await AuthStorage.getUserName();
    _myRole = await AuthStorage.getUserRole();
    _token = await AuthStorage.getToken();

    if (_token == null || _token!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sessão expirada. Faça login novamente.';
        });
      }
      return;
    }

    String? conversaId = conversaIdArg;

    if (conversaId == null && diagnosticoId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/history');
      }
      return;
    }

    if (conversaId == null && diagnosticoId != null) {
      conversaId = await _encontrarOuCriarConversa(
        token: _token!,
        diagnosticoId: diagnosticoId,
        diagnosticoTexto: diagnosticoTexto,
      );
    }

    if (conversaId == null || conversaId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Não foi possível iniciar o chat. Tente novamente.';
        });
      }
      return;
    }

    _conversaId = conversaId;
    ChatReadTracker.markRead(conversaId);

    final convResult = await ChatService.buscarConversa(
      token: _token!,
      conversaId: conversaId,
    );
    if (convResult['success'] == true && mounted) {
      final data = convResult['data'] as Map<String, dynamic>;
      setState(() {
        _conversaStatus = data['status']?.toString() ?? '';
      });
    }

    await _carregarMensagens();

    _realtimeService.start(
      token: _token!,
      conversaId: conversaId,
      onFetch: () async {
        final result = await ChatService.buscarMensagens(
          token: _token!,
          conversaId: conversaId!,
        );
        if (result['success'] == true) {
          return (result['data'] as List).cast<Map<String, dynamic>>();
        }
        return [];
      },
      onUpdate: (rawList) {
        final novas = rawList
            .map((j) => MensagemModel.fromJson(j))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (mounted && _mensagensAlteradas(novas)) {
          setState(() => _mensagens = novas);
        }
      },
      onWsMessage: (json) {
        if (json['conteudo'] != null || json['content'] != null) {
          try {
            final msg = MensagemModel.fromJson(json);
            if (mounted && !_mensagens.any((m) => m.id == msg.id)) {
              final senderId = msg.usuario?.id ?? json['usuarioId']?.toString();
              final isMeu = senderId != null && _myUserId != null && senderId == _myUserId;

              if (isMeu) {
                final idxPendente = _mensagens.indexWhere((m) =>
                    m.isPending &&
                    m.tipo == msg.tipo &&
                    (m.tipo != 'TEXTO' || m.conteudo == msg.conteudo));

                if (idxPendente != -1) {
                  setState(() => _mensagens[idxPendente] = msg);
                  return;
                }
              }

              setState(() => _mensagens.insert(0, msg));
            }
          } catch (_) {}
        }
      },
      onMensagensLidas: (leitorId) {
        // é o OUTRO participante lendo — marca minhas mensagens enviadas
        // como lidas (é o mesmo efeito do check azul do WhatsApp)
        if (leitorId == _myUserId || !mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _mensagens = _mensagens
                .map((m) => _isMinhaMensagem(m) && m.readAt == null
                    ? m.copyWith(readAt: DateTime.now())
                    : m)
                .toList();
          });
        });
      },
    );
  }

  bool _mensagensAlteradas(List<MensagemModel> novas) {
    final confirmadas = _mensagens.where((m) => !m.isPending).toList();
    if (novas.length != confirmadas.length) return true;
    if (novas.isEmpty) return false;
    return novas.first.id != confirmadas.firstOrNull?.id;
  }

  Future<String?> _encontrarOuCriarConversa({
    required String token,
    required String diagnosticoId,
    String? diagnosticoTexto,
  }) async {
    final minhasResult = await ChatService.buscarConversaPorDiagnosticoId(
      token: token,
      diagnosticoId: diagnosticoId,
    );
    if (minhasResult['success'] == true) {
      final data = minhasResult['data'] as Map<String, dynamic>;
      if (data['aiDiagnosticoId']?.toString() == diagnosticoId) {
        loggerService.d('Conversa existente: ${data['id']}');
        return data['id']?.toString();
      }
    }

    final createResult = await ChatService.criarConversa(
      token: token,
      aiDiagnosticoId: diagnosticoId,
    );

    if (createResult['success'] != true) {
      loggerService.e('Falha ao criar conversa: ${createResult['message']}');
      return null;
    }

    final convId = (createResult['data'] as Map<String, dynamic>)['id']
        ?.toString();

    if (convId != null &&
        diagnosticoTexto != null &&
        diagnosticoTexto.isNotEmpty) {
      await ChatService.enviarMensagem(
        token: token,
        conversaId: convId,
        conteudo: diagnosticoTexto,
        usuarioId: _myUserId,
      );
    }

    return convId;
  }

  Future<void> _carregarMensagens() async {
    if (_conversaId == null || _token == null) return;

    final result = await ChatService.buscarMensagens(
      token: _token!,
      conversaId: _conversaId!,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final lista = (result['data'] as List)
          .map((j) => MensagemModel.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _mensagens = lista;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message']?.toString();
      });
    }
  }

  Future<void> _enviarMensagem() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty || _conversaId == null || _isSending || _token == null) {
      return;
    }

    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final msgPendente = MensagemModel(
      id: tempId,
      tipo: 'TEXTO',
      conteudo: texto,
      createdAt: DateTime.now(),
      isPending: true,
    );

    setState(() {
      _mensagens.insert(0, msgPendente);
      _isSending = true;
      _messageController.clear();
    });

    final result = await ChatService.enviarMensagem(
      token: _token!,
      conversaId: _conversaId!,
      conteudo: texto,
      usuarioId: _myUserId,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final msgConfirmada = MensagemModel.fromJson(
        result['data'] as Map<String, dynamic>,
      );
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        // o WS pode ter entregue essa mesma mensagem antes da resposta HTTP
        // voltar (o backend emite pro socket antes de responder o POST) —
        // sem essa checagem, ela entraria duas vezes pra quem enviou
        if (!_mensagens.any((m) => m.id == msgConfirmada.id)) {
          _mensagens.insert(0, msgConfirmada);
        }
        _isSending = false;
      });
    } else {
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erro ao enviar mensagem.'),
          backgroundColor: AppColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _encerrarConversa() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar conversa'),
        content: const Text(
          'Deseja encerrar esta conversa e marcar o problema como resolvido?\n\nApós encerrado, não será possível enviar novas mensagens.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
            ),
            child: const Text(
              'Problema resolvido',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || _conversaId == null || _token == null) return;

    setState(() => _isEncerrandoConversa = true);

    final result = await ChatService.encerrarConversa(
      token: _token!,
      conversaId: _conversaId!,
    );

    if (!mounted) return;
    setState(() => _isEncerrandoConversa = false);

    if (result['success'] == true) {
      setState(() {
        _conversaStatus = 'ENCERRADA';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erro ao encerrar conversa.'),
          backgroundColor: AppColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<Uint8List> _comprimirImagem(Uint8List bytes) async {
    try {
      final original = img.decodeImage(bytes);
      if (original == null) return bytes;
      final resized = img.copyResize(
        original,
        width: original.width > 800 ? 800 : original.width,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
    } catch (_) {
      return bytes;
    }
  }

  Future<void> _selecionarEEnviarImagem() async {
    if (_conversaId == null || _token == null || _isUploadingImage) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    if ((file.size) > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem muito grande. Máximo: 5MB.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final tempId = 'pending_img_${DateTime.now().millisecondsSinceEpoch}';
    final msgPendente = MensagemModel(
      id: tempId,
      tipo: 'IMAGEM',
      conteudo: '',
      createdAt: DateTime.now(),
      isPending: true,
    );

    setState(() {
      _mensagens.insert(0, msgPendente);
      _isUploadingImage = true;
    });

    final bytes = await _comprimirImagem(file.bytes!);
    final fileName = file.name.toLowerCase().endsWith('.png')
        ? file.name
        : '${file.name.split('.').first}.jpg';

    final uploadResult = await ChatService.uploadArquivo(
      token: _token!,
      bytes: bytes,
      fileName: fileName,
    );

    if (!mounted) return;

    if (uploadResult['success'] != true) {
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadResult['message'] ?? 'Erro ao enviar imagem.'),
          backgroundColor: AppColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final midiaUrl = (uploadResult['data'] as Map<String, dynamic>)['url']
        ?.toString();

    if (midiaUrl == null || midiaUrl.isEmpty) {
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        _isUploadingImage = false;
      });
      return;
    }

    final sendResult = await ChatService.enviarMensagem(
      token: _token!,
      conversaId: _conversaId!,
      tipo: 'IMAGEM',
      midiaUrl: midiaUrl,
      usuarioId: _myUserId,
    );

    if (!mounted) return;

    if (sendResult['success'] == true) {
      final msgConfirmada = MensagemModel.fromJson(
        sendResult['data'] as Map<String, dynamic>,
      );
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        if (!_mensagens.any((m) => m.id == msgConfirmada.id)) {
          _mensagens.insert(0, msgConfirmada);
        }
        _isUploadingImage = false;
      });
    } else {
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sendResult['message'] ?? 'Erro ao enviar imagem.'),
          backgroundColor: AppColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Áudio ──────────────────────────────────────────────────────────────────

  void _iniciarTimerGravacao() {
    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  void _pararTimerGravacao() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  String _formatarDuracaoGravacao() {
    final min = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _iniciarGravacao() async {
    if (_conversaId == null || _token == null || _isUploadingAudio) return;

    try {
      if (kIsWeb) {
        await _webAudioRecorder.start();
      } else {
        final hasPermission = await _audioRecorder.hasPermission();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permissão de microfone negada.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      }

      if (mounted) {
        setState(() => _isRecordingAudio = true);
        _iniciarTimerGravacao();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao iniciar gravação: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pararEEnviarAudio() async {
    _pararTimerGravacao();
    final Uint8List? webBytes = kIsWeb ? await _webAudioRecorder.stop() : null;
    final path = kIsWeb ? null : await _audioRecorder.stop();

    if (mounted) setState(() => _isRecordingAudio = false);

    if (path == null && webBytes == null ||
        _conversaId == null ||
        _token == null)
      return;

    Uint8List bytes;
    if (kIsWeb) {
      bytes = webBytes!;
    } else {
      try {
        final file = File(path!);
        bytes = await file.readAsBytes();
        await file.delete();
      } catch (e) {
        loggerService.e('Erro ao ler arquivo de áudio: $e');
        return;
      }
    }

    final fileName = kIsWeb
        ? 'audio_${DateTime.now().millisecondsSinceEpoch}.webm'
        : 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final tempId = 'pending_audio_${DateTime.now().millisecondsSinceEpoch}';
    final msgPendente = MensagemModel(
      id: tempId,
      tipo: 'AUDIO',
      conteudo: '',
      createdAt: DateTime.now(),
      isPending: true,
    );

    setState(() {
      _mensagens.insert(0, msgPendente);
      _isUploadingAudio = true;
    });

    final uploadResult = await ChatService.uploadArquivo(
      token: _token!,
      bytes: bytes,
      fileName: fileName,
    );

    if (!mounted) return;

    if (uploadResult['success'] != true) {
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        _isUploadingAudio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadResult['message'] ?? 'Erro ao enviar áudio.'),
          backgroundColor: AppColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final midiaUrl = (uploadResult['data'] as Map<String, dynamic>)['url']
        ?.toString();

    if (midiaUrl == null || midiaUrl.isEmpty) {
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        _isUploadingAudio = false;
      });
      return;
    }

    final sendResult = await ChatService.enviarMensagem(
      token: _token!,
      conversaId: _conversaId!,
      tipo: 'AUDIO',
      midiaUrl: midiaUrl,
      usuarioId: _myUserId,
    );

    if (!mounted) return;

    if (sendResult['success'] == true) {
      final msgConfirmada = MensagemModel.fromJson(
        sendResult['data'] as Map<String, dynamic>,
      );
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        if (!_mensagens.any((m) => m.id == msgConfirmada.id)) {
          _mensagens.insert(0, msgConfirmada);
        }
        _isUploadingAudio = false;
      });
    } else {
      setState(() {
        _mensagens.removeWhere((m) => m.id == tempId);
        _isUploadingAudio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sendResult['message'] ?? 'Erro ao enviar áudio.'),
          backgroundColor: AppColors.statusUrgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelarGravacao() async {
    _pararTimerGravacao();
    if (kIsWeb) {
      await _webAudioRecorder.cancel();
    } else {
      await _audioRecorder.cancel();
    }
    if (mounted) setState(() => _isRecordingAudio = false);
  }

  void _abrirImagemFullscreen(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewerPage(url: url),
        fullscreenDialog: true,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────

  bool _isMinhaMensagem(MensagemModel msg) {
    if (msg.isPending) return true;
    if (_myUserId == null || _myUserId!.isEmpty) return false;
    return msg.usuario?.id == _myUserId;
  }

  String _formatarHora(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/chat',
      title: context.isDesktop ? 'Chat' : '',
      showAppBar: !context.isDesktop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop
            ? null
            : AppBar(
                title: const Text('Chat'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/home');
                    }
                  },
                ),
              ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed),
              )
            : _errorMessage != null
            ? _buildErro()
            : Column(
                children: [
                  Expanded(child: _buildListaMensagens()),
                  if (_isEncerrada)
                    _buildBannerEncerrada()
                  else
                    _buildBarraInput(),
                ],
              ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.primaryRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
              ),
              child: const Text(
                'Voltar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaMensagens() {
    if (_mensagens.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma mensagem ainda.',
          style: TextStyle(color: AppColors.textLight),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
      itemCount: _mensagens.length,
      itemBuilder: (context, index) => _buildBolhaMensagem(_mensagens[index]),
    );
  }

  Widget _buildBolhaMensagem(MensagemModel msg) {
    final isMeu = _isMinhaMensagem(msg);

    EdgeInsets bubblePadding;
    if (msg.tipo == 'IMAGEM' && !msg.isPending && msg.midiaUrl != null) {
      bubblePadding = const EdgeInsets.all(4);
    } else if (msg.tipo == 'AUDIO' && !msg.isPending && msg.midiaUrl != null) {
      bubblePadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 10);
    } else {
      bubblePadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMeu
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMeu) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: AppColors.iconBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.support_agent,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMeu
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMeu && msg.usuario != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      msg.usuario!.nome,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (isMeu && _myUserName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 4),
                    child: Text(
                      _myUserName!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Opacity(
                  opacity: msg.isPending ? 0.55 : 1.0,
                  child: Container(
                    padding: bubblePadding,
                    decoration: BoxDecoration(
                      color: isMeu ? AppColors.lightRed : AppColors.cardWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(isMeu ? 12 : 2),
                        bottomRight: Radius.circular(isMeu ? 2 : 12),
                      ),
                      border: Border.all(
                        color: isMeu
                            ? AppColors.primaryRed.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: _buildConteudoBolha(msg, isMeu),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatarHora(msg.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (msg.isPending) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.access_time,
                          size: 10,
                          color: AppColors.textLight,
                        ),
                      ],
                      if (isMeu && !msg.isPending) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.readAt != null
                              ? Icons.done_all
                              : Icons.done,
                          size: 13,
                          color: msg.readAt != null
                              ? Colors.blue
                              : AppColors.textLight,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMeu) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 0, top: 4),
              decoration: const BoxDecoration(
                color: AppColors.primaryRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConteudoBolha(MensagemModel msg, bool isMeu) {
    if (msg.tipo == 'AUDIO') {
      if (msg.isPending || msg.midiaUrl == null) {
        return const SizedBox(
          width: 180,
          height: 44,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryRed,
            ),
          ),
        );
      }
      return _AudioBubble(url: msg.midiaUrl!, isMeu: isMeu);
    }

    if (msg.tipo == 'IMAGEM') {
      if (msg.isPending || msg.midiaUrl == null) {
        return const SizedBox(
          width: 160,
          height: 120,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryRed,
            ),
          ),
        );
      }
      final rawUrl = msg.midiaUrl!;
      final imageUrl = rawUrl.startsWith('http')
          ? rawUrl
          : '${ApiConfig.baseUrl}$rawUrl';
      loggerService.d('chat image URL: $imageUrl');
      return GestureDetector(
        onTap: () => _abrirImagemFullscreen(imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(isMeu ? 10 : 0),
            bottomRight: Radius.circular(isMeu ? 0 : 10),
          ),
          child: Image.network(
          imageUrl,
          width: 220,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 220,
              height: 160,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryRed,
                ),
              ),
            );
          },
          errorBuilder: (ctx, err, stack) {
            loggerService.e('Falha ao carregar imagem: $imageUrl — $err');
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 36,
                    color: AppColors.textLight,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Imagem indisponível',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
            );
          },
        ),
        ),
      );
    }

    return Text(
      msg.conteudo,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.45,
      ),
    );
  }

  Widget _buildBannerEncerrada() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        border: Border(top: BorderSide(color: Color(0xFF388E3C), width: 1)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF388E3C), size: 18),
            SizedBox(width: 8),
            Text(
              'Problema resolvido — conversa encerrada',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF388E3C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraInput() {
    if (_isRecordingAudio) return _buildBarraGravando();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.isDesktop ? 20 : 16,
        vertical: context.isDesktop ? 16 : 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.isDesktop ? 1200 : double.infinity,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _isUploadingImage
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: _selecionarEEnviarImagem,
                      color: AppColors.textSecondary,
                      tooltip: 'Enviar imagem',
                    ),
              _isUploadingAudio
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.mic_outlined),
                      onPressed: _iniciarGravacao,
                      color: AppColors.textSecondary,
                      tooltip: 'Gravar áudio',
                    ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.iconBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escreva uma mensagem...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _enviarMensagem(),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_isCliente)
                Tooltip(
                  message: 'Problema resolvido — encerrar conversa',
                  child: _isEncerrandoConversa
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF388E3C),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF388E3C)),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFF388E3C),
                            ),
                            onPressed: _encerrarConversa,
                            tooltip: '',
                          ),
                        ),
                ),
              if (_isCliente) const SizedBox(width: 4),
              _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: _enviarMensagem,
                      color: AppColors.primaryRed,
                      tooltip: 'Enviar',
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarraGravando() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.isDesktop ? 20 : 16,
        vertical: context.isDesktop ? 16 : 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelarGravacao,
              color: AppColors.textSecondary,
              tooltip: 'Cancelar',
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Gravando...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatarDuracaoGravacao(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ],
              ),
            ),
            _isUploadingAudio
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _pararEEnviarAudio,
                    color: AppColors.primaryRed,
                    tooltip: 'Enviar áudio',
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _realtimeService.stop();
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}

// ── Visualizador de imagem em tela cheia ──────────────────────────────────────

class _ImageViewerPage extends StatelessWidget {
  final String url;

  const _ImageViewerPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (ctx, err, stack) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Imagem indisponível',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget de reprodução de áudio ─────────────────────────────────────────────

class _AudioBubble extends StatefulWidget {
  final String url;
  final bool isMeu;

  const _AudioBubble({required this.url, required this.isMeu});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      final rawUrl = widget.url;
      final audioUrl = rawUrl.startsWith('http')
          ? rawUrl
          : '${ApiConfig.baseUrl}$rawUrl';
      await _player.play(UrlSource(audioUrl));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isMeu ? AppColors.primaryRed : AppColors.textPrimary;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            ),
            color: active,
            iconSize: 32,
            onPressed: _togglePlay,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 8,
                    ),
                    activeTrackColor: active,
                    inactiveTrackColor: active.withValues(alpha: 0.25),
                    thumbColor: active,
                    overlayColor: active.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) async {
                      final pos = Duration(
                        milliseconds: (v * _duration.inMilliseconds).round(),
                      );
                      await _player.seek(pos);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    '${_fmt(_position)} / ${_fmt(_duration)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: active.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
