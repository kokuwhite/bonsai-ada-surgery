#!/usr/bin/env bash
# BonsaiJob8: P49b, P50, P53. Do not edit while running.
cd /c/bonsai/8gb
mkdir receipts/jobrun8.lock 2>/dev/null || exit 1
trap 'rmdir receipts/jobrun8.lock' EXIT
log() { echo "$(date +%T) $*" >> receipts/jobrun8.log; }
log start
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
up() { # tag lookup
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag $1 -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-lookup;BONSAI_LAYER=0;BONSAI_LOOKUP=$2" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && return 0; sleep 5; done; return 1; }
ab() { # dir tag lookup depth
  mkdir -p $1; up $2 $3 || { log "$2 serve failed"; return; }
  ( while true; do nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits; sleep 2; done ) > $1/$2.free.txt &
  SP=$!
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag $2 --out $1/ab.jsonl --depth $4 > $1/$2.out.txt 2>&1
  kill $SP 2>/dev/null
  echo "$2 min free $(sort -n $1/$2.free.txt | head -1) MiB, alive $(curl -s localhost:8080/health | grep -c ok)" >> $1/summary.txt
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
}
ab receipts/p49b mtp_d0 0 0
ab receipts/p49b look_d0 1 0
ab receipts/p49b mtp_d64k 0 64000
ab receipts/p49b look_d64k 1 64000
log p49b done
ab receipts/p50 mtp_d120k 0 120000
ab receipts/p50 look_d120k 1 120000
log p50 done
mkdir -p receipts/p53; up p53_humaneval 1 || { log "p53 serve failed"; exit 1; }
cd /c/bonsai/bonsai-ada-surgery && python bench/humaneval_run.py --base http://127.0.0.1:8080 --key-file artifacts/api_key.txt --arm medium --temp 0 --max-tokens 20480 > /c/bonsai/8gb/receipts/p53/humaneval_lookup.txt 2>&1
cd /c/bonsai/8gb; powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
log p53 done
log end
