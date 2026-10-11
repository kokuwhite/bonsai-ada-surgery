#!/usr/bin/env bash
# BonsaiJob7: P52 then P50. Waits for jobrun6 (P49). Do not edit while running.
cd /c/bonsai/8gb
mkdir receipts/jobrun7.lock 2>/dev/null || exit 1
trap 'rmdir receipts/jobrun7.lock' EXIT
log() { echo "$(date +%T) $*" >> receipts/jobrun7.log; }
log start
until grep -q " end\| build failed\|no lookup flag" receipts/jobrun6.log 2>/dev/null && [ ! -d receipts/jobrun6.lock ]; do sleep 60; done
[ -f /c/bonsai/bonsai-ada-surgery/bin-lookup/llama-server.exe ] || { log "no bin-lookup"; exit 1; }
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'
for b in rc3 lookup; do
  bash run_arm.sh receipts/p52 drafting_$b "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-$b;BONSAI_LAYER=0;BONSAI_LOOKUP=0" "$L" "4000 32000 64000"
  bash run_arm.sh receipts/p52 long_$b "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-$b;BONSAI_LAYER=0;BONSAI_LOOKUP=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf" "$L" "4000 32000 64000"
done
echo "one-token answers: $(cat receipts/p52/*.txt | grep -c '(1 tok)')" > receipts/p52/summary.txt
log p52 done
R=receipts/p50; mkdir -p $R; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
for lk in 0 1; do
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p50_look$lk -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-lookup;BONSAI_LAYER=0;BONSAI_LOOKUP=$lk" > $R/look$lk.serve.txt 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  ( while true; do nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits; sleep 2; done ) > $R/look$lk.free.txt &
  SP=$!
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag look${lk}_d120k --out $R/ab.jsonl --depth 120000 > $R/look$lk.out.txt 2>&1
  kill $SP 2>/dev/null
  echo "look$lk min free $(sort -n $R/look$lk.free.txt | head -1) MiB, alive $(curl -s localhost:8080/health | grep -c ok)" >> $R/summary.txt
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
done
log p50 done
log end
