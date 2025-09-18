param(
  [Parameter(Mandatory = $false)][string]$Root = (Get-Location).Path,
  [Parameter(Mandatory = $false)][string]$OutDir = "dist",
  [Parameter(Mandatory = $false)][string]$Domain = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Copy-Static {
  param([string]$Src, [string]$Dst)
  if (Test-Path $Dst) { Remove-Item -Recurse -Force $Dst }
  New-Item -ItemType Directory -Force -Path $Dst | Out-Null

  $exclude = @(
    '.git', '.github', 'node_modules', 'dist', 'AuditBackup', 'SEOBackup', 'scripts/verify-dns.ps1'
  )

  $files = Get-ChildItem -Path $Src -Recurse -File
  foreach ($file in $files) {
    $rel = [System.IO.Path]::GetRelativePath($Src, $file.FullName)
    # Normalize separators to forward slashes for consistent matching and publishing
    $rel = $rel -replace "\\", "/"
    if ($rel.StartsWith("/")) { $rel = $rel.Substring(1) }

    $skip = $false
    foreach ($ex in $exclude) {
      $exNorm = $ex -replace "\\", "/"
      if ($rel -like "$exNorm*" -or $rel -eq $exNorm) { $skip = $true; break }
    }
    if ($skip) { continue }
    $destPath = Join-Path $Dst $rel
    New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($destPath)) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
  }
}

Write-Host "Building static site from '$Root' into '$OutDir'..."
$src = (Resolve-Path $Root).Path
$dst = Join-Path $src $OutDir
Copy-Static -Src $src -Dst $dst

if ($Domain) {
  $cnamePath = Join-Path $dst 'CNAME'
  Set-Content -LiteralPath $cnamePath -Value $Domain -Encoding ASCII
  Write-Host "Wrote custom domain to CNAME => $Domain"
}

Write-Host "Build complete. Output: $dst"
