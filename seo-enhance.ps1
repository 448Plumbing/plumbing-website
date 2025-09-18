param(
    [string]$Root = "C:\Users\Maitray\Desktop\448Plumbing\448 Plumbing website",
    [string]$BaseUrl = "https://example.com/",
    [switch]$DryRun,
    [switch]$Flatten,
    [switch]$Verbose
)

<#!
.SYNOPSIS
  Apply consistent SEO enhancements (canonical, meta description, Open Graph, Twitter card) to every page directory containing an index.html.
  The site uses a directory-per-page pattern (e.g. services.html\index.html). This script normalizes head tags, fixes copyright symbol, and
  trims duplicate appended HTML after the first closing </html> which arose from prior patch concatenations.

.PARAMETER Root
  Root folder of the site (contains directories like services.html, about.html, index.html, etc.).

.PARAMETER BaseUrl
  Absolute production base URL (with or without trailing slash). Example: https://448plumbing.com/

.PARAMETER DryRun
  If set, shows planned changes without writing files.

.PARAMETER Flatten
  If set, creates flattened .html files at the root (e.g. services.html directory's index.html copied to services.html file) for simpler static hosting.
  Existing root files are not overwritten unless their content differs and backup is taken.

.OUTPUTS
  Writes seo-report.json (unless DryRun) summarizing actions.

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message,[string]$Level = 'INFO')
    $ts = (Get-Date).ToString('u')
    Write-Host "[$ts][$Level] $Message"
}

if (-not (Test-Path $Root -PathType Container)) {
    Write-Error "Root path not found: $Root"; exit 1
}

# Normalize BaseUrl -> ensure trailing slash
if (-not $BaseUrl.EndsWith('/')) { $BaseUrl += '/' }

$backupDir = Join-Path $Root 'SEOBackup'
if (-not $DryRun -and -not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }

$pageDirs = Get-ChildItem -LiteralPath $Root -Directory | Where-Object { $_.Name -match '\.html$' }
# Include root index (directory named index.html) if present
$allTargets = @()
if (Test-Path (Join-Path $Root 'index.html') -PathType Container) {
    $allTargets += (Get-Item (Join-Path $Root 'index.html'))
}
$allTargets += $pageDirs | Sort-Object -Property Name -Unique

$report = @()

function Ensure-Tag {
    param(
        [string]$HeadContent,
        [string]$Pattern,
        [string]$Insertion
    )
    if ($HeadContent -notmatch $Pattern) { return $HeadContent + "`n    $Insertion" } else { return $HeadContent }
}

