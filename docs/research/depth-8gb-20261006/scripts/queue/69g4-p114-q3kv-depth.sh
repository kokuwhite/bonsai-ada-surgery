#!/usr/bin/env bash
# P114: the q3_0 KV type at depth on 8 GB (kv-q3-0 6a4851286 = 2cadbfb64 + q3_0; bin-q3kv from P108).
# P108: op tests pass; PPL 16k +0.56 %, 64k +0.03 % vs q4_0; 4k decode equal. q3_0 = 14 B per 32 values (q4_0: 18 B):
# 14,336 B per position (16 layers x K,V x 4 heads x 8 blocks x 14 B), -22 % per cell. The test launcher copy now has
# 'q3_0' { 14336 } in its CellBytes table (start-server-1010test.ps1, local only).
# Arms on the SAME binary, 262k test launcher, layer off, launcher defaults otherwise (lookup on, packed mask, pool):
#   speed_q4 (BONSAI_CTK=q4_0) and speed_q3 (BONSAI_CTK=q3_0): sweep 4k / 64k / 128k / 192k (one server, extends);
#   quality at 160k with q3_0: exact code copies (10) and needles (12), fresh servers (as P105).
# Gate (declared here, before the run): q3_0 VRAM line >= 1.2x the q4_0 line; decode q3_0 >= 1.05x q4_0 at 128k and
# 192k; 4k within 3 %; 0 one-token; trace min free >= 60 MiB; 160k q3_0 needles 12/12 and copies >= 9/10
# (P105 dense q4_0: 12/12, 10/10). Note: this engine has no patch 0053 and no sparse; both arms share that.
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p114; mkdir -p $R
B=/c/bonsai/bonsai-ada-surgery/bin-q3kv
[ -f $B/llama-server.exe ] || { echo "no bin-q3kv" > $R/summary.txt; exit 1; }
grep -q "'q3_0' { 14336 }" /c/bonsai/bonsai-ada-surgery/start-server-1010test.ps1 || { echo "launcher copy lacks q3_0 CellBytes" > $R/summary.txt; exit 1; }
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
BASEV="BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-q3kv;BONSAI_LAYER=0"
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP
  awk '{v=$2+0; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt
  O=$(ls -t logs/*-$1.out.log | head -1); grep -hE "^(8gb|window|kv|spec|ckpt|ram)" "$O" | head -8 > $R/$1.launcher.txt; }
memarm speed_q4 "$BASEV;BONSAI_CTK=q4_0" "$L" "4000 64000 128000 192000"
memarm speed_q3 "$BASEV;BONSAI_CTK=q3_0" "$L" "4000 64000 128000 192000"
serve() { powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p114_$1 -Launcher "$L" -Vars "$2" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done; }
serve q3_code "$BASEV;BONSAI_CTK=q3_0"
PYTHONUTF8=1 python benchx/code_needle.py --key-file $KEY --depth 160000 --n 10 --tag q3_160000 --out $R/code.jsonl > $R/q3_code_160000.txt 2>&1
serve q3_needle "$BASEV;BONSAI_CTK=q3_0"
PYTHONUTF8=1 python benchx/needle_depth.py --key-file $KEY --depth 160000 --n 12 --tag q3_160000 --out $R/needle.jsonl > $R/q3_needle_160000.txt 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ for a in speed_q4 speed_q3; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; cat $R/$a.launcher.txt
    grep -E "loaded|depth|mean decode|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'; done
  echo "== q3_0 160k: code $(tail -1 $R/q3_code_160000.txt) | needles $(tail -1 $R/q3_needle_160000.txt)"
  echo "P105 dense q4_0 160k: code 10/10, needles 12/12"; } > $R/summary.txt
