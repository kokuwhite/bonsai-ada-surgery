#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p80; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-0046;BONSAI_LAYER=0;BONSAI_CTX=262144;GGML_CUDA_KV_TIER_STAGING=0'
memarm tail1 "$V;BONSAI_SPEC_DEEP=1;BONSAI_KV_VRAM_CELLS=54784" "$L" "64000 200000"
memarm tail2 "$V;BONSAI_SPEC_DEEP=2;BONSAI_KV_VRAM_CELLS=46080" "$L" "64000 200000"
{ for f in $R/tail1.txt $R/tail2.txt; do echo "== $(basename $f .txt): $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|accept|min free|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'; done; } > $R/summary.txt
