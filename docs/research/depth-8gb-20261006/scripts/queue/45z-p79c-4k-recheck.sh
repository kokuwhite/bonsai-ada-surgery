#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p79c; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'
for r in 1 2; do
  bash run_arm.sh $R rel_r$r "BONSAI_BIN=C:/bonsai/8gb/release_ckpt/x/bin;BONSAI_LAYER=0" "$L" "4000"
  bash run_arm.sh $R loc_r$r "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-0046;BONSAI_LAYER=0" "$L" "4000"
done
grep -H "mean decode" $R/*.txt | sed "s#$R/##" > $R/summary.txt
