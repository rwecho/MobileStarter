# MobileUI 多租户与运行时配置架构

## 1. 配置层级

```text
Tenant（客户/组织）
  └── App（具体产品）
        └── Environment（development / staging / production）
              ├── iOS Client
              ├── Android Client
              └── HarmonyOS Client
```

- Tenant 负责成员、角色、账单归属和多个 App 的管理。
- App 负责品牌、账号空间、法律文本、会员模型和业务功能。
- Environment 负责密钥、渠道、测试数据、配置发布和灰度。
- Platform 负责包名、商店商品 ID、OAuth client ID、推送和支付能力。

用户默认按 App 隔离。未来如需多个 App 共用账号，必须显式创建
`IdentityPool`，不能仅凭相同邮箱自动跨 App 合并。

## 2. 客户端识别

客户端请求包含：

```text
X-App-Id: mobileui-demo
X-App-Environment: production
X-Platform: ios | android | harmonyos
X-App-Version: 1.4.0
Accept-Language: zh-CN
```

`appId` 是公开标识，不是权限凭据。服务端必须根据已注册的包名、签名、OAuth
audience、用户会话和 App 归属执行真实授权。价格、权益、管理员权限和 provider
secret 永远不能由客户端决定。

## 3. Bootstrap 配置

`GET /api/v1/bootstrap` 返回一个裁剪后的客户端视图：

```json
{
  "schemaVersion": 1,
  "configVersion": 42,
  "expiresAt": "2026-07-30T00:00:00Z",
  "brand": {},
  "launch": {},
  "auth": {},
  "legal": {},
  "membership": {},
  "settingsPolicy": {},
  "features": {},
  "updatePolicy": {},
  "user": null
}
```

服务端内部配置与客户端公开配置分离。OAuth secret、支付密钥、推送凭据、内部
灰度规则和管理信息不得出现在 bootstrap。

## 4. 登录方式动态化

每个 App/Environment/Platform 单独配置：

```text
password: enabled / disabled
apple: enabled + clientId + platform availability
google: enabled + clientIds + platform availability
github: enabled + clientId + platform availability
wechat: enabled + appId + platform availability
```

客户端只渲染 bootstrap 中 `enabled && availableOnCurrentPlatform` 的入口。
服务端仍必须再次校验 provider 是否启用，避免旧客户端或伪造请求绕过。

统一身份规则：

- 邮箱密码、Apple、Google、GitHub、微信均绑定到同一 App 用户。
- 已登录用户主动绑定新的身份。
- 同 App 内只有经过 provider 验证的邮箱才允许进入安全合并流程。
- Apple 隐藏邮箱不得用作跨身份自动合并依据。
- 解绑前必须保证用户仍有至少一种可用登录方式。
- provider 关闭后已有绑定保留，是否允许继续登录由迁移策略决定。

## 5. 三层配置与启动顺序

客户端配置有三层：

1. `Embedded Safe Defaults`：随包发布，保证首次离线启动不白屏。
2. `Last Known Good`：最后一次校验成功并完整落盘的配置。
3. `Remote Published Config`：Next.js 当前发布版本。

冷启动流程：

```text
显示原生 Logo
  → 读取 Last Known Good（失败则 Embedded）
  → 依据本地配置完成路由守卫
  → 展示已经在本地的 Splash 素材
  → 后台请求 bootstrap（ETag / configVersion）
  → 下载并校验新素材
  → 原子写入新的 Last Known Good
  → 下一次冷启动使用新 Splash
```

普通品牌、Splash 和布局配置不应在当前页面中途切换。以下安全策略可立即生效：

- 强制更新；
- 维护模式；
- 账号/会话撤销；
- 高风险功能关闭；
- 支付渠道紧急停用。

## 6. 配置刷新策略

