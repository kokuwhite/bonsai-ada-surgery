#!/usr/bin/env bash
# P17: the one-token stop at depth. 2x2: drafting (C2) vs not (B) x prefetch MAX_KB=1024 vs PCT=0, text probe at 32k.
# Do not edit while running.
cd /c/bonsai/8gb
until grep -q "p15 done" receipts/p15/summary.txt 2>/dev/null; do sleep 30; done
R=receipts/p17; mkdir -p $R; LOG=$R/p17.txt
COM='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p12;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0'
C2="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_SPEC_DEEP=2;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256;BONSAI_KV_VRAM_CELLS=38400"
BB="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0;BONSAI_KV_VRAM_CELLS=58112"
probe_arm() {  # $1 tag, $2 vars
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1 || { echo "STOP FAILED" | tee -a $LOG; exit 1; }
    for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
    for try in 1 2 3 4; do schtasks //run //tn BonsaiAB_P3 > /dev/null; sleep $((6*try)); schtasks //run //tn BonsaiAB_P5 > /dev/null; sleep $((6*try)); [ "$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits | cut -d. -f1)" = "175" ] && break; done
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p17-$1" -Vars "$2" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1 || { echo "serve failed $1" | tee -a $LOG; return; }
    L=$(cat logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    echo "$(date +%T) $1 loaded, power $(nvidia-smi --query-gpu=power.limit --format=csv,noheader)" | tee -a $LOG
    python depth_text_probe.py --tag $1 --depth 32000 --n 200 2>&1 | tee -a $LOG
    cp "${L%.out.log}.err.log" $R/$1.err.log
}
probe_arm c2_pf1024 "$C2;GGML_CUDA_L2_PREFETCH_MAX_KB=1024"
probe_arm c2_pf0 "$C2;GGML_CUDA_L2_PREFETCH_PCT=0"
probe_arm b_pf1024 "$BB;GGML_CUDA_L2_PREFETCH_MAX_KB=1024"
probe_arm b_pf0 "$BB;GGML_CUDA_L2_PREFETCH_PCT=0"
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
echo "p17 done" | tee -a $LOG
