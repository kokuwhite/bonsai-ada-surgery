#!/usr/bin/env bash
cd /c/bonsai/8gb
until grep -q "p25 done" receipts/p25/p25.txt 2>/dev/null; do sleep 30; done
LC='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p25;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0;BONSAI_KV_VRAM_CELLS=58112;GGML_CUDA_FA_PREFILL_F16=65536'
R=receipts/p26
(while true; do powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\sample_mem.ps1'; sleep 3; done) >> $R-mem.txt 2>/dev/null & SP=$!
for r in 1 2; do
  bash run_arm.sh $R ub1024_r$r "$LC;BONSAI_UBATCH=1024" "" "4000 16000 32000 60000"
  bash run_arm.sh $R ub512_r$r "$LC" "" "4000 16000 32000 60000"
done
kill $SP; mv $R-mem.txt $R/mem.txt
touch $R/done.txt
