"""P98b: a real long document (Python standard library source) as one prompt, then short answers, for the K-first
probe at depth on real text (the quick_tps filler is synthetic and may spread attention evenly).
Usage: python realtext_probe.py --key-file K --tokens 200000 --out receipts/p98b/run.jsonl
"""
import argparse, glob, json, os, time, urllib.request

ap = argparse.ArgumentParser()
ap.add_argument("--base", default="http://127.0.0.1:8080")
ap.add_argument("--key-file", required=True)
ap.add_argument("--tokens", type=int, default=200000)
ap.add_argument("--out", required=True)
a = ap.parse_args()
key = open(a.key_file).read().strip()
lib = os.path.join(os.path.dirname(os.__file__))
files = sorted(glob.glob(os.path.join(lib, "*.py")))
parts, chars = [], 0
target_chars = int(a.tokens * 3.2)          # ~3.2 characters per token for Python source
for f in files:
    try:
        t = open(f, encoding="utf-8").read()
    except Exception:
        continue
    parts.append(f"# ===== {os.path.basename(f)} =====\n{t}\n")
    chars += len(parts[-1])
    if chars >= target_chars:
        break
doc = "".join(parts)
questions = [
    "In the file shlex.py above, what does the method `read_token` return at end of input? Answer in two sentences.",
    "Which module above defines the function `fnmatchcase`, and what does it do? Answer briefly.",
    "Summarize what the class `TextWrapper` in textwrap.py above is for, in three sentences.",
]
out = open(a.out, "a")
for i, q in enumerate(questions):
    body = {"messages": [{"role": "user", "content": doc + "\n\n" + q}], "max_tokens": 160, "temperature": 0}
    req = urllib.request.Request(a.base + "/v1/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
    t0 = time.time()
    r = json.loads(urllib.request.urlopen(req, timeout=10800).read())
    u = r.get("usage", {}); ti = r.get("timings", {})
    out.write(json.dumps({"i": i, "prompt_tokens": u.get("prompt_tokens"), "completion_tokens": u.get("completion_tokens"),
                          "wall": round(time.time() - t0, 1), "pp": ti.get("prompt_per_second"), "tg": ti.get("predicted_per_second"),
                          "answer": r["choices"][0]["message"].get("content", "")[:400]}) + "\n")
    out.flush()
