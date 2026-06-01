import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

class WebAudioRecorder {
  html.MediaStream? _stream;
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = [];
  bool isRecording = false;

  Future<void> init() async {
    // nothing for now
  }

  Future<void> start() async {
    if (isRecording) return;
    try {
      _stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
      });
      _recorder = html.MediaRecorder(_stream!);
      _chunks.clear();
      _recorder!.addEventListener('dataavailable', (event) {
        try {
          final be = event as html.BlobEvent;
          if (be.data != null) _chunks.add(be.data!);
        } catch (_) {}
      });
      _recorder!.start();
      isRecording = true;
    } catch (e) {
      rethrow;
    }
  }

  Future<Uint8List?> stop() async {
    if (!isRecording) return null;
    final completer = Completer<Uint8List?>();
    try {
      _recorder!.addEventListener('stop', (_) async {
        try {
          final blob = html.Blob(_chunks, 'audio/webm');
          final reader = html.FileReader();
          reader.readAsArrayBuffer(blob);
          reader.onLoad.listen((_) {
            final result = reader.result;
            if (result is ByteBuffer) {
              final bytes = Uint8List.view(result);
              completer.complete(bytes);
            } else if (result is List<int>) {
              completer.complete(Uint8List.fromList(result));
            } else {
              completer.complete(null);
            }
          });
          reader.onError.listen((e) {
            completer.completeError(e);
          });
        } catch (e) {
          completer.completeError(e);
        }
      });
      _recorder!.stop();
      _stream?.getTracks().forEach((t) => t.stop());
      isRecording = false;
    } catch (e) {
      completer.completeError(e);
    }
    return completer.future;
  }

  Future<void> cancel() async {
    if (!isRecording) return;
    try {
      _recorder?.stop();
    } catch (_) {}
    try {
      _stream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _chunks.clear();
    isRecording = false;
  }
}
