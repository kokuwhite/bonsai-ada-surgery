#!/usr/bin/env bash
# P80c: tail draft 2 vs 1 at 200k on the 262k 8 GB launcher; chunked prefill (bin-chunk, C=32768) so the 200k step
# fits in time; same engine in both arms. QTPS_TIMEOUT for the long steps (P80b timed out at 200k).
cd /c/bonsai/8gb; R=receipts/p80c; mkdir -p $R
export QTPS_TIMEOUT=7200
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-chunk;BONSAI_LAYER=0;GGML_CUDA_FA_CHUNK=32768'
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
memarm tail1 "$V;BONSAI_SPEC_DEEP=1" "$L" "64000 200000"
memarm tail2 "$V;BONSAI_SPEC_DEEP=2;BONSAI_VRAM_MARGIN=375" "$L" "64000 200000"
{ for a in tail1 tail2; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|depth|mean decode|accept|did not|trace min|rror" $f | sed -E 's/ttft +[0-9.]+s +//'; grep -hE "^kv     tiered" logs/*$a.out.log | tail -1; done; } > $R/summary.txt
