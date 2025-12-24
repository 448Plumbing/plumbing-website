param(
    [string]$Root = ".",
    [string]$BaseUrl = "",
    [switch]$DryRun = $false,
    [string]$OutputPath = "seo-report.json"
)

$ErrorActionPreference = "Stop"

function Write-Log { param($m) Write-Host "[seo-enhance] $m" }

$rootItem = Get-Item $Root
Write-Log "Root: $($rootItem.FullName)"

# Normalize BaseUrl if provided
if (-not [string]::IsNullOrWhiteSpace($BaseUrl)) {
    try {
        $uri = [Uri]$BaseUrl
        $BaseUrl = ($uri.Scheme + '://' + $uri.Host.ToLowerInvariant()).TrimEnd('/') + '/'
    } catch {
        $BaseUrl = $BaseUrl.TrimEnd('/') + '/'
    }
}

$files = Get-ChildItem -Path $rootItem.FullName -Recurse -Include '*.html','*.htm' -File |
    Where-Object {
        $_.FullName -notlike "*\dist\*" -and
        $_.FullName -notlike "*\desktop-site\webstie building install*"
    }

Write-Log "Found $($files.Count) HTML pages to summarize."

$rootLen = $rootItem.FullName.Length
$pages = @()

foreach ($f in $files) {
    $rel = $f.FullName.Substring($rootLen).TrimStart('\\') -replace '\\','/'
    $url = $null
    if (-not [string]::IsNullOrWhiteSpace($BaseUrl)) {
        if ($rel -eq "index.html") {
            $url = $BaseUrl
        } else {
            $url = $BaseUrl.TrimEnd('/') + '/' + $rel
        }
    }

    $title = $null
    $description = $null

    try {
        $html = Get-Content -LiteralPath $f.FullName -Raw
        if ($html -match '<title>(.*?)</title>') {
            $title = $Matches[1].Trim()
        }
        if ($html -match '<meta[^>]+name="description"[^>]*content="(.*?)"[^"]*>') {
            $description = $Matches[1].Trim()
        }
    } catch {
        Write-Warning "Failed to inspect HTML for $($f.FullName): $_"
    }

    $pages += [pscustomobject]@{
        File        = $f.FullName
        Relative    = $rel
        Url         = $url
        Title       = $title
        Description = $description
    }
}

$data = [ordered]@{
    RunDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ssK")
    Root    = $Root
    BaseUrl = $BaseUrl
    DryRun  = [bool]$DryRun
    Pages   = $pages
}

$json = $data | ConvertTo-Json -Depth 5

if (-not $DryRun) {
    $outPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $rootItem.FullName $OutputPath }
    Write-Log "Writing SEO report to $outPath"
    Set-Content -LiteralPath $outPath -Value $json -Encoding UTF8
} else {
    Write-Log "DryRun enabled - not writing $OutputPath"
}

Write-Log "SEO summarization complete."