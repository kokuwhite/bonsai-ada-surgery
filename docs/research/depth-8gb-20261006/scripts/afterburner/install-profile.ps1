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
