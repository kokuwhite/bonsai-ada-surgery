#!/usr/bin/env bash
# P102d: which path makes "set_rows indices are not a host-set input: one sync per K write" on the 2060 (P102c)?
# Arms at 245k, lookup off, bin-sparse3 (ae61c4cf3): dense no-MTP (baseline), s8192 no-MTP (BONSAI_SPEC=0),
# s8192 with MTP but the tier write redirect off (GGML_CUDA_KV_TIER_REDIRECT=0).
cd /c/bonsai/8gb; R=receipts/p102d; mkdir -p $R
export QTPS_TIMEOUT=7200
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse3;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768'
SP='GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
bash run_arm.sh $R dense_nospec "$BASEV;BONSAI_SPEC=0" "$L" "245000"
bash run_arm.sh $R s8192_nospec "$BASEV;BONSAI_SPEC=0;$SP" "$L" "245000"
bash run_arm.sh $R s8192_noredirect "$BASEV;GGML_CUDA_KV_TIER_REDIRECT=0;$SP" "$L" "245000"
{ for a in dense_nospec s8192_nospec s8192_noredirect; do f=$R/$a.txt; E=$(ls -t logs/*-$a.err.log | head -1)
    echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|accept|did not|rror" $f | sed -E 's/ttft +[0-9.]+s +//'
    echo "   sync-per-write warning lines: $(grep -c 'one sync per K write' $E)"; grep -E "FA_SPARSE.*fast:" $E | tail -1 | cut -c1-200; done; } > $R/summary.txt
