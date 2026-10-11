# 8 GB research: report (2026-10-06 to 2026-10-11, ongoing)

All runs on one RTX 2060 SUPER 8 GB (Turing, PCIe 3.0, desktop on the card), unattended from a job queue. Each
experiment has a plan and a gate written in `NOTEBOOK.md` before its result, and one record in `experiments/`.
On 2026-10-11 four writers re-read every notebook entry against its receipts to make the records. They found about 60
places where the notebook and the receipts disagree. Each one is in its record, and the notebook has correction
entries for them (end of `NOTEBOOK.md`). Where a correction changes a reading, this report uses the corrected value.

## Bottom line

Mission goal (Cary): beat the community 8 GB recipe (sudoingX's floor) on this card, 60+ tok/s, quality and stability
to the end of the window, and make the full 262k window the worthwhile default on 8 GB.

| | Start (2026-10-06) | Shipped now (`bundle-20261010` + patch 0053) |
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

**Experimental, not shipped:** sparse host-tail reads (#21) decode 1.9x at 160k (9.7 -> 18.5 tok/s, quality equal,
P105, P106) but are still slower at 245k and cost 16 % at 64k. P109 tests whether VRAM over-commit causes both losses.

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
| Tier-graphs (CUDA graphs past the line) | +16 / +9 / +8 % at 128k / 192k / 245k | P103 | patch 0053 (4070 session) |
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
- **2026-10-11 (P104-P109):** no streaming heads (P104); sparse 1.9x at 160k (P105, P106); 245k op timing (P107);
  the VRAM over-commit lead (P109); q3_0 KV tests (P108).

## Method lessons (from the audit)

- **Grade every gate as written.** P89's speed gate was 1.41x at 128k (gate 1.5x) and the patch shipped on its quality
  result without saying so; P30's free-VRAM gate was missed by 12 MiB and never graded.
- **Compare like with like.** Several readings compared different request sequences or prompt mixes: P14c and P16b
  vs the floor (P23 corrected them), P33's "+8 %", the P39 drift numbers (two alternating prompts).
- **Count failures with more than one counter.** P67's "0/3 one-token" arm had 4-5-token answers.
- **Check free VRAM in every arm, and read wrapped values.** The sparse arms' "min free 4194274 MiB" was an
  over-commit that nobody read for five runs (P102-P106).
- **Texts differ across session history** with lookup drafting (P94): compare texts only inside one server's history.

## Open

P107 (op timing at 245k), P108 (q3_0 KV type: tests, perplexity, decode), P109 (sparse VRAM margin). The levers
without 8 GB numbers are listed at the end of `TOOLBOX.md`.
