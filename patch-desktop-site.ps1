<#
Safe patch-desktop-site.ps1
- Purpose: selective backup + idempotent patching for 448 Plumbing desktop copy
- Usage examples:
 - Usage examples:
    pwsh -NoProfile -ExecutionPolicy Bypass -File C:\workspace\site\patch-desktop-site.ps1 -Root "C:\Users\Maitray\Desktop\448Plumbing\448 Plumbing website" -DryRun:$true
    pwsh -NoProfile -ExecutionPolicy Bypass -File C:\workspace\site\patch-desktop-site.ps1 -Root "C:\Users\Maitray\Desktop\448Plumbing\448 Plumbing website" -DryRun:$false
    # Recurse into subfolders
    pwsh -NoProfile -ExecutionPolicy Bypass -File C:\workspace\site\patch-desktop-site.ps1 -Root "C:\Users\Maitray\Desktop\448Plumbing\448 Plumbing website" -Recurse -DryRun:$true
    # Run against a single file
    pwsh -NoProfile -ExecutionPolicy Bypass -File C:\workspace\site\patch-desktop-site.ps1 -Root "C:\Users\Maitray\Desktop\448Plumbing\448 Plumbing website\index.html" -DryRun:$true
Notes:
- Save this file to disk and run it from PowerShell. Do NOT paste prompt lines into the shell.
- The script avoids zipping the whole Home directory by copying only site files to a temp folder first (selective backup).
#>
param(
    [Parameter(Mandatory=$false)]
    [string]$Root = "",
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $true,
    [Parameter(Mandatory=$false)]
    [switch]$VerboseMode = $false
    ,
    [Parameter(Mandatory=$false)]
    [switch]$Recurse,
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeDirs = @('Patch','Doc','Lib')
)

# (Recurse is a declared parameter)

Set-StrictMode -Version Latest

function Write-Log {
    param([string]$msg)
    $time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    if ($VerboseMode) { Write-Host "[$time] $msg" }
    else { Write-Output $msg }
}

# If Root not provided, prompt user and then exit unless confirmed.
if ([string]::IsNullOrWhiteSpace($Root)) {
    Write-Host "No -Root provided. Please run with -Root 'C:\path\to\site' or provide interactively now." -ForegroundColor Yellow
    $Root = Read-Host 'Enter site root directory (full path) or CTRL+C to cancel'
}

# If $Root is a file, normalize to its folder and note single-file mode
if (-not (Test-Path -Path $Root)) {
    Write-Error "Provided Root path does not exist: $Root"
    exit 2
}

if (Test-Path -Path $Root -PathType Leaf) {
    $singleFileMode = $true
    $singleFile = (Get-Item $Root).FullName
    $Root = Split-Path -Path $singleFile -Parent
} else {
    $singleFileMode = $false
}

$Root = (Get-Item $Root).FullName
Write-Log "Operating on Root: $Root"

# Build an exclude regex from ExcludeDirs (used to skip large/unrelated folders)
$excludeRegex = $null
if ($ExcludeDirs -and $ExcludeDirs.Count -gt 0) {
    $escaped = $ExcludeDirs | ForEach-Object { [regex]::Escape($_) }
    $excludeRegex = [regex]::new(($escaped -join '|'), 'IgnoreCase')
    Write-Log "Excluding paths that match: $($ExcludeDirs -join ', ')"
}

# Find HTML files (top-level and direct subfolders by default). To recurse fully, set $RecurseAll = $true early in the script.
$RecurseAll = $false
$SearchOption = if ($RecurseAll) { [System.IO.SearchOption]::AllDirectories } else { [System.IO.SearchOption]::TopDirectoryOnly }

# Collect candidate files (html and partials)
Write-Log "Collecting HTML files..."
$searchRecurse = $false
if ($Recurse.IsPresent) { $searchRecurse = $true }
if ($singleFileMode) {
    # If the single file is inside an excluded folder, warn but still allow single-file mode
    if ($excludeRegex -and $excludeRegex.IsMatch($singleFile)) {
        Write-Host "Warning: the single file appears inside an excluded path (matches ExcludeDirs). Proceeding because you specified a single file." -ForegroundColor Yellow
    }
    $htmlFiles = @((Get-Item $singleFile))
} else {
    if ($searchRecurse) {
        $htmlFiles = @(Get-ChildItem -Path $Root -Filter *.html -File -Recurse -ErrorAction SilentlyContinue | Where-Object { -not ($excludeRegex -and $excludeRegex.IsMatch($_.FullName)) } | Sort-Object FullName)
    } else {
        $htmlFiles = @(Get-ChildItem -Path $Root -Filter *.html -File -ErrorAction SilentlyContinue | Where-Object { -not ($excludeRegex -and $excludeRegex.IsMatch($_.FullName)) } | Sort-Object FullName)
    }
}
$htmlCount = ($htmlFiles | Measure-Object).Count
if ($htmlCount -eq 0) {
    Write-Host "WARNING: No .html files found under $Root. If your site is in nested folders, re-run with RecurseAll = `$true (edit the script)." -ForegroundColor Yellow
} else {
    Write-Log "Found $htmlCount HTML files to inspect."
}

