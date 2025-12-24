param(
  [string]$FilePath,
  [string[]]$ArgumentList,
  [int]$TimeoutSeconds = 1200,
  [string]$WorkingDirectory = (Get-Location).Path,
  [string]$LogDir = ".\build-logs"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $LogDir)) {
  New-Item -Force -ItemType Directory -Path $LogDir | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$stdout = Join-Path $LogDir ("run-{0}.out.log" -f $stamp)
$stderr = Join-Path $LogDir ("run-{0}.err.log" -f $stamp)

Write-Host "Running: $FilePath $($ArgumentList -join ' ')"
Write-Host "WorkingDirectory: $WorkingDirectory"
Write-Host "TimeoutSeconds: $TimeoutSeconds"
Write-Host "STDOUT: $stdout"
Write-Host "STDERR: $stderr"

$proc = Start-Process -FilePath $FilePath `
  -ArgumentList $ArgumentList `
  -WorkingDirectory $WorkingDirectory `
  -NoNewWindow `
  -PassThru `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr

$exited = $proc.WaitForExit($TimeoutSeconds * 1000)

if (-not $exited) {
  Write-Host "TIMEOUT after $TimeoutSeconds seconds. Killing process tree PID $($proc.Id) ..."
  cmd /c "taskkill /PID $($proc.Id) /T /F" | Out-Host
  throw "Timed out running: $FilePath. Logs: $stdout, $stderr"
}

Write-Host "ExitCode: $($proc.ExitCode)"
if ($proc.ExitCode -ne 0) {
  Write-Host "---- STDERR tail (last 200 lines) ----"
  if (Test-Path $stderr) {
    Get-Content $stderr -Tail 200 | Out-Host
  }
  throw "Process failed with exit code $($proc.ExitCode). Logs: $stdout, $stderr"
}

Write-Host "SUCCESS"
Write-Host "Logs: $stdout, $stderr"
