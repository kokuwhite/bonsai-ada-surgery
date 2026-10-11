#!/usr/bin/env bash
# P72 rerun: the first run failed to extract the zip inside the task; bin-8gbfix is installed by hand (142d5105d).
cd /c/bonsai/8gb; R=receipts/p72b; mkdir -p $R
echo "zip sha256 aaf7637ef1f7d04f314d755cf39deca0c9dd2ad25617153bed7138025f08fe09, 608055810 bytes, engine 142d5105d" > $R/zip.txt
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
for o in ADD RMS_NORM FLASH_ATTN_EXT; do echo "$o: $(/c/bonsai/bonsai-ada-surgery/bin-8gbfix/test-backend-ops.exe -o $o -b CUDA0 2>&1 | grep -E 'tests passed' | tr -d '\r')" >> $R/tests.txt; done
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-8gbfix;BONSAI_LAYER=0'
for r in 1 2; do bash run_arm.sh $R fresh60k_r$r "$V" "$L" "60000"; done
bash run_arm.sh $R sweep "$V" "$L" "4000 32000 64000"
bash run_arm.sh $R long "$V;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf" "$L" "4000 32000"
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p72b_ab -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag rel_d0 --out $R/ab.jsonl --depth 0 > $R/ab.txt 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ cat $R/zip.txt $R/tests.txt; for f in $R/fresh*.txt $R/sweep.txt $R/long.txt; do echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token; $(grep -E 'loaded|mean decode|min free|did not' $f | tr '\n' ' ')"; done; echo "ab d0 one-token: $(grep -c '"n": 1,' $R/ab.jsonl) of $(wc -l < $R/ab.jsonl)"; } > $R/summary.txt
