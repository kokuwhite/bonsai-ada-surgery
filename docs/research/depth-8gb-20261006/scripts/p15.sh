#!/usr/bin/env bash
# P15 after P13: tail 1 vs tail 2. Do not edit while running.
cd /c/bonsai/8gb
until [ -f receipts/p13/done.txt ] || [ -f receipts/p13-failed.txt ]; do sleep 30; done
OURS='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p12;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_MAX_KB=1024;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256'
R=receipts/p15
bash run_arm.sh $R tail2_n38400 "$OURS;BONSAI_SPEC_DEEP=2;BONSAI_KV_VRAM_CELLS=38400;LLAMA_ARG_LOG_VERBOSITY=5" "" "4000"
bash run_arm.sh $R tail1_n38400 "$OURS;BONSAI_SPEC_DEEP=1;BONSAI_KV_VRAM_CELLS=38400;LLAMA_ARG_LOG_VERBOSITY=5" "" "4000"
s2=$(grep -o "server [0-9]*" $R/tail2_n38400.txt | head -1 | awk '{print $2}'); s1=$(grep -o "server [0-9]*" $R/tail1_n38400.txt | head -1 | awk '{print $2}')
idle=$(grep -o "idle [0-9]*" $R/tail1_n38400.txt | head -1 | awk '{print $2}')
N=$(python -c "
s1=$s1; idle=$idle; MiB=1<<20
fixed = s1*MiB - 38400*18432 - (131072-38400)*1152
n = ((8007 - 257 - idle)*MiB - fixed - 131072*1152)//17280
print(max(16384, min(131072, int(n)//256*256)))")
echo "tail2 server $s2 MiB, tail1 server $s1 MiB (saved $((s2 - s1))), tail1 sized N=$N" | tee $R/summary.txt
bash run_arm.sh $R tail1_n$N "$OURS;BONSAI_SPEC_DEEP=1;BONSAI_KV_VRAM_CELLS=$N"
echo "p15 done" >> $R/summary.txt
