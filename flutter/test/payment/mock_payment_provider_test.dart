import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter_flutter/payment/mock_payment_provider.dart';

void main() {
  test('purchase returns a receipt carrying the productId', () async {
    final provider = MockPaymentProvider();
    final result = await provider.purchase('com.x.pro');
    expect(result.storeProductId, 'com.x.pro');
    expect((result.receipt as Map)['productId'], 'com.x.pro');
  });

  test('purchase with fail:true yields a fail receipt', () async {
    final provider = MockPaymentProvider();
    final result = await provider.purchase('com.x.pro', fail: true);
    expect((result.receipt as Map)['fail'], true);
  });

  test('restore replays previously purchased products', () async {
    final provider = MockPaymentProvider();
    await provider.purchase('com.x.pro');
    await provider.purchase('pro_g');
    final restored = await provider.restore();
    expect(restored.map((r) => r.storeProductId).toSet(), {'com.x.pro', 'pro_g'});
  });
}
