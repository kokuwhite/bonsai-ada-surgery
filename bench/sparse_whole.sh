#!/usr/bin/env bash
# Whole-context page selection (GGML_CUDA_FA_SPARSE_SINKS: the VRAM part is selected too, so attention work per step
# follows the budget): dense vs sparse with sinks, decode and draft verify (fast path), tile skip on. 12 GB recipe with
# its normal VRAM line, layer off, f16 mask, graphs off. Per arm: quick_tps at SPEED_DEPTH, code_needle (exact copies)
# and needle_depth (12 facts) at DEPTH.
#   bash bench/sparse_whole.sh <root with the engine>   -> receipts/sparse_whole.{log,jsonl}
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd -W)"; MODEL="$REPO\models\Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf"; ROOT="$(cygpath -w "${1:?root}")"
LOG=receipts/sparse_whole.log; OUT=receipts/sparse_whole.jsonl; DEPTH=${DEPTH:-160000}; SPEED_DEPTH=${SPEED_DEPTH:-192000}; SP=${SPARSE:-8192,256,1024}; SINKS=${SINKS:-1024}
say() { echo "$(date '+%H:%M') $*" | tee -a "$LOG"; }
rm -f logs/ramguard.stop
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ramguard.ps1 -Names llama-server -StopFile logs/ramguard.stop &
GUARD=$!
trap 'touch logs/ramguard.stop; wait $GUARD 2>/dev/null; powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1' EXIT
BASE="LLAMA_ARG_KQ_MASK_PACKED=0 GGML_CUDA_DISABLE_GRAPHS=1"
SPARSE_ENV="GGML_CUDA_FA_SPARSE=$SP GGML_CUDA_FA_SPARSE_FAST=1 GGML_CUDA_KV_TIER_STAGE_MIN_Q=9"
say "=== sparse whole: quality depth $DEPTH, speed depth $SPEED_DEPTH, sparse $SP, sinks $SINKS, root $ROOT"
for A in "dense|" "sparse-tail|$SPARSE_ENV GGML_CUDA_FA_TILE_SKIP=1" "sparse-whole|$SPARSE_ENV GGML_CUDA_FA_TILE_SKIP=1 GGML_CUDA_FA_SPARSE_SINKS=$SINKS"; do
  NAME=${A%%|*}; ENVS=${A#*|}
  [[ " ${ARMS:-dense sparse-tail sparse-whole} " == *" $NAME "* ]] || continue
  powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1; sleep 4
  env BONSAI_MODEL="$MODEL" BONSAI_LAYER=0 $BASE $ENVS powershell -NoProfile -Command "Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$ROOT\start-server.ps1' -RedirectStandardOutput '$REPO\logs\spwhole_$NAME.launcher.log' -RedirectStandardError '$REPO\logs\spwhole_$NAME.server.log'"
  ok=0; for k in $(seq 1 90); do sleep 2; curl -s -m 2 http://127.0.0.1:8080/health | grep -q ok && { ok=1; break; }; done
  say "arm $NAME ($ENVS): health=$ok; $(grep '^kv' logs/spwhole_$NAME.launcher.log | cut -c1-90)"
  [ $ok = 1 ] || continue
  PYTHONUTF8=1 python bench/quick_tps.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --depth $SPEED_DEPTH 2>&1 | sed "s/^/$NAME /" | tee -a "$LOG"
  PYTHONUTF8=1 python bench/code_needle.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --depth $DEPTH --n 10 --tag $NAME --out $OUT 2>&1 | tail -1 | tee -a "$LOG"
  PYTHONUTF8=1 python bench/needle_depth.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --depth $DEPTH --n 12 --tag $NAME --out $OUT 2>&1 | tail -1 | tee -a "$LOG"
  say "$NAME: $(grep -c 'GGML_CUDA_FA_SPARSE B=' logs/spwhole_$NAME.server.log) engaged lines; last: $(grep 'GGML_CUDA_FA_SPARSE B=' logs/spwhole_$NAME.server.log | tail -1 | cut -c1-160)"
done
say "=== done"
