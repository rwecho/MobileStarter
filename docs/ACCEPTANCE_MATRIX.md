# MobileUI 最终验收矩阵

本文件是最终审核组的核销清单。不得以“页面已做”“接口已写”代替逐项证据。

## 使用规则

- 状态仅允许：`NOT_STARTED / IMPLEMENTED / SELF_VERIFIED / REVIEWED / ACCEPTED / REJECTED`。
- 一条需求必须分别验证服务端、React Native、Flutter、ArkTS；不适用时必须写明原因。
- “真实”表示服务端确认且重启后仍成立，不能只修改客户端内存。
- 破坏性操作必须验证取消、确认、执行中、成功和失败五个分支。
- 每项证据记录代码链接、测试名称、截图/录屏、API trace 或数据库断言。

## A. 基础与远端配置

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| CFG-01 | App 隔离 | 两个 `appId` 请求得到各自品牌和配置，数据不串用 | NOT_STARTED |
| CFG-02 | 环境隔离 | development/staging/production 配置独立 | NOT_STARTED |
| CFG-03 | 配置版本 | 响应包含稳定版本，未变化时支持缓存命中 | NOT_STARTED |
| CFG-04 | 草稿隔离 | 保存草稿不影响已发布客户端 | NOT_STARTED |
| CFG-05 | 发布 | 发布后客户端按策略拉到新版本 | NOT_STARTED |
| CFG-06 | 回滚 | 回滚后恢复上一稳定版本并保留审计记录 | NOT_STARTED |
| CFG-07 | 非法配置 | 缺字段、重复 key、错误周期均禁止发布 | NOT_STARTED |
| CFG-08 | 离线首次启动 | 无缓存时使用内置安全配置并可进入 App | NOT_STARTED |
| CFG-09 | 离线再次启动 | 使用最后成功配置并显示离线状态 | NOT_STARTED |
| CFG-10 | 维护模式 | 服务端开启后显示维护页并按间隔重试 | NOT_STARTED |
| CFG-11 | 强制更新 | 低于最低版本时只允许进入更新流程 | NOT_STARTED |
| CFG-12 | 功能开关 | 关闭功能后入口、路由和服务端权限同时生效 | NOT_STARTED |

## B. 启动、Logo 与 Splash

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| LCH-01 | Logo 初始化 | 冷启动展示品牌且初始化不重复执行 | NOT_STARTED |
| LCH-02 | 最低展示时间 | 快速设备也不会造成闪屏 | NOT_STARTED |
| LCH-03 | 远端 Splash | 服务端换素材后无需发版即可更新 | NOT_STARTED |
| LCH-04 | 时间窗 | 未开始和已结束活动不展示 | NOT_STARTED |
| LCH-05 | 人群/平台 | 不符合条件的用户和平台不展示 | NOT_STARTED |
| LCH-06 | 频次控制 | 达到每日/总次数后跳过 | NOT_STARTED |
| LCH-07 | 跳过 | 跳过只记录一次并进入正确守卫路由 | NOT_STARTED |
| LCH-08 | CTA | 白名单内部路由/HTTPS 链接正确跳转 | NOT_STARTED |
| LCH-09 | 素材失败 | 图片失败使用品牌降级图，不停留死页 | NOT_STARTED |
| LCH-10 | 首次引导 | 仅按配置版本和完成记录展示 | NOT_STARTED |

## C. 注册、登录和会话

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| AUTH-01 | 注册成功 | 创建真实用户和会话，密码不可逆存储 | NOT_STARTED |
| AUTH-02 | 邮箱重复 | 返回字段级冲突，不暴露额外账号信息 | NOT_STARTED |
| AUTH-03 | 密码策略 | 客户端提示与服务端校验一致 | NOT_STARTED |
| AUTH-04 | 协议同意 | 未同意不能注册，同意版本留记录 | NOT_STARTED |
| AUTH-05 | 登录成功 | 返回会话并恢复登录前目标路由 | NOT_STARTED |
| AUTH-06 | 登录失败 | 错误明确、不清空邮箱、不记录密码 | NOT_STARTED |
| AUTH-07 | 限速/锁定 | 连续失败触发策略，冷却后可恢复 | NOT_STARTED |
| AUTH-08 | 邮箱验证 | 正确令牌验证，过期和复用均拒绝 | NOT_STARTED |
| AUTH-09 | 重发验证 | 冷却和次数限制生效 | NOT_STARTED |
| AUTH-10 | 找回申请 | 无论账号存在与否外部响应一致 | IMPLEMENTED |
| AUTH-11 | 重置密码 | 正确令牌可改密，过期/复用拒绝 | IMPLEMENTED |
| AUTH-12 | Token 刷新 | 并发 401 只执行一次 refresh | NOT_STARTED |
| AUTH-13 | Token 轮换 | 旧 refresh token 复用触发撤销策略 | NOT_STARTED |
| AUTH-14 | 当前设备退出 | 服务端撤销且本地敏感数据清除 | NOT_STARTED |
| AUTH-15 | 全部设备退出 | 所有既有会话失效 | NOT_STARTED |
| AUTH-16 | 会话过期 | 进入登录守卫，不出现循环跳转 | NOT_STARTED |
| AUTH-17 | 重置验证码 | 10 分钟过期、5 次锁定、60 秒重发冷却 | IMPLEMENTED |

