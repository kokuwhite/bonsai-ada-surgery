#!/usr/bin/env bash
# P10: #209 + #314 (switch commit) on Turing vs bin-turing. B serve (q4_0, N=38656), stock clocks. Do not edit while running.
R=/c/bonsai/8gb/receipts/p10; mkdir -p $R
LOG=$R/p10.txt
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
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p10-$1" -Vars "$BASE$2" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1 || { echo "serve failed" | tee -a $LOG; exit 1; }
    L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    grep -q "listening on http" "${L%.out.log}.err.log" || { echo "$1 did not start" | tee -a $LOG; exit 1; }
    sleep 3
    python /c/bonsai/8gb/memclock_probe.py --tag ${1}_4k --out C:/bonsai/8gb/receipts/p10 --reps 2 --depth 4000 | tee -a $LOG
    python /c/bonsai/8gb/memclock_probe.py --tag ${1}_16k --out C:/bonsai/8gb/receipts/p10 --reps 1 --depth 16000 | tee -a $LOG
}
until grep -q "build-alpha exit 0" /c/bonsai/8gb/logs/build-alpha.log 2>/dev/null; do
    grep -q "build-alpha exit [1-9]" /c/bonsai/8gb/logs/build-alpha.log 2>/dev/null && { echo "alpha build failed" | tee -a $LOG; exit 1; }
    sleep 30
done
[ -f /c/bonsai/bonsai-ada-surgery/bin-alpha/llama-server.exe ] || { echo "bin-alpha not staged" | tee -a $LOG; exit 1; }
echo "P10 $(date -Iseconds)" >> $LOG
arm turing1 "$TUR"
arm a_off1 "$ALP;GGML_CUDA_L2_PREFETCH_PCT=0"
arm a_def "$ALP"
arm a_kb2048 "$ALP;GGML_CUDA_L2_PREFETCH_MAX_KB=2048"
arm a_kb1024 "$ALP;GGML_CUDA_L2_PREFETCH_MAX_KB=1024"
arm a_kb2048_c34 "$ALP;GGML_CUDA_L2_PREFETCH_MAX_KB=2048;GGML_CUDA_L2_PREFETCH_CTAS=34"
arm turing2 "$TUR"
arm a_off2 "$ALP;GGML_CUDA_L2_PREFETCH_PCT=0"
stopit
python - <<'PY' | tee -a $LOG
import json
D = "C:/bonsai/8gb/receipts/p10/"
L = lambda n: json.load(open(D + n + ".json", encoding="utf-8"))
def same(a, b):
    d = [x["name"] for x, y in zip(L(a)["rows"], L(b)["rows"]) if x["text"] != y["text"]]
    return "IDENTICAL" if not d else "DIFFERS " + str(sorted(set(d)))
for dep in ("4k", "16k"):
    print(f"[{dep}] a_off1 vs turing1 (#209 alone): {same('a_off1_' + dep, 'turing1_' + dep)}")
    for t in ("a_def", "a_kb2048", "a_kb1024", "a_kb2048_c34", "a_off2"):
        print(f"[{dep}] {t} vs a_off1: {same(t + '_' + dep, 'a_off1_' + dep)}")
    print(f"[{dep}] mean decode: " + ", ".join(f"{t} {L(t + '_' + dep)['mean_decode']:.2f}" for t in
          ("turing1", "a_off1", "a_def", "a_kb2048", "a_kb1024", "a_kb2048_c34", "turing2", "a_off2")))
PY
echo "p10 done" | tee -a $LOG
