import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:mobilestarter_flutter/app/app_repository.dart';

// 401 会话过期语义（对齐 arkts ApiTransport）：/api/v1/auth/* 的 401 是凭证
// 错误（登录密码错、验证码错等），必须走表单内联错误展示，绝不能触发
// onSessionExpired（会把用户切回登录页）；只有受保护路径的 401 才是会话失效。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // secure storage 返回 null（无已存 token）→ _performRefresh 直接失败，
    // 聚焦 401 分支本身；channel 名见 widget_test.dart 同款 mock。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  AppRepository repositoryWithStatus(int status, String code, String message) {
    return AppRepository(
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'error': {
                'code': code,
                'message': message,
                'retryable': false,
                'traceId': 'test',
              },
            }),
            status,
            headers: {'content-type': 'application/json'},
          )),
    );
  }

  test('auth 路径 401（密码错误）不触发 onSessionExpired', () async {
    final repository =
        repositoryWithStatus(401, 'INVALID_CREDENTIALS', '账号或密码不正确');
    var expiredCount = 0;
    repository.onSessionExpired = () => expiredCount++;

    await expectLater(
      repository.signIn('user@test.local', 'wrong'),
      throwsA(isA<ApiException>()),
    );
    expect(expiredCount, 0);
  });

  test('受保护路径 401 触发 onSessionExpired', () async {
    final repository = repositoryWithStatus(401, 'SESSION_EXPIRED', '登录状态已过期');
    var expiredCount = 0;
    repository.onSessionExpired = () => expiredCount++;

    await expectLater(repository.usage(), throwsA(isA<ApiException>()));
    expect(expiredCount, 1);
  });
}
