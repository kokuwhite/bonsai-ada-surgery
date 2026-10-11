#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p67; mkdir -p $R
L='C:/bonsai/bonsai-ada-surgery/start-server-maintest-pool.ps1'; KEY=C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt
V='BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-tier;BONSAI_LAYER=0'
bash run_arm.sh $R graphsoff "$V;GGML_CUDA_DISABLE_GRAPHS=1" "$L" "60000"
bash run_arm.sh $R draftub_default "$V;LLAMA_MTP_DRAFT_UBATCH=512" "$L" "60000"
bash run_arm.sh $R pre0041_pool "BONSAI_BIN=C:/bonsai/bonsai-ada-surgery/bin-lookup;BONSAI_LAYER=0" "$L" "60000"
bash run_arm.sh $R pool_control "$V" "$L" "60000"
# the one token: same 60k filler prompt through /completion with n_probs
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
schtasks //run //tn BonsaiAB_P3 >/dev/null; sleep 4; schtasks //run //tn BonsaiAB_P5 >/dev/null; sleep 6
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Tag p67_probs -Launcher "$L" -Vars "$V" >/dev/null 2>&1
for i in $(seq 1 120); do curl -s localhost:8080/health | grep -q ok && break; sleep 5; done
cd benchmain && python - > /c/bonsai/8gb/$R/probs.txt 2>&1 <<'PY'
import json, urllib.request
from quick_tps import filler, _headers
base = "http://127.0.0.1:8080"; key = open("C:/bonsai/bonsai-ada-surgery/artifacts/api_key.txt").read().strip()
pre = filler(base, key, 60000)
body = {"messages": [{"role": "user", "content": pre + "\nWrite a Python function that parses ISO 8601 durations."}],
        "max_tokens": 32, "temperature": 0, "logprobs": True, "top_logprobs": 5, "chat_template_kwargs": {"enable_thinking": False}}
req = urllib.request.Request(base + "/v1/chat/completions", data=json.dumps(body).encode(), headers=_headers(key))
r = json.load(urllib.request.urlopen(req, timeout=3600))
c = r["choices"][0]
print("finish", c.get("finish_reason"), "content", repr(c["message"].get("content")), "usage", r.get("usage"))
print(json.dumps(c.get("logprobs"), indent=1)[:3000])
PY
cd /c/bonsai/8gb; powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
