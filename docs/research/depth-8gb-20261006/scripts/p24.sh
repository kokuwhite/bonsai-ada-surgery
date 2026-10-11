#!/usr/bin/env bash
cd /c/bonsai/8gb
until [ -f receipts/p23/done.txt ]; do sleep 30; done
R=receipts/p24; mkdir -p $R; LOG=$R/p24.txt
LC='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p22;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_PCT=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0;BONSAI_KV_VRAM_CELLS=67840'
for v in unpacked packed; do
    extra=""; [ $v = packed ] && extra=";LLAMA_ARG_KQ_MASK_PACKED=1"
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
    for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p24-$v" -Vars "$LC$extra" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1
    L=$(cat logs/current.log | tr -d '\r\n' | sed 's#\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    for d in 20000 24000 28000 32000; do python depth_text_probe.py --tag ${v}_$d --depth $d --n 60 --out C:/bonsai/8gb/receipts/p24 | tee -a $LOG; done
done
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
echo "p24 done" | tee -a $LOG
