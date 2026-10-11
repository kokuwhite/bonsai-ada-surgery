#!/usr/bin/env bash
# BonsaiJob (headless conhost): P40 deep end, then jobrun2 (P41b, P43, P44, P42). Do not edit while running.
cd /c/bonsai/8gb
echo "jobrun start $(date +%T)" >> receipts/jobrun.log
L8='C:\bonsai\bonsai-ada-surgery\start-server-8gbtest.ps1'
bash run_arm.sh receipts/p40 drafting_deep 'BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0' "$L8" "4000 32000 64000 96000 126000"
bash run_arm.sh receipts/p40 long_deep 'BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf' "$L8" "4000 32000 64000 96000 126000"
touch receipts/p40/done.txt
echo "p40 end $(date +%T)" >> receipts/jobrun.log
bash jobrun2.sh > receipts/jobrun2-run.out 2>&1
echo "jobrun end $(date +%T)" >> receipts/jobrun.log
