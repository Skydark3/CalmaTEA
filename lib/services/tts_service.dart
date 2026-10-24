import 'package:flutter_tts/flutter_tts.dart';

/// Servicio de texto a voz (TTS) para accesibilidad en CalmaTEA.
/// Lee instrucciones en voz alta para personas con TEA con velocidad y tono tranquilos.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _tts.setLanguage('es-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _isInitialized = true;
  }

  /// Leer un texto en voz alta.
  Future<void> speak(String text) async {
    await initialize();
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Detener la reproducción.
  Future<void> stop() async {
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }
}
