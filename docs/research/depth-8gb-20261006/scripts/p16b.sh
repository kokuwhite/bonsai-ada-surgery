#!/usr/bin/env bash
cd /c/bonsai/8gb
until grep -q "^done" receipts/p18/summary.txt 2>/dev/null; do sleep 30; done
B='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p12;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_MAX_KB=1024;BONSAI_KV_VRAM_CELLS=67840;GGML_CUDA_OP_TIMING=1;LLAMA_ARG_LOG_VERBOSITY=5'
bash run_arm.sh receipts/p16b optiming60k "$B" "" "60000"
f=$(ls -t logs/*optiming60k*.err.log | head -1); grep -A31 "op timing over" "$f" > receipts/p16b/table.txt
echo done >> receipts/p16b/table.txt
