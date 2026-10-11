#!/usr/bin/env bash
# P98: K-first stats probe at depth. How many host cells (union over the 6 q heads x tokens of a KV head) are needed
# so the dropped softmax mass is <= eps? Output unchanged (probe only). Chunked prefill on so the deep steps finish.
cd /c/bonsai/8gb; R=receipts/p98; mkdir -p $R
export QTPS_TIMEOUT=7200
rm -rf /c/bonsai/bonsai-ada-surgery/bin-kfirst && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-kfirst/bin /c/bonsai/bonsai-ada-surgery/bin-kfirst
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-kfirst/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-kfirst/; done
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-kfirst;BONSAI_LAYER=0;GGML_CUDA_FA_CHUNK=32768;GGML_CUDA_KV_TIER_KFIRST_STATS=1;GGML_CUDA_KV_TIER_KFIRST_EVERY=16'
bash run_arm.sh $R probe "$V" "$L" "64000 128000 192000 250000"
E=$(ls -t logs/*-probe.err.log | head -1)
grep -E "kfirst" "$E" > $R/kfirst_lines.txt
{ echo "== probe: $(grep -c '(1 tok)' $R/probe.txt) one-token"; grep -E "loaded|depth|mean decode|did not|rror" $R/probe.txt | sed -E 's/ttft +[0-9.]+s +//';
  echo "-- kfirst-sum lines: $(grep -c 'kfirst-sum' $R/kfirst_lines.txt), op lines: $(grep -c 'kfirst op' $R/kfirst_lines.txt)";
  grep "kfirst-sum" $R/kfirst_lines.txt | tail -32; grep -iE "skip|fail|warn" $R/kfirst_lines.txt | grep -v "kfirst op\|kfirst-sum" | head -5; } > $R/summary.txt
