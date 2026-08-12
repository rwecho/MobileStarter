import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:mobilestarter_flutter/app/app_controller.dart';
import 'package:mobilestarter_flutter/app/app_repository.dart';
import 'package:mobilestarter_flutter/app/app_scope.dart';
import 'package:mobilestarter_flutter/navigation/app_route.dart';
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

    final controller = AppController(AppRepository(client: _splashClient()));
    addTearDown(controller.dispose);
    // Run initialize() in real async so the platform-channel futures resolve;
    // the widget-tree pump below runs in the test's fake-async clock.
    await tester.runAsync(() => controller.initialize());

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(controller: controller, child: const SplashScreen()),
      ),
    );
    // Loading phase shows brand + spinner.
    expect(find.text('MobileStarter'), findsOneWidget);
    expect(find.text('加载中…'), findsOneWidget);

    // Advance past the 1s minimum-logo delay; bootstrap already completed
    // during initialize(), so _maybeAdvance enters the countdown.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();

    // The skip capsule renders countdown + label as one text: "3 s 跳过".
    final capsule = find.text('3 s 跳过');
    expect(capsule, findsOneWidget);
    // Anchored to the top of the screen (SafeArea + Align topRight).
    expect(tester.getTopLeft(capsule).dy, lessThan(150));

    // Skipping advances to home.
    await tester.tap(capsule);
    await tester.pump();
    expect(controller.route, AppRoute.home);
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
