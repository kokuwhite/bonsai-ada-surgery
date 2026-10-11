#!/usr/bin/env bash
# After P11b: P14 prefill A/B, then build sudoingX bonsai2 for sm_75, then P13 floor. Do not edit while running.
cd /c/bonsai/8gb
until grep -qE "p11b done|STOP FAILED|serve failed" receipts/p11b/p11b.txt 2>/dev/null; do sleep 30; done
P12B='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p12;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_PCT=0'
R=receipts/p14
bash run_arm.sh $R n77568 "$P12B;BONSAI_KV_VRAM_CELLS=77568" "" "4000"
bash run_arm.sh $R n77568_bi "$P12B;BONSAI_KV_VRAM_CELLS=77568;GGML_CUDA_BATCH_INVARIANT=1" "" "4000"
bash run_arm.sh $R n38656 "$P12B;BONSAI_KV_VRAM_CELLS=38656" "" "4000"
bash run_arm.sh $R n77568_r2 "$P12B;BONSAI_KV_VRAM_CELLS=77568" "" "4000"
echo "p14 done" > $R/done.txt
# build sudo
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Location C:\bonsai\bonsai-ada-surgery; & .\build\build_windows.ps1 -Arch 75 -Src 'C:\bonsai\bonsai-ada-surgery\vendor\sudo-bonsai2' -Build 'C:\bonsai\bonsai-ada-surgery\tooling\build-sudo' -Out 'C:\bonsai\bonsai-ada-surgery\bin-sudo'" > logs/build-sudo.log 2>&1
echo "build-sudo exit $?" >> logs/build-sudo.log
[ -f /c/bonsai/bonsai-ada-surgery/bin-sudo/llama-server.exe ] || { echo "no bin-sudo" > receipts/p13-failed.txt; exit 1; }
M='C:\bonsai\bonsai-ada-surgery\models\Ternary-Bonsai-2-27B-PTQ1_0.gguf'
SUDO="raw:C:\bonsai\bonsai-ada-surgery\bin-sudo\llama-server.exe -m $M -c 65536 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --jinja --reasoning-effort medium --temp 1.0 --top-p 0.95 --top-k 20 --host 127.0.0.1 --port 8899"
OURS='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p12;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_MAX_KB=1024'
C2="$OURS;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_SPEC_DEEP=2;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256;BONSAI_KV_VRAM_CELLS=38400"
BB="$OURS;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0;BONSAI_KV_VRAM_CELLS=77568"
R=receipts/p13
bash run_arm.sh $R sudo1 "" "$SUDO"
bash run_arm.sh $R oursC2 "$C2"
bash run_arm.sh $R oursB "$BB"
bash run_arm.sh $R sudo2 "" "$SUDO"
echo "p13 done" > $R/done.txt
