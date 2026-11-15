import 'dart:convert';

import 'package:http/http.dart' as http;

/// Base address for the MindSpeak backend.
///
/// Chrome running on the same laptop can use localhost. When testing on a
/// physical phone, pass the laptop's local IP at run time, for example:
/// --dart-define=API_BASE_URL=http://192.168.1.10:4000
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);

class ApiException implements Exception {
  const ApiException(this.message, {this.code = 'REQUEST_FAILED'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({required this.token, required this.calibrated});

  final String token;
  final bool calibrated;
}

class MindSpeakApi {
  MindSpeakApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) =>
      Uri.parse('${apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}$path');

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final request = http.Request(method, _uri(path))
        ..headers.addAll(headers)
        ..body = body == null ? '' : jsonEncode(body);
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final text = await response.stream.bytesToString();
      final decoded = text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'] as Map<String, dynamic>?;
        throw ApiException(
          error?['message'] as String? ??
              'Something went wrong. Please try again.',
          code: error?['code'] as String? ?? 'REQUEST_FAILED',
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('The server returned an invalid response.');
    } catch (_) {
      throw const ApiException(
        'Cannot reach the MindSpeak server. Check that it is running and the API address is correct.',
        code: 'NETWORK',
      );
    }
  }

  Future<String> register({
    required String username,
    required String email,
    required String password,
    required String birthDate,
    required String phone,
  }) async {
    final result = await _request(
      '/auth/register',
      body: {
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'birthDate': birthDate.trim(),
        'phone': phone.trim(),
        'role': 'patient',
      },
    );
    return result['email'] as String? ?? email.trim();
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _request(
      '/auth/verify-email',
      body: {'email': email, 'code': code.trim()},
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final result = await _request(
      '/auth/login',
      body: {'email': email.trim(), 'password': password, 'role': 'patient'},
    );
    final data = result['data'] as Map<String, dynamic>?;
    return AuthSession(
      token: result['token'] as String,
      calibrated: data?['calibrated'] == true,
    );
  }

  Future<void> saveCalibration(String token) async {
    await _request(
      '/me/data',
      method: 'PUT',
      token: token,
      body: {
        'profile': <String, dynamic>{},
        'settings': null,
        'history': <dynamic>[],
        'notifications': <dynamic>[],
        'calibrated': true,
      },
    );
  }
}
