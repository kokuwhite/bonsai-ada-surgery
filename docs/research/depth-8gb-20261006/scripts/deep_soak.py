"""P99: a long agent-style session deep in the 262k window. One conversation: a ~150k-token real-source prefix, then N
turns; each turn appends the previous answer and a new user message with ~2-3k tokens of real source and a question.
Per turn: prompt tokens, new tokens processed, wall, prefill / decode tok/s, completion tokens, one-token flag; and
free VRAM / server private bytes sampled after each turn.
"""
import argparse, glob, json, os, subprocess, time, urllib.request

ap = argparse.ArgumentParser()
ap.add_argument("--base", default="http://127.0.0.1:8080")
ap.add_argument("--key-file", required=True)
ap.add_argument("--start-tokens", type=int, default=150000)
ap.add_argument("--turns", type=int, default=25)
ap.add_argument("--turn-tokens", type=int, default=2500)
ap.add_argument("--out", required=True)
a = ap.parse_args()
key = open(a.key_file).read().strip()
lib = os.path.dirname(os.__file__)
files = sorted(glob.glob(os.path.join(lib, "*.py"))) + sorted(glob.glob(os.path.join(lib, "*", "*.py")))
texts = []
for f in files:
    try:
        texts.append((os.path.relpath(f, lib), open(f, encoding="utf-8").read()))
    except Exception:
        pass
pos = 0
def take(n_tokens):
    global pos
    want, buf = int(n_tokens * 3.2), []
    got = 0
    while got < want and pos < len(texts):
        name, t = texts[pos]; pos += 1
        piece = f"# ===== {name} =====\n{t}\n"
        buf.append(piece); got += len(piece)
    return "".join(buf), [name for name, _ in texts[pos - len(buf):pos]]

def sample():
    cmd = ("$p = Get-Process llama-server -ErrorAction SilentlyContinue | Select-Object -First 1; "
           "if ($p) { [int]($p.PrivateMemorySize64/1MB) } else { -1 }")
    priv = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True, stdin=subprocess.DEVNULL).stdout.strip()
    vram = subprocess.run(["nvidia-smi", "--query-gpu=memory.free", "--format=csv,noheader,nounits"], capture_output=True, text=True, stdin=subprocess.DEVNULL).stdout.strip()
    return priv, vram

prefix, names = take(a.start_tokens)
messages = [{"role": "user", "content": "Here is part of a Python code base. Read it; I will ask about it next.\n\n" + prefix +
             "\n\nReply with one short sentence when you have read it."}]
out = open(a.out, "a")
for turn in range(a.turns + 1):
    if turn > 0:
        chunk, cn = take(a.turn_tokens)
        q = f"More files follow ({', '.join(cn[:3])}{'...' if len(cn) > 3 else ''}).\n\n{chunk}\n\nIn two or three sentences: what does the first of these files do, and which earlier file in this conversation is most related to it?"
        messages.append({"role": "user", "content": q})
    body = {"messages": messages, "max_tokens": 300, "temperature": 0}
    req = urllib.request.Request(a.base + "/v1/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
    t0 = time.time()
    rec = {"turn": turn}
    try:
        r = json.loads(urllib.request.urlopen(req, timeout=10800).read())
        u = r.get("usage", {}); ti = r.get("timings", {})
        ans = r["choices"][0]["message"].get("content", "") or ""
        rec.update(ok=True, prompt_tokens=u.get("prompt_tokens"), new_tokens=ti.get("prompt_n"), completion_tokens=u.get("completion_tokens"),
                   wall=round(time.time() - t0, 1), pp=round(ti.get("prompt_per_second") or 0, 1), tg=round(ti.get("predicted_per_second") or 0, 1),
                   one_token=(u.get("completion_tokens") or 0) <= 1, answer=ans[:240])
        messages.append({"role": "assistant", "content": ans})
    except Exception as e:
        rec.update(ok=False, error=str(e)[:200], wall=round(time.time() - t0, 1))
    rec["server_private_mib"], rec["vram_free_mib"] = sample()
    out.write(json.dumps(rec) + "\n"); out.flush()
    if not rec.get("ok"):
        break
