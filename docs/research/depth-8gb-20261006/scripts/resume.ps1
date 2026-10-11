# Resume GPU testing after serving. Run: powershell -ExecutionPolicy Bypass -File C:\bonsai\8gb\resume.ps1
Set-Location C:\bonsai\8gb
& powershell -NoProfile -ExecutionPolicy Bypass -File C:\bonsai\8gb\stop.ps1 | Out-Null
Remove-Item queue\PAUSE -Force -ErrorAction SilentlyContinue
if ((Get-ScheduledTask BonsaiQueue).State -ne 'Running') { Start-ScheduledTask BonsaiQueue }
Add-Content receipts\queue.log "$(Get-Date -Format 'MM-dd HH:mm:ss') RESUMED"
Write-Host "Testing resumed."
