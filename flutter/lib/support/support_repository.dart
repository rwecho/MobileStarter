import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'support_models.dart';

final class SupportRepository {
  static const _apiBase = String.fromEnvironment(
    'MOBILEUI_API_URL',
    defaultValue: 'http://localhost:3210',
  );
  static const _appId = String.fromEnvironment(
    'MOBILEUI_APP_ID',
    defaultValue: 'mobileui',
  );
  static const _installationKey = 'mobileui.support.installationId';
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
  }) async {
    await _request(
      '/api/v1/support/feedback',
      method: 'POST',
      body: {
        'category': category,
        'title': title,
        'body': body,
        'rating': rating,
      },
    );
  }

  Future<Object?> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final installationId = await _installationId();
    final headers = {
      'content-type': 'application/json',
      'x-app-id': _appId,
      'x-platform': Platform.isIOS ? 'ios' : 'android',
      'x-app-version': '1.0.0',
      'x-installation-id': installationId,
      'accept-language': 'zh-CN',
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
        'flutter-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    await storage.setString(_installationKey, created);
    return created;
  }

  static Map<String, Object?> _map(Object? value) =>
      Map<String, Object?>.from(value! as Map);
}
