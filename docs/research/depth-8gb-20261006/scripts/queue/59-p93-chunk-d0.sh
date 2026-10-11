#!/usr/bin/env bash
# P93: does GGML_CUDA_FA_CHUNK=32768 change depth-0 texts (where no op should have > 32,768 KV cells)?
# Same launcher (PR #19 branch copy), same bin; off vs on, twice each; server log at verbosity 4 for the chunk line.
cd /c/bonsai/8gb; R=receipts/p93; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-chunktest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
logpath() { cat logs/current.log | tr -d '\r' | sed -e 's#\\#/#g' -e 's#^C:#/c#'; }
for arm in off on off2 on2; do
  C=0; case $arm in on|on2) C=32768 ;; esac
  V="BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-chunk;BONSAI_LAYER=0;GGML_CUDA_FA_CHUNK=$C;LLAMA_LOG_VERBOSITY=4"
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p93_$arm -Launcher "$L" -Vars "$V" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag ${arm}_d0 --out $R/ab.jsonl --depth 0 > $R/ab_$arm.txt 2>&1
  O="$(logpath)"; E="${O%out.log}err.log"
  grep -m3 -E "FA_CHUNK|chunks of" "$E" > $R/$arm.chunkline.txt 2>/dev/null
  grep -oE "n_kv[ =:]+[0-9]+|kv_size[ =:]+[0-9]+" "$E" | sort | uniq -c | sort -rn | head -5 > $R/$arm.nkv.txt 2>/dev/null
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json
rows = [json.loads(l) for l in open('receipts/p93/ab.jsonl')]
arms = {}
for r in rows:
    arms.setdefault(r['tag'], {})[(r['kind'], r['item'])] = r['sha']
base = arms.get('off_d0', {})
for tag, d in arms.items():
    diff = [k[1] + '/' + k[0] for k in d if base.get(k) != d[k]]
    print(f"{tag}: {len(d) - len(diff)}/{len(d)} same as off_d0; diff {diff}")
PY
for a in off on off2 on2; do echo "-- $a chunk line: $(cat $R/$a.chunkline.txt 2>/dev/null)"; done >> $R/summary.txt
