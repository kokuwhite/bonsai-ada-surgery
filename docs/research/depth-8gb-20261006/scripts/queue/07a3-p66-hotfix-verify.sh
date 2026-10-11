#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p66; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-hotfix.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tier;BONSAI_LAYER=0'
for d in 30000 60000 120000; do
  bash run_arm.sh $R fresh$d "$V" "$L" "$d"
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p66_ab30k -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
( while true; do nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits; sleep 2; done ) > $R/ab30k.free.txt &
SP=$!
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag hotfix_d30k --out $R/ab.jsonl --depth 30000 > $R/ab30k.txt 2>&1
kill $SP 2>/dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ for f in $R/fresh*.txt; do echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token of $(grep -cE '^(code|prose|bash) +depth' $f); $(grep -E 'loaded|min free' $f | tr '\n' ' ')"; done
  echo "ab30k: one-token items $(grep -c '"n": 1,' $R/ab.jsonl) of $(wc -l < $R/ab.jsonl); min free $(sort -n $R/ab30k.free.txt | head -1) MiB"; } > $R/summary.txt
