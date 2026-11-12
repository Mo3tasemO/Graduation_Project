import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspeak_flutter/bluetooth/headset_bluetooth.dart';
import 'package:mindspeak_flutter/home/home_repository.dart';
import 'package:mindspeak_flutter/home/home_screen.dart';
import 'package:mindspeak_flutter/home/speech_controller.dart';

void main() {
  testWidgets('manual text and quick phrases speak only after a user tap', (
    tester,
  ) async {
    final repo = _FakeHomeRepository();
    final speech = _FakeSpeechEngine();
    await tester.pumpWidget(_home(repo, speech));
    await tester.pumpAndSettle();

    expect(speech.spoken, isEmpty);
    expect(find.text('I need help'), findsOneWidget);
    expect(find.text('I am thirsty'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);

    await tester.tap(find.text('I need help'));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const Key('home_message_field')),
    );
    expect(field.controller!.text, 'I need help');
    await tester.enterText(
      find.byKey(const Key('home_message_field')),
      'Please help me now',
    );
    await tester.tap(find.byKey(const Key('speak_button')));
    await tester.pumpAndSettle();

    expect(speech.spoken, ['Please help me now']);
    expect(repo.history.single.text, 'Please help me now');
    expect(
      find.text('BLE Connected · EEG device not configured'),
      findsOneWidget,
    );
  });

  testWidgets('empty messages are rejected and speech can be stopped', (
    tester,
  ) async {
    final speech = _FakeSpeechEngine();
    await tester.pumpWidget(_home(_FakeHomeRepository(), speech));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('home_message_field')), '   ');
    await tester.tap(find.byKey(const Key('speak_button')));
    await tester.pump();
    expect(find.text('Enter a message before speaking.'), findsOneWidget);
    expect(speech.spoken, isEmpty);

    await tester.enterText(
      find.byKey(const Key('home_message_field')),
      'Hello',
    );
    await tester.tap(find.byKey(const Key('speak_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stop_speech_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stop_speech_button')));
    await tester.pumpAndSettle();
    expect(speech.stopCount, 1);
    expect(find.byKey(const Key('speak_button')), findsOneWidget);
  });

  testWidgets(
    'custom phrases can be added and deletion requires confirmation',
    (tester) async {
      final repo = _FakeHomeRepository();
      await tester.pumpWidget(_home(repo, _FakeSpeechEngine()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_phrase_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Call my family');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Call my family'), findsOneWidget);
      expect(repo.phrases, hasLength(2));

      await tester.tap(find.byTooltip('Edit or delete Call my family'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete phrase'));
      await tester.pumpAndSettle();
      expect(find.text('Delete saved phrase?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.phrases, hasLength(2));

      await tester.tap(find.byTooltip('Edit or delete Call my family'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete phrase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(repo.phrases, hasLength(1));
      expect(find.text('Call my family'), findsNothing);
    },
  );

  testWidgets(
    'profile loads user, settings, and logout; BLE loss leaves TTS available',
    (tester) async {
      final gateway = _FakeGateway();
      final repo = _FakeHomeRepository();
      final speech = _FakeSpeechEngine();
      var loggedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            gateway: gateway,
            repository: repo,
            speechEngine: speech,
            onLogout: () => loggedOut = true,
            onReconnect: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      gateway.emit(
        const HeadsetSnapshot(status: HeadsetConnectionStatus.connectionLost),
      );
      await tester.pump();
      expect(
        find.text('Disconnected · EEG device not configured'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('profile_button')));
      await tester.pumpAndSettle();
      expect(find.text('Test User'), findsOneWidget);
    expect(find.textContaining('test@example.com'), findsOneWidget);
      expect(find.textContaining('Email verified'), findsOneWidget);
      expect(find.byKey(const Key('speech_language_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('speech_voice_dropdown')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('logout_button')));
      await tester.tap(find.byKey(const Key('logout_button')));
      expect(loggedOut, isTrue);
    },
  );

  testWidgets(
    'history displays recent messages and replays a selected message',
    (tester) async {
      final repo = _FakeHomeRepository();
      final speech = _FakeSpeechEngine();
      await tester.pumpWidget(_home(repo, speech));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('speak_button')));
      await tester.pumpAndSettle();
      speech.complete?.call();
      await tester.pump();
      await tester.tap(find.byTooltip('Message history'));
      await tester.pumpAndSettle();
      expect(find.text('I need water'), findsOneWidget);
      expect(find.textContaining('202'), findsOneWidget);
      await tester.tap(find.text('I need water'));
      await tester.pumpAndSettle();
      expect(speech.spoken, ['I need water', 'I need water']);
    },
  );
}

Widget _home(_FakeHomeRepository repository, _FakeSpeechEngine speech) =>
    MaterialApp(
      home: HomeScreen(
        gateway: _FakeGateway(),
        repository: repository,
        speechEngine: speech,
        onLogout: () {},
        onReconnect: () {},
      ),
    );

class _FakeSpeechEngine implements SpeechEngine {
  VoidCallback? start;
  VoidCallback? complete;
  ValueChanged<Object?>? error;
  VoidCallback? cancel;
  final spoken = <String>[];
  int stopCount = 0;

  @override
  void setHandlers({
    required VoidCallback onStart,
    required VoidCallback onComplete,
    required ValueChanged<Object?> onError,
    required VoidCallback onCancel,
  }) {
    start = onStart;
    complete = onComplete;
    error = onError;
    cancel = onCancel;
  }

  @override
  Future<List<String>> getLanguages() async => ['en-US', 'ar'];
  @override
  Future<List<SpeechVoice>> getVoices() async => const [
    SpeechVoice(name: 'Test Voice', locale: 'en-US'),
  ];
  @override
  Future<void> setLanguage(String language) async {}
  @override
  Future<void> setVoice(SpeechVoice? voice) async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    start?.call();
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    cancel?.call();
  }
}

class _FakeHomeRepository implements HomeRepository {
  final List<SavedPhrase> phrases = [
    const SavedPhrase(id: 1, text: 'Good morning'),
  ];
  final List<SpeechHistoryEntry> history = [];
  int _nextPhraseId = 2;
  int _nextHistoryId = 1;

  @override
  Future<Map<String, dynamic>> loadProfile() async => {
    'name': 'Test User',
    'email': 'test@example.com',
    'email_verified_at': '2026-01-01T00:00:00Z',
  };
  @override
  Future<List<SavedPhrase>> loadPhrases() async => List.of(phrases);
  @override
  Future<SavedPhrase> createPhrase(String text) async {
    final item = SavedPhrase(id: _nextPhraseId++, text: text);
    phrases.add(item);
    return item;
  }

  @override
  Future<SavedPhrase> updatePhrase(int id, String text) async {
    final index = phrases.indexWhere((item) => item.id == id);
    final item = SavedPhrase(id: id, text: text);
    phrases[index] = item;
    return item;
  }

  @override
  Future<void> deletePhrase(int id) async =>
      phrases.removeWhere((item) => item.id == id);
  @override
  Future<List<SpeechHistoryEntry>> loadHistory() async =>
      List.of(history.reversed);
  @override
  Future<SpeechHistoryEntry> addHistory(String text) async {
    final item = SpeechHistoryEntry(
      id: _nextHistoryId++,
      text: text,
      createdAt: DateTime.utc(2026),
    );
    history.add(item);
    return item;
  }

  @override
  Future<void> deleteHistory(int id) async =>
      history.removeWhere((item) => item.id == id);
  @override
  Future<void> clearHistory() async => history.clear();
  @override
  Future<Map<String, dynamic>> loadPreferences() async => {
    'language': 'en-US',
    'voice_name': null,
    'voice_locale': null,
    'rate': 0.45,
    'volume': 1.0,
  };
  @override
  Future<Map<String, dynamic>> savePreferences(
    Map<String, Object?> value,
  ) async => Map.of(value);
}

class _FakeGateway implements HeadsetBluetoothGateway {
  final _changes = StreamController<HeadsetSnapshot>.broadcast(sync: true);
  HeadsetSnapshot _snapshot = const HeadsetSnapshot(
    status: HeadsetConnectionStatus.connected,
    devices: [HeadsetDevice(id: 'headset', name: 'Test BLE headset')],
    selectedDeviceId: 'headset',
  );
  @override
  HeadsetSnapshot get snapshot => _snapshot;
  @override
  Stream<HeadsetSnapshot> get changes => _changes.stream;
  void emit(HeadsetSnapshot value) {
    _snapshot = value;
    _changes.add(value);
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> scan() async {}
  @override
  void selectDevice(String? deviceId) {}
  @override
  Future<void> connectSelected() async {}
  @override
  Future<void> reconnect() async {}
  @override
  Future<bool> openBluetoothSettings() async => false;
  @override
  void dispose() => _changes.close();
}
