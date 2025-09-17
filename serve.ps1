param(
    [string]$Root = "C:\Users\Maitray\Desktop\448Plumbing\448 Plumbing website",
    [int]$Port = 8000
)

Write-Host "Serving folder: $Root on http://localhost:$Port/ (Ctrl+C to stop)"

Add-Type -AssemblyName System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
} catch {
    Write-Error "Failed to start listener on $prefix. Try using a different port or run PowerShell as Administrator. $_"
    exit 1
}

function Get-ContentType($path) {
    switch -regex ([System.IO.Path]::GetExtension($path).ToLower()) {
        "\.html$" { 'text/html; charset=utf-8'; break }
        "\.htm$"  { 'text/html; charset=utf-8'; break }
        "\.css$"  { 'text/css'; break }
        "\.js$"   { 'application/javascript'; break }
        "\.json$" { 'application/json'; break }
        "\.png$"  { 'image/png'; break }
        "\.jpg$"  { 'image/jpeg'; break }
        "\.jpeg$" { 'image/jpeg'; break }
        "\.gif$"  { 'image/gif'; break }
        "\.svg$"  { 'image/svg+xml'; break }
        "\.webp$" { 'image/webp'; break }
        default { 'application/octet-stream' }
    }
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $localPath = $request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrEmpty($localPath)) {
            $localPath = 'index.html'
        }
        # Map URL path to file path under Root
        $filePath = Join-Path -Path $Root -ChildPath $localPath

        # If the exact path does not exist, attempt friendly fallbacks:
        # 1. If request path (w/o trailing slash) corresponds to a directory, serve its index.html
        # 2. If path ends with .html but that is actually a directory name ( like services.html/ ), look inside it for index.html
        # 3. If extensionless path requested (e.g. /services or /services/), try services/index.html OR services.html/index.html
        # 4. If user requested something.html and file doesn't exist but a directory something.html\index.html exists, serve that

        function Resolve-FriendlyPath([string]$root, [string]$requested, [string]$fullCandidate) {
            # Returns a tuple-like hashtable @{ Path = <resolved or $null>; Reason = <string> }
            if (Test-Path $fullCandidate -PathType Leaf) {
                return @{ Path = $fullCandidate; Reason = 'exact match' }
            }
            $baseNoSlash = $requested.TrimEnd('/')
            $candidateDir = Join-Path $root $baseNoSlash
            # Case: directory exists (with or without trailing slash) containing index.html
            if (Test-Path $candidateDir -PathType Container) {
                $indexFile = Join-Path $candidateDir 'index.html'
                if (Test-Path $indexFile -PathType Leaf) {
                    return @{ Path = $indexFile; Reason = 'directory index' }
                }
            }
            # Case: requested ends with .html but is actually a directory name containing index.html
            if ($baseNoSlash.EndsWith('.html', [System.StringComparison]::OrdinalIgnoreCase)) {
                $dirLike = Join-Path $root $baseNoSlash
                if (Test-Path $dirLike -PathType Container) {
                    $indexInside = Join-Path $dirLike 'index.html'
                    if (Test-Path $indexInside -PathType Leaf) { return @{ Path = $indexInside; Reason = 'html-named directory index' } }
                }
            } else {
                # Extensionless: try path/index.html
                $extlessDir = Join-Path $root $baseNoSlash
                if (Test-Path $extlessDir -PathType Container) {
                    $extlessIndex = Join-Path $extlessDir 'index.html'
                    if (Test-Path $extlessIndex -PathType Leaf) { return @{ Path = $extlessIndex; Reason = 'extensionless directory index' } }
                }
                # Try adding .html then looking for directory .html/index.html (our site pattern)
                $htmlDir = Join-Path $root ($baseNoSlash + '.html')
                if (Test-Path $htmlDir -PathType Container) {
                    $htmlDirIndex = Join-Path $htmlDir 'index.html'
                    if (Test-Path $htmlDirIndex -PathType Leaf) { return @{ Path = $htmlDirIndex; Reason = 'implied .html directory index' } }
                }
                # Try adding .html file directly
                $htmlFile = Join-Path $root ($baseNoSlash + '.html')
                if (Test-Path $htmlFile -PathType Leaf) { return @{ Path = $htmlFile; Reason = 'implicit .html file' } }
            }
            return @{ Path = $null; Reason = 'unresolved' }
        }

        $resolved = Resolve-FriendlyPath -root $Root -requested $localPath -fullCandidate $filePath
        if ($resolved.Path) {
            $filePath = $resolved.Path
            # Optional verbose logging for debugging
            Write-Host "[200] $($request.HttpMethod) $($request.RawUrl) -> $filePath ($($resolved.Reason))"
        }
        # Prevent directory traversal
        $fullRoot = [System.IO.Path]::GetFullPath($Root)
        $fullFile = $null
        try { $fullFile = [System.IO.Path]::GetFullPath($filePath) } catch { $fullFile = $null }
        if (-not $fullFile -or -not $fullFile.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $context.Response.StatusCode = 403
            $buffer = [System.Text.Encoding]::UTF8.GetBytes('403 Forbidden')
            $context.Response.OutputStream.Write($buffer,0,$buffer.Length)
            $context.Response.Close()
            continue
        }
        if (-not (Test-Path $fullFile -PathType Leaf)) {
            # Final attempt: if path without trailing slash is a directory containing index.html
            $maybeDir = $filePath.TrimEnd('/','\\')
            if (Test-Path $maybeDir -PathType Container) {
                $maybeIndex = Join-Path $maybeDir 'index.html'
                if (Test-Path $maybeIndex -PathType Leaf) {
                    $fullFile = [System.IO.Path]::GetFullPath($maybeIndex)
                }
            }
            if (-not (Test-Path $fullFile -PathType Leaf)) {
                Write-Host "[404] $($request.HttpMethod) $($request.RawUrl)"
                $context.Response.StatusCode = 404
                $buf = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
                $context.Response.OutputStream.Write($buf,0,$buf.Length)
                $context.Response.Close()
                continue
            }
        }

        $bytes = [System.IO.File]::ReadAllBytes($fullFile)
        $contentType = Get-ContentType $fullFile
        $context.Response.ContentType = $contentType
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.OutputStream.Close()
    } catch [System.Net.HttpListenerException] {
        # Listener stopped or interrupted
        break
    } catch {
        Write-Warning "Server error: $_"
    }
}

$listener.Stop()
$listener.Close()
Write-Host "Server stopped."