#!/usr/bin/env bash
# P110: post-move smoke (the PC was moved 2026-10-11/13 to Carmel, Indiana; it slept, no reboot). Is the card the same?
# Same binary, launcher and request mix as P96 (bundle-20261010, main 262k test launcher, layer off), sweep 4k/32k/64k.
# Gate (declared here, before the run): kernel tests pass; decode within 3 % of P96 (51.5 / 51.3 / 34.4); 0 one-token;
# trace min free >= 60 MiB; max GPU temperature <= 80 C. Else stop and tell Cary (seating, cooling, PCIe link).
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p110; mkdir -p $R
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
BIN=$(cd "$(dirname "$(find release_1010/x -name llama-server.exe | head -1)")" && pwd -W); echo "BIN $BIN" > $R/bin.txt
for o in ADD RMS_NORM FLASH_ATTN_EXT; do
  echo "$o: $("$BIN/test-backend-ops.exe" -o $o -b CUDA0 < /dev/null 2>&1 | grep -E 'tests passed' | tr -d '\r')" >> $R/tests.txt
done
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
V="BONSAI_BIN=$BIN;BONSAI_LAYER=0"
( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free,temperature.gpu,clocks.gr,clocks.mem,power.draw,pcie.link.gen.current,pcie.link.width.current --format=csv,noheader,nounits)"; sleep 10; done ) > $R/trace.txt & MP=$!
bash run_arm.sh $R sweep "$V" "$L" "4000 32000 64000"
kill $MP
{ cat $R/bin.txt $R/tests.txt; f=$R/sweep.txt; echo "== sweep: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|did not" $f | sed -E 's/ttft +[0-9.]+s +//'
  awk -F', ' '{v=$1; sub(/^[0-9:]+ /,"",v); v+=0; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v; if ($2>t) t=$2; g[$6" x"$7]++} END{print "trace min free", m, "MiB; max temp", t, "C; samples", NR; for (k in g) print "pcie", k, g[k]}' $R/trace.txt
  echo "P96 reference: decode 51.5 / 51.3 / 34.4 at 4k / 32k / 64k"; } > $R/summary.txt
