#!/usr/bin/env bash
# BonsaiJob5: P48. Waits for jobrun4 (P47). Do not edit while running.
cd /c/bonsai/8gb
mkdir receipts/jobrun5.lock 2>/dev/null || exit 1
trap 'rmdir receipts/jobrun5.lock' EXIT
echo "$(date +%T) start" >> receipts/jobrun5.log
until grep -q " end" receipts/jobrun4.log 2>/dev/null && [ ! -d receipts/jobrun4.lock ]; do sleep 60; done
R=receipts/p48; mkdir -p $R
B='C:\bonsai\bonsai-ada-surgery\tooling\build-p37\bin\llama-server.exe'; M='C:\bonsai\bonsai-ada-surgery\models\Ternary-Bonsai-2-27B-PTQ1_0.gguf'
COM="-m $M -c 8192 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --host 127.0.0.1 --port 8899"
texts() { for p in "Write a Python function that parses ISO 8601 durations." "Explain how a heat pump works." "Write a bash script that rotates log files."; do
  curl -s localhost:8899/completion -d "{\"prompt\":\"$p\",\"n_predict\":300,\"temperature\":0,\"cache_prompt\":false}" | python -c "import sys,json; print(json.load(sys.stdin)['content'].replace(chr(10),' '))"; done; }
for r in 1 2 3; do for f in 0 1; do
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  bash run_arm.sh $R fuse${f}_$r "GGML_CUDA_ADD_RMS_FUSE=$f" "raw:$B $COM" "4000 16000"
  powershell -NoProfile -ExecutionPolicy Bypass -File serve_raw.ps1 -Tag p48_text$f -Vars "GGML_CUDA_ADD_RMS_FUSE=$f" -Cmd "$B $COM" >/dev/null
  for i in $(seq 1 90); do curl -s localhost:8899/health | grep -q ok && break; sleep 3; done
  texts > $R/text_fuse${f}_$r.txt
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
done; done
powershell -NoProfile -ExecutionPolicy Bypass -File serve_raw.ps1 -Tag p48_census -Vars 'GGML_CUDA_ADD_RMS_FUSE=1;GGML_CUDA_GRAPH_STATS=1;LLAMA_ARG_LOG_VERBOSITY=5' -Cmd "$B $COM" >/dev/null
for i in $(seq 1 90); do curl -s localhost:8899/health | grep -q ok && break; sleep 3; done
curl -s localhost:8899/completion -d '{"prompt":"Hello there, how are you","n_predict":32,"temperature":0}' > /dev/null
L="$(cygpath "$(tr -d '\r' < logs/current.log)")"; E="${L%.out.log}.err.log"
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
grep -A40 "cuda graph stats" "$E" | sed -E 's/^[0-9.]+ [A-Z] //' > $R/census_fuse1.txt
{ grep -H "mean decode" $R/fuse*.txt | sed "s#$R/##"; echo "texts: $(md5sum $R/text_fuse*.txt | awk '{print $1}' | sort -u | wc -l) distinct md5 over 6 files"; } > $R/summary.txt
echo "$(date +%T) end" >> receipts/jobrun5.log
