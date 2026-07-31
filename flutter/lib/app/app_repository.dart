import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'runtime_models.dart';

final class ApiException implements Exception {
  const ApiException(this.code, this.message, this.status);
  final String code;
  final String message;
  final int status;
  @override
  String toString() => message;
}

final class BootstrapResult {
  const BootstrapResult({
    required this.config,
    required this.user,
    required this.authProviders,
    required this.authProviderPolicy,
    required this.authProviderConfig,
  });
  final RuntimeConfig config;
  final AppUser? user;
  final Map<String, bool> authProviders;
  final Map<String, bool> authProviderPolicy;
  final Map<String, Object?> authProviderConfig;
}

final class AuthResult {
  const AuthResult({
    required this.token,
    required this.refreshToken,
    required this.user,
  });
  final String token;
  final String refreshToken;
  final AppUser user;
}

final class AppRepository {
  AppRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _apiBase = String.fromEnvironment(
    'MOBILEUI_API_URL',
    defaultValue: 'http://localhost:3210',
  );
  // app_id（租户）必须通过 --dart-define=MOBILEUI_APP_ID 显式配置，未配置即报错，
  // 避免混入不可预测的 app_id；启动期统一校验见 main()。
  static const _appIdValue = String.fromEnvironment('MOBILEUI_APP_ID');
  static String get _appId {
    if (_appIdValue.isEmpty) {
      throw StateError(
        'MOBILEUI_APP_ID 未配置：请使用 --dart-define=MOBILEUI_APP_ID=<app-id> 启动，不能为空。',
      );
    }
    return _appIdValue;
  }

  // environment（development/staging/production 等）同样必须显式配置，未配置即报错。
  static const _appEnvironmentValue = String.fromEnvironment('MOBILEUI_APP_ENVIRONMENT');
  static String get _appEnvironment {
    if (_appEnvironmentValue.isEmpty) {
      throw StateError(
        'MOBILEUI_APP_ENVIRONMENT 未配置：请使用 --dart-define=MOBILEUI_APP_ENVIRONMENT=<env> 启动，不能为空。',
      );
    }
    return _appEnvironmentValue;
  }
  static const _tokenKey = 'mobileui.sessionToken';
  static const _refreshTokenKey = 'mobileui.sessionRefreshToken';
  static const _bootstrapKey = 'mobileui.bootstrap.public';

  final http.Client _client;
  final FlutterSecureStorage _secure = FlutterSecureStorage();
  String _token = '';
  String _acceptLanguage = 'zh-CN';
  Future<bool>? _refreshInFlight;
  // Set by the controller so an unrecoverable session expiry clears the user and
  // returns to the sign-in guard instead of looping on failing requests.
  void Function()? onSessionExpired;

  Future<BootstrapResult> bootstrap() async {
    _token = await _secure.read(key: _tokenKey) ?? '';
    try {
      final data = await _request('/api/v1/bootstrap');
      await _cacheBootstrap(data);
      return _parseBootstrap(data);
    } catch (_) {
      final cached = await SharedPreferencesAsync().getString(_bootstrapKey);
      if (cached == null) rethrow;
      return _parseBootstrap(JsonMap.from(jsonDecode(cached) as Map));
    }
  }

  BootstrapResult _parseBootstrap(JsonMap data) {
    return BootstrapResult(
      config: RuntimeConfig.fromJson(JsonMap.from(data['config']! as Map)),
      user: data['user'] == null
          ? null
          : AppUser.fromJson(JsonMap.from(data['user']! as Map)),
      authProviders: Map<String, bool>.from(data['authProviders']! as Map),
      authProviderPolicy: Map<String, bool>.from(
        data['authProviderPolicy']! as Map,
      ),
      authProviderConfig: data['authProviderConfig'] == null
          ? const {}
          : Map<String, Object?>.from(data['authProviderConfig']! as Map),
    );
  }

  Future<void> _cacheBootstrap(JsonMap data) {
    final publicData = <String, Object?>{
      'config': data['config'],
      'user': null,
      'authProviders': data['authProviders'],
      'authProviderPolicy': data['authProviderPolicy'],
    };
    return SharedPreferencesAsync().setString(
      _bootstrapKey,
      jsonEncode(publicData),
    );
  }

