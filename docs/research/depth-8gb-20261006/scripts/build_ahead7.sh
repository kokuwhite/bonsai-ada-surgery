#!/usr/bin/env bash
cd /c/bonsai/8gb
echo "$(date +%T) build pstage (-j 4)" >> receipts/build_ahead.log
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-pstage\build.bat' > logs/build-pstage.log 2>&1
B=/c/bonsai/bonsai-ada-surgery/tooling/build-pstage/bin
if [ -f $B/llama-server.exe ] && [ -f $B/test-backend-ops.exe ] && ! grep -q "build stopped" logs/build-pstage.log; then echo "$(date +%T) pstageR exit 0" >> receipts/build_ahead.log; else echo "$(date +%T) pstageR exit 1" >> receipts/build_ahead.log; fi
