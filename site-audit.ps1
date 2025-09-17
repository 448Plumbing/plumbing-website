param(
  [string]$Root = (Get-Location).Path,
  [switch]$Fix,
  [switch]$DryRun,
  [switch]$FailOnError
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Log { param($Msg,[string]$Level='INFO'); Write-Host "[$((Get-Date).ToString('u'))][$Level] $Msg" }

if (-not (Test-Path $Root -PathType Container)) { Write-Error "Root not found: $Root"; exit 1 }

$htmlFiles = Get-ChildItem -Path $Root -Recurse -Include *.html,*.htm -File
if (-not $htmlFiles) { Log "No HTML files under $Root" 'WARN' }

$backupDir = Join-Path $Root 'AuditBackup'
if ($Fix -and -not $DryRun -and -not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }

# Build relative path map
$allRel = @{}
$rootFull = (Get-Item $Root).FullName
foreach ($f in $htmlFiles) {
  $rel = $f.FullName.Substring($rootFull.Length).TrimStart('\\')
  $norm = ($rel -replace '\\','/').ToLower()
  $allRel[$norm] = $true
}

$descPlaceholder = 'Local professional plumbing services in Dallas Fort Worth area.'
$report = @()

foreach ($file in $htmlFiles) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  $original = $content
  $issues = @(); $actions = @();

  # Missing lang
  if ($content -notlike '*<html*lang=*') {
    $issues += 'missing-lang'
    if ($Fix -and -not $DryRun) {
      $content = $content -replace '<html','<html lang="en"'
      if ($content -like '*lang="en"*') { $actions += 'add-lang-en' }
    }
  }

  # Meta description
  if ($content -notlike '*name="description"*') {
    $issues += 'missing-meta-description'
    if ($Fix -and -not $DryRun -and $content -like '*</head>*') {
      $content = $content -replace '</head>', "  <meta name=\"description\" content=\"$descPlaceholder\" />`n</head>"
      $actions += 'insert-description'
    }
  }

  # Duplicate IDs (naive scan)
  $idValues = @()
  $scanIndex = 0
  while (($scanIndex = $content.IndexOf('id="', $scanIndex)) -ge 0) {
    $start = $scanIndex + 4
    $end = $content.IndexOf('"', $start)
    if ($end -gt $start) { $idValues += $content.Substring($start, $end - $start) }
    $scanIndex = $end + 1
  }
  if ($idValues.Count -gt 0) {
    $dupSet = $idValues | Group-Object | Where-Object { $_.Count -gt 1 }
    foreach ($d in $dupSet) { $issues += ('duplicate-id:' + $d.Name) }
  }

  # Images missing alt
  $imgIndex = 0
  while (($imgIndex = $content.IndexOf('<img', $imgIndex)) -ge 0) {
    $close = $content.IndexOf('>', $imgIndex)
    if ($close -lt 0) { break }
    $tag = $content.Substring($imgIndex, $close - $imgIndex + 1)
    if ($tag -notlike '*alt=*') {
      $issues += 'img-missing-alt'
      if ($Fix -and -not $DryRun) {
        $newTag = $tag.TrimEnd('>') + ' alt="" >'
        $content = $content.Substring(0,$imgIndex) + $newTag + $content.Substring($close+1)
        $actions += 'add-empty-alt'
        $imgIndex += ($newTag.Length)
        continue
      }
    }
    $imgIndex = $close + 1
  }

  # Broken links (internal)
  $hrefIndex = 0
  while (($hrefIndex = $content.IndexOf('href="', $hrefIndex)) -ge 0) {
    $start = $hrefIndex + 6
    $end = $content.IndexOf('"', $start)
    if ($end -lt 0) { break }
    $href = $content.Substring($start, $end - $start)
    $hrefIndex = $end + 1
    if ($href -like 'http*' -or $href -like 'mailto:*' -or $href -like 'tel:*' -or $href -like '#*') { continue }
    $target = $href.TrimStart('/')
    if (-not $target) { continue }
    $normT = ($target).ToLower()
    if (-not $allRel.ContainsKey($normT)) {
      $maybeDir = ($target.TrimEnd('/')) + '/index.html'
      $maybeNorm = ($maybeDir -replace '\\','/').ToLower()
      if (-not $allRel.ContainsKey($maybeNorm)) {
        $issues += ('broken-link:' + $href)
        # GitHub Actions error annotation
        Write-Output ('::error::Broken link found: ' + $href + ' in ' + $file.FullName)
      }
    }
  }

  $changed = $original -ne $content
  if ($changed -and -not $DryRun) {
    $relName = $file.FullName.Substring($rootFull.Length).TrimStart('\\') -replace '[\\/:]','_'
    $backup = Join-Path $backupDir ($relName + '.bak')
    if ($Fix -and -not (Test-Path $backup)) { [IO.File]::WriteAllText($backup,$original,[Text.UTF8Encoding]::new($false)) }
    if ($Fix) { [IO.File]::WriteAllText($file.FullName,$content,[Text.UTF8Encoding]::new($false)) }
  }

  $report += [PSCustomObject]@{
    File = $file.FullName
    Relative = ($file.FullName.Substring($rootFull.Length).TrimStart('\\') -replace '\\','/')
    Issues = ($issues | Sort-Object -Unique) -join ';'
    Actions = ($actions | Sort-Object -Unique) -join ';'
    Changed = $changed
  }
}

$summary = [PSCustomObject]@{
  RunDate = (Get-Date).ToString('u')
  Root = $Root
  FixMode = [bool]$Fix
  DryRun = [bool]$DryRun
  Files = $report
}

if ($DryRun) {
  Log '--- DryRun audit (first 10) ---'
  $report | Select-Object -First 10 File, Issues, Actions | Format-Table
} else {
  $out = Join-Path $Root 'site-audit-report.json'
  $summary | ConvertTo-Json -Depth 4 | Out-File -FilePath $out -Encoding UTF8
  Log "Audit report written: $out"
}

Log "Audited $($report.Count) HTML files." 'INFO'

# Summary & optional failure
$totalIssues = ($report | ForEach-Object { if ($_.Issues) { $_.Issues.Split(';').Count } else { 0 } } | Measure-Object -Sum).Sum
Write-Output ("::notice::Audit complete. Files=" + $report.Count + ", Issues=" + ($totalIssues | ForEach-Object { $_ }))
if ($FailOnError -and $totalIssues -gt 0) { exit 1 }
