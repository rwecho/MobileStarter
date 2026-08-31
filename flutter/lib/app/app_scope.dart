import 'package:flutter/widgets.dart';
import 'app_controller.dart';

// re-export：AppController 的部分方法拆在 part 的 extension 里
// （app_controller_data.dart，服从 350 行硬上限），
// extension 方法只在调用点可见——screens 统一经由本门面取 controller。
export 'app_controller.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final AppScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context');
    return scope!.notifier!;
  }
}
