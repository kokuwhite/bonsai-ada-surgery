"""Issue #16 probe: host-memory use of llama-server during sequential long-thinking chat requests.

Sends N chat requests (thinking on by the launcher defaults, max_tokens 4096, temperature 0.6) and samples the
server's private bytes (commit) and working set every 5 s with PowerShell. Writes JSON lines to --out.
"""
import argparse, json, subprocess, threading, time, urllib.request

PROMPTS = [
    "Find and fix the bug in this Python function, then explain the fix step by step:\n\n"
    "def merge_intervals(xs):\n    xs.sort()\n    out = [xs[0]]\n    for a, b in xs[1:]:\n        if a < out[-1][1]:\n"
    "            out[-1][1] = b\n        else:\n            out.append([a, b])\n    return out\n",
    "This C function sometimes crashes. Find all bugs, fix them, and explain:\n\n"
    "char *join(char **parts, int n) {\n  int len = 0;\n  for (int i = 0; i <= n; i++) len += strlen(parts[i]);\n"
    "  char *s = malloc(len);\n  for (int i = 0; i < n; i++) strcat(s, parts[i]);\n  return s;\n}\n",
    "Design a rate limiter for an HTTP API (token bucket vs sliding window). Compare them, pick one, and write it in Python with tests.",
    "Prove that the sum of the first n odd numbers is n^2, then give two different proofs and check n = 1..5.",
    "A train leaves at 9:40 at 72 km/h; a second leaves the same station at 10:05 at 90 km/h on the same track. When and where does the second catch up? Show the work and check it.",
    "Refactor this JavaScript to async/await and handle errors correctly:\n\nfunction load(u, cb){ fetch(u).then(r=>r.json()).then(j=>cb(null,j)).catch(e=>cb(e)) }\nload('/a', (e,a)=>{ load('/b', (e2,b)=>{ console.log(a,b) }) })",
    "Explain how a B-tree insert splits nodes, with a worked example of inserting 1..12 into an order-3 B-tree.",
]


def sample(stop, out, t0):
    cmd = ("$p = Get-Process llama-server -ErrorAction SilentlyContinue | Select-Object -First 1; "
           "if ($p) { '{0} {1}' -f $p.PrivateMemorySize64, $p.WorkingSet64 } else { 'none' }; "
           "$os = Get-CimInstance Win32_OperatingSystem; '{0} {1}' -f $os.FreeVirtualMemory, $os.FreePhysicalMemory")
    while not stop.is_set():
        r = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True, stdin=subprocess.DEVNULL).stdout.split()
        rec = {"t": round(time.time() - t0, 1), "kind": "mem"}
        if len(r) >= 4 and r[0] != "none":
            rec.update(private_mib=int(r[0]) // 2**20, ws_mib=int(r[1]) // 2**20, free_commit_mib=int(r[2]) // 1024, free_phys_mib=int(r[3]) // 1024)
        out.write(json.dumps(rec) + "\n"); out.flush()
        stop.wait(5)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8080")
    ap.add_argument("--key-file", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--n", type=int, default=7)
    ap.add_argument("--prefix-words", type=int, default=0, help="a different long prefix per request (~1.3 tokens per word)")
    a = ap.parse_args()
    key = open(a.key_file).read().strip()
    t0 = time.time()
    out = open(a.out, "a")
    stop = threading.Event()
    th = threading.Thread(target=sample, args=(stop, out, t0), daemon=True)
    th.start()
    for i in range(a.n):
        content = PROMPTS[i % len(PROMPTS)]
        if a.prefix_words:
            import random
            rnd = random.Random(1000 + i)
            words = ["alpha", "river", "stone", "copper", "lantern", "mesa", "orbit", "quill", "tundra", "violet", "harbor", "ember"]
            prefix = " ".join(rnd.choice(words) + str(rnd.randint(0, 999)) for _ in range(a.prefix_words))
            content = "Background notes (ignore unless needed):\n" + prefix + "\n\nTask:\n" + content
        body = {"messages": [{"role": "user", "content": content}], "max_tokens": 4096, "temperature": 0.6}
        req = urllib.request.Request(a.base + "/v1/chat/completions", data=json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
        ts = time.time()
        rec = {"t": round(ts - t0, 1), "kind": "req", "i": i}
        try:
            r = json.loads(urllib.request.urlopen(req, timeout=3600).read())
            u = r.get("usage", {})
            rec.update(ok=True, completion_tokens=u.get("completion_tokens"), prompt_tokens=u.get("prompt_tokens"), wall=round(time.time() - ts, 1))
        except Exception as e:
            rec.update(ok=False, error=str(e)[:200], wall=round(time.time() - ts, 1))
        out.write(json.dumps(rec) + "\n"); out.flush()
    stop.set(); th.join(10)


if __name__ == "__main__":
    main()
