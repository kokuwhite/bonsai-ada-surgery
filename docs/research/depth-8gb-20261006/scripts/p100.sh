#!/usr/bin/env bash
# P100: quality cost of a lower-bit KV format (fake 3-bit / 2-bit on the q4_0 grid, GGML_CUDA_KV_FAKE_BITS) by
# perplexity on wikitext-2 test: 16k window (all chunks) and 64k window (2 chunks). Same bin, same VRAM line.
cd /c/bonsai/8gb; R=receipts/p100; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
rm -rf /c/bonsai/bonsai-ada-surgery/bin-fakekv && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-fakekv/bin /c/bonsai/bonsai-ada-surgery/bin-fakekv
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-fakekv/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-fakekv/; done
P=/c/bonsai/bonsai-ada-surgery/bin-fakekv/llama-perplexity.exe
M=C:/bonsai/bonsai-ada-surgery/models/Ternary-Bonsai-2-27B-PTQ1_0.gguf
F=C:/bonsai/bonsai-ada-surgery/artifacts/eval/wiki.test.raw
for ctx in 16384 65536; do
  CH=""; [ $ctx = 65536 ] && CH="--chunks 2"
  for bits in 0 3 2; do
    env GGML_CUDA_KV_FAKE_BITS=$bits GGML_CUDA_FA_PREFILL_F16=32768 GGML_CUDA_FA_CHUNK=32768 \
      $P -m $M -f $F -c $ctx -b 2048 -ub 512 $CH -ngl 99 -fa on -ctk q4_0 -ctv q4_0 --kv-vram-cells 45056 < /dev/null > $R/c${ctx}_b$bits.log 2>&1
    echo "ctx $ctx bits $bits: $(grep -oE 'Final estimate: PPL = [0-9.]+ \+/- [0-9.]+' $R/c${ctx}_b$bits.log)" >> $R/summary.txt
  done
done
grep -hiE "error|failed" $R/*.log | grep -v "fit params" | head -5 >> $R/summary.txt
