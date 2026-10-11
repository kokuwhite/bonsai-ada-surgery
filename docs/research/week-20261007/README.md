# Serving research, 2026-10-07 to 2026-10-10

The week's serving work on one RTX 4070 12 GB (PCIe 4.0), plus the RTX 2060 SUPER 8 GB rig runs whose receipts are in
`docs/receipts/{262k_8gb,chunked_prefill,depth_8gb,ram_8gb}/`: issue #7 (slow agent sessions), prefill past the VRAM
line, more context in VRAM on 12 GB, checkpoints inside long messages, the 262k window and chunked prefill on 8 GB,
RAM sizing (issue #16), the PR checks and every release smoke. Read `REPORT.md` first. 48 entries in `EXPERIMENTS.md`
(W01-W48), one line each in `runs.jsonl` (with `wall_s` and `gpu_h` from the receipts' timestamps where they have
them). `OPEN.md` lists inferred dates, numbers computed for this log, and the points that are not resolved.

| Path | What |
| --- | --- |
| `REPORT.md` | Bottom line, promoted / rejected with the bundle that shipped each item, order of the work, open items |
| `EXPERIMENTS.md` | One entry per experiment: question, gate (only where one was written), setup, result, verdict, receipts |
| `runs.jsonl` | One JSON line per experiment |
| `OPEN.md` | Dates and numbers inferred or computed for this log; unresolved points |
| `../../receipts/` | The receipts named in each entry |
| `../../../bench/` | The scripts named in each entry (the 8 GB rig's scripts are on the rig, not in this repo) |

This log was written after the runs, from the receipts, the commits that added them and the docs. Gates are recorded
only where a script header, a doc or a commit states one; most runs here were measurements without a written gate.
GPU time: 17.1 h on the RTX 4070 and 1.6 h of timed RTX 2060 SUPER runs (five entries have no usable times).
Related logs: `../depth-20261010/` (the depth work that followed), `../release-20261011/`, `../quality-20260929/`.
