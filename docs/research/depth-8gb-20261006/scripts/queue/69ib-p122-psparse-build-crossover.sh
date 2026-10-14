#!/usr/bin/env bash
# P122 (#21, sparse bundle step 3, item 1): build product-sparse 3ab0af3c2 (= product-0054 de873117e + sparse as patch 0055
# candidate, incl. the MIN_HOST eligibility fix 9d9a968d9) for 75-real; op tests; then the crossover again on this build.
# Launcher: start-server-sparsetest.ps1 = launcher-sparse c1908b7 (PR #49) + the BONSAI_BIN line (test copy only). It sets
# the sparse env by itself (8192,64,1024, FAST=1, MIN_HOST=32768) and counts the page bounds in the line. No DISABLE_GRAPHS,
# no mask change (graphs on via 0053, packed mask on).
# Crossover arms (one server each, 96k -> 128k): dense = BONSAI_SPARSE=0; sparse0 = launcher default + MIN_HOST=0 by hand.
# Reading (declared before the run): decode ratio at 96k / 128k -> MIN_HOST = host tail at the first depth with >= 1.05x.
# Gates for the build (before the arms): FLASH_ATTN_EXT and GATED_DELTA_NET op tests pass, else stop.
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p122; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
H=$(git -C /c/bonsai/bonsai-ada-surgery/vendor/prism-tiergraphs rev-parse --short HEAD); echo "source $H" > $R/build.txt
ok=0; for i in 1 2 3; do cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-tiergraphs\build.bat' > logs/build-psparse.log 2>&1
  if [ -f /c/bonsai/bonsai-ada-surgery/tooling/build-tiergraphs/bin/llama-server.exe ] && ! grep -q "build stopped" logs/build-psparse.log && ! grep -qE "error C|error:|LNK[0-9]+" logs/build-psparse.log; then ok=1; echo "build ok try $i $(date +%T)" >> $R/build.txt; break; fi; done
[ $ok = 1 ] || { echo "build FAILED"; cat $R/build.txt; grep -E "error" logs/build-psparse.log | head; } > $R/summary.txt
[ $ok = 1 ] || exit 1
B=/c/bonsai/bonsai-ada-surgery/bin-psparse
rm -rf $B && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-tiergraphs/bin $B
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f $B/$b ] || cp $f $B/; done
for o in FLASH_ATTN_EXT GATED_DELTA_NET; do echo "$o: $($B/test-backend-ops.exe -o $o -b CUDA0 < /dev/null 2>&1 | grep -E 'tests passed' | tr -d '\r') FAIL lines $($B/test-backend-ops.exe -o $o -b CUDA0 < /dev/null 2>&1 | grep -c FAIL)" >> $R/tests.txt; done
grep -qE "FAIL lines [1-9]" $R/tests.txt && { echo "op tests FAIL"; cat $R/build.txt $R/tests.txt; } > $R/summary.txt && exit 1
L='C:/bonsai/bonsai-ada-surgery/start-server-sparsetest.ps1'
V="BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-psparse;BONSAI_LAYER=0"
arm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.trace.txt & MP=$!
  bash run_arm.sh $R "$@"; kill $MP
  awk -F', ' '{split($1,a," "); v=$2+0; if (v>4000000) v-=4194304; if (NR==1||v<m) {m=v; t=a[1]}} END{print "trace min free", m, "MiB at", t, "over", NR, "samples"}' $R/$1.trace.txt >> $R/$1.txt
  E=$(ls -t logs/*-$1.err.log | head -1); O="${E%err.log}out.log"
  echo "sparse_mask lines: $(grep -c ggml_cuda_fa_sparse_mask "$E"); graph switch lines: $(grep -ciE 'CUDA graphs (on|off)' "$E")" >> $R/$1.txt
  grep -hE "^(kv|8gb|window) " "$O" > $R/$1.launcher.txt; }
arm dense "$V;BONSAI_SPARSE=0" "$L" "96000 128000"
arm sparse0 "$V;GGML_CUDA_FA_SPARSE_MIN_HOST=0" "$L" "96000 128000"
{ cat $R/build.txt $R/tests.txt; for a in dense sparse0; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; cat $R/$a.launcher.txt
    grep -E "loaded|depth|mean decode|did not|trace min|sparse_mask lines" $f | sed -E 's/ttft +[0-9.]+s +//'; done; } > $R/summary.txt
