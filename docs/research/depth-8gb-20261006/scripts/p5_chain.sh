#!/usr/bin/env bash
# P5 remainder: wait for arm B, re-run arm A, size arm C by measurement, run arm C. Do not edit while running.
cd /c/bonsai/8gb
R=receipts/p5
until grep -q "arm done" $R/B_q4_n38656.txt 2>/dev/null; do sleep 10; done

bash p5_arm2.sh A_q8_n16384_r2 'BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf;BONSAI_CTX=131072;BONSAI_SPEC=0;BONSAI_CTK=q8_0;BONSAI_KV_VRAM_CELLS=16384;BONSAI_LAYER=0;GGML_CUDA_BATCH_INVARIANT=1'

# C sizing: load with N=8192, read the server's VRAM, solve for the fixed cost with the head on.
CVARS='BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf;BONSAI_CTX=131072;BONSAI_SPEC=1;BONSAI_SPEC_DEEP=2;BONSAI_DRAFT_WINDOW=16384;BONSAI_CTK=q4_0;BONSAI_LAYER=0'
bash p5_arm2.sh C_sizing_n8192 "$CVARS;BONSAI_KV_VRAM_CELLS=8192" "4000"
NC=$(python - <<'EOF'
import re
t = open("receipts/p5/C_sizing_n8192.txt", encoding="utf-8").read()
idle = int(re.search(r"idle used before: (\d+)", t).group(1))
used = int(re.search(r"after load: (\d+) MiB", t).group(1))
MiB = 1 << 20
server = (used - idle) * MiB
fixed = server - 8192 * 18432 - (131072 - 8192) * 1152
budget = 6656 * MiB
n = (budget - fixed - 131072 * 1152) // 17280
print(int(n // 256 * 256))
open("receipts/p5/C_sizing_solve.txt", "w").write(
    f"idle {idle} used {used} server {server // MiB} MiB, fixed with head {fixed / MiB:.0f} MiB, N for 6656 MiB = {int(n // 256 * 256)}\n")
EOF
)
cat $R/C_sizing_solve.txt
if [ -z "$NC" ] || [ "$NC" -lt 2048 ]; then echo "C does not fit the budget (N=$NC)" >> $R/C_sizing_solve.txt; exit 0; fi
bash p5_arm2.sh C_q4_head_n$NC "$CVARS;BONSAI_KV_VRAM_CELLS=$NC"
echo "chain done" >> $R/C_sizing_solve.txt
