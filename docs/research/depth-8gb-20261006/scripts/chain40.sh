#!/usr/bin/env bash
cd /c/bonsai/8gb
until grep -q done receipts/p39c/compare.txt 2>/dev/null; do sleep 30; done
# P41 census
mkdir -p receipts/p41
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
B='C:\bonsai\bonsai-ada-surgery\tooling\build-p37\bin\llama-server.exe'; M='C:\bonsai\bonsai-ada-surgery\models\Ternary-Bonsai-2-27B-PTQ1_0.gguf'
powershell -NoProfile -ExecutionPolicy Bypass -File serve_raw.ps1 -Tag p41_census -Vars 'GGML_CUDA_GRAPH_STATS=1' -Cmd "$B -m $M -c 8192 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --host 127.0.0.1 --port 8899" >/dev/null
for i in $(seq 1 90); do curl -s localhost:8899/health | grep -q ok && break; sleep 3; done
curl -s localhost:8899/completion -d '{"prompt":"Hello there, how are you","n_predict":32,"temperature":0}' > /dev/null
L="$(cygpath "$(tr -d '\r' < logs/current.log)")"; E="${L%.out.log}.err.log"
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
grep -A80 "cuda graph stats" "$E" | sed -E 's/^[0-9.]+ [A-Z] //' > receipts/p41/census.txt
# P40 deep end
L8='C:\bonsai\bonsai-ada-surgery\start-server-8gbtest.ps1'
bash run_arm.sh receipts/p40 drafting_deep 'BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0' "$L8" "4000 32000 64000 96000 126000"
bash run_arm.sh receipts/p40 long_deep 'BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf' "$L8" "4000 32000 64000 96000 126000"
touch receipts/p40/done.txt
