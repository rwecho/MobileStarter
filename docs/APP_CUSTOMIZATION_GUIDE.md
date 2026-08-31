# 落地定制指南：主题 / 闪屏 / 品牌资产 / 法务合规

新产品落地时"改成自己的品牌"涉及哪些文件、按什么顺序改，是本指南回答的问题。
身份类替换（包名 / Bundle ID / URL scheme / 目录结构）由 `mobileui` CLI 完成，见
[`docs/MOBILEUI_CLI.md`](MOBILEUI_CLI.md)；本指南覆盖 CLI 之后的**换肤层、
法务合规内容（隐私政策/用户协议）与密钥模型**。文末附可配置内容总表。

## 三层模型

品牌内容分布在三层，改法完全不同，先判断要改的东西属于哪层：

| 层 | 内容 | 改法 | 生效方式 |
|---|---|---|---|
| **L1 服务端运营层** | 应用名 / 标语 / 主色、品牌闪屏内容、会员档位、功能开关 | 运营控制台或 DB，**不改代码** | 客户端下次 bootstrap 拉取 |
| **L2 客户端设计 token 层** | 全量配色（含深色模式）、圆角、间距 | 改三端 token 文件 | 重新构建 |
| **L3 原生资产层** | 桌面图标、原生启动屏、应用显示名、原生背景色 | 替换图片资源 + 平台配置 | 重新构建 / prebuild |

判断口诀：**首页文案和闪屏活动在 L1；全局颜色在 L2；桌面图标和开屏第一帧在 L3。**

## mobileui CLI 与本指南的分工

CLI 只做**身份替换**（`create` 时一次性文本重写），不做任何换肤或内容配置。
对照 `tool/mobileui/lib/identity_rewriter.dart` 的替换表：

CLI 覆盖：

| create 参数 | 替换目标 |
|---|---|
| `--display-name` | RN `app.json` name、Flutter label 与描述、ArkTS `string.json`（含 en_US）里的 "MobileStarter" |
| `--app-id` | URL scheme（`mobilestarter://` → `<appId>://`）、包名字符串、server 深链校验文件、biz-server `APP_ID` |
| `--organization` | native 包名 `com.<organization>.<产品名>`（Android / iOS / HarmonyOS） |
| （自动） | 移除 ArkTS 签名凭据、改写 CI workflow 镜像名占位 |

CLI **不**覆盖（按本指南对应层操作）：

- L1 全部内容（brand / splash / legal / tiers…）——运营层，控制台或 DB
- L2 主题 token——改代码
- L3 图标与启动屏的**图片资产**——CLI 只换名字字符串，不动图片
- 深链关联域名（`associatedDomains` / `intentFilters` 指向的 auth.zhongbei.tech）

命令速查：`create` / `doctor`（结构与身份残留检查，落地后必跑）/
`feature add` / `template` / `update --check`（检查上游模板新版本，不覆盖业务
代码）。注意：**没有 `rename` 命令**——create 之后要改身份只能手工改并用
`doctor` 验证残留。

## 密钥与 client secret：客户端不需要

常见疑问："落地新 app，客户端要不要配一个 client secret？"——**不需要**。
本模板是"声明式租户 + 会话验签"模型，没有 per-app 密钥：

- 客户端 → server：每个请求带 `x-app-id` + `x-app-environment` 两个声明头
  （三端配置位置见 README「应用身份」表，未配置启动即报错）。登录后持有
  服务端签发的 JWT，服务端 `verifyAccessToken` 验签即可——**无共享密钥**。
- biz-server → auth server：用 auth server 的 JWKS 公钥验签，同样无 secret。
- `app_id` 是自报的租户键，不是安全凭据：它决定"数据隔离到哪个桶"，用户数据
  的安全边界在会话 JWT 的归属校验上，不在 app_id 保密上。

真正存在密钥的位置（全部在**服务端 env**，客户端零密钥）：

| 密钥 | env（server） | 何时涉及 |
|---|---|---|
| 对象存储 | `S3_ENDPOINT` / `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY` / `S3_BUCKET` | 头像、闪屏素材等上传（共享 BaaS 已配好） |
| 第三方登录 | `GITHUB_CLIENT_SECRET`、`HUAWEI_OAUTH_CLIENT_SECRET`、Apple/HMS 凭据 | 启用对应社交登录；产品接入自己的开放平台时换成自己的 |
| 推送 / 崩溃分析 | Firebase 服务账号等 | 启用推送 / Crashlytics |

