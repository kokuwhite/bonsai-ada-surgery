#!/usr/bin/env bash
# P42: +1000 soak with the clock set before the server starts (no live switch). Do not edit while running.
cd /c/bonsai/8gb; R=receipts/p42; mkdir -p $R
ab() { schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P$1 >/dev/null; sleep 8; nvidia-smi --query-gpu=clocks.max.mem,power.limit,fan.speed --format=csv,noheader >> $R/clocks.txt; }
STOP() { powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1; }
SERVE() { powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p42_$1 -Launcher 'C:/bonsai/bonsai-ada-surgery/start-server-8gbtest.ps1' -Vars 'BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0' >> $R/serve.txt 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && return 0; sleep 5; done; return 1; }
# P40c: deep end on the right engine (P40 ran the launcher's default bin = bundle-20260927). Inserted before the soak.
L8='C:/bonsai/bonsai-ada-surgery/start-server-8gbtest.ps1'
bash run_arm.sh receipts/p40c drafting_deep 'BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0' "$L8" "4000 32000 64000 96000 126000"
bash run_arm.sh receipts/p40c long_deep 'BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf' "$L8" "4000 32000 64000 96000 126000"
STOP; ab 2
SERVE mem1000 || { echo "serve failed mem1000" >> $R/compare.txt; }
python p9_soak.py --base http://127.0.0.1:8080 --tag mem1000 --seconds 3600 --depths 4000,16000,32000 --out $R > $R/mem1000.txt 2>&1
STOP; ab 5
SERVE stock || { echo "serve failed stock" >> $R/compare.txt; }
python p9_soak.py --base http://127.0.0.1:8080 --tag stock --seconds 1200 --depths 4000,16000,32000 --out $R > $R/stock.txt 2>&1
STOP
python - >> $R/compare.txt 2>&1 <<'PY'
import json, os
R = 'receipts/p42/'
ref = {}
for r in json.load(open(R + 'stock.json'))['rows']:
    ref.setdefault((r['depth'], r['prompt']), set()).add(r['text'])
for tag in ['stock', 'mem1000']:
    if not os.path.exists(R + tag + '.json'):
        print(tag, 'MISSING (server died?)'); continue
    d = json.load(open(R + tag + '.json')); rows = d['rows']
    diff = sum(1 for r in rows if r['text'] not in ref.get((r['depth'], r['prompt']), {r['text']}))
    dec = {}
    for r in rows: dec.setdefault(r['depth'], []).append(r['decode'])
    print(tag, 'requests', len(rows), 'texts not in stock set', diff, 'stock variants', max(len(v) for v in ref.values()),
          'decode', {k: round(sum(v) / len(v), 2) for k, v in dec.items()}, 'maxT', d['max_temp'], d['summary'])
PY
echo done >> $R/compare.txt
