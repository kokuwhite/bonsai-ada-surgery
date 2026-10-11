#!/usr/bin/env bash
# P35: draft 1/2/3 below the VRAM line, tail 1. Do not edit while running.
cd /c/bonsai/8gb
R=receipts/p35; mkdir -p $R
COM='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc2;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC_DEEP=1;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256;GGML_CUDA_FA_PREFILL_F16=32768'
D="4000 16000 32000 60000"
bash run_arm.sh $R d1_a "$COM;BONSAI_SPEC=1;BONSAI_KV_VRAM_CELLS=47360" "" "$D"
bash run_arm.sh $R d2 "$COM;BONSAI_SPEC=2;BONSAI_KV_VRAM_CELLS=37120" "" "$D"
bash run_arm.sh $R d3 "$COM;BONSAI_SPEC=3;BONSAI_KV_VRAM_CELLS=26880" "" "$D"
bash run_arm.sh $R d1_b "$COM;BONSAI_SPEC=1;BONSAI_KV_VRAM_CELLS=47360" "" "$D"
echo "one-token answers: $(cat $R/d*.txt | grep -c '(1 tok)')" > $R/summary.txt
echo done >> $R/summary.txt
