#!/usr/bin/env bash
# P94: does prompt-cache state change greedy texts? One server per arm, lookup_ab depth 0 twice in the same server
# (pass 2 meets a warm prompt cache). Arms: prompt cache on (default) / off (LLAMA_ARG_CACHE_RAM=0).
cd /c/bonsai/8gb; R=receipts/p94; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
for arm in cacheon cacheoff; do
  V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-pmask;BONSAI_LAYER=0'; [ $arm = cacheoff ] && V="$V;LLAMA_ARG_CACHE_RAM=0"
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p94_$arm -Launcher "$L" -Vars "$V" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  for pass in 1 2; do
    python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag ${arm}_p$pass --out $R/ab.jsonl --depth 0 > $R/ab_${arm}_$pass.txt 2>&1
  done
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json
rows = [json.loads(l) for l in open('receipts/p94/ab.jsonl')]
arms = {}
for r in rows:
    arms.setdefault(r['tag'], {})[(r['kind'], r['item'])] = r['sha']
ref = {}
for l in open('receipts/p85/ab.jsonl'):
    r = json.loads(l)
    if r['depth'] == 0: ref[(r['kind'], r['item'])] = r['sha']
today = {}
for l in open('receipts/p92/ab.jsonl'):
    r = json.loads(l)
    if r['tag'] == 'pmask_d0': today[(r['kind'], r['item'])] = r['sha']
for tag, d in arms.items():
    print(f"{tag}: vs P85 (Oct 9) {sum(d[k] == ref.get(k) for k in d)}/{len(d)}, vs P92 (Oct 10) {sum(d[k] == today.get(k) for k in d)}/{len(d)}")
PY
