#!/usr/bin/env bash
cd /c/bonsai/8gb
until grep -q "p17 done" receipts/p17/p17.txt 2>/dev/null; do sleep 30; done
B='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p12;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_MAX_KB=1024'
R=receipts/p14c
bash run_arm.sh $R n67840_ub512 "$B;BONSAI_KV_VRAM_CELLS=67840" "" "4000 32000"
bash run_arm.sh $R n77568_ub256 "$B;BONSAI_KV_VRAM_CELLS=77568;BONSAI_UBATCH=256" "" "4000 32000"
bash run_arm.sh $R n77568_ub512 "$B;BONSAI_KV_VRAM_CELLS=77568" "" "4000 32000"
bash run_arm.sh $R n58112_ub512 "$B;BONSAI_KV_VRAM_CELLS=58112" "" "4000 32000"
echo done > $R/done.txt
