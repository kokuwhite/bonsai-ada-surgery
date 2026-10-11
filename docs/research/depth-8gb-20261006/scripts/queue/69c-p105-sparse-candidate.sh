#!/usr/bin/env bash
# P105 (#21 candidate): sparse decode, page 64, B=8192, on fa-sparse-proto d6c6e9f01 (64-cell MMA tile map), 8 GB
# launcher. Dense vs sparse at 160k and 245k: exact code copies (10), needles (12), decode (quick_tps). Prefill dense
# (MAXQ default), CHECK unset; both arms graphs off + f16 mask. Records the sync-warning count and the first fast: line.
cd /c/bonsai/8gb; R=receipts/p105; mkdir -p $R
export QTPS_TIMEOUT=7200
rm -rf /c/bonsai/bonsai-ada-surgery/bin-sparse5 && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-sparse/bin /c/bonsai/bonsai-ada-surgery/bin-sparse5
for f in /c/bonsai/bonsai-ada-surgery/bin-0046/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-sparse5/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-sparse5/; done
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
BASEV='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-sparse5;BONSAI_LAYER=0;LLAMA_ARG_KQ_MASK_PACKED=0;GGML_CUDA_DISABLE_GRAPHS=1;GGML_CUDA_FA_CHUNK=32768'
SP='GGML_CUDA_FA_SPARSE=8192,64,1024;GGML_CUDA_FA_SPARSE_FAST=1;GGML_CUDA_KV_TIER_STAGE_MIN_Q=9'
logpath() { cat logs/current.log | tr -d '\r' | sed -e 's#\\#/#g' -e 's#^C:#/c#'; }
serve() {   # serve <tag> <vars>
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p105_$1 -Launcher "$L" -Vars "$2" >/dev/null 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
}
notes() {   # notes <tag>: sync warnings and fast: line from the current server log
  O="$(logpath)"; E="${O%out.log}err.log"
  echo "$1: sync-per-write warnings $(grep -c 'one sync per K write' "$E"); $(grep -m1 -E 'FA_SPARSE.*fast:' "$E" | cut -c1-170)" >> $R/notes.txt
}
for D in 160000 245000; do
  for arm in dense sparse; do
    V="$BASEV"; [ $arm = sparse ] && V="$BASEV;$SP"
    serve ${arm}_code_$D "$V"
    PYTHONUTF8=1 python benchx/code_needle.py --key-file $KEY --depth $D --n 10 --tag ${arm}_$D --out $R/code.jsonl > $R/${arm}_code_$D.txt 2>&1
    notes ${arm}_code_$D
    serve ${arm}_needle_$D "$V"
    PYTHONUTF8=1 python benchx/needle_depth.py --key-file $KEY --depth $D --n 12 --tag ${arm}_$D --out $R/needle.jsonl > $R/${arm}_needle_$D.txt 2>&1
    notes ${arm}_needle_$D
  done
done
bash run_arm.sh $R speed_dense_160k "$BASEV" "$L" "160000"
bash run_arm.sh $R speed_sparse_160k "$BASEV;$SP" "$L" "160000"
# hypothesis check (P102e): 5-query verify ops (MTP tail 4) take the MMA 64-cell tile map like on the 4070
bash run_arm.sh $R speed_sparse_tail4_160k "$BASEV;$SP;BONSAI_SPEC_DEEP=4;BONSAI_VRAM_MARGIN=675" "$L" "160000"
bash run_arm.sh $R speed_dense_tail4_160k "$BASEV;BONSAI_SPEC_DEEP=4;BONSAI_VRAM_MARGIN=675" "$L" "160000"
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ for D in 160000 245000; do for arm in dense sparse; do echo "== $arm $D: code $(tail -1 $R/${arm}_code_$D.txt) | needles $(tail -1 $R/${arm}_needle_$D.txt)"; done; done
  python - <<'PY'
import json, collections
by = collections.defaultdict(list)
for l in open('receipts/p105/code.jsonl', encoding='utf-8'):
    r = json.loads(l); by[r['tag']].append(r)
for tag, rows in by.items():
    rr = rows[1:]
    print(f"code {tag}: {sum(r['ok'] for r in rows)}/{len(rows)} exact; failed {[r['fn'] for r in rows if not r['ok']]}; decode on items mean {sum(r['tg'] for r in rr)/max(1,len(rr)):.2f} tok/s")
PY
  for a in speed_dense_160k speed_sparse_160k speed_sparse_tail4_160k speed_dense_tail4_160k; do echo "-- $a: $(grep 'mean decode' $R/$a.txt) $(grep -c '(1 tok)' $R/$a.txt) one-token"; done
  cat $R/notes.txt; } > $R/summary.txt
