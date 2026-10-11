#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p80b; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-pmask;BONSAI_LAYER=0'
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
memarm tail1 "$V;BONSAI_SPEC_DEEP=1" "$L" "64000 200000"
memarm tail2 "$V;BONSAI_SPEC_DEEP=2;BONSAI_VRAM_MARGIN=375" "$L" "64000 200000"
{ for a in tail1 tail2; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|accept|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'; grep -hE "^kv     tiered" logs/*$a.out.log | tail -1; done; } > $R/summary.txt
