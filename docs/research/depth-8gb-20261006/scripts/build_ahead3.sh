#!/usr/bin/env bash
cd /c/bonsai/8gb
echo "$(date +%T) build poolsync" >> receipts/build_ahead.log
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-poolsync\build.bat' > logs/build-poolsync.log 2>&1; echo "$(date +%T) poolsync exit $?" >> receipts/build_ahead.log
