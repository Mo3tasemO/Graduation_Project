import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_preferences.dart';

/// Small client for the independent MindSpeak API.
/// Override the base URL with --dart-define when using a device/emulator.
class AuthApi {
  AuthApi._();

  static const String _baseUrl = String.fromEnvironment(
    'MINDSPEAK_API_URL',
    defaultValue: 'http://127.0.0.1:8001/api/v1',
  );
  static String? _accessToken;
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'mindspeak_access_token';

  static String? get accessToken => _accessToken;

  static Future<bool> hasSavedToken() async =>
      MindSpeakPreferences.instance.sessionStored;

  /// Restores the saved token only after optional device biometrics have passed,
  /// then validates it against the server before treating the user as signed in.
  static Future<bool> restoreSession() async {
    final saved = await _storage.read(key: _tokenKey);
    if (saved == null || saved.isEmpty) return false;
    _accessToken = saved;
    try {
      await getProfile();
      return true;
    } on AuthApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await logout();
        return false;
      }
      // A server or permission error does not prove that the session is invalid.
      return true;
    } catch (_) {
      // Preserve a valid-looking secure token during temporary network outages.
      return true;
    }
  }

  static Future<void> logout() async {
    _accessToken = null;
    await _storage.delete(key: _tokenKey);
    await MindSpeakPreferences.instance.setSessionStored(false);
  }

  static Future<void> _saveToken(String? token) async {
    _accessToken = token;
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _tokenKey);
      await MindSpeakPreferences.instance.setSessionStored(false);
    } else {
      await _storage.write(key: _tokenKey, value: token);
      await MindSpeakPreferences.instance.setSessionStored(true);
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async => (await _request('POST', path, body: body)) as Map<String, dynamic>;

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final client = http.Client();
    late final http.Response streamed;
    try {
      streamed = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 15)),
      );
    } finally {
      client.close();
    }
    final decoded = streamed.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(streamed.body);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw AuthApiException(
        _messageFrom(decoded),
        statusCode: streamed.statusCode,
      );
    }
    return decoded;
  }

  static String _messageFrom(dynamic response) {
    if (response is! Map<String, dynamic>) {
      return 'The request could not be completed. Please try again.';
    }
    final detail = response['detail'];
    if (detail is Map<String, dynamic> && detail['message'] is String) {
      return detail['message'] as String;
    }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map<String, dynamic> && first['msg'] is String) {
        return (first['msg'] as String).replaceFirst('Value error, ', '');
      }
    }
    return 'The request could not be completed. Please try again.';
  }

  static Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    await _saveToken(null);
    await _post('/auth/register', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
    });
  }

  static Future<void> resendVerificationCode(String email) async {
    await _post('/auth/resend-verification-code', {'email': email});
  }

  static Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final result = await _post('/auth/verify-email', {
      'email': email,
      'code': code,
    });
    await _saveToken(result['access_token'] as String?);
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final result = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    await _saveToken(result['access_token'] as String?);
  }

  static Future<void> requestPasswordReset(String email) async {
    await _post('/auth/forgot-password', {'email': email});
  }

  static Future<String> verifyResetCode({
    required String email,
    required String code,
  }) async {
    final result = await _post('/auth/verify-reset-code', {
      'email': email,
      'code': code,
    });
    return result['reset_token'] as String;
  }

  static Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _post('/auth/reset-password', {
      'email': email,
      'reset_token': resetToken,
      'new_password': newPassword,
    });
    await _saveToken(null);
  }

  static Future<Map<String, dynamic>> getProfile() async =>
      (await _request('GET', '/me', authenticated: true))
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, Object?> changes,
  ) async =>
      (await _request('PUT', '/me', body: changes, authenticated: true))
          as Map<String, dynamic>;

  static Future<List<dynamic>> getCustomPhrases() async =>
      (await _request('GET', '/home/phrases', authenticated: true))
          as List<dynamic>;

  static Future<Map<String, dynamic>> createCustomPhrase(String text) async =>
      (await _request(
        'POST',
        '/home/phrases',
        body: {'text': text},
        authenticated: true,
      )) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> updateCustomPhrase(
    int id,
    String text,
  ) async => (await _request(
    'PUT',
    '/home/phrases/$id',
    body: {'text': text},
    authenticated: true,
  )) as Map<String, dynamic>;

  static Future<void> deleteCustomPhrase(int id) async {
    await _request('DELETE', '/home/phrases/$id', authenticated: true);
  }

  static Future<List<dynamic>> getMessageHistory({int limit = 50}) async =>
      (await _request('GET', '/home/history?limit=$limit', authenticated: true))
          as List<dynamic>;

  static Future<Map<String, dynamic>> addMessageHistory(String text) async =>
      (await _request(
        'POST',
        '/home/history',
        body: {'text': text},
        authenticated: true,
      )) as Map<String, dynamic>;

  static Future<void> deleteMessageHistory(int id) async {
    await _request('DELETE', '/home/history/$id', authenticated: true);
  }

  static Future<void> clearMessageHistory() async {
    await _request('DELETE', '/home/history', authenticated: true);
  }

  static Future<Map<String, dynamic>> getSpeechPreferences() async =>
      (await _request('GET', '/home/preferences', authenticated: true))
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> saveSpeechPreferences(
    Map<String, Object?> preferences,
  ) async => (await _request(
    'PUT',
    '/home/preferences',
    body: preferences,
    authenticated: true,
  )) as Map<String, dynamic>;
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
