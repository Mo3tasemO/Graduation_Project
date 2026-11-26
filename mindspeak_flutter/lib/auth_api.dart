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
  static const _refreshKey = 'mindspeak_refresh_token';
  static Future<bool>? _refreshInFlight;

  /// Tokens always live in memory while the app is open. They are written to
  /// secure storage only when the user agreed to stay signed in on this device.
  /// The password itself is never stored.
  static String? _refreshToken;
  static bool _remember = false;

  static String? get accessToken => _accessToken;

  /// Whether this device keeps the sign-in after the app is closed.
  static bool get isSessionRemembered => _remember;

  /// Called after the user answers "Stay signed in on this device?".
  /// Yes saves the current sign-in to secure storage; no removes any saved copy
  /// (the user stays signed in until the app is closed).
  static Future<void> setRememberSession(bool remember) async {
    _remember = remember;
    if (remember && _accessToken != null) {
      await _storage.write(key: _tokenKey, value: _accessToken);
      if (_refreshToken != null) {
        await _storage.write(key: _refreshKey, value: _refreshToken);
      }
      await MindSpeakPreferences.instance.setSessionStored(true);
    } else {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _refreshKey);
      await MindSpeakPreferences.instance.setSessionStored(false);
      // Biometric unlock only protects a saved sign-in, so it goes with it.
      await MindSpeakPreferences.instance.setBiometrics(false);
    }
  }

  static Future<bool> hasSavedToken() async =>
      MindSpeakPreferences.instance.sessionStored;

  /// Restores the saved sign-in only after optional device biometrics have passed,
  /// then validates it against the server before treating the user as signed in.
  /// An expired access token is renewed with the saved refresh token, so the user
  /// is not asked for the password again until the refresh token itself expires.
  static Future<bool> restoreSession() async {
    final saved = await _storage.read(key: _tokenKey);
    final refresh = await _storage.read(key: _refreshKey);
    if ((saved == null || saved.isEmpty) && (refresh == null || refresh.isEmpty)) {
      return false;
    }
    _accessToken = (saved == null || saved.isEmpty) ? null : saved;
    _refreshToken = (refresh == null || refresh.isEmpty) ? null : refresh;
    _remember = true;
    if (_accessToken == null && !await _refreshAccessToken()) return false;
    try {
      await getProfile();
      return true;
    } on AuthApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearSession();
        return false;
      }
      // A server or permission error does not prove that the session is invalid.
      return true;
    } catch (_) {
      // Preserve a valid-looking secure token during temporary network outages.
      return true;
    }
  }

  /// Ends this device's sign-in on the server (best effort) and clears saved tokens.
  static Future<void> logout() async {
    final refresh = _refreshToken ?? await _storage.read(key: _refreshKey);
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _send('POST', '/auth/logout', body: {'refresh_token': refresh})
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Logging out locally must still work when the server is unreachable.
      }
    }
    await _clearSession();
  }

  static Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _remember = false;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
    await MindSpeakPreferences.instance.setSessionStored(false);
  }

  static Future<void> _saveTokens(Map<String, dynamic> result) async {
    final access = result['access_token'] as String?;
    if (access == null || access.isEmpty) {
      await _clearSession();
      return;
    }
    _accessToken = access;
    final refresh = result['refresh_token'] as String?;
    if (refresh != null && refresh.isNotEmpty) _refreshToken = refresh;
    if (!_remember) return;
    await _storage.write(key: _tokenKey, value: access);
    if (_refreshToken != null) {
      await _storage.write(key: _refreshKey, value: _refreshToken);
    }
    await MindSpeakPreferences.instance.setSessionStored(true);
  }

  /// Trades the saved refresh token for a new pair. Concurrent callers share one
  /// request, because each refresh token can be used only once.
  static Future<bool> _refreshAccessToken() {
    return _refreshInFlight ??= () async {
      try {
        final refresh = _refreshToken ?? await _storage.read(key: _refreshKey);
        if (refresh == null || refresh.isEmpty) return false;
        final response = await _send(
          'POST',
          '/auth/refresh',
          body: {'refresh_token': refresh},
        );
        final decoded = _decode(response);
        if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
          await _saveTokens(decoded);
          return true;
        }
        if (response.statusCode == 401) await _clearSession();
        return false;
      } catch (_) {
        return false;
      } finally {
        _refreshInFlight = null;
      }
    }();
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async => (await _request('POST', path, body: body)) as Map<String, dynamic>;

  static Future<http.Response> _send(
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
    try {
      return await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 15)),
      );
    } finally {
      client.close();
    }
  }

  static dynamic _decode(http.Response response) =>
      response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
  }) async {
    var response = await _send(
      method,
      path,
      body: body,
      authenticated: authenticated,
    );
    // The access token lasts minutes; renew it once and retry instead of
    // sending the user back to the login screen.
    if (authenticated &&
        response.statusCode == 401 &&
        await _refreshAccessToken()) {
      response = await _send(
        method,
        path,
        body: body,
        authenticated: authenticated,
      );
    }
    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        _messageFrom(decoded),
        statusCode: response.statusCode,
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
    await _clearSession();
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
    // A new sign-in starts unsaved; the app then asks whether to keep it.
    await _clearSession();
    await _saveTokens(result);
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final result = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    // A new sign-in starts unsaved; the app then asks whether to keep it.
    await _clearSession();
    await _saveTokens(result);
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
    await _clearSession();
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
