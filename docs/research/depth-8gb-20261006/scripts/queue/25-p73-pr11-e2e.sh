#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p73; mkdir -p $R
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-0046\build.bat' > logs/build-0046.log 2>&1 || { echo "build failed" > $R/summary.txt; exit 1; }
rm -rf /c/bonsai/bonsai-ada-surgery/bin-0046 && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-0046/bin /c/bonsai/bonsai-ada-surgery/bin-0046
for f in /c/bonsai/bonsai-ada-surgery/bin-8gbfix/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-0046/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-0046/; done
L='C:/bonsai/bonsai-ada-surgery/start-server-pr11.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
for arm in "auto|" "off|;BONSAI_CKPT_EVERY=0"; do tag=${arm%%|*}; extra=${arm#*|}
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p73_$tag -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-0046;BONSAI_LAYER=0$extra" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  L2="$(cygpath "$(tr -d '\r' < logs/current.log)")"; cp "$L2" $R/$tag.launcher.log
  powershell -NoProfile -Command "(Get-CimInstance Win32_Process -Filter \"Name='llama-server.exe'\").CommandLine" > $R/$tag.cmdline.txt
  ( while true; do echo "$(date +%T) $(powershell -NoProfile -Command '[int]((Get-Process llama-server).WorkingSet64/1MB)')"; sleep 20; done ) > $R/$tag.ram.txt &
  SP=$!
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag $tag --out $R/ab.jsonl --depth 64000 > $R/$tag.txt 2>&1
  kill $SP 2>/dev/null
  grep -ciE "restored context checkpoint" "${L2%.out.log}.err.log" > $R/$tag.restores.txt
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json, collections
rows=[json.loads(l) for l in open('receipts/p73/ab.jsonl')]
by=collections.defaultdict(dict)
for r in rows: by[(r['kind'],r['item'])][r['tag']]=(r['sha'],r['wall'],r['n'])
same=sum(1 for v in by.values() if len(v)==2 and v['auto'][0]==v['off'][0])
print('items', len(by), 'same text', same, 'one-token', sum(1 for r in rows if r['n']<=1))
for t in ('auto','off'):
    w=[r['wall'] for r in rows if r['tag']==t][1:]
    print(t, 'wall after first: mean', round(sum(w)/len(w),1), 'min', min(w), 'max', max(w))
PY
