#!/usr/bin/env bash
# P90 (issue #16): system-RAM use of the 8 GB preset at 131k during sequential long-thinking requests.
cd /c/bonsai/8gb; R=receipts/p90b; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-vramtest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/8gb/release_vram/x/bin;BONSAI_LAYER=0;BONSAI_CTX=131072'
logpath() { cat logs/current.log | tr -d '\r' | sed -e 's#\\#/#g' -e 's#^C:#/c#'; }
for arm in default capped budget; do
  VV="$V"; [ $arm = capped ] && VV="$V;LLAMA_ARG_CTX_CHECKPOINTS=8;LLAMA_ARG_CACHE_RAM=1024"
  LL="$L"; [ $arm = budget ] && LL='C:/bonsai/bonsai-ada-surgery/start-server-ramtest.ps1'
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p90_$arm -Launcher "$LL" -Vars "$VV" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  O="$(logpath)"; E="${O%out.log}err.log"
  grep -hE '^(ram|kv|window) ' "$O" > $R/$arm.launcher_lines.txt 2>/dev/null
  python ram_probe.py --key-file $KEY --out $R/$arm.jsonl --n 7 --prefix-words 6000 > $R/$arm.out.txt 2>&1
  grep -E "cache size limit|removing oldest|bad alloc|created context checkpoint|cache state" "$E" | tail -20 > $R/$arm.cache_lines.txt 2>/dev/null
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
python - > $R/summary.txt <<'PY'
import json
for arm in ('default', 'capped', 'budget'):
    try:
        rows = [json.loads(l) for l in open(f'receipts/p90b/{arm}.jsonl')]
    except FileNotFoundError:
        print(f"== {arm}: no data"); continue
    mem = [r for r in rows if r['kind'] == 'mem' and 'private_mib' in r]
    req = [r for r in rows if r['kind'] == 'req']
    print(f"== {arm}: requests ok {sum(r['ok'] for r in req)}/{len(req)}; completion tokens {[r.get('completion_tokens') for r in req]}")
    if mem:
        print(f"   private (commit) MiB: start {mem[0]['private_mib']} peak {max(m['private_mib'] for m in mem)} end {mem[-1]['private_mib']}; "
              f"working set peak {max(m['ws_mib'] for m in mem)}; min free commit {min(m['free_commit_mib'] for m in mem)} MiB")
PY
for arm in default capped budget; do echo "-- $arm launcher"; cat $R/$arm.launcher_lines.txt 2>/dev/null; echo "-- $arm cache lines"; tail -6 $R/$arm.cache_lines.txt 2>/dev/null; done >> $R/summary.txt
