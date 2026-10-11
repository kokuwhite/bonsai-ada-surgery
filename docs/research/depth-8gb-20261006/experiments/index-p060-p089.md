# Index, P60 to P89

Events (PRs, merges, decisions, check-ins, fillers, incidents) for this range: `events-p060-p089.md`.

| ID | date | title | status | one-line result |
| --- | --- | --- | --- | --- |
| [P060](P060.md) | 2026-10-08 | Patch 0043 candidate (f16 prefill for >= 64 queries) on Turing | FAIL (neutral) | Prefill same (345.2 vs 344.5-344.8), lookup quote decode 125.7 vs 124.1 at d0: no gain on Turing; no objection to 0043 for Ada |
| [P061](P061.md) | 2026-10-08 | Min-Q data for #330 at 30k / 60k; 1-token answers found | PARTIAL | Prefill equal (345.4 / 344.1 at 30k, 255.0 / 254.4 at 60k), but every fresh 60k request answered 1 token in both engines |
| [P062](P062.md) | 2026-10-08 | 126k row on 8a6d2ea12 | PASS (reading) | Decode 51.4 / 45.9 / 30.2 / 17.7 / 14.1 at 4k-126k; 126k prefill 111.6 (P40c 11.3 / 105) |
| [P063](P063.md) | 2026-10-08 | Patch 0042 check: 107 tools at depth 20000 | PARTIAL | 2 tools 43.8 tok/s, 107 tools 34.8 tok/s (46,878-token prompt); depth confounded |
| [P064](P064.md) | 2026-10-08 | Bisect 1-token answers: f16 x lookup x pool | PASS (cause found) | All pool-on arms 3/3 one-token, pool off 0/3: shared CUDA pool is the cause -> hotfix PR #10 |
| [P065](P065.md) | 2026-10-08 | Isolate the bug: no MTP / pre-0041 / window 64k / long mode | VOID | Launcher copy lost the pool mid-run; all arms 0/3, consistent with "pool off passes" only |
| [P066](P066.md) | 2026-10-08 | Hotfix PR #10 verify | PASS | 0 one-token at fresh 30k/60k/120k and 0/11 at 30k; prefill 344/254/172; min free 133-145 MiB |
| [P067](P067.md) | 2026-10-08 | Narrow the pool bug: graphs off, draft ubatch, pre-0041, control, logprobs | PARTIAL | Graphs off still fails; pool-on control passed 0/3 (intermittent); bad token = end-of-turn at 75 % (wrong state) |
| [P068](P068.md) | 2026-10-08 | Poolsync candidate 142d5105d, pool on | PASS | 0/9 fresh 60k one-token, 0/11 at 30k; decode 31.6 (pool-on 31.3, pool-off 29.1) |
| [P069](P069.md) | 2026-10-08 | Poolsync vs 8a6d2ea12, alternated x6 | PASS | Poolsync 0/18, 8a6d2ea12 18/18 one-token -> fix works (patch 0045) |
| [P070](P070.md) | 2026-10-08 | Clean min-Q set for #330, pool off | PASS (data) | 0/66 one-token, texts identical; min-Q neutral on Turing (prefill 30k 339.4 vs 343.0, 60k 253.5 vs 253.3) |
| [P071](P071.md) | 2026-10-08/09 | Deep checkpoint restore: 4 isolation arms | PASS | --checkpoint-every-nt correct (texts = N=0 reference); P59 wrong output was the pool race -> PR #11 |
| [P072](P072.md) | 2026-10-08/09 | Release check bundle-20261008-8gbfix (P72 void, P72b) | PASS (P72b) | P72 failed to extract the zip; P72b: tests pass, 0/32 one-token, decode 51.5 / 46.4 / 30.4, long 43.7 / 34.1 |
| [P073](P073.md) | 2026-10-09 | PR #11 end to end (launcher sets 8192) | PASS | 64k wall after first 60.5 s vs 227.0 s; 11/11 same text; working set 7333 vs 6834 MiB |
| [P074](P074.md) | 2026-10-09 | Does plain decode evaluate 2 tokens per step? | SUPERSEDED (cancelled) | The <2,4> census was the warmup graph; decode is 1-column; lead moved to gate+up fusion (P76) |
| [P075](P075.md) | 2026-10-09 | 262k window as served today | FAIL | VRAM line 41,472; decode 51.9 / 24.1 / 9.9 / 6.9 / 4.9 (4k-250k); free VRAM below zero at depth |
| [P076](P076.md) | 2026-10-09 | Gate+up+GLU fusion in all 64 FFNs | REJECTED (correct, +0.2 %) | 64/64 gate-fused, texts identical, 4k decode 44.0 vs 43.9; not shipped (stop micro-fusions) |
| [P077](P077.md) | 2026-10-09 | Tier staging off | FAIL | Window cost gone, decode +26 % at 64k (more N), but prefill -60 / -70 % at 96k / 128k and 262k over-commits (f16 mask) |
| [P078](P078.md) | 2026-10-09 | Turing launch-shape tuning and GRAPH_OPT | FAIL | Best 4x2 only +0.6 % (n=1) / +0.3 % (n=2); mat-vec at 80 % of peak bandwidth; GRAPH_OPT=1 slower (40.5 / 36.4 vs 43.0 / 42.7) |
| [P079](P079.md) | 2026-10-09 | Release check bundle-20261009-ckpt (+ P79c 4k recheck) | PASS | Checkpoints as shipped (59.7 s); 4k -6 % reading was noise (P79c: release 52.1 / 51.8 vs local 52.1 / 52.1) |
| [P080](P080.md) | 2026-10-09/10 | Tail draft 2 vs 1 at ~200k (P80 void, P80b partial, P80c) | PASS (data; default unchanged) | Tail 2 -10 % at 64k, +17 % at 200k (8.8 vs 7.5); tail 1 stays default, tail 2 documented for deep sessions |
| [P081](P081.md) | 2026-10-09 | Partial staging + mask-aware launcher | PASS (mechanism) / FAIL (default) | 262k without over-commit, prefill = 131k to N+S; D decode -12 % at 64k vs A (mask cost); staging = in-place for decode on Turing |
| [P082](P082.md) | 2026-10-09 | Packed KQ mask with MTP drafting | PROMOTED | Texts 22/22 identical; load free +108 MiB at 131k; P22b/P24 corruption was old races |
| [P083](P083.md) | 2026-10-09 | Shared pool on 8 GB with patch 0045 | PROMOTED | N +2,048: decode +7 % at 64k, +4 % at 96k; 0 one-token in fresh 60k x3; trace min 131 MiB |
| [P084](P084.md) | 2026-10-09 | Packed mask + pool + partial staging together | PROMOTED | 262k at N 59,904 beats 131k preset: 64k 37.8 vs 30.5, 128k 14.2 vs 13.0; fresh 60k 37.3 vs 28.2 -> 262k default (PR #13) |
| [P085](P085.md) | 2026-10-09 | The 262k launcher as users get it | PASS | Auto N 58,880; decode 50.8 / 45.8 / 37.5 / 20.0 / 14.1 (within 1.7 % of P84); 0 one-token; trace min 110-116 MiB |
| [P086](P086.md) | 2026-10-09/10 | End of the 262k window (P86, P86b) | PARTIAL / PASS | Stable to 250k; decode 11.2 / 8.1 / 5.7 at 128k / 192k / 250k; bulk prefill past N+S 58 / 25.4 tok/s (slow) |
| [P087](P087.md) | 2026-10-10 | HumanEval on the 262k launcher | PASS | 158/164 (96.34 %), same 6 failures as P53 |
| [P088](P088.md) | 2026-10-09 | Release check bundle-20261009-vram | PASS | Decode 51.1 / 46.2 / 37.5 / 20.0 / 14.1, texts 22/22 = P85, trace min 86 MiB |
| [P089](P089.md) | 2026-10-09/10 | Chunked flash attention for prefill (P89, P89b, P89c) | PROMOTED (patches 0051-0052, PR #19) | Code prefill 171 / 116 / 90 at 128k / 192k / 250k (vs 121 / 58 / 25.4); texts 8/11 (merge rounding); PPL 7.2074 vs 7.2107 / 7.2106 |
