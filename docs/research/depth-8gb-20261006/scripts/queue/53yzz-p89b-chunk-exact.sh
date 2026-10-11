#!/usr/bin/env bash
# P89b: is the chunk merge exact? Chunked f16 (C=32768) vs whole-cache f16 (FA_PREFILL_F16=65536), same bin, same N.
cd /c/bonsai/8gb; R=receipts/p89b; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-chunk;BONSAI_LAYER=0;BONSAI_KV_VRAM_CELLS=45056'
for arm in whole chunk; do
  VV="$V;GGML_CUDA_FA_PREFILL_F16=65536"; [ $arm = chunk ] && VV="$V;GGML_CUDA_FA_PREFILL_F16=32768;GGML_CUDA_FA_CHUNK=32768"
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p89b_$arm -Launcher "$L" -Vars "$VV" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$arm.mem.txt & MP=$!
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag ${arm}_d64000 --out $R/ab.jsonl --depth 64000 > $R/ab_$arm.txt 2>&1
  kill $MP
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json
rows = [json.loads(l) for l in open('receipts/p89b/ab.jsonl')]
a = {(r['kind'], r['item']): r for r in rows if r['tag'] == 'whole_d64000'}
b = {(r['kind'], r['item']): r for r in rows if r['tag'] == 'chunk_d64000'}
same = [k for k in a if k in b and a[k]['sha'] == b[k]['sha']]
diff = [k[1] + '/' + k[0] for k in a if k in b and a[k]['sha'] != b[k]['sha']]
print(f"64k texts, whole-cache f16 vs chunked f16: {len(same)}/{len(a)} same; diff {diff}; one-token {sum(r['n'] == 1 for r in rows)}")
for arm, d in (('whole', a), ('chunk', b)):
    w = [r['wall'] for r in d.values()]
    print(f"{arm}: first request {w[0] if w else '-'} s, mean after first {sum(w[1:]) / max(1, len(w) - 1):.1f} s")
PY
for arm in whole chunk; do awk -v a=$arm '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print a, "trace min free", m}' $R/$arm.mem.txt >> $R/summary.txt; done
