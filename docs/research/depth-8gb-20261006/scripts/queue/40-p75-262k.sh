#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p75; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-0046;BONSAI_LAYER=0;BONSAI_CTX=262144'
bash run_arm.sh $R sweep "$V" "$L" "4000 64000 128000 192000 250000"
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p75_ab -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
O="$(cygpath "$(tr -d '\r' < logs/current.log)")"; cp "$O" $R/ab.launcher.log
( while true; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits) $(powershell -NoProfile -Command '[int]((Get-Process llama-server).WorkingSet64/1MB)')"; sleep 20; done ) > $R/ab.mem.txt &
SP=$!
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag d250k --out $R/ab.jsonl --depth 250000 > $R/ab.txt 2>&1
kill $SP 2>/dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
