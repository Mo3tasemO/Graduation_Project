import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:mindspeak_flutter/app_preferences.dart';

void main() {
  test('theme and UI language are persisted between loads', () async {
    final storage = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = storage;
    final preferences = MindSpeakPreferences.instance;

    await preferences.load();
    await preferences.setTheme(ThemeMode.dark);
    await preferences.setLanguage('ar');

    preferences.themeMode = ThemeMode.light;
    preferences.locale = const Locale('en');
    await preferences.load();

    expect(preferences.themeMode, ThemeMode.dark);
    expect(preferences.locale, const Locale('ar'));
  });
}
