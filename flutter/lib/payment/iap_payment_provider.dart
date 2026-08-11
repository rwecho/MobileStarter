import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'payment_models.dart';
import 'payment_provider.dart';

/// Real StoreKit / Play Billing provider via the `in_app_purchase` plugin.
/// On iOS 15+ the plugin uses StoreKit 2; `serverVerificationData` is the
/// signed transaction JWS that the server (ApplePaymentAdapter) verifies.
class IapPaymentProvider implements PaymentProvider {
  IapPaymentProvider() : _iap = InAppPurchase.instance;

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, Completer<PurchaseResult>> _pending = {};

  /// Start listening to the purchase stream. Call once at app init.
  void start() {
    _sub ??= _iap.purchaseStream.listen(_onPurchase);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _onPurchase(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      final completer = _pending.remove(p.productID);
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        _iap.completePurchase(p);
        completer?.complete(PurchaseResult(
          storeProductId: p.productID,
          receipt: p.verificationData.serverVerificationData,
        ));
      } else if (p.status == PurchaseStatus.error || p.status == PurchaseStatus.canceled) {
        completer?.completeError(Exception(p.error?.message ?? 'purchase failed'));
      }
    }
  }

  @override
  Future<List<StoreProduct>> loadProducts(StoreProductMapping? mapping) async {
    if (mapping == null) return const [];
    final ids = <String>{
      if (Platform.isIOS && mapping.apple != null) mapping.apple!,
      if (Platform.isAndroid && mapping.google != null) mapping.google!,
    };
    if (ids.isEmpty) return const [];
    final resp = await _iap.queryProductDetails(ids);
    return resp.productDetails
        .map((p) => StoreProduct(storeProductId: p.id, title: p.title))
        .toList(growable: false);
  }

  @override
  Future<PurchaseResult> purchase(String storeProductId) async {
    start();
    final resp = await _iap.queryProductDetails({storeProductId});
    if (resp.productDetails.isEmpty) {
      throw Exception('product not found: $storeProductId');
    }
    final product = resp.productDetails.first;
    final completer = Completer<PurchaseResult>();
    _pending[storeProductId] = completer;
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
    return completer.future;
  }

  @override
  Future<List<PurchaseResult>> restore() async {
    start();
    // restorePurchases triggers the purchaseStream with restored items.
    // We collect them via a temporary completer.
    final results = <PurchaseResult>[];
    final completer = Completer<List<PurchaseResult>>();
    late StreamSubscription sub;
    sub = _iap.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.restored) {
          _iap.completePurchase(p);
          results.add(PurchaseResult(
            storeProductId: p.productID,
            receipt: p.verificationData.serverVerificationData,
          ));
        }
      }
    }, onDone: () {
      sub.cancel();
      if (!completer.isCompleted) completer.complete(results);
    });
    await _iap.restorePurchases();
    // Give the stream a moment to deliver, then resolve.
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      sub.cancel();
      return results;
    });
  }
}
