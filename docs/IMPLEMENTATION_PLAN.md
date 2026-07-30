# MobileUI 全功能落地与最终审核计划

版本：1.0  
状态：实施基线  
覆盖范围：Next.js 控制面、React Native、Flutter、ArkTS

## 1. 最终目标

MobileUI 不是静态页面模板，而是一套可派生不同 App 的运行时产品底座：

- 三端共享同一份业务契约、路由语义、状态机和远端配置。
- 账号、会员、订单、通知、Splash、设置均由真实数据驱动。
- 派生产品可以只更换品牌包、功能开关和服务端配置，不修改核心流程。
- 所有可见按钮必须有明确行为、等待状态、成功结果和失败恢复。
- 所有成功结果必须经过服务端确认并可在重启 App 后恢复。

## 2. 硬性完成门禁

以下任意一项不满足，版本不得进入最终审核：

1. 页面存在无行为按钮、假成功 Toast、硬编码会员价格或占位数据。
2. 服务端不可启动、数据库不可迁移、种子数据不可重复执行。
3. React Native、Flutter、ArkTS 使用不同含义的字段、路由或状态。
4. 改头像、改用户名、改密码、退出、删号等关键流程没有持久化。
5. Splash、会员层级、方案或功能开关修改后必须重新发布客户端。
6. 支付回调不能防重复，或重复回调会重复发放权益。
7. 账号删除后旧会话仍可访问受保护接口。
8. 通知仅有 UI，没有站内消息数据、已读状态和设备注册。
9. 使用 Emoji、Unicode 符号或图标字体代替 SVG 图标。
10. 缺少加载、空、错误、离线、未授权和重试状态。

## 3. 总体架构

```text
Flutter ──────────┐
React Native ─────┼── REST/JSON v1 ── Next.js Control Plane ── PostgreSQL
ArkTS ────────────┘                         │
                                           ├── Local/S3 Object Storage
                                           ├── Apple/Google Purchase Adapters
                                           ├── WeChat Pay/Alipay Adapters
                                           └── FCM/APNs/HMS Push Adapters
```

Next.js 负责业务编排、配置、权限、订单和通知记录。支付渠道负责真实扣款，
FCM/APNs/HMS 负责系统级推送送达；服务端不伪装成支付渠道或系统推送通道。

## 4. 阶段与详细任务

### P0 — 契约、规则与验收基础

- [ ] `server/AGENTS.md`：服务端分层、文件长度、事务、日志和安全规则。
- [ ] OpenAPI 3.1：所有请求、响应、错误码、分页和幂等头。
- [ ] JSON Schema：远端配置、会员等级、方案、权益和 Splash。
- [ ] 统一错误模型：`code / messageKey / fieldErrors / traceId / retryable`。
- [ ] 统一异步状态：`idle/loading/success/empty/error/offline/unauthorized`。
- [ ] 统一 API 客户端生成策略和契约兼容策略。
- [ ] 测试账号、测试设备、测试订单和审核数据集。

验收证据：

- OpenAPI lint 通过。
- 三端契约模型编译通过。
- 非法配置会被服务端拒绝并返回精确字段错误。
- 契约快照及兼容性测试报告。

### P1 — Next.js 本地控制面

- [ ] Tenant → App → Environment → Platform 四级隔离。
- [ ] 每个 App 独立账号空间；可选共享 IdentityPool。
- [ ] Next.js App Router 与 `/api/v1` Route Handlers。
- [ ] PostgreSQL Docker Compose、本地环境样例和一键启动脚本。
- [ ] 数据库迁移、回滚说明、幂等种子脚本。
- [ ] 健康检查：进程、数据库、存储和配置版本。
- [ ] 结构化日志、`traceId`、敏感字段脱敏。
- [ ] 管理页面：App、环境、配置草稿、发布版本和回滚。
- [ ] 本地文件存储适配器；生产环境预留 S3 兼容适配器。

验收证据：

- 全新机器按 README 可启动。
- 重复执行迁移和种子不会制造重复数据。
- `/health/live` 与 `/health/ready` 能区分存活和可服务状态。
- 配置发布和回滚均留审计记录。

### P2 — 认证与会话

