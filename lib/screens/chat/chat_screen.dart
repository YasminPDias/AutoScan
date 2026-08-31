import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/app_colors.dart';
import '../../layouts/desktop_layout.dart';
import '../../utils/responsive.dart';
import '../../services/chat_service.dart';
import '../../services/auth_storage.dart';
import '../../services/logger_service.dart';
import '../../services/websocket_service.dart';
import '../../services/web_audio_recorder.dart';
import '../../services/chat_read_tracker.dart';
import '../../services/atendimento_service.dart';
import '../../services/audio_player_controller.dart';
import '../../models/mensagem_model.dart';
import '../../widgets/chat_midia_widgets.dart';
import '../../services/esquema_service.dart';

const _uuid = Uuid();

/// Bytes retidos para permitir reenvio sem pedir o arquivo de novo.
/// Descartados assim que a mensagem confirma.
class _MidiaPendente {
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final String tipo;

  const _MidiaPendente({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.tipo,
  });
}

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
  final AudioPlayerController _audioController = AudioPlayerController();
  final ImagePicker _imagePicker = ImagePicker();

  List<MensagemModel> _mensagens = [];
  final Map<String, _MidiaPendente> _midiasPendentes = {};

  bool _initialized = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;
  bool _isRecordingAudio = false;
  bool _isUploadingAudio = false;
  bool _isEncerrandoConversa = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  int _atendentesOnlineCount = 0;

  bool _isCarregandoMais = false;
  bool _temMaisMensagens = false;
  int _paginaAtual = 1;
  static const int _porPagina = 20;

  String? _conversaId;
  String? _errorMessage;
  String? _myUserId;
  String? _myUserName;
  String? _token;
  String? _clienteId;
  String _conversaStatus = '';

  bool get _isEncerrada =>
      _conversaStatus == 'ENCERRADA' ||
      _conversaStatus == 'FECHADA' ||
      _conversaStatus == 'CONCLUIDA';

  bool get _isDonoDaConversa {
    if (_clienteId == null || _myUserId == null) return false;
    return _clienteId == _myUserId;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _inicializar();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _carregarMaisMensagens();
    }
  }

  // ─── estado da lista ──────────────────────────────────────────────────────

  /// Funde por id em vez de substituir.
  ///
  /// O polling busca sempre a página 1. Substituir `_mensagens` descartava tudo
  /// que a paginação já tinha carregado, e como `_paginaAtual` continuava no
  /// valor antigo, o próximo "carregar mais" pulava um bloco inteiro.
  void _fundir(Iterable<MensagemModel> novas) {
    final porId = <String, MensagemModel>{};
    for (final m in _mensagens) {
      porId[m.id] = m;
    }

    for (final m in novas) {
      final pendente = _acharPendenteCorrespondente(m);
      if (pendente != null) {
        porId.remove(pendente.id);
        _midiasPendentes.remove(pendente.id);
      }
      porId[m.id] = m;
    }

    _mensagens = porId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// `clientMessageId` é a chave primária de reconciliação — o backend persiste
  /// e devolve o campo. `midiaRef` e conteúdo ficam como fallback para
  /// mensagens criadas antes da coluna existir.
  MensagemModel? _acharPendenteCorrespondente(MensagemModel confirmada) {
    for (final m in _mensagens) {
      if (!m.isPending && !m.falhou) continue;

      if (m.clientMessageId != null &&
          m.clientMessageId == confirmada.clientMessageId) {
        return m;
      }
      if (m.tipo != confirmada.tipo) continue;
      if (m.midiaRef != null && m.midiaRef == confirmada.midiaRef) return m;
      if (m.tipo == 'TEXTO' && m.conteudo == confirmada.conteudo) return m;
    }
    return null;
  }

  void _marcarFalha(String tempId) {
    final i = _mensagens.indexWhere((m) => m.id == tempId);
    if (i != -1) {
      _mensagens[i] = _mensagens[i].copyWith(isPending: false, falhou: true);
    }
  }

  // ─── inicialização ────────────────────────────────────────────────────────

  Future<void> _inicializar() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final diagnosticoId = args?['diagnosticoId'] as String?;
    final diagnosticoTexto = args?['diagnosticoTexto'] as String?;
    final conversaIdArg = args?['conversaId'] as String?;

    _myUserId = await AuthStorage.getUserId();
    _myUserName = await AuthStorage.getUserName();
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
    ChatReadTracker.setConversaAberta(conversaId);

    // Se o argumento 'disponivel' for passado como true, somos atendentes abrindo
    // um chamado disponível pela primeira vez. Tentamos reivindicar antes de buscar.
    final isDisponivel = args?['disponivel'] == true;

    if (isDisponivel) {
      final role = await AuthStorage.getUserRole();
      final normalizedRole = role?.trim().toUpperCase() ?? '';
      final isAtendente = normalizedRole == 'ADMIN' || normalizedRole == 'ASSISTENTE';
      if (isAtendente) {
        // Como o atendente clicou no card disponível de Esquema Elétrico, reivindica
        await ChatService.reivindicarConversa(token: _token!, conversaId: conversaId);
      }
    }

    var convResult =
        await ChatService.buscarConversa(token: _token!, conversaId: conversaId);

    if (!mounted) return;

    // Se der 403 (e não foi reivindicado acima por falta da flag), verificamos se é
    // do tipo ESQUEMA_ELETRICO. Se for, o atendente assume automaticamente (fallback URL/Push).
    if (convResult['statusCode'] == 403) {
      final role = await AuthStorage.getUserRole();
      final normalizedRole = role?.trim().toUpperCase() ?? '';
      final isAtendente = normalizedRole == 'ADMIN' || normalizedRole == 'ASSISTENTE';

      if (isAtendente) {
        // Tenta obter os detalhes da solicitação de esquema elétrico. Se for sucesso, sabemos que é do tipo ESQUEMA_ELETRICO.
        final esqDet = await EsquemaService.obterDetalhe(token: _token!, conversaId: conversaId);
        if (esqDet['success'] == true) {
          final claimRes = await ChatService.reivindicarConversa(token: _token!, conversaId: conversaId);
          if (claimRes['success'] == true) {
            convResult = await ChatService.buscarConversa(token: _token!, conversaId: conversaId);
            if (!mounted) return;
          }
        }
      }
    }

    if (convResult['statusCode'] == 403) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Você não tem acesso a esta conversa.';
      });
      return;
    }

    if (convResult['success'] == true) {
      final data = convResult['data'] as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      final atendenteId = data['atendenteId']?.toString();
      final tipo = data['tipo']?.toString()?.toUpperCase() ?? '';

      setState(() {
        _conversaStatus = status;
        _clienteId = data['clienteId']?.toString();
      });

      // Se for atendente e o status de ESQUEMA_ELETRICO ainda estiver aguardando/pendente ou sem atendente atribuído
      final role = await AuthStorage.getUserRole();
      final normalizedRole = role?.trim().toUpperCase() ?? '';
      final isAtendente = normalizedRole == 'ADMIN' || normalizedRole == 'ASSISTENTE';

      if (isAtendente && tipo == 'ESQUEMA_ELETRICO' && (status == 'AGUARDANDO' || status == 'PENDENTE' || atendenteId == null || atendenteId.isEmpty)) {
        final claimRes = await ChatService.reivindicarConversa(token: _token!, conversaId: conversaId);
        if (claimRes['success'] == true && mounted) {
          setState(() {
            _conversaStatus = 'EM_ATENDIMENTO';
          });
          ChatReadTracker.markRead(conversaId);
        }
      }
    }

    final atResult =
        await AtendimentoService.listarAtendentesOnline(token: _token!);
    if (atResult['success'] == true && mounted) {
      setState(() => _atendentesOnlineCount = atResult['total'] as int? ?? 0);
    }

    await _carregarMensagens(pagina: 1);

    _realtimeService.start(
      token: _token!,
      conversaId: conversaId,
      onFetch: () async {
        final result = await ChatService.buscarMensagens(
          token: _token!,
          conversaId: conversaId!,
          pagina: 1,
          porPagina: _porPagina,
        );
        if (result['success'] == true) {
          final data = result['data'];
          if (data is Map) {
            return (data['dados'] as List? ?? []).cast<Map<String, dynamic>>();
          }
          if (data is List) return data.cast<Map<String, dynamic>>();
        }
        return <Map<String, dynamic>>[];
      },
      onUpdate: (rawList) {
        if (!mounted) return;
        setState(() => _fundir(rawList.map(MensagemModel.fromJson)));
      },
      onWsMessage: (json) {
        if (json['conteudo'] == null && json['content'] == null) return;
        try {
          final msg = MensagemModel.fromJson(json);
          if (!mounted) return;
          setState(() => _fundir([msg]));
        } catch (e) {
          loggerService.w('mensagem WS inválida: $e');
        }
      },
      onMensagensLidas: (leitorId) {
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
        return data['id']?.toString();
      }
    }

    final createResult = await ChatService.criarConversa(
      token: token,
      aiDiagnosticoId: diagnosticoId,
    );
    if (createResult['success'] != true) return null;

    final convId =
        (createResult['data'] as Map<String, dynamic>)['id']?.toString();

    if (convId != null &&
        diagnosticoTexto != null &&
        diagnosticoTexto.isNotEmpty) {
      await ChatService.enviarMensagem(
        token: token,
        conversaId: convId,
        conteudo: diagnosticoTexto,
        clientMessageId: _uuid.v4(),
      );
    }
    return convId;
  }

  // ─── carregamento ─────────────────────────────────────────────────────────

  Future<void> _carregarMensagens({int pagina = 1}) async {
    if (_conversaId == null || _token == null) return;

    final result = await ChatService.buscarMensagens(
      token: _token!,
      conversaId: _conversaId!,
      pagina: pagina,
      porPagina: _porPagina,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'];
      final List<MensagemModel> lista;
      int totalPaginas = 1;

      if (data is Map) {
        lista = (data['dados'] as List? ?? [])
            .map((j) => MensagemModel.fromJson(j as Map<String, dynamic>))
            .toList();
        totalPaginas =
            int.tryParse(data['totalPaginas']?.toString() ?? '1') ?? 1;
      } else if (data is List) {
        lista = data
            .map((j) => MensagemModel.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        lista = const [];
      }

      setState(() {
        _fundir(lista);
        _paginaAtual = pagina;
        _temMaisMensagens = pagina < totalPaginas;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message']?.toString();
      });
    }
  }

  Future<void> _carregarMaisMensagens() async {
    if (!_temMaisMensagens ||
        _isCarregandoMais ||
        _conversaId == null ||
        _token == null) {
      return;
    }

    setState(() => _isCarregandoMais = true);

    final proximaPagina = _paginaAtual + 1;
    final result = await ChatService.buscarMensagens(
      token: _token!,
      conversaId: _conversaId!,
      pagina: proximaPagina,
      porPagina: _porPagina,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'];
      List<MensagemModel> novas = const [];
      int totalPaginas = _paginaAtual;

      if (data is Map) {
        novas = (data['dados'] as List? ?? [])
            .map((j) => MensagemModel.fromJson(j as Map<String, dynamic>))
            .toList();
        totalPaginas =
            int.tryParse(data['totalPaginas']?.toString() ?? '1') ?? 1;
      }

      setState(() {
        _fundir(novas);
        _paginaAtual = proximaPagina;
        _temMaisMensagens = proximaPagina < totalPaginas;
        _isCarregandoMais = false;
      });
    } else {
      setState(() => _isCarregandoMais = false);
    }
  }

  /// Renova o SAS de UMA mídia.
  ///
  /// Antes isso recarregava a página 1 inteira só para reassinar. Com
  /// `POST /chat/midias/urls` a renovação é pontual — e funciona para mensagem
  /// de qualquer página, não só a primeira.
  Future<String?> _renovarUrlDe(String mensagemId) async {
    if (_token == null) return null;

    final i = _mensagens.indexWhere((m) => m.id == mensagemId);
    if (i == -1) return null;

    final referencia = _mensagens[i].midiaRef;
    if (referencia == null) return null;

    final urls = await ChatService.resolverUrlsMidia(
      token: _token!,
      referencias: [referencia],
    );

    final nova = urls[referencia];
    if (nova == null || !mounted) return null;

    setState(() {
      final j = _mensagens.indexWhere((m) => m.id == mensagemId);
      if (j != -1) _mensagens[j] = _mensagens[j].copyWith(midiaUrl: nova);
    });

    return nova;
  }

  // ─── envio de texto ───────────────────────────────────────────────────────

  Future<void> _enviarMensagem() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty || _conversaId == null || _isSending || _token == null) {
      return;
    }

    final clientId = _uuid.v4();

    setState(() {
      _mensagens.insert(
        0,
        MensagemModel(
          id: clientId,
          clientMessageId: clientId,
          tipo: 'TEXTO',
          conteudo: texto,
          createdAt: DateTime.now(),
          isPending: true,
        ),
      );
      _isSending = true;
      _messageController.clear();
    });

    final result = await ChatService.enviarMensagem(
      token: _token!,
      conversaId: _conversaId!,
      conteudo: texto,
      clientMessageId: clientId,
    );

    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (result['success'] == true) {
        _fundir(
            [MensagemModel.fromJson(result['data'] as Map<String, dynamic>)]);
      } else {
        _marcarFalha(clientId);
      }
    });

    if (result['success'] != true) {
      _mostrarErro(result['message']?.toString() ?? 'Erro ao enviar mensagem.');
    }
  }

  /// Reenvio com o MESMO `clientMessageId`: o índice único no backend garante
  /// que uma tentativa que chegou mas não respondeu não vira mensagem duplicada.
  Future<void> _reenviar(MensagemModel msg) async {
    if (_token == null || _conversaId == null) return;

    final clientId = msg.clientMessageId ?? msg.id;

    setState(() {
      final i = _mensagens.indexWhere((m) => m.id == msg.id);
      if (i != -1) {
        _mensagens[i] = _mensagens[i].copyWith(isPending: true, falhou: false);
      }
    });

    final midia = _midiasPendentes[msg.id];

    final result = midia != null
        ? await ChatService.enviarMidia(
            token: _token!,
            conversaId: _conversaId!,
            tipo: midia.tipo,
            bytes: midia.bytes,
            fileName: midia.fileName,
            contentType: midia.contentType,
            clientMessageId: clientId,
          )
        : await ChatService.enviarMensagem(
            token: _token!,
            conversaId: _conversaId!,
            conteudo: msg.conteudo,
            tipo: msg.tipo,
            midiaRef: msg.midiaRef,
            clientMessageId: clientId,
          );

    if (!mounted) return;

    setState(() {
      if (result['success'] == true) {
        _fundir(
            [MensagemModel.fromJson(result['data'] as Map<String, dynamic>)]);
      } else {
        _marcarFalha(msg.id);
      }
    });
  }

  void _descartar(MensagemModel msg) {
    setState(() {
      _mensagens.removeWhere((m) => m.id == msg.id);
      _midiasPendentes.remove(msg.id);
    });
  }

  // ─── imagem ───────────────────────────────────────────────────────────────

  Future<void> _escolherOrigemImagem() async {
    if (kIsWeb) {
      await _selecionarEEnviarImagem(ImageSource.gallery);
      return;
    }

    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (origem != null) await _selecionarEEnviarImagem(origem);
  }

  Future<void> _selecionarEEnviarImagem(ImageSource origem) async {
    if (_conversaId == null || _token == null || _isUploadingImage) return;

    final XFile? escolhida = await _imagePicker.pickImage(
      source: origem,
      // 1600 px preserva texto de etiqueta de ECU. A 800 px o código da
      // central vira borrão — que é o motivo de a foto existir.
      maxWidth: 1600,
      imageQuality: 85,
      requestFullMetadata: false, // iOS: sem prompt de localização, sem GPS
    );
    if (escolhida == null) return;

    Uint8List bytes;
    try {
      bytes = await _comprimir(escolhida);
    } catch (e) {
      loggerService.e('falha ao comprimir imagem: $e');
      _mostrarErro('Não foi possível processar a imagem.');
      return;
    }

    // Valida DEPOIS de comprimir: uma foto de 12 MP que viraria 500 KB era
    // rejeitada na cara do usuário pelo limite aplicado antes.
    if (bytes.length > 15 * 1024 * 1024) {
      _mostrarErro('Imagem muito grande. Máximo: 15 MB.');
      return;
    }

    setState(() => _isUploadingImage = true);

    // Sempre .jpg: a compressão encoda JPEG. Manter .png no nome gravava
    // Content-Type image/png sobre bytes JPEG.
    await _enviarMidia(
      bytes: bytes,
      fileName: '${_uuid.v4()}.jpg',
      contentType: 'image/jpeg',
      tipo: 'IMAGEM',
      aoFinalizar: () => _isUploadingImage = false,
    );
  }

  /// `package:image` decodifica em Dart puro na isolate principal: 2–5 s de
  /// congelamento em Android intermediário, e o bitmap (w*h*4) somado ao
  /// buffer de saída estourava a memória.
  Future<Uint8List> _comprimir(XFile arquivo) async {
    if (kIsWeb) return arquivo.readAsBytes();

    final resultado = await FlutterImageCompress.compressWithFile(
      arquivo.path,
      minWidth: 1600,
      minHeight: 1600,
      quality: 85,
      autoCorrectionAngle: true, // aplica orientação EXIF
      format: CompressFormat.jpeg,
    );

    return resultado ?? await arquivo.readAsBytes();
  }

  // ─── áudio ────────────────────────────────────────────────────────────────

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
          _mostrarErro('Permissão de microfone negada.');
          return;
        }
        final dir = await getTemporaryDirectory();
        await _audioRecorder.start(
          // AAC: o iOS não decodifica Opus/WebM.
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: '${dir.path}/audio_${_uuid.v4()}.m4a',
        );
      }

      if (mounted) {
        setState(() => _isRecordingAudio = true);
        _iniciarTimerGravacao();
      }
    } catch (e) {
      loggerService.e('falha ao iniciar gravação: $e');
      _mostrarErro('Não foi possível iniciar a gravação.');
    }
  }

  Future<void> _pararEEnviarAudio() async {
    _pararTimerGravacao();

    final Uint8List? webBytes = kIsWeb ? await _webAudioRecorder.stop() : null;
    final path = kIsWeb ? null : await _audioRecorder.stop();

    if (mounted) setState(() => _isRecordingAudio = false);
    if ((path == null && webBytes == null) ||
        _conversaId == null ||
        _token == null) {
      return;
    }

    final Uint8List bytes;
    if (kIsWeb) {
      bytes = webBytes!;
    } else {
      try {
        final file = File(path!);
        bytes = await file.readAsBytes();
        await file.delete();
      } catch (e) {
        loggerService.e('Erro ao ler áudio: $e');
        _mostrarErro('Não foi possível ler a gravação.');
        return;
      }
    }

    setState(() => _isUploadingAudio = true);

    await _enviarMidia(
      bytes: bytes,
      fileName: kIsWeb ? '${_uuid.v4()}.webm' : '${_uuid.v4()}.m4a',
      contentType: kIsWeb ? 'audio/webm' : 'audio/mp4',
      tipo: 'AUDIO',
      aoFinalizar: () => _isUploadingAudio = false,
    );
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

  // ─── envio de mídia ───────────────────────────────────────────────────────

  /// UMA requisição: upload e criação da mensagem.
  ///
  /// O fluxo anterior era `upload-arquivo` → `enviar`. Se o segundo passo
  /// falhasse, o blob ficava órfão e pago; e o cliente escolhia a string de
  /// referência, o que permitia apontar para mídia alheia.
  Future<void> _enviarMidia({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String tipo,
    required VoidCallback aoFinalizar,
  }) async {
    final clientId = _uuid.v4();

    setState(() {
      _mensagens.insert(
        0,
        MensagemModel(
          id: clientId,
          clientMessageId: clientId,
          tipo: tipo,
          conteudo: '',
          createdAt: DateTime.now(),
          isPending: true,
        ),
      );
      // Retido para reenvio: o arquivo já foi processado, pedir de novo ao
      // usuário seria perder trabalho feito.
      _midiasPendentes[clientId] = _MidiaPendente(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        tipo: tipo,
      );
    });

    final result = await ChatService.enviarMidia(
      token: _token!,
      conversaId: _conversaId!,
      tipo: tipo,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      clientMessageId: clientId,
    );

    if (!mounted) return;

    setState(() {
      aoFinalizar();
      if (result['success'] == true) {
        _fundir(
            [MensagemModel.fromJson(result['data'] as Map<String, dynamic>)]);
      } else {
        _marcarFalha(clientId);
      }
    });

    if (result['success'] != true) {
      _mostrarErro(result['message']?.toString() ?? 'Erro ao enviar arquivo.');
    }
  }

  // ─── conversa ─────────────────────────────────────────────────────────────

  Future<void> _encerrarConversa() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar conversa'),
        content: const Text(
          'Deseja encerrar esta conversa e marcar o problema como resolvido?'
          '\n\nApós encerrado, não será possível enviar novas mensagens.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C)),
            child: const Text('Problema resolvido',
                style: TextStyle(color: Colors.white)),
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
      setState(() => _conversaStatus = 'ENCERRADA');
      ChatReadTracker.markRead(_conversaId!);
    } else {
      _mostrarErro(
          result['message']?.toString() ?? 'Erro ao encerrar conversa.');
    }
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: AppColors.statusUrgent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isMinhaMensagem(MensagemModel msg) {
    if (msg.isPending || msg.falhou) return true;
    if (_myUserId == null || _myUserId!.isEmpty) return false;
    return msg.usuario?.id == _myUserId;
  }

  String _formatarHora(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _abrirImagemFullscreen(MensagemModel msg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(
          url: msg.midiaUrl!,
          cacheKey: msg.midiaRef,
          aoTentarNovamente: () => _renovarUrlDe(msg.id),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/chat',
      title: context.isDesktop ? 'Chat' : '',
      showAppBar: !context.isDesktop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop ? null : _buildAppBar(),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed))
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

  PreferredSizeWidget _buildAppBar() {
    final online = _atendentesOnlineCount > 0;

    return AppBar(
      title: Row(
        children: [
          const Text('Chat'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: online ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    online ? const Color(0xFF4CAF50) : const Color(0xFFBDBDBD),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle,
                    size: 8,
                    color: online
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF9E9E9E)),
                const SizedBox(width: 4),
                Text(
                  online
                      ? '$_atendentesOnlineCount Atendente${_atendentesOnlineCount > 1 ? 's' : ''} Online'
                      : 'IA Pronta',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: online
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF616161),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline,
                color: AppColors.primaryRed, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
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
                  backgroundColor: AppColors.primaryRed),
              child:
                  const Text('Voltar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaMensagens() {
    if (_mensagens.isEmpty) {
      return const Center(
        child: Text('Nenhuma mensagem ainda.',
            style: TextStyle(color: AppColors.textLight)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
      itemCount: _mensagens.length + (_temMaisMensagens ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _mensagens.length) return _buildCarregarMais();

        final msg = _mensagens[index];

        // Sem key, o State é reaproveitado por POSIÇÃO: mensagem nova entra em
        // index 0, desloca todas, e a bolha de áudio passa a controlar o player
        // de outra mensagem.
        return KeyedSubtree(
          key: ValueKey(msg.id),
          child: _buildBolhaMensagem(msg),
        );
      },
    );
  }

  Widget _buildCarregarMais() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: _isCarregandoMais
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryRed),
              )
            : TextButton.icon(
                onPressed: _carregarMaisMensagens,
                icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                label: const Text('Carregar mensagens anteriores',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary),
              ),
      ),
    );
  }

  Widget _buildBolhaMensagem(MensagemModel msg) {
    final isMeu = _isMinhaMensagem(msg);
    final temMidia = msg.midiaPronta && !msg.isPending;

    final EdgeInsets bubblePadding;
    if (msg.tipo == 'IMAGEM' && temMidia) {
      bubblePadding = const EdgeInsets.all(4);
    } else if (msg.tipo == 'AUDIO' && temMidia) {
      bubblePadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 10);
    } else {
      bubblePadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMeu ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMeu)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: AppColors.iconBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.support_agent,
                  size: 18, color: AppColors.textPrimary),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMeu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMeu && msg.usuario != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(msg.usuario!.nome,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
                  ),
                if (isMeu && _myUserName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, right: 4),
                    child: Text(_myUserName!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
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
                        color: msg.falhou
                            ? AppColors.statusUrgent
                            : isMeu
                                ? AppColors.primaryRed.withValues(alpha: 0.3)
                                : AppColors.border,
                      ),
                    ),
                    child: _buildConteudoBolha(msg, isMeu),
                  ),
                ),
                _buildRodapeBolha(msg, isMeu),
              ],
            ),
          ),
          if (isMeu) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                  color: AppColors.primaryRed, shape: BoxShape.circle),
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRodapeBolha(MensagemModel msg, bool isMeu) {
    if (msg.falhou) {
      return Padding(
        padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 12, color: AppColors.statusUrgent),
            const SizedBox(width: 4),
            const Text('Não enviada',
                style: TextStyle(fontSize: 10, color: AppColors.statusUrgent)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _reenviar(msg),
              child: const Text('Reenviar',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _descartar(msg),
              child: const Text('Descartar',
                  style: TextStyle(fontSize: 10, color: AppColors.textLight)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_formatarHora(msg.createdAt),
              style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          if (msg.isPending) ...[
            const SizedBox(width: 4),
            const Icon(Icons.access_time, size: 10, color: AppColors.textLight),
          ],
          if (isMeu && !msg.isPending) ...[
            const SizedBox(width: 4),
            Icon(
              msg.readAt != null ? Icons.done_all : Icons.done,
              size: 13,
              color: msg.readAt != null ? Colors.blue : AppColors.textLight,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConteudoBolha(MensagemModel msg, bool isMeu) {
    if (msg.tipo == 'AUDIO') {
      if (msg.isPending) return _placeholderMidia(180, 44);
      if (!msg.midiaPronta) {
        return MidiaIndisponivel(
          texto: 'Áudio indisponível',
          aoTentarNovamente: () => _renovarUrlDe(msg.id),
        );
      }
      return AudioBubble(
        mensagemId: msg.id,
        url: msg.midiaUrl!,
        isMeu: isMeu,
        controller: _audioController,
        aoExpirar: () => _renovarUrlDe(msg.id),
      );
    }

    if (msg.tipo == 'IMAGEM' || msg.tipo == 'DOCUMENTO') {
      if (msg.isPending) return _placeholderMidia(160, 120);

      // Referência não resolvida = bug de backend (mapper sem o mapa de URLs).
      // O fallback antigo montava `${baseUrl}chat/...jpg` e recebia 404 mudo.
      if (!msg.midiaPronta) {
        return MidiaIndisponivel(
            aoTentarNovamente: () => _renovarUrlDe(msg.id));
      }

      return ImagemChat(
        url: msg.midiaUrl!,
        cacheKey: msg.midiaRef,
        largura: 220,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
          bottomLeft: Radius.circular(isMeu ? 10 : 0),
          bottomRight: Radius.circular(isMeu ? 0 : 10),
        ),
        aoTocar: () => _abrirImagemFullscreen(msg),
        aoTentarNovamente: () => _renovarUrlDe(msg.id),
      );
    }

    return MarkdownBody(
      data: msg.conteudo,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
            fontSize: 14, color: AppColors.textPrimary, height: 1.45),
        strong: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold),
        h2: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold),
        h3: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold),
        listBullet:
            const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        blockSpacing: 8,
      ),
      shrinkWrap: true,
      softLineBreak: true,
    );
  }

  Widget _placeholderMidia(double w, double h) => SizedBox(
        width: w,
        height: h,
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primaryRed),
        ),
      );

  Widget _buildBannerEncerrada() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        border: Border(top: BorderSide(color: Color(0xFF388E3C), width: 1)),
      ),
      child: const SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF388E3C), size: 18),
            SizedBox(width: 8),
            Text('Problema resolvido — conversa encerrada',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF388E3C),
                )),
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
              maxWidth: context.isDesktop ? 1200 : double.infinity),
          child: Row(
            children: [
              _isUploadingImage
                  ? _spinnerBotao()
                  : IconButton(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: _escolherOrigemImagem,
                      color: AppColors.textSecondary,
                      tooltip: 'Enviar imagem',
                    ),
              _isUploadingAudio
                  ? _spinnerBotao()
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
              if (_isDonoDaConversa) ...[
                Tooltip(
                  message: 'Problema resolvido — encerrar conversa',
                  child: _isEncerrandoConversa
                      ? _spinnerBotao(cor: const Color(0xFF388E3C))
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: const Color(0xFF388E3C)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.check_circle_outline,
                                color: Color(0xFF388E3C)),
                            onPressed: _encerrarConversa,
                          ),
                        ),
                ),
                const SizedBox(width: 4),
              ],
              _isSending
                  ? _spinnerBotao()
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
                        color: AppColors.primaryRed, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text('Gravando...',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                  Text(_formatarDuracaoGravacao(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed,
                      )),
                ],
              ),
            ),
            _isUploadingAudio
                ? _spinnerBotao()
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

  Widget _spinnerBotao({Color cor = AppColors.primaryRed}) => Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: cor),
        ),
      );

  @override
  void dispose() {
    ChatReadTracker.setConversaAberta(null);
    _scrollController.removeListener(_onScroll);
    _realtimeService.stop();
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioController.dispose();
    _midiasPendentes.clear();
    super.dispose();
  }
}