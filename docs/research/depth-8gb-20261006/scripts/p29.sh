#!/usr/bin/env bash
cd /c/bonsai/8gb
DR='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p25;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_SPEC_DEEP=1;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256;BONSAI_KV_VRAM_CELLS=47360;GGML_CUDA_FA_PREFILL_F16=32768'
R=receipts/p29
for i in 1 2 3; do bash run_arm.sh $R r$i "$DR" "" "4000 16000 32000"; done
for f in $R/r*.txt; do echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token of $(grep -cE '^(code|prose|bash) +depth' $f) $(grep -E 'not stock|failed' $f)"; done > $R/summary.txt
echo done >> $R/summary.txt
