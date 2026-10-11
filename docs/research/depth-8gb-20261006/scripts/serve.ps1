# Start the Bonsai launcher hidden with logs. Env knobs are passed as -Env 'NAME=value',...
# Usage: powershell -File C:\bonsai\8gb\serve.ps1 -Tag p1-n16384 -Vars 'BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_KV_VRAM_CELLS=16384'
param([string]$Tag = 'run', [string]$Vars = '', [string]$Launcher = 'C:\bonsai\bonsai-ada-surgery\start-server.ps1')
$ErrorActionPreference = 'Stop'
# One server at a time: a second llama-server would share port 8080 and over-commit VRAM (WDDM pages one out).
$running = Get-Process llama-server -ErrorAction SilentlyContinue
if ($running) { throw "llama-server already running (pid $($running.Id -join ', ')): run stop.ps1 first" }
$LogDir = 'C:\bonsai\8gb\logs'
New-Item -ItemType Directory -Force $LogDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path $LogDir "$stamp-$Tag.out.log"
$err = Join-Path $LogDir "$stamp-$Tag.err.log"
$sets = ($Vars -split ';' | Where-Object { $_ } | ForEach-Object { $k, $v = $_ -split '=', 2; "`$env:$k='$v';" }) -join ' '
$cmd = "$sets & '$Launcher'"
$p = Start-Process powershell -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd)
Set-Content C:\bonsai\8gb\logs\current.pid $p.Id
Set-Content C:\bonsai\8gb\logs\current.log $out
Write-Host "launcher pid $($p.Id)  out $out"
