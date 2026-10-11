#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p87; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p87_humaneval -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-pmask;BONSAI_LAYER=0" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
grep -hE "^(window|kv)" "$(cat logs/current.log | tr -d '\r' | sed 's#\#/#g; s#^C:#/c#')" > $R/launcher_lines.txt 2>/dev/null
cd /c/bonsai/bonsai-ada-surgery && python bench/humaneval_run.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --arm medium --temp 0 --max-tokens 20480 < /dev/null > /c/bonsai/8gb/$R/humaneval.txt 2>&1
cd /c/bonsai/8gb && powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
tail -5 $R/humaneval.txt > $R/summary.txt; cat $R/launcher_lines.txt >> $R/summary.txt
