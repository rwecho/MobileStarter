import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../theme/app_theme.dart';
import 'app_controller.dart';
import 'app_repository.dart';
import 'app_router.dart';
import 'app_scope.dart';
import '../support/support_controller.dart';
import '../support/support_repository.dart';
import '../support/support_scope.dart';

class MobileUiApp extends StatefulWidget {
  const MobileUiApp({super.key});

  @override
  State<MobileUiApp> createState() => _MobileUiAppState();
}

class _MobileUiAppState extends State<MobileUiApp> with WidgetsBindingObserver {
  late final AppController controller;
  final supportController = SupportController(SupportRepository());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = AppController(AppRepository());
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await controller.initialize();
    controller.openEntryName(
      _routeName(WidgetsBinding.instance.platformDispatcher.defaultRouteName),
      cold: true,
    );
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    controller.openEntryName(
      _routeName(routeInformation.uri.toString()),
      cold: false,
    );
    return true;
  }

  String? _routeName(String location) {
    if (location.isEmpty || location == '/') return null;
    final uri = Uri.tryParse(location);
    if (uri == null) return null;
    return uri.queryParameters['route'] ??
        (uri.pathSegments.isEmpty ? null : uri.pathSegments.last);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: SupportScope(
        controller: supportController,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'MobileStarter',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _themeModeOf(controller),
            locale: _localeOf(controller),
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(_textScaleOf(controller)),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: AppRouter.screenFor(controller.route),
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
