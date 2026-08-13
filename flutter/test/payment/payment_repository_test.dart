@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter_flutter/payment/payment_repository.dart';
import 'package:mobilestarter_flutter/payment/token_store.dart';
import 'test_server.dart';

void main() {
  late PaymentRepository repo;

  setUp(() async {
    final token = await signUpAndGetToken('p12-repo-${DateTime.now().microsecondsSinceEpoch}@test.local');
    repo = PaymentRepository(tokenStore: InMemoryTokenStore(token));
  });

  test('createOrder returns pending + storeProductId, verify succeeds + grants entitlements', () async {
    final order = await repo.createOrder('pro-monthly', idempotencyKey: 'p12-repo-${DateTime.now().microsecondsSinceEpoch}');
    expect(order.status, 'pending');
    expect(order.storeProductId, isNotEmpty);

    final verified = await repo.verifyPurchase(orderId: order.orderId, receipt: {'productId': order.storeProductId});
    expect(verified.status.toString(), contains('success'));

    final mc = await repo.membershipCurrent();
    expect(mc.entitlements, isNotEmpty);
  });

  test('verifyPurchase with fail receipt yields a failed order', () async {
    final order = await repo.createOrder('pro-monthly', idempotencyKey: 'p12-repo-fail-${DateTime.now().microsecondsSinceEpoch}');
    final verified = await repo.verifyPurchase(orderId: order.orderId, receipt: {'productId': order.storeProductId, 'fail': true});
    expect(verified.status.toString(), contains('failed'));
  });
}
