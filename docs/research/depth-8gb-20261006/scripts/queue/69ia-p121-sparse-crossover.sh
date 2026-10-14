#!/usr/bin/env bash
# P121 (#21, the 4070's request after D18): where does sparse start to win on 8 GB? (the MIN_HOST crossover)
# bin-sparse7 (3299a0b4b), margin 475 (line 34,560), lookup off, f16 mask, graphs off, no OP_TIMING. One server per arm,
# 96k then 128k (extends). Arms: dense; sparse with MIN_HOST=0 (always sparse when there is a host tail).
# Note: P118 found an always-on cost of FA_SPARSE inside FLASH_ATTN_EXT (+15 ms per graph at 64k). It is in the sparse
# arm here too, so this crossover is for today's build; it moves lower when that routing is fixed.
# Reading (declared before the run, no pass/fail): decode ratio sparse / dense at 96k and 128k, with P115 (64k never-sparse
# 22.8 vs 28.7, so sparse loses there) and P112 (160k 19.6 vs 9.1). Recommend MIN_HOST = host tail at the first depth where
# sparse >= 1.05x dense.
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p121; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse7;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768;BONSAI_VRAM_MARGIN=475;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
arm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.trace.txt & MP=$!
  bash run_arm.sh $R "$@"; kill $MP
  awk -F', ' '{split($1,a," "); v=$2+0; if (v>4000000) v-=4194304; if (NR==1||v<m) {m=v; t=a[1]}} END{print "trace min free", m, "MiB at", t, "over", NR, "samples"}' $R/$1.trace.txt >> $R/$1.txt
  E=$(ls -t logs/*-$1.err.log | head -1); echo "sparse_mask lines: $(grep -c ggml_cuda_fa_sparse_mask "$E")" >> $R/$1.txt; }
arm dense "$BASEV" "$L" "96000 128000"
arm sparse0 "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_MIN_HOST=0" "$L" "96000 128000"
{ for a in dense sparse0; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"
    grep -E "loaded|depth|mean decode|did not|trace min|sparse_mask lines" $f | sed -E 's/ttft +[0-9.]+s +//'; done
  echo "P115 64k: dense 28.7, never-sparse 22.8; P112 160k: dense 9.1, sparse 19.6"; } > $R/summary.txt
