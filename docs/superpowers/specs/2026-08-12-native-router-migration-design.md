# 三端原生路由迁移设计

- 状态：draft
- 日期：2026-08-12
- 关联：issue #2（[ArkTS] 壳路由建议改用原生 Navigation）

## 背景

issue #2 指出 ArkTS 壳路由（`arkts/entry/src/main/ets/pages/Index.ets` 的 `RouteHost / LaunchAuthHost / ProfileHost / SettingsHost`）用 `if / else if` 按 `store.route` 条件渲染分发页面，导致跳转后源页面被销毁、返回时重建——`@State` 重置、列表滚动位置丢失、`aboutToAppear` 重跑。

排查发现这是**三端共性问题**，非 ArkTS 独有：

- **Flutter**：`flutter/lib/app/app_controller_navigation.dart` 已维护真实栈 `_stack: List<AppRoute>`（`navigate`/`back`/`replace`/`canGoBack` 齐全），但 `flutter/lib/app/mobile_ui_app.dart:121` 的 `home: AppRouter.screenFor(controller.route)` 只取栈顶交 `switch` 渲染——有栈数据、无实例保活，是个"假栈"。
- **RN**：`react-native/src/state/useAppShellState.ts` / `AppStore.tsx` 同样有 `navigate/back/replace/stack` 抽象，但 `react-native/src/navigation/AppRouter.tsx` 仍是 `switch(route)` 返回单组件——同样假栈。
- **ArkTS**：`Index.ets` 纯 `if/else` 单值 route，连栈数据都没有。

**病根**：三端渲染层都是 switch，页面实例从未被保活。

## 目标 / 非目标

**目标**

- 三端用各端原生栈导航组件替换 switch 渲染，根治"返回重建/状态丢失"。
- 底部 Tab 切换保活。
- 保留 deep-link / entry-intent / guard / telemetry 四项能力。

**非目标**

- 不改 UI、不改业务逻辑。
- 不改 guard 规则（只把拦截点从 `navigate` 搬到 router 钩子）。

## 决策（已确认）

| 维度 | 选择 |
|---|---|
| 形态 | Shell（底部 3 Tab）+ 每 Tab 一个原生栈 |
| 调用 | 直接用各端原生 API（废弃统一 `navigate(route)` 抽象） |
| ArkTS | `Navigation` + `NavPathStack` + `NavDestination` |
| Flutter | `go_router`（`StatefulShellRoute` + `redirect` + `NavigatorObserver`） |
| RN | `@react-navigation/native-stack` + `bottom-tabs` |

## 目标架构（业界标准 App 形态）

1. **Shell**：底部 Home / 会员 / 我的 三 Tab，每 Tab 独立导航栈；Tab 切换各栈保活（三端原生 Tab 默认行为）。
2. **鉴权 gate**：`signedIn ? MainTabs : AuthStack`。未登录走顶层 AuthStack（登录/注册/引导/找回密码/验证邮箱/重置密码），登录完成后切到 MainTabs。
3. **二级页**：从某 Tab 进入的设置/详情/法律/关于等，push 到该 Tab 自己的栈（标准 push），返回自然回到来源页——直接解决 issue "抽屉设置返回重建阅读器"。
4. **Deep-link / entry-intent**：冷启动 reset 重建返回栈（根 → … → 目标），热启动 push。
5. **Guard / telemetry**：集中在 router 钩子。guard：go_router `redirect` / @navigation `onStateChange` / ArkTS push 包装层。telemetry：`NavigatorObserver.didPush` / `screenListeners.focus` / `NavDestination.onShown`。

## 各端落点

### ArkTS — `Navigation` / `NavPathStack` / `NavDestination`

