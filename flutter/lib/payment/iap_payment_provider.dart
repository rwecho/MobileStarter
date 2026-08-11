import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'payment_models.dart';
import 'payment_provider.dart';

/// Real StoreKit / Play Billing provider via the `in_app_purchase` plugin.
///
/// **Server-authoritative flow (Apple/Google recommended)**:
/// - iOS: sends `purchaseID` (transactionIdentifier) → server calls Apple's
///   App Store Server API `getTransactionInfo` → authoritative verify.
/// - Android: sends `{productId, purchaseToken}` → server calls Google Play
///   Developer API → authoritative verify.
///
/// On desktop/web this provider should not be used; use MockPaymentProvider.
class IapPaymentProvider implements PaymentProvider {
  IapPaymentProvider() : _iap = InAppPurchase.instance;

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, Completer<PurchaseResult>> _pending = {};

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
        completer?.complete(_toResult(p));
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
    final results = <PurchaseResult>[];
    final completer = Completer<List<PurchaseResult>>();
    late StreamSubscription sub;
    sub = _iap.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.restored) {
          _iap.completePurchase(p);
          results.add(_toResult(p));
        }
      }
    }, onDone: () {
      sub.cancel();
      if (!completer.isCompleted) completer.complete(results);
    });
    await _iap.restorePurchases();
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      sub.cancel();
      return results;
    });
  }

  /// Build the platform-specific receipt the server expects.
  PurchaseResult _toResult(PurchaseDetails p) {
    Object receipt;
    if (Platform.isIOS) {
      // iOS: transactionIdentifier → server calls Apple Server API getTransactionInfo.
      receipt = p.purchaseID ?? '';
    } else if (Platform.isAndroid) {
      // Android: {productId, purchaseToken} → server calls Play Developer API.
      receipt = <String, dynamic>{
        'productId': p.productID,
        'purchaseToken': p.verificationData.serverVerificationData,
      };
    } else {
      receipt = p.purchaseID ?? '';
    }
    return PurchaseResult(storeProductId: p.productID, receipt: receipt);
  }
}
