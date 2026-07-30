# Telemetry、客服与反馈架构

## 1. 数据类型必须分离

| 类型 | 用途 | 是否受分析许可控制 | 默认存储 |
|---|---|---|---|
| Product Event | 页面、点击、漏斗、功能使用 | 是 | 自有事件库 |
| Operational Log | API、任务、依赖故障 | 否，最小必要 | 自有日志平台 |
| Security Audit | 登录、改密、删号、支付 | 否，最小必要 | 不可变审计库 |
| Crash/Performance | 崩溃、卡顿、启动和网络 | 按政策 | 自有平台 + 可选 Firebase |

Firebase/GA4 是按 App、平台和地区启用的 sink，自有服务端是事件事实来源。

## 2. 统一事件模型

```text
eventId
tenantId / appId / environmentId
anonymousId / userId
sessionId
name / schemaVersion
screenId / previousScreenId
occurredAt / durationMs
platform / appVersion / configVersion
locale / market / dataRegion
properties
consentRevision
```

导航器自动产生 `screen_view/screen_leave`；设计系统按钮使用稳定
`analyticsId` 产生 `ui_action`。禁止采集密码、Token、验证码、输入正文和原始触摸坐标。

## 3. 发送链路

```text
Client encrypted queue
  → POST /api/v1/telemetry/events
  → append-only event store
  → transactional outbox
      ├── own analytics
      ├── GA4 Measurement Protocol
      └── future sinks
```

`firebaseMode`：

- `disabled`
- `client_direct`
- `server_forwarded`

同一事件只能通过一种路径进入 GA4，避免重复统计。

## 3.1 客户端非阻塞硬约束

`track()`、`screen()` 和 `report()` 都是同步入队接口，调用方禁止 `await`。它们不得执行
HTTP、磁盘 I/O、Firebase 初始化或序列化整个历史队列。

| 约束 | React Native / Flutter | ArkTS |
|---|---:|---:|
| 自有遥测内存上限 | 200 条 | 200 条 |
| 单批上限 | 25 条 | 25 条 |
| 单次网络超时 | 5 秒 | 5 秒 |
| 同时上传 | 1 个 | 1 个 |
| 失败退避 | 2/5/15/30/60 秒 + 抖动 | 2/5/15/30/60 秒 |
| Firebase 待处理上限 | 100 条 | 暂不启用 |

- 队列满时丢弃最旧的低优先级产品事件；不得扩容、阻塞或抢占业务请求。
- 磁盘快照使用防抖后台写入，写入失败仅丢失待上传遥测，不影响应用状态。
- Firebase 是独立的 best-effort sink；它的初始化、上传或崩溃上报失败不得阻塞自有后端。
- 前台只做短批次；低电量、后台、弱网和数据节省模式可由平台调度器延迟上传。
- 事件使用 `eventId` 幂等，重试不会形成重复统计。
- 服务端必须过滤敏感字段；客户端也不得把输入正文、Token、密码或验证码传给 `track()`。

## 4. 区域模型

```text
locale       UI 与客服语言
market       商业与渠道规则
dataRegion   数据存储区域
supportQueue 客服分配队列
```

判断顺序：App 固定市场 → 账号 `homeRegion` → 用户首次选择 → 商店渠道 →
服务端 IP 建议 → 系统语言/时区弱提示。IP 不能作为唯一依据。

## 5. 客服和产品反馈

客服工单与产品建议是两个领域：

- 工单：解决账号、会员、支付、故障和隐私问题。
- 反馈：建议、体验评价、需求投票和迭代状态。

工单状态：

```text
submitted -> triaged -> in_progress -> waiting_for_user -> resolved -> closed
```

建议状态：

```text
submitted -> reviewing -> planned -> in_development -> released | declined
```

## 6. 路由规则

服务端按以下字段决定客服队列：

```text
appId + market + dataRegion + locale + category + tier + severity
```

未登录反馈使用 App 范围的匿名安装 ID。附件必须经类型/大小校验、恶意文件扫描和
生命周期清理；附带诊断信息必须由用户明确同意。

## 7. API

```text
POST /api/v1/telemetry/events
GET  /api/v1/support/config
GET  /api/v1/support/help
POST /api/v1/support/tickets
GET  /api/v1/support/tickets
GET  /api/v1/support/tickets/:id
POST /api/v1/support/tickets/:id/messages
POST /api/v1/support/feedback
GET  /api/v1/support/feedback/:id
```
