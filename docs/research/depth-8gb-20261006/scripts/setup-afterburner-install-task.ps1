# Run ONCE elevated:
#   Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-File','C:\bonsai\8gb\setup-afterburner-install-task.ps1'
# Creates task BonsaiAB_Install. When started (schtasks /run /tn BonsaiAB_Install) it runs install-profile.ps1 as
# admin: stops Afterburner, backs up the card's profile file, copies C:\bonsai\8gb\afterburner\staged.cfg over it, and
# starts Afterburner again minimized. It touches nothing but that one Afterburner file and process.
$ErrorActionPreference = 'Stop'
$dir = 'C:\bonsai\8gb\afterburner'
New-Item -ItemType Directory -Force $dir | Out-Null
$installer = Join-Path $dir 'install-profile.ps1'
@'
$ErrorActionPreference = 'Stop'
$ab = 'C:\Program Files (x86)\MSI Afterburner'
$cfg = Join-Path $ab 'Profiles\VEN_10DE&DEV_1F47&SUBSYS_13AD10DE&REV_A1&BUS_9&DEV_0&FN_0.cfg'
$staged = 'C:\bonsai\8gb\afterburner\staged.cfg'
$log = 'C:\bonsai\8gb\afterburner\install.log'
if (-not (Test-Path $staged)) { Add-Content $log "$(Get-Date -Format s) no staged.cfg"; exit 1 }
Get-Process MSIAfterburner -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Copy-Item -LiteralPath $cfg ("C:\bonsai\8gb\afterburner\backup-" + (Get-Date -Format yyyyMMdd-HHmmss) + '.cfg')
Copy-Item -LiteralPath $staged $cfg -Force
Start-Process (Join-Path $ab 'MSIAfterburner.exe') -ArgumentList '-m'
Add-Content $log "$(Get-Date -Format s) installed staged.cfg"
'@ | Set-Content -Encoding UTF8 $installer
# Only an administrator may change the installer script (so the admin task cannot be repointed by a normal process).
icacls $installer /inheritance:r /grant:r 'Administrators:F' 'SYSTEM:F' "$env:USERNAME`:RX" | Out-Null
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installer`""
Register-ScheduledTask -TaskName 'BonsaiAB_Install' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "registered BonsaiAB_Install -> $installer"
