# Pause all GPU testing so Cary can serve the model. Run: powershell -ExecutionPolicy Bypass -File C:\bonsai\8gb\pause.ps1
# The queue runner keeps running but starts nothing while queue\PAUSE exists. The interrupted job goes back to pending.
$ErrorActionPreference = 'Continue'
Set-Location C:\bonsai\8gb
New-Item -ItemType File -Force queue\PAUSE | Out-Null
Get-ScheduledTask BonsaiJob* -ErrorAction SilentlyContinue | Where-Object State -eq 'Running' | Stop-ScheduledTask
# stop job scripts (not the runner): jobrun*.sh, queue\running\*.sh, filler_*.sh, run_arm.sh, lookup_ab.py, humaneval
Get-CimInstance Win32_Process | Where-Object {
    ($_.Name -eq 'bash.exe' -and $_.CommandLine -match 'jobrun\d+\.sh|queue/running/|filler_.*\.sh|run_arm\.sh') -or
    ($_.Name -eq 'python.exe' -and $_.CommandLine -match 'lookup_ab\.py|quick_tps\.py|humaneval_run\.py|p9_soak\.py') } |
    ForEach-Object { & taskkill /PID $_.ProcessId /T /F 2>$null | Out-Null }
Get-ChildItem queue\running\*.sh -ErrorAction SilentlyContinue | Move-Item -Destination queue\pending -Force
Get-ChildItem receipts\jobrun*.lock -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
& powershell -NoProfile -ExecutionPolicy Bypass -File C:\bonsai\8gb\stop.ps1 | Out-Null
& schtasks /run /tn BonsaiAB_P3 | Out-Null; Start-Sleep 4; & schtasks /run /tn BonsaiAB_P5 | Out-Null   # stock clocks, fan 100 %
Add-Content receipts\queue.log "$(Get-Date -Format 'MM-dd HH:mm:ss') PAUSED for serving"
Write-Host "Testing paused. Start the server: C:\bonsai\bonsai-ada-surgery\start-server.ps1. Resume: C:\bonsai\8gb\resume.ps1"
