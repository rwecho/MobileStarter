import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'app/mobile_ui_app.dart';
import 'telemetry/telemetry.dart';

void main() {
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
