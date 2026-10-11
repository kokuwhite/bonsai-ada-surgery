"""Greedy request at a given filler depth; prints and saves the generated text, token count and finish reason.

python depth_text_probe.py --tag x --depth 32000 [--base http://127.0.0.1:8080] [--n 200]
"""
import argparse
import json
import os
import sys
import urllib.request

sys.path.insert(0, r"C:\bonsai\bonsai-ada-surgery\bench")
from quick_tps import filler  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8080")
    ap.add_argument("--key-file", default=r"C:\bonsai\bonsai-ada-surgery\artifacts\api_key.txt")
    ap.add_argument("--tag", required=True)
    ap.add_argument("--depth", type=int, default=32000)
    ap.add_argument("--n", type=int, default=200)
    ap.add_argument("--out", default=r"C:\bonsai\8gb\receipts\p17")
    a = ap.parse_args()
    key = open(a.key_file).read().strip()
    os.makedirs(a.out, exist_ok=True)
    rows = []
    for prompt in ("Write a Python function that merges overlapping intervals, with tests. Code only.",
                   "Explain how a heat pump works in winter, step by step."):
        body = {"model": "b", "messages": [{"role": "user", "content": filler(a.base, key, a.depth) + prompt}],
                "max_tokens": a.n, "temperature": 0, "chat_template_kwargs": {"enable_thinking": False}}
        req = urllib.request.Request(a.base + "/v1/chat/completions", data=json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
        r = json.loads(urllib.request.urlopen(req, timeout=3600).read())
        c = r["choices"][0]
        row = {"prompt": prompt[:30], "finish": c.get("finish_reason"), "n": r["timings"].get("predicted_n"),
               "decode": r["timings"].get("predicted_per_second"), "text": c["message"].get("content"),
               "reasoning": c["message"].get("reasoning_content")}
        rows.append(row)
        print(f"{a.tag} depth {a.depth} {row['prompt']!r}: finish={row['finish']} n={row['n']} "
              f"decode={row['decode']:.1f} text={row['text'][:120]!r} reasoning={str(row['reasoning'])[:80]!r}", flush=True)
    json.dump(rows, open(os.path.join(a.out, a.tag + ".json"), "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
