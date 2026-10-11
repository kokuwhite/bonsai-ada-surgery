#!/usr/bin/env bash
# After P10: P9b (OC +150 re-soak with desk fans, fan 100%) then P11 (margin soak at N=65280, N=77568). Do not edit while running.
R9=/c/bonsai/8gb/receipts/p9b; R11=/c/bonsai/8gb/receipts/p11; mkdir -p $R9 $R11
TUR='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-turing;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q4_0;BONSAI_LAYER=0'
gpu() { nvidia-smi --query-gpu=power.limit,fan.speed,clocks.gr,temperature.gpu,memory.used,memory.free --format=csv,noheader; }
slot() { schtasks //run //tn BonsaiAB_P3 > /dev/null; sleep 6; schtasks //run //tn "BonsaiAB_P$1" > /dev/null; sleep 6; }  # via slot 3 so slot 5 really applies
stopit() { powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' || { echo "STOP FAILED"; exit 1; }; }
serve() {  # $1 tag, $2 N, $3 log
    stopit
    for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
    echo "$(date +%T) idle before $1: $(gpu)" | tee -a $3
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "$1" -Vars "$TUR;BONSAI_KV_VRAM_CELLS=$2" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' || { echo "serve failed" | tee -a $3; exit 1; }
    L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    grep -q "listening on http" "${L%.out.log}.err.log" || { echo "$1 did not start" | tee -a $3; exit 1; }
    sleep 3
    echo "$(date +%T) loaded $1 (N=$2): $(gpu)" | tee -a $3
}
shared_sampler() {  # $1 out file; samples llama-server shared + dedicated GPU memory and card free every 5 s
    while true; do
        powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\sample_mem.ps1' >> $1 2>/dev/null
        sleep 5
    done
}
until grep -qE "p10 done|failed|STOP FAILED|not stock|did not start|not idle|not staged" /c/bonsai/8gb/receipts/p10/p10.txt 2>/dev/null; do sleep 30; done

# P9b
L9=$R9/p9b.txt; echo "P9b $(date -Iseconds) desk fans, fan 100%, 1280x1024" >> $L9
slot 5; serve p9b-B 38656 $L9
python /c/bonsai/8gb/p9_soak.py --tag stock --seconds 120 --out C:/bonsai/8gb/receipts/p9b | tee -a $L9
slot 4; echo "oc150: $(gpu)" | tee -a $L9
python /c/bonsai/8gb/p9_soak.py --tag oc150 --seconds 600 --out C:/bonsai/8gb/receipts/p9b | tee -a $L9
slot 5; echo "$(date +%T) back to slot 5: $(gpu)" | tee -a $L9
python - <<'PY' | tee -a $L9
import json
D = "C:/bonsai/8gb/receipts/p9b/"
s = json.load(open(D + "stock.json", encoding="utf-8"))["rows"]
o = json.load(open(D + "oc150.json", encoding="utf-8"))["rows"]
ref = {(r["depth"], r["prompt"]): r["text"] for r in s}
pairs = [r["text"] == ref[(r["depth"], r["prompt"])] for r in o if (r["depth"], r["prompt"]) in ref]
print(f"oc150 vs stock identity: {sum(pairs)}/{len(pairs)} identical")
PY

# P11
L11=$R11/p11.txt; echo "P11 $(date -Iseconds) stock clocks, fan 100%, desk fans, 1280x1024" >> $L11
for N in 65280 77568; do
    serve p11-n$N $N $L11
    shared_sampler $R11/n$N.mem.txt & SP=$!
    python /c/bonsai/8gb/p9_soak.py --tag n$N --seconds 600 --depths 4000,16000,48000 --out C:/bonsai/8gb/receipts/p11 | tee -a $L11
    kill $SP
    echo "n$N min free: $(grep -o 'free [0-9]*' $R11/n$N.mem.txt | awk '{print $2}' | sort -n | head -1) MiB; shared first/last/max: $(grep shared $R11/n$N.mem.txt | head -1 | awk '{print $3}') / $(grep shared $R11/n$N.mem.txt | tail -1 | awk '{print $3}') / $(grep shared $R11/n$N.mem.txt | awk '{print $3}' | sort -n | tail -1) MiB" | tee -a $L11
done
stopit
echo "chain done" | tee -a $L11
