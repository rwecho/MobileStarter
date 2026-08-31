# I18N 指南

三端 i18n 范式与文案抽取规则。当前 auth 模块已全部接入，其余模块按本指南迁移。

## 现状

| 端 | 方案 | 语言字典 | 切换机制 |
|---|---|---|---|
| ArkTS | 系统资源 `string.json` + `appString(AppString.X, store.language)` | `AppScope/resources/{base,en_US}/element/string.json` | 用户 settings.language（服务端下发） |
| Flutter | 官方 gen_l10n（`flutter gen-l10n`） | `lib/l10n/app_{zh,en}.arb` → 生成 `lib/l10n/generated/` | MaterialApp `locale` ← settings.language |
| RN | i18next + react-i18next | `src/i18n/{zh,en}.ts` | `setAppLanguage()` ← settings.language（AppStore 驱动） |

默认语言均为 zh-CN；三端语言 key 一一对应（auth 命名空间已对齐）。

## 新增一条文案的步骤

以 auth 模块为例（其他模块同构，建议按模块划分 key 前缀）：

1. **ArkTS**：`AppStrings.ets` enum 加成员 + `resName()` 加映射 + 两个 `string.json` 加条目；组件里 `appString(AppString.X, this.store.language)`。
2. **Flutter**：`app_zh.arb`（模板文件）加 key 并跑 `flutter gen-l10n`；`app_en.arb` 同步翻译；组件里 `AppLocalizations.of(context)!.authXxx`。
3. **RN**：`zh.ts` 加 key；`en.ts` 同步翻译（`satisfies typeof zh` 会强制 key 对齐，漏译 typecheck 报错）；组件里 `t('auth.xxx')`。

## 约束

- 翻译 key 双语必须同时新增：RN 由 `satisfies` 编译期保证；ArkTS/Flutter 靠 review（资源缺失时 appString 回退资源名，gen_l10n 回退模板语言）。
- state/动作层的用户可见错误（如 ArkTS `authErrorMessage`、apiClient 抛出的服务端 message）目前仍为服务端下发中文，服务端 i18n 是独立课题，不在客户端字典范围内。
- 插值：RN `t('auth.codeSentTo', { email })`；ARB `"authCodeSentTo": "…{email}"`（带 `@` 元数据）；ArkTS 用字符串拼接或拆分 key。
- 剩余硬编码文案的迁移是机械工作，按上述步骤按模块批量推进即可（`grep -rn '[一-龥]'` 可定位）。
