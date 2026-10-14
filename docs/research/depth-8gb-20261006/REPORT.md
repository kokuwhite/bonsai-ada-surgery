# 8 GB research: report (2026-10-06 to 2026-10-14, ongoing)

All runs on one RTX 2060 SUPER 8 GB (Turing, PCIe 3.0, desktop on the card), unattended from a job queue. Each
experiment has a plan and a gate written in `NOTEBOOK.md` before its result, and one record in `experiments/`.
On 2026-10-11 four writers re-read every notebook entry against its receipts to make the records. They found about 60
places where the notebook and the receipts disagree. Each one is in its record, and the notebook has correction
entries for them (end of `NOTEBOOK.md`). Where a correction changes a reading, this report uses the corrected value.

## Bottom line

Mission goal (Cary): beat the community 8 GB recipe (sudoingX's floor) on this card, 60+ tok/s, quality and stability
to the end of the window, and make the full 262k window the worthwhile default on 8 GB.

| | Start (2026-10-06) | Shipped now (`bundle-20261013` = `bundle-20261011` + patch 0054; on Turing 0054 changes nothing, P116 / P126b) |
| --- | --- | --- |
| Window | 64k (community recipe, all in VRAM); 120k stock tiered at 3.0 tok/s (P2) | **262,144**, the 8 GB default (P84, P85, PR #13) |
| Decode 4k | 37.2 (floor, P13); 36.9 stock tiered (P2) | **51.5** (P96) |
| Decode 32k | 24.5 (floor); 13.5 stock | **51.3** (P96) |
| Decode 60-64k | 17.5 (floor, 60k); 6.0 stock (64k) | **34.4** at 64k (P96) |
| Decode 128k | - (floor window ends at 64k) | **14.8** (P103, tier-graphs) |
| Decode 192k / 245k | - | **8.6 / 6.7** (P103) |
| Prefill at depth | stock: in-place q4_0 attention | chunked prefill: 121 -> 171 tok/s at 128k, 25 -> 90 at 250k (P89) |
| Quality | - | HumanEval 158/164 on the 262k launcher (P87); 18/18 turns of one agent session from 133k to 259.5k tokens, 0 one-token answers (P99) |
| 16 GB RAM machines | bad_alloc and server death (issue #16) | RAM-budget launcher (P90, PR #18) |

Decode is above the floor at every depth the floor serves (P13, P20, P96), and the window is 4x larger. 60 tok/s is
not reached at stock memory: decode is ~73 % ternary mat-vec at 65-80 % of DRAM peak (P36, P37). Past the VRAM line
(~58-60k positions) decode is bound by PCIe 3.0 (~11 of ~13 GB/s at 250k, P98b), so speed falls with depth.

**Experimental, not shipped (in gating):** sparse host-tail reads (#21) and the q3_0 KV type. Sparse: the 245k loss
in P102-P107 was VRAM over-commit (P107, P111). With the sparse tables cut and counted, sparse decodes 2.68x dense at
245k (14.2 vs 5.3 tok/s, no op timing, P115) and 2.15x at 160k (P112), with follow-up prefill equal to dense. The
always-on 64k cost (-20.6 %, P115; all in FLASH_ATTN_EXT, P118) was a routing bug: below MIN_HOST the attention op lost
its tier prefetch. The 4070 fixed it in product-sparse 3ab0af3c2 (P123: 0 sparse ops at 64k). What is left is the
launcher's page-bound reserve: it must cover the whole window, so it costs 13,824 VRAM cells at every depth (P122:
sparse only 1.02x at 96k; P123: 64k -7.0 % vs sparse off). int8 bounds (c8bbb1898, 514 B per host cell) halve it;
P127 / P128 decide the default under the 4070's rule (64k within ~5 % of sparse off). Patch 0055 (draft PR #56) and
launcher PR #49 wait for them and for one quality question: at 245k sparse B 8192 loses one exact copy that dense
keeps (4070 D22 control; P105 here); P133 checks it on c8bbb1898. q3_0: line 1.31x, decode +23 % at 128k and +15 % at 192k, -6.5 % at 64k, copies 10/10
and needles 12/12 at 160k (P114), HumanEval 160/164 (P117). Cary's order: sparse first, q3_0 in a later bundle; the
port (4dbfe57d4) gets the same set as P129-P132.

## What shipped (each with its record)

| Change | Effect on 8 GB | Records | Where |
| --- | --- | --- | --- |
| Turing takes the planar PT layout at one column | decode +13.7 % | P7, P8 | PrismML #325, bundle-20261007 |
| q4_0 K/V as the 8 GB default | ~1.9x positions per MiB (18,432 vs 34,816 B per cell); KL 0.0021, top-1 97.9 % | P5, P6, P31, P32 | launcher |
| Q4_0 MTP head, draft 1 / tail 1 | -214 MiB head, -152 MiB plane; decode 52.3 at 4k | P12, P15, P35, P47 | launcher, tools |
| f16 prefill from pool memory | long-mode prefill +2 to +26 % (floor parity) | P25, P27 | PrismML #330 |
| Lookup drafting on 8 GB | quotes x2.1-3.4, edits +5-30 % | P49, P50, P53 | PR #9 |
| Shared pool (with the poolsync fix 0045) | +2,048 cells, decode +7 % at 64k | P64-P69, P83 | PR #10 hotfix, then 0045 |
| Mid-message checkpoints (`--checkpoint-every-nt`) | 64k follow-up wall 227 -> 60.5 s | P59, P71, P73 | patch 0046, PR #11, PrismML #338 |
| Partial staging + packed KQ mask + pool | 262k at the 131k speed: 64k 37.8 vs 30.5 | P81, P82, P84, P85 | patches 0047-0049, PR #13 |
| Chunked flash attention for prefill | prefill x1.4 at 128k to x3.6 at 250k, PPL equal | P89 | patches 0051-0052, PR #19 |
| RAM-budget launcher (issue #16) | 16 GB machines keep running | P90 | PR #18 |
| Tier-graphs (CUDA graphs past the line) | +16 / +9 / +8 % at 128k / 192k / 245k | P103, P113 | patch 0053, bundle-20261011 (4070 session) |
| Memory clock +1000 (opt-in, never default) | +2.4-2.7 % drafting decode | P38, P42 | docs/8GB.md |

## What was rejected or did not help (each with its record)

| Lever | Result | Records |
| --- | --- | --- |
| Core overclock +150 / 215 W | +3.5-4.1 % but 86 C (74 C with desk fans) and 1 of 26 texts diverged | P4, P9 |
| Memory +1250 / +1500 | GPU fault after ~10 min / crashed the PC | P39 |
| PrismML #209, #314 (4070 defaults), #314 prefetch | 0.0 %, -2.4 %, no gain on Turing | P10, P43 |
| Draft 2 / 3, tail 2-4 as default | prose -10 %, 60k -19 %; tail 4 -41 % at 32k | P35, P47, P105 |
| DFlash 2 drafters | ~645 MiB more VRAM, prefill -33 %, mean decode below ours | P33 |
| Micro-fusions (gate+up+GLU, ADD+RMS_NORM+MUL) | +0.2 %; stopped by decision | P48, P76 |
| Mat-vec launch shape, GRAPH_OPT | +0.6 % / slower | P78 |
| Staging off | prefill -60 to -70 % at depth | P77 |
| Min-Q for f16 prefill (patch 0043) | neutral on Turing | P60, P70 |
| CPU attention over the host tail | 110-278 ms per layer vs PCIe ~19 ms | P95, P97 |
| 2-bit KV | PPL +1.9 % (64k) to +3.6 % (16k) | P100 |
| Streaming / retrieval head split | no streaming heads in this model | P104 |
| 77k positions in VRAM | prefill cliff under memory pressure | P11, P14 |

## Results by day

- **2026-10-06 (P1-P12):** fixed cost and the stock record; clocks (memory did not limit decode then; P38 corrected
  this on the new engine); positions vs drafting at equal VRAM (q4_0 wins); the Turing one-column kernel fix (+13.7 %);
  margin soaks; drafting made cheap.
- **2026-10-07 (P13-P48):** sudoingX's floor measured; the prefill cliff; tail 1; the one-token bug first seen; packed
  mask rejected (later found to be the build's races, P82); f16 prefill to the floor; release `bundle-20261007`;
  HumanEval 157/164; DFlash rejected; decode time budget (P36, P37); the memory-clock limits and the +1500 crash.
- **2026-10-08 (P49-P72):** lookup drafting; the shared-pool race found and fixed (P64-P69, patch 0045);
  mid-message checkpoints proved correct (P71); release check `8gbfix`.
- **2026-10-09 (P73-P89):** 262k window: the cost was the staging buffer (P75, P77), fixed by partial staging,
  packed mask and pool (P81-P85); 262k becomes the 8 GB default; chunked prefill for depth (P89).
- **2026-10-10 (P90-P103):** RAM budget for 16 GB machines; texts compared only within one session history (P92-P94);
  CPU attention ruled out; attention is diffuse (P98); deep agent session to 259.5k (P99); 3-bit KV costs ~nothing
  (P100); sparse reads quality equal (P101); tier-graphs pass (P103).
- **2026-10-11 (P104-P107):** no streaming heads (P104); sparse 1.9x at 160k (P105, P106); 245k op timing finds a
  VRAM wrap at the first sparse decode step (P107); stop for the move at 11:50 (P109 interrupted, no result).
- **2026-10-13 (P108-P118, P109b, P121-P123, P126):** post-move smoke: card unchanged (P110; its single-run gate
  failed at 32k); q3_0 KV passes (P108); P109 superseded by the 4070's allocation answer; sparse 2.23x at 245k once
  VRAM is not over-committed (P111); the depth threshold works, 64k still -20 % (P112); `bundle-20261011` release check
  PASS (P113). q3_0 at depth: line 1.31x, +23 % at 128k, +15 % at 192k, quality held (P114); HumanEval 160/164 (P117).
  Patch 0054 skips cleanly on sm_75 (P116, P116b). Clean 245k sparse 2.68x; the 64k cost is always-on (P115) and sits
  in FLASH_ATTN_EXT (P118). P109b infeasible (margin 1025 leaves 3,328 cells). Crossover on the old build 1.45x at
  96k, 1.78x at 128k (P121). product-sparse builds and passes op tests; the launcher reserve costs 13,824 cells
  (P122); the routing fix holds, 64k -7.0 % from the line (P123). A power cut (~21:27) and a Windows servicing crash
  (~23:56) cut P126 and P126b; P126 read 4-7 % low at 64k-128k against P113 (another session).
- **2026-10-14 (P126b; P124 running):** bundle-20261013 = bundle-20261011 within 1.5 % in one session, so the
  bundle-20261013 release check passes (P126b). P124 (product-sparse release-style sweep) running: 4k-128k so far
  52.8 / 47.4 / 35.2 / 27.0 / 26.0.

## Method lessons (from the audit)

- **Grade every gate as written.** P89's speed gate was 1.41x at 128k (gate 1.5x) and the patch shipped on its quality
  result without saying so; P30's free-VRAM gate was missed by 12 MiB and never graded.
- **Compare like with like.** Several readings compared different request sequences or prompt mixes: P14c and P16b
  vs the floor (P23 corrected them), P33's "+8 %", the P39 drift numbers (two alternating prompts).
- **Count failures with more than one counter.** P67's "0/3 one-token" arm had 4-5-token answers.
- **Check free VRAM in every arm, and read wrapped values.** The sparse arms' "min free 4194274 MiB" was an
  over-commit that nobody read for five runs (P102-P106).
- **Texts differ across session history** with lookup drafting (P94): compare texts only inside one server's history.
- **Compare releases only inside one session.** P126 read bundle-20261013 4-7 % below P113 at 64k-128k; the same two
  bundles alternated in one session differed by -1.0 to +1.5 % (P126b). Across sessions (reboots, idle VRAM, the line)
  this card moved ~5 % at 64k. A release check gates on a same-session A/B against the previous release.
- **A launcher reserve sized for the full window costs the line at every depth.** The sparse page bounds (244-245 MiB
  at 262k) moved the line from 62,464 to 48,640 cells: sparse lost its 96k gain (1.02x, P122) and ran 64k 7.0 % below
  sparse off (P123). The reserve cannot be sized by depth (the line is fixed at load), so shrink its bytes (int8
  bounds) and check the line cost at the shallow depths, not only the gain at the deep ones.

## Open

Done since the last version of this report: P109b (VOID, infeasible), P114, P115, P116, P116b, P117, P118, P121,
P122, P123, P126, P126b. bundle-20261013 passes on the 2060 (P126 + P126b).

Open (2026-10-14 01:54, in queue order): P124 (product-sparse 3ab0af3c2 release-style sweep, 160k / 245k vs sparse
off, 245k trace minimum; running), P127 (int8 bounds c8bbb1898: build, 64k vs sparse off, the 4070's 5 % rule), P133
(245k copies and needles on c8bbb1898: dense, sparse B 8192, sparse B 16384), P128 (release-style sweep on c8bbb1898),
P129-P132 (q3_0 on 4dbfe57d4: op tests and PPL, depth with sparse off, HumanEval, sparse on with q3_0 vs q4_0), P125
(HumanEval on product-sparse), P119 / P120 (the P99 deep agent session on bundle-20261011 and on c8bbb1898). The sparse
default on 8 GB, patch 0055 (draft PR #56) and launcher PR #49 wait for P124 / P127 / P128 and for the 245k copy
question: at 245k sparse B 8192 loses one exact copy that dense keeps (4070 D22 control; P105 on this card).
q3_0 needs a launcher CellBytes entry (14,336 B) and the P129-P132 results before any default. The levers without 8 GB
numbers are listed at the end of `TOOLBOX.md`.
