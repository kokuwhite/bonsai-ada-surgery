# Index, P090 to P108

Run times are rig local time from receipts/queue.log. Events (PRs, releases, issue threads, designs, research,
cleanup) are in `events-p090-p108.md`.

| ID | date | title | status | one-line result |
| --- | --- | --- | --- | --- |
| [P090](P090.md) | 2026-10-09 plan; 10-10 00:04-07:18 | System RAM use of the 8 GB preset (issue #16) and the RAM-budget launcher (P90, P90b-e) | PROMOTED (PR #18, bundle-20261010); P90 VOID | Defaults: commit 9.6 -> 18.3 GB in 7 thinking requests (24.4k-token prompts); budget v2 on a 16 GB-like machine: 6 checkpoints, cache off, 7/7, peak 10.5 GB, min free commit 1,980 MiB |
| [P091](P091.md) | 2026-10-10 07:18-07:57 | The PR #19 launcher as users get it (chunk on for 8 GB) | PARTIAL | Decode 52.3 / 52.7 / 36.0 / 20.5 / 14.3 (4k-128k), 0 one-token, trace min 105-139 MiB; depth-0 texts 8/11 vs P85 (later shown not to be the switch) |
| [P092](P092.md) | 2026-10-10 08:33-08:40 | Chunk switch off vs the engine without the chunk patch, depth 0 | PASS | pmask / chunk-off / pmask again: 11/11 identical each |
| [P093](P093.md) | 2026-10-10 08:57-09:06 | Chunk switch on vs off at depth 0, alternated x2 | PASS | 11/11 identical in all four arms; Oct 9 vs Oct 10 text groups differ in the 3 plain items only |
| [P094](P094.md) | 2026-10-10 09:09-09:16 | Does prompt-cache state change greedy texts? | PASS (answered) | Pass 2 differs from pass 1 in 3 plain items with the cache on and off: request history in one server, not the prompt cache |
| [P095](P095.md) | 2026-10-10 10:46-10:48 | CPU attention over the host tail, stock kernel | FAIL | CPU 278.0 ms per layer at 192k rows, 2 queries (gate <= ~12 ms; PCIe ~19 ms) |
| [P096](P096.md) | 2026-10-10 09:45-10:29 | Release check of bundle-20261010 on the 2060 SUPER | PASS | sha match; tests pass; decode 51.5 / 51.3 / 34.4 / 20.4 / 14.3 (4k-128k); 0 one-token; trace min 103 MiB; texts = P91 (22/22) |
| [P097](P097.md) | 2026-10-10 (by hand) | Dedicated AVX2 kernel for host-tail attention | FAIL | 9.5 ms per layer at 16,384 rows -> ~110 ms at 192k (gate <= 12 ms); CPU route dropped |
| [P098](P098.md) | 2026-10-10 11:25-12:35 | K-first statistics probe: how much of the host tail does attention need? (P98, P98b) | FAIL on the design rule; B conclusion SUPERSEDED (E7) | Attention mass is diffuse (<= 1e-4 needs 0.76-1.00 of host rows per layer on real text); designs A and B dropped, then B revived by the output-based 4070 test |
| [P099](P099.md) | 2026-10-10 12:52-13:54 | Deep agent session on bundle-20261010 to the end of the 262k window | PASS | 18/18 turns from 132,882 to 259,554 tokens, 0 one-token, VRAM min 115 MiB, private 12.2 -> 14.5 GB, decode 10.3 -> 5.4 tok/s |
| [P100](P100.md) | 2026-10-10 13:54-15:21 | Quality cost of a fake 3-bit / 2-bit KV format | PASS | PPL 64k: 4-bit 7.2074, 3-bit 7.2060 (-0.02 %), 2-bit 7.3417 (+1.86 %); 16k: +0.60 % / +3.64 % |
| [P101](P101.md) | 2026-10-10 15:21-18:39 | Sparse host-tail reads at 245k on 8 GB: quality | PASS (quality) | Dense, B=8192, B=16384: copies 10/10, needles 12/12 each; decode on code items 7.38 / 6.34 / 6.34 (lookup verifies off the fast path) |
| [P102](P102.md) | 2026-10-10 18:39 - 10-11 03:54 | Sparse decode speed at 245k, build by build (P102, P102b-e) | FAIL (speed); P102b VOID; P102d two arms VOID | Dense 5.7 tok/s; sparse 2.9 (87e2ac160), 2.6 (ae61c4cf3), 4.3 (d6c6e9f01, sync gone), 5.2 with SINKS (prefill 6.2) |
| [P103](P103.md) | 2026-10-10 23:11 - 10-11 04:06 | Tier-graphs on 8 GB (P103, P103b) | PROMOTED (patch 0053) | Decode +16 % at 128k, +9 % at 192k, +8 % at 245k, +12 % at 192k lookup off; 4k / 32k identical in alternated runs |
| [P104](P104.md) | 2026-10-11 10:06-10:32 | Streaming vs retrieval head calibration at ~196k | PASS (answered; item closed) | No streaming heads; focus differs by layer (L3-23 and L59-63 diffuse, L27-55 ~3x more focused); q3_0 build OK |
| [P105](P105.md) | 2026-10-11 04:06-08:35 | The #21 candidate d6c6e9f01: sparse quality and speed at 160k and 245k | PARTIAL | 160k: copies 10/10, needles 12/12, decode 9.7 -> 18.3 tok/s (1.9x); 245k: copies 9/10 (dense 10/10), needles 12/12, not faster; MTP tail 4 not a path on 8 GB |
| [P106](P106.md) | 2026-10-11 08:35-10:06 | 028f606fc vec warp skip; follow-up prefill diagnosis | PARTIAL | 160k 18.5 vs 9.7 (1.9x); 245k 4.9 vs 5.7; 64k 29.0 vs 34.5 (-16 %); follow-up prefill loss comes with FA_SPARSE set, not tracking |
| [P107](P107.md) | 2026-10-11 10:32-11:42 | Per-op timing at 245k, dense vs sparse | PASS (diagnosis) | Sparse FA -30 ms/graph (91.8 -> 61.5); mat-vecs 2.5-24x slower after a VRAM wrap at the first sparse decode step; test P109 |
| [P108](P108.md) | 2026-10-11 (queued) | First GPU tests of the q3_0 KV type | OPEN | Queued after P107 at the time of writing |
