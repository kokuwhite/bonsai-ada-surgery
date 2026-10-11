"""One memory-clock arm: greedy decode in VRAM, tok/s and the exact output text, plus the memory clock under load.

python memclock_probe.py --tag stock --out receipts/memclock
Writes <out>/<tag>.json. Compare texts across arms: any byte difference at greedy is a failed identity gate.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import threading
import time
import urllib.request

sys.path.insert(0, r"C:\bonsai\bonsai-ada-surgery\bench")
from quick_tps import filler  # noqa: E402  same filler the depth sweep uses

PROMPTS = [
    ("code", "Write a Python function that parses ISO 8601 durations, with tests. Code only.", 400),
    ("prose", "Explain how a refrigerator works, step by step, in about 400 words.", 400),
]


def clock_sampler(stop, samples):
    while not stop.is_set():
        out = subprocess.run(["nvidia-smi", "--query-gpu=clocks.mem,clocks.gr,temperature.gpu,power.draw",
                              "--format=csv,noheader,nounits"], capture_output=True, text=True).stdout.strip()
        samples.append(out)
        time.sleep(1)


def go(base, key, prompt, n):
    body = {"model": "b", "messages": [{"role": "user", "content": prompt}], "max_tokens": n, "temperature": 0,
            "cache_prompt": True, "chat_template_kwargs": {"enable_thinking": False}}
    req = urllib.request.Request(base + "/v1/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
    r = json.loads(urllib.request.urlopen(req, timeout=1800).read())
    return r["choices"][0]["message"]["content"], r["timings"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8080")
    ap.add_argument("--key-file", default=r"C:\bonsai\bonsai-ada-surgery\artifacts\api_key.txt")
    ap.add_argument("--tag", required=True)
    ap.add_argument("--out", default=r"C:\bonsai\8gb\receipts\memclock")
    ap.add_argument("--depth", type=int, default=4000)
    ap.add_argument("--reps", type=int, default=2)
    a = ap.parse_args()
    key = open(a.key_file).read().strip()
    os.makedirs(a.out, exist_ok=True)
    pre = filler(a.base, key, a.depth) if a.depth else ""
    go(a.base, key, pre + "Say hi.", 4)  # warm the prompt cache with the filler
    stop, samples = threading.Event(), []
    th = threading.Thread(target=clock_sampler, args=(stop, samples), daemon=True)
    th.start()
    rows = []
    for rep in range(a.reps):
        for name, p, n in PROMPTS:
            text, t = go(a.base, key, pre + p, n)
            rows.append({"rep": rep, "name": name, "decode": t.get("predicted_per_second"),
                         "n": t.get("predicted_n"), "text": text})
            print(f"{a.tag:<8} rep {rep} {name:<6} decode {t.get('predicted_per_second', 0):6.2f} tok/s", flush=True)
    stop.set()
    th.join()
    clocks = [int(s.split(",")[0]) for s in samples if s and s.split(",")[0].strip().isdigit()]
    res = {"tag": a.tag, "depth": a.depth, "rows": rows, "clock_samples": samples,
           "mem_clock_max": max(clocks) if clocks else None, "mean_decode": sum(r["decode"] for r in rows) / len(rows)}
    with open(os.path.join(a.out, a.tag + ".json"), "w", encoding="utf-8") as f:
        json.dump(res, f, indent=1)
    print(f"{a.tag:<8} mean decode {res['mean_decode']:.2f} tok/s  mem clock under load max {res['mem_clock_max']} MHz")


if __name__ == "__main__":
    main()
