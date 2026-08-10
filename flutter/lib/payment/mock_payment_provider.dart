import 'payment_models.dart';
import 'payment_provider.dart';

class MockPaymentProvider implements PaymentProvider {
  /// When true, the next/ongoing purchases produce a fail receipt the server
  /// rejects (verifies as a failed order). This is the sandbox failure mode.
  bool failPurchases = false;
  final Set<String> _owned = {};

  @override
  Future<List<StoreProduct>> loadProducts(StoreProductMapping? mapping) async {
    if (mapping == null) return const [];
    return [
      if (mapping.apple != null) StoreProduct(storeProductId: mapping.apple!),
      if (mapping.google != null) StoreProduct(storeProductId: mapping.google!),
      if (mapping.hms != null) StoreProduct(storeProductId: mapping.hms!),
    ];
  }

  @override
  Future<PurchaseResult> purchase(String storeProductId) async {
    final receipt = <String, Object?>{'productId': storeProductId, if (failPurchases) 'fail': true};
    if (!failPurchases) _owned.add(storeProductId);
    return PurchaseResult(storeProductId: storeProductId, receipt: receipt);
  }

  @override
  Future<List<PurchaseResult>> restore() async {
    return _owned
        .map((id) => PurchaseResult(storeProductId: id, receipt: <String, Object?>{'productId': id}))
        .toList(growable: false);
  }
}
