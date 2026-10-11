#!/usr/bin/env bash
# P95: CPU vs GPU flash attention for decode at depth, Bonsai shape (q4_0 K/V, head 256, 4 KV heads, GQA 6, 1-2 queries).
# Runs alone (no server). CPU backend: all 12 threads, AVX2. CUDA0: K/V in VRAM (an upper bound for the GPU, not the
# PCIe-bound host read).
cd /c/bonsai/8gb; R=receipts/p95; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
rm -rf /c/bonsai/bonsai-ada-surgery/bin-cpuattn && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-cpuattn/bin /c/bonsai/bonsai-ada-surgery/bin-cpuattn
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-cpuattn/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-cpuattn/; done
T=/c/bonsai/bonsai-ada-surgery/bin-cpuattn/test-backend-ops.exe
F='hsk=256,hsv=256,nh=4,nr23=\[6,1\],kv=(32768|65536|131072|196608)'
for b in CPU CUDA0; do
  "$T" perf -o FLASH_ATTN_EXT -b $b -p "$F" < /dev/null > $R/perf_$b.txt 2>&1
done
python - > $R/summary.txt <<'PY'
import re
for b in ('CPU', 'CUDA0'):
    for line in open(f'receipts/p95/perf_{b}.txt', errors='ignore'):
        m = re.search(r'kv=(\d+),nb=(\d+).*?([0-9.]+) us/run', line)
        if m:
            kv, nb, us = int(m.group(1)), int(m.group(2)), float(m.group(3))
            print(f"{b:6s} kv {kv:6d} nb {nb}: {us/1000:8.2f} ms per layer")
PY
