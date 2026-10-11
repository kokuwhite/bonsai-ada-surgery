#!/usr/bin/env bash
# P4: cooling/power/core sweep. Slots: 5 stock, 1 power 122 + fan 85, 2/3/4 + core +50/+100/+150. Ends on stock.
# Do not edit while running.
R=/c/bonsai/8gb/receipts/coreclock
mkdir -p $R
LOG=$R/sweep.txt
probe="python /c/bonsai/8gb/memclock_probe.py --out C:/bonsai/8gb/receipts/coreclock"
apply() { schtasks //run //tn "BonsaiAB_P$1" > /dev/null; sleep 6; echo "applied slot $1: $(nvidia-smi --query-gpu=power.limit,fan.speed,clocks.mem --format=csv,noheader)" | tee -a $LOG; }
same() {
python - "$R/stock.json" "$R/$1.json" <<'EOF'
import json, sys
a, b = (json.load(open(p, encoding="utf-8")) for p in sys.argv[1:3])
diff = [(x["rep"], x["name"]) for x, y in zip(a["rows"], b["rows"]) if x["text"] != y["text"]]
print("IDENTICAL" if not diff else "DIFFERS " + str(diff))
EOF
}
up() { curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/health; }
echo "P4 sweep $(date -Iseconds)" > $LOG
apply 5; $probe --tag stock | tee -a $LOG
for arm in "1 cool" "2 core50" "3 core100" "4 core150"; do
    set -- $arm
    apply $1
    if ! $probe --tag $2 | tee -a $LOG || [[ $(up) != 200 ]]; then
        echo "$2: probe failed or server down (driver reset?): stopping" | tee -a $LOG; break
    fi
    v=$(same $2); echo "$2 identity: $v" | tee -a $LOG
    if [[ $v != IDENTICAL* ]]; then echo "identity failed at $2: stopping" | tee -a $LOG; break; fi
done
if [[ $(up) == 200 ]]; then apply 1; $probe --tag cool2 | tee -a $LOG; echo "cool2 identity: $(same cool2)" | tee -a $LOG; fi
apply 5
echo "sweep done" | tee -a $LOG
