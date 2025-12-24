param(
    [string]$Root = ".",
    [string]$BaseUrl = "https://www.448plumbing.com",
    [switch]$SkipEncodingCleanup = $false,
    [switch]$SkipSeo = $false,
    [switch]$SkipAudit = $false,
    [switch]$FailOnError = $true
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step { param($m) Write-Host "[optimize-and-build] $m" }

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    Write-Step "Starting: $Name"
    try {
        & $Action
        Write-Step "Completed: $Name"
    } catch {
        Write-Error "Step '$Name' failed: $_"
        if ($FailOnError) { throw }
    }
}

$rootItem = Get-Item $Root
Write-Step "Root: $($rootItem.FullName)"
Write-Step "BaseUrl: $BaseUrl"

if (-not $SkipEncodingCleanup) {
    $encScript = Join-Path $scriptDir 'encoding-cleanup.ps1'
    Invoke-Step "Encoding cleanup" { & $encScript -Root $Root -DryRun:$false }
}

if (-not $SkipSeo) {
    $seoScript = Join-Path $scriptDir 'seo-enhance.ps1'
    Invoke-Step "SEO enhancement" { & $seoScript -Root $Root -BaseUrl $BaseUrl -DryRun:$false -OutputPath "seo-report.json" }
}

if (-not $SkipAudit) {
    $auditScript = Join-Path $scriptDir 'site-audit.ps1'
    Invoke-Step "Site audit" { & $auditScript -Root $Root -FixMode:$true -DryRun:$false -OutputPath "site-audit-report.json" }
}

$buildScript = Join-Path $scriptDir 'build.ps1'
$distPath = Join-Path $Root 'dist'

Invoke-Step "Build" { & $buildScript -Root $Root -Dist $distPath -DryRun:$false -BaseUrl $BaseUrl }

Write-Step "All steps completed successfully."