#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p39a; mkdir -p $R; OUT=$R/table.txt; : > $OUT
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
for s in 5 1 2 1 2 5; do
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P$s >/dev/null; sleep 6
  ( for i in $(seq 1 40); do nvidia-smi --query-gpu=clocks.mem,clocks.sm,power.draw,temperature.gpu,power.limit --format=csv,noheader; sleep 2; done ) > $R/clk_$s_$RANDOM.txt &
  CP=$!
  r=$(cd /c/bonsai/bonsai-ada-surgery/bin-rc3 && ./llama-bench.exe -m ../models/Ternary-Bonsai-2-27B-PTQ1_0.gguf -ngl 99 -fa 1 -ctk q4_0 -ctv q4_0 -p 0 -n 256 -r 3 2>&1 | grep tg256 | awk -F'|' '{print $(NF-1)}')
  kill $CP 2>/dev/null
  clk=$(nvidia-smi --query-gpu=clocks.max.mem,power.limit --format=csv,noheader)
  echo "slot $s tg256 $r  maxmem/plimit $clk" >> $OUT
done
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null
echo done >> $OUT
