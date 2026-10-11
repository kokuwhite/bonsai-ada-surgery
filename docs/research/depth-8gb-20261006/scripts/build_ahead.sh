#!/usr/bin/env bash
# CPU-only: pre-build queued engines so the GPU jobs find nothing to compile.
cd /c/bonsai/8gb
echo "$(date +%T) build tier" >> receipts/build_ahead.log
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-tier\build.bat' > logs/build-tier.log 2>&1; echo "$(date +%T) tier exit $?" >> receipts/build_ahead.log
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-ckpt\build.bat' > logs/build-ckpt.log 2>&1; echo "$(date +%T) ckpt exit $?" >> receipts/build_ahead.log
