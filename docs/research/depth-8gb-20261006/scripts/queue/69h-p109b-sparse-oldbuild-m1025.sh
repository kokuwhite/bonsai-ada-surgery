#!/usr/bin/env bash
# P109b (#21): the over-commit cause on the OLD build, with enough margin. P109 (margin 425) was stopped twice with no
# result and is superseded: the 4070 measured the sparse-only VRAM of 028f606fc as up to ~446 MiB at 160k and ~780 MiB
# at 245k (page-bound tables f32 + a whole-tail first fill), so +200 could not settle it.
# Arm: bin-sparse6 (028f606fc, the P107 build), BONSAI_VRAM_MARGIN=1025 (225 + ~800), sparse, 160k cold -> 245k,
# OP_TIMING, nvidia-smi trace every 10 s. Compare the ternary mat-vecs with P107 dense245 (2.625 ms/graph for
# MUL_MAT 17408x5120) and P111 dense_m475.
# Gate (declared here, before the run): the cause is confirmed on the old build if trace min free > 0 for the whole arm
# AND MUL_MAT 17408x5120 <= 1.1x the dense time (P107 dense 2.625 ms/graph). If it still wraps or stays slow, the
# cause is something else (then P111 alone is not proof either).
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p109b; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse6;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768;GGML_CUDA_OP_TIMING=1;BONSAI_VRAM_MARGIN=1025;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9;GGML_CUDA_FA_SPARSE=8192,64,1024'
( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/sparse_m1025.trace.txt & MP=$!
bash run_arm.sh $R sparse_m1025 "$V" "$L" "160000 245000"; kill $MP
E=$(ls -t logs/*-sparse_m1025.err.log | head -1)
awk '/op timing over/ {buf=""} {if (/op timing over/ || /ms\/graph/) buf=buf $0 "\n"} END{printf "%s", buf}' "$E" | head -30 > $R/sparse_m1025_optiming.txt
awk -F', ' '{split($1,a," "); v=$2+0; if (v>4000000) v-=4194304; if (NR==1||v<m) {m=v; t=a[1]}} END{print "trace min free", m, "MiB at", t, "over", NR, "samples"}' $R/sparse_m1025.trace.txt >> $R/sparse_m1025.txt
{ f=$R/sparse_m1025.txt; echo "== sparse_m1025: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'
  head -10 $R/sparse_m1025_optiming.txt | sed -E 's/^[0-9.]+ W +//'; echo "P107 dense245 MUL_MAT 17408x5120: 2.625 ms/graph"; } > $R/summary.txt
