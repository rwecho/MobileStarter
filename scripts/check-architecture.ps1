param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$sourcePatterns = @('*.dart', '*.ts', '*.tsx', '*.ets')
$sourceFiles = foreach ($pattern in $sourcePatterns) {
  Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $pattern |
    Where-Object {
      $_.FullName -notmatch '[\\/](node_modules(?:\.[^\\/]+)?|build|dist|oh_modules|\.next)[\\/]'
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

  if ($file.Extension -in @('.ts', '.tsx') -and $content -match '\bany\b') {
    $errors.Add("$($file.FullName): TypeScript any is forbidden")
  }

  if ($file.Extension -eq '.dart' -and $content -match '\bIcons\.') {
    $errors.Add("$($file.FullName): icon fonts are forbidden; use SVG assets")
  }
}

$svgFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.svg' |
  Where-Object {
    $_.FullName -notmatch '[\\/](node_modules(?:\.[^\\/]+)?|build|dist|oh_modules|\.next)[\\/]'
  }
foreach ($svg in $svgFiles) {
  $svgText = Get-Content -Raw -LiteralPath $svg.FullName
  $isIllustration = $svg.BaseName -in @('promo', 'empty', 'offline')
  if (-not $isIllustration -and $svgText -notmatch 'viewBox="0 0 24 24"') {
    $errors.Add("$($svg.FullName): SVG must use viewBox 0 0 24 24")
  }
}

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Output "Architecture checks passed for $($sourceFiles.Count) source files."
