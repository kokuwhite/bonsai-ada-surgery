#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p57; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p57_soak -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-lookup;BONSAI_LAYER=0" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
( while true; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 2; done ) > $R/free.txt &
SP=$!; T0=$(date +%s)
for k in 1 2 3; do python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag soak$k --out $R/ab.jsonl --depth 64000 > $R/run$k.txt 2>&1; done
kill $SP
echo "seconds $(( $(date +%s) - T0 )), min free $(awk '{print $2}' $R/free.txt | sort -n | head -1) MiB, alive $(curl -s localhost:8080/health | grep -c ok)" > $R/summary.txt
powershell -NoProfile -Command "(Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=(Get-Date).AddHours(-1)} -ErrorAction SilentlyContinue | Where-Object { \$_.ProviderName -match 'nvlddmkm|WHEA' }).Count" >> $R/summary.txt
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
