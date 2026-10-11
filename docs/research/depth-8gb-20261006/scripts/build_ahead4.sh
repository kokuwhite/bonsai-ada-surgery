#!/usr/bin/env bash
cd /c/bonsai/8gb
echo "$(date +%T) build fuse" >> receipts/build_ahead.log
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-fuse\build.bat' > logs/build-fuse.log 2>&1; echo "$(date +%T) fuse exit $?" >> receipts/build_ahead.log
