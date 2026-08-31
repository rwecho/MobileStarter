// AppStore 的导航动作——从 AppStore.ets 拆出以服从 CI 350 行硬上限。
// ArkTS 无 partial class / extension，动作实现为收 store 的自由函数，
// AppStore 以薄委托保持原有调用面不变。
import { AppRoute, routeByName, routeName } from '../navigation/AppRoute'
import { guardRoute } from '../navigation/RouteGuard'
import { telemetry } from '../telemetry/Telemetry'
import { AppStore } from './AppStore'
import { ROUTE_BY_NAME } from './AppRouteTable'

export function navigateAction(store: AppStore, route: AppRoute): void {
  const decision = guardRoute(route, store.signedIn, store.config)
  if (decision.pending !== null) store.pendingRoute = decision.pending
  if (decision.unavailable) store.showToast('当前 App 未启用此功能')
  store.navStack.pushPath({ name: routeName(decision.route) })
  store.currentRoute = decision.route
  telemetry.screen(decision.route.toString())
}

// 解析应用内路由名（通知深链）并导航；外部 URL 与未知名忽略。
export function navigateByNameAction(store: AppStore, name: string | null): void {
  if (name === null || name.length === 0 || name.includes('://')) return
  const route = ROUTE_BY_NAME[name]
  if (route === undefined) return
  navigateAction(store, route)
}

export function openEntryByNameAction(store: AppStore, name: string | null, cold: boolean): void {
  if (name === null || name.length === 0 || name.includes('://')) return
  if (!store.initialized) {
    store.queuedEntryName = name
    store.queuedEntryCold = cold
    return
  }
  const target = ROUTE_BY_NAME[name]
  if (target === undefined) return
  const decision = guardRoute(target, store.signedIn, store.config)
  if (decision.pending !== null) store.pendingRoute = decision.pending
  if (decision.unavailable) store.showToast('当前 App 未启用此功能')
  if (cold) {
    // Cold start: reset to the tab shell (Home) + push the target if deep.
    store.navStack.clear()
    store.navStack.pushPath({ name: AppStore.TAB_NAME })
    if (decision.route !== AppRoute.Home && decision.route !== AppRoute.Profile) {
      store.navStack.pushPath({ name: routeName(decision.route) })
    }
  } else if (store.currentRoute !== decision.route) {
    store.navStack.pushPath({ name: routeName(decision.route) })
  }
  store.currentRoute = decision.route
  telemetry.screen(decision.route.toString())
}

// 切到底部 tab（Home=0 / Profile=1）：清栈后 push tabs 容器（Tabs 保活，
// 切换无翻页转场）。子页面/登录/闪屏仍走 navStack push。
function resetToTabs(store: AppStore, index: number): void {
  store.currentTab = index
  store.navStack.clear()
  store.navStack.pushPath({ name: AppStore.TAB_NAME })
  store.currentRoute = index === 0 ? AppRoute.Home : AppRoute.Profile
  telemetry.screen(store.currentRoute.toString())
}

function isTabRoute(route: AppRoute): boolean {
  return route === AppRoute.Home || route === AppRoute.Profile
}

export function replaceAllAction(store: AppStore, route: AppRoute): void {
  const decision = guardRoute(route, store.signedIn, store.config)
  if (decision.pending !== null) store.pendingRoute = decision.pending
  if (decision.unavailable) store.showToast('当前 App 未启用此功能')
  if (isTabRoute(decision.route)) {
    resetToTabs(store, decision.route === AppRoute.Home ? 0 : 1)
    return
  }
  store.navStack.clear()
  store.navStack.pushPath({ name: routeName(decision.route) })
  store.currentRoute = decision.route
  telemetry.screen(decision.route.toString())
}

export function replaceTopAction(store: AppStore, route: AppRoute): void {
  const decision = guardRoute(route, store.signedIn, store.config)
  if (decision.pending !== null) store.pendingRoute = decision.pending
  if (decision.unavailable) store.showToast('当前 App 未启用此功能')
  if (isTabRoute(decision.route)) {
    // 认证完成/登出后回到 tab 壳（Home tab）。
    resetToTabs(store, decision.route === AppRoute.Home ? 0 : 1)
    return
  }
  store.navStack.pop()
  store.navStack.pushPath({ name: routeName(decision.route) })
  store.currentRoute = decision.route
  telemetry.screen(decision.route.toString())
}

export function backAction(store: AppStore): void {
  if (!store.canGoBack) {
    return
  }
  store.navStack.pop()
  const names = store.navStack.getAllPathName()
  const top = names.length > 0 ? names[names.length - 1] : ''
  if (top === AppStore.TAB_NAME) {
    // 从子页面返回 tab 壳：当前 tab 由 currentTab 决定（Tabs 保活）。
    store.currentRoute = store.currentTab === 0 ? AppRoute.Home : AppRoute.Profile
  } else {
    store.currentRoute = routeByName(top) ?? AppRoute.Home
  }
  telemetry.screen(store.currentRoute.toString())
}
