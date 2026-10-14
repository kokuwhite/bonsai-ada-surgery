#!/usr/bin/env bash
# P116b (PR #40, merged): re-check 0054 on sm_75 after the 4070 applied the P116 note (de873117e: the device is checked
# before any temporaries; cards without BF16 MMA log "chunked GDN prefill (MMA) skipped: device cc N ...").
# Build (incremental) in tooling/build-tiergraphs from prism-tiergraphs (branch product-0054-2060 = de873117e), then:
# Gates (declared here, before the run): GATED_DELTA_NET op tests pass; the server log has the "skipped: device cc" line
# and no "not taken" / "engaged" line; 32k decode and prefill within 3 % of P116 (0054 r1/r2: prefill 343.9 / 344.0,
# decode 44.9 / 44.7) and of the bundle-20261011 arm run here.
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p116b; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
H=$(git -C /c/bonsai/bonsai-ada-surgery/vendor/prism-tiergraphs rev-parse --short HEAD); echo "source $H" > $R/build.txt
ok=0; for i in 1 2 3; do cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-tiergraphs\build.bat' > logs/build-0054b.log 2>&1
  if [ -f /c/bonsai/bonsai-ada-surgery/tooling/build-tiergraphs/bin/llama-server.exe ] && ! grep -q "build stopped" logs/build-0054b.log && ! grep -qE "error C|error:|LNK[0-9]+" logs/build-0054b.log; then ok=1; echo "build ok try $i $(date +%T)" >> $R/build.txt; break; fi; done
[ $ok = 1 ] || { echo "build FAILED"; cat $R/build.txt; } > $R/summary.txt
[ $ok = 1 ] || exit 1
B=/c/bonsai/bonsai-ada-surgery/bin-0054b
rm -rf $B && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-tiergraphs/bin $B
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f $B/$b ] || cp $f $B/; done
B53=$(cd /c/bonsai/8gb/release_1011/x/bin && pwd -W)
echo "GATED_DELTA_NET: $($B/test-backend-ops.exe -o GATED_DELTA_NET -b CUDA0 < /dev/null 2>&1 | grep -E 'tests passed' | tr -d '\r')" > $R/tests.txt
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
bash run_arm.sh $R p53 "BONSAI_BIN=$B53;BONSAI_LAYER=0" "$L" "32000"
bash run_arm.sh $R p54b "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-0054b;BONSAI_LAYER=0" "$L" "32000"
E=$(ls -t logs/*-p54b.err.log | head -1); grep -hE "chunked GDN prefill" "$E" | sed -E 's/^[0-9.]+ W +//' > $R/gdn_lines.txt
{ cat $R/build.txt $R/tests.txt; echo "-- 0054b GDN lines:"; sort $R/gdn_lines.txt | uniq -c
  echo "skipped: $(grep -c 'skipped: device cc' $R/gdn_lines.txt), not taken: $(grep -c 'not taken' $R/gdn_lines.txt), engaged: $(grep -c engaged $R/gdn_lines.txt)"
  for a in p53 p54b; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|did not" $f | sed -E 's/ttft +[0-9.]+s +//'; done
  echo "P116 0054 r1/r2: prefill 343.9 / 344.0, decode 44.9 / 44.7"; } > $R/summary.txt
