#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p76; mkdir -p $R
until grep -q "fuse exit 0" receipts/build_ahead.log; do grep -q "fuse exit [1-9]" receipts/build_ahead.log && { echo "build failed" > $R/summary.txt; exit 1; }; sleep 60; done
rm -rf /c/bonsai/bonsai-ada-surgery/bin-fuse && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-fuse/bin /c/bonsai/bonsai-ada-surgery/bin-fuse
for f in /c/bonsai/bonsai-ada-surgery/bin-8gbfix/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-fuse/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-fuse/; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
T=/c/bonsai/bonsai-ada-surgery/bin-fuse/test-backend-ops.exe
for o in MUL_MAT GLU MUL_MAT_VEC_FUSION; do echo "$o: $($T -o $o -b CUDA0 2>&1 | grep -E 'tests passed|not supported' | tail -1 | tr -d '\r')" >> $R/tests.txt; done
B='C:\bonsai\bonsai-ada-surgery\bin-fuse\llama-server.exe'; M='C:/bonsai/bonsai-ada-surgery/models/Ternary-Bonsai-2-27B-PTQ1_0.gguf'
COM="-m $M -c 8192 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --host 127.0.0.1 --port 8899"
texts() { for p in "Write a Python function that parses ISO 8601 durations." "Explain how a heat pump works." "Write a bash script that rotates log files."; do
  curl -s localhost:8899/completion -d "{\"prompt\":\"$p\",\"n_predict\":300,\"temperature\":0,\"cache_prompt\":false}" | python -c "import sys,json,hashlib; print(hashlib.sha256(json.load(sys.stdin)['content'].encode()).hexdigest()[:12])"; done; }
for f in 1 0; do
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  powershell -NoProfile -ExecutionPolicy Bypass -File serve_raw.ps1 -Tag p76_census$f -Vars "GGML_CUDA_GLU_ALIAS_FUSE=$f;GGML_CUDA_GRAPH_STATS=1;LLAMA_ARG_LOG_VERBOSITY=5" -Cmd "$B $COM" >/dev/null
  for i in $(seq 1 90); do curl -s localhost:8899/health | grep -q ok && break; sleep 3; done
  texts > $R/text_$f.txt
  L="$(cygpath "$(tr -d '\r' < logs/current.log)")"; grep -A45 "cuda graph stats (#2)" "${L%.out.log}.err.log" | sed -E 's/^[0-9.]+ [A-Z] //' | head -30 > $R/census_$f.txt
done
for r in 1 2 3; do for f in 1 0; do
  bash run_arm.sh $R tps_f${f}_r$r "GGML_CUDA_GLU_ALIAS_FUSE=$f" "raw:$B $COM" "4000"
done; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ cat $R/tests.txt; echo "texts identical: $(cmp -s $R/text_1.txt $R/text_0.txt && echo yes || echo NO)"; for f in 1 0; do echo "census f$f: $(head -1 $R/census_$f.txt) | gate-fused: $(grep -c 'ptILi1ELi4ELb1ELb1E' $R/census_$f.txt) lines, $(grep 'ptILi1ELi4ELb1ELb1E' $R/census_$f.txt | awk '{print $1}')"; done; grep -H "mean decode" $R/tps_*.txt | sed "s#$R/##"; } > $R/summary.txt
