# Firebase Analytics 与 Crashlytics 接入

Firebase 是按 App、平台和租户配置的可选辅助 sink。自有遥测后端始终保存规范事件，
Firebase 故障不会影响登录、支付、配置加载或页面交互。

## 运行模式

- `disabled`：不初始化 Firebase。
- `client_direct`：移动端 SDK 直接发送 Analytics/Crashlytics；自有事件同时批量发送到后端。
- `server_forwarded`：客户端只发自有后端，服务端后续通过 Measurement Protocol 转发。

同一 App 只能选择一种 Firebase Analytics 路径，禁止 direct 与 forwarded 同时启用。
Crashlytics 只支持客户端 SDK，不经普通 Analytics 事件转发。

## React Native / Expo

已安装：

```text
@react-native-firebase/app
@react-native-firebase/analytics
@react-native-firebase/crashlytics
expo-dev-client
```

每个派生 App 提供自己的：

```text
react-native/google-services.json
react-native/GoogleService-Info.plist
```

配置文件到位后生成 Expo development build 或正式原生包。React Native Firebase 依赖
原生代码，不能在 Expo Go 中验证。远程配置只有在本地文件存在且用户分析许可允许时才把
`firebaseMode` 设为 `client_direct`。

## Flutter

依赖已加入 `pubspec.yaml`。每个派生 App 在自己的 Firebase 项目执行：

```text
flutterfire configure
```

该命令生成平台配置和 `firebase_options.dart`。模板默认不等待 Firebase 初始化；缺少配置时
自动退化到自有遥测。接入生成文件后，可在初始化适配器中传入
`DefaultFirebaseOptions.currentPlatform`。

## 密钥和发布

- Firebase 客户端配置按 App、bundle/application ID 和环境隔离。
- Service Account 私钥、Measurement Protocol API secret 永远只放服务端密钥管理系统。
- 模板仓库不提交任何真实生产配置。
- 发布前分别用 Analytics DebugView 与 Crashlytics 测试崩溃确认每个平台接收成功。
- 用户关闭分析许可时停止 Product Event；必要的安全审计与最小崩溃诊断按隐私政策单独处理。
