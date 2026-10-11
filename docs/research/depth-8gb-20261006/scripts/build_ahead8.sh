#!/usr/bin/env bash
cd /c/bonsai/8gb
echo "$(date +%T) build pmask (-j 4)" >> receipts/build_ahead.log
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-pmask\build.bat' > logs/build-pmask.log 2>&1
B=/c/bonsai/bonsai-ada-surgery/tooling/build-pmask/bin
if [ -f $B/llama-server.exe ] && [ -f $B/test-backend-ops.exe ] && ! grep -q "build stopped" logs/build-pmask.log; then echo "$(date +%T) pmask exit 0" >> receipts/build_ahead.log; else echo "$(date +%T) pmask exit 1" >> receipts/build_ahead.log; fi
