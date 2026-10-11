# Run ONCE from an elevated PowerShell:  powershell -ExecutionPolicy Bypass -File C:\bonsai\8gb\setup-afterburner-tasks.ps1
# Creates tasks BonsaiAB_P1..P5. Each one only runs "MSIAfterburner.exe -ProfileN" with admin rights, in your
# logged-on session. Afterwards a non-admin shell can start them with:  schtasks /run /tn BonsaiAB_P3
# Remove them later with:  1..5 | % { Unregister-ScheduledTask -TaskName "BonsaiAB_P$_" -Confirm:$false }
$ErrorActionPreference = 'Stop'
$exe = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
if (-not (Test-Path $exe)) { throw "Afterburner not found at $exe" }
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
foreach ($n in 1..5) {
    $action = New-ScheduledTaskAction -Execute $exe -Argument "-Profile$n"
    Register-ScheduledTask -TaskName "BonsaiAB_P$n" -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "registered BonsaiAB_P$n -> $exe -Profile$n"
}
