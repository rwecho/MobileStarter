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

`Server Image` 工作流会把 Next.js standalone 镜像发布到
`ghcr.io/rwecho/mobilestarter-server`。`server/compose.yml` 提供了带持久化数据卷的
运行示例。

## 工程规则

仓库总规则位于 [`AGENTS.md`](AGENTS.md)，完整中文规范位于
[`docs/CODE_RULES.md`](docs/CODE_RULES.md)。实现进度以
[`docs/ACCEPTANCE_MATRIX.md`](docs/ACCEPTANCE_MATRIX.md) 为准。
