#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p60; mkdir -p $R
for b in tier minq; do
  cmd //c "C:\bonsai\bonsai-ada-surgery\tooling\build-$b\build.bat" > logs/build-$b-p60.log 2>&1 || { echo "build $b failed" >> $R/summary.txt; exit 1; }
  rm -rf /c/bonsai/bonsai-ada-surgery/bin-$b && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-$b/bin /c/bonsai/bonsai-ada-surgery/bin-$b
  for f in /c/bonsai/bonsai-ada-surgery/bin-lookup/*.dll; do x=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-$b/$x ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-$b/; done
done
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
up() { powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p60_$1 -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-$2;BONSAI_LAYER=0;GGML_CUDA_FA_PREFILL_F16=32768" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && return 0; sleep 5; done; return 1; }
for r in 1 2; do for b in tier minq; do
  up ${b}_$r $b || { echo "$b serve failed" >> $R/summary.txt; continue; }
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag ${b}_r${r}_d0 --out $R/ab.jsonl --depth 0 > $R/${b}_r${r}_d0.txt 2>&1
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag ${b}_r${r}_d16k --out $R/ab.jsonl --depth 16000 > $R/${b}_r${r}_d16k.txt 2>&1
  up ${b}_${r}_pf $b && python /c/bonsai/bonsai-ada-surgery/bench/quick_tps.py --base http://127.0.0.1:8080 --key-file $KEY --depth 30000 2>&1 | grep -E "depth|mean decode" > $R/${b}_r${r}_prefill30k.txt
done; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
