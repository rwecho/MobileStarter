import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter_flutter/app/runtime_models.dart';
import 'package:mobilestarter_flutter/payment/payment_models.dart';

void main() {
  test('BillingPlan parses storeProductMapping', () {
    final plan = BillingPlan.fromJson({
      'id': 'pro-monthly', 'tierId': 'pro', 'name': 'Pro', 'interval': 'month',
      'priceMinor': 1800, 'currency': 'CNY', 'provider': 'mock',
      'storeProductMapping': {'apple': 'com.x.pro', 'google': 'pro_g', 'hms': 'pro_h'},
    });
    expect(plan.storeProductMapping?.apple, 'com.x.pro');
    expect(plan.storeProductMapping?.hms, 'pro_h');
  });

  test('BillingPlan storeProductMapping nullable', () {
    final plan = BillingPlan.fromJson({
      'id': 'free', 'tierId': 'free', 'name': 'Free', 'interval': 'lifetime',
      'priceMinor': 0, 'currency': 'CNY', 'provider': 'mock',
    });
    expect(plan.storeProductMapping, isNull);
  });

  test('OrderView parses status/provider/storeTransactionId/expiresAt', () {
    final order = OrderView.fromJson({
      'id': 'o1', 'planId': 'pro-monthly', 'status': 'success',
      'amountMinor': 1800, 'currency': 'CNY', 'provider': 'mock',
      'storeTransactionId': 't1', 'receiptHash': 'h1', 'expiresAt': '2026-12-31T00:00:00.000Z',
    });
    expect(order.status, OrderStatus.success);
    expect(order.provider, 'mock');
    expect(order.storeTransactionId, 't1');
    expect(order.expiresAt, '2026-12-31T00:00:00.000Z');
  });

  test('MembershipCurrent fromJson', () {
    final mc = MembershipCurrent.fromJson({
      'tier': 'pro',
      'entitlements': [{'key': 'export.hd', 'expiresAt': null}],
      'subscription': {'planId': 'pro-monthly', 'status': 'active', 'renewAt': '2026-12-31T00:00:00.000Z'},
    });
    expect(mc.tier, 'pro');
    expect(mc.entitlements.first.key, 'export.hd');
    expect(mc.subscription?.planId, 'pro-monthly');
  });
}
