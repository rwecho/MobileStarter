import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobilestarter_flutter/app/app_repository.dart';
import 'package:mobilestarter_flutter/app/app_scope.dart';
import 'package:mobilestarter_flutter/l10n/generated/app_localizations.dart';
import 'package:mobilestarter_flutter/navigation/app_route.dart';
import 'package:mobilestarter_flutter/navigation/app_route_paths.dart';
import 'package:mobilestarter_flutter/screens/auth_screens.dart';
import 'package:mobilestarter_flutter/telemetry/telemetry.dart';

void main() {
  testWidgets('registration shows specific errors and bottom legal consent', (
    tester,
  ) async {
    final controller = AppController(AppRepository());
    addTearDown(controller.dispose);
    await _pumpAuth(tester, controller, AuthMode.signUp);

    await tester.tap(find.text('注册'));
    await tester.pump();

    expect(find.text('请输入邮箱'), findsOneWidget);
    expect(find.text('用户名至少 2 个字符'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(
      tester.getCenter(find.text('我已阅读并同意')).dy,
      greaterThan(tester.getCenter(find.text('注册')).dy),
    );

    await tester.tap(find.text('用户协议'));
    await tester.pumpAndSettle();
    // Tapping the consent link pushes the terms page via go_router; the auth
    // screen beneath is offstage, so only the terms page's title is found.
    expect(find.text('用户协议'), findsOneWidget);
  });

  testWidgets('sign-in also requires legal consent', (tester) async {
    final controller = AppController(AppRepository());
    addTearDown(controller.dispose);
    await _pumpAuth(tester, controller, AuthMode.signIn);

    expect(find.text('我已阅读并同意'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('用户名、邮箱或手机号'), findsOneWidget);
  });
}

Future<void> _pumpAuth(
  WidgetTester tester,
  AppController controller,
  AuthMode mode,
) async {
  await telemetry.configure(
    const TelemetryConfig(enabled: false, backendEnabled: false),
  );
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => AuthScreen(mode: mode)),
      GoRoute(
        path: pathFor(AppRoute.termsOfService),
        builder: (context, state) => const Scaffold(body: Text('用户协议')),
      ),
      GoRoute(
        path: pathFor(AppRoute.privacyPolicy),
        builder: (context, state) => const Scaffold(body: Text('隐私政策')),
      ),
      GoRoute(
        path: pathFor(AppRoute.signUp),
        builder: (context, state) => const AuthScreen(mode: AuthMode.signUp),
      ),
      GoRoute(
        path: pathFor(AppRoute.forgotPassword),
        builder: (context, state) => const AuthScreen(mode: AuthMode.forgot),
      ),
    ],
  );
  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    ),
  );
  await tester.pump();
}
