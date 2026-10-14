#!/usr/bin/env bash
# P118 (#21): which op carries the -20.6 % that FA_SPARSE costs at 64k with no sparse op (P115 dense64 28.7 vs never64
# 22.8)? Same env as P115 + GGML_CUDA_OP_TIMING=1; arms dense64 and never64 (FA_SPARSE=8192,64,1024 + MIN_HOST=1e9).
# Reading (declared before the run, no pass/fail): the op(s) whose ms/graph differ by more than 1 ms between the arms.
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p118; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse7;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768;BONSAI_VRAM_MARGIN=475;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9;GGML_CUDA_OP_TIMING=1'
for a in dense64 never64; do
  V="$BASEV"; [ $a = never64 ] && V="$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_MIN_HOST=1000000000"
  bash run_arm.sh $R $a "$V" "$L" "64000"
  E=$(ls -t logs/*-$a.err.log | head -1)
  awk '/op timing over/ {buf=""} {if (/op timing over/ || /ms\/graph/) buf=buf $0 "\n"} END{printf "%s", buf}' "$E" | head -40 | sed -E 's/^[0-9.]+ W +//' > $R/${a}_optiming.txt
done
{ for a in dense64 never64; do echo "== $a: $(grep 'mean decode' $R/$a.txt)"; head -16 $R/${a}_optiming.txt; done; } > $R/summary.txt
