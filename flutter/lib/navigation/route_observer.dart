import 'package:flutter/widgets.dart';
import '../telemetry/telemetry.dart';

/// Reports every pushed route as a screen-view event. `didPop` is a no-op —
/// screen events fire on push/focus, not pop.
class AppRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    telemetry.screen(_nameOf(route));
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    telemetry.screen(_nameOf(newRoute));
  }

  String _nameOf(Route<dynamic>? route) {
    if (route == null) return 'unknown';
    final settings = route.settings;
    final name = settings.name;
    if (name != null && name.isNotEmpty) return name;
    if (settings.arguments is String) return settings.arguments as String;
    return route.runtimeType.toString();
  }
}
