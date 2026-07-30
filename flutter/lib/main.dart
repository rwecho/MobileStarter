import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'app/mobile_ui_app.dart';
import 'telemetry/telemetry.dart';

void main() {
  if (const String.fromEnvironment('MOBILEUI_APP_ID').isEmpty ||
      const String.fromEnvironment('MOBILEUI_APP_ENVIRONMENT').isEmpty) {
    throw StateError(
      'MOBILEUI_APP_ID / MOBILEUI_APP_ENVIRONMENT 未配置：请使用 '
      '--dart-define=MOBILEUI_APP_ID=<id> --dart-define=MOBILEUI_APP_ENVIRONMENT=<env> '
      '启动，两者均不能为空。',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    telemetry.report(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    telemetry.report(error, stack);
    return false;
  };
  runApp(const MobileUiApp());
  unawaited(telemetry.configure(const TelemetryConfig()));
}
