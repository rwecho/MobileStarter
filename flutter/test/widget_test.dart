import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter_flutter/app/mobile_ui_app.dart';
import 'package:mobilestarter_flutter/telemetry/telemetry.dart';

void main() {
  testWidgets('launch flow opens the remote promotion surface', (tester) async {
    await telemetry.configure(
      const TelemetryConfig(enabled: false, backendEnabled: false),
    );
    await tester.pumpWidget(const MobileUiApp());

    expect(find.text('MobileStarter'), findsOneWidget);
    await tester.tap(find.text('轻触继续'));
    await tester.pumpAndSettle();

    expect(find.text('立即体验'), findsOneWidget);
  });
}
