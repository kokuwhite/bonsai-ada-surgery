#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p85; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-pmask;BONSAI_LAYER=0'
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
memarm auto262 "$V" "$L" "4000 32000 64000 96000 128000"
grep -hE "^(8gb|window|kv|spec|ckpt|note|warn)" logs/*auto262.out.log | sort -u > $R/launcher_lines.txt
for r in 1 2; do memarm fresh60k_r$r "$V" "$L" "60000"; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p85_ab -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/ab.mem.txt & MP=$!
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag l262_d0 --out $R/ab.jsonl --depth 0 > $R/ab_d0.txt 2>&1
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag l262_d64000 --out $R/ab.jsonl --depth 64000 > $R/ab_d64000.txt 2>&1
kill $MP; powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "ab trace min free", m}' $R/ab.mem.txt > $R/ab_mem.txt
{ cat $R/launcher_lines.txt; for a in auto262 fresh60k_r1 fresh60k_r2; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|prose  depth|mean decode|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'; done; cat $R/ab_mem.txt; echo "ab one-token: $(grep -c '"n": 1,' $R/ab.jsonl) of $(wc -l < $R/ab.jsonl)"; } > $R/summary.txt
