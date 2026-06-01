// Conditional export: use web implementation when available
export 'web_audio_recorder_io.dart'
    if (dart.library.html) 'web_audio_recorder_web.dart';
