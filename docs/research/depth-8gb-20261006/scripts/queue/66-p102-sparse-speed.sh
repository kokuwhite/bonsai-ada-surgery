#!/usr/bin/env bash
# P102: sparse host-tail reads - decode SPEED at 245k on 8 GB. Lookup off (BONSAI_LOOKUP=0) so every decode op has
# <= 2 queries (MTP draft 1) and takes the FAST sparse path; P101's code items ran lookup verifies of 10-33 queries,
# which the fast path does not cover. Same base env as P101 (f16 mask, graphs off, chunked prefill).
cd /c/bonsai/8gb; R=receipts/p102; mkdir -p $R
export QTPS_TIMEOUT=7200
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768'
bash run_arm.sh $R dense "$BASEV" "$L" "245000"
bash run_arm.sh $R s8192 "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9" "$L" "245000"
bash run_arm.sh $R s8192_staged "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_FAST=1" "$L" "245000"
{ for a in dense s8192 s8192_staged; do echo "== $a: $(grep -c '(1 tok)' $R/$a.txt) one-token"; grep -E "loaded|depth|mean decode|accept|did not|rror" $R/$a.txt | sed -E 's/ttft +[0-9.]+s +//'; done; } > $R/summary.txt
