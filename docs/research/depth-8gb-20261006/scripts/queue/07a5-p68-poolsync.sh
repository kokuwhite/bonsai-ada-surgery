#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p68; mkdir -p $R
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-poolsync\build.bat' > logs/build-poolsync-p68.log 2>&1 || { echo "build failed" > $R/summary.txt; exit 1; }
rm -rf /c/bonsai/bonsai-ada-surgery/bin-poolsync && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-poolsync/bin /c/bonsai/bonsai-ada-surgery/bin-poolsync
for f in /c/bonsai/bonsai-ada-surgery/bin-tier/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-poolsync/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-poolsync/; done
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest-pool.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-poolsync;BONSAI_LAYER=0'
for r in 1 2 3; do bash run_arm.sh $R fresh60k_r$r "$V" "$L" "60000"; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p68_ab30k -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag poolsync_d30k --out $R/ab.jsonl --depth 30000 > $R/ab30k.txt 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ for f in $R/fresh*.txt; do echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token of $(grep -cE '^(code|prose|bash) +depth' $f); $(grep 'mean decode' $f)"; done
  echo "ab30k: one-token items $(grep -c '"n": 1,' $R/ab.jsonl) of $(wc -l < $R/ab.jsonl)"; } > $R/summary.txt
