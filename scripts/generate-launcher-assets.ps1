param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Export-SquarePng {
  param(
    [System.Drawing.Image]$Source,
    [string]$Destination,
    [int]$Size,
    [bool]$FlattenBackground
  )

  $bitmap = New-Object System.Drawing.Bitmap(
    $Size,
    $Size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  )
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CompositingQuality =
      [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode =
      [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode =
      [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $background = if ($FlattenBackground) {
      [System.Drawing.Color]::FromArgb(255, 168, 68, 68)
    } else {
      [System.Drawing.Color]::Transparent
    }
    $graphics.Clear($background)
    $graphics.DrawImage($Source, 0, 0, $Size, $Size)
    $directory = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $directory)) {
      New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

$masterPath = Join-Path $Root 'assets\illustrations\app-icon.png'
$masterTemp = Join-Path $Root 'assets\illustrations\app-icon.generated.png'
$source = [System.Drawing.Image]::FromFile($masterPath)
try {
  Export-SquarePng $source $masterTemp 1024 $true
} finally {
  $source.Dispose()
}
Move-Item -LiteralPath $masterTemp -Destination $masterPath -Force

$icon = [System.Drawing.Image]::FromFile($masterPath)
try {
  Export-SquarePng $icon (Join-Path $Root 'react-native\assets\app-icon.png') 1024 $true

  $androidIcons = @{
    'mipmap-mdpi\ic_launcher.png' = 48
    'mipmap-hdpi\ic_launcher.png' = 72
    'mipmap-xhdpi\ic_launcher.png' = 96
    'mipmap-xxhdpi\ic_launcher.png' = 144
    'mipmap-xxxhdpi\ic_launcher.png' = 192
  }
  foreach ($entry in $androidIcons.GetEnumerator()) {
    $target = Join-Path $Root "flutter\android\app\src\main\res\$($entry.Key)"
    Export-SquarePng $icon $target $entry.Value $true
  }

  $iosIcons = @{
    'Icon-App-20x20@1x.png' = 20
    'Icon-App-20x20@2x.png' = 40
    'Icon-App-20x20@3x.png' = 60
    'Icon-App-29x29@1x.png' = 29
    'Icon-App-29x29@2x.png' = 58
    'Icon-App-29x29@3x.png' = 87
    'Icon-App-40x40@1x.png' = 40
    'Icon-App-40x40@2x.png' = 80
    'Icon-App-40x40@3x.png' = 120
    'Icon-App-60x60@2x.png' = 120
    'Icon-App-60x60@3x.png' = 180
    'Icon-App-76x76@1x.png' = 76
    'Icon-App-76x76@2x.png' = 152
    'Icon-App-83.5x83.5@2x.png' = 167
    'Icon-App-1024x1024@1x.png' = 1024
  }
  $iosIconRoot = Join-Path $Root 'flutter\ios\Runner\Assets.xcassets\AppIcon.appiconset'
  foreach ($entry in $iosIcons.GetEnumerator()) {
    Export-SquarePng $icon (Join-Path $iosIconRoot $entry.Key) $entry.Value $true
  }
} finally {
  $icon.Dispose()
}

$splashPath = Join-Path $Root 'assets\illustrations\splash-logo.png'
$splash = [System.Drawing.Image]::FromFile($splashPath)
try {
  $launchRoot = Join-Path $Root 'flutter\ios\Runner\Assets.xcassets\LaunchImage.imageset'
  Export-SquarePng $splash (Join-Path $launchRoot 'LaunchImage.png') 88 $false
  Export-SquarePng $splash (Join-Path $launchRoot 'LaunchImage@2x.png') 176 $false
  Export-SquarePng $splash (Join-Path $launchRoot 'LaunchImage@3x.png') 264 $false
} finally {
  $splash.Dispose()
}

Write-Output 'Launcher icons and native launch images generated.'
