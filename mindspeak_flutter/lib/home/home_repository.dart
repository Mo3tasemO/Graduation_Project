import '../auth_api.dart';

class SavedPhrase {
  const SavedPhrase({required this.id, required this.text});

  final int id;
  final String text;

  factory SavedPhrase.fromJson(Map<String, dynamic> json) =>
      SavedPhrase(id: json['id'] as int, text: json['text'] as String);
}

class SpeechHistoryEntry {
  const SpeechHistoryEntry({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  final int id;
  final String text;
  final DateTime createdAt;

  factory SpeechHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SpeechHistoryEntry(
        id: json['id'] as int,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

abstract interface class HomeRepository {
  Future<Map<String, dynamic>> loadProfile();
  Future<List<SavedPhrase>> loadPhrases();
  Future<SavedPhrase> createPhrase(String text);
  Future<SavedPhrase> updatePhrase(int id, String text);
  Future<void> deletePhrase(int id);
  Future<List<SpeechHistoryEntry>> loadHistory();
  Future<SpeechHistoryEntry> addHistory(String text);
  Future<void> deleteHistory(int id);
  Future<void> clearHistory();
  Future<Map<String, dynamic>> loadPreferences();
  Future<Map<String, dynamic>> savePreferences(Map<String, Object?> value);
}

class ApiHomeRepository implements HomeRepository {
  const ApiHomeRepository();

  @override
  Future<Map<String, dynamic>> loadProfile() => AuthApi.getProfile();

  @override
  Future<List<SavedPhrase>> loadPhrases() async =>
      (await AuthApi.getCustomPhrases())
          .map((item) => SavedPhrase.fromJson(item as Map<String, dynamic>))
          .toList();

  @override
  Future<SavedPhrase> createPhrase(String text) async =>
      SavedPhrase.fromJson(await AuthApi.createCustomPhrase(text));

  @override
  Future<SavedPhrase> updatePhrase(int id, String text) async =>
      SavedPhrase.fromJson(await AuthApi.updateCustomPhrase(id, text));

  @override
  Future<void> deletePhrase(int id) => AuthApi.deleteCustomPhrase(id);

  @override
  Future<List<SpeechHistoryEntry>> loadHistory() async =>
      (await AuthApi.getMessageHistory())
          .map(
            (item) => SpeechHistoryEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList();

  @override
  Future<SpeechHistoryEntry> addHistory(String text) async =>
      SpeechHistoryEntry.fromJson(await AuthApi.addMessageHistory(text));

  @override
  Future<void> deleteHistory(int id) => AuthApi.deleteMessageHistory(id);

  @override
  Future<void> clearHistory() => AuthApi.clearMessageHistory();

  @override
  Future<Map<String, dynamic>> loadPreferences() =>
      AuthApi.getSpeechPreferences();

  @override
  Future<Map<String, dynamic>> savePreferences(Map<String, Object?> value) =>
      AuthApi.saveSpeechPreferences(value);
}
