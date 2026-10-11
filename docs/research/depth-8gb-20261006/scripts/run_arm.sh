#!/usr/bin/env bash
# Generic arm: bash run_arm.sh <outdir> <tag> '<VARS;...>' [launcher] [depths]
# Stops any server, waits for idle VRAM, forces slot 5 (stock + fan 100%), serves, runs quick_tps at each depth, stops.
# A launcher of "raw:<command line>" runs that llama-server command directly (for foreign builds/recipes).
OUT=$1; TAG=$2; VARS=$3; LAUNCHER=${4:-C:/bonsai/8gb/start-server-bin.ps1}; DEPTHS=${5:-"4000 16000 32000 60000"}
mkdir -p $OUT; LOG=$OUT/$TAG.txt
B=/c/bonsai/bonsai-ada-surgery
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1 || { echo "STOP FAILED" | tee -a $LOG; exit 1; }
for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
IDLE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
[ "$IDLE" -ge 1500 ] && { echo "VRAM not idle ($IDLE)" | tee -a $LOG; exit 1; }
for try in 1 2 3 4; do
    schtasks //run //tn BonsaiAB_P3 > /dev/null; sleep $((6 * try)); schtasks //run //tn BonsaiAB_P5 > /dev/null; sleep $((6 * try))
    PL=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits)
    [ "${PL%.*}" = "175" ] && break
done
[ "${PL%.*}" != "175" ] && { echo "not stock ($PL W)" | tee -a $LOG; exit 1; }
echo "$(date +%T) $TAG idle $IDLE MiB, power $PL W, vars: $VARS" | tee -a $LOG
if [[ $LAUNCHER == raw:* ]]; then
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve_raw.ps1' -Tag "$TAG" -Cmd "${LAUNCHER#raw:}" -Vars "$VARS" >> $LOG 2>&1 || { echo "serve failed" | tee -a $LOG; exit 1; }
    BASE=http://127.0.0.1:8899; KEYARG=""
else
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "$TAG" -Vars "$VARS" -Launcher "$LAUNCHER" >> $LOG 2>&1 || { echo "serve failed" | tee -a $LOG; exit 1; }
    BASE=http://127.0.0.1:8080; KEYARG="--key-file $B/artifacts/api_key.txt"
fi
L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
grep -q "listening on http" "${L%.out.log}.err.log" || { echo "did not start" | tee -a $LOG; tail -8 "${L%.out.log}.err.log" >> $LOG; exit 1; }
sleep 3
USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
echo "$(date +%T) loaded: used $USED server $((USED - IDLE)) MiB free $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)" | tee -a $LOG
for d in $DEPTHS; do
    python $B/bench/quick_tps.py --base $BASE $KEYARG --depth $d 2>&1 | grep -E "depth|mean decode|Error|error" | tee -a $LOG
done
grep -o "draft acceptance = [0-9.]*" "${L%.out.log}.err.log" | awk '{s+=$4; n++} END {if (n) printf "acceptance mean %.3f over %d\n", s/n, n}' | tee -a $LOG
echo "min free $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits) MiB at end" | tee -a $LOG
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
echo "arm done" | tee -a $LOG