## D. 资料、头像与账号安全

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| USR-01 | 查看资料 | 展示服务端真实资料和加载/错误状态 | NOT_STARTED |
| USR-02 | 改用户名 | 校验后持久化，重启和另一设备同步 | NOT_STARTED |
| USR-03 | 用户名冲突 | 返回字段级错误并保留输入 | NOT_STARTED |
| USR-04 | 选择头像 | 相机/相册权限与取消操作正确 | NOT_STARTED |
| USR-05 | 裁剪压缩 | 方向正确、大小受控、预览一致 | NOT_STARTED |
| USR-06 | 上传头像 | 进度、防重复、失败重试和最终 URL 正确 | NOT_STARTED |
| USR-07 | 删除头像 | 恢复默认头像并按策略处理旧文件 | NOT_STARTED |
| USR-08 | 修改密码 | 要求当前密码，新密码生效 | NOT_STARTED |
| USR-09 | 改密会话处置 | 旧设备/旧 token 按策略失效 | NOT_STARTED |
| USR-10 | 设备列表 | 当前设备、平台和最近活动真实 | NOT_STARTED |
| USR-11 | 撤销设备 | 目标设备下次请求退出，当前页面刷新 | NOT_STARTED |
| USR-12 | 数据导出 | 创建请求、查询状态并取得结果 | NOT_STARTED |
| USR-13 | 删除账号申请 | 重新认证、确认短语、冷静期正确 | NOT_STARTED |
| USR-14 | 取消删号 | 冷静期内可取消并保留账号 | NOT_STARTED |
| USR-15 | 完成删号 | 会话失效，数据删除/匿名化符合策略 | NOT_STARTED |

## E. 会员、权益与用量

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| MEM-01 | 单等级 | 只有 Free 时页面不显示虚假升级按钮 | NOT_STARTED |
| MEM-02 | 二等级 | Free/Pro 正确显示当前等级和差异 | NOT_STARTED |
| MEM-03 | 三等级 | Free/Pro/Business 无客户端改码自动布局 | NOT_STARTED |
| MEM-04 | 多等级 | 超过三档可滚动/比较且无布局溢出 | NOT_STARTED |
| MEM-05 | 等级排序 | 服务端顺序和推荐标记正确 | NOT_STARTED |
| MEM-06 | 隐藏等级 | 新用户不可见，既有权益不丢失 | NOT_STARTED |
| MEM-07 | 布尔权益 | 开/关能力由服务端强制校验 | NOT_STARTED |
| MEM-08 | 额度权益 | 总量、已用、剩余和重置时间一致 | NOT_STARTED |
| MEM-09 | 月付方案 | 周期、价格、币种和商品映射正确 | NOT_STARTED |
| MEM-10 | 年付方案 | 折扣表达由数据计算且可核对 | NOT_STARTED |
| MEM-11 | 一次性包 | 购买后增加对应额度而非错误订阅 | NOT_STARTED |
| MEM-12 | 免费试用 | 资格、起止时间和重复领取限制生效 | NOT_STARTED |
| MEM-13 | 促销 | 时间窗/人群外不显示或不可购买 | NOT_STARTED |
| MEM-14 | 当前订阅 | 状态、续费日、宽限期和渠道真实 | NOT_STARTED |
| MEM-15 | 升降级 | 生效时间和价差策略按渠道结果展示 | NOT_STARTED |
| MEM-16 | 恢复购买 | 找回同账号有效商店权益且不重复发放 | NOT_STARTED |

