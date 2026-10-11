#!/usr/bin/env bash
# One P5 arm: bash p5_arm.sh <tag> '<VARS;...>' [depths]. Starts the serve, measures, stops it. Do not edit while running.
TAG=$1; VARS=$2; DEPTHS=${3:-"4000 16000 32000 64000"}
R=/c/bonsai/8gb/receipts/p5; mkdir -p $R
OUT=$R/$TAG.txt
B=/c/bonsai/bonsai-ada-surgery
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' || { echo "stop failed before $TAG: not starting"; exit 1; }
for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
IDLE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
if [ "$IDLE" -ge 1500 ]; then echo "VRAM not idle ($IDLE MiB) before $TAG: not starting"; exit 1; fi
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p5-$TAG" -Vars "$VARS" || { echo "serve failed for $TAG"; exit 1; }
L=$(cat /c/bonsai/8gb/logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
for i in $(seq 1 180); do
    grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break
    if ! powershell -NoProfile -Command "Get-Process -Id (Get-Content C:\bonsai\8gb\logs\current.pid) -ErrorAction SilentlyContinue" > /dev/null 2>&1; then break; fi
    sleep 2
done
sleep 3
{
echo "P5 arm $TAG $(date -Iseconds)  vars: $VARS"
cat "$L"
echo "idle used before: $IDLE MiB"
echo "after load: $(nvidia-smi --query-gpu=memory.used,memory.free,clocks.mem --format=csv,noheader)"
} > $OUT
if ! grep -q "listening on http" "${L%.out.log}.err.log"; then
    echo "SERVER DID NOT START" >> $OUT; tail -20 "${L%.out.log}.err.log" >> $OUT; exit 1
fi
(while true; do nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits; sleep 5; done) > $R/$TAG.free.txt & SP=$!
python /c/bonsai/8gb/memclock_probe.py --tag $TAG --out C:/bonsai/8gb/receipts/p5 --reps 1 >> $OUT 2>&1
for d in $DEPTHS; do
    python $B/bench/quick_tps.py --base http://127.0.0.1:8080 --key-file $B/artifacts/api_key.txt --depth $d >> $OUT 2>&1 || echo "depth $d FAILED" >> $OUT
done
kill $SP
grep -iE "draft acceptance|accept" "${L%.out.log}.err.log" | tail -3 >> $OUT
echo "min free during run: $(sort -n $R/$TAG.free.txt | head -1) MiB" >> $OUT
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $OUT 2>&1 || { echo "STOP FAILED" >> $OUT; exit 1; }
echo "arm done" >> $OUT
