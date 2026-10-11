#!/usr/bin/env bash
# BonsaiJob4: P47 tail sweep. Waits for jobrun2 (soak) to end. Do not edit while running.
cd /c/bonsai/8gb
mkdir receipts/jobrun4.lock 2>/dev/null || exit 1
trap 'rmdir receipts/jobrun4.lock' EXIT
echo "$(date +%T) start" >> receipts/jobrun4.log
until grep -q " end" receipts/jobrun2.log 2>/dev/null && [ ! -d receipts/jobrun2.lock ]; do sleep 60; done
L8='C:/bonsai/bonsai-ada-surgery/start-server-8gbtest.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0'
for t in "1 51200" "2 40960" "3 30720" "4 20480"; do set -- $t
  bash run_arm.sh receipts/p47 tail$1 "$V;BONSAI_SPEC_DEEP=$1;BONSAI_KV_VRAM_CELLS=$2" "$L8" "4000 32000 64000 96000 126000"
done
echo "one-token answers: $(cat receipts/p47/tail*.txt | grep -c '(1 tok)')" > receipts/p47/summary.txt
echo "$(date +%T) end" >> receipts/jobrun4.log