  Future<AuthResult> signIn(String identifier, String password) =>
      _authenticate('/api/v1/auth/sign-in', {
        'identifier': identifier,
        'password': password,
        'deviceName': 'Flutter · MobileUI',
      });

  Future<AuthResult> signUp(
    String email,
    String password,
    String username,
    String consentVersion,
  ) =>
      _authenticate('/api/v1/auth/sign-up', {
        'email': email,
        'password': password,
        'username': username,
        'consentVersion': consentVersion,
        'deviceName': 'Flutter · MobileUI',
      });

  Future<bool> verifyEmail(String email, String code) async {
    await _request('/api/v1/auth/verify-email', method: 'POST', body: {
      'email': email,
      'code': code,
    });
    return true;
  }

  Future<void> resendEmailVerification(String email) => _request(
    '/api/v1/auth/verify-email/resend',
    method: 'POST',
    body: {'email': email},
  );

  Future<void> requestPhoneCode(String phone) => _request(
    '/api/v1/auth/phone/request',
    method: 'POST',
    body: {'phone': phone},
  );

  Future<AuthResult> verifyPhoneCode(String phone, String code) =>
      _authenticate('/api/v1/auth/phone/verify', {
        'phone': phone,
        'code': code,
        'deviceName': 'Flutter · MobileUI',
      });

  Future<AuthResult> socialSignIn(Map<String, Object?> payload) {
    final body = Map<String, Object?>.from(payload);
    body['deviceName'] = kIsWeb ? 'web · MobileUI' : 'Flutter · MobileUI';
    return _authenticate('/api/v1/auth/social', body);
  }

  Future<void> requestPasswordReset(String email) => _request(
    '/api/v1/auth/password/forgot',
    method: 'POST',
    body: {'email': email},
  );

  Future<String> verifyPasswordReset(String email, String code) async {
    final data = await _request(
      '/api/v1/auth/password/verify',
      method: 'POST',
      body: {'email': email, 'code': code},
    );
    return data['resetToken']! as String;
  }

  Future<void> resetPassword(String token, String password) => _request(
    '/api/v1/auth/password/reset',
    method: 'POST',
    body: {'resetToken': token, 'newPassword': password},
  );

  Future<AppUser> updateProfile(
    String displayName,
    String bio,
    String? avatarUrl,
  ) async {
    final data = await _request(
      '/api/v1/me/profile',
      method: 'PATCH',
      body: {'displayName': displayName, 'bio': bio, 'avatarUrl': avatarUrl},
    );
    return AppUser.fromJson(data);
  }

  Future<JsonMap> saveSettings(JsonMap patch) =>
      _request('/api/v1/me/settings', method: 'PUT', body: patch);

  Future<List<SessionView>> sessions() =>
      _list('/api/v1/me/sessions', SessionView.fromJson);

  Future<void> revokeSession(String id) =>
      _request('/api/v1/me/sessions/$id', method: 'DELETE');

  Future<List<NotificationView>> notifications() =>
      _list('/api/v1/notifications', NotificationView.fromJson);

  Future<void> markNotificationsRead() =>
      _request('/api/v1/notifications', method: 'PATCH');

  Future<void> markNotificationRead(String id) =>
      _request('/api/v1/notifications/$id', method: 'PATCH');

  Future<void> deleteNotification(String id) =>
      _request('/api/v1/notifications/$id', method: 'DELETE');

  Future<List<OrderView>> orders() =>
      _list('/api/v1/orders', OrderView.fromJson);

  Future<UsageSummary> usage() async =>
      UsageSummary.fromJson(await _request('/api/v1/me/usage'));

  Future<List<CouponView>> coupons() =>
      _list('/api/v1/me/coupons', CouponView.fromJson);

  Future<ReferralView> referral() async =>
      ReferralView.fromJson(await _request('/api/v1/me/referral'));

