#!/usr/bin/env bash
# P33: DFlash 2 on PrismML b10754 vs plain. After P32. Do not edit while running.
cd /c/bonsai/8gb
until grep -q "pass@1" receipts/p32/run.txt 2>/dev/null; do sleep 30; done
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1'
B='C:\bonsai\dflash\bin\llama-server.exe'; M='C:\bonsai\bonsai-ada-surgery\models\Ternary-Bonsai-2-27B-PTQ1_0.gguf'
COM="-m $M -c 16384 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --jinja --host 127.0.0.1 --port 8899"
R=receipts/p33
bash run_arm.sh $R plain "" "raw:$B $COM" "4000 12000"
bash run_arm.sh $R dflash_q2_n3 "" "raw:$B $COM -md C:\bonsai\dflash\Ternary-Bonsai-2-27B-DFlash2-ft5-Q2_K.gguf -ngld 99 --spec-type draft-dflash --spec-draft-n-max 3" "4000 12000"
bash run_arm.sh $R dflash_q2_n7 "" "raw:$B $COM -md C:\bonsai\dflash\Ternary-Bonsai-2-27B-DFlash2-ft5-Q2_K.gguf -ngld 99 --spec-type draft-dflash --spec-draft-n-max 7" "4000 12000"
bash run_arm.sh $R dflash_q4km_n3 "" "raw:$B $COM -md C:\bonsai\dflash\Ternary-Bonsai-2-27B-DFlash2-ft5-Q4_K_M.gguf -ngld 99 --spec-type draft-dflash --spec-draft-n-max 3" "4000 12000"
touch $R/done.txt
