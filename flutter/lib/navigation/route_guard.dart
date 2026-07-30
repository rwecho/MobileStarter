import '../app/runtime_models.dart';
import 'app_route.dart';

final class RouteDecision {
  const RouteDecision(this.route, {this.pending, this.unavailable = false});

  final AppRoute route;
  final AppRoute? pending;
  final bool unavailable;
}

RouteDecision guardRoute(
  AppRoute route, {
  required bool signedIn,
  required RuntimeConfig? config,
}) {
  if (_protectedRoutes.contains(route) && !signedIn) {
    return RouteDecision(AppRoute.signIn, pending: route);
  }
  if (!_featureAllows(route, config?.features ?? const {})) {
    return const RouteDecision(AppRoute.home, unavailable: true);
  }
  return RouteDecision(route);
}

const _protectedRoutes = <AppRoute>{
  AppRoute.profileEdit,
  AppRoute.statistics,
  AppRoute.invite,
  AppRoute.coupons,
  AppRoute.checkout,
  AppRoute.orders,
  AppRoute.accountSecurity,
  AppRoute.devices,
  AppRoute.deleteAccount,
  AppRoute.notificationCenter,
};

bool _featureAllows(AppRoute route, Map<String, bool> features) {
  if ({
    AppRoute.membership,
    AppRoute.membershipPlans,
    AppRoute.checkout,
    AppRoute.orders,
  }.contains(route)) {
    return features['membership'] == true;
  }
  if (route == AppRoute.notificationCenter) {
    return features['notifications'] == true;
  }
  if (route == AppRoute.profileEdit) return features['profileEditing'] == true;
  if (route == AppRoute.statistics) return features['statistics'] == true;
  if (route == AppRoute.coupons) return features['coupons'] == true;
  if (route == AppRoute.invite) return features['invites'] == true;
  if (route == AppRoute.deleteAccount) {
    return features['accountDeletion'] == true;
  }
  return true;
}
