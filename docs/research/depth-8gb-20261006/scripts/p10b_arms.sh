#!/usr/bin/env bash
# P10b: replicate #314 on Turing (bin-alpha). B serve (q4_0, N=38656), stock clocks. Do not edit while running.
R=/c/bonsai/8gb/receipts/p10b; mkdir -p $R
LOG=$R/p10b.txt
BASE='BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q4_0;BONSAI_KV_VRAM_CELLS=38656;BONSAI_LAYER=0'
TUR=';BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-turing'
ALP=';BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-alpha'
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
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p10b-$1" -Vars "$BASE$2" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1 || { echo "serve failed" | tee -a $LOG; exit 1; }
    L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    grep -q "listening on http" "${L%.out.log}.err.log" || { echo "$1 did not start" | tee -a $LOG; exit 1; }
    sleep 3
    python /c/bonsai/8gb/memclock_probe.py --tag ${1}_4k --out C:/bonsai/8gb/receipts/p10b --reps 2 --depth 4000 | tee -a $LOG
    python /c/bonsai/8gb/memclock_probe.py --tag ${1}_16k --out C:/bonsai/8gb/receipts/p10b --reps 1 --depth 16000 | tee -a $LOG
}
until grep -qE "chain done|failed|STOP FAILED|did not start" /c/bonsai/8gb/receipts/p11/p11.txt 2>/dev/null; do sleep 30; done
echo "P10b $(date -Iseconds)" >> $LOG
for r in 1 2; do
    arm off$r "$ALP;GGML_CUDA_L2_PREFETCH_PCT=0"
    arm def$r "$ALP"
    arm kb1024_$r "$ALP;GGML_CUDA_L2_PREFETCH_MAX_KB=1024"
    arm kb512_$r "$ALP;GGML_CUDA_L2_PREFETCH_MAX_KB=512"
done
stopit
python - <<'PYX' | tee -a $LOG
import json
D = "C:/bonsai/8gb/receipts/p10b/"
L = lambda n: json.load(open(D + n + ".json", encoding="utf-8"))
for dep in ("4k", "16k"):
    for t in ("def", "kb1024_", "kb512_"):
        for r in (1, 2):
            a = L(f"{t}{r}_{dep}" if t.endswith("_") else f"{t}{r}_{dep}"); b = L(f"off{r}_{dep}")
            same = all(x["text"] == y["text"] for x, y in zip(a["rows"], b["rows"]))
            print(f"[{dep}] round {r} {t.rstrip('_'):<7} {a['mean_decode']:.2f} vs off {b['mean_decode']:.2f} ({100*(a['mean_decode']/b['mean_decode']-1):+.1f}%) texts {'IDENTICAL' if same else 'DIFFER'}")
PYX
echo "p10b done" | tee -a $LOG
