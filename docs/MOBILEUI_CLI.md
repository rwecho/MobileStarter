# MobileUI CLI

`mobileui` 从本地母模板或 Git 仓库生成身份独立、平台范围明确的产品仓库。
它不会覆盖非空目录，也不会把母模板的本机缓存、构建产物或 ArkTS 签名凭据复制到产品。

## 当前能力

- `flutter`、`react-native`、`arkts` 单平台 Profile
- `all` 组合 Profile，三个平台仍使用独立 CI 与发布工作流
- 配置驱动的 `profiles/<id>/profile.json`
- 本地模板或远程 Git ref（branch、tag、SHA）
- 产品名称、包名、Bundle ID、URL scheme 等身份替换
- `.mobileui/template.json` 记录模板版本、来源、ref 和实际 commit
- `doctor` 检查目录、元数据、身份残留和 ArkTS 凭据
- `feature add` 为所有已选平台建立 feature-first 边界
- `update --check` 检查远程模板 ref 是否有新 commit，不覆盖业务代码

## 创建项目

本地开发模板：

```powershell
dart run tool/mobileui/bin/mobileui.dart create app-example `
  --output D:\workspace `
  --profile flutter `
  --display-name "Example" `
  --organization tech.zhongbei `
  --app-id example
```

React Native、ArkTS 或三平台组合：

```powershell
mobileui create app-rn --output D:\workspace --profile react-native `
  --display-name "RN App" --organization tech.zhongbei --app-id rn-app

mobileui create app-harmony --output D:\workspace --profile arkts `
  --display-name "Harmony App" --organization tech.zhongbei --app-id harmony-app

mobileui create app-all --output D:\workspace --profile all `
  --display-name "All App" --organization tech.zhongbei --app-id all-app
```

## 从 GitHub 获取最新模板

默认远程仓库是 `https://github.com/rwecho/MobileStarter.git`，默认 ref 是
`main`。命令会浅拉取该 ref，并将解析后的 commit SHA 写入 manifest：

```powershell
mobileui create app-example --output D:\workspace --profile flutter `
  --display-name "Example" --organization tech.zhongbei --app-id example `
  --source github
```

生产项目建议锁定 tag 或 commit，确保生成可复现：

```powershell
mobileui create app-example --output D:\workspace --profile flutter `
  --display-name "Example" --organization tech.zhongbei --app-id example `
  --source github --ref v0.2.0
```

也可以使用其他 Git 仓库：

```powershell
mobileui create app-example --output D:\workspace --profile arkts `
  --display-name "Example" --organization tech.zhongbei --app-id example `
  --source github --source-url https://github.com/acme/mobileui-template.git `
  --ref main
```

## 模板、Feature 和更新检查

```powershell
mobileui template list
mobileui doctor --project D:\workspace\app-example
mobileui feature add achievements --project D:\workspace\app-example
mobileui update --check --project D:\workspace\app-example
```

`feature add` 只创建 `domain/application/data/presentation` 所有权边界，
不生成虚假业务逻辑。`update --check` 返回值为 `0` 表示已是最新或使用本地来源，
`2` 表示远程 ref 出现新 commit。为了保护产品代码，当前不会自动覆盖模板文件；升级时应先审查差异。

## 生成结构

```text
app-example/
  .mobileui/template.json
  .github/workflows/
  flutter/          # 按 Profile 存在
  react-native/     # 按 Profile 存在
  arkts/            # 按 Profile 存在
  README.md
```