foreach ($dir in $allTargets) {
    $indexPath = Join-Path $dir.FullName 'index.html'
    if (-not (Test-Path $indexPath -PathType Leaf)) { continue }
    $original = Get-Content -LiteralPath $indexPath -Raw
    $origHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $indexPath).Hash

    $actions = @()

    # Trim after first closing </html>
    $closeIdx = $original.IndexOf('</html>', [System.StringComparison]::OrdinalIgnoreCase)
    if ($closeIdx -ge 0) {
        $endIdx = $closeIdx + 7
        if ($original.Length -gt $endIdx) {
            $original = $original.Substring(0,$endIdx)
            $actions += 'trim-extra-after-html'
        }
    }

    # Ensure UTF8 normalized newlines
    $content = $original -replace '\r\n?', "`n"

    # Basic parse: isolate <head> ... </head>
    $headPattern = '(?is)(<head[^>]*>)(.*?)(</head>)'
    $headMatch = [Regex]::Match($content, $headPattern)
    if (-not $headMatch.Success) {
        Write-Log "No <head> found in $indexPath" 'WARN'
        continue
    }
    $headOpen = $headMatch.Groups[1].Value
    $headBody = $headMatch.Groups[2].Value.TrimEnd()
    $headClose = $headMatch.Groups[3].Value

    # Derive page key and canonical
    $pageKey = $dir.Name # e.g. services.html
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($pageKey) # services
    if ($pageKey -ieq 'index.html') {
        $canonical = $BaseUrl
    } else {
        $canonical = "$BaseUrl$baseName/"
    }

    # Title extraction
    $titleMatch = [Regex]::Match($headBody, '(?is)<title>(.*?)</title>')
    if ($titleMatch.Success) {
        $title = ($titleMatch.Groups[1].Value -replace '\s+', ' ').Trim()
    } else {
        $title = "${baseName} | 448 Plumbing"
    }

    # Simple description heuristic
    $desc = 'Professional plumbing services in the Dallas–Fort Worth area. 24/7 emergency support, licensed & insured.'
    $pMatch = [Regex]::Match($content, '(?is)<p[^>]*>(.{60,600}?)</p>')
    if ($pMatch.Success) {
        $sample = ($pMatch.Groups[1].Value -replace '<.*?>',' ' -replace '\s+',' ').Trim()
        if ($sample.Length -ge 60 -and $sample.Length -le 300) { $desc = $sample }
    }

    # OG image placeholder
    $ogImage = "$BaseUrl".TrimEnd('/') + '/assets/og-default.jpg'

    $beforeHeadBody = $headBody
    $headBody = Ensure-Tag -HeadContent $headBody -Pattern '<link[^>]+rel=["'']canonical["'']' -Insertion ('<link rel="canonical" href="{0}" />' -f $canonical)
    if ($headBody -ne $beforeHeadBody) { $actions += 'add-canonical' }

    $before = $headBody
    $headBody = Ensure-Tag -HeadContent $headBody -Pattern '<meta[^>]+name=["'']description["'']' -Insertion ('<meta name="description" content="{0}" />' -f $desc)
    if ($headBody -ne $before) { $actions += 'add-description' }

    $ogPairs = @{
        'og:title'       = $title
        'og:description' = $desc
        'og:type'        = 'website'
        'og:url'         = $canonical
        'og:image'       = $ogImage
        'twitter:card'   = 'summary_large_image'
        'twitter:title'  = $title
        'twitter:description' = $desc
        'twitter:image'  = $ogImage
    }
    foreach ($kv in $ogPairs.GetEnumerator()) {
    $prop = [Regex]::Escape($kv.Key)
    $pattern = ('<meta[^>]+(property|name)=["'']{0}["'']' -f $prop)
        $beforeOG = $headBody
        if ($kv.Key -like 'og:*') {
            $insertion = ('<meta property="{0}" content="{1}" />' -f $kv.Key, $kv.Value)
        } else {
            $insertion = ('<meta name="{0}" content="{1}" />' -f $kv.Key, $kv.Value)
        }
        $headBody = Ensure-Tag -HeadContent $headBody -Pattern $pattern -Insertion $insertion
        if ($headBody -ne $beforeOG) { $actions += "add-${($kv.Key)}" }
    }

    # Fix copyright symbol occurrences like 'c 2023' or '(c)'
    $content = $content -replace '(?i)([^&])\bc\s+20(2[4-9]|3[0-9])', '$1© 2025'
    if ($content -ne $original) { $actions += 'fix-copyright' }

    # Reassemble content with updated head (use substring to avoid regex escaping issues)
    $newHead = "$headOpen`n$headBody`n$headClose"
    $prefix = $content.Substring(0, $headMatch.Index)
    $suffixStart = $headMatch.Index + $headMatch.Length
    $suffix = $content.Substring($suffixStart)
    $content = "$prefix$newHead$suffix"

    $newHash = [System.BitConverter]::ToString(( [System.Security.Cryptography.SHA256]::Create()).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($content))) -replace '-',''

    $changed = $origHash -ne $newHash
    if ($changed -and -not $DryRun) {
        $rel = [IO.Path]::GetRelativePath($Root, $indexPath)
        $backupTarget = Join-Path $backupDir ($rel -replace '[\\/:]','_') + '.bak'
        if (-not (Test-Path $backupTarget)) { [IO.File]::WriteAllText($backupTarget, (Get-Content -LiteralPath $indexPath -Raw), [Text.UTF8Encoding]::new($false)) }
        [IO.File]::WriteAllText($indexPath, $content, [Text.UTF8Encoding]::new($false))
    }

    if ($Flatten) {
        if ($pageKey -ieq 'index.html') { $flatName = 'index.html' } else { $flatName = $pageKey }
        $flatTarget = Join-Path $Root $flatName
        $flatSrcChanged = $false
        if ($Flatten -and (Test-Path $flatTarget -PathType Leaf)) {
            $existing = Get-Content -LiteralPath $flatTarget -Raw
            if ($existing -ne $content) { $flatSrcChanged = $true }
        } elseif ($Flatten) { $flatSrcChanged = $true }
        if ($Flatten -and $flatSrcChanged -and -not $DryRun) {
            $backupFlat = Join-Path $backupDir ($flatName + '.flat.bak')
            if (Test-Path $flatTarget -PathType Leaf -and -not (Test-Path $backupFlat)) { Copy-Item -LiteralPath $flatTarget -Destination $backupFlat }
            [IO.File]::WriteAllText($flatTarget, $content, [Text.UTF8Encoding]::new($false))
            $actions += 'flatten-copy'
        }
    }

    $report += [PSCustomObject]@{
        PageDirectory = $pageKey
        Canonical     = $canonical
        Title         = $title
        Changed       = $changed
        Actions       = ($actions | Sort-Object -Unique) -join ','
    }
}

$reportSummary = [PSCustomObject]@{
    RunDate   = (Get-Date).ToString('u')
    Root      = $Root
    BaseUrl   = $BaseUrl
    DryRun    = [bool]$DryRun
    Pages     = $report
}

if ($DryRun) {
    Write-Log '--- DryRun Summary ---'
    $report | Format-Table PageDirectory, Changed, Actions
} else {
    $jsonPath = Join-Path $Root 'seo-report.json'
    $reportSummary | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Log "Report written: $jsonPath"
}

Write-Log "Processed $($report.Count) page directories." 'INFO'
