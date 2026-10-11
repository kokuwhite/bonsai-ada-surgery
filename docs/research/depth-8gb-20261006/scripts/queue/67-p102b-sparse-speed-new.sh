#!/usr/bin/env bash
# P102b: P102's sparse speed arm on the newer fa-sparse-proto c084831aa (device page selection, no per-op syncs,
# bounds follow writes). Dense baseline = P102's dense arm (the dense path is unchanged).
cd /c/bonsai/8gb; R=receipts/p102b; mkdir -p $R
export QTPS_TIMEOUT=7200
rm -rf /c/bonsai/bonsai-ada-surgery/bin-sparse2 && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-sparse/bin /c/bonsai/bonsai-ada-surgery/bin-sparse2
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-sparse2/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-sparse2/; done
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse2;BONSAI_LAYER=0;BONSAI_LOOKUP=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768'
bash run_arm.sh $R s8192_new "$BASEV;GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9" "$L" "245000"
E=$(ls -t logs/*-s8192_new.err.log | head -1)
grep -E "FA_SPARSE|host tail kept" "$E" | head -2 > $R/sparse_lines.txt; grep -E "FA_SPARSE|host tail kept" "$E" | tail -2 >> $R/sparse_lines.txt
{ echo "== s8192_new: $(grep -c '(1 tok)' $R/s8192_new.txt) one-token"; grep -E "loaded|depth|mean decode|accept|did not|rror" $R/s8192_new.txt | sed -E 's/ttft +[0-9.]+s +//'; cat $R/sparse_lines.txt;
  echo "-- P102 dense for comparison:"; grep -A6 "== dense" receipts/p102/summary.txt; } > $R/summary.txt
