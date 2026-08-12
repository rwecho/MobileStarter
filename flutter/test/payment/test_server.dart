import 'dart:convert';
import 'package:http/http.dart' as http;

const _apiBase = String.fromEnvironment('MOBILEUI_API_URL', defaultValue: 'http://localhost:3210');
// Defaults mirror the local dev server (README + payment plan): tenant
// `zhongbei`, env `development`. Tests otherwise fail with APP_ID_REQUIRED
// because an unset const String.fromEnvironment is an empty string.
const _appId = String.fromEnvironment('MOBILEUI_APP_ID', defaultValue: 'zhongbei');
const _appEnv = String.fromEnvironment(
  'MOBILEUI_APP_ENVIRONMENT',
  defaultValue: 'development',
);

/// Signs up a fresh test user against the real server; returns the access token.
Future<String> signUpAndGetToken(String email, {String password = 'Test1234'}) async {
  final username = email.split('@').first;
  final response = await http
      .post(
        Uri.parse('$_apiBase/api/v1/auth/sign-up'),
        headers: {
          'content-type': 'application/json',
          'x-app-id': _appId,
          'x-app-environment': _appEnv,
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          // Server enforces username <= 24 chars; truncate but keep the unique
          // microseconds-suffix so usernames stay distinct across tests.
          'username': username.length > 24 ? username.substring(0, 24) : username,
          'consentVersion': '2026-07-29',
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 201) {
    throw StateError('sign-up failed (${response.statusCode}): ${response.body}');
  }
  final envelope = jsonDecode(response.body) as Map;
  final data = envelope['data'] as Map;
  // The server returns { token, refreshToken, user } — the access token field is `token`,
  // matching how AppRepository._authenticate parses sign-in/sign-up responses.
  return data['token']! as String;
}
