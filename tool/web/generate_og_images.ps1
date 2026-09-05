# Generate 1200x630 OG preview PNGs for Aura's social unfurls.
#
# Run from the repository root (one directory above aura_final/):
#   powershell -ExecutionPolicy Bypass -File aura_final/tool/web/generate_og_images.ps1
#
# Output: aura_final/web/social/og-default.png, og-investors.png,
# og-mission.png, og-founder.png. These are committed as static assets;
# the Docker build does NOT regenerate them.
#
# -OutDir writes somewhere else instead, so a copy change can be rendered and
# looked at before it replaces a committed card. The script rewrites all four
# every run, and three of them were already out of step with what is committed
# -- rendering blind would have quietly changed cards nobody asked about.

param([string]$OutDir)

Add-Type -AssemblyName System.Drawing

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$assetsDir = if ($OutDir) { $OutDir } else { Join-Path $repoRoot 'aura_final\web\social' }
$markPath = Join-Path $repoRoot 'aura_final\web\icons\Icon-512.png'

New-Item -ItemType Directory -Force $assetsDir | Out-Null

$bgNavy   = [System.Drawing.Color]::FromArgb(26, 26, 46)   # #1A1A2E
$gold     = [System.Drawing.Color]::FromArgb(201, 165, 92) # #C9A55C
$white    = [System.Drawing.Color]::FromArgb(255, 255, 255)
$lightDim = [System.Drawing.Color]::FromArgb(210, 210, 225)
$dim      = [System.Drawing.Color]::FromArgb(165, 165, 185)

function New-Og {
  param(
    [string]$OutFile,
    [string]$Headline,
    [string]$Subline
  )

  $w = 1200
  $h = 630
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g   = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.Clear($bgNavy)

  # ── Top zone: mark + brand name ─────────────────────────────────
  $mark = [System.Drawing.Image]::FromFile($markPath)
  try {
    $g.DrawImage($mark, 72, 64, 96, 96)
  } finally {
    $mark.Dispose()
  }

  $brandFont = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Regular)
  $brandBrush = New-Object System.Drawing.SolidBrush($lightDim)
  $g.DrawString('Aura Platform', $brandFont, $brandBrush, [single]188, [single]96)
  $brandFont.Dispose(); $brandBrush.Dispose()

  # ── Center zone: headline + subline (wrapped in rectangles) ─────
  $headlineFont  = New-Object System.Drawing.Font('Segoe UI', 56, [System.Drawing.FontStyle]::Bold)
  $headlineBrush = New-Object System.Drawing.SolidBrush($white)
  $headlineRect  = New-Object System.Drawing.RectangleF([single]72, [single]205, [single]($w - 144), [single]200)
  $sfHead = New-Object System.Drawing.StringFormat
  $sfHead.Trimming = [System.Drawing.StringTrimming]::Word
  $g.DrawString($Headline, $headlineFont, $headlineBrush, $headlineRect, $sfHead)
  $headlineFont.Dispose(); $headlineBrush.Dispose()

  $subFont  = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Regular)
  $subBrush = New-Object System.Drawing.SolidBrush($lightDim)
  $subRect  = New-Object System.Drawing.RectangleF([single]72, [single]430, [single]($w - 144), [single]120)
  $sfSub = New-Object System.Drawing.StringFormat
  $sfSub.Trimming = [System.Drawing.StringTrimming]::Word
  $g.DrawString($Subline, $subFont, $subBrush, $subRect, $sfSub)
  $subFont.Dispose(); $subBrush.Dispose()

  # ── Bottom: gold rule + footer ──────────────────────────────────
  $rulePen = New-Object System.Drawing.Pen($gold, 2)
  $g.DrawLine($rulePen, 72, 558, $w - 72, 558)
  $rulePen.Dispose()

  $footerFont  = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Regular)
  $footerBrush = New-Object System.Drawing.SolidBrush($dim)
  $g.DrawString('Aura Platform LLC', $footerFont, $footerBrush, [single]72, [single]578)

  $right = 'auraplatform.org'
  $rightSize = $g.MeasureString($right, $footerFont)
  $g.DrawString($right, $footerFont, $footerBrush, [single]($w - $rightSize.Width - 72), [single]578)
  $footerFont.Dispose(); $footerBrush.Dispose()

  $bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()

  Write-Host "Wrote $OutFile"
}

# Use [char]0x2014 for an em dash so PowerShell 5.1's source encoding
# (which can mojibake literal — when this file isn't UTF-8 with BOM)
# does not corrupt the rendered text.
$emdash = [char]0x2014

# THE DEFAULT CARD IS AURA'S GENERAL IDENTITY, SO IT FOLLOWS THE CANON.
#
# This card is what every share without an image of its own unfurls as -- every
# article, post, announcement and profile that has no cover. It is the single
# most-seen statement of what Aura is, and it was three versions behind.
#
# Committed PNG (rendered before 2026-05-21): "Accountable public discourse." /
# "Institutional communication infrastructure..." -- what the founder saw on
# Facebook and LinkedIn on 2026-09-05 and called legacy.
#
# This script (until now): a third, institution-first headline again -- so the
# file on disk was not even what this generator produced. That headline is
# named verbatim in the public-first causal gate's prohibited map and is not
# repeated here, because the gate now scans this file and would flag the
# sentence describing its own removal. The gate never scanned it before, which
# is exactly why the phrase survived every correction around it.
#
# Canon: representation/inventory/PRODUCT_IDENTITY_CANON.md, Aura > Identity,
# and the matching public-first correction already carried in
# aura_final/web/index.html. Both lines below are lifted from those, not
# composed here -- a card that paraphrases the canon is a fifth wording.
New-Og `
  -OutFile (Join-Path $assetsDir 'og-default.png') `
  -Headline 'Public-first civic discourse.' `
  -Subline 'People take part in purposeful communication that keeps its context. Institutions enter under clear identity, accountable for what they say officially.'

New-Og `
  -OutFile (Join-Path $assetsDir 'og-investors.png') `
  -Headline 'Investors & Partners' `
  -Subline ('Trust. Action. Records. One identity, one record, one accountable surface ' + $emdash + ' the Aura Platform thesis.')

New-Og `
  -OutFile (Join-Path $assetsDir 'og-mission.png') `
  -Headline 'Mission' `
  -Subline 'Build the durable substrate institutions run on, in an era where capability is abundant and continuity is scarce.'

New-Og `
  -OutFile (Join-Path $assetsDir 'og-founder.png') `
  -Headline 'Founder' `
  -Subline 'Operator-builder background. Building infrastructure where identity, action, and records stay connected.'
