#!/usr/bin/env bash
# P104: streaming vs retrieval head calibration at depth (research item 3) + the q3_0 build in the background.
# Probe kfirst-probe 0e0dc757a: per (layer, KV head) union fraction of host cells needed for dropped mass <= eps.
# Real text (Python stdlib source) ~230k tokens, 3 questions. Stats run: CPU load does not matter, so the q3_0 build
# (kv-q3-0 6a4851286, WIP) runs at the same time.
cd /c/bonsai/8gb; R=receipts/p104; mkdir -p $R
# 1. probe rebuild (incremental, a few minutes)
for i in 1 2 3; do cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-kfirst\build.bat' > logs/build-kfirst2.log 2>&1
  [ -f /c/bonsai/bonsai-ada-surgery/tooling/build-kfirst/bin/llama-server.exe ] && ! grep -q "build stopped" logs/build-kfirst2.log && break; done
grep -q "build stopped" logs/build-kfirst2.log && { echo "probe build failed" > $R/summary.txt; exit 1; }
rm -rf /c/bonsai/bonsai-ada-surgery/bin-kfirst2 && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-kfirst/bin /c/bonsai/bonsai-ada-surgery/bin-kfirst2
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-kfirst2/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-kfirst2/; done
# 2. q3_0 build in the background (one ninja at a time: the probe build is done)
( for i in 1 2 3; do cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-q3kv\build.bat' > logs/build-q3kv.log 2>&1
    [ -f /c/bonsai/bonsai-ada-surgery/tooling/build-q3kv/bin/llama-server.exe ] && ! grep -q "build stopped" logs/build-q3kv.log && { echo "q3 build ok (try $i)" > $R/q3build.txt; exit 0; }
    grep -qE "error C|error:|error LNK" logs/build-q3kv.log && { echo "q3 build: compile errors" > $R/q3build.txt; grep -E "error C|error:|error LNK" logs/build-q3kv.log | head -20 >> $R/q3build.txt; exit 1; }
  done; echo "q3 build failed 3x" > $R/q3build.txt ) &
# 3. calibration run
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-kfirst2;BONSAI_LAYER=0;GGML_CUDA_FA_CHUNK=32768;GGML_CUDA_KV_TIER_KFIRST_STATS=1;GGML_CUDA_KV_TIER_KFIRST_EVERY=16'
logpath() { cat logs/current.log | tr -d '\r' | sed -e 's#\\#/#g' -e 's#^C:#/c#'; }
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p104 -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
python realtext_probe.py --key-file $KEY --tokens 230000 --out $R/run.jsonl > $R/run.txt 2>&1
O="$(logpath)"; E="${O%out.log}err.log"
grep -E "kfirst-heads|kfirst-sum" "$E" > $R/heads_lines.txt
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
wait
python - > $R/summary.txt <<'PY'
import re, collections
acc = collections.defaultdict(lambda: collections.defaultdict(list))
for l in open('receipts/p104/heads_lines.txt'):
    m = re.search(r'kfirst-heads cache_k_l(\d+) \| 1e-2 ([0-9. ]+) \| 1e-3 ([0-9. ]+) \| 1e-4', l)
    if not m: continue
    L = int(m.group(1))
    for g, v in enumerate(m.group(2).split()): acc[(L, g)]['e2'].append(float(v))
    for g, v in enumerate(m.group(3).split()): acc[(L, g)]['e3'].append(float(v))
rows = sorted(((sum(d['e3'])/len(d['e3']), sum(d['e2'])/len(d['e2']), k) for k, d in acc.items()))
print('KV heads ranked by host fraction needed for dropped mass <= 1e-3 (and 1e-2), mean over summary windows:')
for f3, f2, (L, g) in rows:
    print(f"  layer {L:2d} head {g}: 1e-3 {f3:.3f}  1e-2 {f2:.3f}")
PY
cat $R/q3build.txt >> $R/summary.txt 2>/dev/null
