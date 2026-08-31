# 全仓源码架构检查（行数硬限 / emoji / TS any / 图标字体 / SVG viewBox / 关键行为标记）。
# TODO(长期)：按栈分片——各 CI 用 -Root 只查自己的目录，并给纯类型/表驱动文件
# 加目录级例外；领域抽象由业务变化驱动，不由行数驱动（2026-08-31 拆分复盘结论）。
param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$sourcePatterns = @('*.dart', '*.ts', '*.tsx', '*.ets')
$sourceFiles = foreach ($pattern in $sourcePatterns) {
  Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $pattern |
    Where-Object {
      # generated 除外：l10n 等代码生成物不受手写源码的行数/样式硬限约束。
      $_.FullName -notmatch '[\\/](node_modules(?:\.[^\\/]+)?|build|dist|oh_modules|\.next|\.dart_tool|\.preview|\.hvigor|\.git|generated)[\\/]' -and
      $_.FullName -notmatch '[\\/]\.claude[\\/]worktrees[\\/]'
    }
}

foreach ($file in $sourceFiles) {
  $lines = Get-Content -LiteralPath $file.FullName
  if ($lines.Count -gt 350) {
    $errors.Add("$($file.FullName): $($lines.Count) lines exceeds hard limit 350")
  }

  $content = $lines -join "`n"
  if ($content -match '[\uD800-\uDBFF][\uDC00-\uDFFF]') {
    $errors.Add("$($file.FullName): emoji is forbidden; use an SVG icon")
  }

  if (
    $file.Extension -in @('.ts', '.tsx') -and
    $content -match '(:\s*any\b|<\s*any\s*>|\bas\s+any\b|\bany\s*\[\])'
  ) {
    $errors.Add("$($file.FullName): TypeScript any is forbidden")
  }

  if ($file.Extension -eq '.dart' -and $content -match '\bIcons\.') {
    $errors.Add("$($file.FullName): icon fonts are forbidden; use SVG assets")
  }
}

$svgFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.svg' |
  Where-Object {
    $_.FullName -notmatch '[\\/](node_modules(?:\.[^\\/]+)?|build|dist|oh_modules|\.next|\.dart_tool|\.preview|\.hvigor|\.git)[\\/]' -and
    $_.FullName -notmatch '[\\/]\.claude[\\/]worktrees[\\/]'
  }
foreach ($svg in $svgFiles) {
  $svgText = Get-Content -Raw -LiteralPath $svg.FullName
  $isIllustration = $svg.BaseName -in @(
    'promo',
    'empty',
    'offline',
    'logo',
    'app_icon',
    'start_window_icon'
  )
  if (-not $isIllustration -and $svgText -notmatch 'viewBox="0 0 24 24"') {
    $errors.Add("$($svg.FullName): SVG must use viewBox 0 0 24 24")
  }
}

function Assert-SourceContains {
  param([string]$RelativePath, [string]$Pattern, [string]$Message)
  $path = Join-Path $Root $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    $errors.Add("$path`: required source file is missing")
    return
  }
  $content = Get-Content -Raw -LiteralPath $path
  if ($content -notmatch $Pattern) {
    $errors.Add("$path`: $Message")
  }
}

Assert-SourceContains 'flutter/lib/screens/auth_screens.dart' `
  'consumeAuthRedirectTarget\(\)\s*\?\?\s*AppRoute\.home' `
  'ordinary authentication must land on home'
Assert-SourceContains 'react-native/src/state/AppStore.tsx' `
  "pendingRoute\s*\?\?\s*'home'" `
  'ordinary authentication must land on home'
Assert-SourceContains 'arkts/entry/src/main/ets/state/AppStore.ets' `
  'pendingRoute\s*\?\?\s*AppRoute\.Home' `
  'ordinary authentication must land on home'
Assert-SourceContains 'flutter/lib/app/mobile_ui_app.dart' `
  'textScaler:\s*TextScaler\.linear' `
  'saved text scale must be applied at the app root'
Assert-SourceContains 'react-native/src/preferences/PreferencesProvider.tsx' `
  'applyTheme\(palette,\s*textScale\)' `
  'saved text scale must be applied to shared typography'
Assert-SourceContains 'server/src/server/payment-providers.ts' `
  'MOCK_PAYMENT_FORBIDDEN' `
  'production must reject mock payment'

if ($errors.Count -gt 0) {
  # 一次性列出全部违规。不能用 Write-Error 逐条报：ErrorActionPreference=Stop
  # 下首条即中止脚本，后续违规全部被藏住（曾致 7 个超限文件在 CI 潜伏两周）。
  $errors | ForEach-Object { Write-Host "::error::$_" }
  Write-Host "Architecture checks failed with $($errors.Count) violation(s)."
  exit 1
}

Write-Output "Architecture checks passed for $($sourceFiles.Count) source files."
