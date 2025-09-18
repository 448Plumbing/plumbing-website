param(
  [string]$Domain = "448Plumbing.com"
)

# Quick DNS diagnostics for Pages setup without changing anything.
Write-Host "Checking DNS for $Domain and www.$Domain ..."

function Resolve-Name($name) {
  try {
    $records = Resolve-DnsName -Name $name -Type A -ErrorAction Stop
    $aaaa = @()
    try { $aaaa = Resolve-DnsName -Name $name -Type AAAA -ErrorAction Stop } catch {}
    return @{ A = $records; AAAA = $aaaa }
  } catch {
    return @{ A = @(); AAAA = @() }
  }
}

function Resolve-CNAME($name) {
  try { return Resolve-DnsName -Name $name -Type CNAME -ErrorAction Stop } catch { return @() }
}

$rootA = Resolve-Name $Domain
$wwwCname = Resolve-CNAME ("www." + $Domain)
$wwwA = Resolve-Name ("www." + $Domain)

Write-Host "\n== Root (@) A/AAAA"
$rootA.A | ForEach-Object { Write-Host ("A    {0} -> {1}" -f $_.NameHost, $_.IPAddress) }
$rootA.AAAA | ForEach-Object { Write-Host ("AAAA {0} -> {1}" -f $_.NameHost, $_.IPAddress) }

Write-Host "\n== www CNAME"
if ($wwwCname) {
  $wwwCname | ForEach-Object { Write-Host ("CNAME {0} -> {1}" -f $_.Name, $_.NameHost) }
} else {
  Write-Host "No CNAME for www"
}

Write-Host "\n== www A/AAAA (should be empty if CNAME exists)"
$wwwA.A | ForEach-Object { Write-Host ("A    {0} -> {1}" -f $_.NameHost, $_.IPAddress) }
$wwwA.AAAA | ForEach-Object { Write-Host ("AAAA {0} -> {1}" -f $_.NameHost, $_.IPAddress) }

Write-Host "\nExpected for GitHub Pages:" 
Write-Host "- www CNAME -> 448Plumbing.github.io"
Write-Host "- Root A -> 185.199.108.153/109.153/110.153/111.153 (and optionally AAAA 2606:50c0:8000..8003::153)"
Write-Host "- MX stays with Google Workspace; do not touch"
