import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/audio_player_controller.dart';
import '../theme/app_colors.dart';

// ── Placeholder de midia ausente ─────────────────────────────────────────────

class MidiaIndisponivel extends StatelessWidget {
  final String texto;
  final VoidCallback? aoTentarNovamente;
  final bool escuro;

  const MidiaIndisponivel({
    super.key,
    this.texto = 'Mídia indisponível',
    this.aoTentarNovamente,
    this.escuro = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = escuro ? Colors.white54 : AppColors.textLight;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: escuro ? 48 : 36, color: cor),
          const SizedBox(height: 4),
          Text(texto, style: TextStyle(fontSize: escuro ? 14 : 11, color: cor)),
          if (aoTentarNovamente != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: aoTentarNovamente,
              style: TextButton.styleFrom(
                foregroundColor: cor,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Tentar novamente', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Imagem do chat ───────────────────────────────────────────────────────────

class ImagemChat extends StatelessWidget {
  /// URL assinada (SAS). Rotaciona a cada leitura.
  final String url;

  /// Blob path. Chave de cache estavel — sem isso o CachedNetworkImage trata
  /// cada SAS como recurso novo e rebaixa a imagem a cada poll.
  final String? cacheKey;

  final double largura;
  final BorderRadius borderRadius;
  final VoidCallback? aoTocar;
  final VoidCallback? aoTentarNovamente;

  const ImagemChat({
    super.key,
    required this.url,
    required this.cacheKey,
    required this.largura,
    required this.borderRadius,
    this.aoTocar,
    this.aoTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: aoTocar,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: cacheKey,
          width: largura,
          fit: BoxFit.cover,
          placeholder: (_, __) => SizedBox(
            width: largura,
            height: largura * 0.72,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryRed,
              ),
            ),
          ),
          errorWidget: (_, __, ___) =>
              MidiaIndisponivel(aoTentarNovamente: aoTentarNovamente),
        ),
      ),
    );
  }
}

// ── Bolha de audio ───────────────────────────────────────────────────────────

class AudioBubble extends StatelessWidget {
  final String mensagemId;
  final String url;
  final bool isMeu;
  final AudioPlayerController controller;
  final Future<String?> Function()? aoExpirar;

  const AudioBubble({
    super.key,
    required this.mensagemId,
    required this.url,
    required this.isMeu,
    required this.controller,
    this.aoExpirar,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final active = isMeu ? AppColors.primaryRed : AppColors.textPrimary;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ativa = controller.estaAtiva(mensagemId);
        final tocando = controller.estaTocando(mensagemId);

        final posicao = ativa ? controller.posicao : Duration.zero;
        final duracao = ativa ? controller.duracao : Duration.zero;
        final progresso = duracao.inMilliseconds > 0
            ? (posicao.inMilliseconds / duracao.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return SizedBox(
          width: 220,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  tocando ? Icons.pause_circle_filled : Icons.play_circle_filled,
                ),
                color: active,
                iconSize: 32,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => controller.alternar(
                  mensagemId,
                  url,
                  aoExpirar: aoExpirar,
                ),
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
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 8),
                        activeTrackColor: active,
                        inactiveTrackColor: active.withValues(alpha: 0.25),
                        thumbColor: active,
                        overlayColor: active.withValues(alpha: 0.1),
                      ),
                      child: Slider(
                        value: progresso,
                        // onChanged apenas move o thumb; o seek acontece no fim.
                        // Antes o seek disparava a cada pixel arrastado.
                        onChanged: ativa ? (_) {} : null,
                        onChangeEnd: ativa && duracao.inMilliseconds > 0
                            ? (v) => controller.buscar(
                                  Duration(
                                    milliseconds:
                                        (v * duracao.inMilliseconds).round(),
                                  ),
                                )
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        '${_fmt(posicao)} / ${_fmt(duracao)}',
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
      },
    );
  }
}

// ── Visualizador em tela cheia ───────────────────────────────────────────────

class ImageViewerPage extends StatelessWidget {
  final String url;
  final String? cacheKey;
  final VoidCallback? aoTentarNovamente;

  const ImageViewerPage({
    super.key,
    required this.url,
    this.cacheKey,
    this.aoTentarNovamente,
  });

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
          child: CachedNetworkImage(
            imageUrl: url,
            cacheKey: cacheKey,
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                const CircularProgressIndicator(color: Colors.white),
            errorWidget: (_, __, ___) => MidiaIndisponivel(
              escuro: true,
              aoTentarNovamente: aoTentarNovamente,
            ),
          ),
        ),
      ),
    );
  }
}