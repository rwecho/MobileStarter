import 'payment_models.dart';

abstract interface class PaymentProvider {
  Future<List<StoreProduct>> loadProducts(StoreProductMapping? mapping);
  Future<PurchaseResult> purchase(String storeProductId);
  Future<List<PurchaseResult>> restore();
}
