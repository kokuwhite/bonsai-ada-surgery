#!/usr/bin/env bash
# P102e: sparse decode speed at 245k on fa-sparse-proto c803e03ea: set_rows index copies without sync (2f47c38b7),
# MMA tile skip (GGML_CUDA_FA_TILE_SKIP=1, 03d904ac4 / 615b93cb7), optional SINKS (selection over the VRAM part too).
# Dense baselines: P102 (lookup off 5.7) and P102c (lookup on 5.7).
cd /c/bonsai/8gb; R=receipts/p102e; mkdir -p $R
export QTPS_TIMEOUT=7200
rm -rf /c/bonsai/bonsai-ada-surgery/bin-sparse4 && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-sparse/bin /c/bonsai/bonsai-ada-surgery/bin-sparse4
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-sparse4/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-sparse4/; done
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse4;BONSAI_LAYER=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768;GGML_CUDA_FA_TILE_SKIP=1'
SP='GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
bash run_arm.sh $R s8192_lkoff "$BASEV;BONSAI_LOOKUP=0;$SP" "$L" "245000"
bash run_arm.sh $R s8192_lkon "$BASEV;$SP" "$L" "245000"
bash run_arm.sh $R s8192_sinks_lkoff "$BASEV;BONSAI_LOOKUP=0;$SP;GGML_CUDA_FA_SPARSE_SINKS=4096" "$L" "245000"
{ for a in s8192_lkoff s8192_lkon s8192_sinks_lkoff; do f=$R/$a.txt; E=$(ls -t logs/*-$a.err.log | head -1)
    echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|accept|did not|rror" $f | sed -E 's/ttft +[0-9.]+s +//'
    echo "   sync-per-write warning lines: $(grep -c 'one sync per K write' $E)"; grep -E "FA_SPARSE.*fast:" $E | tail -1 | cut -c1-220; done
  echo "-- dense 245k: lookup off 5.7 (P102), lookup on 5.7 (P102c); 512-token prefill 79"; } > $R/summary.txt
