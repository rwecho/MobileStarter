import 'package:flutter/widgets.dart';
import 'payment_controller.dart';

final class PaymentScope extends InheritedNotifier<PaymentController> {
  const PaymentScope({
    required PaymentController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static PaymentController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaymentScope>();
    assert(scope != null, 'PaymentScope is missing');
    return scope!.notifier!;
  }
}
