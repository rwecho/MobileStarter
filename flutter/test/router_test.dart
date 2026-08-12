import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter_flutter/app/app_controller.dart';
import 'package:mobilestarter_flutter/app/app_repository.dart';
import 'package:mobilestarter_flutter/app/app_scope.dart';
import 'package:mobilestarter_flutter/navigation/app_route.dart';
import 'package:mobilestarter_flutter/navigation/app_route_paths.dart';
import 'package:mobilestarter_flutter/navigation/app_router_config.dart';
import 'package:mobilestarter_flutter/telemetry/telemetry.dart';

void main() {
  test('path map covers every AppRoute', () {
    for (final route in AppRoute.values) {
      expect(appRoutePaths[route], isNotNull, reason: 'no path for $route');
    }
    expect(
      appRoutePaths.values.toSet().length,
      appRoutePaths.length,
      reason: 'duplicate paths',
    );
  });

  testWidgets('signed-out push to a protected route redirects to sign-in and remembers target', (
    tester,
  ) async {
    await telemetry.configure(
      const TelemetryConfig(enabled: false, backendEnabled: false),
    );
    _enlargeView(tester);
    final controller = AppController(AppRepository());
    addTearDown(controller.dispose);
    final router = buildAppRouter(controller);
    await tester.pumpWidget(
      AppScope(controller: controller, child: MaterialApp.router(routerConfig: router)),
    );
    router.go(pathFor(AppRoute.profileEdit));
    await tester.pumpAndSettle();
    // Landed on the sign-in screen (its account field label).
    expect(find.text('用户名、邮箱或手机号'), findsOneWidget);
    // The redirect remembered what the signed-out user was trying to reach.
    expect(controller.consumeAuthRedirectTarget(), AppRoute.profileEdit);
    // consume clears the target — resume-once semantics.
    expect(controller.consumeAuthRedirectTarget(), isNull);
  });

  testWidgets('signed-out push to a public route is not redirected', (tester) async {
    await telemetry.configure(
      const TelemetryConfig(enabled: false, backendEnabled: false),
    );
    _enlargeView(tester);
    final controller = AppController(AppRepository());
    addTearDown(controller.dispose);
    final router = buildAppRouter(controller);
    await tester.pumpWidget(
      AppScope(controller: controller, child: MaterialApp.router(routerConfig: router)),
    );
    router.go(pathFor(AppRoute.legal));
    await tester.pumpAndSettle();
    // Legal is not protected: no redirect, the page renders, nothing remembered.
    expect(find.text('协议与政策'), findsOneWidget);
    expect(controller.consumeAuthRedirectTarget(), isNull);
  });
}

/// Enlarge the test view so list-based screens render fully (matches the
/// existing auth_screen_test setup).
void _enlargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
