#!/usr/bin/env bash
# P79: released bundle-20261009-ckpt on the 2060 SUPER (plan in DECISIONS.md, written before the run).
cd /c/bonsai/8gb; R=receipts/p79; mkdir -p $R release_ckpt
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
[ -f release_ckpt/bonsai-bundle-win-x64.zip ] || gh release download bundle-20261009-ckpt -R professorpalmer/bonsai-ada-surgery -p bonsai-bundle-win-x64.zip -D release_ckpt < /dev/null >> $R/zip.txt 2>&1
WANT=9afbb49f9656cf8abee95ae5e30b22c072a3eca5cc24a37d47dcc817f983f479
GOT=$(powershell -NoProfile -Command "(Get-FileHash C:/bonsai/8gb/release_ckpt/bonsai-bundle-win-x64.zip -Algorithm SHA256).Hash.ToLower()" < /dev/null | tr -d '\r\n')
echo "size $(stat -c %s release_ckpt/bonsai-bundle-win-x64.zip) sha256 $GOT (want $WANT)" >> $R/zip.txt
[ "$GOT" = "$WANT" ] || { echo "SHA MISMATCH" >> $R/zip.txt; echo "sha mismatch: stop" > $R/summary.txt; exit 1; }
[ -d release_ckpt/x ] || powershell -NoProfile -Command "Expand-Archive -LiteralPath C:/bonsai/8gb/release_ckpt/bonsai-bundle-win-x64.zip -DestinationPath C:/bonsai/8gb/release_ckpt/x" < /dev/null >> $R/zip.txt 2>&1
EXE=$(find release_ckpt/x -name llama-server.exe | head -1)
[ -n "$EXE" ] || { echo "no llama-server.exe in zip" > $R/summary.txt; exit 1; }
BIN=$(cd "$(dirname "$EXE")" && pwd -W); echo "BIN $BIN" >> $R/zip.txt
for o in ADD RMS_NORM FLASH_ATTN_EXT; do
  T="$BIN/test-backend-ops.exe"; [ -f "$T" ] || { echo "$o: no test-backend-ops in zip" >> $R/tests.txt; continue; }
  echo "$o: $("$T" -o $o -b CUDA0 < /dev/null 2>&1 | grep -E 'tests passed' | tr -d '\r')" >> $R/tests.txt
done
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V="BONSAI_BIN=$BIN;BONSAI_LAYER=0"
for r in 1 2; do bash run_arm.sh $R fresh60k_r$r "$V" "$L" "60000"; done
grep -h -i "checkpoint.every\|CHECKPOINT_EVERY" logs/*fresh60k_r1*.log 2>/dev/null | head -5 > $R/ckpt_flag.txt
bash run_arm.sh $R sweep "$V" "$L" "4000 32000 64000"
bash run_arm.sh $R long "$V;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf" "$L" "4000 32000"
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p79_ab -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
grep -h -i "checkpoint.every\|CHECKPOINT_EVERY" $(cat logs/current.log | tr -d '\r' | sed 's#\#/#g; s#^C:#/c#') "$(cat logs/current.log | tr -d '\r' | sed 's#\#/#g; s#^C:#/c#; s#out.log$#err.log#')" 2>/dev/null | head -5 >> $R/ckpt_flag.txt
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag rel_d0 --out $R/ab.jsonl --depth 0 > $R/ab_d0.txt 2>&1
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag rel_d64000 --out $R/ab.jsonl --depth 64000 > $R/ab_d64000.txt 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ cat $R/zip.txt $R/tests.txt; echo "ckpt flag lines: $(wc -l < $R/ckpt_flag.txt)"; for f in $R/fresh*.txt $R/sweep.txt $R/long.txt; do echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token; $(grep -E 'loaded|mean decode|min free|did not' $f | tr '\n' ' ')"; done; echo "ab one-token: $(grep -c '"n": 1,' $R/ab.jsonl) of $(wc -l < $R/ab.jsonl)"; } > $R/summary.txt
