#!/usr/bin/env bash
# P102c: sparse host-tail reads, decode speed at 245k on fa-sparse-proto ae61c4cf3 (no per-op / per-write syncs; verify
# batches up to 64 queries stage only the kept pages). Arms: s8192 lookup off; dense lookup on; s8192 lookup on.
# Dense lookup off = P102 (5.7 tok/s). Checks: no "one sync per K write" warning; the "fast: N ops" WARN line appears.
cd /c/bonsai/8gb; R=receipts/p102c; mkdir -p $R
export QTPS_TIMEOUT=7200
for i in 1 2 3; do cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-sparse\build.bat' > logs/build-sparse3.log 2>&1
  [ -f /c/bonsai/bonsai-ada-surgery/tooling/build-sparse/bin/llama-server.exe ] && ! grep -q "build stopped" logs/build-sparse3.log && break; done
grep -q "build stopped" logs/build-sparse3.log && { echo "build failed" > $R/summary.txt; exit 1; }
rm -rf /c/bonsai/bonsai-ada-surgery/bin-sparse3 && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-sparse/bin /c/bonsai/bonsai-ada-surgery/bin-sparse3
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-sparse3/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-sparse3/; done
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse3;BONSAI_LAYER=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768'
SP='GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
bash run_arm.sh $R s8192_lkoff "$BASEV;BONSAI_LOOKUP=0;$SP" "$L" "245000"
bash run_arm.sh $R dense_lkon "$BASEV" "$L" "245000"
bash run_arm.sh $R s8192_lkon "$BASEV;$SP" "$L" "245000"
{ for a in s8192_lkoff dense_lkon s8192_lkon; do f=$R/$a.txt; E=$(ls -t logs/*-$a.err.log | head -1)
    echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|accept|did not|rror" $f | sed -E 's/ttft +[0-9.]+s +//'
    echo "   sync-per-write warning lines: $(grep -c 'one sync per K write' $E)"; grep -m1 -E "FA_SPARSE.*fast:" $E | cut -c1-200; grep -E "FA_SPARSE.*fast:" $E | tail -1 | cut -c1-200; done
  echo "-- P102 dense lookup off: 5.7 tok/s decode, 79 tok/s 512-token prefill"; } > $R/summary.txt
