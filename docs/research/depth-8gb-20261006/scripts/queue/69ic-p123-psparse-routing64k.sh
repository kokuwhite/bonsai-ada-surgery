#!/usr/bin/env bash
# P123 (#21, sparse bundle step 3, item 2): the routing-fix check on product-sparse (bin-psparse, P122) with the launcher-sparse
# test copy. 64k, launcher default (sparse on, MIN_HOST=32768: below the threshold at 64k) vs BONSAI_SPARSE=0, alternated x2.
# Gate (declared here, before the run): default within 2 % of BONSAI_SPARSE=0 on mean decode at 64k in both rounds; 0 sparse ops
# at 64k; 0 one-token; trace min free >= 60 MiB. (P115 on the old build: -20.6 %.)
cd /c/bonsai/8gb; R=receipts/p123; mkdir -p $R
export QTPS_TIMEOUT=7200
L='C:/bonsai/bonsai-ada-surgery/start-server-sparsetest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V="BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-psparse;BONSAI_LAYER=0"
[ -f /c/bonsai/bonsai-ada-surgery/bin-psparse/llama-server.exe ] || { echo "no bin-psparse (P122 builds it)" > $R/summary.txt; exit 1; }
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
arm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.trace.txt & MP=$!
  bash run_arm.sh $R "$@"; kill $MP
  awk -F", " '{split($1,a," "); v=$2+0; if (v>4000000) v-=4194304; if (NR==1||v<m) {m=v; t=a[1]}} END{print "trace min free", m, "MiB at", t, "over", NR, "samples"}' $R/$1.trace.txt >> $R/$1.txt
  E=$(ls -t logs/*-$1.err.log | head -1); O="${E%err.log}out.log"
  echo "sparse_mask lines: $(grep -c ggml_cuda_fa_sparse_mask "$E")" >> $R/$1.txt; grep -hE "^(kv|8gb|window) |VRAM line" "$O" > $R/$1.launcher.txt; }
sumarms() { for a in "$@"; do f=$R/$a.txt; echo "== $a: $(grep -c "(1 tok)" $f) one-token"; cat $R/$a.launcher.txt 2>/dev/null; grep -E "loaded|depth|mean decode|did not|trace min|sparse_mask lines" $f | sed -E "s/ttft +[0-9.]+s +//"; done; }
for r in 1 2; do arm off_r$r "$V;BONSAI_SPARSE=0" "$L" "64000"; arm def_r$r "$V" "$L" "64000"; done
{ cat $R/build.txt $R/tests.txt 2>/dev/null; sumarms off_r1 def_r1 off_r2 def_r2; } > $R/summary.txt
