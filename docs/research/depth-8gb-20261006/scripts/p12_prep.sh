#!/usr/bin/env bash
# P12 prep after P10b: build bin-p12 and requantize the head (in parallel), then prove the trunk is untouched.
# Do not edit while running.
LOG=/c/bonsai/8gb/logs/p12-prep.log
M=/c/bonsai/bonsai-ada-surgery/models
until grep -qE "p10b done|failed|STOP FAILED|did not start|not stock|not idle" /c/bonsai/8gb/receipts/p10b/p10b.txt 2>/dev/null; do sleep 30; done
echo "prep start $(date -Iseconds)" > $LOG
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Location C:\bonsai\bonsai-ada-surgery; & .\build\build_windows.ps1 -Arch 75 -Src 'C:\bonsai\bonsai-ada-surgery\vendor\prism-p12' -Build 'C:\bonsai\bonsai-ada-surgery\tooling\build-p12' -Out 'C:\bonsai\bonsai-ada-surgery\bin-p12'" > /c/bonsai/8gb/logs/build-p12.log 2>&1 &
BP=$!
PYTHONPATH=/c/bonsai/bonsai-ada-surgery/vendor/prism-llama/gguf-py python /c/bonsai/8gb/tools/requant_mtp.py $M/Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf $M/Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf >> $LOG 2>&1
echo "requant exit $?" >> $LOG
G=$M/donor/bonsai2-small-gpu/graft/tools
python $G/merge.py --strip $M/Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf $M/donor/q4head-strip-check.gguf >> $LOG 2>&1
a=$(sha256sum $M/Ternary-Bonsai-2-27B-PTQ1_0.gguf | cut -c1-64); b=$(sha256sum $M/donor/q4head-strip-check.gguf | cut -c1-64)
echo "base $a" >> $LOG; echo "strip $b" >> $LOG
[ "$a" = "$b" ] && echo "STRIP PROOF OK" >> $LOG || echo "STRIP PROOF FAILED" >> $LOG
rm -f $M/donor/q4head-strip-check.gguf
wait $BP; echo "build-p12 exit $?" >> $LOG
ls /c/bonsai/bonsai-ada-surgery/bin-p12/llama-server.exe >> $LOG 2>&1
echo "prep done" >> $LOG
