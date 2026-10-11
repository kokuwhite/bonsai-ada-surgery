#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p70; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
up() { powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p70_$1 -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-$2;BONSAI_LAYER=0;GGML_CUDA_FA_PREFILL_F16=32768" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && return 0; sleep 5; done; return 1; }
for b in tier minq; do
  up ${b}_ab $b && for d in 0 16000 30000; do python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag ${b}_d$d --out $R/ab.jsonl --depth $d > $R/${b}_d$d.txt 2>&1; done
  for d in 30000 60000; do up ${b}_pf$d $b && python benchmain/quick_tps.py --base http://127.0.0.1:8080 --key-file $KEY --depth $d 2>&1 | grep -E "depth|mean decode" > $R/${b}_prefill$d.txt; done
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
echo "1-token items: $(grep -c '"n": 1,' $R/ab.jsonl) of $(wc -l < $R/ab.jsonl); quick_tps 1-token: $(cat $R/*prefill*.txt | grep -c '(1 tok)')" > $R/summary.txt
