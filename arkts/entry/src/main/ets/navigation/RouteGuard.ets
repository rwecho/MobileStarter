import { RuntimeConfig } from '../domain/Models'
import { AppRoute } from './AppRoute'

export class RouteDecision {
  route: AppRoute
  pending: AppRoute | null
  unavailable: boolean

  constructor(route: AppRoute, pending: AppRoute | null = null, unavailable: boolean = false) {
    this.route = route
    this.pending = pending
    this.unavailable = unavailable
  }
}

export function guardRoute(
  route: AppRoute,
  signedIn: boolean,
  config: RuntimeConfig | null
): RouteDecision {
  if (requiresAuthentication(route) && !signedIn) {
    return new RouteDecision(AppRoute.SignIn, route)
  }
  if (!featureAllows(route, config?.features ?? {})) {
    return new RouteDecision(AppRoute.Home, null, true)
  }
  return new RouteDecision(route)
}

function requiresAuthentication(route: AppRoute): boolean {
  return route === AppRoute.ProfileEdit || route === AppRoute.Statistics ||
    route === AppRoute.Invite || route === AppRoute.Coupons ||
    route === AppRoute.Checkout || route === AppRoute.Orders ||
    route === AppRoute.AccountSecurity || route === AppRoute.Devices ||
    route === AppRoute.DeleteAccount || route === AppRoute.NotificationCenter
}

function featureAllows(route: AppRoute, features: Record<string, boolean>): boolean {
  if (route === AppRoute.Membership || route === AppRoute.MembershipPlans ||
    route === AppRoute.Checkout || route === AppRoute.Orders) {
    return features['membership'] === true
  }
  if (route === AppRoute.NotificationCenter) return features['notifications'] === true
  if (route === AppRoute.ProfileEdit) return features['profileEditing'] === true
  if (route === AppRoute.Statistics) return features['statistics'] === true
  if (route === AppRoute.Coupons) return features['coupons'] === true
  if (route === AppRoute.Invite) return features['invites'] === true
  if (route === AppRoute.DeleteAccount) return features['accountDeletion'] === true
  return true
}
