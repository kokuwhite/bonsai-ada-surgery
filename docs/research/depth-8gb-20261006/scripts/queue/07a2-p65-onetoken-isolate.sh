#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p65; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
arms=("nospec|BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tier;BONSAI_SPEC=0"
      "pre0041|BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-lookup"
      "window64k|BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tier;BONSAI_DRAFT_WINDOW=65536"
      "longmode|BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tier;BONSAI_MODEL=Ternary-Bonsai-2-27B-PTQ1_0.gguf")
for a in "${arms[@]}"; do tag=${a%%|*}; v=${a#*|}
  powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
  schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
  powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p65_$tag -Launcher "$L" -Vars "$v;BONSAI_LAYER=0;LLAMA_ARG_LOG_VERBOSITY=4" > $R/$tag.serve.txt 2>&1
  for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
  python benchmain/quick_tps.py --base http://127.0.0.1:8080 --key-file $KEY --depth 60000 2>&1 | grep -E "depth|mean decode" > $R/$tag.txt
  L2="$(cygpath "$(tr -d '\r' < logs/current.log)")"; cp "${L2%.out.log}.err.log" $R/$tag.server.log; cp "$L2" $R/$tag.launcher.log
done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
for f in $R/*.txt; do case $f in *serve.txt) continue;; esac; echo "$(basename $f .txt): $(grep -c '(1 tok)' $f) one-token of $(grep -c 'depth' $f)"; done > $R/summary.txt