- [ ] 邮箱注册：格式、强度、重复账号、协议确认。
- [ ] 邮箱登录：密码错误、账号锁定、速率限制。
- [ ] 邮箱验证：发送、重发冷却、过期、已使用。
- [ ] 找回密码：申请、验证码/令牌、设置新密码、成功页。
- [ ] 密码安全存储与参数升级策略。
- [ ] Access/refresh 会话、轮换、撤销和过期。
- [ ] 当前设备退出与全部设备退出。
- [ ] 第三方登录适配接口；未配置渠道不显示入口。
- [ ] 未授权路由守卫和登录后原路返回。

验收证据：

- 注册后数据库存在账号，密码不可逆。
- 改密后旧 refresh token 全部失效。
- 退出后受保护接口返回统一 `unauthorized`。
- 重发、暴力尝试和令牌复用均有自动测试。

### P3 — 用户资料与账号安全

- [ ] 查看资料：头像、用户名、邮箱、会员、创建时间。
- [ ] 修改用户名：长度、字符、敏感词、唯一性策略可配置。
- [ ] 修改头像：相册/相机权限、裁剪、压缩、上传、失败重试。
- [ ] 删除/恢复默认头像。
- [ ] 修改密码：验证当前密码、新密码策略、会话处置。
- [ ] 登录设备列表：平台、型号、最近活动、当前设备标记。
- [ ] 撤销单台设备会话。
- [ ] 删除账户：风险说明、重新认证、冷静期配置、最终删除。
- [ ] 数据导出请求与处理状态。
- [ ] 审计事件：登录、改密、设备撤销、删号申请。

验收证据：

- 修改资料后杀掉并重开 App，数据仍保持。
- 头像 CDN/本地存储 URL 可用，旧头像按策略回收。
- 撤销设备后目标设备下次请求立即退出。
- 删除账号后用户、会话和个人数据按策略删除或匿名化。

### P4 — 动态品牌、启动与功能配置

- [ ] App 维度：`appId / environment / platform / locale / version`。
- [ ] 内置默认、Last Known Good、远端发布三层配置。
- [ ] ETag、TTL、前台恢复刷新和新资源预下载/原子切换。
- [ ] 品牌：名称、Logo、配色、字体、协议和客服入口。
- [ ] Logo 页：最低展示时间、初始化状态和失败恢复。
- [ ] Splash：素材、明暗资源、标题、正文、CTA、跳转、倒计时。
- [ ] Splash 策略：时间窗、人群、版本、平台、频控和优先级。
- [ ] 本地最后成功配置缓存、ETag/版本号和离线降级。
- [ ] 最低版本、推荐更新、维护模式和公告。
- [ ] 功能开关：显示、可用、灰度比例和依赖条件。
- [ ] 登录 provider 和设置项的可见性、可修改性及平台能力策略。
- [ ] 多 App、多语言、版本化法律文本和重新同意守卫。
- [ ] 配置草稿、预览、发布、回滚和审计。

验收证据：

- 服务端换 Splash 后三端下次启动展示新内容，无需发版。
- 无网时使用最后成功配置；首次启动无网使用内置安全默认值。
- 过期活动不会展示，CTA 只跳转白名单路由/域名。
- 两个配置版本可一键切换并恢复。

### P5 — 动态会员、权益和订阅方案

- [ ] 会员等级为任意有序数组，不写死 Free/Pro。
- [ ] 支持 1、2、3 及更多等级；支持隐藏和下线。
- [ ] 权益使用稳定 `entitlementKey`，不依赖等级名称。
- [ ] 等级映射权益及额度：布尔、次数、容量、并发数。
- [ ] 方案支持月、季、年、终身、一次性包和自定义周期。
- [ ] 支持免费试用、首购价、原价、促销时间窗和地区币种。
- [ ] 方案按平台映射 Apple/Google/微信/支付宝商品 ID。
- [ ] 当前权益、额度消耗、续费日、宽限期和过期状态。
- [ ] 升级、降级、取消续费、恢复购买和订单历史。
- [ ] 会员页完全由等级和方案数组渲染。
- [ ] 无可售方案、仅单等级、三级比较和超长权益列表状态。

验收证据：

- 配置从二级切到三级，三端布局自动变化且不改客户端代码。
- 新增月付/年付后自动出现，价格来自服务端/商店校验结果。
- 隐藏等级后已有用户权益不丢失，新用户不可购买。
- 权益检查在服务端执行，客户端隐藏按钮不能绕过权限。