`mobileui` CLI 本身是纯本地模板工具，无网络鉴权、无 secret；仅
`--source github` 拉私有模板仓库时涉及 git 凭据。

## 落地顺序 Checklist

1. `mobileui create` 生成产品仓库（身份、目录、CI 已就位）
2. 服务端为新 app_id 建租户 + 初始化 runtime config（L1）
3. 替换三端设计 token 中的品牌色（L2）
4. 替换图标 / 启动屏资产与应用显示名（L3）
5. 同步三端离线兜底配置（见 L1 末尾）
6. 按「验收清单」逐项检查，`mobileui doctor` 查身份残留

---

## L1 服务端运营层（runtime config）

每个 app × environment 有一份 runtime config 文档，存于服务端 `runtime_configs`
表（`app_id` + `environment` 唯一）。schema 见
`server/src/server/schemas.ts` 的 `runtimeConfigSchema`。

品牌相关字段：

```ts
brand: {
  appName: string,      // 应用内显示名（首页欢迎语、闪屏标题，≤40 字符）
  tagline: string,      // 标语（≤100 字符）
  primaryColor: string, // #RRGGBB，客户端品牌点缀色
},
splash: {               // 品牌闪屏活动；null = 不展示闪屏，直接进首页
  id, title,            // 标题（≤80）
  description,          // 描述（≤200）
  badge,                // 角标文案（≤30）
  actionLabel,          // 底部按钮文案（≤30）
  imageUrl, videoUrl,   // 全屏素材（图或视频二选一）
  linkUrl,              // 按钮跳转链接
  skippable,            // 是否显示跳过按钮
  durationSeconds,      // 1–30 秒
} | null,
```

修改方式（二选一）：

- **运营控制台**：登录 server 控制台 → Config 页（`server/src/app/(console)/config`），
  可视化编辑并按版本发布。
- **直接写库**：更新 `runtime_configs` 的 `document` 并递增 `version`
  （客户端按 version 判断刷新）。

客户端消费路径：`GET /api/v1/bootstrap` → `config.brand` / `config.splash`。
三端闪屏页（`react-native/src/screens/LaunchScreens.tsx`、
`flutter/lib/screens/launch_screens.dart`、`arkts/.../pages/LaunchPages.ets`）
只负责渲染这份配置——**改闪屏内容不碰任何客户端代码**。

### 离线兜底配置必须同步

客户端拿不到服务端配置时（首启离线、bootstrap 失败）会退回内置默认值。
改了 L1 之后，务必同步 RN 的兜底文件，否则离线用户看到旧品牌：

- `react-native/src/config/embeddedConfig.ts` — 含 `brand` + `splash` 默认值
- Flutter / ArkTS 无独立兜底文件：首次冷启动必须在线拉取，之后使用最近一次
  成功缓存的配置（`localStore` / repository 缓存）

### 法务文档（隐私政策 / 用户协议 / 订阅说明）

法务文档同样是 runtime config 的一部分（`legal` 数组），随 bootstrap 下发，
改内容**不需要客户端发版**。

存储与公开访问：

- Schema：`server/src/server/schemas.ts` 的 `legal` 数组，每篇文档含
  `type`（privacy / terms / subscription…）、`locale`、`revision`（版本号）、
  `title`、`content`（纯文本）、`requiresReconsent`。
- 默认模板：`server/src/domain/legal-documents.ts`（"终北统一认证"版本）。
  新 app 未配置时回退到它——**落地必须整体替换为新主体**，不能带着模板
  主体名上架。
- 公开 URL（**上架审核填这个**）：
  `https://<server域名>/legal/privacy?app=<appId>&locale=zh-CN`
  （`server/src/app/legal/[type]/page.tsx`，无鉴权、读 production 配置；
  同理 `/legal/terms`、`/legal/subscription`）。

客户端消费方式（三端不同构，注意）：

| 平台 | 应用内展示 | 落地注意 |
|---|---|---|
| RN | `src/screens/LegalScreens.tsx` 读**内置副本** `src/legal/legalDocuments.ts`（结构化 sections，与服务端纯文本 content 不同构） | 改服务端后必须**手工同步这份副本**，否则应用内显示旧条款 |
| Flutter | `lib/screens/legal_screen.dart` 直接渲染 `config.legal` | 纯服务端驱动 |
| ArkTS | `pages/SettingsLegalPages.ets` 渲染 `store.config.legal` | 纯服务端驱动 |

