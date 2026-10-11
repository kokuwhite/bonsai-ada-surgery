#!/usr/bin/env bash
# BonsaiJob3: P45. Waits for jobrun2 to finish. Do not edit while running.
cd /c/bonsai/8gb
mkdir receipts/jobrun3.lock 2>/dev/null || exit 1
trap 'rmdir receipts/jobrun3.lock' EXIT
echo "$(date +%T) start" >> receipts/jobrun3.log
until grep -q " end" receipts/jobrun2.log 2>/dev/null && [ ! -d receipts/jobrun2.lock ]; do sleep 60; done
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf'
P=C:/bonsai/bonsai-ada-surgery
for r in 1 2 3; do
  bash run_arm.sh receipts/p45 A_launcher_$r "$V" "$P/start-server-8gbnew.ps1" "4000"
  bash run_arm.sh receipts/p45 B_minimal_$r "GGML_CUDA_FA_PREFILL_F16=65536" "$P/start-min3.ps1" "4000"
  bash run_arm.sh receipts/p45 C_cut258try_$r "$V" "$P/start-cut258try.ps1" "4000"
  bash run_arm.sh receipts/p45 D_lit_$r "$V" "$P/start-server-8gblit.ps1" "4000"
done
grep -H "mean decode" receipts/p45/*.txt | sed 's#receipts/p45/##' > receipts/p45/summary.txt
echo "$(date +%T) end" >> receipts/jobrun3.log
