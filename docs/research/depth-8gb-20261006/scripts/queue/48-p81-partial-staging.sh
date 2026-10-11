#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p81; mkdir -p $R
until grep -q "pstage exit 0" receipts/build_ahead.log; do grep -q "pstage exit [1-9]" receipts/build_ahead.log && { echo "build failed" > $R/summary.txt; exit 1; }; sleep 60; done
rm -rf /c/bonsai/bonsai-ada-surgery/bin-pstage && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-pstage/bin /c/bonsai/bonsai-ada-surgery/bin-pstage
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-pstage/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-pstage/; done
T=/c/bonsai/bonsai-ada-surgery/bin-pstage/test-backend-ops.exe
$T -o FLASH_ATTN_EXT -b CUDA0 2>&1 | grep -E "tests passed|FAIL" | tail -3 > $R/tests.txt
L='C:/bonsai/bonsai-ada-surgery/start-server-pstage.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-pstage;BONSAI_LAYER=0'
D="4000 32000 64000 96000 128000"
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
memarm A_131k_preset "$V" "$L" "$D"
memarm F_131k_decdirect "$V;BONSAI_KV_VRAM_CELLS=50176;GGML_CUDA_KV_TIER_STAGE_MIN_Q=2" "$L" "$D"
memarm G_131k_stage40k "$V;BONSAI_STAGE_CELLS=40960" "$L" "$D"
memarm D_262k_stage81k "$V;BONSAI_CTX=262144;BONSAI_STAGE_CELLS=80896" "$L" "$D 160000"
{ cat $R/tests.txt; for a in A_131k_preset F_131k_decdirect G_131k_stage40k D_262k_stage81k; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|prose  depth|mean decode|min free|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'; grep -h "kv     " logs/*$a*.out.log 2>/dev/null | tail -3; grep -ho "staging buffer.*" logs/*$a*.err.log 2>/dev/null | sort -u | head -4; done; } > $R/summary.txt
