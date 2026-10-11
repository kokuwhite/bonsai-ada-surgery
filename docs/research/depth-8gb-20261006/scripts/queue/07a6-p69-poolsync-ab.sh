#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p69; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest-pool.ps1'
for r in 1 2 3 4 5 6; do
  bash run_arm.sh $R poolsync_r$r "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-poolsync;BONSAI_LAYER=0" "$L" "60000"
  bash run_arm.sh $R tier_r$r "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tier;BONSAI_LAYER=0" "$L" "60000"
done
for f in $R/*_r*.txt; do echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token of $(grep -cE '^(code|prose|bash) +depth' $f); $(grep 'mean decode' $f)"; done > $R/summary.txt
