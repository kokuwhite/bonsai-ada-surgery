# Stop the launcher started by serve.ps1 and its children (llama-server, layer), by PID only.
# Run with: powershell -NoProfile -ExecutionPolicy Bypass -File C:\bonsai\8gb\stop.ps1  (machine policy is Restricted)
$pidFile = 'C:\bonsai\8gb\logs\current.pid'
if (-not (Test-Path $pidFile)) {
    $orphans = Get-Process llama-server -ErrorAction SilentlyContinue
    if ($orphans) { throw "no current.pid but llama-server is running (pid $($orphans.Id -join ', ')): stop it by PID" }
    Write-Host 'no current.pid, no llama-server'; return
}
$root = [int](Get-Content $pidFile)
function Get-Tree([int]$id) {
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$id" | ForEach-Object { Get-Tree $_.ProcessId; $_.ProcessId }
}
$ids = @(Get-Tree $root) + $root
foreach ($i in $ids) { Stop-Process -Id $i -Force -ErrorAction SilentlyContinue }
$t = 0
while ((Get-Process llama-server -ErrorAction SilentlyContinue) -and $t -lt 30) { Start-Sleep 1; $t++ }
$left = Get-Process llama-server -ErrorAction SilentlyContinue
if ($left) { throw "llama-server still running after stop (pid $($left.Id -join ', '))" }
Remove-Item $pidFile
Write-Host "stopped $($ids -join ', ')"
