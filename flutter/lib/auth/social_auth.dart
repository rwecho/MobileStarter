import 'dart:math';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// Acquires a social-login credential mirroring the RN payloads sent to
// POST /api/v1/auth/social. Each provider needs its own native platform
// configuration (URL schemes, Info.plist queries, OAuth clientIds) and must be
// verified on a real device/simulator — this environment cannot run them.
const _githubRedirect = 'mobilestarter://oauth';

Future<Map<String, Object?>?> acquireSocialCredential(
  String provider, {
  String? githubClientId,
  String? googleClientId,
}) async {
  switch (provider) {
    case 'apple':
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) return null;
      return {'provider': 'apple', 'idToken': idToken};
    case 'google':
      if (googleClientId == null || googleClientId.isEmpty) return null;
      final google = GoogleSignIn(
        scopes: const ['openid', 'profile', 'email'],
        serverClientId: googleClientId,
      );
      final account = await google.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) return null;
      return {'provider': 'google', 'idToken': idToken};
    case 'github':
      if (githubClientId == null || githubClientId.isEmpty) return null;
      // PKCE "plain" challenge avoids an extra crypto dependency; the backend
      // exchanges the code using the codeVerifier we forward.
      final codeVerifier = _randomString(64);
      final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
        'client_id': githubClientId,
        'redirect_uri': _githubRedirect,
        'response_type': 'code',
        'scope': 'read:user user:email',
        'code_challenge': codeVerifier,
        'code_challenge_method': 'plain',
      });
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: 'mobilestarter',
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null || code.isEmpty) return null;
      return {
        'provider': 'github',
        'authorizationCode': code,
        'redirectUri': _githubRedirect,
        'codeVerifier': codeVerifier,
      };
    default:
      return null;
  }
}

String _randomString(int length) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}