consent 版本联动（审计要求）：

- 注册时客户端把 terms 的 `revision` 作为 `consentVersion` 上报（RN 见
  `AuthScreens.tsx` 的 `termsRevision`），服务端写入 `users.consent_version`
  并记录 `consented_at`。
- 因此**每次修改条款内容必须递增 `revision`**——它回答"用户同意的是哪一版"。
  重大变更标 `requiresReconsent: true`。

落地必改清单：

- [ ] 服务提供方主体名称（清除模板里的"苏州终北科技有限公司 / 终北统一认证"字样）
- [ ] 每篇的生效日期与 `revision`
- [ ] 数据处理描述与产品实际能力对齐（头像存储、推送、匿名分析、客服截图…）
- [ ] 三端内置副本同步（RN 两处：`legalDocuments.ts` + `embeddedConfig.ts.legal`）
- [ ] 公开 URL 公网可访问；中国大陆上架另需 ICP 备案与首启隐私合规
- [ ] App Store「App 隐私」问卷与实际采集项一致

---

## L2 客户端设计 token 层（换肤）

三端 token 结构一致（浅色 / 深色两套 + spacing/radii），品牌主色默认
`#A84444`，逐端替换：

| 平台 | Token 文件 | 说明 |
|---|---|---|
| React Native | `src/theme/tokens.ts` | `colors`（浅色）/ `darkColors`（深色覆盖项，未覆盖项继承浅色）/ `radii` / `spacing` / `membershipAccents` |
| Flutter | `lib/theme/app_tokens.dart` | `AppColors` / `AppDarkColors` / `AppSpacing` / `AppRadii`；`app_theme.dart` 组装为 MaterialApp 主题 |
| ArkTS | `entry/src/main/resources/base/element/color.json`（浅色）<br>`entry/src/main/resources/dark/element/color.json`（深色） | `AppTokens.ets` 只是 `$r('app.color.*')` 资源引用，**色值在资源 JSON 里**，深浅色由资源目录机制自动切换 |

换肤要点：

- **最小换肤**只动 `brand` / `brandPressed`(RN) / `brandSoft` 三个语义色；
  其余中性色（背景 / 表面 / 文字 / 边框）通常可保留。
- 深色模式不是简单反色：深色下 `brandSoft`、`error` 等都需要单独的低刺激
  变体（参考 ArkTS：浅色 `#A84444` → 深色 `#C25C5C`）。
- 会员档位色 `membershipBronze/Silver/Gold`（RN）与服务端 tiers 的展示相关，
  换品牌视觉时一并检查。
- 文案（含多语言）不属于 token，走 i18n，见
  [`docs/I18N_GUIDE.md`](I18N_GUIDE.md)。
- 对比度需满足无障碍要求（正文 ≥4.5:1，描边/大字 ≥3:1）。

### 品牌色 #A84444 的全部硬编码位置

换主色时，除 token 文件外，以下原生位置也要同步（详表见 L3）：

- RN：`app.json` → `expo.android.adaptiveIcon.backgroundColor`
- Flutter：`android/.../res/values/colors.xml` 的 `launcher_background`、
  `res/drawable/launch_logo.xml` 的 `fillColor`
- ArkTS：`start_window_icon.svg` 的 `fill`、`color.json` 的 `brand`（深色目录另有一份）

---

## L3 原生资产层（图标 / 启动屏 / 显示名）

### 图标源头与分发

品牌图标**单一源头是 1024×1024 PNG**，当前三端的 `app-icon.png`
字节级一致（手工同步的）。换图标时按此清单分发：

| 目标 | 路径 |
|---|---|
| RN 源 | `react-native/assets/app-icon.png`（+ 闪屏 logo `assets/splash-icon.png`） |
| Flutter Android | `flutter/android/.../res/mipmap-*/ic_launcher.png`（各密度） |
| Flutter iOS | `flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/`（完整尺寸集） |
| ArkTS | `arkts/AppScope/resources/base/media/app_icon.png`（+ entry 模块同名文件） |

### React Native（Expo prebuild 流）

RN 的 `ios/`、`android/` 目录是 **expo prebuild 生成物（gitignore）**，
不要手改原生文件，一律改 `app.json` 后重新生成：

