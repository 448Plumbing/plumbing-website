param(
    [string]$Root = ".",
    [switch]$FixMode = $true,
    [switch]$DryRun = $false,
    [string]$OutputPath = "site-audit-report.json"
)

$ErrorActionPreference = "Stop"

function Write-Log { param($m) Write-Host "[site-audit] $m" }

$rootItem = Get-Item $Root
Write-Log "Root: $($rootItem.FullName)"

$files = Get-ChildItem -Path $rootItem.FullName -Recurse -Include '*.html','*.htm' -File |
    Where-Object {
        $_.FullName -notlike "*\dist\*" -and
        $_.FullName -notlike "*\desktop-site\webstie building install*"
    }

Write-Log "Auditing $($files.Count) HTML files..."

$rootLen = $rootItem.FullName.Length
$resultFiles = @()

foreach ($f in $files) {
    $rel = $f.FullName.Substring($rootLen).TrimStart('\\') -replace '\\','/'

    $issues = @()
    $actions = @()
    $changed = $false

    try {
        $html = Get-Content -LiteralPath $f.FullName -Raw

        if ($html -notmatch '<title>.*?</title>') {
            $issues += "missing-title"
        }
        if ($html -notmatch '<meta[^>]+name="description"[^>]*>') {
            $issues += "missing-meta-description"
        }

        # This script currently only reports issues; it does not modify files
        if ($issues.Count -eq 0) {
            $issuesStr = ""
        } else {
            $issuesStr = ($issues -join ";")
        }

        $actionsStr = ($actions -join ";")

        $resultFiles += [pscustomobject]@{
            File    = $f.FullName
            Relative = $rel
            Issues  = $issuesStr
            Actions = $actionsStr
            Changed = $changed
        }
    } catch {
        Write-Warning "Failed to audit $($f.FullName): $_"
        $resultFiles += [pscustomobject]@{
            File    = $f.FullName
            Relative = $rel
            Issues  = "audit-error"
            Actions = ""
            Changed = $false
        }
    }
}

$data = [ordered]@{
    RunDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ssK")
    Root    = $Root
    FixMode = [bool]$FixMode
    DryRun  = [bool]$DryRun
    Files   = $resultFiles
}

$json = $data | ConvertTo-Json -Depth 6

if (-not $DryRun) {
    $outPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $rootItem.FullName $OutputPath }
    Write-Log "Writing site audit report to $outPath"
    Set-Content -LiteralPath $outPath -Value $json -Encoding UTF8
} else {
    Write-Log "DryRun enabled - not writing $OutputPath"
}

Write-Log "Site audit complete."