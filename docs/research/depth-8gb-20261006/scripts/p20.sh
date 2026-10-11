#!/usr/bin/env bash
# P20: release candidate. Waits for P16b. Do not edit while running.
cd /c/bonsai/8gb
until grep -q "^done" receipts/p16b/table.txt 2>/dev/null; do sleep 30; done
R=receipts/p20; mkdir -p $R; LOG=$R/p20.txt
echo "P20 $(date -Iseconds)" >> $LOG
# 1. release engine, all bundle architectures
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Location C:\bonsai\bonsai-ada-surgery; & .\build\build_windows.ps1 -Arch '75;86;89;89-virtual' -Src 'C:\bonsai\bonsai-ada-surgery\vendor\prism-pool' -Build 'C:\bonsai\bonsai-ada-surgery\tooling\build-rc' -Out 'C:\bonsai\bonsai-ada-surgery\bin-rc'" > logs/build-rc.log 2>&1
echo "build-rc exit $? $(ls /c/bonsai/bonsai-ada-surgery/bin-rc/llama-server.exe 2>&1)" | tee -a $LOG
[ -f /c/bonsai/bonsai-ada-surgery/bin-rc/llama-server.exe ] || exit 1
# 2. repo requant script, end to end on a copy (never touches the live model files)
M=/c/bonsai/bonsai-ada-surgery/models
mkdir -p $M/rc-test && cp $M/Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf $M/rc-test/
cp -r /c/bonsai/bas-display-detect/build/requant_mtp.py /c/bonsai/bas-display-detect/build/make_mtp_q4head.ps1 /c/bonsai/bonsai-ada-surgery/build/ 2>/dev/null
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Location C:\bonsai\bonsai-ada-surgery; & .\build\make_mtp_q4head.ps1 -Src 'models\rc-test\Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf'" >> $LOG 2>&1
echo "repo requant script exit $?" | tee -a $LOG
cmp $M/rc-test/Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf $M/Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf && echo "repo script output byte-identical to tonight's q4head file" | tee -a $LOG
rm -rf $M/rc-test; rm -f /c/bonsai/bonsai-ada-surgery/build/requant_mtp.py /c/bonsai/bonsai-ada-surgery/build/make_mtp_q4head.ps1
until [ -f receipts/p21/done.txt ]; do sleep 30; done   # P21 replays use the GPU during the build
# 3. both modes, twice
COM='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0'
DR="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_SPEC_DEEP=1;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256;BONSAI_KV_VRAM_CELLS=47360"
LC="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0;BONSAI_KV_VRAM_CELLS=67840"
for r in 1 2; do
    bash run_arm.sh $R draft_r$r "$DR" "" "4000 16000 32000 60000"
    bash run_arm.sh $R long_r$r "$LC" "" "4000 16000 32000 60000"
done
echo "one-token answers: $(cat $R/draft_r*.txt $R/long_r*.txt | grep -c '(1 tok)')" | tee -a $LOG
echo "p20 sweeps done" | tee -a $LOG