### P6 — 订单与支付适配

- [ ] 订单状态机：创建、待支付、处理中、成功、失败、关闭、退款。
- [ ] 客户端生成幂等键，服务端防重复下单。
- [ ] 支付适配接口：创建、查询、验证、退款、Webhook。
- [ ] Apple：客户端 StoreKit，服务端交易校验与通知。
- [ ] Google：客户端 Play Billing，服务端购买校验与通知。
- [ ] 微信支付和支付宝：按产品渠道策略启用适配器。
- [ ] Webhook 验签、时钟偏差、重放保护、去重和失败重试。
- [ ] 权益发放与订单确认在同一事务/可靠事件流程中。
- [ ] 对账任务和异常订单人工处理入口。
- [ ] Mock 支付适配器用于本地完整测试，不伪装生产付款。

验收证据：

- 同一回调发送十次只发放一次权益。
- 客户端中途关闭后可通过订单查询恢复最终状态。
- 退款/撤销后权益按产品规则更新。
- 未配置支付渠道时不展示该按钮，也不能调用其接口。

### P7 — 通知中心与系统推送

- [ ] 站内通知：系统、交易、会员、运营和安全类型。
- [ ] 列表分页、未读数、单条已读、全部已读、删除。
- [ ] 通知深链使用白名单 typed route 和受控参数。
- [ ] 通知偏好：渠道、类型、免打扰时段和营销许可。
- [ ] 设备注册：平台、push token、语言、时区、App 版本。
- [ ] token 刷新、失效清理、退出解绑和多设备。
- [ ] Provider 接口：本地日志、FCM、APNs、HMS。
- [ ] Next.js 负责目标筛选、模板渲染、任务和发送记录。
- [ ] 推送失败重试、永久失败识别和送达状态。
- [ ] 前台、后台、冷启动点击三种路由行为。

验收证据：

- 创建通知后站内中心立即可见并正确计算未读数。
- 本地 provider 可验证完整发送链路。
- 配置 FCM 后由 Next.js 可信服务端发给 FCM，再由平台送达。
- 关闭营销通知后营销任务不会选择该设备。

### P8 — 设置中心逐项落地

每个设置项必须标注数据来源、保存位置和生效时机：

- [ ] 账号资料：头像、用户名、邮箱和会员入口。
- [ ] 账号安全：改密、邮箱验证、第三方账号绑定。
- [ ] 登录设备：列表、当前设备、撤销和全部退出。
- [ ] 通知：总开关、分类、系统权限状态、免打扰。
- [ ] 隐私：个性化、分析、崩溃报告和数据导出。
- [ ] 通用：自动播放、网络偏好、默认行为。
- [ ] 外观：系统/浅色/深色、对比度、动态效果。
- [ ] 语言：跟随系统和服务端支持语言列表。
- [ ] 字号：预览、系统缩放和重启保持。
- [ ] 存储：缓存统计、分类清理、清理确认和结果。
- [ ] 权限：相机、相册、通知等真实系统状态与跳转设置。
- [ ] 帮助反馈：分类、内容、附件、提交记录。
- [ ] 法律：协议版本、更新时间、同意记录。
- [ ] 关于：版本、构建号、渠道、更新检查、开源许可。
- [ ] 退出登录：确认、服务端撤销、本地敏感数据清理。
- [ ] 删除账户：重新认证、确认短语、冷静期和状态追踪。

验收证据：

- 审核组逐行点击，无占位按钮、无固定假数据。
- 每项在重启后按定义保持或恢复默认。
- 系统权限被拒绝时有解释与“前往设置”，不会无限弹窗。
- 危险操作均有重新认证、确认和可追踪结果。

### P9 — React Native 首端完整接入

- [ ] 按 feature-first 重构现有原型，不在页面直接请求 API。
- [ ] 安全存储会话、API 拦截、refresh 单飞和超时取消。
- [ ] 启动编排：内置配置 → 缓存配置 → 远端配置 → 路由守卫。
- [ ] P2–P8 全功能 UI、表单、状态和反馈。
- [ ] 图片选择/裁剪、通知权限和购买桥接。
- [ ] 网络切换、离线缓存、恢复和错误映射。
- [ ] 深链和通知点击路由。
- [ ] 单元、组件、导航和 E2E 测试。

验收证据：

