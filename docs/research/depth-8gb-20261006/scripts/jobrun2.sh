#!/usr/bin/env bash
# BonsaiJob2: P41b census, P43 (#314 A/B), P44 (#317 MMA decode A/B), P42 restart-based +1000 soak. Do not edit while running.
cd /c/bonsai/8gb
log() { echo "$(date +%T) $*" >> receipts/jobrun2.log; }
mkdir receipts/jobrun2.lock 2>/dev/null || { log "another jobrun2 holds the lock - exiting"; exit 1; }
trap 'rmdir receipts/jobrun2.lock' EXIT
log start
until [ -f receipts/p40/done.txt ]; do sleep 30; done
log p40 done
STOP() { powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1; }
M='C:\bonsai\bonsai-ada-surgery\models\Ternary-Bonsai-2-27B-PTQ1_0.gguf'
# P41b census (already done 18:55 - skipped)
if false; then
mkdir -p receipts/p41b; STOP
B='C:\bonsai\bonsai-ada-surgery\tooling\build-p37\bin\llama-server.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File serve_raw.ps1 -Tag p41b_census -Vars 'GGML_CUDA_GRAPH_STATS=1;LLAMA_ARG_LOG_VERBOSITY=5' -Cmd "$B -m $M -c 8192 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --host 127.0.0.1 --port 8899" >/dev/null
for i in $(seq 1 90); do curl -s localhost:8899/health | grep -q ok && break; sleep 3; done
curl -s localhost:8899/completion -d '{"prompt":"Hello there, how are you","n_predict":32,"temperature":0}' > /dev/null
L="$(cygpath "$(tr -d '\r' < logs/current.log)")"; E="${L%.out.log}.err.log"; STOP
grep -A120 "cuda graph stats" "$E" | sed -E 's/^[0-9.]+ [A-Z] //' > receipts/p41b/census.txt
log census done
fi
# P43 builds
cd /c/bonsai/bonsai-ada-surgery/vendor/prism-ab314
git checkout -q ab314 && cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-ab314\build.bat' > /c/bonsai/8gb/logs/build-ab314on.log 2>&1 && rm -rf /c/bonsai/bonsai-ada-surgery/bin-ab314on && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-ab314/bin /c/bonsai/bonsai-ada-surgery/bin-ab314on
git checkout -q ab314off && cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-ab314\build.bat' > /c/bonsai/8gb/logs/build-ab314off.log 2>&1 && rm -rf /c/bonsai/bonsai-ada-surgery/bin-ab314off && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-ab314/bin /c/bonsai/bonsai-ada-surgery/bin-ab314off
for d in bin-ab314on bin-ab314off; do for f in /c/bonsai/bonsai-ada-surgery/bin-rc3/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/$d/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/$d/; done; done
cd /c/bonsai/8gb
log builds done $(ls /c/bonsai/bonsai-ada-surgery/bin-ab314on/llama-server.exe /c/bonsai/bonsai-ada-surgery/bin-ab314off/llama-server.exe 2>&1 | tr '\n' ' ')
COM="-m $M -c 16384 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --host 127.0.0.1 --port 8899"
for r in 1 2 3; do
  bash run_arm.sh receipts/p43 off_$r "" "raw:C:\bonsai\bonsai-ada-surgery\bin-ab314off\llama-server.exe $COM" "4000 16000"
  bash run_arm.sh receipts/p43 on_$r "" "raw:C:\bonsai\bonsai-ada-surgery\bin-ab314on\llama-server.exe $COM" "4000 16000"
done
log p43 done
# P44
BR='C:\bonsai\bonsai-ada-surgery\bin-rc3\llama-server.exe'
for r in 1 2; do for kv in q4_0 q8_0; do
  C2="-m $M -c 32768 -ngl 99 -fa on -np 1 -ctk $kv -ctv $kv --host 127.0.0.1 --port 8899"
  bash run_arm.sh receipts/p44 ${kv}_mma_$r "" "raw:$BR $C2" "4000 16000"
  bash run_arm.sh receipts/p44 ${kv}_nomma_$r "GGML_CUDA_FA_MMA_DECODE_MIN_KV=0" "raw:$BR $C2" "4000 16000"
done; done
log p44 done
# P42 restart-based +1000 soak
bash p42.sh > receipts/p42-run.out 2>&1
log p42 done
log end
