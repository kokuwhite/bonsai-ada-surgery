# Start an arbitrary llama-server command line hidden with logs (for foreign builds and recipes run verbatim).
# Usage: serve_raw.ps1 -Tag x -Cmd "C:\path\llama-server.exe -m ... --port 8899" [-Vars 'NAME=v;NAME2=v']
param([string]$Tag = 'raw', [string]$Cmd, [string]$Vars = '')
$ErrorActionPreference = 'Stop'
$running = Get-Process llama-server -ErrorAction SilentlyContinue
if ($running) { throw "llama-server already running (pid $($running.Id -join ', ')): run stop.ps1 first" }
$LogDir = 'C:\bonsai\8gb\logs'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path $LogDir "$stamp-$Tag.out.log"
$err = Join-Path $LogDir "$stamp-$Tag.err.log"
$sets = ($Vars -split ';' | Where-Object { $_ } | ForEach-Object { $k, $v = $_ -split '=', 2; "`$env:$k='$v';" }) -join ' '
$exe, $rest = $Cmd -split ' ', 2
$cmdline = "$sets Set-Location '$(Split-Path $exe)'; & '$exe' $rest"
$p = Start-Process powershell -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmdline)
Set-Content C:\bonsai\8gb\logs\current.pid $p.Id
Set-Content C:\bonsai\8gb\logs\current.log $out
Write-Host "raw launcher pid $($p.Id)  out $out"
