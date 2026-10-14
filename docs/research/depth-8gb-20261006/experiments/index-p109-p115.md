# Index, P109 to P115

Run times are rig local time from receipts/queue.log. Events in this range (the stop for the move, the resume, the
4070's sparse allocation answer and the 8d5b862fc / 3299a0b4b builds, bundle-20261011) are in `events-p090-p108.md`,
sections E18-E22; later events (PR #40, bundle-20261013, the power cut and the crash, product-sparse, int8 bounds, the
q3_0 port) are in `events-p109-p132.md`, E23-E37. P108 (q3_0 tests, run 2026-10-13) is in `index-p090-p108.md`. P116
to P132 are in `index-p116-p132.md`.

| ID | date | title | status | one-line result |
| --- | --- | --- | --- | --- |
| [P109](P109.md) | 2026-10-11 11:42-11:50; 10-13 11:05-11:08 | Is the sparse 8 GB slowdown VRAM over-commit? (margin +200 MiB) | VOID / SUPERSEDED | Interrupted twice, no results; loaded free 510 / 488 MiB (P107: 318). Superseded: the 4070 measured ~446 MiB sparse-only at 160k, ~780 at 245k |
| [P109b](P109.md#p109b-the-over-commit-cause-on-the-old-build-margin-1025-void-infeasible) | 2026-10-13 18:44-18:49 | The over-commit cause on the old build (028f606fc), margin 1025 | VOID (infeasible) | Did not start: "Tiered KV: only 3328 cells fit in VRAM" at idle 217 MiB; not rerun (P107 trace, the 4070's sizes and P111 already show the cause) |
| [P110](P110.md) | 2026-10-13 10:57-11:05 | Post-move smoke on bundle-20261010 | FAIL as written; no change from the move | 52.9 / 45.9 / 37.6 at 4k / 32k / 64k; 32k -10.5 % vs P96 (single-run reference), within 1 % of P85 / P88; 67 C max; PCIe 3 x16; min free 100 MiB |
| [P111](P111.md) | 2026-10-13 12:14-13:59 | P107 on the sparse memory fix (3299a0b4b = 8d5b862fc path), margin 475 | PASS | 245k sparse 11.6 vs dense 5.2 (2.23x), 160k 14.8 vs 8.9 (1.66x), OP_TIMING on; mat-vec 0.89x dense; follow-ups 105.1 / 103.2; min free 106 MiB |
| [P112](P112.md) | 2026-10-13 13:59-14:35 | Sparse depth threshold GGML_CUDA_FA_SPARSE_MIN_HOST=32768 | PARTIAL (160k PASS, 64k FAIL) | 160k 19.6 vs 9.1 (2.15x, clean); 64k 23.0 vs 28.8 (-20 %) with no sparse op run; margin 475 costs line 46,592 -> 34,560 |
| [P113](P113.md) | 2026-10-13 14:35-15:16 | Release check of bundle-20261011 (patch 0053) | PASS | sha match; tests pass; 53.9 / 47.9 / 38.0 / 27.9 / 16.9 (4k-128k); fresh 60k 38.3 / 38.2; 0 one-token; trace min 68 MiB |
| [P114](P114.md) | 2026-10-13 15:16-16:57 | The q3_0 KV type at depth on 8 GB (bin-q3kv, 262k test launcher) | PASS | Line 82,176 vs 62,720 (1.31x); decode 128k 15.6 vs 12.7 (+23 %), 192k 9.4 vs 8.2 (+15 %), 64k -6.5 %, 4k -0.9 %; 160k copies 10/10, needles 12/12; min free 97 / 67 MiB |
| [P115](P115.md) | 2026-10-13 17:08-18:26 | Isolate the 64k FA_SPARSE cost; clean 245k sparse speed | PASS (reading) | 245k sparse 14.2 vs dense 5.3 (2.68x, no op timing); 64k never-sparse 22.8 vs 28.7 (-20.6 %) with 0 sparse ops = always-on cost (later: no prefetch below MIN_HOST, fixed in 3ab0af3c2) |

## Plans of the open experiments

None left in this range: P109b ran (VOID, infeasible), P114 and P115 ran (PASS). Open experiments from P119 on are in
`index-p116-p132.md`.
