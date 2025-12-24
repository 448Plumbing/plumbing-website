param(
    [string]$Root = ".",
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$rootPath = (Resolve-Path $Root).Path
$rootPath = $rootPath.TrimEnd('\','/')

Write-Host "[serve] Serving folder: $rootPath on http://localhost:$Port/ (Ctrl+C to stop)"

Add-Type -AssemblyName System.Net.HttpListener
$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()

# Simple content-type map
$contentTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".json" = "application/json; charset=utf-8"
    ".xml"  = "application/xml; charset=utf-8"
    ".txt"  = "text/plain; charset=utf-8"
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.AbsolutePath
        if ([string]::IsNullOrEmpty($path) -or $path -eq "/") {
            $relPath = "index.html"
        } else {
            $relPath = $path.TrimStart('/')
        }

        $filePath = Join-Path $rootPath $relPath
        if (-not (Test-Path $filePath)) {
            # Try directory index
            if (-not $relPath.EndsWith(".html") -and -not $relPath.EndsWith(".htm")) {
                $filePath = Join-Path $filePath "index.html"
            }
        }

        $statusCode = 200
        if (-not (Test-Path $filePath)) {
            $statusCode = 404
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("Not Found")
            $response.StatusCode = 404
            $response.ContentType = "text/plain; charset=utf-8"
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            Write-Host "[404] GET $path -> $filePath (missing)"
        } else {
            try {
                $ext = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
                $ctype = $contentTypes[$ext]
                if (-not $ctype) { $ctype = "application/octet-stream" }

                $buffer = [System.IO.File]::ReadAllBytes($filePath)
                $response.StatusCode = 200
                $response.ContentType = $ctype
                $response.ContentLength64 = $buffer.LongLength
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                Write-Host "[200] GET $path -> $filePath (exact match)"
            } catch {
                $statusCode = 500
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("Internal Server Error")
                $response.StatusCode = 500
                $response.ContentType = "text/plain; charset=utf-8"
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                Write-Warning "[500] GET $path -> $filePath error: $_"
            }
        }

        $response.OutputStream.Flush()
        $response.Close()
    }
} finally {
    if ($listener -ne $null) {
        $listener.Stop()
        $listener.Close()
    }
}