- 冷启动请求一次。
- App 从后台回到前台且超过 TTL 时请求。
- 前台运行每 15 分钟检查一次，具体 TTL 由服务端下发。
- 使用 `ETag/If-None-Match`，未变化返回 304。
- 网络恢复后执行一次带退避的刷新。
- 配置下载失败不覆盖 Last Known Good。
- `schemaVersion` 不兼容时使用旧配置并上报兼容性事件。
- 资源必须完成下载、哈希校验和解码测试后才能切换配置指针。

## 7. 离线行为矩阵

| 功能 | 离线行为 |
|---|---|
| Logo / Splash | 使用本地配置和已缓存素材；缺图使用内置品牌图 |
| 首页 | 展示缓存内容和持续离线 Banner |
| 已登录资料 | 可读缓存，明确标记可能不是最新 |
| 登录 / 注册 / 找回 | 禁用提交并提供重连动作，不假成功 |
| 修改头像 / 密码 | 禁止提交；不把高风险操作排队 |
| 普通偏好 | 可本地保存，联网后以版本号安全同步 |
| 会员目录 | 展示缓存价格并标记更新时间，购买按钮禁用 |
| 支付 / 恢复购买 | 必须联网 |
| 通知中心 | 可读本地缓存；已读可排队并幂等同步 |
| 隐私条款 | 展示已缓存的当前已知版本 |
| 删除账号 / 退出全部设备 | 必须联网并由服务端确认 |

## 8. 多 App 法律文本

法律文本是版本化数据，不是固定页面：

```text
LegalDocument
  appId
  environmentId
  type: privacy | terms | subscription | children
  locale
  revision
  title
  contentFormat: markdown | html | url
  content / url
  contentHash
  publishedAt
  effectiveAt
  requiresReconsent
```

用户同意记录包含 `userId/appId/type/revision/contentHash/time/platform`。当新的
条款设置 `requiresReconsent=true`，路由守卫必须在进入首页前要求重新同意。

首次安装离线时：

- 默认展示包内法律文本快照；
- App 可配置 `allowOfflineConsent`；
- 允许时本地记录并联网补传；
- 不允许时停留在可解释的联网要求页。

每个 App 可以有完全不同的中文、英文和其他语言文本。

## 9. 设置项策略

设置项由 `settingsPolicy` 控制，不只控制“显示/隐藏”：

```text
visibility: visible | hidden
mutability: user | admin_locked | system
value: 当前 App 默认值
allowedValues: 允许范围
requiresRestart: 是否下次启动生效
requiresNetwork: 是否必须联网
```

示例：

- 某 App 只有中文：语言设置 `visibility=hidden`。
- 显示中英文但不允许修改：`visible + admin_locked`。
- 允许两种语言：`visible + user + allowedValues=[zh-CN,en-US]`。
- 强制深色品牌：主题可隐藏且服务端固定为 dark。
- 禁止营销分析：开关隐藏且服务端也拒绝写入 true。

服务端策略是最终权限来源。客户端隐藏入口只是表现层，不能代替服务端校验。

## 10. 会员与支付的多租户边界

- Tier、Entitlement、Plan、Price 均包含 `appId/environmentId`。
- 同名 `Pro` 在不同 App 中没有天然关联。
- 商店商品映射包含 platform、bundle/package 和 provider product ID。
- 订单从认证会话推导 App，不能接受客户端提交任意 appId。
- Webhook 根据签名凭据和商品映射定位 App。
- provider secret 由服务端加密保存并按 Environment 隔离。

## 11. 通知的多租户边界

- 通知模板、发送者、设备 token 和偏好均按 App 隔离。
- 一个物理设备安装两个 App 会产生两个独立 DeviceInstallation。
- Next.js 负责目标、模板、任务、偏好过滤和发送记录。
- FCM/APNs/HMS 负责系统级送达。
- provider 未配置时仍可使用站内通知和本地审计 provider。

## 12. 管理后台发布流程

```text
编辑草稿
  → Schema 校验
  → 平台能力校验
  → 预览指定 App/平台/语言
  → 审核
  → 定时或立即发布
  → 客户端灰度
  → 全量
  → 可回滚
```

所有发布记录保存配置 diff、操作者、审核人、时间、目标 App/环境和回滚来源。

