import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter_flutter/app/mobile_ui_app.dart';
import 'package:mobilestarter_flutter/telemetry/telemetry.dart';

void main() {
  testWidgets('launch flow shows a top-left countdown and skip action', (
    tester,
  ) async {
    await telemetry.configure(
      const TelemetryConfig(enabled: false, backendEnabled: false),
    );
    await tester.pumpWidget(const MobileUiApp());

    expect(find.text('MobileStarter'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    final countdown = find.text('3');
    final skip = find.text('跳过');
    expect(countdown, findsOneWidget);
    expect(skip, findsOneWidget);
    expect(
      tester.getTopLeft(countdown).dx,
      lessThan(tester.getTopLeft(skip).dx),
    );
  });
}
