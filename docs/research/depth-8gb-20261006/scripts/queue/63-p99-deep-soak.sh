#!/usr/bin/env bash
# P99: deep agent-style soak on the shipped 8 GB config (bundle-20261010 zip, main launcher): ~150k-token start, 25 turns
# of ~2.5k new tokens each (toward ~215k+), VRAM trace every 10 s.
cd /c/bonsai/8gb; R=receipts/p99; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/8gb/release_1010/x/bin;BONSAI_LAYER=0'
logpath() { cat logs/current.log | tr -d '\r' | sed -e 's#\\#/#g' -e 's#^C:#/c#'; }
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p99 -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
O="$(logpath)"; grep -hE '^(window|kv|ram|8gb) ' "$O" > $R/launcher_lines.txt
( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/vram.txt & MP=$!
python deep_soak.py --key-file $KEY --start-tokens 150000 --turns 25 --turn-tokens 2500 --out $R/turns.jsonl > $R/run.txt 2>&1
kill $MP
curl -s -m 5 localhost:8080/health > $R/health_after.txt 2>&1 || echo "server gone" > $R/health_after.txt
E="${O%out.log}err.log"; grep -cE "cache size limit|bad alloc|CUDA error" "$E" > $R/errors.txt 2>/dev/null
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json
rows = [json.loads(l) for l in open('receipts/p99/turns.jsonl')]
for r in rows:
    if r.get('ok'):
        print(f"turn {r['turn']:2d}: prompt {r['prompt_tokens']:6d} new {r['new_tokens']} wall {r['wall']:7.1f}s pp {r['pp']:6.1f} tg {r['tg']:5.1f} out {r['completion_tokens']:3d} one_token {r['one_token']} priv {r['server_private_mib']} vram_free {r['vram_free_mib']}")
    else:
        print(f"turn {r['turn']}: FAILED {r.get('error')}")
print('one-token answers:', sum(1 for r in rows if r.get('one_token')), 'of', sum(1 for r in rows if r.get('ok')))
PY
awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free VRAM", m, "MiB over", NR, "samples"}' $R/vram.txt >> $R/summary.txt
{ cat $R/launcher_lines.txt; echo "health after: $(cat $R/health_after.txt)"; echo "error lines: $(cat $R/errors.txt)"; } >> $R/summary.txt
