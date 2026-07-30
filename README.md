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
flutter run
```

### ArkTS

使用 DevEco Studio 打开 `arkts/`，完成 Hvigor sync 后运行
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
