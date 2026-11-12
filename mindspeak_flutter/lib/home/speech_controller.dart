import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum SpeechStatus { idle, loading, speaking, stopped, error }

@immutable
class SpeechVoice {
  const SpeechVoice({required this.name, required this.locale});

  final String name;
  final String locale;

  Map<String, String> toPluginVoice() => {'name': name, 'locale': locale};
}

abstract interface class SpeechEngine {
  void setHandlers({
    required VoidCallback onStart,
    required VoidCallback onComplete,
    required ValueChanged<Object?> onError,
    required VoidCallback onCancel,
  });
  Future<List<String>> getLanguages();
  Future<List<SpeechVoice>> getVoices();
  Future<void> setLanguage(String language);
  Future<void> setVoice(SpeechVoice? voice);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<bool> speak(String text);
  Future<void> stop();
}

class FlutterTtsSpeechEngine implements SpeechEngine {
  FlutterTtsSpeechEngine() : _tts = FlutterTts();

  final FlutterTts _tts;

  @override
  void setHandlers({
    required VoidCallback onStart,
    required VoidCallback onComplete,
    required ValueChanged<Object?> onError,
    required VoidCallback onCancel,
  }) {
    _tts.setStartHandler(onStart);
    _tts.setCompletionHandler(onComplete);
    _tts.setErrorHandler(onError);
    _tts.setCancelHandler(onCancel);
  }

  @override
  Future<List<String>> getLanguages() async {
    final result = await _tts.getLanguages;
    return result.map((value) => value.toString()).toSet().toList()..sort();
  }

  @override
  Future<List<SpeechVoice>> getVoices() async {
    final result = await _tts.getVoices;
    final voices = <SpeechVoice>[];
    for (final voice in result) {
      if (voice is! Map) continue;
      final name = voice['name']?.toString().trim() ?? '';
      final locale =
          (voice['locale'] ?? voice['language'])?.toString().trim() ?? '';
      if (name.isNotEmpty && locale.isNotEmpty) {
        voices.add(SpeechVoice(name: name, locale: locale));
      }
    }
    return voices;
  }

  @override
  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

  @override
  Future<void> setVoice(SpeechVoice? voice) async {
    if (voice != null) await _tts.setVoice(voice.toPluginVoice());
  }

  @override
  Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume);
  }

  @override
  Future<bool> speak(String text) async {
    await _tts.awaitSpeakCompletion(false);
    final result = await _tts.speak(text);
    return result == 1 || result == true;
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

class SpeechController extends ChangeNotifier {
  SpeechController({SpeechEngine? engine})
    : _engine = engine ?? FlutterTtsSpeechEngine() {
    _engine.setHandlers(
      onStart: () => _setStatus(SpeechStatus.speaking),
      onComplete: () => _setStatus(SpeechStatus.stopped),
      onError: (error) {
        this.error = _friendlyError(error);
        _setStatus(SpeechStatus.error);
      },
      onCancel: () => _setStatus(SpeechStatus.stopped),
    );
  }

  final SpeechEngine _engine;
  SpeechStatus status = SpeechStatus.idle;
  String? error;
  List<String> languages = const [];
  List<SpeechVoice> voices = const [];
  String language = 'en-US';
  SpeechVoice? voice;
  double rate = 0.45;
  double volume = 1.0;
  bool _disposed = false;
  Future<void>? _initialization;

  bool get isSpeaking =>
      status == SpeechStatus.speaking || status == SpeechStatus.loading;

  Future<void> initialize() => _initialization ??= _loadAvailableVoices();

  Future<void> _loadAvailableVoices() async {
    try {
      final results = await Future.wait([
        _engine.getLanguages(),
        _engine.getVoices(),
      ]);
      voices = results[1] as List<SpeechVoice>;
      final reportedLanguages = results[0] as List<String>;
      languages =
          (reportedLanguages.isNotEmpty
                  ? reportedLanguages
                  : voices.map((item) => item.locale).toSet().toList())
              .toSet()
              .toList()
            ..sort();
      _notify();
    } catch (_) {
      languages = const [];
      voices = const [];
      _notify();
    }
  }

  Future<void> applyPreferences(Map<String, dynamic> preferences) async {
    final storedLanguage = preferences['language'];
    if (storedLanguage is String && storedLanguage.isNotEmpty)
      language = storedLanguage;
    final storedName = preferences['voice_name'];
    final storedLocale = preferences['voice_locale'];
    voice = voices
        .where((item) => item.name == storedName && item.locale == storedLocale)
        .firstOrNull;
    final storedRate = preferences['rate'];
    if (storedRate is num && storedRate >= 0.1 && storedRate <= 1)
      rate = storedRate.toDouble();
    final storedVolume = preferences['volume'];
    if (storedVolume is num && storedVolume >= 0 && storedVolume <= 1)
      volume = storedVolume.toDouble();
    await _applyEngineSettings();
    _notify();
  }

  Future<void> updateLanguage(String value) async {
    if (!languages.contains(value)) return;
    language = value;
    voice = voices.where((item) => item.locale == value).firstOrNull;
    await _engine.setLanguage(value);
    _notify();
  }

  Future<void> updateVoice(SpeechVoice? value) async {
    voice = value;
    if (value != null) {
      language = value.locale;
      await _engine.setLanguage(value.locale);
      await _engine.setVoice(value);
    }
    _notify();
  }

  Future<void> updateRate(double value) async {
    rate = value;
    await _engine.setRate(value);
    _notify();
  }

  Future<void> updateVolume(double value) async {
    volume = value;
    await _engine.setVolume(value);
    _notify();
  }

  Future<void> _applyEngineSettings() async {
    if (languages.contains(language)) {
      await _engine.setLanguage(language);
    } else if (languages.isNotEmpty) {
      language = languages.first;
      await _engine.setLanguage(language);
    }
    await _engine.setVoice(voice);
    await _engine.setRate(rate);
    await _engine.setVolume(volume);
  }

  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) {
      error = 'Enter a message before speaking.';
      _setStatus(SpeechStatus.error);
      return false;
    }
    if (isSpeaking) return false;
    error = null;
    _setStatus(SpeechStatus.loading);
    try {
      await _applyEngineSettings();
      final accepted = await _engine.speak(text.trim());
      if (!accepted && status != SpeechStatus.speaking) {
        throw StateError('Speech was not accepted by the system.');
      }
      if (status == SpeechStatus.loading) _setStatus(SpeechStatus.speaking);
      return true;
    } catch (exception) {
      error = _friendlyError(exception);
      _setStatus(SpeechStatus.error);
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _engine.stop();
      error = null;
      _setStatus(SpeechStatus.stopped);
    } catch (_) {
      error = 'Speech could not be stopped. Try again.';
      _setStatus(SpeechStatus.error);
    }
  }

  String _friendlyError(Object? error) {
    final description = error?.toString().toLowerCase() ?? '';
    if (description.contains('notallowed') || description.contains('gesture')) {
      return 'Allow speech in Chrome, then tap Speak message again.';
    }
    return 'Speech is unavailable right now. Check that a voice is installed and try again.';
  }

  void _setStatus(SpeechStatus value) {
    status = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_engine.stop());
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
