import 'package:flutter/widgets.dart';
import 'support_controller.dart';

final class SupportScope extends InheritedNotifier<SupportController> {
  const SupportScope({
    required SupportController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static SupportController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SupportScope>();
    assert(scope != null, 'SupportScope is missing');
    return scope!.notifier!;
  }
}
