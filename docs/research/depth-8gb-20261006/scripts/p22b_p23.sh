#!/usr/bin/env bash
# P22b: packed mask with the draft-context fix. P23: which dev-build change is +11% prefill at depth. Do not edit while running.
cd /c/bonsai/8gb
R=receipts/p22b; mkdir -p $R; LOG=$R/p22b.txt
COM='BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0'
DR="BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p22;$COM;GGML_CUDA_L2_PREFETCH_PCT=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_SPEC_DEEP=1;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256"
bash run_arm.sh $R dr_packed_fix_n51456 "$DR;BONSAI_KV_VRAM_CELLS=51456;LLAMA_ARG_KQ_MASK_PACKED=1" "" "4000 16000 32000 60000"
# texts at 32k, packed (fixed) vs unpacked, same N
for v in unpacked packed; do
    extra=""; [ $v = packed ] && extra=";LLAMA_ARG_KQ_MASK_PACKED=1"
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
    for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p22b-txt-$v" -Vars "$DR;BONSAI_KV_VRAM_CELLS=47360$extra" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1
    L=$(cat logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    python depth_text_probe.py --tag txt32k_$v --depth 32000 --n 200 --out C:/bonsai/8gb/receipts/p22b | tee -a $LOG
done
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
python - <<'PY' | tee -a $LOG
import json
D = "C:/bonsai/8gb/receipts/p22b/"
a = json.load(open(D + "txt32k_unpacked.json", encoding="utf-8")); b = json.load(open(D + "txt32k_packed.json", encoding="utf-8"))
print("packed (fixed) vs unpacked texts at 32k with drafting: " + ("IDENTICAL" if all(x["text"] == y["text"] for x, y in zip(a, b)) else "DIFFER"))
PY
echo "p22b done" | tee -a $LOG
# P23: long mode N=67840, 32k prefill, four engines
R=receipts/p23
LC="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0;BONSAI_KV_VRAM_CELLS=67840"
bash run_arm.sh $R turing_only "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-turing;$LC" "" "4000 32000"
bash run_arm.sh $R rc_turing_pool "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc;$LC" "" "4000 32000"
bash run_arm.sh $R alpha_pf0 "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-alpha;$LC;GGML_CUDA_L2_PREFETCH_PCT=0" "" "4000 32000"
bash run_arm.sh $R alpha_pf1024 "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-alpha;$LC;GGML_CUDA_L2_PREFETCH_MAX_KB=1024" "" "4000 32000"
bash run_arm.sh $R rc_turing_pool_r2 "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc;$LC" "" "4000 32000"
touch $R/done.txt