- 先以 React Native 完成金标准和接口磨合。
- 关键路径录屏、截图、API trace 和测试报告齐全。
- Android/iOS/Web 可支持范围明确；原生能力不以 Web 假通过。

### P10 — Flutter 完整接入

- [ ] 与 RN 使用同一 OpenAPI 和配置 Schema。
- [ ] P2–P8 功能、状态、错误码和路由语义一致。
- [ ] 平台安全存储、图片、通知、购买能力适配。
- [ ] 单元、Widget、导航和集成测试。
- [ ] 与 RN 的视觉和行为差异形成批准记录。

验收证据：

- 使用同一测试数据跑过关键路径。
- 契约测试和视觉基线通过。
- 不存在 Flutter 独有硬编码会员或配置字段。

### P11 — ArkTS 完整接入

- [ ] 与 RN/Flutter 使用同一 OpenAPI 和配置 Schema。
- [ ] P2–P8 功能、状态、错误码和路由语义一致。
- [ ] HarmonyOS 安全存储、图片、通知和支付能力适配。
- [ ] HMS Push 作为可配置 provider，不强耦合会员业务。
- [ ] 单元、UI、导航和集成测试。
- [ ] ArkTSCheck、Hvigor 构建和真机能力验证。

验收证据：

- 使用同一测试数据跑过关键路径。
- HarmonyOS 平台差异有明确产品策略，不以空按钮代替。
- 不存在 ArkTS 独有硬编码等级或方案。

### P12 — 管理后台与运营闭环

- [ ] App/环境切换和角色权限。
- [ ] 品牌、Splash、功能开关、等级、权益和方案编辑。
- [ ] 配置校验、预览、发布、定时生效和回滚。
- [ ] 用户、设备、会员、订单和通知查询。
- [ ] 退款/补发等高风险操作二次确认和审计。
- [ ] 通知模板、目标人群、测试发送和正式发送。
- [ ] 操作日志与配置差异。

验收证据：

- 运营人员不改代码即可完成配置变更。
- 草稿不会影响生产；发布后客户端按缓存策略更新。
- 高风险操作可追溯到操作者、时间、原因和对象。

### P13 — Telemetry、客服与反馈

- [ ] 四类数据分离：产品事件、运行日志、安全审计、崩溃性能。
- [ ] 三端统一事件 Schema、离线队列、批量、退避、采样和删除。
- [ ] 导航停留时长与设计系统语义点击自动采集。
- [ ] 自有采集端为事实来源；Firebase/GA4 为区域化可选 sink。
- [ ] `locale / market / dataRegion / supportQueue` 独立建模。
- [ ] 帮助中心、客服工单、对话、附件、状态和满意度。
- [ ] 产品建议、分类、状态、投票和版本关联。
- [ ] 按 App、区域、语言、问题类型、等级和严重程度分配队列。
- [ ] 用户主动授权后才附带脱敏诊断信息。

验收证据：

- 中国/ArkTS 关闭 Firebase 后事件与客服功能完整可用。
- 海外 App 可切换 `client_direct/server_forwarded/disabled`。
- 页面停留、前后台、idle 和崩溃恢复计算有自动测试。
- 工单和反馈在重启、换设备后仍存在并可继续回复。

## 5. API 最小清单

```text
GET    /api/v1/bootstrap
GET    /api/v1/config

POST   /api/v1/auth/sign-up
POST   /api/v1/auth/sign-in
POST   /api/v1/auth/refresh
POST   /api/v1/auth/sign-out
POST   /api/v1/auth/sign-out-all
POST   /api/v1/auth/verify-email
POST   /api/v1/auth/forgot-password
POST   /api/v1/auth/reset-password

GET    /api/v1/me
PATCH  /api/v1/me/profile
POST   /api/v1/me/avatar
DELETE /api/v1/me/avatar
POST   /api/v1/me/change-password
GET    /api/v1/me/sessions
DELETE /api/v1/me/sessions/:id
POST   /api/v1/me/data-export
POST   /api/v1/me/deletion
DELETE /api/v1/me/deletion

GET    /api/v1/membership/catalog
GET    /api/v1/membership/current
GET    /api/v1/membership/entitlements
POST   /api/v1/orders
GET    /api/v1/orders
GET    /api/v1/orders/:id
POST   /api/v1/purchases/verify
POST   /api/v1/purchases/restore

GET    /api/v1/notifications
GET    /api/v1/notifications/unread-count
PATCH  /api/v1/notifications/:id/read
POST   /api/v1/notifications/read-all
DELETE /api/v1/notifications/:id
GET    /api/v1/notification-preferences
PUT    /api/v1/notification-preferences
POST   /api/v1/devices
DELETE /api/v1/devices/:id

POST   /api/v1/webhooks/apple
POST   /api/v1/webhooks/google
POST   /api/v1/webhooks/wechat
POST   /api/v1/webhooks/alipay
```

