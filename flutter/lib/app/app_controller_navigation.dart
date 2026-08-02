part of 'app_controller.dart';

extension AppControllerNavigation on AppController {
  void _openEntryName(String? name, {required bool cold}) {
    final target = appRouteFromName(name);
    if (target == null) return;
    final decision = guardRoute(target, signedIn: signedIn, config: _config);
    _pendingRoute = decision.pending ?? _pendingRoute;
    final next = decision.route;
    if (cold) {
      _stack
        ..clear()
        ..add(AppRoute.home);
      if (next != AppRoute.home) _stack.add(next);
    } else if (_stack.last != next) {
      _stack.add(next);
    }
    telemetry.screen(next.name);
    _changed();
  }

  void _navigate(AppRoute route) {
    final decision = guardRoute(route, signedIn: signedIn, config: _config);
    _pendingRoute = decision.pending ?? _pendingRoute;
    _stack.add(decision.route);
    telemetry.screen(decision.route.name);
    _changed();
  }

  void _replaceAll(AppRoute route) {
    final decision = guardRoute(route, signedIn: signedIn, config: _config);
    _pendingRoute = decision.pending ?? _pendingRoute;
    _stack
      ..clear()
      ..add(decision.route);
    telemetry.screen(decision.route.name);
    _changed();
  }

  void _replaceTop(AppRoute route) {
    final decision = guardRoute(route, signedIn: signedIn, config: _config);
    _pendingRoute = decision.pending ?? _pendingRoute;
    _stack
      ..removeLast()
      ..add(decision.route);
    telemetry.screen(decision.route.name);
    _changed();
  }

  void _completeAuthentication() {
    final target = _pendingRoute ?? AppRoute.home;
    _pendingRoute = null;
    _replaceTop(target);
  }

  void _back() {
    if (!canGoBack) return;
    _stack.removeLast();
    telemetry.screen(route.name);
    _changed();
  }
}
