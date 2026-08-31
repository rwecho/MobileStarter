import { createNavigationContainerRef } from '@react-navigation/native';
import type { AppRoute } from './routes';

// Every route takes no params. AuthScreen mode and PreferenceScreen kind are
// derived from the route name inside the screen wrapper (AuthRoute/PreferenceRoute),
// not passed as nav params — keeps RootParamList uniform.
//
// 'tabs' 是 Bottom Tab Navigator 容器（对齐 Flutter StatefulShellRoute / ArkTS Tabs）：
// home / profile.home 挂在它内部，其余路由仍是 root stack 直挂屏。
export type RootParamList = { [K in AppRoute]: undefined } & { tabs: undefined };

// Imperative navigation handle. AppStore.navigate/replace/back forward to this
// ref so existing useApp().navigate(...) call sites work unchanged after the
// migration to @react-navigation (issue #2: real native stack keeps source
// screens alive on push).
export const navigationRef = createNavigationContainerRef<RootParamList>();

// @react-navigation's navigate() overloads require a literal route name; a
// dynamic union (AppRoute) won't satisfy them, so this helper centralizes the
// cast. See https://reactnavigation.org/docs/typescript.
export function navigateRoute(name: AppRoute): void {
  if (navigationRef.isReady()) navigationRef.navigate(name as never);
}

const TAB_ROUTES: ReadonlySet<AppRoute> = new Set<AppRoute>(['home', 'profile.home']);

// reset 语义的嵌套适配：tab 根路由要写进 tabs 容器的嵌套 state，
// 其余路由仍是 root stack 直挂屏，直接平铺 reset。
export function resetToRoute(name: AppRoute): void {
  if (!navigationRef.isReady()) return;
  if (TAB_ROUTES.has(name)) {
    navigationRef.reset({
      index: 0,
      routes: [{ name: 'tabs', state: { index: 0, routes: [{ name }] } }],
    } as never);
    return;
  }
  navigationRef.reset({ routes: [{ name }] });
}

// 冷启动深链：tabs(home) 之上 push 目标页——back 回首页，
// 与旧版平铺 [home, entry] 栈语义等价。
export function resetToHomeThenPush(name: AppRoute): void {
  if (!navigationRef.isReady()) return;
  resetToRoute('home');
  navigateRoute(name);
}
