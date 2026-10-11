#!/usr/bin/env bash
# P11b: second margin pass, block design. Runs after P12. Do not edit while running.
R=/c/bonsai/8gb/receipts/p11b; mkdir -p $R; LOG=$R/p11b.txt
VARS='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-turing;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q4_0;BONSAI_LAYER=0;BONSAI_KV_VRAM_CELLS=77568'
until grep -qE "p12 done|STOP FAILED|failed|stopping" /c/bonsai/8gb/receipts/p12/p12.txt 2>/dev/null; do sleep 30; done
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1 || { echo "STOP FAILED" | tee -a $LOG; exit 1; }
for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
schtasks //run //tn BonsaiAB_P3 > /dev/null; sleep 6; schtasks //run //tn BonsaiAB_P5 > /dev/null; sleep 6
echo "P11b $(date -Iseconds) idle $(nvidia-smi --query-gpu=memory.used,power.limit,fan.speed --format=csv,noheader)" | tee -a $LOG
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag p11b -Vars "$VARS" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1 || { echo "serve failed" | tee -a $LOG; exit 1; }
L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\#/#g; s#^C:#/c#')
for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
echo "loaded: $(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader)" | tee -a $LOG
(while true; do powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\sample_mem.ps1'; sleep 5; done) >> $R/mem.txt 2>/dev/null & SP=$!
b=0; for d in 4000 64000 4000 64000; do b=$((b+1)); python /c/bonsai/8gb/p9_soak.py --tag block${b}_$d --seconds 240 --depths $d --out C:/bonsai/8gb/receipts/p11b | tail -2 | tee -a $LOG; done
kill $SP
python - <<'PY' | tee -a $LOG
import json
D = "C:/bonsai/8gb/receipts/p11b/"
m = {}
for b, d in ((1, 4000), (2, 64000), (3, 4000), (4, 64000)):
    r = json.load(open(f"{D}block{b}_{d}.json", encoding="utf-8"))["rows"]
    m[b] = sum(x["decode"] for x in r) / len(r)
    print(f"block{b} depth {d}: mean {m[b]:.2f} over {len(r)} requests")
print(f"4k block3 vs block1: {100*(m[3]/m[1]-1):+.1f}%   64k block4 vs block2: {100*(m[4]/m[2]-1):+.1f}%")
PY
echo "min free $(grep -o 'free [0-9]*' $R/mem.txt | awk '{print $2}' | sort -n | head -1) MiB; shared min/max $(grep -o 'shared [0-9]*' $R/mem.txt | awk '{print $2}' | sort -n | sed -n '1p;$p' | tr '\n' ' ')" | tee -a $LOG
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
echo "p11b done" | tee -a $LOG