## F. 订单与支付

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| PAY-01 | 创建订单 | 金额由服务端计算，客户端不能篡改 | NOT_STARTED |
| PAY-02 | 幂等下单 | 同一幂等键重复请求只产生一单 | NOT_STARTED |
| PAY-03 | Mock 成功 | 本地完整走过支付、回调和权益发放 | NOT_STARTED |
| PAY-04 | Mock 失败 | 失败原因可恢复，不发权益 | NOT_STARTED |
| PAY-05 | 中断恢复 | 杀 App 后查询订单获得最终状态 | NOT_STARTED |
| PAY-06 | 重复回调 | 十次相同 Webhook 只处理一次 | NOT_STARTED |
| PAY-07 | 验签失败 | 拒绝回调、记录安全事件、不改订单 | NOT_STARTED |
| PAY-08 | Apple 校验 | 交易与 App/商品/用户映射一致 | NOT_STARTED |
| PAY-09 | Google 校验 | purchase token 校验和确认状态正确 | NOT_STARTED |
| PAY-10 | 微信适配 | 未配置不展示；配置后按签名协议执行 | NOT_STARTED |
| PAY-11 | 支付宝适配 | 未配置不展示；配置后按签名协议执行 | NOT_STARTED |
| PAY-12 | 退款撤销 | 订单和权益按规则同步更新 | NOT_STARTED |
| PAY-13 | 对账 | 漏单、金额差异和状态差异可发现 | NOT_STARTED |
| PAY-14 | 渠道故障 | 显示可重试状态且不制造重复订单 | NOT_STARTED |

## G. 通知与设备

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| NTF-01 | 站内通知 | 服务端创建后通知中心可见 | NOT_STARTED |
| NTF-02 | 分页与空态 | 翻页不重复，空态有说明 | NOT_STARTED |
| NTF-03 | 未读数 | 单条读/全部读后所有入口同步 | NOT_STARTED |
| NTF-04 | 删除 | 删除真实持久化，刷新不恢复 | NOT_STARTED |
| NTF-05 | 通知深链 | 登录守卫后到达白名单目标路由 | NOT_STARTED |
| NTF-06 | 偏好保存 | 分类、渠道和免打扰持久化 | NOT_STARTED |
| NTF-07 | 系统权限 | 拒绝后解释并可前往系统设置 | NOT_STARTED |
| NTF-08 | 设备注册 | token、平台、语言、时区和版本真实 | NOT_STARTED |
| NTF-09 | token 轮换 | 新 token 替代旧 token 且不重复设备 | NOT_STARTED |
| NTF-10 | 退出解绑 | 退出后营销消息不再发给该会话设备 | NOT_STARTED |
| NTF-11 | 本地 provider | 无云密钥时可审计完整发送任务 | NOT_STARTED |
| NTF-12 | FCM provider | Next.js 发往 FCM 并记录单设备结果 | NOT_STARTED |
| NTF-13 | APNs/HMS 扩展 | provider 可替换，不侵入通知领域逻辑 | NOT_STARTED |
| NTF-14 | 前后台行为 | 前台、后台、冷启动点击均符合路由规则 | NOT_STARTED |
| NTF-15 | 失败处理 | 临时失败重试，永久无效 token 清除 | NOT_STARTED |

## H. 设置中心

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| SET-01 | 账号入口 | 登录/未登录状态显示正确动作 | NOT_STARTED |
| SET-02 | 账号安全 | 修改密码、邮箱验证、身份绑定均有功能 | NOT_STARTED |
| SET-03 | 登录设备 | 进入真实设备列表并可撤销 | NOT_STARTED |
| SET-04 | 通知设置 | 应用偏好与系统权限区分展示 | NOT_STARTED |
| SET-05 | 隐私设置 | 个性化和分析许可真实保存 | NOT_STARTED |
| SET-06 | 通用设置 | 每个开关有明确数据源和生效位置 | NOT_STARTED |
| SET-07 | 主题 | 系统/浅色/深色即时生效并保持 | NOT_STARTED |
| SET-08 | 语言 | 切换后全局文案更新并保持 | NOT_STARTED |
| SET-09 | 字号 | 预览、动态字体和布局无截断 | NOT_STARTED |
| SET-10 | 存储 | 统计真实，分类清理后数值变化 | NOT_STARTED |
| SET-11 | 权限 | 读取真实系统状态并正确引导 | NOT_STARTED |
| SET-12 | 帮助反馈 | 可提交内容/附件并查询提交结果 | NOT_STARTED |
| SET-13 | 法律协议 | 内容、版本和更新时间来自配置 | NOT_STARTED |
| SET-14 | 关于 | 版本、构建、渠道和更新检查真实 | NOT_STARTED |
| SET-15 | 退出登录 | 确认后撤销会话并清敏感缓存 | NOT_STARTED |
| SET-16 | 删除账户 | 完成 USR-13 至 USR-15 全流程 | NOT_STARTED |
| SET-17 | 无占位 | 审核组逐行点击无空回调或假 Toast | NOT_STARTED |