| 项 | 位置（`react-native/app.json`） |
|---|---|
| 应用名 / slug / scheme | `expo.name` / `expo.slug` / `expo.scheme` |
| Bundle ID / 包名 | `expo.ios.bundleIdentifier` / `expo.android.package`（CLI 已替换） |
| 桌面图标 | `expo.icon` → `./assets/app-icon.png` |
| 原生启动屏 | `expo.plugins → expo-splash-screen`：`backgroundColor`（当前 `#FFFFFF`）+ `image`（`./assets/splash-icon.png`，`imageWidth 88`） |
| Android 自适应图标背景 | `expo.android.adaptiveIcon.backgroundColor`（当前 `#A84444`） |

改完执行 `npx expo prebuild --clean`（或直接 `npm run ios` / `npm run android`
触发重建）。注意：应用内还有一个 JS 层品牌闪屏（见 L1），原生启动屏只是
首帧前的 logo——两层都在，缺一不可。

### Flutter（原生工程入库，直接改）

| 项 | 文件 | 当前值 |
|---|---|---|
| Android 应用名 | `android/app/src/main/AndroidManifest.xml` `android:label` | `mobileui_flutter` |
| Android 启动屏背景 | `res/drawable/launch_background.xml`（+ `drawable-v21/` 变体） | 白底 + 居中 logo |
| 启动屏 logo | `res/drawable/launch_logo.xml`（vector，`fillColor` 品牌色） | 红盾图标 |
| 启动主题（深色） | `res/values-night/styles.xml` | 同 drawable，深色 parent |
| 自适应图标背景色 | `res/values/colors.xml` `launcher_background` | `#A84444` |
| 自适应图标前景 | `res/drawable/ic_launcher_foreground.xml`（vector） | 白色盾形 |
| iOS 显示名 | `ios/Runner/Info.plist` `CFBundleDisplayName` | `Mobileui Flutter` |
| iOS 启动屏 | `ios/Runner/Base.lproj/LaunchScreen.storyboard`（白底、居中 88×88）+ `Assets.xcassets/LaunchImage.imageset/` 三张 PNG | — |
| iOS 图标 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | 完整尺寸集 |

可选：引入 `flutter_launcher_icons` 包，用单一 1024 源图自动生成 Android +
iOS 全套图标，替代手工替换各密度 PNG。

### ArkTS / HarmonyOS

| 项 | 文件 | 当前值 |
|---|---|---|
| 应用名（AppScope 级） | `arkts/AppScope/app.json5` → `$string:app_name`<br>`AppScope/resources/base/element/string.json`<br>`AppScope/resources/en_US/element/string.json` | `MobileStarter`（**base 与 en_US 两份都要改**） |
| Ability 名（entry 级） | `entry/src/main/module.json5` → `label`，解析到 `entry/src/main/resources/base/element/string.json` | `MobileStarter` |
| 桌面图标 | `AppScope/resources/base/media/app_icon.png`（+ entry 模块同名文件） | 品牌图标 |
| 启动窗口图标 | `module.json5` → `startWindowIcon` → `entry/.../base/media/start_window_icon.svg`（vector `fill` 为品牌色） | 红盾 SVG |
| 启动窗口背景 | `module.json5` → `startWindowBackground` → `base/element/color.json` + `dark/element/color.json` 的 `start_window_background` | 浅色 `#F6F7F9` / 深色 `#0F1115` |

HarmonyOS 的启动窗口完全由 `module.json5` 的 `startWindow*` 声明，
`EntryAbility.ets` 无运行时 splash 代码，不需要改代码。

---

## 容易踩的坑

1. **RN 手改原生目录**：`ios/`、`android/` 会被下次 prebuild 覆盖，品牌改动
   只认 `app.json` + assets。当前磁盘上的生成物已过期（如 `iconBackground`
   资源缺失），重新 prebuild 即可对齐。
2. **ArkTS 字符串两份**：`AppScope` 与 `entry` 各有 `string.json`，且各有
   `base` / `en_US` 两个 locale——改一处漏三处是常态。
3. **深色模式漏改**：ArkTS 的 `dark/element/color.json`、RN 的 `darkColors`、
   Flutter 的 `AppDarkColors` 各有一套深色覆盖，启动窗口背景同样分深浅两份。
