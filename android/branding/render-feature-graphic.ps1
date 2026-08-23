# Play Store feature graphic, 1024x500 (docs/mobile-migration.md Phase 4).
# Same wordmark treatment as index.html's <h1 class="title">BLOK<em>RUSH</em></h1>
# (index.html:765) — Arial Narrow Bold, BLOK in the light/cyan-glow color,
# RUSH in magenta-glow — plus an enlarged copy of the launcher motif
# (render-icon.ps1) as the accompanying art. Same "no image editor" approach
# as render-icon.ps1; see that file's header for why System.Drawing instead
# of the plan's suggested HTML-page-plus-browser-capture.
#
# Usage: powershell -File render-feature-graphic.ps1
Add-Type -AssemblyName System.Drawing

$W = 1024; $H = 500
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function C($a, $r, $gg, $b) { [System.Drawing.Color]::FromArgb($a, $r, $gg, $b) }

# Background: panel-to-void gradient, matching the marquee treatment
# (index.html: linear-gradient(180deg, --bg-panel, --bg-deep)).
$rect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect, (C 255 0x17 0x10 0x2f), (C 255 0x0a 0x01 0x18), 90)
$g.FillRectangle($grad, $rect)

# Faint scanline texture, matching .scanlines in index.html.
for ($y = 0; $y -lt $H; $y += 3) {
    $pen = New-Object System.Drawing.Pen((C 10 255 255 255), 1)
    $g.DrawLine($pen, 0, $y, $W, $y)
    $pen.Dispose()
}

$typoFmt = [System.Drawing.StringFormat]::GenericTypographic

function Draw-GlowText($text, $x, $y, $font, $glowColor, $coreColor) {
    # Poor-man's glow: the same string drawn several times at small radial
    # offsets in a dim glow color first, then crisp on top — GDI+ has no
    # blur filter, so this is the same trick the icon's ball rings use.
    # GenericTypographic drops the default format's side bearing padding, so
    # BLOK and RUSH sit flush the way index.html's single <h1> does, and so
    # MeasureString (which also uses it, below) matches what's actually drawn.
    $glowBrush = New-Object System.Drawing.SolidBrush($glowColor)
    $offsets = @(
        @(-3,0), @(3,0), @(0,-3), @(0,3), @(-2,-2), @(2,2), @(-2,2), @(2,-2),
        @(-5,0), @(5,0), @(0,-5), @(0,5)
    )
    foreach ($o in $offsets) {
        $g.DrawString($text, $font, $glowBrush, $x + $o[0], $y + $o[1], $typoFmt)
    }
    $glowBrush.Dispose()
    $coreBrush = New-Object System.Drawing.SolidBrush($coreColor)
    $g.DrawString($text, $font, $coreBrush, $x, $y, $typoFmt)
    $coreBrush.Dispose()
}

# Wordmark — BLOK (cyan glow / near-white core) + RUSH (magenta glow / white core).
$font = New-Object System.Drawing.Font("Arial Narrow", 108, [System.Drawing.FontStyle]::Bold)
$blokX = 60; $wordY = 150
Draw-GlowText "BLOK" $blokX $wordY $font (C 70 0x2d 0xe2 0xe6) (C 255 0xf2 0xee 0xfc)
$blokWidth = $g.MeasureString("BLOK", $font, [int]::MaxValue, $typoFmt).Width
Draw-GlowText "RUSH" ($blokX + $blokWidth) $wordY $font (C 80 0xff 0x2e 0x88) (C 255 0xff 0x2e 0x88)
$font.Dispose()

# Tagline, Segoe UI Semibold (index.html's --font-body fallback) — matches
# the marquee's own subhead voice without quoting index.html's actual
# localized copy verbatim.
$tagFont = New-Object System.Drawing.Font("Segoe UI Semibold", 28, [System.Drawing.FontStyle]::Regular)
$tagBrush = New-Object System.Drawing.SolidBrush((C 255 0x90 0x89 0xb8))
$g.DrawString("NEON ARCADE BREAKOUT", $tagFont, $tagBrush, $blokX + 4, $wordY + 145)
$tagFont.Dispose(); $tagBrush.Dispose()

# Decorative motif, enlarged, anchored bottom-right. Positioned from the
# content's own bounding box (x:18-90, y:30-86 in the 108-unit design, same
# as ic_launcher_foreground.xml), not the full conceptual canvas, so the
# visible art — not empty margin — is what sits 40px off each edge.
$motifScale = 2.6
$ox = $W - 40 - (90 * $motifScale)
$oy = $H - 40 - (86 * $motifScale)

function Fill-Ellipse2($cx, $cy, $r, $argb) {
    $brush = New-Object System.Drawing.SolidBrush((C $argb[0] $argb[1] $argb[2] $argb[3]))
    $d = 2 * $r * $motifScale
    $g.FillEllipse($brush, $ox + ($cx - $r) * $motifScale, $oy + ($cy - $r) * $motifScale, $d, $d)
    $brush.Dispose()
}
function Fill-RoundRect2($x, $y, $w, $h, $r, $argb) {
    $brush = New-Object System.Drawing.SolidBrush((C $argb[0] $argb[1] $argb[2] $argb[3]))
    $px = $ox + $x * $motifScale; $py = $oy + $y * $motifScale
    $pw = $w * $motifScale; $ph = $h * $motifScale; $pr = $r * $motifScale * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($px, $py, $pr, $pr, 180, 90)
    $path.AddArc($px + $pw - $pr, $py, $pr, $pr, 270, 90)
    $path.AddArc($px + $pw - $pr, $py + $ph - $pr, $pr, $pr, 0, 90)
    $path.AddArc($px, $py + $ph - $pr, $pr, $pr, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
    $brush.Dispose(); $path.Dispose()
}

Fill-Ellipse2 54 66 18 @(56, 0x9d, 0xff, 0x1e)
Fill-Ellipse2 54 66 14 @(89, 0x9d, 0xff, 0x1e)
Fill-RoundRect2 18 30 20 14 3 @(255, 0x2d, 0xe2, 0xe6)
Fill-RoundRect2 44 30 20 14 3 @(255, 0xff, 0x2e, 0x88)
Fill-RoundRect2 70 30 20 14 3 @(255, 0xff, 0xb6, 0x27)
Fill-Ellipse2 54 66 11 @(255, 0x9d, 0xff, 0x1e)
Fill-RoundRect2 34 80 40 6 3 @(255, 0xc3, 0xce, 0xe0)

$g.Dispose()
$outPath = Join-Path $PSScriptRoot "play-feature-graphic-1024x500.png"
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "wrote $outPath ($W x $H)"
