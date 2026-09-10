param(
    [string]$Root = ".",
    [string]$Dist = "",
    [switch]$DryRun = $true,
    [string]$BaseUrl = "https://www.448plumbing.com"
)
$ErrorActionPreference = "Stop"
$rootPath = (Get-Item -LiteralPath $Root).FullName
if ([string]::IsNullOrWhiteSpace($Dist)) { $Dist = Join-Path $rootPath 'dist' }
$distPath = [IO.Path]::GetFullPath($Dist)
if ($distPath -eq $rootPath) { throw 'Dist must differ from the source directory.' }
$baseUri = [Uri]$BaseUrl
$base = ($baseUri.Scheme + '://' + $baseUri.Host.ToLowerInvariant()).TrimEnd('/')

# Publish only website files. Reports, build logs and source tooling stay private to the repo.
$files = @(Get-ChildItem -LiteralPath $rootPath -File | Where-Object { $_.Extension -in @('.html', '.htm') })
foreach ($folder in @('assets', 'blog', 'partials')) {
    $path = Join-Path $rootPath $folder
    if (Test-Path -LiteralPath $path) {
        $files += Get-ChildItem -LiteralPath $path -Recurse -File | Where-Object {
            $_.Extension -in @('.html','.htm','.css','.js','.png','.jpg','.jpeg','.gif','.svg','.webp','.ico','.woff','.woff2') -and
            $_.Name -ne 'tailwind-input.css'
        }
    }
}
if ($DryRun) { Write-Host "[build] Would publish $($files.Count) files to $distPath"; return }
# GitHub's runner has npx; regenerate utilities for future HTML edits.
# Local previews may use the checked-in CSS when Node/npm is unavailable.
$npxCommand = Get-Command npx -ErrorAction SilentlyContinue
if ($npxCommand) {
    Push-Location $rootPath
    try {
        & $npxCommand.Source --yes tailwindcss@3.4.17 -i assets/tailwind-input.css -o assets/utilities.css --content './*.html,./partials/*.html,./blog/*.html,./assets/*.js' --minify
        if ($LASTEXITCODE -ne 0) { throw 'Tailwind CSS generation failed.' }
    } finally { Pop-Location }
} elseif (-not (Test-Path -LiteralPath (Join-Path $rootPath 'assets/utilities.css'))) {
    throw 'Generate assets/utilities.css before building without npm.'
}
if (Test-Path -LiteralPath $distPath) { Remove-Item -LiteralPath $distPath -Recurse -Force }
New-Item -ItemType Directory -Path $distPath -Force | Out-Null
$header = Get-Content -LiteralPath (Join-Path $rootPath 'partials/header.html') -Raw
$footer = Get-Content -LiteralPath (Join-Path $rootPath 'partials/footer.html') -Raw

foreach ($file in $files) {
    $relative = [IO.Path]::GetRelativePath($rootPath, $file.FullName)
    $destination = Join-Path $distPath $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    if ($file.Extension -in @('.html','.htm') -and $relative -notmatch '^partials[\\/]') {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $content = $content.Replace('<div id="site-header"></div>', '<div id="site-header">' + $header + '</div>')
        $content = $content.Replace('<div id="site-footer"></div>', '<div id="site-footer">' + $footer + '</div>')
        # A working fallback when JavaScript is disabled: show navigation and leave contact links usable.
        $content = $content.Replace('</head>', '<noscript><style>#mobileMenu{display:block !important}#mobileMenuBtn,[data-analytics-settings]{display:none !important}</style></noscript></head>')
        Set-Content -LiteralPath $destination -Value $content -Encoding utf8
    } else {
        # Do not regex-minify JS: strings and regular expressions can contain comment-like text.
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    }
}
Set-Content -LiteralPath (Join-Path $distPath 'CNAME') -Value $baseUri.Host.ToLowerInvariant() -Encoding ascii

# Include only real, indexable pages; never headers, footers, redirects or thank-you/404 pages.
$urls = foreach ($file in Get-ChildItem -LiteralPath $distPath -Recurse -Filter '*.html' -File) {
    $relative = [IO.Path]::GetRelativePath($distPath, $file.FullName).Replace('\','/')
    if ($relative -match '^(partials|assets)/') { continue }
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match '<meta[^>]+name="robots"[^>]+content="[^"]*noindex' -or $content -match '<meta[^>]+http-equiv="refresh"') { continue }
    if ($relative -eq 'index.html') { "$base/" } else { "$base/$relative" }
}
$lines = @('<?xml version="1.0" encoding="UTF-8"?>','<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
foreach ($url in ($urls | Sort-Object -Unique)) { $lines += '  <url><loc>' + [Security.SecurityElement]::Escape($url) + '</loc></url>' }
$lines += '</urlset>'
$lines | Set-Content -LiteralPath (Join-Path $distPath 'sitemap.xml') -Encoding utf8
"User-agent: *`nAllow: /`nSitemap: $base/sitemap.xml" | Set-Content -LiteralPath (Join-Path $distPath 'robots.txt') -Encoding utf8
Write-Host "[build] Published $($files.Count) files; $(@($urls).Count) indexable pages."
