#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p63; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p63_tools -Launcher "$L" -Vars "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tier;BONSAI_LAYER=0" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
PROBE_ARMS=server python benchmain/agent_depth_probe.py --base http://127.0.0.1:8080 --key-file $KEY --depth 20000 --tag 8gb-t2 --out $R/probe.jsonl > $R/t2.txt 2>&1
PROBE_MANY_TOOLS=105 PROBE_TOOL_CHARS=976 PROBE_PI=1 PROBE_ARMS=server python benchmain/agent_depth_probe.py --base http://127.0.0.1:8080 --key-file $KEY --depth 20000 --tag 8gb-t107 --out $R/probe.jsonl > $R/t107.txt 2>&1
PROBE_ARMS=server python benchmain/agent_depth_probe.py --base http://127.0.0.1:8080 --key-file $KEY --depth 20000 --tag 8gb-t2b --out $R/probe.jsonl > $R/t2b.txt 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
