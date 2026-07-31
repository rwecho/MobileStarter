param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$source = Join-Path $Root 'assets'
$targets = @(
  (Join-Path $Root 'flutter\assets'),
  (Join-Path $Root 'react-native\assets'),
  (Join-Path $Root 'arkts\entry\src\main\resources\base\media')
)

foreach ($target in $targets) {
  if (-not (Test-Path -LiteralPath $target)) {
    New-Item -ItemType Directory -Path $target | Out-Null
  }
}

function Sync-FolderContents {
  param(
    [string]$SourceDirectory,
    [string]$TargetDirectory
  )

  if (-not (Test-Path -LiteralPath $TargetDirectory)) {
    New-Item -ItemType Directory -Path $TargetDirectory | Out-Null
  }
  Get-ChildItem -LiteralPath $SourceDirectory -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $TargetDirectory -Force
  }
}

Sync-FolderContents (Join-Path $source 'icons') (Join-Path $targets[0] 'icons')
Sync-FolderContents (Join-Path $source 'illustrations') `
  (Join-Path $targets[0] 'illustrations')
Sync-FolderContents (Join-Path $source 'icons') (Join-Path $targets[1] 'icons')
Sync-FolderContents (Join-Path $source 'illustrations') `
  (Join-Path $targets[1] 'illustrations')

Get-ChildItem -LiteralPath (Join-Path $source 'icons') -File | ForEach-Object {
  $arkName = $_.Name.Replace('-', '_')
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targets[2] $arkName) -Force
}
Get-ChildItem -LiteralPath (Join-Path $source 'illustrations') -File |
  ForEach-Object {
  $arkName = $_.Name.Replace('-', '_')
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targets[2] $arkName) -Force
}

$appIconSource = Join-Path $source 'illustrations\app-icon.png'
$appScopeMedia = Join-Path $Root 'arkts\AppScope\resources\base\media'
Copy-Item -LiteralPath $appIconSource `
  -Destination (Join-Path $appScopeMedia 'app_icon.png') -Force

& (Join-Path $PSScriptRoot 'generate-launcher-assets.ps1') -Root $Root
Write-Output 'Shared and launcher assets synchronized.'
