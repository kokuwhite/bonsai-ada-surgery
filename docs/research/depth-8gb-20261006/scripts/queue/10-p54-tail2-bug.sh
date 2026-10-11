#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p54; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-lookup;BONSAI_LAYER=0;BONSAI_LOOKUP=0'
for i in 1 2 3; do
  bash run_arm.sh $R t2cache_r$i "$V;BONSAI_SPEC_DEEP=2;BONSAI_KV_VRAM_CELLS=40960" "$L" "4000 16000 32000"
  bash run_arm.sh $R t2nocache_r$i "$V;BONSAI_SPEC_DEEP=2;BONSAI_KV_VRAM_CELLS=40960;LLAMA_ARG_CACHE_RAM=0" "$L" "4000 16000 32000"
  bash run_arm.sh $R t1_r$i "$V;BONSAI_SPEC_DEEP=1;BONSAI_KV_VRAM_CELLS=51200" "$L" "4000 16000 32000"
done
for f in $R/t*_r*.txt; do echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token answers of $(grep -cE '^(code|prose|bash) +depth' $f)"; done > $R/summary.txt
