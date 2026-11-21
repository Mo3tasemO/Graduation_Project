import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MindSpeakPreferences extends ChangeNotifier {
  MindSpeakPreferences._();

  static final instance = MindSpeakPreferences._();
  SharedPreferencesAsync? _storage;

  SharedPreferencesAsync? get _store {
    try {
      return _storage ??= SharedPreferencesAsync();
    } on StateError {
      // Widget tests can run without a host platform preferences plugin.
      return null;
    }
  }

  ThemeMode themeMode = ThemeMode.light;
  Locale locale = const Locale('en');
  bool biometricsEnabled = false;
  bool sessionStored = false;
  bool ready = false;

  Future<void> load() async {
    final store = _store;
    final theme = await store?.getString('mindspeak.theme');
    final language = await store?.getString('mindspeak.language');
    biometricsEnabled = await store?.getBool('mindspeak.biometrics') ?? false;
    sessionStored = await store?.getBool('mindspeak.session_stored') ?? false;
    themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    // English and Arabic are the two spoken languages already documented by
    // this project. UI strings use the same locale preference.
    locale = Locale(language == 'ar' ? 'ar' : 'en');
    ready = true;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode value) async {
    themeMode = value;
    await _store?.setString('mindspeak.theme', value.name);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    locale = Locale(language == 'ar' ? 'ar' : 'en');
    await _store?.setString('mindspeak.language', locale.languageCode);
    notifyListeners();
  }

  Future<void> setBiometrics(bool enabled) async {
    biometricsEnabled = enabled;
    await _store?.setBool('mindspeak.biometrics', enabled);
    notifyListeners();
  }

  Future<void> setSessionStored(bool stored) async {
    sessionStored = stored;
    await _store?.setBool('mindspeak.session_stored', stored);
    notifyListeners();
  }
}

class MindSpeakText {
  const MindSpeakText(this.english, [this.arabic]);
  final String english;
  final String? arabic;

  String of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? (arabic ?? english)
      : english;
}

class MindSpeakPalette {
  const MindSpeakPalette({
    required this.background,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
    required this.border,
    required this.softSurface,
  });

  final Color background;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;
  final Color border;
  final Color softSurface;

  static MindSpeakPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const MindSpeakPalette(
            background: Color(0xFF101B26),
            surface: Color(0xFF182838),
            primaryText: Color(0xFFEAF2F8),
            secondaryText: Color(0xFFB1C3D2),
            border: Color(0xFF334A5F),
            softSurface: Color(0xFF20384D),
          )
        : const MindSpeakPalette(
            background: Color(0xFFF5F7FA),
            surface: Colors.white,
            primaryText: Color(0xFF173F5F),
            secondaryText: Color(0xFF5C7185),
            border: Color(0xFFD6E0E9),
            softSurface: Color(0xFFDCE9F4),
          );
  }
}
