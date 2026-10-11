#!/usr/bin/env bash
# P101: sparse host-tail reads at REAL depth on 8 GB (issue #21). 262k main launcher (line ~58k: host tail ~187k cells
# at 245k), bin-sparse (4070 fa-sparse-proto 87e2ac160, built for sm_75). Every arm: f16 mask, CUDA graphs off, chunked
# prefill. Sparse arms: GGML_CUDA_FA_SPARSE=B,64,1024 with FAST=1 (decode-sized ops only, the deployable mode) and
# STAGE_MIN_Q=9 (decode reads the host tail in place, so unselected pages are not read: the speed path).
# Per arm: 10 exact code copies (benchx/code_needle.py) and 12 needle facts (benchx/needle_depth.py) at ~245k.
cd /c/bonsai/8gb; R=receipts/p101; mkdir -p $R
rm -rf /c/bonsai/bonsai-ada-surgery/bin-sparse && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-sparse/bin /c/bonsai/bonsai-ada-surgery/bin-sparse
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-sparse/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-sparse/; done
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse;BONSAI_LAYER=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768'
logpath() { cat logs/current.log | tr -d '\r' | sed -e 's#\\#/#g' -e 's#^C:#/c#'; }
DEPTH=${DEPTH:-245000}
for arm in dense s8192 s16384; do
  V="$BASEV"
  case $arm in
    s8192)  V="$V;GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9" ;;
    s16384) V="$V;GGML_CUDA_FA_SPARSE=16384,64,1024;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9" ;;
  esac
  for test in code needle; do
    powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
    schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
    powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p101_${arm}_$test -Launcher "$L" -Vars "$V" >/dev/null 2>&1
    for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
    O="$(logpath)"; E="${O%out.log}err.log"
    grep -hE '^(window|kv) ' "$O" > $R/${arm}_$test.launcher.txt
    if [ $test = code ]; then
      PYTHONUTF8=1 python benchx/code_needle.py --key-file $KEY --depth $DEPTH --n 10 --tag $arm --out $R/code.jsonl > $R/${arm}_code.txt 2>&1
    else
      PYTHONUTF8=1 python benchx/needle_depth.py --key-file $KEY --depth $DEPTH --n 12 --tag $arm --out $R/needle.jsonl > $R/${arm}_needle.txt 2>&1
    fi
    grep -E "FA_SPARSE|sparse|host tail kept" "$E" | tail -3 > $R/${arm}_$test.sparse_lines.txt
  done
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ for arm in dense s8192 s16384; do for test in code needle; do echo "== $arm $test: $(tail -1 $R/${arm}_$test.txt)"; head -2 $R/${arm}_$test.launcher.txt; cat $R/${arm}_$test.sparse_lines.txt; done; done
  python - <<'PY'
import json, collections
by = collections.defaultdict(list)
for l in open('receipts/p101/code.jsonl', encoding='utf-8'):
    r = json.loads(l); by[r['tag']].append(r)
for tag, rows in by.items():
    rows2 = rows[1:]
    print(f"code {tag}: {sum(r['ok'] for r in rows)}/{len(rows)} exact; decode tok/s (after the first) mean {sum(r['tg'] for r in rows2)/max(1,len(rows2)):.2f}; wall after first {sum(r['wall_s'] for r in rows2)/max(1,len(rows2)):.1f} s")
PY
} > $R/summary.txt
