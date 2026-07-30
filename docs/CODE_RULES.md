# MobileUI 三端工程规范

## 1. 目标

MobileUI 是可派生不同产品的母模板。三端共享产品语义、路由名称、状态机、
设计令牌和测试场景；平台只负责原生表现及能力适配。

## 2. 固定模块

```text
app/
  bootstrap       启动、依赖注入、路由守卫
  navigation      类型化路由与深链
core/
  errors          统一错误模型
  network         网络状态与请求协议
  storage         安全存储协议
design_system/
  tokens          颜色、间距、字体、圆角、阴影、动效
  icons           仅 SVG
  components      Button、Field、Card、ListRow、反馈组件
features/
  launch          Logo、运营 Splash、首次引导
  auth            登录、注册、找回、验证、新密码
  home            通用首页框架
  profile         我的、资料、统计、邀请、优惠券
  membership      会员、方案、订阅、订单
  settings        完整设置及子页
  notifications   通知中心与通知偏好
```

## 3. 统一路由

| Route ID | 页面 |
|---|---|
| `launch.logo` | 系统初始化 Logo |
| `launch.promo` | 可运营 Splash |
| `launch.onboarding` | 首次引导 |
| `home` | 首页 |
| `auth.signIn` | 登录 |
| `auth.signUp` | 注册 |
| `auth.forgotPassword` | 找回密码 |
| `auth.verifyEmail` | 验证邮箱 |
| `auth.resetPassword` | 设置新密码 |
| `profile.home` | 我的 |
| `profile.edit` | 个人资料 |
| `profile.statistics` | 使用统计 |
| `profile.invite` | 邀请好友 |
| `profile.coupons` | 优惠券 |
| `membership.home` | 会员中心 |
| `membership.plans` | 方案对比 |
| `membership.checkout` | 订阅确认 |
| `membership.orders` | 订单管理 |
| `settings.home` | 设置 |
| `settings.accountSecurity` | 账户与安全 |
| `settings.devices` | 登录设备 |
| `settings.notifications` | 通知 |
| `settings.privacy` | 隐私 |
| `settings.general` | 通用 |
| `settings.appearance` | 外观 |
| `settings.language` | 语言 |
| `settings.textSize` | 字号 |
| `settings.storage` | 存储与缓存 |
| `settings.permissions` | 权限 |
| `settings.helpFeedback` | 帮助与反馈 |
| `settings.legal` | 协议与政策 |
| `settings.about` | 关于与版本 |
| `settings.deleteAccount` | 注销账号 |
| `notifications.center` | 通知中心 |

## 4. 统一状态

```text
idle -> loading -> success
              ├-> empty
              ├-> error -> loading (retry)
              ├-> offline -> loading (reconnect)
              └-> unauthorized -> auth.signIn
```

禁止组合 `isLoading + hasError + isEmpty`。必须使用互斥的枚举/联合类型，
并携带必要数据或错误。

## 5. 组件边界

- 页面负责布局和组合，不负责请求或持久化。
- Controller/ViewModel 负责事件到状态的转换。
- Repository 只暴露领域模型，不暴露 HTTP/数据库结构。
- 设计系统组件不得导入任何 feature。
- 一个组件出现两次即可评估抽取，出现三次必须抽取。
- 同一页面出现三种以上卡片样式，视为设计系统失控。
- 列表项统一使用 `AppListTile`，表单统一使用 `AppField`。

## 6. SVG 图标规范

- 统一使用 24x24 `viewBox`、`currentColor`、2px 描边、round cap/join。
- 文件名使用 `kebab-case.svg`。
- 禁止 Emoji、Unicode 箭头、文本符号、icon font。
- 箭头、关闭、返回、勾选、警告等全部由 SVG 提供。
- 平台组件必须能应用语义颜色，并提供无障碍标签。

## 7. 三端差异

| 约束 | Flutter | React Native | ArkTS |
|---|---|---|---|
| 状态 | sealed class + controller | discriminated union + reducer/store | union/enum + ViewModel |
| 路由 | typed route enum/config | typed route map | typed page enum/config |
| UI 嵌套 | Widget tree <= 6 | JSX <= 6 | ArkUI DSL <= 6 |
| 组件文件 | <= 250 行 | <= 250 行 | <= 250 行 |
| 方法 | <= 40 行 | <= 40 行 | <= 40 行 |
| 图标 | `flutter_svg` | `react-native-svg` | SVG media/resource |
| 格式 | `dart format` | Prettier | hvigor/IDE formatter |
| 静态检查 | `flutter analyze` | ESLint + TypeScript | ArkTSCheck |