4. **离线兜底旧品牌**：服务端改了 `brand`/`splash` 但 RN 的
   `embeddedConfig.ts` 没同步，离线/首启失败用户会看到旧品牌。
5. **域名关联**：`app.json` 的 `associatedDomains`（applinks）与 Android
   `intentFilters` 指向 `auth.zhongbei.tech`；自建 BaaS 域名时两处 +
   服务端都要换，属于身份层，先跑 CLI 再核对本项。
6. **两层闪屏**：原生启动屏（L3，静态 logo）与品牌闪屏（L1，服务端活动配置）
   是两个东西；只改其一会出现"开屏新 logo、进 App 旧活动"的割裂。
7. **RN 法务双源**：应用内"协议与政策"页读内置副本，注册 consent 读服务端
   `config.legal` 的 revision——只改服务端会出现"应用内旧条款、注册记录新
   版本号"的错位。
8. **权限用途描述**：RN 的 `app.json` 未显式配置 iOS `infoPlist` 权限描述，
   上架前核对 prebuild 产物（相册 `NSPhotoLibraryUsageDescription` 等）；
   ArkTS 当前仅声明 `ohos.permission.INTERNET`（相册走系统 Picker 无需权限）。

---

## 附录：可配置内容总表

| 要改什么 | 层 | 怎么改 | 要发版？ |
|---|---|---|---|
| 应用显示名（桌面/设置） | CLI+L3 | CLI create 替换；事后手工改 `string.json`、`Info.plist`、`app.json` | 是 |
| 包名 / Bundle ID / scheme | CLI | create 时 `--organization` + `--app-id`（无 rename 命令） | 是 |
| 深链关联域名 | 手工 | `app.json` associatedDomains + intentFilters + 服务端校验文件 | 是 |
| 桌面图标 | L3 | 替换图片资产（L3 分发表） | 是 |
| 原生启动屏 | L3 | RN: app.json+prebuild；Flutter: drawable/storyboard；ArkTS: startWindow* | 是 |
| 主题色 / 深色模式 / 圆角 | L2 | 三端 token 文件 | 是 |
| 多语言文案 | L2 | 各端 i18n 资源（见 I18N_GUIDE） | 是 |
| 应用名/标语/主色（应用内） | L1 | 控制台/DB：runtime config `brand` | 否 |
| 品牌闪屏活动 | L1 | runtime config `splash`（null 即关闭闪屏） | 否 |
| 隐私政策/用户协议/订阅说明 | L1 | runtime config `legal`（bump revision）+ RN 内置副本同步 | 否 |
| 会员档位 / 价格 / 权益 | L1 | runtime config `tiers` / `plans` | 否 |
| 功能开关（会员/优惠券/邀请/统计） | L1 | runtime config `features` | 否 |
| 客服分类 / 队列 / 市场 | L1 | runtime config `support` | 否 |
| 遥测 / 分析 / 崩溃开关 | L1 | runtime config `telemetry` | 否 |
| 离线兜底品牌与条款 | L1' | RN `embeddedConfig.ts` + `legalDocuments.ts` 手工同步 | 是 |
| 权限用途描述（审核） | L3 | iOS Info.plist / Android manifest / ArkTS requestPermissions | 是 |
| 社交登录 / 推送 / S3 密钥 | 服务端 | server env（客户端永远零密钥） | 部署 |

---

## 验收清单

- [ ] 三端冷启动：原生启动屏 logo / 背景色为新品牌，无旧素材残留
- [ ] 三端深色模式：主题色、启动窗口背景均正确（逐端切换系统深色验证）
- [ ] 桌面图标、应用显示名（桌面 / 设置 / 任务切换器）为新品牌
- [ ] 在线 bootstrap：闪屏活动、首页欢迎语 `appName`、主色点缀来自新配置
- [ ] 断网冷启动（含首次安装）：兜底品牌内容与线上一致
- [ ] 会员页三档配色与新视觉协调
- [ ] `mobileui doctor` 无身份残留告警
- [ ] 多语言抽查（zh-CN / en-US）无旧文案（见 I18N_GUIDE）
- [ ] 法务三件套：应用内展示新主体条款，公开 `/legal/*` URL 可访问且无模板主体残留
- [ ] 注册成功后 `users.consent_version` 等于新 terms 的 revision
- [ ] 应用内与公开页的条款版本号一致（RN 双源已同步）
