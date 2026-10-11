#!/usr/bin/env bash
# P108: first GPU tests of the q3_0 KV type (kv-q3-0 6a4851286, WIP, built during P104).
# 1. test-backend-ops (q3_0 cases: SET_ROWS, GET_ROWS, CPY, FLASH_ATTN_EXT) vs CPU.
# 2. perplexity q3_0 vs q4_0 on the same binary, wikitext-2: 16k (all chunks), 64k (2 chunks).
# 3. decode sanity: raw llama-server -c 8192, quick_tps 4k, q3_0 vs q4_0.
cd /c/bonsai/8gb; R=receipts/p108; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
B=/c/bonsai/bonsai-ada-surgery/bin-q3kv
rm -rf $B && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-q3kv/bin $B
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f $B/$b ] || cp $f $B/; done
for op in SET_ROWS GET_ROWS CPY FLASH_ATTN_EXT; do
  echo "$op: $($B/test-backend-ops.exe -o $op -b CUDA0 -p 'q3_0' < /dev/null 2>&1 | grep -E 'tests passed' | tr -d '\r') $($B/test-backend-ops.exe -o $op -b CUDA0 -p 'q3_0' < /dev/null 2>&1 | grep -c FAIL) FAIL" >> $R/tests.txt
done
M=C:/bonsai/bonsai-ada-surgery/models/Ternary-Bonsai-2-27B-PTQ1_0.gguf
F=C:/bonsai/bonsai-ada-surgery/artifacts/eval/wiki.test.raw
for ctx in 16384 65536; do
  CH=""; [ $ctx = 65536 ] && CH="--chunks 2"
  for t in q4_0 q3_0; do
    env GGML_CUDA_FA_PREFILL_F16=32768 GGML_CUDA_FA_CHUNK=32768 $B/llama-perplexity.exe -m $M -f $F -c $ctx -b 2048 -ub 512 $CH -ngl 99 -fa on -ctk $t -ctv $t --kv-vram-cells 45056 < /dev/null > $R/ppl_c${ctx}_$t.log 2>&1
    echo "ctx $ctx $t: $(grep -oE 'Final estimate: PPL = [0-9.]+ \+/- [0-9.]+' $R/ppl_c${ctx}_$t.log)" >> $R/ppl.txt
  done
done
BW='C:\bonsai\bonsai-ada-surgery\bin-q3kv\llama-server.exe'
for t in q4_0 q3_0; do
  bash run_arm.sh $R speed_$t "" "raw:$BW -m $M -c 8192 -ngl 99 -fa on -np 1 -ctk $t -ctv $t --host 127.0.0.1 --port 8899" "4000"
done
{ cat $R/tests.txt $R/ppl.txt; for t in q4_0 q3_0; do echo "decode 4k $t: $(grep 'mean decode' $R/speed_$t.txt) $(grep -c '(1 tok)' $R/speed_$t.txt) one-token"; done
  grep -hiE "error|failed|unsupported|abort" $R/ppl_*.log | grep -v "fit params" | head -5; } > $R/summary.txt
