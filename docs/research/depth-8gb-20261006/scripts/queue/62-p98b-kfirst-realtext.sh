#!/usr/bin/env bash
# P98b: K-first probe on REAL text at ~200k tokens (Python stdlib source as one prompt + 3 questions about it).
cd /c/bonsai/8gb; R=receipts/p98b; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-kfirst;BONSAI_LAYER=0;GGML_CUDA_FA_CHUNK=32768;GGML_CUDA_KV_TIER_KFIRST_STATS=1;GGML_CUDA_KV_TIER_KFIRST_EVERY=16'
logpath() { cat logs/current.log | tr -d '\r' | sed -e 's#\\#/#g' -e 's#^C:#/c#'; }
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p98b -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
python realtext_probe.py --key-file $KEY --tokens 200000 --out $R/run.jsonl > $R/run.txt 2>&1
O="$(logpath)"; E="${O%out.log}err.log"
grep -E "kfirst" "$E" > $R/kfirst_lines.txt
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json, re, collections
for l in open('receipts/p98b/run.jsonl'):
    r = json.loads(l); print({k: r[k] for k in ('i', 'prompt_tokens', 'completion_tokens', 'wall', 'pp', 'tg')}); print('  ', r['answer'][:200].replace('\n', ' '))
agg = collections.defaultdict(list)
for l in open('receipts/p98b/kfirst_lines.txt'):
    if 'kfirst-sum' not in l: continue
    m = re.search(r'cache_k_l(\d+) .*?mass ([0-9.]+) \| 1e-2 u ([0-9.]+)/([0-9.]+) h ([0-9.]+) \| 1e-3 u ([0-9.]+)/([0-9.]+) h ([0-9.]+) \| 1e-4 u ([0-9.]+)/([0-9.]+) h ([0-9.]+)', l)
    if m: agg[int(m.group(1))].append([float(x) for x in m.groups()[1:]])
print('layer  mass  | 1e-2 union mean (per-head) | 1e-3 union (per-head) | 1e-4 union (per-head)')
for L in sorted(agg):
    v = [sum(c) / len(c) for c in zip(*agg[L])]
    print(f"l{L:<3d} {v[0]:.3f} | {v[1]:.3f} ({v[3]:.3f}) | {v[4]:.3f} ({v[6]:.3f}) | {v[7]:.3f} ({v[9]:.3f})")
PY
