#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p39b; mkdir -p $R
ab() { schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P$1 >/dev/null; sleep 6; nvidia-smi --query-gpu=clocks.max.mem,power.limit,fan.speed --format=csv,noheader >> $R/clocks.txt; }
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
ab 5
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p39b -Launcher 'C:/bonsai/bonsai-ada-surgery/start-server-8gbtest.ps1' -Vars 'BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-rc3;BONSAI_LAYER=0' > $R/serve.txt 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
curl -s localhost:8080/health | grep -q ok || { echo SERVE FAILED > $R/compare.txt; tail -n 25 "$(cygpath "$(tr -d '\r' < logs/current.log)")" >> $R/compare.txt; echo done >> $R/compare.txt; exit 1; }
python p9_soak.py --base http://127.0.0.1:8080 --tag stock_a --seconds 360 --depths 4000,16000,32000 --out $R > $R/stock_a.txt 2>&1
ab 1; python p9_soak.py --base http://127.0.0.1:8080 --tag mem1000 --seconds 600 --depths 4000,16000,32000 --out $R > $R/mem1000.txt 2>&1
ab 2; python p9_soak.py --base http://127.0.0.1:8080 --tag mem1250 --seconds 600 --depths 4000,16000,32000 --out $R > $R/mem1250.txt 2>&1
ab 5; python p9_soak.py --base http://127.0.0.1:8080 --tag stock_b --seconds 240 --depths 4000,16000,32000 --out $R > $R/stock_b.txt 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/compare.txt <<'PY'
import json
R='receipts/p39b/'
ref={}
for tag in ['stock_a','stock_b']:
    for r in json.load(open(R+tag+'.json'))['rows']: ref.setdefault((r['depth'],r['prompt']),set()).add(r['text'])
for tag in ['stock_a','mem1000','mem1250','stock_b']:
    d=json.load(open(R+tag+'.json')); rows=d['rows']
    diff=sum(1 for r in rows if r['text'] not in ref[(r['depth'],r['prompt'])])
    dec={}
    for r in rows: dec.setdefault(r['depth'],[]).append(r['decode'])
    print(tag, 'requests', len(rows), 'texts not in stock set', diff, 'stock variants', max(len(v) for v in ref.values()),
          'decode', {k: round(sum(v)/len(v),2) for k,v in dec.items()}, 'maxT', d['max_temp'], d['summary'] and {k: round(v['change_pct'],1) for k,v in d['summary'].items()})
PY
echo done >> $R/compare.txt
