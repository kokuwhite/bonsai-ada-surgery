#!/usr/bin/env bash
# P116 (#21 request, PR #40, patch 0054: chunked gated-delta-net MMA prefill, port of ggml-org/llama.cpp#29353).
# Build: product-0054 e63ce36d9 (= 90ca41e40 product-0053 + 0054), sm_75, tooling/build-tiergraphs -> bin-0054.
# Reference: bundle-20261011 bin (90ca41e40 = product-0053), release_1011/x/bin.
# On sm_75 the MMA path must not run (BF16 MMA needs GA10x / Ada). Reading of the code: with n_mma >= 64 and scalar
# gates the branch allocates temporaries (and activates raw gates), then ggml_cuda_gdn_mma_launch fails on the device
# and logs once "chunked GDN prefill (MMA) not taken (shape or device)"; the recurrent kernel then runs as before.
# Gates (from the 4070 request, declared here before the run):
#  1. test-backend-ops -o GATED_DELTA_NET passes on bin-0054.
#  2. the 0054 server log has a "chunked GDN prefill (MMA) skipped" or "... not taken" line and NO "engaged" line.
#  3. 32k on the 8 GB launcher: prefill and decode of 0054 equal 0053 within noise (|diff| <= 3 %, alternated twice).
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p116; mkdir -p $R
for i in $(seq 1 120); do [ -f receipts/build-0054.txt ] && break; sleep 30; done
grep -q "build ok" receipts/build-0054.txt 2>/dev/null || { echo "build of e63ce36d9 not ok: $(cat receipts/build-0054.txt 2>/dev/null)" > $R/summary.txt; exit 1; }
B=/c/bonsai/bonsai-ada-surgery/bin-0054
rm -rf $B && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-tiergraphs/bin $B
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f $B/$b ] || cp $f $B/; done
B53=$(cd /c/bonsai/8gb/release_1011/x/bin && pwd -W)
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
echo "GATED_DELTA_NET 0054: $($B/test-backend-ops.exe -o GATED_DELTA_NET -b CUDA0 < /dev/null 2>&1 | grep -E 'tests passed' | tr -d '\r') FAIL lines: $($B/test-backend-ops.exe -o GATED_DELTA_NET -b CUDA0 < /dev/null 2>&1 | grep -c FAIL)" > $R/tests.txt
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
V53="BONSAI_BIN=$B53;BONSAI_LAYER=0"; V54="BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-0054;BONSAI_LAYER=0"
for r in 1 2; do
  bash run_arm.sh $R p53_r$r "$V53" "$L" "32000"
  bash run_arm.sh $R p54_r$r "$V54" "$L" "32000"
  E=$(ls -t logs/*-p54_r$r.err.log | head -1); grep -hE "chunked GDN prefill" "$E" | sed -E 's/^[0-9.]+ W +//' >> $R/gdn_lines_p54.txt
  E=$(ls -t logs/*-p53_r$r.err.log | head -1); echo "p53_r$r GDN lines: $(grep -c 'chunked GDN prefill' "$E")" >> $R/gdn_lines_p53.txt
done
{ cat $R/tests.txt; echo "-- 0054 GDN log lines:"; sort | uniq -c < $R/gdn_lines_p54.txt; cat $R/gdn_lines_p53.txt
  echo "engaged lines: $(grep -c engaged $R/gdn_lines_p54.txt)"
  for a in p53_r1 p54_r1 p53_r2 p54_r2; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|did not" $f | sed -E 's/ttft +[0-9.]+s +//'; done; } > $R/summary.txt
