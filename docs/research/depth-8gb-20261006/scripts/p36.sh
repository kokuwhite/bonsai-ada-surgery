#!/usr/bin/env bash
cd /c/bonsai/8gb
true
R=receipts/p36b; mkdir -p $R
bash run_arm.sh $R optiming_decode_nograph 'BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc2;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q4_0;BONSAI_LAYER=0;BONSAI_KV_VRAM_CELLS=53248;BONSAI_UBATCH=1024;GGML_CUDA_FA_PREFILL_F16=65536;GGML_CUDA_OP_TIMING=1;GGML_CUDA_DISABLE_GRAPHS=1;LLAMA_ARG_LOG_VERBOSITY=5' "" "4000 32000"
touch $R/done.txt
