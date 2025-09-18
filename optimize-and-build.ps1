param(
  [string]$Root = (Resolve-Path ".").Path,
  [string]$BaseUrl = "https://www.yoursite.com",
  [string]$SeoRoot = $null,
  [string]$Dist = $null,
  [switch]$FailOnError
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Step($name, [scriptblock]$block) {
  Write-Host "==> $name"
  try {
    & $block
    Write-Host "✔ $name completed"
    # Ensure any non-zero exit code from native commands does not leak
    $global:LASTEXITCODE = 0
  } catch {
    Write-Error "Step failed: $name`n$_"
    exit 1
  }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Dist) { $Dist = Join-Path $scriptDir 'dist' }
if (-not $SeoRoot) { $SeoRoot = $Root }

# 1) SEO enhance (safe no-op if structure isn't directory-per-page)
Step "SEO enhance" {
  & (Join-Path $scriptDir 'seo-enhance.ps1') -Root $SeoRoot -BaseUrl $BaseUrl -DryRun:$false
}

# 2) Audit and fix (GitHub-friendly output when -FailOnError)
Step "Site audit & fix" {
  $auditArgs = @{ Root = $Root; Fix = $true }
  if ($FailOnError) { $auditArgs.FailOnError = $true }
  & (Join-Path $scriptDir 'site-audit.ps1') @auditArgs
}

# 3) Build to dist
Step "Build" {
  & (Join-Path $scriptDir 'build.ps1') -Root $Root -Dist $Dist -BaseUrl $BaseUrl -DryRun:$false
}

Write-Host "All steps completed successfully."
# Force a successful process exit code even if a previous native command set LASTEXITCODE
$global:LASTEXITCODE = 0
exit 0