- `Index.ets` 根换成 `Navigation(this.navStack)`，页面以 `NavDestination` 按 `AppRoute` 名注册。
- **删除** `RouteHost / LaunchAuthHost / ProfileHost / SettingsHost` 四个 `if/else` switch。
- Shell：底部 `Tabs`（3 Tab），每 Tab 持独立 `NavPathStack`。确切的 "Navigation × Tabs 嵌套" 在实现计划阶段依 HarmonyOS 官方文档定（候选 A：单根 `Navigation` + `Tabs` 内嵌子栈；候选 B：三 Tab 各持独立 `Navigation`）。
- 跳转：`pushPath / replacePath / pop`。
- guard：push 包装层；telemetry：`NavDestination.onShown`；entry-intent：cold `clear + push home + push target`。
- 移除 `AppStore.route` 单值，由栈状态驱动。

### Flutter — `go_router`

- `mobile_ui_app.dart` 改 `MaterialApp.router(routerConfig:)`。
- **删除** `app_router.dart` 的 switch + `app_controller_navigation.dart` 的 `_stack`。
- `StatefulShellRoute`（三 branch=三 Tab，各保活子栈）+ `redirect:`（guard）+ `NavigatorObserver`（telemetry）。
- 跳转：`context.push / go / pop`。
- entry-intent：`router.go`（cold 清栈）/ `push`；deep-link 复用已有 `didPushRouteInformation`。
- 保留 `AppRoute` 枚举作 path 来源；解耦页面里对 `controller.route` 的读取。

### RN — `@react-navigation/native-stack` + `bottom-tabs`

- 装 `@react-navigation/{native, native-stack, bottom-tabs}`。
- `NavigationContainer` > `RootStack`（顶层 auth/onboarding gate）+ `BottomTabs`（三 Tab 各 native-stack）。
- **删除** `AppRouter.tsx` 的 switch + `useAppShellState` 的 stack + `AppStore` 的自造 `navigation` 对象。
- 跳转：`navigation.navigate / goBack`。
- guard：root `onStateChange` / `listeners`；telemetry：`screenListeners.focus`；entry-intent cold：`reset`。

## 数据流

路由状态从 "`store.route` 单值" 变为 "各端原生栈真实状态"。`AppStore` / `AppController` 不再持有 route，只保留登录态 / 配置 / 用户等业务态。guard 仍读这些态，拦截点移到 router 钩子。

## 迁移策略

- 三端各自分步：先搭 Shell+栈骨架跑通核心流（Home → 详情 → back 保活）→ 再迁其余 40+ 页。
- 保留 `AppRoute` 常量作路由名/path 唯一来源；`navigate(route)` 调用点批量改为各端原生 API。
- 每端独立可验证、可分 PR。
- 顺序：**Flutter → ArkTS → RN**（Flutter 已有假栈最易先验证；ArkTS 是 issue 主角；RN 调用点最多放最后）。

## 测试与验收

**新增自动化**

- Flutter：widget 测试（go_router `redirect` / guard / entry-intent reset）。
- RN：`renderNavigation` 测试（guard / entry-intent）。
- ArkTS：`hvigorw assembleHap` 通过 + 真机/模拟器手测（ArkTS 单测能力有限）。

**三端统一手测验收**

1. 列表滚动 → 进详情 → 返回 → 滚动位置/数据保留（不重刷）。
2. Tab 切换 → 回来 → 各 Tab 状态在。
3. 未登录访问受保护页 → 跳登录 → 完成后回到目标页。
4. 冷启动 deep-link 到深层页 → 返回栈正确（根 → … → 目标）。
5. （issue 专项）阅读器 → 文章详情 → 返回不重刷。

## 风险

- **ArkTS**：Navigation × Tabs 保活组合需真机验证；冷启 deep-link 还原栈序。
- **Flutter**：`StatefulShellRoute` 保活与现有 `AnimatedBuilder` / `controller.route` 耦合，需逐一解耦页面读取。
- **RN**：引入 `@react-navigation` 较大依赖；`useApp().navigate` 调用点几十处全改。
- **三端**：散落的 `controller.route` / `useApp().route` 读取点（非导航用途）要清理。
