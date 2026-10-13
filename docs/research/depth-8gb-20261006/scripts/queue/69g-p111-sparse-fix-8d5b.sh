#!/usr/bin/env bash
# P111 (#21, the 4070's request "P110" on 2026-10-13; renamed: P110 = the post-move smoke): P107 on 8d5b862fc.
# Build: 3299a0b4b = 8d5b862fc + GGML_CUDA_FA_SPARSE_MIN_HOST (unset here = off, so the same code path as 8d5b862fc).
# 8d5b862fc = 028f606fc + sparse page bounds in f16 (1 KiB per host cell) + first fill in chunks of
# GGML_CUDA_FA_SPARSE_FILL_CELLS (16384): sparse-only VRAM at 245k ~230 MiB (was up to ~780 MiB, the P107 over-commit).
# Until the launcher counts it: BONSAI_VRAM_MARGIN=475 (225 + ~230 + slack) in BOTH arms (same VRAM line).
# Arms (one server each, 160k cold then extend to 245k): dense, sparse; OP_TIMING; nvidia-smi trace every 10 s.
# Gate (declared here, before the run; from the 4070's #21 request): sparse trace min free > 0 MiB for the whole arm,
# AND the ternary mat-vec MUL_MAT 17408x5120 in the sparse arm <= 1.1x the dense arm's time, AND the 160k 512-token
# follow-up prefill in the sparse arm >= 100 tok/s (P106: dense 107, sparse 85). Report 245k decode sparse vs dense.
# FLASH_ATTN_EXT op tests must pass first (else stop).
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p111; mkdir -p $R
for i in $(seq 1 240); do [ -f receipts/build-sparse7.txt ] && break; sleep 30; done   # the build runs beside P108
grep -q "build ok" receipts/build-sparse7.txt 2>/dev/null || { echo "build of 8d5b862fc not ok: $(cat receipts/build-sparse7.txt 2>/dev/null)" > $R/summary.txt; exit 1; }
B=/c/bonsai/bonsai-ada-surgery/bin-sparse7
rm -rf $B && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-sparse/bin $B
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f $B/$b ] || cp $f $B/; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
$B/test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 < /dev/null 2>&1 | grep -E "tests passed|FAIL" | tail -5 > $R/tests.txt
grep -q "FAIL" $R/tests.txt && { echo "op tests FAIL"; cat $R/tests.txt; } > $R/summary.txt && exit 1
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse7;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768;GGML_CUDA_OP_TIMING=1;BONSAI_VRAM_MARGIN=475;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
arm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.trace.txt & MP=$!
  bash run_arm.sh $R "$@"; kill $MP
  E=$(ls -t logs/*-$1.err.log | head -1)
  awk '/op timing over/ {buf=""} {if (/op timing over/ || /ms\/graph/) buf=buf $0 "\n"} END{printf "%s", buf}' "$E" | head -30 > $R/$1_optiming.txt
  awk -F', ' '{split($1,a," "); v=$2+0; if (v>4000000) v-=4194304; if (NR==1||v<m) {m=v; t=a[1]}} END{print "trace min free", m, "MiB at", t, "over", NR, "samples"}' $R/$1.trace.txt >> $R/$1.txt; }
arm dense_m475 "$BASEV" "$L" "160000 245000"
arm sparse_m475 "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024" "$L" "160000 245000"
{ cat $R/tests.txt; for a in dense_m475 sparse_m475; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"
    grep -E "loaded|depth|mean decode|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'
    head -10 $R/${a}_optiming.txt | sed -E 's/^[0-9.]+ W +//'; done; } > $R/summary.txt
