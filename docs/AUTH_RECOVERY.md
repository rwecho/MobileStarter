# 密码找回与邮件投递

密码找回使用三段式协议：

```text
POST /api/v1/auth/password/forgot
POST /api/v1/auth/password/verify
POST /api/v1/auth/password/reset
```

- 找回申请对存在和不存在的邮箱返回相同结果，避免账号枚举。
- 六位验证码有效期 10 分钟，60 秒内不重复发送，连续错误 5 次后锁定。
- 验证成功只签发 10 分钟有效的一次性重置令牌。
- 修改密码后撤销该用户全部现有会话。
- 验证码与重置令牌只以带服务端 pepper 的哈希形式保存。

邮件先写入 `outbound_messages`，再投递到 `MOBILEUI_EMAIL_ENDPOINT`。外部邮件服务接收：

```json
{
  "appId": "mobileui",
  "to": "user@example.com",
  "template": "password_reset_code",
  "code": "123456"
}
```

请求使用 `Authorization: Bearer <MOBILEUI_EMAIL_API_KEY>`。未配置 endpoint 时保留
`pending` 本地邮件，供本地开发和审核；生产发布门禁必须验证真实邮件 provider。

## 手机号验证码登录

- 租户通过 `auth.providers` 的 `phone` 项控制入口及平台范围。
- 号码必须使用 E.164 格式；验证码 10 分钟有效、60 秒冷却、最多 5 次尝试。
- 验证码只保存带 pepper 的哈希，成功后一次性作废并签发常规 Session。
- 短信先写入 `outbound_messages`，再非阻塞投递至 `MOBILEUI_SMS_ENDPOINT`。
- 外部短信服务使用 `MOBILEUI_SMS_API_KEY` 鉴权；未配置时消息保留为 `pending`，便于本地审核。
- Apple、Google、GitHub 的图标由租户策略控制可见性，由平台 Client ID/Secret 控制可用性。
