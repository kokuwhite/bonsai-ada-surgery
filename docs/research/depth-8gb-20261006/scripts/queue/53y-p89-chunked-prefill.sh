#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p89; mkdir -p $R
export QTPS_TIMEOUT=7200
rm -rf /c/bonsai/bonsai-ada-surgery/bin-chunk && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-chunk/bin /c/bonsai/bonsai-ada-surgery/bin-chunk
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-chunk/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-chunk/; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
cd /c/bonsai/bonsai-ada-surgery/bin-chunk
{ echo "base: $(./test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 2>&1 | grep -E 'tests passed' | tr -d '\r')"
  echo "chunk256: $(GGML_CUDA_FA_CHUNK=256 ./test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 2>&1 | grep -E 'tests passed|FA_CHUNK: chunks' | sort -u | tr -d '\r' | tr '\n' ' ')"
  echo "chunk768: $(GGML_CUDA_FA_CHUNK=768 ./test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 2>&1 | grep -E 'tests passed' | tr -d '\r')"
  echo "chunk256 minq1 hs256: $(GGML_CUDA_FA_CHUNK=256 GGML_CUDA_FA_PREFILL_F16_MIN_Q=1 ./test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 -p 'hsk=256,hsv=256,nh=4,nr23=\[6,1\]' 2>&1 | grep -E 'tests passed' | tr -d '\r')"
  GGML_CUDA_FA_CHUNK=256 ./test-backend-ops.exe -o FLASH_ATTN_EXT -b CUDA0 2>&1 | grep -E "FAIL" | head -10
} > /c/bonsai/8gb/$R/tests.txt 2>&1
cd /c/bonsai/8gb
grep -q "FAIL" $R/tests.txt && { echo "tests failed - no server arms" > $R/summary.txt; cat $R/tests.txt >> $R/summary.txt; exit 1; }
L='C:/bonsai/bonsai-ada-surgery/start-server-262test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-chunk;BONSAI_LAYER=0'
for C in 0 32768; do
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  VV="$V"; [ $C != 0 ] && VV="$V;GGML_CUDA_FA_CHUNK=$C"
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p89_ab_c$C -Launcher "$L" -Vars "$VV" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag c${C}_d64000 --out $R/ab.jsonl --depth 64000 > $R/ab_c$C.txt 2>&1
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
memarm chunk_deep "$V;GGML_CUDA_FA_CHUNK=32768" "$L" "4000 64000 128000 192000 250000"
python - > $R/summary.txt <<'PY'
import json
rows=[json.loads(l) for l in open('receipts/p89/ab.jsonl')]
a={(r['kind'],r['item']):r for r in rows if r['tag']=='c0_d64000'}
b={(r['kind'],r['item']):r for r in rows if r['tag']=='c32768_d64000'}
same=sum(1 for k in a if k in b and a[k]['sha']==b[k]['sha'])
diff=[k[1]+'/'+k[0] for k in a if k in b and a[k]['sha']!=b[k]['sha']]
one=sum(1 for r in rows if r['n']==1)
wa=[r['wall'] for r in a.values()][1:]; wb=[r['wall'] for r in b.values()][1:]
print(f"d64k texts chunk off vs 32768: {same}/{len(a)} same, diff {diff}; one-token {one}; wall after first {sum(wa)/max(1,len(wa)):.1f} vs {sum(wb)/max(1,len(wb)):.1f} s")
PY
{ cat $R/tests.txt; echo "== chunk_deep: $(grep -c '(1 tok)' $R/chunk_deep.txt) one-token"; grep -E "loaded|depth|mean decode|accept|did not|trace min|rror" $R/chunk_deep.txt | sed -E 's/ttft +[0-9.]+s +//'; grep -ho "GGML_CUDA_FA_CHUNK: chunks.*" logs/*chunk_deep.err.log | head -1; } >> $R/summary.txt
