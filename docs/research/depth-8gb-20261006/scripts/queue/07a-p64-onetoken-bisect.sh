#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p64; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
for arm in "f16_look 32768 1 maintest" "nof16_look 0 1 maintest" "f16_nolook 32768 0 maintest" "nof16_nolook 0 0 maintest" "f16_look_nopool 32768 1 maintest-nopool"; do set -- $arm
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p64_$1 -Launcher "C:/bonsai/bonsai-ada-surgery/start-server-$4.ps1" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tier;BONSAI_LAYER=0;GGML_CUDA_FA_PREFILL_F16=$2;BONSAI_LOOKUP=$3" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  python benchmain/quick_tps.py --base http://127.0.0.1:8080 --key-file $KEY --depth 60000 2>&1 | grep -E "depth|mean decode" > $R/$1.txt
  L2="$(cygpath "$(tr -d '\r' < logs/current.log)")"; cp "${L2%.out.log}.err.log" $R/$1.server.log
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
for f in $R/*.txt; do echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token of $(grep -c 'depth' $f)"; done > $R/summary.txt
