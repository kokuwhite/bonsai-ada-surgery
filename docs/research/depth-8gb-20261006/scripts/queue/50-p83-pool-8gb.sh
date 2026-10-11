#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p83; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-0046;BONSAI_LAYER=0'
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
P="GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256"
memarm A_preset "$V" "$L" "4000 32000 64000 96000"
memarm P_pool_N52224 "$V;$P;BONSAI_KV_VRAM_CELLS=52224" "$L" "4000 32000 64000 96000"
for r in 1 2 3; do bash run_arm.sh $R fresh60k_pool_r$r "$V;$P;BONSAI_KV_VRAM_CELLS=52224" "$L" "60000"; done
{ for a in A_preset P_pool_N52224 fresh60k_pool_r1 fresh60k_pool_r2 fresh60k_pool_r3; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|mean decode|min free|did not|trace min" $f; done; } > $R/summary.txt
