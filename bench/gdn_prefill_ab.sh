#!/usr/bin/env bash
# Chunked gated-delta-net prefill (MMA kernel, port of ggml-org/llama.cpp#29353) vs the recurrent kernel, same engine
# (GGML_CUDA_GDN_MMA_DISABLE=1 = before). Product launcher (12 GB recipe, drafting on: K > 1 snapshots, so the MMA +
# recurrent split runs), layer off. Per arm: quick_tps at each of SPEED_DEPTHS (prefill and decode), code_needle (exact
# copies) and needle_depth (12 facts) at DEPTH.
#   bash bench/gdn_prefill_ab.sh <root with the engine>   -> receipts/gdn_prefill_ab.{log,jsonl}
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd -W)"; MODEL="$REPO\models\Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf"; ROOT="$(cygpath -w "${1:?root}")"
LOG=receipts/gdn_prefill_ab.log; OUT=receipts/gdn_prefill_ab.jsonl; DEPTH=${DEPTH:-32000}; SPEED_DEPTHS=${SPEED_DEPTHS:-4000 32000 128000}
say() { echo "$(date '+%H:%M') $*" | tee -a "$LOG"; }
rm -f logs/ramguard.stop
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ramguard.ps1 -Names llama-server -StopFile logs/ramguard.stop &
GUARD=$!
trap 'touch logs/ramguard.stop; wait $GUARD 2>/dev/null; powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1' EXIT
say "=== gdn prefill A/B: speed depths $SPEED_DEPTHS, quality depth $DEPTH, root $ROOT"
for A in "recurrent|GGML_CUDA_GDN_MMA_DISABLE=1" "mma|"; do
  NAME=${A%%|*}; ENVS=${A#*|}
  [[ " ${ARMS:-recurrent mma} " == *" $NAME "* ]] || continue
  powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1; sleep 4
  env BONSAI_MODEL="$MODEL" BONSAI_LAYER=0 $ENVS powershell -NoProfile -Command "Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$ROOT\start-server.ps1' -RedirectStandardOutput '$REPO\logs\gdnab_$NAME.launcher.log' -RedirectStandardError '$REPO\logs\gdnab_$NAME.server.log'"
  ok=0; for k in $(seq 1 90); do sleep 2; curl -s -m 2 http://127.0.0.1:8080/health | grep -q ok && { ok=1; break; }; done
  say "arm $NAME ($ENVS): health=$ok; $(grep '^kv' logs/gdnab_$NAME.launcher.log | cut -c1-90)"
  [ $ok = 1 ] || continue
  for D in $SPEED_DEPTHS; do
    PYTHONUTF8=1 python bench/quick_tps.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --depth $D 2>&1 | sed "s/^/$NAME /" | tee -a "$LOG"
  done
  PYTHONUTF8=1 python bench/code_needle.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --depth $DEPTH --n 10 --tag $NAME --out $OUT 2>&1 | tail -1 | tee -a "$LOG"
  PYTHONUTF8=1 python bench/needle_depth.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --depth $DEPTH --n 12 --tag $NAME --out $OUT 2>&1 | tail -1 | tee -a "$LOG"
done
say "=== done"
