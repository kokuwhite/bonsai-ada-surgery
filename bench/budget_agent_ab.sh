#!/usr/bin/env bash
# Thinking budget on agent work: the server default (BONSAI_THINK_BUDGET unset = 20480) vs smaller budgets, product
# template and rules unchanged. Raw server (layer off), product launcher otherwise. Per arm: the suite's workspace
# tasks (bench/plans/tools_workspace.json, 5 tasks x 3 seeds), then the tool-call syntax stress test. HumanEval with
# the same budgets: 2048 -> 160/164 at 913 mean tokens, 4096 -> 160/164 at 1178 (default 160/164 at 2312).
#   bash bench/budget_agent_ab.sh   -> receipts/budget_agent_ab.log, artifacts/eval/budget_<arm>/   (BUDGETS="default 4096 2048")
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd -W)"; LOG=receipts/budget_agent_ab.log; PLAN=${PLAN:-bench/plans/tools_workspace.json}
say() { echo "$(date '+%H:%M') $*" | tee -a "$LOG"; }
rm -f logs/ramguard.stop
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ramguard.ps1 -Names llama-server -StopFile logs/ramguard.stop &
GUARD=$!
trap 'touch logs/ramguard.stop; wait $GUARD 2>/dev/null; powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1' EXIT
say "=== thinking budget on agent work: budgets ${BUDGETS:-default 4096 2048}, plan $PLAN"
for B in ${BUDGETS:-default 4096 2048}; do
  NAME=b$B; ENVS=""; [ "$B" != default ] && ENVS="BONSAI_THINK_BUDGET=$B"
  powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1; sleep 4
  env BONSAI_LAYER=0 $ENVS powershell -NoProfile -Command "Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$REPO\\start-server.ps1' -RedirectStandardOutput '$REPO\\logs\\budget_$NAME.launcher.log' -RedirectStandardError '$REPO\\logs\\budget_$NAME.server.log'"
  ok=0; for k in $(seq 1 90); do sleep 2; curl -s -m 2 http://127.0.0.1:8080/health | grep -q ok && { ok=1; break; }; done
  say "arm $NAME: health=$ok; $(grep -h '^listen' logs/budget_$NAME.launcher.log | cut -c1-110)"
  [ $ok = 1 ] || continue
  PYTHONUTF8=1 python suite/run_suite.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --plan "$PLAN" \
      --out artifacts/eval/budget_$NAME --label-a $NAME 2>&1 | tail -12 | tee -a "$LOG"
  PYTHONUTF8=1 python bench/toolcall_stress.py --base http://127.0.0.1:8080 --key "$(cat artifacts/api_key.txt)" --n 6 \
      --out artifacts/eval/budget_${NAME}_stress.json 2>&1 | tail -4 | tee -a "$LOG"
done
say "=== done"
