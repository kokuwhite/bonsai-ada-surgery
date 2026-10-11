#!/usr/bin/env bash
# Wait for the KL run and the tests build, run test-backend-ops MUL_MAT on the Turing build, then the P9 soak.
# Do not edit while running.
R=/c/bonsai/8gb/receipts
T=/c/bonsai/bonsai-ada-surgery/tooling/build-turing/bin
while powershell -NoProfile -Command "if (Get-Process llama-perplexity -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"; do sleep 10; done
until grep -q "^exit" /c/bonsai/8gb/logs/build-turing-tests.log 2>/dev/null; do sleep 10; done
grep -q "^exit 0" /c/bonsai/8gb/logs/build-turing-tests.log || { echo "tests build failed" > $R/p8-test-backend-ops.txt; exit 1; }
cd $T
CUDA=/c/Users/USER/AppData/Local/Programs/Python/Python312/Lib/site-packages/nvidia/cu13
export PATH="$CUDA/bin:$CUDA/bin/x86_64:$PATH"
{ echo "== default (new build, PT at one column on sm_75)"; ./test-backend-ops.exe -o MUL_MAT -b CUDA0 2>&1 | grep -E "ptq1|PTQ1|FAIL|passed|Backend" | tail -40
  echo "== GGML_CUDA_BATCH_INVARIANT=1"; GGML_CUDA_BATCH_INVARIANT=1 ./test-backend-ops.exe -o MUL_MAT -b CUDA0 2>&1 | grep -E "FAIL|passed|Backend" | tail -10
} > $R/p8-test-backend-ops.txt 2>&1
cd /c/bonsai/8gb && bash p9.sh > $R/p9-run.out 2>&1
