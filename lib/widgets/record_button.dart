import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/web_audio_recorder.dart';

typedef OnRecorded = void Function(Uint8List data);

class RecordButton extends StatefulWidget {
  final OnRecorded? onRecorded;
  const RecordButton({Key? key, this.onRecorded}) : super(key: key);

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  late WebAudioRecorder _recorder;
  bool _recording = false;
  bool _supported = kIsWeb;

  @override
  void initState() {
    super.initState();
    _recorder = WebAudioRecorder();
    if (_supported) _recorder.init();
  }

  Future<void> _toggle() async {
    if (!_supported) return;
    if (_recording) {
      final data = await _recorder.stop();
      setState(() => _recording = false);
      if (data != null && widget.onRecorded != null) widget.onRecorded!(data);
    } else {
      try {
        await _recorder.start();
        setState(() => _recording = true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao iniciar microfone: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return const SizedBox.shrink();
    }
    return ElevatedButton.icon(
      onPressed: _toggle,
      icon: Icon(_recording ? Icons.stop : Icons.mic),
      label: Text(_recording ? 'Parar' : 'Gravar'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _recording ? Colors.red : null,
      ),
    );
  }
}
