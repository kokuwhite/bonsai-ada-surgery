#!/usr/bin/env bash
# HumanEval 164 at medium, raw server (layer off), greedy, with one chat template file; also saves the server's own
# render of a HumanEval-style request (/apply-template) next to the results.
#   bash bench/he_template_one.sh <template file | -> <name> [kwargs json]  -> artifacts/humaneval-<name>/, receipts/he_template_ab.log
# template "-": the model's own template. HE_ROOT=<dir>: start that root's launcher and bin (default: this repo).
# HE_EXTRA: more humaneval_run.py flags (e.g. --prefix-file f).
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd -W)"; TPL=${1:?template}; NAME=${2:?name}; KW=${3:-}
TPLW=""; [ "$TPL" != "-" ] && TPLW="$(cygpath -w "$(realpath "$TPL")")"
ROOTW="$REPO"; [ -n "$HE_ROOT" ] && ROOTW="$(cygpath -w "$HE_ROOT")"
LOG=receipts/he_template_ab.log; OUT=artifacts/humaneval-$NAME
say() { echo "$(date '+%H:%M') $*" | tee -a "$LOG"; }
rm -f logs/ramguard.stop
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ramguard.ps1 -Names llama-server -StopFile logs/ramguard.stop &
GUARD=$!
trap 'touch logs/ramguard.stop; wait $GUARD 2>/dev/null; powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1' EXIT
powershell -NoProfile -ExecutionPolicy Bypass -File bench/stop_serve.ps1 >/dev/null 2>&1; sleep 4
env BONSAI_LAYER=0 BONSAI_MODEL="$REPO\\models\\Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf" ${TPLW:+LLAMA_ARG_CHAT_TEMPLATE_FILE="$TPLW"} powershell -NoProfile -Command "Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$ROOTW\\start-server.ps1' -RedirectStandardOutput '$REPO\\logs\\heone_$NAME.launcher.log' -RedirectStandardError '$REPO\\logs\\heone_$NAME.server.log'"
ok=0; for k in $(seq 1 120); do sleep 2; curl -s -m 2 http://127.0.0.1:8080/health | grep -q ok && { ok=1; break; }; done
TPLNAME=model; [ -n "$TPLW" ] && TPLNAME=$(basename "$TPLW")
say "=== $NAME: template $TPLNAME, root $ROOTW, kwargs ${KW:-none}${HE_EXTRA:+, $HE_EXTRA}, health=$ok"
[ $ok = 1 ] || exit 1
mkdir -p "$OUT"
PYTHONUTF8=1 python - "$OUT" "$KW" <<'PY'
import json, sys, urllib.request
out, kw = sys.argv[1], sys.argv[2]
key = open("artifacts/api_key.txt").read().strip()
user = ("Complete this Python function so it passes its docstring examples. Reply with one python code block containing "
        "only the function. Do not write tests.\n\ndef f(x):\n    \"\"\"Return x.\"\"\"\n")
kwargs = {"enable_thinking": True, "reasoning_effort": "medium", **(json.loads(kw) if kw else {})}
body = {"messages": [{"role": "user", "content": user}], "chat_template_kwargs": kwargs}
req = urllib.request.Request("http://127.0.0.1:8080/apply-template", data=json.dumps(body).encode(),
                             headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
prompt = json.loads(urllib.request.urlopen(req, timeout=60).read()).get("prompt", "")
open(out + "/apply_template.txt", "w", encoding="utf-8").write(prompt)
print("apply-template: %d chars, system block: %s" % (len(prompt), "<|im_start|>system" in prompt))
PY
PYTHONUTF8=1 python bench/humaneval_run.py --arm medium --max-tokens 24576 ${KW:+--kwargs "$KW"} $HE_EXTRA --out "$OUT" 2>&1 | tail -2 | tee -a "$LOG"
python -c "import json;r=json.load(open('$OUT/summary.json'))['rows'];t=sorted(x['completion_tokens'] for x in r);print('$NAME: mean tokens %.0f median %d, over 4k: %d' % (sum(t)/len(t), t[len(t)//2], sum(x>4000 for x in t)))" | tee -a "$LOG"
say "=== $NAME done"
