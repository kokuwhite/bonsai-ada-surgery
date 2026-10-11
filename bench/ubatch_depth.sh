#!/usr/bin/env bash
# Prefill micro-batch size at depth: each micro-batch reads the whole prefix K/V once per attention op (from VRAM and
# over PCIe for the host tail), so a larger ubatch reads it fewer times per prompt. Product launcher (12 GB recipe
# unless the card says otherwise), layer off, one server per arm, quick_tps at DEPTHS (cold prefill of the deep
# prompt, then the follow-up). RAM guard on.
#   bash bench/ubatch_depth.sh [root]   -> receipts/ubatch_depth.log   (UBS="512 1024 2048", DEPTHS="128000 192000")
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd -W)"; MODEL="$REPO\models\Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf"; ROOT="$(cygpath -w "${1:-.}")"
LOG=receipts/ubatch_depth.log; DEPTHS=${DEPTHS:-128000 192000}; UBS=${UBS:-512 1024 2048}
say() { echo "$(date '+%H:%M') $*" | tee -a "$LOG"; }
rm -f logs/ramguard.stop
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ramguard.ps1 -Names llama-server -StopFile logs/ramguard.stop &
GUARD=$!
trap 'touch logs/ramguard.stop; wait $GUARD 2>/dev/null; powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1' EXIT
say "=== ubatch at depth: ubs $UBS, depths $DEPTHS, root $ROOT"
for UB in $UBS; do
  powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1; sleep 4
  env BONSAI_MODEL="$MODEL" BONSAI_LAYER=0 BONSAI_UBATCH=$UB powershell -NoProfile -Command "Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$ROOT\start-server.ps1' -RedirectStandardOutput '$REPO\logs\ubdepth_$UB.launcher.log' -RedirectStandardError '$REPO\logs\ubdepth_$UB.server.log'"
  ok=0; for k in $(seq 1 120); do sleep 2; curl -s -m 2 http://127.0.0.1:8080/health | grep -q ok && { ok=1; break; }; done
  say "ub $UB: health=$ok; $(grep '^kv' logs/ubdepth_$UB.launcher.log | cut -c1-100)"
  [ $ok = 1 ] || { tail -5 logs/ubdepth_$UB.server.log | tee -a "$LOG"; continue; }
  for D in $DEPTHS; do
    PYTHONUTF8=1 python bench/quick_tps.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --depth $D 2>&1 | sed "s/^/ub$UB /" | tee -a "$LOG"
  done
done
say "=== done"
