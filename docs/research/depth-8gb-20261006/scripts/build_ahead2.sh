#!/usr/bin/env bash
cd /c/bonsai/8gb
until grep -q "ckpt exit" receipts/build_ahead.log 2>/dev/null; do sleep 30; done
echo "$(date +%T) build minq" >> receipts/build_ahead.log
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-minq\build.bat' > logs/build-minq.log 2>&1; echo "$(date +%T) minq exit $?" >> receipts/build_ahead.log
