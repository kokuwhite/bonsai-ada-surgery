#!/usr/bin/env bash
# P107 (#21): per-op timing at 245k, dense vs sparse (028f606fc, bin-sparse6), lookup off, f16 mask, graphs off.
# Why is sparse slower than dense at 245k (4.9 vs 5.7) but 1.9x at 160k? Which op grows with the host tail?
cd /c/bonsai/8gb; R=receipts/p107; mkdir -p $R
export QTPS_TIMEOUT=7200
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse6;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768;GGML_CUDA_OP_TIMING=1'
REST='GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
bash run_arm.sh $R dense245 "$BASEV;$REST" "$L" "245000"
bash run_arm.sh $R sparse245 "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;$REST" "$L" "245000"
for a in dense245 sparse245; do E=$(ls -t logs/*-$a.err.log | head -1)
  # the last op-timing block (decode graphs at 245k)
  awk '/op timing over/ {buf=""} {if (/op timing over/ || /ms\/graph/) buf=buf $0 "\n"} END{printf "%s", buf}' "$E" | head -30 > $R/${a}_optiming.txt; done
{ for a in dense245 sparse245; do echo "== $a: $(grep 'mean decode' $R/$a.txt)"; head -14 $R/${a}_optiming.txt | sed -E 's/^[0-9.]+ W +//'; done; } > $R/summary.txt
