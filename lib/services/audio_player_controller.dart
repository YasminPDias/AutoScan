import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'logger_service.dart';

/// Um unico AudioPlayer para a tela inteira.
///
/// A versao anterior instanciava um AudioPlayer por bolha dentro de uma
/// ListView.builder. Cada instancia aloca um player nativo; uma conversa com
/// 30 audios abria 30 players simultaneos, acima do limite de MediaPlayer no
/// Android. Alem disso, sem `key` nas bolhas o State era reaproveitado por
/// posicao — mensagem nova entrava em index 0, deslocava todas as outras, e a
/// bolha passava a tocar o audio de outra mensagem.
class AudioPlayerController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  String? _mensagemId;
  bool _tocando = false;
  Duration _posicao = Duration.zero;
  Duration _duracao = Duration.zero;
  bool _disposed = false;

  String? get mensagemId => _mensagemId;
  bool get tocando => _tocando;
  Duration get posicao => _posicao;
  Duration get duracao => _duracao;

  bool estaTocando(String id) => _mensagemId == id && _tocando;
  bool estaAtiva(String id) => _mensagemId == id;

  AudioPlayerController() {
    _player.onPlayerStateChanged.listen((s) {
      _tocando = s == PlayerState.playing;
      _notificar();
    });
    _player.onDurationChanged.listen((d) {
      _duracao = d;
      _notificar();
    });
    _player.onPositionChanged.listen((p) {
      _posicao = p;
      _notificar();
    });
    _player.onPlayerComplete.listen((_) {
      _tocando = false;
      _posicao = Duration.zero;
      _notificar();
    });
  }

  /// [obterUrl] e chamado de forma preguicosa: se o SAS tiver expirado, o
  /// chamador pode recarregar a mensagem e devolver uma URL nova.
  Future<void> alternar(
    String mensagemId,
    String url, {
    Future<String?> Function()? aoExpirar,
  }) async {
    if (_mensagemId == mensagemId && _tocando) {
      await _player.pause();
      return;
    }

    if (_mensagemId == mensagemId && !_tocando && _posicao > Duration.zero) {
      await _player.resume();
      return;
    }

    _mensagemId = mensagemId;
    _posicao = Duration.zero;
    _duracao = Duration.zero;
    _notificar();

    try {
      await _player.play(UrlSource(url));
    } catch (e) {
      loggerService.w('audio falhou, tentando renovar URL: $e');

      // TTL do SAS para audio e de 30 min. Com a tela aberta por mais tempo,
      // a URL congelada em memoria expira.
      final nova = await aoExpirar?.call();
      if (nova == null) {
        _mensagemId = null;
        _tocando = false;
        _notificar();
        return;
      }

      try {
        await _player.play(UrlSource(nova));
      } catch (e2) {
        loggerService.e('audio indisponivel: $e2');
        _mensagemId = null;
        _tocando = false;
        _notificar();
      }
    }
  }

  Future<void> buscar(Duration posicao) async {
    if (_mensagemId == null) return;
    await _player.seek(posicao);
  }

  Future<void> parar() async {
    await _player.stop();
    _mensagemId = null;
    _tocando = false;
    _posicao = Duration.zero;
    _notificar();
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _player.dispose();
    super.dispose();
  }
}