## I. 通用质量与三端一致性

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| QLT-01 | SVG 图标 | 无 Emoji、Unicode 图标或 icon font | NOT_STARTED |
| QLT-02 | 点击区域 | 图标按钮至少 44×44 且有语义标签 | NOT_STARTED |
| QLT-03 | 明暗主题 | 所有关键页面无硬编码颜色漂移 | NOT_STARTED |
| QLT-04 | 动态字体 | 最大支持字号无关键内容截断 | NOT_STARTED |
| QLT-05 | 屏幕阅读器 | 标签、顺序和状态播报可理解 | NOT_STARTED |
| QLT-06 | 减少动态效果 | 系统开启后非必要动画被抑制 | NOT_STARTED |
| QLT-07 | 网络异常 | 断网、慢网、超时和 5xx 均可恢复 | NOT_STARTED |
| QLT-08 | 防重复提交 | 表单、订单和危险操作 pending 时禁用 | NOT_STARTED |
| QLT-09 | 敏感数据 | 日志、URL、分析和持久 UI 无密钥/令牌/密码 | NOT_STARTED |
| QLT-10 | 架构规则 | 文件、函数、嵌套、复杂度和分层检查通过 | NOT_STARTED |
| QLT-11 | 契约一致 | 三端模型通过同一契约测试 | NOT_STARTED |
| QLT-12 | 路由一致 | 三端 route ID、守卫和参数语义一致 | NOT_STARTED |
| QLT-13 | 状态一致 | 三端异步状态和错误映射一致 | NOT_STARTED |
| QLT-14 | 冷启动性能 | 达到项目设定预算并有真机报告 | NOT_STARTED |
| QLT-15 | 崩溃恢复 | 异常退出后不会卡在 loading 或损坏会话 | NOT_STARTED |
| QLT-16 | 构建可复现 | 锁文件、环境说明和全新构建验证通过 | NOT_STARTED |

## J. Telemetry、客服与反馈

| ID | 验收项 | 核心动作与预期 | 状态 |
|---|---|---|---|
| TEL-01 | 页面进入 | 三端导航自动产生统一 `screen_view` | NOT_STARTED |
| TEL-02 | 停留时长 | 返回、切后台、idle 和异常恢复计算正确 | NOT_STARTED |
| TEL-03 | 语义点击 | Button/ListRow 使用稳定 action ID，不记录坐标 | NOT_STARTED |
| TEL-04 | 离线队列 | 断网事件缓存，联网批量幂等上传 | NOT_STARTED |
| TEL-05 | 隐私过滤 | 密码、Token、验证码和输入正文不可进入事件 | NOT_STARTED |
| TEL-06 | 多租户 | 事件按 App/环境/区域隔离 | NOT_STARTED |
| TEL-07 | Firebase 模式 | disabled/direct/forwarded 不产生重复事件 | NOT_STARTED |
| TEL-08 | UI 零等待 | 埋点调用不 await，慢网/断网/存储故障不增加业务操作等待 | IMPLEMENTED |
| TEL-09 | 有界资源 | 自有队列最多 200、Firebase 最多 100，满后丢旧且内存不增长 | IMPLEMENTED |
| TEL-10 | 批量与单飞 | 每批最多 25 条、同时最多一个自有上传请求 | IMPLEMENTED |
| TEL-11 | 超时与退避 | 5 秒取消，按 2/5/15/30/60 秒退避且成功后复位 | IMPLEMENTED |
| TEL-12 | 崩溃隔离 | Crashlytics/自有错误上报失败不产生未处理异常或崩溃循环 | IMPLEMENTED |
| SUP-01 | 帮助内容 | 按 App、区域和语言返回正确文章 | IMPLEMENTED |
| SUP-02 | 创建工单 | 登录与匿名用户均可创建真实工单 | IMPLEMENTED |
| SUP-03 | 工单对话 | 用户可查看状态、继续回复并收到通知 | PARTIAL |
| SUP-04 | 区域路由 | locale/market/dataRegion/supportQueue 分别生效 | IMPLEMENTED |
| SUP-05 | 附件与诊断 | 明确授权、限制、脱敏和清理策略生效 | NOT_STARTED |
| SUP-06 | 产品反馈 | 建议真实持久化并可查询处理状态 | IMPLEMENTED |
| SUP-07 | 满意度 | 已解决工单可评价且不可重复刷写 | NOT_STARTED |
| SUP-08 | 所有权隔离 | 其他安装、账号或 App 读取工单/反馈返回 404/401 | IMPLEMENTED |

## 审核签署

| 审核角色 | 审核人 | 日期 | 结果 | 未通过 ID |
|---|---|---|---|---|
| 产品 |  |  |  |  |
| 设计 |  |  |  |  |
| 工程 |  |  |  |  |
| 安全 |  |  |  |  |
| QA |  |  |  |  |

只有全部硬门禁通过，且关键项不存在 `REJECTED` 或未说明的 `NOT_STARTED`，
版本才允许标记为最终可交付。
