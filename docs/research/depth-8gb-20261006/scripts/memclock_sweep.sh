#!/usr/bin/env bash
# P3: memory-clock sweep. Slots: 5 = stock, 1 = +250, 2 = +500, 3 = +750, 4 = +1000. Ends on stock (slot 5).
# Do not edit while running.
R=/c/bonsai/8gb/receipts/memclock
mkdir -p $R
LOG=$R/sweep.txt
probe=/c/bonsai/8gb/memclock_probe.py
apply() { schtasks //run //tn "BonsaiAB_P$1" > /dev/null; sleep 4; echo "applied slot $1: idle mem clock $(nvidia-smi --query-gpu=clocks.mem --format=csv,noheader)" | tee -a $LOG; }
same() {  # identity of arm $1 vs stock
python - "$R/stock.json" "$R/$1.json" <<'EOF'
import json, sys
a, b = (json.load(open(p, encoding="utf-8")) for p in sys.argv[1:3])
diff = [(x["rep"], x["name"]) for x, y in zip(a["rows"], b["rows"]) if x["text"] != y["text"]]
print("IDENTICAL" if not diff else "DIFFERS " + str(diff))
EOF
}
echo "P3 sweep $(date -Iseconds)" > $LOG
apply 5; python $probe --tag stock | tee -a $LOG
for arm in "1 p250" "2 p500" "3 p750" "4 p1000"; do
    set -- $arm
    apply $1; python $probe --tag $2 | tee -a $LOG
    v=$(same $2); echo "$2 identity: $v" | tee -a $LOG
    if [[ $v != IDENTICAL* ]]; then echo "identity failed at $2: stopping" | tee -a $LOG; break; fi
done
apply 5; python $probe --tag stock2 | tee -a $LOG
echo "stock2 identity: $(same stock2)" | tee -a $LOG
echo "sweep done" | tee -a $LOG
