#!/usr/bin/env bash
# P126b: is P126's -4 to -7 % at 64k-128k (bundle-20261013 vs P113's bundle-20261011) the release, or the session?
# P126 ran after a power cut (idle 233 MiB vs 217, line 61,696 vs 62,464). Same session, same launcher (1010test copy, layer
# off), alternated: 1011, 1013, 1011, 1013; sweep 64k -> 96k -> 128k per server.
# Gate (declared here, before the run): bundle-20261013 within 3 % of bundle-20261011 at each depth (mean of the two rounds);
# else the release has a past-the-line regression on Turing (report to the 4070 with both lines).
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p126b; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
B11=$(cd /c/bonsai/8gb/release_1011/x/bin && pwd -W); B13=$(cd /c/bonsai/8gb/release_1013/x/bin && pwd -W)
for r in 1 2; do
  bash run_arm.sh $R b1011_r$r "BONSAI_BIN=$B11;BONSAI_LAYER=0" "$L" "64000 96000 128000"
  bash run_arm.sh $R b1013_r$r "BONSAI_BIN=$B13;BONSAI_LAYER=0" "$L" "64000 96000 128000"
done
{ for a in b1011_r1 b1013_r1 b1011_r2 b1013_r2; do f=$R/$a.txt; O=$(ls -t logs/*-$a.out.log | head -1)
    echo "== $a: $(grep -c '(1 tok)' $f) one-token; $(grep -hE '^kv +tiered' "$O" | cut -c1-60)"; grep -E "loaded|mean decode|did not" $f; done; } > $R/summary.txt
