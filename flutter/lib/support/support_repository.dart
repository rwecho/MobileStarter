import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'support_models.dart';

final class SupportRepository {
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
  static const _appEnvironmentValue = String.fromEnvironment(
    'MOBILEUI_APP_ENVIRONMENT',
  );
  static String get _appEnvironment {
    if (_appEnvironmentValue.isEmpty) {
      throw StateError(
        'MOBILEUI_APP_ENVIRONMENT 未配置：请使用 --dart-define=MOBILEUI_APP_ENVIRONMENT=<env> 启动，不能为空。',
      );
    }
    return _appEnvironmentValue;
  }

  static const _installationKey = 'mobileui.support.installationId';
  // Mirrors AppRepository._tokenKey so support calls carry the same session
  // token as the rest of the app (support tickets are user-scoped).
  static const _sessionTokenKey = 'mobileui.sessionToken';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  Future<String>? _installationFuture;

  Future<List<HelpArticle>> help() async {
    final data = await _request('/api/v1/support/help');
    return (data as List<Object?>)
        .map((item) => HelpArticle.fromJson(_map(item)))
        .toList(growable: false);
  }

  Future<List<SupportTicket>> tickets() async {
    final data = await _request('/api/v1/support/tickets');
    return (data as List<Object?>)
        .map((item) => SupportTicket.fromJson(_map(item)))
        .toList(growable: false);
  }

  Future<SupportTicketDetail> ticket(String id) async {
    final data = await _request('/api/v1/support/tickets/$id');
    return SupportTicketDetail.fromJson(_map(data));
  }

  Future<SupportTicket> createTicket({
    required String category,
    required String severity,
    required String subject,
    required String message,
  }) async {
    final data = await _request(
      '/api/v1/support/tickets',
      method: 'POST',
      body: {
        'category': category,
        'severity': severity,
        'subject': subject,
        'message': message,
      },
    );
    return SupportTicket.fromJson(_map(data));
  }

  Future<SupportMessage> reply(String id, String message) async {
    final data = await _request(
      '/api/v1/support/tickets/$id/messages',
      method: 'POST',
      body: {'message': message},
    );
    return SupportMessage.fromJson(_map(data));
  }

  Future<void> feedback({
    required String category,
    required String title,
    required String body,
    required int rating,
    required List<FeedbackScreenshot> screenshots,
  }) async {
    await _request(
      '/api/v1/support/feedback',
      method: 'POST',
      body: {
        'category': category,
        'title': title,
        'body': body,
        'rating': rating,
        'screenshots': screenshots.map((item) => item.toJson()).toList(),
      },
    );
  }

  Future<Object?> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final installationId = await _installationId();
    final token = await _secure.read(key: _sessionTokenKey) ?? '';
    final headers = {
      'content-type': 'application/json',
      'x-app-id': _appId,
      'x-app-environment': _appEnvironment,
      'x-platform': _platformName(),
      'x-app-version': '1.0.0',
      'x-installation-id': installationId,
      'accept-language': 'zh-CN',
      if (token.isNotEmpty) 'authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$_apiBase$path');
    final response = method == 'GET'
        ? await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 12))
        : await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 12));
    final envelope = _map(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _map(envelope['error']);
      throw StateError(error['message'] as String? ?? '服务暂时不可用');
    }
    return envelope['data'];
  }

  Future<String> _installationId() {
    _installationFuture ??= _loadInstallationId();
    return _installationFuture!;
  }

  Future<String> _loadInstallationId() async {
    final storage = SharedPreferencesAsync();
    final current = await storage.getString(_installationKey);
    if (current != null) return current;
    final created =
        'flutter-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x3FFFFFFF)}';
    await storage.setString(_installationKey, created);
    return created;
  }

  static Map<String, Object?> _map(Object? value) =>
      Map<String, Object?>.from(value! as Map);
}

String _platformName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
