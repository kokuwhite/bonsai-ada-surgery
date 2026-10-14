#!/usr/bin/env bash
# P117: HumanEval 164 on the 8 GB 262k launcher with q3_0 K/V (bin-q3kv, kv-q3-0 6a4851286 on 2cadbfb64).
# Same harness as P87 (bench/humaneval_run.py, arm medium, temp 0, max tokens 20480), layer off.
# Reference: P87 = 158/164 (96.34 %) with q4_0 on bin-pmask; P53 = 158/164 (lookup on); P31 = 157/164.
# Gate (declared here, before the run): q3_0 >= 157/164 (the lowest q4_0 8 GB result, P31) -> no quality cost on code;
# report the failed task ids vs P87's 6 failures.
cd /c/bonsai/8gb; R=receipts/p117; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
grep -q "'q3_0' { 14336 }" $L 2>/dev/null || grep -q "'q3_0' { 14336 }" /c/bonsai/bonsai-ada-surgery/start-server-1010test.ps1 || { echo "launcher copy lacks q3_0" > $R/summary.txt; exit 1; }
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p117_humaneval_q3 -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-q3kv;BONSAI_LAYER=0;BONSAI_CTK=q3_0" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
O=$(ls -t logs/*p117_humaneval_q3*.out.log 2>/dev/null | head -1); [ -n "$O" ] && grep -hE "^(window|kv)" "$O" > $R/launcher_lines.txt
cd /c/bonsai/bonsai-ada-surgery && python bench/humaneval_run.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --arm medium --temp 0 --max-tokens 20480 < /dev/null > /c/bonsai/8gb/$R/humaneval.txt 2>&1
cd /c/bonsai/8gb && powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ tail -8 $R/humaneval.txt; cat $R/launcher_lines.txt 2>/dev/null; echo "P87 q4_0: 158/164"; } > $R/summary.txt
