# start-server.ps1
# Robust starter for a Python HTTP server for the site folder.
# Usage: Right-click -> Run with PowerShell, or from PowerShell run:
#   powershell -ExecutionPolicy Bypass -File .\start-server.ps1

# Resolve the folder where this script lives
$scriptPath = $MyInvocation.MyCommand.Definition
$siteFolder = Split-Path -Path $scriptPath -Parent
Set-Location -Path $siteFolder

Write-Host "Starting preview server from: $siteFolder" -ForegroundColor Green

# Helper to try a command and return boolean
function Try-Command([string]$cmd, [string[]]$args) {
    try {
        $proc = Start-Process -FilePath $cmd -ArgumentList $args -NoNewWindow -PassThru -ErrorAction Stop
        return $proc
    } catch {
        return $null
    }
}

# Prefer to launch server in a new PowerShell window so logs are visible
$serverCommand = {
    param($siteFolder)
    Set-Location -Path $siteFolder
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Write-Host "Using 'python' from PATH" -ForegroundColor Yellow
        python -m http.server 8000 --bind 127.0.0.1
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        Write-Host "Using 'py -3' launcher" -ForegroundColor Yellow
        py -3 -m http.server 8000 --bind 127.0.0.1
    } else {
        Write-Host "Python not found. Please install Python 3 and enable 'Add to PATH' during install." -ForegroundColor Red
        Write-Host "Manual commands you can run once Python is installed:" -ForegroundColor Cyan
        Write-Host "  python -m http.server 8000 --bind 127.0.0.1"
        Write-Host "  OR"
        Write-Host "  py -3 -m http.server 8000 --bind 127.0.0.1"
        Pause
    }
}

# Build a command line for a new window that runs PowerShell and starts the server
$escapedSite = $siteFolder -replace "'","''"
$inner = "Set-Location -LiteralPath '$escapedSite' ; `nif (Get-Command python -ErrorAction SilentlyContinue) { Write-Host 'Starting python server...' ; python -m http.server 8000 --bind 127.0.0.1 } elseif (Get-Command py -ErrorAction SilentlyContinue) { Write-Host 'Starting py -3 server...' ; py -3 -m http.server 8000 --bind 127.0.0.1 } else { Write-Host 'Python not found in this environment.' ; Pause }"

Start-Process -FilePath powershell -ArgumentList ('-NoExit', '-Command', $inner)

# Open browser to the local URL (won't guarantee server ready but helps)
Start-Sleep -Seconds 1
try {
    Start-Process "http://127.0.0.1:8000"
} catch {
    Write-Host "Could not open the browser automatically. Open http://127.0.0.1:8000 manually." -ForegroundColor Yellow
}

Write-Host "If the new window reports 'Address already in use', try changing the port to 8080 or another free port." -ForegroundColor Cyan
Write-Host "If Python isn't found, install Python 3 from https://python.org and ensure 'Add to PATH' is checked." -ForegroundColor Cyan
