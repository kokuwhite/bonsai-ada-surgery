#!/usr/bin/env bash
# P112 (#21): the sparse depth threshold GGML_CUDA_FA_SPARSE_MIN_HOST (3299a0b4b, bin-sparse7): dense while the host
# tail has fewer than N cells. Sparse cost ~16 % at 64k on 8 GB (P106: 34.5 dense vs 29.0 sparse; host tail ~18k cells)
# and gave 1.9x at 160k (host tail ~114k cells). N = 32768: 64k stays dense, 160k and deeper go sparse.
# Same env as P111 (margin 475, lookup off, f16 mask, graphs off, no OP_TIMING). Arms, one server each, 64k -> 160k:
#   dense, sparse + MIN_HOST=32768.
# Gate (declared here, before the run): 64k sparse+threshold decode within 2 % of dense; 160k >= 1.7x dense;
# 0 one-token; trace min free > 0 MiB in both arms. Runs after P111; if P111 failed its free-VRAM gate, read with care.
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p112; mkdir -p $R
B=/c/bonsai/bonsai-ada-surgery/bin-sparse7
[ -f $B/llama-server.exe ] || { echo "no bin-sparse7 (P111 makes it)" > $R/summary.txt; exit 1; }
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse7;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768;BONSAI_VRAM_MARGIN=475;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
arm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.trace.txt & MP=$!
  bash run_arm.sh $R "$@"; kill $MP
  awk -F', ' '{split($1,a," "); v=$2+0; if (v>4000000) v-=4194304; if (NR==1||v<m) {m=v; t=a[1]}} END{print "trace min free", m, "MiB at", t, "over", NR, "samples"}' $R/$1.trace.txt >> $R/$1.txt; }
arm dense "$BASEV" "$L" "64000 160000"
arm sparse_mh32k "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_MIN_HOST=32768" "$L" "64000 160000"
{ for a in dense sparse_mh32k; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"
    grep -E "loaded|depth|mean decode|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'; done; } > $R/summary.txt
