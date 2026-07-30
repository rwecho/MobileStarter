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

Copy-Item -LiteralPath (Join-Path $source 'icons') `
  -Destination (Join-Path $targets[0] 'icons') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $source 'illustrations') `
  -Destination (Join-Path $targets[0] 'illustrations') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $source 'icons') `
  -Destination (Join-Path $targets[1] 'icons') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $source 'illustrations') `
  -Destination (Join-Path $targets[1] 'illustrations') -Recurse -Force

Get-ChildItem -LiteralPath (Join-Path $source 'icons') -File | ForEach-Object {
  $arkName = $_.Name.Replace('-', '_')
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targets[2] $arkName) -Force
}
Get-ChildItem -LiteralPath (Join-Path $source 'illustrations') -File | ForEach-Object {
  $arkName = $_.Name.Replace('-', '_')
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targets[2] $arkName) -Force
}

Write-Output 'SVG assets synchronized.'
