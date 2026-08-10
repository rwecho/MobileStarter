import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter_flutter/app/runtime_models.dart';
import 'package:mobilestarter_flutter/payment/mock_payment_provider.dart';
import 'package:mobilestarter_flutter/payment/payment_controller.dart';
import 'package:mobilestarter_flutter/payment/payment_repository.dart';
import 'package:mobilestarter_flutter/payment/token_store.dart';
import 'package:mobilestarter_flutter/state/async_state.dart';
import 'test_server.dart';

void main() {
  late PaymentRepository repo;
  late PaymentController controller;

  setUp(() async {
    final token = await signUpAndGetToken('p12-ctrl-${DateTime.now().microsecondsSinceEpoch}@test.local');
    repo = PaymentRepository(tokenStore: InMemoryTokenStore(token));
  });

  test('checkout success → Success + order success + entitlements granted', () async {
    controller = PaymentController(repository: repo, provider: MockPaymentProvider());
    final ok = await controller.checkout('pro-monthly');
    expect(ok, isTrue);
    expect(controller.purchaseState, isA<Success<OrderView>>());
    expect((controller.purchaseState as Success<OrderView>).data.status, OrderStatus.success);
    final mc = await repo.membershipCurrent();
    expect(mc.entitlements, isNotEmpty);
  });

  test('checkout with failPurchases → HTTP ok but order failed, no entitlements', () async {
    controller = PaymentController(
      repository: repo,
      provider: MockPaymentProvider()..failPurchases = true,
    );
    final ok = await controller.checkout('pro-monthly');
    // The server accepts the fail receipt and marks the ORDER as failed (HTTP 200),
    // so checkout completes successfully at the transport level but grants nothing.
    expect(ok, isTrue);
    expect(controller.purchaseState, isA<Success<OrderView>>());
    expect((controller.purchaseState as Success<OrderView>).data.status, OrderStatus.failed);
    final mc = await repo.membershipCurrent();
    expect(mc.entitlements, isEmpty);
  });
}
