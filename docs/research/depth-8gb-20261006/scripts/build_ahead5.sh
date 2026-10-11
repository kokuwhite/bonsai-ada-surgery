#!/usr/bin/env bash
cd /c/bonsai/8gb
echo "$(date +%T) build tune" >> receipts/build_ahead.log
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-tune\build.bat' > logs/build-tune.log 2>&1; echo "$(date +%T) tune exit $?" >> receipts/build_ahead.log
