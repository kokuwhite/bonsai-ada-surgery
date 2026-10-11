#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p77; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-0046;BONSAI_LAYER=0'
D="4000 32000 64000 96000 128000"
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
memarm A_131k_preset "$V" "$L" "$D"
memarm B_131k_nostage "$V;GGML_CUDA_KV_TIER_STAGING=0;BONSAI_KV_VRAM_CELLS=54784" "$L" "$D"
memarm C_262k_nostage "$V;BONSAI_CTX=262144;GGML_CUDA_KV_TIER_STAGING=0;BONSAI_KV_VRAM_CELLS=54784" "$L" "$D"
{ for f in $R/A_131k_preset.txt $R/B_131k_nostage.txt $R/C_262k_nostage.txt; do echo "== $(basename $f .txt): $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|code   depth|mean decode|min free|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'; done; } > $R/summary.txt
