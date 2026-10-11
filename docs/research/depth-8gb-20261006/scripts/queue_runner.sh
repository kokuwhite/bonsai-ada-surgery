#!/usr/bin/env bash
# GPU queue runner (BonsaiQueue task, every 10 min, one instance). Never leaves the GPU idle:
# 1) waits while another job holds a lock (receipts/jobrun*.lock with a live process),
# 2) runs queue/pending/*.sh in name order (moved to running/, then done/ or failed/),
# 3) when the queue is empty, runs the next default sweep (filler_*.sh, rotating).
cd /c/bonsai/8gb
LOG=receipts/queue.log
log() { echo "$(date '+%m-%d %T') $*" >> $LOG; }
if ! mkdir receipts/queue.lock 2>/dev/null; then
  old=$(cat receipts/queue.lock/pid 2>/dev/null)
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then exit 0; fi   # a live runner has it
  log "stale queue lock (pid $old) - taking over"
fi
echo $$ > receipts/queue.lock/pid
trap 'rm -rf receipts/queue.lock' EXIT
live_job() { # any jobrun lock whose script still runs
  for l in receipts/jobrun*.lock; do [ -d "$l" ] || continue
    n=$(basename $l .lock)
    if powershell -NoProfile -Command "@(Get-CimInstance Win32_Process | Where-Object { \$_.Name -eq 'bash.exe' -and \$_.CommandLine -match '$n\.sh' }).Count" | grep -qv '^0$'; then return 0; fi
    log "stale lock $l removed"; rmdir "$l"
  done; return 1; }
log "runner start"
while true; do
  if [ -f queue/PAUSE ]; then sleep 60; continue; fi   # serving: pause.ps1 makes it, resume.ps1 removes it
  if live_job; then sleep 60; continue; fi
  next=$(ls queue/pending/*.sh 2>/dev/null | sort | head -1)
  if [ -n "$next" ]; then
    b=$(basename $next); mv "$next" queue/running/; log "run $b"
    if bash queue/running/$b > receipts/queue-$b.out 2>&1; then mv queue/running/$b queue/done/; log "done $b"
    else mv queue/running/$b queue/failed/; log "FAILED $b (see receipts/queue-$b.out)"; fi
    continue
  fi
  # empty queue: rotate the default sweeps
  n=$(cat receipts/filler.next 2>/dev/null || echo 0)
  fillers=($(ls filler_*.sh | sort)); f=${fillers[$((n % ${#fillers[@]}))]}
  echo $((n + 1)) > receipts/filler.next
  log "queue empty - filler $f"
  [ -f queue/PAUSE ] && continue
  bash $f > receipts/queue-$f.out 2>&1; log "filler $f exit $?"
done
