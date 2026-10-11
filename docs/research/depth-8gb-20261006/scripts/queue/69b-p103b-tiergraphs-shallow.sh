#!/usr/bin/env bash
# P103b: is the -3 % / -5 % at 4k / 32k in P103 (new vs old, one run each, an hour apart) real? Alternated runs.
cd /c/bonsai/8gb; R=receipts/p103b; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tiergraphs;BONSAI_LAYER=0'
for r in 1 2; do
  bash run_arm.sh $R new_r$r "$V" "$L" "4000 32000"
  bash run_arm.sh $R old_r$r "$V;GGML_CUDA_KV_TIER_GRAPHS=1" "$L" "4000 32000"
done
{ for a in new_r1 old_r1 new_r2 old_r2; do echo "$a: $(grep 'mean decode' $R/$a.txt | tr '\n' ' ')"; done; } > $R/summary.txt
