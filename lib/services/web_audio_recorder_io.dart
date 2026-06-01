import 'dart:typed_data';

class WebAudioRecorder {
  bool isRecording = false;
  Future<void> init() async {}
  Future<void> start() async {
    throw UnsupportedError('Web audio recorder is only supported on web.');
  }

  Future<Uint8List?> stop() async {
    throw UnsupportedError('Web audio recorder is only supported on web.');
  }

  Future<void> cancel() async {
    throw UnsupportedError('Web audio recorder is only supported on web.');
  }
}
