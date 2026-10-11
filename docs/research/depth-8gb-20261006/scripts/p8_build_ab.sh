#!/usr/bin/env bash
# P8: Turing one-column fix (bin-turing) vs bundle (bin). Do not edit while running.
R=/c/bonsai/8gb/receipts/p8; mkdir -p $R
LOG=$R/p8.txt
BASE='BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q8_0;BONSAI_KV_VRAM_CELLS=16384;BONSAI_LAYER=0'
stopit() { powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1 || { echo "STOP FAILED" | tee -a $LOG; exit 1; }; }
arm() {  # $1 tag, $2 extra vars
    stopit
    for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
    used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
    [ "$used" -ge 1500 ] && { echo "VRAM not idle ($used) before $1" | tee -a $LOG; exit 1; }
    schtasks //run //tn BonsaiAB_P5 > /dev/null; sleep 6
    pl=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits)
    echo "$(date +%T) $1: stock applied, power.limit $pl W, idle $used MiB" | tee -a $LOG
    [ "${pl%.*}" != "175" ] && { echo "not stock ($pl W): stopping" | tee -a $LOG; exit 1; }
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p8-$1" -Vars "$BASE$2" -Launcher "C:/bonsai/8gb/start-server-bin.ps1" >> $LOG 2>&1 || { echo "serve failed" | tee -a $LOG; exit 1; }
    L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    grep -q "listening on http" "${L%.out.log}.err.log" || { echo "$1 did not start" | tee -a $LOG; exit 1; }
    sleep 3
    python /c/bonsai/8gb/memclock_probe.py --tag $1 --out C:/bonsai/8gb/receipts/p8 --reps 2 | tee -a $LOG
}
echo "P8 $(date -Iseconds)" >> $LOG
arm s1_bundle_soa ';BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin'
arm n1_new ';BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-turing'
arm b1_bundle_pt ';BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin;GGML_CUDA_BATCH_INVARIANT=1'
arm n2_new ';BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-turing'
arm i1_new_bi ';BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-turing;GGML_CUDA_BATCH_INVARIANT=1'
stopit
python - <<'PY' | tee -a $LOG
import json
L = lambda n: json.load(open(f"C:/bonsai/8gb/receipts/p8/{n}.json", encoding="utf-8"))
def same(a, b):
    d = [x["name"] for x, y in zip(L(a)["rows"], L(b)["rows"]) if x["text"] != y["text"]]
    return "IDENTICAL" if not d else "DIFFERS " + str(sorted(set(d)))
print("i1_new_bi vs b1_bundle_pt (gate):", same("i1_new_bi", "b1_bundle_pt"))
print("n1_new vs n2_new:", same("n1_new", "n2_new"))
print("n1_new vs s1_bundle_soa (report):", same("n1_new", "s1_bundle_soa"))
PY
echo "p8 done" | tee -a $LOG
