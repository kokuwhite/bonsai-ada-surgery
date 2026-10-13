#!/usr/bin/env bash
# P113: released bundle-20261011 (90ca41e40, 53 patches; patch 0053 tier-graphs) on the 2060 SUPER, test launcher with BONSAI_BIN = the bundle bin, layer off (as P96).
# Gate (declared here, before the run): sha256 match; ADD / RMS_NORM / FLASH_ATTN_EXT all pass; decode within the P85 / P88 / P96 / P110 range
# at 4k-128k minus 3 % (4k >= 49.3, 32k >= 44.4, 64k >= 33.4, 96k >= 19.4, 128k >= 13.9) and 128k >= P96 (14.3) since 0053 helps past
# the line; 0 one-token; trace min free >= 60 MiB; lookup_ab texts compared with P96 (report, no gate: history differs, P94).
export QTPS_TIMEOUT=7200
cd /c/bonsai/8gb; R=receipts/p113; mkdir -p $R release_1011
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
[ -f release_1011/bonsai-bundle-win-x64.zip ] || gh release download bundle-20261011 -R professorpalmer/bonsai-ada-surgery -p bonsai-bundle-win-x64.zip -D release_1011 < /dev/null >> $R/zip.txt 2>&1
WANT=f8899cbfd98091b6830615dc83182626b0b551d8b833ceea58c4e2e52cda8bf8
GOT=$(powershell -NoProfile -Command "(Get-FileHash C:/bonsai/8gb/release_1011/bonsai-bundle-win-x64.zip -Algorithm SHA256).Hash.ToLower()" < /dev/null | tr -d '\r\n')
echo "size $(stat -c %s release_1011/bonsai-bundle-win-x64.zip) sha256 $GOT (want $WANT)" >> $R/zip.txt
[ "$GOT" = "$WANT" ] || { echo "SHA MISMATCH" >> $R/zip.txt; echo "sha mismatch: stop" > $R/summary.txt; exit 1; }
[ -d release_1011/x ] || powershell -NoProfile -Command "Expand-Archive -LiteralPath C:/bonsai/8gb/release_1011/bonsai-bundle-win-x64.zip -DestinationPath C:/bonsai/8gb/release_1011/x" < /dev/null >> $R/zip.txt 2>&1
EXE=$(find release_1011/x -name llama-server.exe | head -1)
[ -n "$EXE" ] || { echo "no llama-server.exe in zip" > $R/summary.txt; exit 1; }
BIN=$(cd "$(dirname "$EXE")" && pwd -W); echo "BIN $BIN" >> $R/zip.txt
for o in ADD RMS_NORM FLASH_ATTN_EXT; do
  T="$BIN/test-backend-ops.exe"; [ -f "$T" ] || { echo "$o: no test-backend-ops in zip" >> $R/tests.txt; continue; }
  echo "$o: $("$T" -o $o -b CUDA0 < /dev/null 2>&1 | grep -E 'tests passed' | tr -d '\r')" >> $R/tests.txt
done
L='C:/bonsai/bonsai-ada-surgery/start-server-1010test.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V="BONSAI_BIN=$BIN;BONSAI_LAYER=0"
memarm() { ( while :; do echo "$(date +%T) $(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits)"; sleep 10; done ) > $R/$1.mem.txt & MP=$!; bash run_arm.sh $R "$@"; kill $MP; awk '{v=$2+0; if (v>4000000) v=v-4194304; if (NR==1||v<m) m=v} END{print "trace min free", m, "MiB over", NR, "samples"}' $R/$1.mem.txt >> $R/$1.txt; }
memarm sweep "$V" "$L" "4000 32000 64000 96000 128000"
grep -hE "^(8gb|window|kv|spec|ckpt|note|warn|ram)" logs/*-sweep.out.log 2>/dev/null | tail -8 > $R/launcher_lines.txt
for r in 1 2; do memarm fresh60k_r$r "$V" "$L" "60000"; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p113_ab -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag rel_d0 --out $R/ab.jsonl --depth 0 > $R/ab_d0.txt 2>&1
python lookup_ab.py --base http://127.0.0.1:8080 --key-file $KEY --tag rel_d64000 --out $R/ab.jsonl --depth 64000 > $R/ab_d64000.txt 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
{ cat $R/zip.txt $R/tests.txt $R/launcher_lines.txt; for a in sweep fresh60k_r1 fresh60k_r2; do f=$R/$a.txt; echo "== $a: $(grep -c '(1 tok)' $f) one-token"; grep -E "loaded|prose  depth|mean decode|did not|trace min" $f | sed -E 's/ttft +[0-9.]+s +//'; done; echo "ab one-token: $(grep -c '"n": 1,' $R/ab.jsonl) of $(wc -l < $R/ab.jsonl)"; } > $R/summary.txt
