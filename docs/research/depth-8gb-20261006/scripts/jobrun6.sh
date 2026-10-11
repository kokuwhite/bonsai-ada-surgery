#!/usr/bin/env bash
# BonsaiJob6: build the lookup engine, then P49. Waits for jobrun4 (P47). Do not edit while running.
cd /c/bonsai/8gb
mkdir receipts/jobrun6.lock 2>/dev/null || exit 1
trap 'rmdir receipts/jobrun6.lock' EXIT
log() { echo "$(date +%T) $*" >> receipts/jobrun6.log; }
log start
until grep -q " end" receipts/jobrun4.log 2>/dev/null && [ ! -d receipts/jobrun4.lock ]; do sleep 60; done
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-lookup\build.bat' > logs/build-lookup.log 2>&1 || { log build failed; exit 1; }
rm -rf /c/bonsai/bonsai-ada-surgery/bin-lookup && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-lookup/bin /c/bonsai/bonsai-ada-surgery/bin-lookup
for f in /c/bonsai/bonsai-ada-surgery/bin-rc3/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-lookup/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-lookup/; done
/c/bonsai/bonsai-ada-surgery/bin-lookup/llama-server.exe --help 2>&1 | grep -q "spec-lookup-n-max" && log "build ok (lookup flag present)" || { log "build has no lookup flag"; exit 1; }
R=receipts/p49; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'
KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
arm() { # tag lookup depth
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p49_$1 -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-lookup;BONSAI_LAYER=0;BONSAI_LOOKUP=$2" > $R/$1.serve.txt 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  O="$(cygpath "$(tr -d '\r' < logs/current.log)")"; cp "$O" $R/$1.launcher.txt
  ( while true; do nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits; sleep 2; done ) > $R/$1.free.txt &
  SP=$!
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag $1 --out $R/ab.jsonl --depth $3 > $R/$1.out.txt 2>&1
  kill $SP 2>/dev/null
  echo "$1 min free $(sort -n $R/$1.free.txt | head -1) MiB, server alive $(curl -s localhost:8080/health | grep -c ok)" >> $R/summary.txt
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
}
arm mtp_d0 0 0
arm look_d0 1 0
arm mtp_d64k 0 64000
arm look_d64k 1 64000
arm look_d0b 1 0
log end