  Future<OrderView> purchase(String planId) async {
    final data = await _request(
      '/api/v1/orders',
      method: 'POST',
      body: {'planId': planId},
      idempotencyKey: 'flutter-${DateTime.now().microsecondsSinceEpoch}',
    );
    return OrderView.fromJson(data);
  }

  Future<void> changePassword(String current, String next) => _request(
    '/api/v1/me/change-password',
    method: 'POST',
    body: {'currentPassword': current, 'newPassword': next},
  );

  Future<void> deleteAccount(String password) => _request(
    '/api/v1/me/deletion',
    method: 'DELETE',
    body: {'password': password, 'confirmation': 'DELETE'},
  );

  Future<void> signOut() async {
    try {
      await _request('/api/v1/auth/sign-out', method: 'POST');
    } finally {
      await _clearSession();
    }
  }

  Future<void> signOutAll() async {
    try {
      await _request('/api/v1/auth/sign-out-all', method: 'POST');
    } finally {
      await _clearSession();
    }
  }

  Future<void> _clearSession() async {
    _token = '';
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _refreshTokenKey);
  }

  Future<AuthResult> _authenticate(String path, JsonMap body) async {
    final data = await _request(path, method: 'POST', body: body);
    final result = AuthResult(
      token: data['token']! as String,
      refreshToken: data['refreshToken']! as String,
      user: AppUser.fromJson(JsonMap.from(data['user']! as Map)),
    );
    _token = result.token;
    await _secure.write(key: _tokenKey, value: result.token);
    await _secure.write(key: _refreshTokenKey, value: result.refreshToken);
    return result;
  }

  Future<List<T>> _list<T>(String path, T Function(JsonMap) decode) async {
    final data = await _requestRaw(path);
    return (data as List)
        .map((value) => decode(JsonMap.from(value as Map)))
        .toList(growable: false);
  }

  Future<JsonMap> _request(
    String path, {
    String method = 'GET',
    JsonMap? body,
    String? idempotencyKey,
  }) async => JsonMap.from(
    await _requestRaw(
          path,
          method: method,
          body: body,
          idempotencyKey: idempotencyKey,
        )
        as Map,
  );

  Future<Object?> _requestRaw(
    String path, {
    String method = 'GET',
    JsonMap? body,
    String? idempotencyKey,
    bool retried = false,
  }) async {
    final request = http.Request(method, Uri.parse('$_apiBase$path'));
    request.headers.addAll(_headers(idempotencyKey));
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 10));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && !retried && await _refreshSession()) {
      return _requestRaw(
        path,
        method: method,
        body: body,
        idempotencyKey: idempotencyKey,
        retried: true,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && !retried) onSessionExpired?.call();
      final error = JsonMap.from(decoded['error']! as Map);
      throw ApiException(
        error['code']! as String,
        error['message']! as String,
        response.statusCode,
      );
    }
    return decoded['data'];
  }

  Future<bool> _refreshSession() {
    _refreshInFlight ??= _performRefresh();
    return _refreshInFlight!.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _secure.read(key: _refreshTokenKey) ?? '';
    if (refreshToken.isEmpty) return false;
    try {
      final request = http.Request('POST', Uri.parse('$_apiBase/api/v1/auth/refresh'));
      request.headers.addAll(_headers(null));
      request.body = jsonEncode({'refreshToken': refreshToken});
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      final data = JsonMap.from(decoded['data']! as Map);
      final token = data['token']! as String;
      final refresh = data['refreshToken']! as String;
      _token = token;
      await _secure.write(key: _tokenKey, value: token);
      await _secure.write(key: _refreshTokenKey, value: refresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _headers(String? idempotencyKey) {
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept-language': _acceptLanguage,
      'x-app-id': _appId,
      'x-app-environment': _appEnvironment,
      'x-platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'x-app-version': '1.0.0',
    };
    if (_token.isNotEmpty) headers['authorization'] = 'Bearer $_token';
    if (idempotencyKey != null) headers['idempotency-key'] = idempotencyKey;
    return headers;
  }

  void setLocale(String locale) {
    _acceptLanguage = locale;
  }

  void dispose() => _client.close();
}
