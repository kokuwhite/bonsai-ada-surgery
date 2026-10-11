#!/usr/bin/env bash
# P92: does bin-chunk with the chunk path OFF give the release text? bin-pmask (d90e35528) vs bin-chunk (+0051/0052),
# same launcher (262k test launcher, does not set GGML_CUDA_FA_CHUNK), lookup_ab at depth 0 (all in VRAM, < 32k).
cd /c/bonsai/8gb; R=receipts/p92; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
for arm in pmask chunkoff pmask2; do
  B=bin-pmask; [ $arm = chunkoff ] && B=bin-chunk
  V="BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/$B;BONSAI_LAYER=0;GGML_CUDA_FA_CHUNK=0"
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p92_$arm -Launcher "$L" -Vars "$V" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag ${arm}_d0 --out $R/ab.jsonl --depth 0 > $R/ab_$arm.txt 2>&1
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json
rows = [json.loads(l) for l in open('receipts/p92/ab.jsonl')]
arms = {}
for r in rows:
    arms.setdefault(r['tag'], {})[(r['kind'], r['item'])] = r['sha']
base = arms.get('pmask_d0', {})
for tag, d in arms.items():
    same = sum(1 for k in d if base.get(k) == d[k])
    diff = [k[1] + '/' + k[0] for k in d if base.get(k) != d[k]]
    print(f"{tag}: {same}/{len(d)} same as pmask_d0; diff {diff}")
PY
