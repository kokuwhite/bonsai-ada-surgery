#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p56; mkdir -p $R
cmd //c 'C:\bonsai\bonsai-ada-surgery\tooling\build-tier\build.bat' > logs/build-tier.log 2>&1 || { echo "build failed" > $R/summary.txt; exit 1; }
rm -rf /c/bonsai/bonsai-ada-surgery/bin-tier && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-tier/bin /c/bonsai/bonsai-ada-surgery/bin-tier
for f in /c/bonsai/bonsai-ada-surgery/bin-lookup/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-tier/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-tier/; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
for o in ADD RMS_NORM FLASH_ATTN_EXT; do echo "$o: $(/c/bonsai/bonsai-ada-surgery/bin-tier/test-backend-ops.exe -o $o -b CUDA0 2>&1 | grep -E 'tests passed' | tr -d '\r')" >> $R/tests.txt; done
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'
for r in 1 2; do for b in lookup tier; do
  bash run_arm.sh $R ${b}_$r "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-$b;BONSAI_LAYER=0" "$L" "4000 32000 64000 96000"
done; done
grep -H -E "loaded|mean decode|min free|code   depth" $R/*_?.txt | sed "s#$R/##" > $R/summary.txt
