#!/usr/bin/env bash
# P89c: chunked prefill quality. Perplexity at a 64k window on wikitext-2 test (2 chunks of 65,536 tokens):
# in-place q4_0 (release path past 32k), whole-cache f16, chunked f16 (C=32768). Same bin, same VRAM line.
cd /c/bonsai/8gb; R=receipts/p89c; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
P=/c/bonsai/bonsai-ada-surgery/bin-chunk/llama-perplexity.exe; cp -n /c/bonsai/bonsai-ada-surgery/tooling/build-chunk/bin/*.dll /c/bonsai/bonsai-ada-surgery/bin-chunk/ 2>/dev/null
[ -f $P ] || cp /c/bonsai/bonsai-ada-surgery/tooling/build-chunk/bin/llama-perplexity.exe /c/bonsai/bonsai-ada-surgery/bin-chunk/
M=C:/bonsai/bonsai-ada-surgery/models/Ternary-Bonsai-2-27B-PTQ1_0.gguf
F=C:/bonsai/bonsai-ada-surgery/artifacts/eval/wiki.test.raw
ARGS="-m $M -f $F -c 65536 -b 2048 -ub 512 --chunks 2 -ngl 99 -fa on -ctk q4_0 -ctv q4_0 --kv-vram-cells 45056"
for arm in inplace whole chunk; do
  case $arm in
    inplace) E="GGML_CUDA_FA_PREFILL_F16=32768" ;;
    whole)   E="GGML_CUDA_FA_PREFILL_F16=65536" ;;
    chunk)   E="GGML_CUDA_FA_PREFILL_F16=32768 GGML_CUDA_FA_CHUNK=32768" ;;
  esac
  env $E $P $ARGS < /dev/null > $R/$arm.log 2>&1
  echo "$arm: $(grep -oE 'Final estimate: PPL = [0-9.]+ \+/- [0-9.]+' $R/$arm.log) $(grep -oE '\[[0-9]+\][0-9.]+' $R/$arm.log | tr '\n' ' ')" >> $R/summary.txt
done
grep -hE "error|failed|invalid argument" $R/*.log | head -5 >> $R/summary.txt
