#!/usr/bin/env bash
cd /c/bonsai/8gb
until [ -f receipts/p14c/done.txt ]; do sleep 30; done
B='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p12;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_MAX_KB=1024;BONSAI_KV_VRAM_CELLS=58112;GGML_CUDA_OP_TIMING=1;LLAMA_ARG_LOG_VERBOSITY=5'
bash run_arm.sh receipts/p16 optiming_n58112 "$B" "" "32000"
f=$(ls -t logs/*p16*optiming*.err.log 2>/dev/null | head -1); [ -z "$f" ] && f=$(ls -t logs/*optiming*.err.log | head -1)
cp "$f" receipts/p16/optiming.err.log
echo done > receipts/p16/done.txt
