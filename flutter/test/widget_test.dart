import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:mobilestarter_flutter/app/app_repository.dart';
import 'package:mobilestarter_flutter/app/app_scope.dart';
import 'package:mobilestarter_flutter/navigation/app_route.dart';
import 'package:mobilestarter_flutter/navigation/app_route_paths.dart';
import 'package:mobilestarter_flutter/screens/launch_screens.dart';
import 'package:mobilestarter_flutter/telemetry/telemetry.dart';

// Deterministic splash-flow test. Pumps SplashScreen directly with a controller
// backed by a mock client returning a fixed bootstrap config carrying a splash
// campaign (durationSeconds: 3). The old "pump the whole MobileUiApp" variant
// was flaky: it only showed the countdown when a live server happened to
// respond in time, and its bootstrap hit the secure-storage/platform channels
// that are unimplemented in the widget-test binding.
void main() {
  testWidgets('splash shows a top countdown skip capsule and advances on skip', (
    tester,
  ) async {
    _installPlatformMocks();
    await telemetry.configure(
      const TelemetryConfig(enabled: false, backendEnabled: false),
    );

    final controller = AppController(
      // appId/environment 走测试注入 seam，裸跑 flutter test 不依赖 --dart-define。
      AppRepository(
        client: _splashClient(),
        appId: 'test-app',
        environment: 'test',
      ),
    );
    addTearDown(controller.dispose);
    // Run initialize() in real async so the platform-channel futures resolve;
    // the widget-tree pump below runs in the test's fake-async clock.
    await tester.runAsync(() => controller.initialize());

    final router = GoRouter(
      initialLocation: pathFor(AppRoute.logo),
      routes: [
        GoRoute(
          path: pathFor(AppRoute.logo),
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: pathFor(AppRoute.home),
          builder: (context, state) => const Scaffold(body: Text('home-page')),
        ),
        GoRoute(
          path: pathFor(AppRoute.signIn),
          builder: (context, state) =>
              const Scaffold(body: Text('sign-in-page')),
        ),
      ],
    );
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // Loading phase shows brand only（16ff1e9 起去掉"加载中…"提示文案，
    // 极短 loading 门：logo + 转圈即分流）。
    expect(find.text('MobileStarter'), findsOneWidget);

    // issue #24 已去掉 1s 最短展示：bootstrap 在 initialize()（runAsync）中已
    // 先行完成，localReady 后 _maybeAdvance 于首帧 post-frame 回调进入倒计时；
    // pump 一帧渲染倒计时胶囊。
    await tester.pump();

    // The skip capsule renders countdown + label as one text: "3 s 跳过".
    final capsule = find.text('3 s 跳过');
    expect(capsule, findsOneWidget);
    // Anchored to the top of the screen (SafeArea + Align topRight).
    expect(tester.getTopLeft(capsule).dy, lessThan(150));

    // Skipping advances by login state (16ff1e9 启动门分流): mock bootstrap
    // 返回 user: null → 未登录 → 落地认证页 signIn（不再是 home）。
    await tester.tap(capsule);
    await tester.pumpAndSettle();
    expect(find.text('sign-in-page'), findsOneWidget);
  });
}

void _installPlatformMocks() {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync
      .empty();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
}

http.Client _splashClient() => MockClient((request) async {
  return http.Response(
    jsonEncode({
      'data': {
        'config': {
          'version': 1,
          'brand': {'appName': 'MobileStarter', 'tagline': '测试'},
          'splash': {
            'id': 'test-splash',
            'title': '标题',
            'description': '描述',
            'badge': '徽标',
            'actionLabel': '跳过',
            'imageUrl': '',
            'videoUrl': '',
            'linkUrl': '',
            'skippable': true,
            'durationSeconds': 3,
          },
          'features': <String, bool>{},
          'settingsPolicy': <String, Object?>{},
          'tiers': <Object?>[],
          'plans': <Object?>[],
          'legal': <Object?>[],
        },
        'user': null,
        'authProviders': <String, bool>{},
        'authProviderPolicy': <String, bool>{},
        'authProviderConfig': <String, Object?>{},
      },
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
});