# Selective backup: copy site files to temp folder then zip that.
$backupDir = Join-Path -Path $env:USERPROFILE -ChildPath 'patch-desktop-site-backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$zipPath = Join-Path $backupDir "backup-$timestamp.zip"
$workTemp = Join-Path -Path $env:TEMP -ChildPath "patch-desktop-site-$timestamp"

Write-Log "Creating selective backup in temp folder: $workTemp"
New-Item -ItemType Directory -Force -Path $workTemp | Out-Null

# Copy only html, css, js, images, assets folder and common webfile types
$includePatterns = @('*.html','*.css','*.js','*.png','*.jpg','*.jpeg','*.gif','*.svg','*.webp','fonts/*','assets/*')
foreach ($pattern in $includePatterns) {
    # Use robocopy-style copy fallback: use Copy-Item for simple patterns
    try {
        Get-ChildItem -Path (Join-Path $Root $pattern) -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $dest = Join-Path $workTemp ($_.FullName.Substring($Root.Length).TrimStart('\'))
            $destDir = Split-Path -Path $dest -Parent
            # Skip files inside excluded directories
            if ($excludeRegex -and $excludeRegex.IsMatch($_.FullName)) { return }
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
            Copy-Item -Path $_.FullName -Destination $dest -Force
        }
    } catch {
        # ignore pattern copy errors
    }
}

# Create zip of temp folder (use Compress-Archive; if it fails, leave the copied folder as backup)
try {
    Write-Log "Creating ZIP backup: $zipPath"
    Compress-Archive -Path (Join-Path $workTemp '*') -DestinationPath $zipPath -Force -ErrorAction Stop
    Write-Log "Backup created: $zipPath"
} catch {
    Write-Host "Warning: Compress-Archive failed; leaving selective copy at $workTemp" -ForegroundColor Yellow
    Write-Log "Compress-Archive failed: $($_.Exception.Message)"
}

# Utility: safe regex replace in a file with dry-run support
function Safe-Replace {
    param(
        [string]$filePath,
        [System.Text.RegularExpressions.Regex]$regex,
        [string]$replacement
    )
    $content = Get-Content -Raw -Path $filePath -ErrorAction Stop
    if ($regex.IsMatch($content)) {
        $new = $regex.Replace($content, $replacement)
        if ($new -ne $content) {
            if ($DryRun) {
                Write-Output "[DryRun] Would patch: $filePath ($($content.Length) -> $($new.Length) chars)"
                return $true
            } else {
                Set-Content -Path $filePath -Value $new -Force
                Write-Output "Patched: $filePath"
                return $true
            }
        }
    }
    return $false
}

# Patching rules (idempotent)
$patchCount = 0
foreach ($f in $htmlFiles) {
    $p = $f.FullName
    # Skip if not a regular file (defensive)
    if (-not (Test-Path -Path $p -PathType Leaf)) {
        Write-Output "[Skip] Not a file: $p"
        continue
    }
    if ($VerboseMode) { Write-Log "Inspecting $p" }

    # 1) Replace contact hrefs (mailto: / contact.html / tel:) with Instagram anchor (idempotent)
    $regex1 = [regex]::new('href\s*=\s*"(contact\.html|mailto:[^"]+|tel:[^"]+)"','IgnoreCase')
    $rep1 = 'href="https://www.instagram.com/448plumbing/#" target="_blank" rel="noopener noreferrer" class="contact-button"'
    if (Safe-Replace -filePath $p -regex $regex1 -replacement $rep1) { $patchCount++ }

    # 2) Ensure instagram links that already point to instagram include class and target/rel
    $regexInsta = [regex]::new('<a\s+([^>]*?)href\s*=\s*"https?://(www\.)?instagram\.com/448plumbing[^\"]*"([^>]*?)>','IgnoreCase')
    $repInsta = '<a $1href="https://www.instagram.com/448plumbing/" $3 target="_blank" rel="noopener noreferrer" class="contact-button">'
    if (Safe-Replace -filePath $p -regex $regexInsta -replacement $repInsta) { $patchCount++ }

    # 3) Replace visible 'Blog' nav link text to 'Team' and href blog -> team (simple text/anchor replacement)
    $regexBlog = [regex]::new('>\s*Blog\s*<','IgnoreCase')
    $repBlog = '> Team <'
    if (Safe-Replace -filePath $p -regex $regexBlog -replacement $repBlog) { $patchCount++ }
    $regexBlogHref = [regex]::new('href\s*=\s*"blog(?:\.html)?"','IgnoreCase')
    $repBlogHref = 'href="team.html"'
    if (Safe-Replace -filePath $p -regex $regexBlogHref -replacement $repBlogHref) { $patchCount++ }

    # 4) Tailwind blue -> gold class mappings (limited set)
    $classMap = @{
        'text-blue-600' = 'text-gold-500'
        'bg-blue-600' = 'bg-gold-500'
        'border-blue-600' = 'border-gold'
        'hover:text-blue-800' = 'hover:text-gold-600'
        'text-blue-500' = 'text-gold-500'
        'bg-blue-500' = 'bg-gold-500'
    }
    foreach ($k in $classMap.Keys) {
        $v = $classMap[$k]
        $regexC = [regex]::new('\b' + [regex]::Escape($k) + '\b','IgnoreCase')
        $content = Get-Content -Raw -Path $p
        if ($regexC.IsMatch($content)) {
            if ($DryRun) {
                Write-Output "[DryRun] Would replace class $k -> $v in $p"
                $patchCount++
            } else {
                $newc = $regexC.Replace($content, $v)
                Set-Content -Path $p -Value $newc -Force
                Write-Output ("Patched classes in {0}: {1} -> {2}" -f $p, $k, $v)
                $patchCount++
            }
        }
    }

    # 5) Inject theme link if missing
    $themeLink = '<link rel="stylesheet" href="/assets/theme.css">'
    $raw = Get-Content -Raw -Path $p
    if ($raw -notmatch [regex]::Escape('/assets/theme.css')) {
        if ($DryRun) {
            Write-Output "[DryRun] Would insert theme link into $p"
        } else {
            $raw2 = $raw -replace '(<head[^>]*>)', "`$1`n    $themeLink"
            Set-Content -Path $p -Value $raw2 -Force
            Write-Output "Injected theme link into $p"
            $patchCount++
        }
    }

    # 6) Add target/rel/class to anchors that point to instagram but are missing attributes (idempotent handled above)
    # Already handled by $regexInsta
}

Write-Host "--- Patch Summary ---"
Write-Host "Files inspected: $htmlCount"
Write-Host "Patch operations recorded (approx): $patchCount"

# Diagnostics: missing title/meta/alt
$missingTitle = @()
$missingMetaDesc = @()
$imagesMissingAlt = @()
foreach ($f in $htmlFiles) {
    $raw = Get-Content -Raw -Path $f.FullName
    if ($raw -notmatch '(?i)<title>.*?</title>') { $missingTitle += $f.FullName }
    if ($raw -notmatch '(?i)<meta\s+name\s*=\s*"description"') { $missingMetaDesc += $f.FullName }
    # images missing alt
    $imgRegex = [regex] '<img\s+[^>]*>'
    foreach ($m in $imgRegex.Matches($raw)) {
        $tag = $m.Value
        if ($tag -notmatch '(?i)alt\s*=') { $imagesMissingAlt += "$($f.FullName) :: $tag" }
    }
}

Write-Host "Diagnostics:" -ForegroundColor Cyan
Write-Host "Pages missing <title>: $($missingTitle.Count)"
if ($missingTitle.Count -gt 0) { $missingTitle | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" } }
Write-Host "Pages missing meta description: $($missingMetaDesc.Count)"
if ($missingMetaDesc.Count -gt 0) { $missingMetaDesc | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" } }
Write-Host "Images missing alt: $($imagesMissingAlt.Count)"
if ($imagesMissingAlt.Count -gt 0) { $imagesMissingAlt | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" } }

# Write diagnostics to a JSON file inside the selective backup temp folder for easy sharing
try {
    $diagObj = [PSCustomObject]@{
        Root = $Root
        Timestamp = (Get-Date).ToString('o')
        FilesInspected = $htmlCount
        Files = ($htmlFiles | ForEach-Object { $_.FullName })
        PatchCount = $patchCount
        MissingTitle = $missingTitle
        MissingMetaDescription = $missingMetaDesc
        ImagesMissingAlt = $imagesMissingAlt
    }
    $diagPath = Join-Path -Path $workTemp -ChildPath "diagnostics.json"
    $diagObj | ConvertTo-Json -Depth 5 | Out-File -FilePath $diagPath -Encoding utf8
    Write-Host "Diagnostics written to: $diagPath"
} catch {
    Write-Host "Warning: Unable to write diagnostics JSON: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Final notes
if ($DryRun) {
    Write-Host "Dry-run mode enabled. No files were changed. Re-run with -DryRun:$false to apply changes." -ForegroundColor Yellow
}

Write-Host "Done. You may delete the temporary selective backup at: $workTemp (or keep it for manual restore)."

# Mark todo complete (update the todo list file in workspace if present)
$todoPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'todo-updates.txt'
try { "LastRan=$((Get-Date).ToString('o')) Root=$Root DryRun=$($DryRun.IsPresent)" | Out-File -FilePath $todoPath -Encoding utf8 } catch { }
