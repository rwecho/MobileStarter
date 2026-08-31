import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:mobilestarter_flutter/app/app_repository.dart';
import 'package:mobilestarter_flutter/app/app_scope.dart';
import 'package:mobilestarter_flutter/navigation/app_route.dart';
import 'package:mobilestarter_flutter/navigation/app_route_paths.dart';
import 'package:mobilestarter_flutter/navigation/app_router_config.dart';
import 'package:mobilestarter_flutter/telemetry/telemetry.dart';

// Automated proxy for the manual acceptance scenarios (issue #2 root cause):
// the bottom-tab shell keeps each branch alive, and a pushed sub-page pops back
// to the shell. Full visual/interactive acceptance still needs `flutter run`.
//
// These tests drive controller.initialize(), which sends an x-app-id header
// from --dart-define=MOBILEUI_APP_ID, so they must be run WITH the documented
// defines (same as the payment tests):
//   flutter test --dart-define=MOBILEUI_API_URL=http://localhost:3210 \
//     --dart-define=MOBILEUI_APP_ID=zhongbei \
//     --dart-define=MOBILEUI_APP_ENVIRONMENT=development \
//     --dart-define=MOBILEUI_PLATFORM=ios test/shell_test.dart
void main() {
  testWidgets('shell tab switching keeps branches alive', (tester) async {
    _installPlatformMocks();
    await telemetry.configure(
      const TelemetryConfig(enabled: false, backendEnabled: false),
    );
    final controller = AppController(AppRepository(client: _bootstrapClient()));
    addTearDown(controller.dispose);
    await tester.runAsync(() => controller.initialize());

    final router = buildAppRouter(controller);
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh', 'CN'),
        ),
      ),
    );
    router.go(pathFor(AppRoute.home));
    await tester.pumpAndSettle();
    expect(find.text('MobileStarter'), findsOneWidget, reason: 'home tab renders');

    // Switch tabs by going to another shell branch location (the mechanism
    // ShellScaffold's NavigationBar drives via goBranch). The shell now has two
    // branches: home + profile (membership is a pushed child page).
    router.go(pathFor(AppRoute.profile));
    await tester.pumpAndSettle();
    expect(find.text('登录后同步你的数据'), findsOneWidget, reason: 'profile tab renders');

    router.go(pathFor(AppRoute.home));
    await tester.pumpAndSettle();
    expect(find.text('MobileStarter'), findsOneWidget, reason: 'home tab preserved');
  });

  testWidgets('pushing a sub-page and popping returns to the shell', (
    tester,
  ) async {
    _installPlatformMocks();
    await telemetry.configure(
      const TelemetryConfig(enabled: false, backendEnabled: false),
    );
    final controller = AppController(AppRepository(client: _bootstrapClient()));
    addTearDown(controller.dispose);
    await tester.runAsync(() => controller.initialize());

    final router = buildAppRouter(controller);
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh', 'CN'),
        ),
      ),
    );
    router.go(pathFor(AppRoute.home));
    await tester.pumpAndSettle();

    router.push(pathFor(AppRoute.legal));
    await tester.pumpAndSettle();
    expect(find.text('协议与政策'), findsOneWidget, reason: 'legal sub-page pushed');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('MobileStarter'), findsOneWidget, reason: 'back returns to the shell');
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

http.Client _bootstrapClient() => MockClient((request) async {
  return http.Response(
    jsonEncode({
      'data': {
        'config': {
          'version': 1,
          'brand': {'appName': 'MobileStarter', 'tagline': '测试'},
          'splash': null,
          'features': <String, bool>{'membership': true},
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
