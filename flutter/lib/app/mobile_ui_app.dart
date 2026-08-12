import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_router_config.dart';
import '../payment/iap_payment_provider.dart';
import '../payment/mock_payment_provider.dart';
import '../payment/payment_controller.dart';
import '../payment/payment_repository.dart';
import '../payment/payment_scope.dart';
import '../payment/token_store.dart';
import '../support/support_controller.dart';
import '../support/support_repository.dart';
import '../support/support_scope.dart';
import '../theme/app_theme.dart';
import 'app_controller.dart';
import 'app_repository.dart';
import 'app_scope.dart';

class MobileUiApp extends StatefulWidget {
  const MobileUiApp({super.key});

  @override
  State<MobileUiApp> createState() => _MobileUiAppState();
}

class _MobileUiAppState extends State<MobileUiApp> with WidgetsBindingObserver {
  late final AppController controller;
  final supportController = SupportController(SupportRepository());
  late final PaymentController paymentController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = AppController(AppRepository());
    paymentController = PaymentController(
      repository: PaymentRepository(tokenStore: SecureTokenStore()),
      // dart:io Platform is unsupported on web (throws on _operatingSystem);
      // use kIsWeb + defaultTargetPlatform. IAP (in_app_purchase) has no web
      // support, so web always uses the mock provider.
      provider: (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android))
          ? IapPaymentProvider()
          : MockPaymentProvider(),
      onMembershipChanged: () => controller.initialize(),
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.resume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    supportController.dispose();
    paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: SupportScope(
        controller: supportController,
        child: PaymentScope(
          controller: paymentController,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              controller,
              supportController,
              paymentController,
            ]),
            builder: (context, _) => _RouterHost(controller: controller),
          ),
        ),
      ),
    );
  }

  static ThemeMode _themeModeOf(AppController controller) {
    final value = controller.user?.settings['theme'];
    if (value == 'dark') return ThemeMode.dark;
    if (value == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  static Locale _localeOf(AppController controller) {
    return controller.user?.settings['language'] == 'en-US'
        ? const Locale('en', 'US')
        : const Locale('zh', 'CN');
  }

  static double _textScaleOf(AppController controller) {
    final value = controller.user?.settings['textScale'];
    return value is num ? value.toDouble().clamp(0.9, 1.3) : 1;
  }
}

/// Hosts the app's GoRouter. URL deep links / entry intents resolve natively
/// through go_router's route information provider and redirect; the controller
/// drives auth-state redirects via `refreshListenable`.
class _RouterHost extends StatefulWidget {
  const _RouterHost({required this.controller});

  final AppController controller;

  @override
  State<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends State<_RouterHost> {
  late GoRouter _router =
      buildAppRouter(widget.controller, routerRefresh: widget.controller);

  @override
  void didUpdateWidget(_RouterHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      setState(() {
        _router =
            buildAppRouter(widget.controller, routerRefresh: widget.controller);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      title: 'MobileStarter',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _MobileUiAppState._themeModeOf(widget.controller),
      locale: _MobileUiAppState._localeOf(widget.controller),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(
              _MobileUiAppState._textScaleOf(widget.controller),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
