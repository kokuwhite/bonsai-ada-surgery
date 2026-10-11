#!/usr/bin/env bash
cd /c/bonsai/8gb
until [ -f receipts/p26/done.txt ]; do sleep 30; done
LC='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p25;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0;GGML_CUDA_FA_PREFILL_F16=65536;BONSAI_UBATCH=1024'
R=receipts/p27; mkdir -p $R
(while true; do powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\sample_mem.ps1'; sleep 3; done) >> $R/mem.txt 2>/dev/null & SP=$!
for r in 1 2; do bash run_arm.sh $R n53248_r$r "$LC;BONSAI_KV_VRAM_CELLS=53248" "" "4000 16000 32000 60000"; done
kill $SP; touch $R/done.txt
