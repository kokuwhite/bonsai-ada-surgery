#!/usr/bin/env bash
# P109 (#21): is the sparse 8 GB slowdown VRAM over-commit?
# Found 2026-10-11 by the record writer: every sparse arm in P102-P106 ends with nvidia-smi memory.free wrapped
# (4194274-4194296 = -8 to -30 MiB, i.e. used > total: WDDM over-commit), every dense arm ends with 107-124 MiB free.
# On WDDM, over-commit spills to system memory, so the cost would grow with depth (245k worse than 160k) and would
# hit the 8 GB recipe only (the 4070 has headroom): it fits both open items (245k sparse < dense; follow-up prefill drop).
# Arms: the P106 env (028f606fc, bin-sparse6, lookup off, f16 mask, graphs off), BONSAI_VRAM_MARGIN=425
# (launcher default with drafting is 225: +200 MiB, about -11k VRAM cells), sparse at 160k + 245k, dense at 245k.
# Gate (declared here, before the run): over-commit is the cause if sparse with the margin ends with free > 0 AND
# (245k sparse decode > the same-margin dense 245k OR the 160k 512-token follow-up prefill recovers to >= 100 tok/s,
# P106 dense 107, sparse 85).
cd /c/bonsai/8gb; R=receipts/p109; mkdir -p $R
export QTPS_TIMEOUT=7200
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse6;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768;BONSAI_VRAM_MARGIN=425'
REST='GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
bash run_arm.sh $R sparse_m425 "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;$REST" "$L" "160000 245000"
bash run_arm.sh $R dense_m425 "$BASEV;$REST" "$L" "245000"
{ for a in sparse_m425 dense_m425; do f=$R/$a.txt; E=$(ls -t logs/*-$a.err.log | head -1); O="${E%err.log}out.log"
    echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "depth|mean decode|did not|rror|min free" $f | sed -E 's/ttft +[0-9.]+s +//'
    grep -hiE "kv tier|vram cells|tier cells|kv staging" "$O" "$E" 2>/dev/null | head -3; done; } > $R/summary.txt
