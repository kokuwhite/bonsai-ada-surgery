#!/usr/bin/env bash
# P25: f16 prefill from pool memory. After the bin-p25 build and P24. Do not edit while running.
cd /c/bonsai/8gb
until grep -q "build-p25 exit" logs/build-p25.log 2>/dev/null && grep -q "p24 done" receipts/p24/p24.txt 2>/dev/null; do sleep 30; done
R=receipts/p25; mkdir -p $R; LOG=$R/p25.txt
[ -f /c/bonsai/bonsai-ada-surgery/bin-p25/llama-server.exe ] || { echo "no bin-p25" | tee -a $LOG; exit 1; }
T=/c/bonsai/bonsai-ada-surgery/tooling/build-p25/bin; CU=/c/Users/USER/AppData/Local/Programs/Python/Python312/Lib/site-packages/nvidia/cu13
echo "== test-backend-ops FLASH_ATTN_EXT, GGML_CUDA_FA_PREFILL_F16=1048576" | tee -a $LOG
( cd $T && GGML_CUDA_FA_PREFILL_F16=1048576 PATH="$CU/bin:$CU/bin/x86_64:$PATH" ./test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 2>&1 | grep -E "FAIL|passed|Backend" | tail -6 ) | tee -a $LOG
COM='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p25;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0'
LC="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0;BONSAI_KV_VRAM_CELLS=58112"
DR="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_SPEC_DEEP=1;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256;BONSAI_KV_VRAM_CELLS=47360"
# identity: texts at 32k, in-place vs f16 prefill
for v in native f16; do
    extra=""; [ $v = f16 ] && extra=";GGML_CUDA_FA_PREFILL_F16=65536"
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
    for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p25-txt-$v" -Vars "$LC$extra" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1
    L=$(cat logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    python depth_text_probe.py --tag txt32k_$v --depth 32000 --n 120 --out C:/bonsai/8gb/receipts/p25 | tee -a $LOG
done
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
python - <<'PY' | tee -a $LOG
import json
D = "C:/bonsai/8gb/receipts/p25/"
a = json.load(open(D + "txt32k_native.json", encoding="utf-8")); b = json.load(open(D + "txt32k_f16.json", encoding="utf-8"))
print("f16-prefill vs in-place texts at 32k: " + ("IDENTICAL" if all(x["text"] == y["text"] for x, y in zip(a, b)) else "DIFFER"))
PY
# speed, P20 sequence
bash run_arm.sh $R lc_native "$LC" "" "4000 16000 32000 60000"
bash run_arm.sh $R lc_f16 "$LC;GGML_CUDA_FA_PREFILL_F16=65536" "" "4000 16000 32000 60000"
bash run_arm.sh $R dr_native "$DR" "" "4000 16000 32000"
bash run_arm.sh $R dr_f16_32k "$DR;GGML_CUDA_FA_PREFILL_F16=32768" "" "4000 16000 32000"
bash run_arm.sh $R lc_f16_r2 "$LC;GGML_CUDA_FA_PREFILL_F16=65536" "" "4000 16000 32000 60000"
echo "p25 done" | tee -a $LOG
