#!/usr/bin/env bash
# P9: overclock soak on the B serve with the Turing build. Do not edit while running.
R=/c/bonsai/8gb/receipts/p9; mkdir -p $R
LOG=$R/p9.txt
VARS='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-turing;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q4_0;BONSAI_KV_VRAM_CELLS=38656;BONSAI_LAYER=0'
gpu() { nvidia-smi --query-gpu=power.limit,fan.speed,clocks.gr,temperature.gpu --format=csv,noheader; }
echo "P9 $(date -Iseconds)" >> $LOG
while powershell -NoProfile -Command "if (Get-Process llama-perplexity -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"; do sleep 10; done
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1 || { echo "STOP FAILED" | tee -a $LOG; exit 1; }
schtasks //run //tn BonsaiAB_Install > /dev/null; sleep 10
tail -1 /c/bonsai/8gb/afterburner/install.log | tee -a $LOG
schtasks //run //tn BonsaiAB_P5 > /dev/null; sleep 6
echo "stock: $(gpu)" | tee -a $LOG
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag p9-B-turing -Vars "$VARS" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1 || { echo "serve failed" | tee -a $LOG; exit 1; }
L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
grep -q "listening on http" "${L%.out.log}.err.log" || { echo "server did not start" | tee -a $LOG; exit 1; }
echo "loaded: $(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader)" | tee -a $LOG
python /c/bonsai/8gb/p9_soak.py --tag stock --seconds 120 | tee -a $LOG
schtasks //run //tn BonsaiAB_P4 > /dev/null; sleep 6
echo "oc150: $(gpu)" | tee -a $LOG
python /c/bonsai/8gb/p9_soak.py --tag oc150 --seconds 600 | tee -a $LOG
python - <<'PY' | tee -a $LOG
import json
s = json.load(open("C:/bonsai/8gb/receipts/p9/stock.json", encoding="utf-8"))["rows"]
o = json.load(open("C:/bonsai/8gb/receipts/p9/oc150.json", encoding="utf-8"))["rows"]
ref = {(r["depth"], r["prompt"]): r["text"] for r in s}
pairs = [(r["depth"], r["prompt"], r["text"] == ref[(r["depth"], r["prompt"])]) for r in o if (r["depth"], r["prompt"]) in ref]
bad = [p for p in pairs if not p[2]]
print(f"oc150 vs stock identity: {len(pairs) - len(bad)}/{len(pairs)} identical" + (f", DIFFERS {sorted(set((d, p) for d, p, _ in bad))}" if bad else ""))
PY
echo "after soak: $(gpu)" | tee -a $LOG
echo "p9 done (slot 4 left applied; serve still up)" | tee -a $LOG
