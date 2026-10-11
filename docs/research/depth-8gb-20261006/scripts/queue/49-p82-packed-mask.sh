#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p82; mkdir -p $R
rm -rf /c/bonsai/bonsai-ada-surgery/bin-pmask && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-pmask/bin /c/bonsai/bonsai-ada-surgery/bin-pmask
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-pmask/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-pmask/; done
/c/bonsai/bonsai-ada-surgery/bin-pmask/test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 2>&1 | grep -E "tests passed|FAIL" | tail -3 > $R/tests.txt
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
for P in 0 1; do
  V="BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-pmask;BONSAI_LAYER=0;BONSAI_KV_VRAM_CELLS=50176;LLAMA_ARG_KQ_MASK_PACKED=$P"
  [ $P = 0 ] && V="BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-pmask;BONSAI_LAYER=0;BONSAI_KV_VRAM_CELLS=50176"
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p82_packed$P -Launcher "$L" -Vars "$V" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  echo "packed=$P loaded free $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits) MiB" >> $R/mem.txt
  ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/packed$P.mem.txt & MP=$!
  for d in 32000 64000; do python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag packed${P}_d$d --out $R/ab.jsonl --depth $d > $R/ab_p${P}_d$d.txt 2>&1; done
  kill $MP
  awk -v p=$P '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "packed=" p " trace min free", m}' $R/packed$P.mem.txt >> $R/mem.txt
  grep -c "KQ mask\|packed" "$(cat logs/current.log | tr -d '\r' | sed 's#\#/#g; s#^C:#/c#; s#out.log$#err.log#')" >> $R/mem.txt
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json
rows=[json.loads(l) for l in open('receipts/p82/ab.jsonl')]
for d in (32000,64000):
    a={(r['kind'],r['item']):r for r in rows if r['tag']==f'packed0_d{d}'}
    b={(r['kind'],r['item']):r for r in rows if r['tag']==f'packed1_d{d}'}
    same=[k for k in a if k in b and a[k]['sha']==b[k]['sha']]
    diff=[f"{k[1]}/{k[0]}" for k in a if k in b and a[k]['sha']!=b[k]['sha']]
    one=sum(1 for r in list(a.values())+list(b.values()) if r['n']==1)
    ta=sum(r['tps'] for r in a.values())/max(1,len(a)); tb=sum(r['tps'] for r in b.values())/max(1,len(b))
    print(f"d{d}: same text {len(same)}/{len(a)} diff {diff} one-token {one} mean tps f16 {ta:.1f} packed {tb:.1f}")
PY
cat $R/tests.txt $R/mem.txt >> $R/summary.txt
