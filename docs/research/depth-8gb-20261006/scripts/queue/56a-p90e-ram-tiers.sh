#!/usr/bin/env bash
# P90e (issue #16, PR #18 v3): RAM tiers. Arm t32: this 32 GB machine as is (tier 24-47 GB: cache 4096, 32 checkpoints).
# Arm b16: ballast to ~13.4 GB free commit + BONSAI_RAM_GB=16 (the budget branch, as P90d).
cd /c/bonsai/8gb; R=receipts/p90e; mkdir -p $R
KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
LL='C:/bonsai/bonsai-ada-surgery/start-server-ramtest.ps1'
V='BONSAI_BIN=C:/bonsai/8gb/release_vram/x/bin;BONSAI_LAYER=0;BONSAI_CTX=131072'
logpath() { cat logs/current.log | tr -d '\r' | sed -e 's#\\#/#g' -e 's#^C:#/c#'; }
freecommit() { powershell -NoProfile -Command "[int]((Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory/1024)" < /dev/null | tr -d '\r'; }
for arm in t32 b16; do
  VV="$V"; [ $arm = b16 ] && VV="$V;BONSAI_RAM_GB=16"
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1; sleep 5
  rm -f $R/ballast.pid
  if [ $arm = b16 ]; then
    F=$(freecommit); G=$(( (F - 13312) / 1024 )); [ $G -lt 0 ] && G=0
    python ballast.py $G $R/ballast.pid > $R/$arm.ballast.txt 2>&1 &
    for i in $(seq 1 60); do [ -f $R/ballast.pid ] && break; sleep 2; done
    echo "free commit before ballast $F MiB, ballast $G GiB, after $(freecommit) MiB" >> $R/$arm.ballast.txt
  fi
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p90e_$arm -Launcher "$LL" -Vars "$VV" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  O="$(logpath)"; E="${O%out.log}err.log"
  grep -hE '^(ram|kv|window) ' "$O" > $R/$arm.launcher_lines.txt 2>/dev/null
  grep -oE -- "--cache-ram [0-9]+|--ctx-checkpoints [0-9]+" "$O" "$E" 2>/dev/null | sort -u > $R/$arm.args.txt
  python ram_probe.py --key-file $KEY --out $R/$arm.jsonl --n 7 --prefix-words 6000 > $R/$arm.out.txt 2>&1
  grep -E "cache size limit|removing oldest|bad alloc|exceeds cache size" "$E" | tail -20 > $R/$arm.cache_lines.txt 2>/dev/null
  curl -s -m 5 localhost:8080/health > $R/$arm.health_after.txt 2>&1 || echo "server gone" > $R/$arm.health_after.txt
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  [ -f $R/ballast.pid ] && taskkill //F //PID $(cat $R/ballast.pid) > /dev/null 2>&1
done
python - > $R/summary.txt <<'PY'
import json
for arm in ('t32', 'b16'):
    try:
        rows = [json.loads(l) for l in open(f'receipts/p90e/{arm}.jsonl')]
    except FileNotFoundError:
        print(f"== {arm}: no data"); continue
    mem = [r for r in rows if r['kind'] == 'mem' and 'private_mib' in r]
    req = [r for r in rows if r['kind'] == 'req']
    print(f"== {arm}: requests ok {sum(r['ok'] for r in req)}/{len(req)}; errors {[r.get('error', '')[:60] for r in req if not r['ok']]}")
    if mem:
        print(f"   private MiB: start {mem[0]['private_mib']} peak {max(m['private_mib'] for m in mem)}; min free commit {min(m['free_commit_mib'] for m in mem)} MiB")
PY
for arm in t32 b16; do echo "-- $arm"; cat $R/$arm.ballast.txt $R/$arm.launcher_lines.txt $R/$arm.args.txt $R/$arm.health_after.txt 2>/dev/null; echo; tail -3 $R/$arm.cache_lines.txt 2>/dev/null; done >> $R/summary.txt
