#!/usr/bin/env bash
# P37: decode cost of each small-op class (diagnostic skip; outputs are garbage by design). Do not edit while running.
cd /c/bonsai/8gb
R=receipts/p37c; mkdir -p $R; OUT=$R/table.txt; : > $OUT
B='C:\bonsai\bonsai-ada-surgery\tooling\build-p37\bin\llama-server.exe'
M='C:\bonsai\bonsai-ada-surgery\models\Ternary-Bonsai-2-27B-PTQ1_0.gguf'
ARMS="none MUL_MAT_Q GATED_DELTA_NET FLASH_ATTN_EXT RMS_NORM,MUL,CPY,GET_ROWS,SCALE,CONCAT,SWIGLU,CONT,SILU,L2_NORM,SSM_CONV,MUL_MAT_F,SIGMOID,ROPE,SET_ROWS,ADD,SOFTPLUS,EXP,NEG none"
for a in $ARMS; do
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  V="GGML_CUDA_SKIP_OPS=,$a,"
  powershell -NoProfile -ExecutionPolicy Bypass -File serve_raw.ps1 -Tag "p37_$a" -Vars "$V" -Cmd "$B -m $M -c 8192 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --host 127.0.0.1 --port 8899" >/dev/null
  ok=0; for i in $(seq 1 90); do curl -s localhost:8899/health | grep -q ok && { ok=1; break; }; sleep 3; done
  [ $ok = 1 ] || { echo "$a LOAD FAILED" >> $OUT; continue; }
  r=""
  for k in 1 2 3; do
    t=$(curl -s localhost:8899/completion -d '{"prompt":"Write a long story about a lighthouse keeper.","n_predict":256,"temperature":0,"ignore_eos":true,"cache_prompt":false}' | python -c "import sys,json; d=json.load(sys.stdin); print(round(d['timings']['predicted_per_second'],2))" 2>/dev/null)
    r="$r $t"
  done
  echo "$a$r" >> $OUT
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
echo done >> $OUT
