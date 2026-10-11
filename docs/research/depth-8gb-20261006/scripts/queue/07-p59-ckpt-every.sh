#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p59; mkdir -p $R
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-ckpt\build.bat' > logs/build-ckpt.log 2>&1 || { echo "build failed" > $R/summary.txt; exit 1; }
rm -rf /c/bonsai/bonsai-ada-surgery/bin-ckpt && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-ckpt/bin /c/bonsai/bonsai-ada-surgery/bin-ckpt
for f in /c/bonsai/bonsai-ada-surgery/bin-lookup/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-ckpt/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-ckpt/; done
/c/bonsai/bonsai-ada-surgery/bin-ckpt/llama-server.exe --help 2>&1 | grep -q "checkpoint-every-nt" || { echo "flag missing" > $R/summary.txt; exit 1; }
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
for n in 8192 0; do
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p59_n$n -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-ckpt;BONSAI_LAYER=0;LLAMA_ARG_CHECKPOINT_EVERY_NT=$n" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  ( while true; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits) $(powershell -NoProfile -Command '[int]((Get-Process llama-server).WorkingSet64/1MB)')"; sleep 5; done ) > $R/n$n.mem.txt &
  SP=$!
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag n$n --out $R/ab.jsonl --depth 64000 > $R/n$n.out.txt 2>&1
  kill $SP 2>/dev/null
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
done
