#!/usr/bin/env bash
# P115 (#21): (1) isolate the -20 % at 64k that P112 found with GGML_CUDA_FA_SPARSE set but no sparse op run;
# (2) the clean 245k sparse decode (P111 had OP_TIMING on: 11.6 vs 5.2 dense).
# Same env as P111 / P112 (bin-sparse7 = 3299a0b4b, margin 475 -> line 34,560, lookup off, f16 mask, graphs off).
# Arms (one server each): dense64 (64k); never64 (64k, FA_SPARSE=8192,64,1024 + MIN_HOST=1000000000: sparse never
# runs); sparse245 (245k cold, FA_SPARSE + MIN_HOST=32768, no OP_TIMING); dense245 (245k cold, no OP_TIMING).
# Gate / reading (declared here, before the run): if never64 is >= 5 % below dense64, the 64k cost is an always-on
# overhead of FA_SPARSE (engine fix on the 4070), not sparse selection. sparse245 vs dense245: report (expect >= 2x).
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p115; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse7;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768;BONSAI_VRAM_MARGIN=475;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
SP='GGML_CUDA_FA_SPARSE=8192,64,1024'
arm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.trace.txt & MP=$!
  bash run_arm.sh $R "$@"; kill $MP
  awk -F', ' '{split($1,a," "); v=$2+0; if (v>4000000) v-=4194304; if (NR==1||v<m) {m=v; t=a[1]}} END{print "trace min free", m, "MiB at", t, "over", NR, "samples"}' $R/$1.trace.txt >> $R/$1.txt
  E=$(ls -t logs/*-$1.err.log | head -1); echo "sparse_mask lines: $(grep -c ggml_cuda_fa_sparse_mask "$E")" >> $R/$1.txt; }
arm dense64 "$BASEV" "$L" "64000"
arm never64 "$BASEV;$SP;GGML_CUDA_FA_SPARSE_MIN_HOST=1000000000" "$L" "64000"
arm sparse245 "$BASEV;$SP;GGML_CUDA_FA_SPARSE_MIN_HOST=32768" "$L" "245000"
arm dense245 "$BASEV" "$L" "245000"
{ for a in dense64 never64 sparse245 dense245; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"
    grep -E "loaded|depth|mean decode|did not|trace min|sparse_mask lines" $f | sed -E 's/ttft +[0-9.]+s +//'; done; } > $R/summary.txt
