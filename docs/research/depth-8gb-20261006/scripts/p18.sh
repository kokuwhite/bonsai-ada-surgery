#!/usr/bin/env bash
cd /c/bonsai/8gb
until [ -f receipts/p16/done.txt ]; do sleep 30; done
COM='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p12;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_MAX_KB=1024;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256'
R=receipts/p18
for i in 1 2 3; do
  bash run_arm.sh $R t1_r$i "$COM;BONSAI_SPEC_DEEP=1;BONSAI_KV_VRAM_CELLS=47360" "" "4000 16000 32000"
  bash run_arm.sh $R t2_r$i "$COM;BONSAI_SPEC_DEEP=2;BONSAI_KV_VRAM_CELLS=38400" "" "4000 16000 32000"
done
for f in $R/t*_r*.txt; do echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token answers of $(grep -c 'depth' $f)"; done > $R/summary.txt
echo done >> $R/summary.txt
