import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app/runtime_models.dart';
import 'payment_models.dart';
import 'token_store.dart';

final class PaymentApiException implements Exception {
  const PaymentApiException(this.code, this.message, this.status);
  final String code;
  final String message;
  final int status;
  @override
  String toString() => message;
}

final class PaymentRepository {
  PaymentRepository({required TokenStore tokenStore}) : _tokenStore = tokenStore;

  final TokenStore _tokenStore;

  static const _apiBase = String.fromEnvironment(
    'MOBILEUI_API_URL',
    defaultValue: 'http://localhost:3210',
  );
  static const _appIdValue = String.fromEnvironment('MOBILEUI_APP_ID');
  static const _appEnvironmentValue = String.fromEnvironment('MOBILEUI_APP_ENVIRONMENT');
  static const _platformOverride = String.fromEnvironment('MOBILEUI_PLATFORM');

  static String get _appId {
    if (_appIdValue.isEmpty) {
      throw StateError('MOBILEUI_APP_ID 未配置：请用 --dart-define=MOBILEUI_APP_ID=<app-id>。');
    }
    return _appIdValue;
  }

  static String get _appEnvironment {
    if (_appEnvironmentValue.isEmpty) {
      throw StateError('MOBILEUI_APP_ENVIRONMENT 未配置：请用 --dart-define=MOBILEUI_APP_ENVIRONMENT=<env>。');
    }
    return _appEnvironmentValue;
  }

  String get _platform => _platformOverride.isNotEmpty ? _platformOverride : _platformName();

  Future<CreateOrderResult> createOrder(String planId, {required String idempotencyKey}) async {
    final data = await _request(
      '/api/v1/orders',
      method: 'POST',
      body: {'planId': planId},
      idempotencyKey: idempotencyKey,
    );
    return CreateOrderResult.fromJson(_map(data));
  }

  Future<OrderView> verifyPurchase({String? orderId, required Object receipt}) async {
    final data = await _request(
      '/api/v1/purchases/verify',
      method: 'POST',
      body: _verifyBody(orderId, receipt),
    );
    return OrderView.fromJson(_map(data));
  }

  Future<List<String>> restore(List<Object> receipts) async {
    final data = await _request(
      '/api/v1/purchases/restore',
      method: 'POST',
      body: {'receipts': receipts},
    );
    return (_map(data)['entitlements'] as List<Object?>).cast<String>();
  }

  Future<MembershipCurrent> membershipCurrent() async {
    final data = await _request('/api/v1/membership/current');
    return MembershipCurrent.fromJson(_map(data));
  }

  Future<List<String>> entitlements() async {
    final data = await _request('/api/v1/membership/entitlements');
    return (_map(data)['keys'] as List<Object?>).cast<String>();
  }

  Future<List<OrderView>> orders() async {
    final data = await _request('/api/v1/orders');
    return (data as List<Object?>)
        .map((item) => OrderView.fromJson(_map(item)))
        .toList(growable: false);
  }

  Map<String, Object?> _verifyBody(String? orderId, Object receipt) {
    final body = <String, Object?>{'receipt': receipt};
    if (orderId != null) body['orderId'] = orderId;
    return body;
  }

  Future<Object?> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    final token = await _tokenStore.read() ?? '';
    final headers = <String, String>{
      'content-type': 'application/json',
      'x-app-id': _appId,
      'x-app-environment': _appEnvironment,
      'x-platform': _platform,
      'x-app-version': '1.0.0',
      'accept-language': 'zh-CN',
      if (token.isNotEmpty) 'authorization': 'Bearer $token',
      'idempotency-key': ?idempotencyKey,
    };
    final uri = Uri.parse('$_apiBase$path');
    final response = method == 'GET'
        ? await http.get(uri, headers: headers).timeout(const Duration(seconds: 12))
        : await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 12));
    final envelope = _map(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _map(envelope['error']);
      throw PaymentApiException(
        error['code'] as String? ?? 'HTTP_ERROR',
        _errorMessage(error),
        response.statusCode,
      );
    }
    return envelope['data'];
  }

  static Map<String, Object?> _map(Object? value) => Map<String, Object?>.from(value! as Map);
  static String _errorMessage(Map<String, Object?> error) {
    final fe = error['fieldErrors'];
    if (fe is Map) {
      final msgs = fe.values.whereType<List>().expand((l) => l.whereType<String>()).toSet();
      if (msgs.isNotEmpty) return msgs.join('；');
    }
    return error['message'] as String? ?? '服务暂时不可用';
  }
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
