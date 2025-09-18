param(
    [string]$Root = "C:\Users\Maitray\Desktop\448Plumbing\448 Plumbing website",
    [string]$Dist = "C:\workspace\site\dist",
    [switch]$DryRun = $true,
    [string]$BaseUrl = ""
)

function Write-Log { param($m) Write-Host "[build] $m" }

Write-Log "Root: $Root"
Write-Log "Dist: $Dist"
if (-not (Test-Path $Root)) { Write-Error "Root path not found: $Root"; exit 1 }

if ($DryRun) { Write-Log "DryRun enabled - no files will be changed. Use -DryRun:$false to perform the build." }

# Create dist folder
if (Test-Path $Dist) { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Dist }
if (-not $DryRun) { New-Item -ItemType Directory -Path $Dist | Out-Null }

# Copy static files (selective)
$includeExtensions = @('*.html','*.htm','*.css','*.js','*.png','*.jpg','*.jpeg','*.gif','*.svg','*.webp','*.ico','*.json')
Write-Log "Collecting files to copy..."
$files = @()
foreach ($ext in $includeExtensions) {
    $files += Get-ChildItem -Path $Root -Recurse -Include $ext -File -ErrorAction SilentlyContinue
}
$files = $files | Sort-Object FullName -Unique
Write-Log "Found $($files.Count) files to copy."

$rootFull = (Get-Item $Root).FullName
foreach ($f in $files) {
    $full = (Get-Item -LiteralPath $f.FullName).FullName
    $rel = [System.IO.Path]::GetRelativePath($rootFull, $full)
    # Normalize any accidental backslashes to the platform separator for consistency
    if ([System.IO.Path]::DirectorySeparatorChar -eq '/') { $rel = ($rel -replace '\\','/') } else { $rel = ($rel -replace '/','\') }
    $dest = Join-Path -Path $Dist -ChildPath $rel
    $destDir = Split-Path -Parent $dest
    if (-not $DryRun) {
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    }
}

# Minify CSS and JS (simple rules)
if (-not $DryRun) {
    Write-Log "Minifying CSS and JS files..."
    Get-ChildItem -Path $Dist -Recurse -Include '*.css' -File | ForEach-Object {
        try {
            $txt = Get-Content -Raw -LiteralPath $_.FullName
            # remove /* */ comments
            $txt = [regex]::Replace($txt, '/\*.*?\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            # collapse whitespace
            $txt = [regex]::Replace($txt, '\s+', ' ')
            Set-Content -LiteralPath $_.FullName -Value $txt -Force
        } catch { Write-Warning "Failed to minify CSS: $($_.FullName) - $_" }
    }
    Get-ChildItem -Path $Dist -Recurse -Include '*.js' -File | ForEach-Object {
        try {
            $txt = Get-Content -Raw -LiteralPath $_.FullName
            # remove /* */ comments and // comments
            $txt = [regex]::Replace($txt, '/\*.*?\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            $txt = [regex]::Replace($txt, '//.*?$','', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            $txt = [regex]::Replace($txt, '\s+', ' ')
            Set-Content -LiteralPath $_.FullName -Value $txt -Force
        } catch { Write-Warning "Failed to minify JS: $($_.FullName) - $_" }
    }
}

# Strip HTML comments (light) and optionally collapse whitespace between tags
if (-not $DryRun) {
    Write-Log "Cleaning HTML files..."
    Get-ChildItem -Path $Dist -Recurse -Include '*.html','*.htm' -File | ForEach-Object {
        try {
            $txt = Get-Content -Raw -LiteralPath $_.FullName
            $txt = [regex]::Replace($txt, '<!--.*?-->', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            # collapse multiple blank lines
            $txt = [regex]::Replace($txt, '\n\s*\n', "`n")
            Set-Content -LiteralPath $_.FullName -Value $txt -Force
        } catch { Write-Warning "Failed to clean HTML: $($_.FullName) - $_" }
    }

    # Create directory aliases so /page/ works in addition to /page.html
    $rootHtml = Get-ChildItem -Path $Dist -File -Filter *.html -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'index.html' }
    foreach ($page in $rootHtml) {
        try {
            $name = [System.IO.Path]::GetFileNameWithoutExtension($page.Name)
            $aliasDir = Join-Path $Dist $name
            if (-not (Test-Path $aliasDir)) { New-Item -ItemType Directory -Path $aliasDir | Out-Null }
            $aliasIndex = Join-Path $aliasDir 'index.html'
            Copy-Item -LiteralPath $page.FullName -Destination $aliasIndex -Force
        } catch { Write-Warning "Failed to create alias for $($page.Name): $_" }
    }
}

# Generate sitemap.xml if BaseUrl provided
if (-not [string]::IsNullOrEmpty($BaseUrl) -and -not $DryRun) {
    Write-Log "Generating sitemap.xml with base URL: $BaseUrl"
    $distFull = (Get-Item $Dist).FullName
    $urls = Get-ChildItem -Path $Dist -Recurse -Include '*.html','*.htm' -File | ForEach-Object {
        $relPath = [System.IO.Path]::GetRelativePath($distFull, ($_.FullName))
        $rel = ($relPath -replace '\\','/')
        if ($rel -eq 'index.html') { $loc = $BaseUrl.TrimEnd('/') + '/' } else { $loc = $BaseUrl.TrimEnd('/') + '/' + $rel }
        "  <url><loc>$loc</loc></url>"
    }
    $sitemapPath = Join-Path -Path $Dist -ChildPath 'sitemap.xml'
    $body = $urls -join "`n"
    $sitemap = @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$body
</urlset>
"@
    Set-Content -LiteralPath $sitemapPath -Value $sitemap -Force
}

# Write robots.txt
if (-not $DryRun) {
    $robots = "User-agent: *`nAllow: /`nSitemap: " + ([string]::IsNullOrEmpty($BaseUrl) ? '' : ($BaseUrl.TrimEnd('/') + '/sitemap.xml'))
    Set-Content -LiteralPath (Join-Path $Dist 'robots.txt') -Value $robots -Force
}

# Zip the dist for convenience
$zipPath = Join-Path -Path (Split-Path -Parent $Dist) -ChildPath "site-dist-$(Get-Date -Format yyyyMMdd-HHmmss).zip"
if (-not $DryRun) {
    Write-Log "Creating ZIP: $zipPath"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($Dist, $zipPath)
    Write-Log "ZIP created: $zipPath"
}

Write-Log "Build finished."