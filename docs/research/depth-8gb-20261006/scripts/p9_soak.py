"""Soak: alternate 4k / 16k greedy requests for --seconds, logging decode and GPU telemetry per request.

python p9_soak.py --tag oc150 --seconds 600
Writes receipts/p9/<tag>.json and prints one line per request plus a first-vs-last summary per depth.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import threading
import time

sys.path.insert(0, r"C:\bonsai\8gb")
from memclock_probe import go  # noqa: E402
sys.path.insert(0, r"C:\bonsai\bonsai-ada-surgery\bench")
from quick_tps import filler  # noqa: E402

PROMPTS = ["Write a Python function that merges overlapping intervals, with tests. Code only.",
           "Explain how a heat pump works in winter, step by step, in about 300 words."]


def sampler(stop, out):
    while not stop.is_set():
        s = subprocess.run(["nvidia-smi", "--query-gpu=clocks.gr,temperature.gpu,power.draw,clocks_throttle_reasons.active",
                            "--format=csv,noheader,nounits"], capture_output=True, text=True).stdout.strip()
        out.append((time.time(), s))
        time.sleep(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8080")
    ap.add_argument("--key-file", default=r"C:\bonsai\bonsai-ada-surgery\artifacts\api_key.txt")
    ap.add_argument("--tag", required=True)
    ap.add_argument("--seconds", type=int, default=600)
    ap.add_argument("--depths", default="4000,16000")
    ap.add_argument("--out", default=r"C:\bonsai\8gb\receipts\p9")
    a = ap.parse_args()
    key = open(a.key_file).read().strip()
    os.makedirs(a.out, exist_ok=True)
    depths = [int(x) for x in a.depths.split(",")]
    pre = {d: filler(a.base, key, d) for d in depths}
    for d in pre:  # warm both prefixes so every timed request decodes from a cached prompt
        go(a.base, key, pre[d] + "Say hi.", 4)
    stop, samples = threading.Event(), []
    th = threading.Thread(target=sampler, args=(stop, samples), daemon=True)
    th.start()
    rows, t0, i = [], time.time(), 0
    while time.time() - t0 < a.seconds:
        d = depths[i % len(depths)]
        p = PROMPTS[(i // len(depths)) % 2]
        ts = time.time()
        text, t = go(a.base, key, pre[d] + p, 300)
        rows.append({"t": ts - t0, "depth": d, "prompt": p[:20], "decode": t.get("predicted_per_second"), "text": text})
        print(f"{ts - t0:6.0f}s depth {d:>5} decode {t.get('predicted_per_second', 0):6.2f}  gpu {samples[-1][1] if samples else ''}",
              flush=True)
        i += 1
    stop.set()
    th.join()
    summary = {}
    for d in depths:
        r = [x for x in rows if x["depth"] == d]
        first = [x["decode"] for x in r if x["t"] < 120]
        last = [x["decode"] for x in r if x["t"] > a.seconds - 120]
        if first and last:
            f, l = sum(first) / len(first), sum(last) / len(last)
            summary[d] = {"first2min": f, "last2min": l, "change_pct": 100 * (l - f) / f}
    temps = [float(s.split(",")[1]) for _, s in samples if s]
    res = {"tag": a.tag, "rows": rows, "samples": samples, "summary": summary, "max_temp": max(temps) if temps else None}
    json.dump(res, open(os.path.join(a.out, a.tag + ".json"), "w", encoding="utf-8"), indent=1)
    for d, v in summary.items():
        print(f"{a.tag} depth {d}: first 2 min {v['first2min']:.2f}, last 2 min {v['last2min']:.2f} ({v['change_pct']:+.1f}%)")
    print(f"{a.tag} max temp {res['max_temp']} C, requests {len(rows)}")


if __name__ == "__main__":
    main()
