#!/usr/bin/env bash
# P12: drafting made cheap. Runs after p12_prep. Do not edit while running.
R=/c/bonsai/8gb/receipts/p12; mkdir -p $R
LOG=$R/p12.txt
B=/c/bonsai/bonsai-ada-surgery
COMMON='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p12;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_PCT=0'
DRAFT='BONSAI_SPEC=1;BONSAI_SPEC_DEEP=2;BONSAI_DRAFT_WINDOW=16384'
Q8H='BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf'
Q4H='BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf'
PLAIN='BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0'
POOL='GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256'
stopit() { powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1 || { echo "STOP FAILED" | tee -a $LOG; exit 1; }; }
IDLE=0
up() {  # $1 tag, $2 vars; sets IDLE and USED
    stopit
    for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
    IDLE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
    [ "$IDLE" -ge 1500 ] && { echo "VRAM not idle ($IDLE) before $1" | tee -a $LOG; exit 1; }
    schtasks //run //tn BonsaiAB_P3 > /dev/null; sleep 6; schtasks //run //tn BonsaiAB_P5 > /dev/null; sleep 6
    pl=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits)
    [ "${pl%.*}" != "175" ] && { echo "not stock ($pl W): stopping" | tee -a $LOG; exit 1; }
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p12-$1" -Vars "$2" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1 || { echo "serve failed $1" | tee -a $LOG; exit 1; }
    L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    grep -q "listening on http" "${L%.out.log}.err.log" || { echo "$1 did not start" | tee -a $LOG; tail -5 "${L%.out.log}.err.log" >> $LOG; return 1; }
    sleep 3
    USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
    echo "$(date +%T) $1: idle $IDLE used $USED server $((USED - IDLE)) MiB free $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)" | tee -a $LOG
}
accept() { L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#'); grep -o "draft acceptance = [0-9.]*" "${L%.out.log}.err.log" | awk '{s+=$4; n++} END {if (n) printf "acceptance mean %.3f over %d requests\n", s/n, n}' | tee -a $LOG; }
sweep() { for d in 4000 16000 32000 64000; do python $B/bench/quick_tps.py --base http://127.0.0.1:8080 --key-file $B/artifacts/api_key.txt --depth $d 2>&1 | grep -E "mean decode|code +depth" | tee -a $LOG; done; }

until grep -qE "prep done" /c/bonsai/8gb/logs/p12-prep.log 2>/dev/null; do sleep 30; done
grep -q "STRIP PROOF OK" /c/bonsai/8gb/logs/p12-prep.log || { echo "strip proof not OK: stopping" | tee -a $LOG; exit 1; }
grep -q "build-p12 exit 0" /c/bonsai/8gb/logs/p12-prep.log || { echo "build-p12 failed: stopping" | tee -a $LOG; exit 1; }
echo "P12 $(date -Iseconds) stock + fan 100%, desk fans" >> $LOG

# Step 1: VRAM and acceptance at N=16384
declare -A SRV
for arm in "C0:$Q8H" "C1:$Q4H" "C2:$Q4H;$POOL"; do
    t=${arm%%:*}; v=${arm#*:}
    up $t "$COMMON;$DRAFT;$v;BONSAI_KV_VRAM_CELLS=16384" || continue
    SRV[$t]=$((USED - IDLE))
    python /c/bonsai/8gb/memclock_probe.py --tag ${t}_4k --out C:/bonsai/8gb/receipts/p12 --reps 2 | tail -1 | tee -a $LOG
    accept
done
echo "server MiB: C0 ${SRV[C0]} C1 ${SRV[C1]} C2 ${SRV[C2]}  (head q8->q4: $(( ${SRV[C0]:-0} - ${SRV[C1]:-0} )); pool+ubatch: $(( ${SRV[C1]:-0} - ${SRV[C2]:-0} )))" | tee -a $LOG

# Step 2: size the cheapest variant to 257 MiB free, sweep it and B (N=77568) on the same binary
best=C2; [ -z "${SRV[C2]}" ] && best=C1
bvars="$Q4H"; [ $best = C2 ] && bvars="$Q4H;$POOL"
N2=$(python -c "
idle=$IDLE; srv=${SRV[$best]}; MiB=1<<20
fixed = srv*MiB - 16384*18432 - (131072-16384)*1152
n = ((8007 - 257 - idle)*MiB - fixed - 131072*1152) // 17280
print(max(16384, min(131072, int(n)//256*256)))")
echo "step 2: $best sized to N=$N2 for ~257 MiB free (idle $IDLE)" | tee -a $LOG
up ${best}_n$N2 "$COMMON;$DRAFT;$bvars;BONSAI_KV_VRAM_CELLS=$N2" && { sweep; accept; }
up B_n77568 "$COMMON;$PLAIN;BONSAI_KV_VRAM_CELLS=77568" && sweep
stopit
echo "p12 done" | tee -a $LOG