## 6. 数据模型最小清单

- `App`、`AppEnvironment`、`ConfigDraft`、`ConfigRelease`
- `User`、`Identity`、`EmailVerification`、`PasswordReset`
- `Session`、`Device`、`AuditEvent`、`DeletionRequest`
- `Asset`、`SplashCampaign`、`FeatureFlag`
- `Tier`、`Entitlement`、`TierEntitlement`
- `Plan`、`PlanPrice`、`StoreProductMapping`
- `Subscription`、`Order`、`PaymentAttempt`、`WebhookEvent`
- `UserEntitlement`、`UsageLedger`
- `Notification`、`NotificationReceipt`、`NotificationPreference`
- `PushToken`、`PushJob`、`PushAttempt`

所有多租户业务表必须包含 `appId`；所有可变配置必须版本化；所有金额使用最小货币
单位和 ISO 货币代码；所有时间由服务端保存 UTC。

## 7. 状态与异常审核矩阵

每个网络功能至少验证：

| 状态 | 审核动作 | 必须结果 |
|---|---|---|
| Loading | 慢网触发 | 禁止重复提交，显示可访问的加载反馈 |
| Success | 正常完成 | 服务端确认、UI 更新、重启可恢复 |
| Empty | 无数据账号 | 有解释和下一步动作 |
| Validation | 输入非法 | 字段级错误，不清空用户输入 |
| Unauthorized | 撤销会话 | 清理敏感状态并进入登录守卫 |
| Offline | 断网操作 | 显示离线，安全操作不假成功 |
| Server error | 注入 5xx | 展示 traceId/重试，不泄露内部异常 |
| Timeout | 丢包/超时 | 可取消或重试，不产生重复订单 |
| Conflict | 多端同时修改 | 明确冲突并刷新最新数据 |

## 8. 最终审核组与职责

最终审核使用五个角色，可由不同成员或同一成员分轮执行：

1. 产品审核：页面地图、文案、业务分支和无占位检查。
2. 设计审核：视觉、暗黑模式、字号、动效、SVG 和组件一致性。
3. 工程审核：分层、复杂度、契约、三端一致性和构建结果。
4. 安全审核：认证、会话、权限、支付、Webhook、隐私和删号。
5. QA 审核：真机关键路径、异常注入、升级、离线和回归。

每个需求编号只能处于以下状态：

```text
NOT_STARTED -> IMPLEMENTED -> SELF_VERIFIED -> REVIEWED -> ACCEPTED
                                      \-> REJECTED -> IMPLEMENTED
```

`ACCEPTED` 必须同时拥有：

- 对应代码位置；
- 自动化测试或明确的人工测试步骤；
- 实际运行证据（截图、录屏、日志或数据库断言）；
- 审核人和日期；
- 已知平台差异及批准原因。

## 9. 最终交付物

- 三端可构建源码和本地 Next.js 服务端源码。
- 数据库迁移、种子、环境样例和一键启动/停止脚本。
- OpenAPI、JSON Schema、错误码、路由和状态机文档。
- 管理后台使用手册、配置发布和回滚手册。
- 支付与推送 provider 接入手册及密钥配置清单。
- 单元、集成、E2E、架构、安全和契约测试报告。
- 三端关键路径截图/录屏和审核矩阵。
- 可复现版本压缩包、校验值和变更记录。

## 10. 推荐执行顺序

1. 先完成 P0–P5 的服务端、Schema 与 Mock provider。
2. 用 React Native 完成 P2–P8 全链路，作为金标准。
3. 完成支付和通知 provider 边界及本地可重复测试。
4. 将同一契约接入 Flutter，再接入 ArkTS。
5. 完成管理后台，执行五角色最终审核。
6. 只有所有 P0 门禁和关键需求均为 `ACCEPTED` 才发布。
