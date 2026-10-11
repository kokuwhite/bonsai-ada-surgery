#!/usr/bin/env bash
cd /c/bonsai/8gb
echo "$(date +%T) build tune2 (-j 4)" >> receipts/build_ahead.log
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-tune\build-j4.bat' > logs/build-tune2.log 2>&1
B=/c/bonsai/bonsai-ada-surgery/tooling/build-tune/bin
if [ -f $B/llama-server.exe ] && [ -f $B/test-backend-ops.exe ] && ! grep -q "build stopped" logs/build-tune2.log; then echo "$(date +%T) tune2 exit 0" >> receipts/build_ahead.log; else echo "$(date +%T) tune2 exit 1" >> receipts/build_ahead.log; fi
