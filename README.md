# MobileStarter

MobileStarter 是一套可继承、可换肤、可替换业务模块的跨端移动应用起步项目，包含：

- `server/` — Next.js App Router 后端与运营控制台
- `flutter/` — Flutter / Dart 客户端
- `react-native/` — React Native（Expo）/ TypeScript 客户端
- `arkts/` — HarmonyOS ArkTS / ArkUI 客户端
- `assets/` — 三端共享 SVG 图标与插图的唯一源目录
- `docs/` — 产品规范、架构、路由与验收资料

## 能力概览

- 三端共享设计令牌、类型化路由和一致的异步状态语义
- Logo、启动页、认证、首页、会员、个人中心、设置和客户支持流程
- `idle / loading / success / empty / error / offline / unauthorized` 状态模型
- Next.js `/api/v1` 后端、SQLite 本地开发数据层和配置控制台
- Toast、确认弹窗、危险操作、离线与错误恢复体验
- SVG 图标体系，无 Emoji 或图标字体回退

## 应用身份：app_id 与 environment（必填，无默认值）

每个客户端 App 必须显式声明自己的 **`app_id`（租户）** 与 **`environment`
（development / staging / production）**。**两者都没有默认值，未配置则启动即报错退出**，
避免不可预测的 app_id 混入。服务端按这两个值隔离数据：注册、遥测、配置、消息等都绑定到
客户端声明的 `app_id`；`environment` 主要决定运行时配置发布的目标链路（dev/staging/prod）。

| 平台 | app_id | environment |
| --- | --- | --- |
| React Native | `EXPO_PUBLIC_APP_ID`（`react-native/.env`） | `EXPO_PUBLIC_APP_ENVIRONMENT` |
| Flutter | `--dart-define=MOBILEUI_APP_ID=...` | `--dart-define=MOBILEUI_APP_ENVIRONMENT=...` |
| ArkTS | `arkts/.../data/ApiClient.ets` 的 `APP_ID` 常量 | 同文件 `APP_ENVIRONMENT` 常量 |

```bash
# React Native：react-native/.env
EXPO_PUBLIC_APP_ID=mobileui
EXPO_PUBLIC_APP_ENVIRONMENT=development

# Flutter
flutter run --dart-define=MOBILEUI_APP_ID=mobileui --dart-define=MOBILEUI_APP_ENVIRONMENT=development
```

服务端是**多租户**的：`app_id` 来自每个请求的 `x-app-id` 头（由客户端声明），不是服务端启动
配置。请求缺 `x-app-id` / `x-app-environment` 会被拒绝（`400 APP_ID_REQUIRED` /
`ENVIRONMENT_REQUIRED`）。运营控制台登录时也需选择一个 `app_id`，登录后会话即绑定到该 app，
只能查看这一个 app 的数据。

## 本地运行

### Next.js 后端

```bash
cd server
cp .env.example .env.local
npm ci
npm run dev
```

服务默认运行在 `http://localhost:3210`。生产环境必须设置独立密钥和持久化数据库路径，
详见 [`server/README.md`](server/README.md)。

### React Native

先在 `react-native/.env` 配置 `EXPO_PUBLIC_APP_ID` 与 `EXPO_PUBLIC_APP_ENVIRONMENT`（必填）：

```bash
cd react-native
npm ci
npm run typecheck
npm run web
```

### Flutter

```bash
cd flutter
flutter pub get
flutter analyze
flutter run --dart-define=MOBILEUI_APP_ID=mobileui --dart-define=MOBILEUI_APP_ENVIRONMENT=development
```

### ArkTS

先在 `arkts/entry/src/main/ets/data/ApiClient.ets` 顶部填写 `APP_ID` 与 `APP_ENVIRONMENT`
常量（必填），再用 DevEco Studio 打开 `arkts/`，完成 Hvigor sync 后运行
`entry/src/main/ets/pages/Index.ets`。

## 验证

```powershell
.\scripts\check-architecture.ps1
```

GitHub Actions 为 Next.js、React Native、Flutter 和 ArkTS 提供相互独立的 CI。
HarmonyOS 完整构建仍需在安装了 DevEco Studio 和 HarmonyOS SDK 的环境中执行。

## 发布说明

仓库提供一组相互独立的 `*-publish` 工作流，在推送 `v*` 标签或手动触发
（Actions → Run workflow）时产出可下载的构建产物（Actions artifacts）。

| 工作流 | 产物 | 说明 |
| --- | --- | --- |
| `server-publish.yml` | Docker 镜像 | Next.js standalone 镜像，发布到 `ghcr.io/<owner>/mobilestarter-server`；`server/compose.yml` 提供带持久化数据卷的运行示例 |
| `flutter-publish.yml` | Flutter release APK | 默认用 debug 签名；配置密钥后用正式 keystore 签名 |
| `react-native-publish.yml` | React Native release APK | 本地 `expo prebuild` + Gradle 构建；默认 debug 签名 |
| `arkts-publish.yml` | HarmonyOS `.hap` | 需自建带 DevEco Studio 的 self-hosted runner（标签 `harmonyos`），产出未签名 hap |

### 应用身份（发布必填）

三端 publish 工作流会注入 `app_id` / `environment`，否则构建出的 App 启动即崩。在仓库
Settings → Secrets and variables → Actions 中添加：

- `APP_ID`（**必填**）= 该 App 的租户 id，如 `mobileui`。优先取 GitHub Variables，其次 Secrets。
- `APP_ENVIRONMENT`（可选）= 发布环境，未设置时默认 `production`。

React Native 经 `EXPO_PUBLIC_*` 注入，Flutter 经 `--dart-define` 注入，ArkTS 在构建前写入
`ApiClient.ets` 的常量。`APP_ID` 缺失时三个 publish 工作流都会 `::error::` 中断。
`server-publish` 无需配置（服务端多租户，身份由客户端按请求声明）。

### 签名密钥（可选）

未配置时移动端产物使用 debug 签名（仍可安装测试）。如需正式签名，在仓库 Settings →
Secrets 中添加：

- Flutter：`FLUTTER_KEYSTORE`（keystore 的 base64）、`FLUTTER_STORE_PASSWORD`、
  `FLUTTER_KEY_ALIAS`、`FLUTTER_KEY_PASSWORD`
- React Native：`RN_KEYSTORE`（base64）、`RN_STORE_PASSWORD`、`RN_KEY_ALIAS`、
  `RN_KEY_PASSWORD`；以及可选的 `RN_GOOGLE_SERVICES_JSON`（未提供时 CI 会生成占位文件
  以保证 Firebase Gradle 插件可构建，运行时 Firebase 不生效）
- ArkTS：上传未签名 `.hap`；如需可安装的正式包，在 `build-profile.json5` 配置华为 AGC
  签名材料

## 工程规则

仓库总规则位于 [`AGENTS.md`](AGENTS.md)，完整中文规范位于
[`docs/CODE_RULES.md`](docs/CODE_RULES.md)。实现进度以
[`docs/ACCEPTANCE_MATRIX.md`](docs/ACCEPTANCE_MATRIX.md) 为准。
