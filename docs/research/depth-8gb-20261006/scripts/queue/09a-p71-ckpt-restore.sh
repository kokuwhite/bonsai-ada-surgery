#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p71; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
B='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-ckpt;BONSAI_LAYER=0;LLAMA_ARG_CHECKPOINT_EVERY_NT=8192'
arms=("ctrl|$B;LLAMA_ARG_LOG_VERBOSITY=4" "nospec|$B;BONSAI_SPEC=0" "gather|$B;GGML_GDN_STATE_GATHER=1" "notier|$B;GGML_CUDA_KV_TIER_REDIRECT=0;GGML_CUDA_KV_TIER_PREFETCH=0")
for a in "${arms[@]}"; do tag=${a%%|*}; v=${a#*|}
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p71_$tag -Launcher "$L" -Vars "$v" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag $tag --out $R/ab.jsonl --depth 64000 > $R/$tag.txt 2>&1
  L2="$(cygpath "$(tr -d '\r' < logs/current.log)")"; grep -iE "checkpoint" "${L2%.out.log}.err.log" | tail -n 60 > $R/$tag.ckpt.log
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json, collections
rows=[json.loads(l) for l in open('receipts/p71/ab.jsonl')]
g=collections.defaultdict(lambda: collections.defaultdict(list))
for r in rows: g[r['tag']][r['kind']].append(r['sha'])
for t,k in g.items():
    print(t, {kind: f"{len(set(v))} distinct of {len(v)}" for kind,v in k.items()})
PY
