# Renders the Blokrush launcher icon motif deterministically at exact pixel
# sizes via .NET's System.Drawing (GDI+) — no image editor, no external
# tooling, matching the repo's no-build-step ethos the same way the vector
# XML does. Deviates from docs/mobile-migration.md Phase 4's suggested
# "throwaway HTML page + browser capture" approach: this generator has no
# browser-chrome/scrollbar cropping to get pixel-exact, and pixel dimensions
# are verified programmatically afterward instead of by eye.
#
# The geometry mirrors ../app/src/main/res/drawable/ic_launcher_foreground.xml
# exactly (same 108x108 unit coordinates) — that file is the source of truth
# for the adaptive icon (API 26+); this script exists only for the surfaces
# adaptive icons don't cover: the legacy per-density PNG mipmaps required for
# API 24-25, and the flat 512x512 Play Store icon. Re-run after any change to
# the vector XML's geometry or palette to keep them in sync.
#
# Usage: powershell -File render-icon.ps1
Add-Type -AssemblyName System.Drawing

function New-BlokrushIcon {
    param(
        [int]$Size,
        [string]$OutPath
    )

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $scale = $Size / 108.0

    # void background (index.html's --bg-void, index.html:23)
    $void = [System.Drawing.Color]::FromArgb(255, 0x0a, 0x01, 0x18)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($void)), 0, 0, $Size, $Size)

    function Fill-Ellipse($cx, $cy, $r, $argb) {
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(
            $argb[0], $argb[1], $argb[2], $argb[3]))
        $d = 2 * $r * $scale
        $g.FillEllipse($brush, ($cx - $r) * $scale, ($cy - $r) * $scale, $d, $d)
        $brush.Dispose()
    }

    function Fill-RoundRect($x, $y, $w, $h, $r, $argb) {
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(
            $argb[0], $argb[1], $argb[2], $argb[3]))
        $px = $x * $scale; $py = $y * $scale; $pw = $w * $scale; $ph = $h * $scale; $pr = $r * $scale * 2
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc($px, $py, $pr, $pr, 180, 90)
        $path.AddArc($px + $pw - $pr, $py, $pr, $pr, 270, 90)
        $path.AddArc($px + $pw - $pr, $py + $ph - $pr, $pr, $pr, 0, 90)
        $path.AddArc($px, $py + $ph - $pr, $pr, $pr, 90, 90)
        $path.CloseFigure()
        $g.FillPath($brush, $path)
        $brush.Dispose()
        $path.Dispose()
    }

    # glow rings (ball, lime, alpha 0.22 / 0.35)
    Fill-Ellipse 54 66 18 @(56, 0x9d, 0xff, 0x1e)   # 0.22 * 255 ~= 56
    Fill-Ellipse 54 66 14 @(89, 0x9d, 0xff, 0x1e)   # 0.35 * 255 ~= 89

    # bricks
    Fill-RoundRect 18 30 20 14 3 @(255, 0x2d, 0xe2, 0xe6)   # cyan
    Fill-RoundRect 44 30 20 14 3 @(255, 0xff, 0x2e, 0x88)   # magenta
    Fill-RoundRect 70 30 20 14 3 @(255, 0xff, 0xb6, 0x27)   # amber

    # ball
    Fill-Ellipse 54 66 11 @(255, 0x9d, 0xff, 0x1e)

    # paddle
    Fill-RoundRect 34 80 40 6 3 @(255, 0xc3, 0xce, 0xe0)

    $g.Dispose()
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "wrote $OutPath ($Size x $Size)"
}

$targets = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}

$resRoot = Join-Path $PSScriptRoot "..\app\src\main\res"
foreach ($dir in $targets.Keys) {
    $outDir = Join-Path $resRoot $dir
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    New-BlokrushIcon -Size $targets[$dir] -OutPath (Join-Path $outDir "ic_launcher.png")
    New-BlokrushIcon -Size $targets[$dir] -OutPath (Join-Path $outDir "ic_launcher_round.png")
}

# Play Store 512x512 icon (same motif, full res)
New-BlokrushIcon -Size 512 -OutPath (Join-Path $PSScriptRoot "play-icon-512.png")
