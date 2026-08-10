import 'package:flutter/foundation.dart';

import '../state/async_state.dart';
import '../app/runtime_models.dart';
import 'payment_provider.dart';
import 'payment_repository.dart';

final class PaymentController extends ChangeNotifier {
  PaymentController({
    required PaymentRepository repository,
    required PaymentProvider provider,
    this.onMembershipChanged,
  }) : _repository = repository,
       _provider = provider;

  final PaymentRepository _repository;
  final PaymentProvider _provider;

  /// Invoked after a successful checkout so the app can refresh user/membership state
  /// (e.g. re-bootstrap). Optional — wired by the app shell in a later task.
  Future<void> Function()? onMembershipChanged;

  AsyncState<OrderView> purchaseState = const Idle();
  AsyncState<List<String>> restoreState = const Idle();
  String? pendingPlanId;
  bool _busy = false;

  /// Resets purchase state before starting a checkout for a (possibly different)
  /// plan, so the CheckoutScreen auto-triggers instead of showing a stale result.
  void resetPurchaseState() {
    purchaseState = const Idle<OrderView>();
  }

  Future<bool> checkout(String planId) async {
    if (_busy) return false;
    _busy = true;
    purchaseState = const Loading();
    notifyListeners();
    try {
      final idempotencyKey = 'flutter-${DateTime.now().microsecondsSinceEpoch}';
      final order = await _repository.createOrder(
        planId,
        idempotencyKey: idempotencyKey,
      );
      final result = await _provider.purchase(order.storeProductId);
      final verified = await _repository.verifyPurchase(
        orderId: order.orderId,
        receipt: result.receipt,
      );
      purchaseState = Success(verified);
      notifyListeners();
      if (verified.status == OrderStatus.success) {
        try {
          await _repository.membershipCurrent();
          await onMembershipChanged?.call();
        } catch (_) {
          // membership refresh failure must not mask a successful purchase
        }
      }
      return true;
    } on PaymentApiException catch (error) {
      purchaseState = error.status == 401
          ? const Unauthorized()
          : Failure(error.message);
      notifyListeners();
      return false;
    } catch (_) {
      purchaseState = const Offline();
      notifyListeners();
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<bool> restorePurchases() async {
    if (_busy) return false;
    _busy = true;
    restoreState = const Loading();
    notifyListeners();
    try {
      final results = await _provider.restore();
      final receipts = results.map((r) => r.receipt).toList();
      final entitlements = await _repository.restore(receipts);
      restoreState = entitlements.isEmpty
          ? const Empty()
          : Success(entitlements);
      notifyListeners();
      return true;
    } on PaymentApiException catch (error) {
      restoreState = error.status == 401
          ? const Unauthorized()
          : Failure(error.message);
      notifyListeners();
      return false;
    } catch (_) {
      restoreState = const Offline();
      notifyListeners();
      return false;
    } finally {
      _busy = false;
    }
  }
}
