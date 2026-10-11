#!/usr/bin/env bash
# P28: final verification of RC2 (both modes). After the RC2 build. Do not edit while running.
cd /c/bonsai/8gb
until grep -q "build-rc2 exit" logs/build-rc2.log 2>/dev/null; do sleep 30; done
R=receipts/p28; mkdir -p $R
grep -q "build-rc2 exit 0" logs/build-rc2.log && [ -f /c/bonsai/bonsai-ada-surgery/bin-rc2/llama-server.exe ] || { echo "no bin-rc2" > $R/failed.txt; exit 1; }
COM='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc2;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0'
DR="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_SPEC_DEEP=1;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256;BONSAI_KV_VRAM_CELLS=47360;GGML_CUDA_FA_PREFILL_F16=32768"
LC="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0;BONSAI_KV_VRAM_CELLS=53248;BONSAI_UBATCH=1024;GGML_CUDA_FA_PREFILL_F16=65536"
bash run_arm.sh $R drafting "$DR" "" "4000 16000 32000 60000"
bash run_arm.sh $R long "$LC" "" "4000 16000 32000 60000"
echo "one-token answers: $(cat $R/drafting.txt $R/long.txt | grep -c '(1 tok)')" > $R/summary.txt
echo done >> $R/summary.txt
