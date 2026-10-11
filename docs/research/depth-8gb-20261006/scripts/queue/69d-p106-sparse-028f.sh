#!/usr/bin/env bash
# P106 (#21): fa-sparse-proto 028f606fc (vec kernel warp skip of fully masked 32-cell groups, for 2-query decode).
# 1. test-backend-ops FLASH_ATTN_EXT.  2. the 8 GB 512-token prefill halving: arms at 64k -> 160k (one server each):
#    (a) full sparse env + GGML_CUDA_OP_TIMING=1, (b) same without GGML_CUDA_FA_SPARSE, (c) full + SPARSE_NOTRACK=1.
# 3. decode at 245k, sparse lookup off (P102: dense 5.7; P102e: sparse 4.3 on d6c6e9f01).
cd /c/bonsai/8gb; R=receipts/p106; mkdir -p $R
export QTPS_TIMEOUT=7200
rm -rf /c/bonsai/bonsai-ada-surgery/bin-sparse6 && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-sparse/bin /c/bonsai/bonsai-ada-surgery/bin-sparse6
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-sparse6/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-sparse6/; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
/c/bonsai/bonsai-ada-surgery/bin-sparse6/test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 < /dev/null 2>&1 | grep -E "tests passed|FAIL" | tail -5 > $R/tests.txt
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse6;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768'
REST='GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
bash run_arm.sh $R a_sparse "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;$REST;GGML_CUDA_OP_TIMING=1" "$L" "64000 160000"
bash run_arm.sh $R b_nosparse "$BASEV;$REST" "$L" "64000 160000"
bash run_arm.sh $R c_notrack "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;$REST;GGML_CUDA_FA_SPARSE_NOTRACK=1" "$L" "64000 160000"
E=$(ls -t logs/*-a_sparse.err.log | head -1); grep -A40 -iE "op timing|OP_TIMING" "$E" | tail -120 > $R/a_optiming.txt
bash run_arm.sh $R decode245_sparse "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;$REST" "$L" "245000"
{ cat $R/tests.txt; for a in a_sparse b_nosparse c_notrack decode245_sparse; do f=$R/$a.txt; E=$(ls -t logs/*-$a.err.log | head -1)
    echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "depth|mean decode|did not|rror" $f | sed -E 's/ttft +[0-9.]+s +//'
    echo "   sync warnings $(grep -c 'one sync per K write' $E)"; grep -E "FA_SPARSE.*fast:" $E | tail -1 | cut -c1-170; done
  echo "-- op timing block (arm a): receipts/p106/a_optiming.txt ($(wc -l < $R/a_optiming.txt) lines)"; } > $R/summary.txt
