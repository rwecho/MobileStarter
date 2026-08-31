// 推送基线：FCM/APNs 令牌注册 + 前台消息转发。
// 依赖原生 Firebase 配置（google-services / GoogleService-Info），与 telemetry
// 同策略：未配置平台静默降级（令牌获取/权限失败不抛出、不阻塞登录流程）。
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../telemetry/telemetry.dart';

/// 后台消息回调要求顶层函数；模板基线仅保活入口（业务可在此补埋点/本地库写入）。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushService {
  static String? _token;
  static bool _starting = false;
  static StreamSubscription<RemoteMessage>? _messageSub;
  static StreamSubscription<String>? _tokenSub;
  static Future<bool> Function(String token)? _register;
  static Future<void> Function(String token)? _unregister;
  static void Function(String message)? _onForeground;

  /// 登录后调用：请求权限、取令牌上报服务端，并监听令牌轮换与前台消息。
  static Future<void> start({
    required Future<bool> Function(String token) register,
    required Future<void> Function(String token) unregister,
    required void Function(String message) onForeground,
  }) async {
    if (_starting || _messageSub != null) return;
    _starting = true;
    _register = register;
    _unregister = unregister;
    _onForeground = onForeground;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await _registerToken(await messaging.getToken());
      _tokenSub = messaging.onTokenRefresh.listen(_registerToken);
      _messageSub = FirebaseMessaging.onMessage.listen((message) {
        final body = message.notification?.body;
        if (body != null && body.isNotEmpty) _onForeground?.call(body);
      });
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (error, stack) {
      // 原生配置缺失/模拟器无 APNs 等：推送整体降级，telemetry 留痕即可。
      telemetry.report(error, stack);
    } finally {
      _starting = false;
    }
  }

  static Future<void> _registerToken(String? token) async {
    if (token == null || token.isEmpty) return;
    _token = token;
    try {
      await _register?.call(token);
    } catch (error, stack) {
      telemetry.report(error, stack);
    }
  }

  /// 登出调用：解绑监听、服务端解除令牌绑定并删除本地令牌。
  static Future<void> stop() async {
    await _messageSub?.cancel();
    _messageSub = null;
    await _tokenSub?.cancel();
    _tokenSub = null;
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await _unregister?.call(token);
      if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (error, stack) {
      telemetry.report(error, stack);
    }
  }
}
