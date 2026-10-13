# Index, P109 to P115

Run times are rig local time from receipts/queue.log. Events in this range (the stop for the move, the resume, the
4070's sparse allocation answer and the 8d5b862fc / 3299a0b4b builds, bundle-20261011) are in `events-p090-p108.md`,
sections E18-E22. P108 (q3_0 tests, run 2026-10-13) is in `index-p090-p108.md`.

| ID | date | title | status | one-line result |
| --- | --- | --- | --- | --- |
| [P109](P109.md) | 2026-10-11 11:42-11:50; 10-13 11:05-11:08 | Is the sparse 8 GB slowdown VRAM over-commit? (margin +200 MiB) | VOID / SUPERSEDED | Interrupted twice, no results; loaded free 510 / 488 MiB (P107: 318). Superseded: the 4070 measured ~446 MiB sparse-only at 160k, ~780 at 245k |
| P109b | queued 2026-10-13 (queue 69h) | The over-commit cause on the old build (028f606fc), margin 1025 | OPEN (plan only) | Gate (script header): trace min free > 0 for the whole arm AND MUL_MAT 17408x5120 <= 1.1x P107 dense (2.625 ms/graph) |
| [P110](P110.md) | 2026-10-13 10:57-11:05 | Post-move smoke on bundle-20261010 | FAIL as written; no change from the move | 52.9 / 45.9 / 37.6 at 4k / 32k / 64k; 32k -10.5 % vs P96 (single-run reference), within 1 % of P85 / P88; 67 C max; PCIe 3 x16; min free 100 MiB |
| [P111](P111.md) | 2026-10-13 12:14-13:59 | P107 on the sparse memory fix (3299a0b4b = 8d5b862fc path), margin 475 | PASS | 245k sparse 11.6 vs dense 5.2 (2.23x), 160k 14.8 vs 8.9 (1.66x), OP_TIMING on; mat-vec 0.89x dense; follow-ups 105.1 / 103.2; min free 106 MiB |
| [P112](P112.md) | 2026-10-13 13:59-14:35 | Sparse depth threshold GGML_CUDA_FA_SPARSE_MIN_HOST=32768 | PARTIAL (160k PASS, 64k FAIL) | 160k 19.6 vs 9.1 (2.15x, clean); 64k 23.0 vs 28.8 (-20 %) with no sparse op run; margin 475 costs line 46,592 -> 34,560 |
| [P113](P113.md) | 2026-10-13 14:35-15:16 | Release check of bundle-20261011 (patch 0053) | PASS | sha match; tests pass; 53.9 / 47.9 / 38.0 / 27.9 / 16.9 (4k-128k); fresh 60k 38.3 / 38.2; 0 one-token; trace min 68 MiB |
| P114 | running from 2026-10-13 15:16 (queue 69g4) | The q3_0 KV type at depth on 8 GB (bin-q3kv, 262k test launcher) | OPEN (plan only) | Gate (script header): q3_0 line >= 1.2x q4_0; decode >= 1.05x at 128k and 192k; 4k within 3 %; 0 one-token; min free >= 60; 160k needles 12/12, copies >= 9/10 |
| P115 | queued 2026-10-13 (queue 69g5) | Isolate the 64k FA_SPARSE cost; clean 245k sparse speed | OPEN (plan only) | Reading (script header): never64 >= 5 % below dense64 = always-on FA_SPARSE overhead; sparse245 vs dense245 reported (expect >= 2x) |

## Plans of the open experiments

P109b (scripts in the rig's queue/pending, 69h-p109b-sparse-oldbuild-m1025.sh). Arm: bin-sparse6 (028f606fc, the P107
build), BONSAI_VRAM_MARGIN=1025 (225 + ~800), sparse, 160k cold -> 245k, OP_TIMING, nvidia-smi trace every 10 s.
Header gate: "the cause is confirmed on the old build if trace min free > 0 for the whole arm AND MUL_MAT 17408x5120
<= 1.1x the dense time (P107 dense 2.625 ms/graph). If it still wraps or stays slow, the cause is something else (then
P111 alone is not proof either)."

P114 (queue/running, 69g4-p114-q3kv-depth.sh). Same binary (bin-q3kv, kv-q3-0 6a4851286), 262k test launcher with
'q3_0' { 14336 } in its CellBytes table, layer off, launcher defaults otherwise (lookup on, packed mask, pool). Arms:
speed_q4 (BONSAI_CTK=q4_0) and speed_q3 (BONSAI_CTK=q3_0), sweep 4k / 64k / 128k / 192k on one server; quality at 160k
with q3_0: exact code copies (10) and needles (12), fresh servers (as P105). Header gate: "q3_0 VRAM line >= 1.2x the
q4_0 line; decode q3_0 >= 1.05x q4_0 at 128k and 192k; 4k within 3 %; 0 one-token; trace min free >= 60 MiB; 160k
q3_0 needles 12/12 and copies >= 9/10 (P105 dense q4_0: 12/12, 10/10). Note: this engine has no patch 0053 and no
sparse; both arms share that."

P115 (queue/pending, 69g5-p115-sparse-overhead.sh). Same env as P111 / P112 (bin-sparse7 = 3299a0b4b, margin 475 ->
line 34,560, lookup off, f16 mask, graphs off). Arms, one server each: dense64 (64k); never64 (64k, FA_SPARSE=8192,64,1024
+ MIN_HOST=1000000000: sparse never runs); sparse245 (245k cold, FA_SPARSE + MIN_HOST=32768, no OP_TIMING); dense245
(245k cold, no OP_TIMING). Header: "if never64 is >= 5 % below dense64, the 64k cost is an always-on overhead of
FA_SPARSE (engine fix on the 4070), not sparse selection. sparse245 vs dense245: report (expect >= 2x)."
