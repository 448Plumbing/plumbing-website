param(
    [string]$Root = ".",
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

function Write-Log { param($m) Write-Host "[encoding-cleanup] $m" }

$rootItem = Get-Item $Root
Write-Log "Root: $($rootItem.FullName)"

# All HTML/HTM files, excluding dist and desktop-site (third-party payload)
$files = Get-ChildItem -Path $rootItem.FullName -Recurse -Include '*.html','*.htm' -File |
    Where-Object {
        $_.FullName -notlike "*\dist\*" -and
        $_.FullName -notlike "*\desktop-site\webstie building install*"
    }

Write-Log "Scanning $($files.Count) HTML files..."

[int]$changedCount = 0

foreach ($f in $files) {
    $text = Get-Content -LiteralPath $f.FullName -Raw
    $original = $text

    # Remove control chars except CR/LF/TAB
    $chars = $text.ToCharArray() | ForEach-Object {
        $code = [int]$_
        if ($code -lt 32 -and $_ -ne "`n" -and $_ -ne "`r" -and $_ -ne "`t") {
            return $null
        }
        return $_
    }
    $text = -join $chars

    # Remove Unicode replacement character U+FFFD and stray box U+25A1 if present
    $text = $text -replace [string][char]0xFFFD, ''
    $text = $text -replace [string][char]0x25A1, ''

    # Normalize Dallas–Fort Worth spelling if any odd hyphen artifacts remain
    $text = $text -replace "Dallas.?Fort Worth", "Dallas–Fort Worth"

    # Ensure we have a UTF-8 meta charset inside <head>
    if ($text -match "<head[\s\S]*?</head>") {
        $head = $Matches[0]
        if ($head -notmatch "charset=") {
            $replacement = $head -replace '<head>', "<head>`r`n    <meta charset='UTF-8'>"
            $text = $text.Replace($head, $replacement)
        }
    }

    if ($text -ne $original) {
        $changedCount++
        Write-Log "Cleaning: $($f.FullName)"
        if (-not $DryRun) {
            Set-Content -LiteralPath $f.FullName -Value $text -Encoding UTF8
        }
    }
}

Write-Log "Done. Changed $changedCount file(s)."