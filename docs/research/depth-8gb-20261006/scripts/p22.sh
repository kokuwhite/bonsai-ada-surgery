#!/usr/bin/env bash
# P22: packed KQ mask. After P20 sweeps and the bin-p22 build. Do not edit while running.
cd /c/bonsai/8gb
until grep -q "p20 sweeps done" receipts/p20/p20.txt 2>/dev/null && grep -q "build-p22 exit" logs/build-p22.log 2>/dev/null; do sleep 30; done
R=receipts/p22; mkdir -p $R; LOG=$R/p22.txt
grep -q "build-p22 exit 0" logs/build-p22.log && [ -f /c/bonsai/bonsai-ada-surgery/bin-p22/llama-server.exe ] || { echo "no bin-p22" | tee -a $LOG; exit 1; }
# 1. kernel test
T=/c/bonsai/bonsai-ada-surgery/tooling/build-p22/bin; CU=/c/Users/USER/AppData/Local/Programs/Python/Python312/Lib/site-packages/nvidia/cu13
( cd $T && PATH="$CU/bin:$CU/bin/x86_64:$PATH" ./test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 2>&1 | grep -E "FAIL|passed|Backend" | tail -6 ) | tee -a $LOG
COM='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-p22;BONSAI_CTX=131072;BONSAI_CTK=q4_0;BONSAI_LAYER=0;GGML_CUDA_L2_PREFETCH_MAX_KB=1024'
DR="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations-q4head.gguf;BONSAI_SPEC=1;BONSAI_SPEC_DEEP=1;BONSAI_DRAFT_WINDOW=16384;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256"
LC="$COM;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_SPEC=0"
# 2-3. identity and VRAM at the default N, unpacked vs packed (probe texts at 4k and 16k)
for v in unpacked packed; do
    extra=""; [ $v = packed ] && extra=";LLAMA_ARG_KQ_MASK_PACKED=1"
    bash run_arm.sh $R dr_$v "$DR;BONSAI_KV_VRAM_CELLS=47360$extra" "" "4000"
done
# re-serve each to capture texts with the probe (same seeds/prompts both ways)
for v in unpacked packed; do
    extra=""; [ $v = packed ] && extra=";LLAMA_ARG_KQ_MASK_PACKED=1"
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
    for i in $(seq 1 60); do [ $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) -lt 1500 ] && break; sleep 1; done; sleep 2
    powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\serve.ps1' -Tag "p22-txt-$v" -Vars "$DR;BONSAI_KV_VRAM_CELLS=47360$extra" -Launcher 'C:/bonsai/8gb/start-server-bin.ps1' >> $LOG 2>&1
    L=$(cat logs/current.log | tr -d '\r\n' | sed 's#\\#/#g; s#^C:#/c#')
    for i in $(seq 1 150); do grep -q "listening on http" "${L%.out.log}.err.log" 2>/dev/null && break; sleep 2; done
    python memclock_probe.py --tag txt4k_$v --out C:/bonsai/8gb/receipts/p22 --reps 1 --depth 4000 | tail -1 | tee -a $LOG
    python memclock_probe.py --tag txt16k_$v --out C:/bonsai/8gb/receipts/p22 --reps 1 --depth 16000 | tail -1 | tee -a $LOG
done
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\bonsai\8gb\stop.ps1' >> $LOG 2>&1
python - <<'PY' | tee -a $LOG
import json
D = "C:/bonsai/8gb/receipts/p22/"
for d in ("4k", "16k"):
    a = json.load(open(f"{D}txt{d}_unpacked.json", encoding="utf-8"))["rows"]; b = json.load(open(f"{D}txt{d}_packed.json", encoding="utf-8"))["rows"]
    print(f"packed vs unpacked texts at {d}: " + ("IDENTICAL" if all(x["text"] == y["text"] for x, y in zip(a, b)) else "DIFFER"))
PY
su=$(grep -o "server [0-9]*" $R/dr_unpacked.txt | head -1 | awk '{print $2}'); sp=$(grep -o "server [0-9]*" $R/dr_packed.txt | head -1 | awk '{print $2}')
idle=$(grep -o "idle [0-9]*" $R/dr_packed.txt | head -1 | awk '{print $2}')
N=$(python -c "
sp=$sp; idle=$idle; MiB=1<<20
fixed = sp*MiB - 47360*18432 - (131072-47360)*1152
n = ((8007 - 257 - idle)*MiB - fixed - 131072*1152)//17280
print(max(16384, min(131072, int(n)//256*256)))")
echo "server unpacked $su packed $sp MiB (saved $((su - sp))); drafting resized N=$N" | tee -a $LOG
# 4. drafting default resized
bash run_arm.sh $R dr_packed_n$N "$DR;BONSAI_KV_VRAM_CELLS=$N;LLAMA_ARG_KQ_MASK_PACKED=1" "" "4000 16000 32000 60000"
# 5. long mode: ub 512 vs 1024, packed
bash run_arm.sh $R lc_packed_ub512 "$LC;BONSAI_KV_VRAM_CELLS=67840;LLAMA_ARG_KQ_MASK_PACKED=1" "" "4000 32000"
bash run_arm.sh $R lc_packed_ub1024 "$LC;BONSAI_KV_VRAM_CELLS=67840;LLAMA_ARG_KQ_MASK_PACKED=1;BONSAI_UBATCH=1024" "" "4000 32000"
echo "p22 done" | tee -a $LOG
