#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p55b; mkdir -p $R
B='C:\bonsai\bonsai-ada-surgery\tooling\build-p55\bin\llama-server.exe'; MD='C:/bonsai/bonsai-ada-surgery/models'
census() { # tag model extra
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  powershell -NoProfile -ExecutionPolicy Bypass -File serve_raw.ps1 -Tag p55_$1 -Vars 'GGML_CUDA_GRAPH_STATS=1;LLAMA_ARG_LOG_VERBOSITY=5' -Cmd "$B -m $MD/$2 -c 8192 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --host 127.0.0.1 --port 8899 $3" >/dev/null
  for i in $(seq 1 90); do curl -s localhost:8899/health | grep -q ok && break; sleep 3; done
  curl -s localhost:8899/completion -d '{"prompt":"Write a short story about a lighthouse keeper.","n_predict":64,"temperature":0}' > /dev/null
  L="$(cygpath "$(tr -d '\r' < logs/current.log)")"; E="${L%.out.log}.err.log"
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  grep -A60 "cuda graph stats" "$E" | sed -E 's/^[0-9.]+ [A-Z] //' > $R/census_$1.txt
}
census plain Ternary-Bonsai-2-27B-PTQ1_0.gguf ""
census mtp Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf "--spec-type draft-mtp --spec-draft-n-max 1 -ctkd q4_0 -ctvd q4_0"
