#!/usr/bin/env bash
# P103 (issue #22): tier-graphs on 8 GB. Fork tier-graphs 4715804d6 (= release 2cadbfb64 + CUDA graphs off for graphs
# whose attention reads the host tail, so the tier prefetch pipeline runs). Main 262k launcher, layer off, launcher
# defaults (lookup on, packed mask, chunk on). Arms: new (default) vs old (GGML_CUDA_KV_TIER_GRAPHS=1), sweep
# 4k/32k/128k/192k/245k; then 192k with BONSAI_LOOKUP=0 for both. Per arm: decode, prefill, line, switch-line count,
# server private bytes peak (sampled every 10 s), VRAM trace.
cd /c/bonsai/8gb; R=receipts/p103; mkdir -p $R
export QTPS_TIMEOUT=7200
rm -rf /c/bonsai/bonsai-ada-surgery/bin-tiergraphs && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-tiergraphs/bin /c/bonsai/bonsai-ada-surgery/bin-tiergraphs
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-tiergraphs/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-tiergraphs/; done
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tiergraphs;BONSAI_LAYER=0'
arm() {   # arm <tag> <vars> <depths>
  ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits) $(powershell -NoProfile -Command "\$p=Get-Process llama-server -ErrorAction SilentlyContinue|Select-Object -First 1; if(\$p){[int](\$p.PrivateMemorySize64/1MB)}else{-1}" < /dev/null | tr -d '\r')"; sleep 10; done ) > $R/$1.mem.txt & MP=$!
  bash run_arm.sh $R "$1" "$2" "$L" "$3"; kill $MP
  E=$(ls -t logs/*-$1.err.log | head -1)
  echo "switch lines: $(grep -c 'attention reads the host tail' $E)" >> $R/$1.txt
  awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v; if ($3>p) p=$3} END{print "trace min free VRAM", m, "MiB; server private peak", p, "MiB"}' $R/$1.mem.txt >> $R/$1.txt
}
arm new "$V" "4000 32000 128000 192000 245000"
arm old "$V;GGML_CUDA_KV_TIER_GRAPHS=1" "4000 32000 128000 192000 245000"
arm new_lkoff "$V;BONSAI_LOOKUP=0" "192000"
arm old_lkoff "$V;GGML_CUDA_KV_TIER_GRAPHS=1;BONSAI_LOOKUP=0" "192000"
{ for a in new old new_lkoff old_lkoff; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"
    grep -E "loaded|prose  depth|mean decode|did not|rror|switch lines|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'
    grep -hE "^kv     tiered" logs/*-$a.out.log | tail -1 | cut -c1-80; done; } > $R/summary.txt
