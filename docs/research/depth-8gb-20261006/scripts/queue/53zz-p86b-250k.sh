#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p86b; mkdir -p $R
export QTPS_TIMEOUT=7200
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-pmask;BONSAI_LAYER=0'
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
memarm end262 "$V" "$L" "128000 192000 250000"
{ echo "== end262: $(grep -c '(1 tok)' $R/end262.txt) one-token"; grep -E "loaded|depth|mean decode|accept|did not|trace min|rror" $R/end262.txt | sed -E 's/ttft +[0-9.]+s +//'; } > $R/summary.txt
