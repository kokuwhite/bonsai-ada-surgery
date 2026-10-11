#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p84; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-pstage.ps1'
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-pmask;BONSAI_LAYER=0'
H="LLAMA_ARG_KQ_MASK_PACKED=1;GGML_CUDA_SHARED_POOL=1;LLAMA_MTP_DRAFT_UBATCH=256;BONSAI_KV_VRAM_CELLS=59904"
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
memarm A_preset "$V" "$L" "4000 32000 64000 96000 128000"
memarm H131 "$V;$H" "$L" "4000 32000 64000 96000 128000"
memarm H262 "$V;$H;BONSAI_CTX=262144;GGML_CUDA_KV_TIER_STAGING_FRAC=0.308594" "$L" "4000 32000 64000 96000 128000 160000"
for r in 1 2; do memarm H262_fresh60k_r$r "$V;$H;BONSAI_CTX=262144;GGML_CUDA_KV_TIER_STAGING_FRAC=0.308594" "$L" "60000"; done
{ for a in A_preset H131 H262 H262_fresh60k_r1 H262_fresh60k_r2; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|prose  depth|mean decode|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'; grep -ho "staging buffer.*" logs/*$a.err.log 2>/dev/null | sort -u | head -2; done; } > $R/summary.txt
