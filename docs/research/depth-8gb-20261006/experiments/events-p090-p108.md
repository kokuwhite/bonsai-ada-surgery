# Events, 2026-10-10 to 2026-10-11 (range p090-p108)

Notebook entries in this range that are not experiments: PRs, releases, issue threads, design notes, research,
corrections, cleanups and TODOs. Source: `C:\bonsai\8gb\DECISIONS.md` (NOTEBOOK.md here) from the entry "2026-10-10
P86b, P89b, P90b (results) and P89c / P90c (plans)" to the end. Times with "Z" are UTC as written in the notebook;
queue times are rig local time (UTC-5). Experiment results in the same entries are in the P files (P80b/c, P86b, P87,
P89b/c belong to the earlier range).

- [E1 PR #18: launcher RAM budget (issue #16)](#e1-pr-18-launcher-ram-budget-issue-16)
- [E2 PR #19: chunked prefill for 8 GB](#e2-pr-19-chunked-prefill-for-8-gb)
- [E3 bundle-20261010 published](#e3-bundle-20261010-published)
- [E4 Depth decode: two candidate designs (for Cary)](#e4-depth-decode-two-candidate-designs-for-cary)
- [E5 PrismML #330 / #346: crash after a long prompt on another engine](#e5-prismml-330--346-crash-after-a-long-prompt-on-another-engine)
- [E6 PR #20: docs/8GB "Sessions that stay deep"](#e6-pr-20-docs8gb-sessions-that-stay-deep)
- [E7 Correction: sparse host-tail reads look viable; issue #21 opened](#e7-correction-sparse-host-tail-reads-look-viable-issue-21-opened)
- [E8 Issue #21 thread: the 4070 sparse builds](#e8-issue-21-thread-the-4070-sparse-builds)
- [E9 Issue #22: tier-graphs and patch 0053](#e9-issue-22-tier-graphs-and-patch-0053)
- [E10 Cary: all three depth levers + outside research; q3_0 KV type started](#e10-cary-all-three-depth-levers--outside-research-q3_0-kv-type-started)
- [E11 Research (agent): Strata and offloaded-KV decode methods, ranked](#e11-research-agent-strata-and-offloaded-kv-decode-methods-ranked)
- [E12 2026-10-11 cleanup and queue additions](#e12-2026-10-11-cleanup-and-queue-additions)
- [E13 TODO: the "8 GB, one week" before/after card](#e13-todo-the-8-gb-one-week-beforeafter-card)
- [E14 4070 docs PRs #24 and #25](#e14-4070-docs-prs-24-and-25)
- [E15 PR #26: DEPTH.md 8 GB sparse correction](#e15-pr-26-depthmd-8-gb-sparse-correction)
- [E16 PR #29: research/ and receipts/ moved under docs/](#e16-pr-29-research-and-receipts-moved-under-docs)
- [E17 Lessons recorded in this range](#e17-lessons-recorded-in-this-range)

## E1 PR #18: launcher RAM budget (issue #16)

| | |
| --- | --- |
| Date | 2026-10-10: opened after P90d (entry "P87, P90d, P89c (results); PR #18 (issue #16)"); v3 pushed after P90e; merged 13:36Z |
| What | PR #18 (branch ram-budget, 27c34a4 on main 1904624): the launcher sizes the server's prompt cache and context checkpoints from system RAM / free commit. Adds receipts/ram_8gb/ and bench/commit_ballast.py |
| Cause | Issue #16 (howdya: RTX 3060 Ti 8 GB, 16 GB RAM): bad_alloc and server death in long thinking runs. P90b measured +8.7 GB of commit with server defaults |
| Steps | v1 (P90c: cache 60 %, free commit fell to 682 MiB) -> v2 (P90d: checkpoints first 40 %, cache half of the rest, 0 below 1536 MiB; PASS) -> v3 = RAM tiers (P90e: >= 48 GB defaults, 24-47 GB cache 4096 / 32 checkpoints, < 24 GB from free commit), pushed as 2bae2f5. "PR #18 updated; merge after the 4070 ack." |
| Outcome | "PR #18 merged by the 4070 session (13:36Z); issue #16 closed. Needs a bundle for users (launcher change only)." Answered #16 (after P90d). Shipped in bundle-20261010 (E3) |
| Links | P090; issue #16; split with the 4070 (2026-10-09): the 2060 rig owns the launcher RAM-budget PR, the 4070 adds 12 GB numbers |

## E2 PR #19: chunked prefill for 8 GB

| | |
| --- | --- |
| Date | 2026-10-10: opened after P89c (same entry as E1); merged by the 4070 14:03Z |
| What | PR #19 (fa-chunk-8gb, 4d95fbc): patches 0051-0052 chunked prefill attention + launcher GGML_CUDA_FA_CHUNK=32768 on 8 GB + docs table + receipts/chunked_prefill. Patch numbers: "0050 = concat (fork df5559e065); 0051-0052 stay" (0050 is the 4070's concat patch) |
| Review | 4070 queued the Ada check: "sm_89 tests off/256/768; 12 GB 262k q8_0 sweep to 250k chunk off/on; texts at 64k and 160k; fresh 20k-100k 1-token" |
| Outcome | "PR #19 merged by the 4070 (14:03Z): Ada prefill +12-14 % at depth; 12 GB keeps chunk off (160k shlex quote differed with chunk on); bundle planned with 0050-0052 + #18." Then on #19: "Posted P91/P92 (d0 plain texts change with the switch on although no op should chunk at d0); P93 investigating before the bundle." After P93: "Posted on #19: bundle can go." |
| Links | P091, P092, P093, P094; the P89 series (earlier range) |

## E3 bundle-20261010 published

| | |
| --- | --- |
| Date | 2026-10-10 (entry "bundle-20261010 published (4070): 0050-0052 + #18; P96 (plan, queue 59z) release check on the 2060") |
| What | Published by the 4070 session: patches 0050 (concat), 0051-0052 (chunked prefill) and PR #18 (RAM budget). Zip sha256 2f3b6544...6da6c (full: 2f3b6544ab2e8cd02bf9a2a16e246ebbdeb66987ce4a14891f0a153c3e46da6c, 609,453,871 bytes) |
| Note from the 4070 | "the 160k shlex quote is a near-tie the chunk tips, and the chunked answer is the exact copy of the source (unchunked adds a blank line)" |
| Checks | P96 release check on the 2060: PASS. P99 deep session on the same zip: PASS |
| Public | README "Upgrading from an older bundle": bundle-20261010 sizes system RAM use from the machine and makes 8 GB prefill at depth faster |

## E4 Depth decode: two candidate designs (for Cary)

| | |
| --- | --- |
| Date | 2026-10-10, after the P97 result |
| Context | P95 / P97 closed the CPU attention route. The depth levers left (P97 entry): "(1) approximate block-sparse attention for the host rows (Cary's call); (2) more verified tokens per host read (tail 2 = +17 % at 200k, -10 % at 64k; lookup for copy-heavy work); (3) fewer bits per host row (custom KV type: ~1.3-1.5x, quality cost)" |

Design A, K-first, bounded (near-exact): for the host rows only, pass 1 reads K (576 of the 1,152 B per cell),
computes the scores, the row max and the softmax sum per head; pass 2 reads V only for rows whose normalized weight
can matter, chosen so the dropped softmax mass is <= eps (e.g. 1e-4) per head. The dropped mass is known exactly
after pass 1, so the error has a hard bound, and eps = 0 is exact. Union of rows over the 6 heads x nb tokens of a KV
head. Merge with the VRAM part as in patch 0051. Bytes per step at 250k: 50 % (K) + the V fraction (expected a few
%): ~1.7-1.9x decode at depth. Work: two CUDA kernels on the tiered alias + the merge; gates: KLD vs exact at
128k/250k, texts.

Design B, block-sparse top-k (approximate, Quest-like): per 128-cell block of the host rows keep a key summary in
VRAM (~50 MB); per step score blocks, fetch the top 10-20 % of blocks. 5-10x fewer bytes: decode at 250k could
approach the 64k speed. Error not bounded; gates: KLD, needle-in-a-haystack at 64k-250k, a long-context task set;
opt-in.

Decision written: "A first (exact by construction with eps=0, and the eps knob shows how much B could ever gain), B
only if Cary wants it." Then "P98 (started): K-first stats probe (agent; worktree prism-kfirst, branch kfirst-probe on
d0c1d8644; build-only)" with the decision rule "if 1e-4 needs <= 10 % of host V rows at 192k+, build design A".

What happened: P98 / P98b dropped both designs (attention mass is diffuse). The same day E7 brought design B back
with an output-based measurement. The sparse branch (fa-sparse-proto) is design B with 64-cell pages.

## E5 PrismML #330 / #346: crash after a long prompt on another engine

| | |
| --- | --- |
| Date | 2026-10-10 (after the design entry; #330 reply 16:18Z) |
| What | PrismML #330: Powerful-Plantain reports a CUDA illegal memory access in launch_fattn after a 30,180-token prompt (Linux, 64k slot, no GPU/flags given). We asked for GPU, commit, command line, env (FA_PREFILL_F16), a CUDA_LAUNCH_BLOCKING=1 run and an f16-path-off run. Reply 16:18Z: "quoted the questions, same log, no new data. Waiting for real details; no further post." |
| Moved | PrismML #346 (moved from #330): RTX 3070 Laptop 8 GB, b10770 (6684606ac) crashes after a 30k/45k prompt (illegal access before an FA launch), b10709 good, --ctx-checkpoints 0 avoids it; "not our PR (no FA_PREFILL_F16 in that tree)". In b10709..b10770 the one checkpoint commit is bf197c43d "server: reuse the buffers of evicted prompt checkpoints (#312)" - posted as the first candidate |
| Our engine | "Our engine base predates b10709: not affected." |
| Standing rule | "WATCH: when we rebase on a newer PrismML, check this before shipping (checkpoints are on in both our recipes)." Public: docs mention "PrismML #346 not affecting this engine" (commit 5a2ee8e on main) |

## E6 PR #20: docs/8GB "Sessions that stay deep"

| | |
| --- | --- |
| Date | 2026-10-10, after P98b |
| What | "PR #20 merged: docs/8GB "Sessions that stay deep" (tail 2 data, CPU attention and sparse reads measured, not used) + receipts/depth_8gb." receipts/depth_8gb holds cpuattn_bench.cpp, p80c_tail2_summary.txt, p95_cpu_fa_perf.txt, p98_filler_kfirst.txt, p98b_realtext_kfirst.txt |
| Later | The "sparse reads ... not used" statement was corrected after E7 (docs/8GB.md now: "the output is much less sensitive than the mass"; commit 712032d on main "corrects the earlier 'cannot cut' note") |

## E7 Correction: sparse host-tail reads look viable; issue #21 opened

| | |
| --- | --- |
| Date | 2026-10-10, after P99 (entry "Correction: sparse host-tail reads look viable (4070 measurement, a97f56a73)") |
| What happened | The 4070 emulated GGML_CUDA_FA_SPARSE (per query, B host cells in pages of 64 + last 1024). KL vs dense at a 16k window (host tail 6-14k): B=8192 0.0030 (same top 97.7 %), 4096 0.0081, 2048 0.0160; needles at 160k 12/12 (dense, 8192, 4096); exact Python copies at 160k 10/10 (dense, 8192), 8/10 (4096) |
| Wrong conclusion corrected | "My P98/P98b mass criterion was the wrong one: the output is much less sensitive than the mass. Design B is back." |
| Open | "the budget at real depth (host tail 130-190k cells on this card)" |
| Action | "Opened a coordination issue: engine on the 4070, depth tests on the 2060 (PPL at 64k dense vs sparse, needles / copies at 200k-250k, P99-style session with sparse on); asked for the emulation branch." This is issue #21. Led to P101-P107 |

## E8 Issue #21 thread: the 4070 sparse builds

Each line is a 4070 post on #21 recorded in the notebook, with what the 2060 did with it.

| Time | 4070 post (notebook text) | 2060 action |
| --- | --- | --- |
| 2026-10-10 23:49Z | "verify batches > 8 queries leave the fast path and run on the MMA kernel without tile skip -> full host read. Local (not pushed): device page selection, bounds follow K-cache writes (CHECK mode). Next: fast path to 64 queries, MMA tile skip, WARN engage line. P102 stays the right test for 87e2ac160." | P102 kept; P102b planned on c084831aa |
| (with P102b plan) | "4070 dense as shipped with lookup on: 19.7 tok/s at 192k, 12.7 at 250k (PCIe 4.0)" | scale for P102b |
| 2026-10-11 00:08Z | "sparse_edit at 160k on fa-sparse-proto 71371d4cb: write tracking -> 0 stale-bound ops, 0 selection diffs; without it 208 stale ops after a deep edit and a changed answer." | (docs/DEPTH.md correctness table) |
| ~20:36 local, 10-10 | c084831aa "still syncs per K write" | P102b stopped |
| (with P102c plan) | "4070 on 71371d4cb: lookup off 192k dense 22.8 vs sparse 21.5; lookup on sparse 14.4 vs dense 19.7." | P102c on ae61c4cf3 |
| after P102c | - | "Posted on #21; offered BONSAI_SPEC=0 and KV_TIER_REDIRECT=0 isolation arms" (P102d) |
| (Strata research) | - | "Posted the kernel-relevant points on #21" (E11) |
| 2026-10-11 04:52Z | "fa-sparse-proto f6f2d146c GGML_CUDA_FA_V_SKIP=1 (vec decode skips V rows of a warp with all weights < exp(-20) of the running max; near exact) + bench vskip_ab.sh. Not in P102e (built on c803e03ea); a later speed arm." | not run on the 2060 in this range (docs/DEPTH.md: 4070 V skip 19.7 -> 19.7 at 192k) |
| 2026-10-11 06:14Z | "RTX 4070 160k, line 32,768 (~127k host): dense 13.6 tok/s; sparse decode without tile map 9.1; sparse decode+prefill with tile map 29.6 (2.2x; quality drop from sparse prefill -> prefill stays dense). Build for P102e: d6c6e9f01 (64-cell tile-map entries, sparse ops always use the MMA tile map, includes 2f47c38b7). Rebuild timed inside P103 new_lkoff prefill." | P102e on d6c6e9f01 |
| after P102e | - | "Posted on #21 with options (64-cell vec skip, or MMA for >= 2q)" |
| 2026-10-11 08:18Z | candidate d6c6e9f01: "160k, line 32,768 (~127k host), prefill dense, decode sparse B=8192: dense 13.6 tok/s 10/10 12/12; page 256 31.1 tok/s 9/10 12/12 (misses _div_nearest twice); page 64 27.6 tok/s (code item 31.7) 10/10 12/12. FLASH_ATTN_EXT 3007/3007." The 4070 called the 2060 test "P104" | P105 (renamed) |
| 2026-10-11 12:32Z | "028f606fc: the vec kernel skips a warp's 32 cells when all are masked (2-query decode at page 64). Prefill halving: not seen on the 4070 (296 vs 284 at 160k); 8 GB-specific." | P106 |
| after P104 | - | P104 result "Posted on #21" |

## E9 Issue #22: tier-graphs and patch 0053

| | |
| --- | --- |
| Date | 2026-10-10 (P103 plan) to 2026-10-11 07:15Z and after P103b |
| What | 4070: "CUDA graphs on (shipped) keep the tier prefetch pipeline off; graphs off at 192k on 12 GB: 19.8 -> 25.0 tok/s." Fork tier-graphs 4715804d6 turns graphs off only for graphs whose attention reads the host tail |
| 07:15Z | "switch line now WARN in release candidate 90ca41e40 (patch 0053); 4070 tier-graphs 192k 23.6->29.4, 250k 12.7->14.6; 4k/32k unchanged there. The bundle waits for P103b." |
| Close | After P103b: "Tier-graphs gate PASS on 8 GB; posted on #22 (bundle can ship)." |
| Public | docs/DEPTH.md "CUDA graphs and the tier prefetch (shipped, patch 0053)" with both cards' numbers |
| Links | P103 |

## E10 Cary: all three depth levers + outside research; q3_0 KV type started

| | |
| --- | --- |
| Date | 2026-10-10 evening (in the P103 plan entry) |
| Decision (Cary) | "go on all three depth levers (sync fix, verify-batch page skip, 3-bit KV) and research outside work ("strata" and other recipes) for hidden gems." |
| Actions | "Research agent started (offloaded-KV decode methods, low-bit KV, hybrid-model tricks, sparse-draft speculative decoding)." (E11) |
| q3_0 | "q3_0 KV type (Cary approved): agent implementing in worktree prism-q3kv (branch kv-q3-0 on 2cadbfb64): 14-byte blocks of 32 (3.5 bpw), set_rows, vec FA K/V, f16/chunk conversion, CPU ref, tests, -ctk/-ctv q3_0. GPU tests after P102d/P103." |
| Later | The agent's compile ran during P103 and was stopped in the cleanup (E12); WIP 6a4851286; built during P104; tested in P108 |
| Links | P100, P104, P108 |

## E11 Research (agent): Strata and offloaded-KV decode methods, ranked

| | |
| --- | --- |
| Date | 2026-10-10 (entry "Research (agent): Strata + offloaded-KV decode methods - ranked for our setup") |
| Asked by | Cary (E10) |

Strata (arXiv 2508.18572, OSDI '26) = hierarchical prompt-KV caching (GPU / CPU / SSD) for time-to-first-token in
multi-tenant serving. Fit: low for single-stream decode. Lesson taken: page-contiguous host layout.

Ranked levers for our setup (rank, method, reasoning as recorded):

| rank | method | notebook note |
| --- | --- | --- |
| 1 | One page set per KV group and per verify batch (PulseInfer SoloHead, 4.7x) | host read ~3.5 GB -> ~150 MB per step at B=8192 |
| 2 | TriForce / MagicDec: sparse self-draft + dense verify | exact; costly on 8 GB: 150 MiB rollback plane per extra draft -> serve sparse, dense for exact modes |
| 3 | Calibrated streaming vs retrieval heads (DuoAttention) | became P104 |
| 4 | Prefetch selected pages during the 3 GDN layers between attention layers + a VRAM page pool (InfiniGen / OmniKV / ArkVale) | 4070 kernel work |
| 5 | 3-bit KV | q3_0 in work (E10, P108) |

Skipped, with reasons: CPU attention (P97); eviction (lossy); ShadowKV (~1 GB VRAM).

Byte check: 192k x 18,432 B = 3.5 GB per step; 320 ms at 11 GB/s; / 1.8 tokens per step = 5.6 tok/s (measured 5.7).
"Posted the kernel-relevant points on #21."

What happened to each item (E12 and later): (1) and (4) = 4070 kernel work, posted on #21, "tested here as builds
land"; (2) "sparse as served default: P99-style session with sparse on once speed is good" (not run in this range);
(3) P104: no streaming heads, closed; (5) q3_0 built during P104, P108 queued.

## E12 2026-10-11 cleanup and queue additions

| | |
| --- | --- |
| Date | 2026-10-11 (early morning; entry "Cleanup (Cary: rig bogged; run only what is needed) and queue additions (Cary: add the valuable research items)") |
| Cause | Cary: the rig was bogged down. The q3_0 agent's -j 4 compile ran during P103's speed run |
| Stopped | "the q3_0 agent (its -j 4 compile ran during P103's speed run), a stray python/bash from an earlier compare, the agent's tail/wait loops." q3_0 work saved as WIP commit 6a4851286 (46 files, not built) |
| Kept | queue runner, P103, one watcher, result waiters (sleep loops) |
| Queue additions | (1) shared page set per group / verify batch and (4) prefetch during the GDN layers = 4070 kernel work (posted on #21; tested here as builds land: P102e next). (2) sparse as served default: P99-style session with sparse on once speed is good. (3) streaming vs retrieval heads: P104 (queue 70) = probe 0e0dc757a with per-KV-head union fractions on ~230k tokens of real code, ranked list of the 64 KV heads. (5) q3_0: built in the background during P104 (a stats run, CPU load does not matter there); then GPU tests |
| Effect | P103's run may carry compile noise; P103b re-checked the shallow depths |

## E13 TODO: the "8 GB, one week" before/after card

| | |
| --- | --- |
| Date | 2026-10-11 (entry "TODO (Cary): the "8 GB, one week" before/after card - when sparse / tier-graphs / q3_0 land") |
| What | "A gorgeous card (style of docs/img/launch.png / card8gb.png) with ALL upgrades since the mission start (2026-10-06)." |
| Before (receipts) | community 8 GB recipe (64k window, all-VRAM, no head) decode 37.2 / 30.4 / 24.5 / 17.5 tok/s at 4k / 16k / 32k / 60k, prefill 427 / 382 / 320 / 256 (docs/8GB.md); our stock record P2 (N 16,384 q8_0): 37 tok/s at 4k, 13.5 at 32k, 3.0 at 120k; no drafting, no lookup, no in-message checkpoints, 1-token answers (pool race), 16 GB RAM crashed (#16) |
| After | "fill from the shipped bundle's release check at the time (window, decode by depth, prefill at depth, P99-style session, lookup x, checkpoints x, HumanEval, RAM tiers, tier-graphs, sparse, q3_0)" |
| Status | Open (waits for sparse / tier-graphs / q3_0 to ship) |

## E14 4070 docs PRs #24 and #25

| | |
| --- | --- |
| Date | 2026-10-11 (end of the TODO entry) |
| What | "#24 (tier prefetch / patch 0053 docs; 8 GB numbers checked: correct) and #25 (docs/DEPTH.md; 8 GB sparse part outdated -> review with P105/P106 rows, status line correction posted)." |
| Outcome | #25 merged before the review comment landed (E15) |

## E15 PR #26: DEPTH.md 8 GB sparse correction

| | |
| --- | --- |
| Date | 2026-10-11 10:22 (entry title); merged 15:21:53Z |
| Cause | "#25 (4070, DEPTH.md) merged seconds before my review comment, so main still said "not yet faster on a real 8 GB card"." |
| What | #26 adds "the P105 quality rows (160k 12/12, 10/10; 245k 12/12, 9/10), a 64k/160k/245k dense-vs-sparse table by build (P105/P106), the three open items (245k below dense, follow-up prefill -20/-45 %, -16 % at 64k), the tail-4 note and the corrected status line." Docs only. Main commit 80aabb4 ("docs/DEPTH: the RTX 2060 SUPER sparse results (P105, P106) ... (#26)") |
| After | "Watcher restarted. P104 running (q3_0 build OK, try 1; calibration prefill in progress). Queue after it: P107, P108." |
| Cross-check | docs/DEPTH.md on main matches P102e / P105 / P106 receipts: 64k 34.5 / 29.0; 160k 9.7 / 18.3 (d6c6e9f01) and 18.5 (028f606fc); 245k 5.7 / 4.3 (d6c6e9f01) and 4.9 (028f606fc); follow-up 160k 107 -> 85, 245k 79 -> 39-44 (P102e 38.9, P106 44.5); MTP tail 4 46,592 -> 20,992 cells, acceptance 0.79 -> 0.55, 160k dense 9.1 / sparse 11.5 |

## E16 PR #29: research/ and receipts/ moved under docs/

| | |
| --- | --- |
| Date | 2026-10-11 "10:3x" (end of the P104 result entry) |
| What | "PR #29 (4070) moved research/ and receipts/ under docs/. The 8 GB research folder (research/depth-8gb-20261006, 5 writer agents running) moves to docs/research/ before its PR; D16 patch saved." |
| Effect on this record | Paths in this folder (research/depth-8gb-20261006/...) change to docs/research/depth-8gb-20261006/... when the folder moves |

## E17 Lessons recorded in this range

- P93: "compare texts only within one session window (same day, alternated arms), as P82/P89/P92/P93 did."
- P94: "Texts are stable for a fresh server with the same request history; compare only arms with the same history."
- E7: the softmax-mass criterion (P98/P98b) is the wrong one for sparse reads; judge by output (KL, needles, copies).
- P103: log lines at INFO level do not reach the server log; engage lines must be WARN (sparse and tier-graphs).
- P102d: on 8 GB the 262k window needs drafting mode; a no-draft arm gets the 131k window (HTTP 400 at 245k).
- E5: when rebasing on a newer PrismML, check bf197c43d (checkpoint buffer reuse) before shipping.
