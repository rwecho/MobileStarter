# MobileUI 验收证据

## 2026-07-29 — 遥测

- React Native TypeScript：通过。
- Next.js TypeScript 与生产构建：通过。
- 同一 `eventId` 第一次接收 `accepted=1`，第二次接收 `duplicates=1`。
- 包含 `token` 的属性上传后，数据库仅保存允许字段。
- 三端静态架构检查：通过。

## 2026-07-29 — 客服、反馈与租户隔离

- 匿名安装创建工单：通过。
- 工单列表包含新工单：通过。
- 工单初始消息持久化：通过。
- 工单继续回复：通过。
- 其他安装标识读取工单：`404`。
- 其他安装标识读取反馈：`404`。
- 使用 App A 的 Session Token 请求 App B：`401 TENANT_MISMATCH`。
- 测试账号在验证后删除。
- 测试工单与测试反馈在验证后从本地数据库清理。

这些结果来自 PostgreSQL 切换前的生产模式 Next.js 服务和真实 SQLite
数据库，不是 mock 响应；数据库切换后的集成验证以当前 Server CI 为准。

## 2026-07-29 — 找回密码

- 找回申请：`202`。
- 错误验证码：`400`，尝试次数被记录。
- 正确验证码换取一次性重置令牌：`200`。
- 使用重置令牌修改密码：`200`。
- 旧密码登录：`401`。
- 重置前的既有 Session：`401`。
- 新密码登录：`200`。
- 测试账号、验证码、重置令牌与邮件队列记录均已清理。

## 2026-07-30 — 最终构建、动态登录与手机号认证

- Next.js：4 个核心测试通过，ESLint 零错误，TypeScript 通过，生产构建通过。
- 真实 API 链路：注册、资料、头像、设置、会话、会员订单、通知、遥测、客服与删号通过。
- 跨租户 Session 请求返回 `401`，测试账号及手机号测试数据均已精确清理。
- 手机号验证码：申请 `202`，短信出站队列生成，验证码校验并创建 Session 成功。
- 租户策略下发 `password / phone / apple / google / github / wechat` 可见性。
- 未配置 OAuth Client ID 的品牌入口保持可见但禁用；配置完成后动态启用。
- React Native：严格 TypeScript 和 Expo Web 生产导出通过。
- Flutter：`flutter analyze` 零问题，Widget 测试通过，Web release 构建通过。
- ArkTS：真实 HTTP、Preferences 缓存及手机号认证已接入；仓库静态门禁通过。
- 全仓架构检查：134 个源文件通过，未发现 emoji/icon font 回退或超限文件。
- React Native 截图：7 张，均为 `390 × 844`，已逐张视觉审核。
