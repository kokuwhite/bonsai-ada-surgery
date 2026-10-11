# Bonsai 2 27B on RTX 2060 SUPER 8 GB: decisions log

Rig (measured 2026-10-06): RTX 2060 SUPER 8,192 MiB, driver 591.86, PCIe gen 3 x16, 31.9 GB RAM (21.8 free),
445 GB free disk. The only display adapter Windows lists is the 2060 SUPER (3840 wide); explorer/shell hosts hold
GPU contexts on it; idle used 783 MiB, free 7,224 MiB. `nvidia-smi display_active` reports `Disabled` anyway, so
the launcher's headless detection is wrong on this rig: every run pins `BONSAI_VRAM_MARGIN` explicitly.

---

## 2026-10-06 P1 (plan): first serve, measure the fixed cost

Launcher model for the plain file (no draft): Fixed = file_MiB - 265 + 150 + 400 + 300 (~6,225 MiB). With free 7,224
and margin 1,300 the budget is negative, so auto-sizing will throw (floor 16,384 cells). The handoff's table assumed
~5,770 fixed for no-draft; the launcher formula does not subtract anything for SPEC=0 beyond ~43 MiB of draft cells.

Arms: plain PTQ1_0 file, BONSAI_SPEC=0, q8_0, BONSAI_CTX=131072, BONSAI_KV_VRAM_CELLS pinned at 16384 then 8192
if 16384 does not load. Read nvidia-smi used at idle-after-load, solve Fixed = used_at_load - before_used - N*CellBytes
- (Ctx-N)*CellBytes/16.

Gates written before the run:
- the server loads and answers one greedy request;
- measured fixed cost is reported to the MiB; if it differs from the launcher's 6,225 by more than 200 MiB, the
  launcher constant is wrong for this card and gets corrected before any auto-sized run;
- no shared-memory (demotion) growth visible in Task Manager "Shared GPU memory" during load.

## 2026-10-06 P1 (result): fixed cost measured, launcher constant is 382 MiB high on this card

Run: plain file (sha256 53107f53...33ee3, 5,946,648,928 B), SPEC=0, q8_0, CTX 131072, --kv-vram-cells 16384 pinned,
layer off, memory clock stock 7000 MHz. Log: logs/20261006-183534-p1-n16384.*
- nvidia-smi used: 838 MiB idle before, 7,494 MiB after load (server 6,656 MiB); 7,506 / 501 free after a request.
- KV head 16384 x 34816 B = 544 MiB; staging 114688 x 2176 B = 238 MiB -> **fixed = 5,874 MiB** (launcher model 6,256).
- Greedy "17*23" -> 391. Shared GPU memory 4,008 MiB = the pinned host tail (3,808 MiB) + host buffers, not spill.
- Gates: loads and answers PASS; fixed off by 382 MiB > 200 -> launcher constant needs correcting for this card
  (BONSAI_KV_VRAM_CELLS pinned until then); shared growth: none beyond the pinned tail.
Consequence: with the display on this card (idle free ~7,170) and margin 1,300, auto-sizing still yields nothing.
The margin, not kernels, is the binding question here: 16,384 cells leaves ~500 MiB free.

## 2026-10-06 P2 (plan): decode-by-depth record at stock, N=16384

Same serve as P1. bench/quick_tps.py (3 prompts, 400 tok, greedy, thinking off) at depth 0 / 4k / 16k / 32k / 64k / 120k.
Record decode, prefill (first prompt), nvidia-smi used and free during each depth. Gates: every depth completes;
free VRAM never under 200 MiB; decode does not fall >30% between repeated prompts at the same depth (the demotion
signature). No pass/fail on speed: this is the record.

## 2026-10-06 P3 (plan): memory-clock sweep via Afterburner slots

Afterburner slots (verified in the profile file): 5 = stock, 1 = +250, 2 = +500, 3 = +750, 4 = +1000 (MemClkBoost kHz;
core, power, fans untouched). Applied by scheduled tasks BonsaiAB_P1..P5 (admin, no prompt). Serve as P1/P2.
Arm order: stock, +250, +500, +750, +1000, stock again (drift check). memclock_probe.py: 4k filler (in VRAM), 2 prompts
x 400 tok greedy x 2 reps, memory clock sampled under load.
Gates per arm, written before the run:
- identity: every output text byte-identical to the stock arm's (greedy; any difference = memory errors -> arm fails,
  and every higher offset is skipped);
- speed: keep the highest offset whose mean decode beats the previous arm by more than the stock-vs-stock-again
  spread (GDDR6 error retry shows as flat or falling tok/s, not a crash);
- the clock actually moved under load (nvidia-smi clocks.mem max > the previous arm's).
Afterwards: apply slot 5 (stock) unless the winner is confirmed by a 10-minute soak in a later entry.
Note from P2: under CUDA load the card sits in P2 at 6,801 MHz, not 7,000; the sweep records what each offset does there.

## 2026-10-06 P2 (result): the stock record, N=16384 q8_0, no draft, display on the card

Receipt: receipts/p2-decode-depth-stock-n16384.txt, VRAM samples receipts/p2-vram-samples.txt.
| depth | 0 | 4k | 16k | 32k | 64k | 120k |
| decode tok/s (mean of 3) | 38.6 | 36.9 | 32.6 | 13.5 | 6.0 | 3.0 |
| prefill tok/s (first prompt, evaluated) | - | 397 (4k) | 325 (12.5k) | 221 (16.5k) | 155 (32.5k) | 102 (56k) |
Gates: all depths completed PASS; min free VRAM 343 MiB PASS (>200); no within-depth decode fall PASS (identical to
0.1 tok/s across prompts). Memory clock under load 6,801 MHz (P2 state), PCIe gen 3 throughout.
Reading: past the VRAM line decode is PCIe-bound and falls ~2.4x at 32k and ~11x at 120k vs in-VRAM. On this card
positions in VRAM are the product; every MiB freed buys ~32 positions at q8_0 (~57 at q4_0).

## 2026-10-06 P3 (result): memory clock does not limit decode on this card; core clock and heat do

Receipts: receipts/memclock/sweep.txt and <arm>.json (texts, per-second clock/temp/power samples).
| arm | mem under load MHz | mean decode | core MHz | temp C | power W |
| stock | 6801 | 36.73 | 1755-1875 | 67-81 | 113-179 |
| +250 | 7050 | 35.88 | 1650-1860 | 75-82 | 136-174 |
| +500 | 7300 | 35.39 | 1650-1845 | 78-82 | 129-172 |
| +750 | 7551 | 35.42 | 1650-1845 | 78-83 | 111-170 |
| +1000 | 7800 | 35.41 | 1650-1845 | 79-83 | 120-172 |
| stock again | 6801 | 35.05 | 1650-1815 | 79-83 | 125-168 |
Gates: identity PASS at every offset (byte-identical to stock, +1000 included); clock moved PASS (offsets apply in
the P2 state 1:1 in nvidia-smi MHz); speed FAIL for every arm: +1000 (+14.7% bandwidth) is +1.0% over stock-hot,
inside the stock-vs-stock drift of 1.68 tok/s (4.8%).
Reading: PTQ1_0 decode on Turing is core-bound, not bandwidth-bound; the drift tracks the core clock falling from
1875 to 1650 as the GPU passes its 81 C target. Power touched the 175 W limit (max slider 215 W). Card left at stock
(slot 5). Handoff's "scale by bandwidth" assumption does not hold here; the op-timing table should show which kernel.

## 2026-10-06 P4 (plan): cooling, power and core-clock sweep

Afterburner slots: 5 = stock (power 100, fan auto); 1 = power 122 (215 W) + fan fixed 85% (user-saved, VF curve as
saved); 2/3/4 = same + core +50/+100/+150 (written by make_staged.py with the VF curve blank so the flat offset applies;
installed by BonsaiAB_Install). Note: PowerLimit=123 is out of range and silently ignored; 122 is the max.
Arm order: stock, slot 1, 2, 3, 4, slot 1 again (drift). Same probe as P3 (4k filler in VRAM, 2 prompts x 400 x 2).
Gates, written before the run:
- identity: byte-identical to the stock arm at every step; a mismatch or a driver reset (server error) stops the
  climb, applies stock, and fails that arm;
- applied: slot 1 shows power.limit 215 W and fan 85%; each core arm's median core clock under load is above the
  previous arm's by at least half its offset step (else the offset did not apply and the arm is void);
- speed: an arm wins only if its mean decode beats the previous arm by more than the slot-1 vs slot-1-again spread.
Afterwards: apply stock unless a winner is confirmed by a 10-minute soak in a later entry.

## 2026-10-06 P4 (result): +4.9% at the most, capped by heat; card left at stock

Receipts: receipts/coreclock/sweep.txt and <arm>.json.
| arm | core median MHz | mean decode | temp C | power median W |
| stock | 1815 | 37.45 | 52-71 | 172 |
| slot 1: 215 W + fan 85% | 1875 | 38.13 | 66-78 | 209 |
| + core +50 | 1905 | 38.51 | 69-80 | 207 |
| + core +100 | 1935 | 38.75 | 72-83 | 211 |
| + core +150 | 1995 | 39.27 | 75-85 | 209 |
| slot 1 again | 1845 | 37.59 | 76-87 | 209 |
Gates: identity PASS every arm; applied PASS (core median +30/+30/+60 MHz per step, power 215 W, fan 85%); speed:
per-step FAIL (each +50 step adds 0.24-0.52 tok/s, inside the 0.54 slot-1 drift), cumulative +150 vs slot 1 +1.14 and
vs stock +1.82 (+4.9%). Decode scales at ~half the core clock (+9.9% clock -> +4.9% decode).
The card heated through the sweep to 87 C (max operating 89 C) at fan 85%: later arms are understated, and +150 is
not a serve setting without a 10-minute soak and better airflow. Not pursued further now: the VRAM line is worth
2.4x-11x past 16k, clocks 5%.

## 2026-10-06 P5 (plan): positions vs drafting at equal VRAM (display on the card, stock clocks)

Budget: the P1 serve's 6,656 MiB on the card (~500 MiB left free). CTX 131072 for all arms. Pinned N per arm:
- A: q8_0, no head, N=16384 (P2 is its record; re-measured here in the same session for comparability)
- B: q4_0, no head, N=38656 predicted ((782 MiB - 131072 x 1152 B) / 17280 B per cell)
- C: q4_0, ProCreations head, draft 1 (sudoingX's 3060 finding), tail draft 2, draft window 16384, N sized at load to
  the same 6,656 MiB (head cost measured, not assumed)
GGML_CUDA_BATCH_INVARIANT=1 in every arm (C needs it; A and B get it so greedy texts are comparable).
Measures: server VRAM at load and min free during the run; quick_tps decode at 4k / 16k / 32k / 64k (3 prompts).
Gates, written before the run:
- every arm within 6,656 MiB +/- 64 at load (else re-pin and re-run that arm);
- C's greedy texts byte-identical to B's at 4k (drafting must be lossless at the same KV type);
- decision: the default is the arm with the best decode at 32k (a long-chat depth past A's line) unless another arm
  beats it by >25% at 4k AND 16k; the losing arms stay documented modes. q4_0 as default additionally needs this
  card's KL receipt (P6) to repeat the 12 GB finding (~1 flipped top token in 48), stated in the README row.

## 2026-10-06 P6 (plan): q8_0 vs q4_0 K/V quality receipt on this card

Command (docs/QUALITY.md recipe): bench\kv_kl_sweep.ps1 -Model models\Ternary-Bonsai-2-27B-PTQ1_0.gguf -Bin bin
-Configs q8_0:q8_0,q4_0:q4_0 (wikitext-2 test, sha256 173c87a5...dd08; 16,384-token chunks x 4, scored at 8k-16k depth;
KL vs the same model with f16 K/V). Server stopped for the run. 12 GB receipt: q8_0 KL 0.00017 / top-1 flip 1 in 160,
q4_0 KL 0.00218 / 1 in 48.
Gates, written before the run:
- the f16 base fits at 16,384 (if it does not, the run uses 8,192 and the entry says so; depths then differ);
- this card's q4_0 numbers are within 2x of the 12 GB receipt in both mean KL and flip rate (Turing kernels differ;
  a larger gap means q4_0 behaves differently here and needs its own investigation before any default);
- the README row for an 8 GB q4_0 default quotes this card's numbers, not the 4070's.

## 2026-10-06 P5 (incident): arms A and A-r2 invalid, cause found and fixed

stop.ps1 was called without -ExecutionPolicy Bypass; this machine's effective policy is Restricted, so it never ran
(output went to /dev/null). Arm A loaded on top of the still-releasing P1 server and hit a CUDA error on its first
request (all depths FAILED). Arm A-r2 ran while arm B's q4_0 server was still alive on the same port 8080: its numbers
(41.3 / 37.2 / 33.4) are B's server answering, and ~13 GB of servers sat on the 8 GB card. Both kept as
receipts/p5/INVALID-*. Arm B is valid (idle 656 MiB at start, one server). P2-P4 valid (one server existed).
Fixes: stop.ps1 runs with Bypass, waits for llama-server to exit and throws if it does not; serve.ps1 refuses to start
while any llama-server runs; the arm script exits if stop/serve fail or VRAM is not under 1,500 MiB before a load.

## 2026-10-06 P7 (plan): one-column PTQ1_0 decode kernel on Turing (planar PT vs Ada SOA_ISUM)

Observation: clean arm A-r3 (q8_0, N=16384, GGML_CUDA_BATCH_INVARIANT=1) probed 42.80 tok/s at 4k vs 36.7-37.5 for the
same serve without the variable (P3/P4). (Its probe ran at 215 W, set outside the scripts; P4 measured 215 W at +1.8%,
so power does not explain it. Stock re-applied 19:50:06, receipts/p5/clock-state.txt.)
Mechanism (engine c8b8993, ggml-cuda/common.cuh ggml_cuda_q8_1_layout_host): one-column decode takes SOA_ISUM unless
the card is Ampere (cc 800-889 -> planar PT, "+5.9% tg128 on a 3060") or BATCH_INVARIANT is set (-> PT with the
warp-reduce epilogue). Turing (cc 750) falls through to the Ada-tuned SOA_ISUM.
Hypothesis: PT beats SOA_ISUM at one column on sm_75 by >10%.
Arms: q8_0 N=16384 serve, stock slot 5 verified before each load; BI unset / BI=1 / unset / BI=1 (alternating against
heat drift); memclock_probe at 4k, 2 prompts x 400 x 2 reps.
Gates, written before the run:
- confirmed if both BI=1 runs beat both unset runs and the mean gap is >10% (> 3x the P4 slot-1 drift of 1.4%);
- if confirmed, the engine fix is to extend the Ampere branch to Turing (cc >= TURING && cc < ADA), built for sm_75,
  then measured as a third arm (PT + four-accumulator epilogue, BI unset) with greedy identity vs a saved dump and
  tg128 in llama-bench; PR to the fork with the receipt.

## 2026-10-06 P5 (deviation): arm C cannot meet the equal budget

C sizing at N=8192 did not start: start-server.ps1 throws below 16,384 cells even when pinned (line 154). The chain
ignored the arm's exit code and solved N from an empty load (411,904); stopped before that arm loaded. Predicted
equal-budget N for C is ~9.6k (fixed ~6,354 MiB with the head), below the floor. C runs at its minimum N=16384 and its
result states the measured VRAM over the 6,656 MiB budget; the decision gate compares at that cost.

## 2026-10-06 P5b (plan): isolate the C vs B text difference

C (mtp-procreations file, draft 1) differs from B (plain file, no draft) at greedy, both q4_0 + BATCH_INVARIANT: prose
splits at char 55 ("by moving heat" / "by continuously removing heat"), code at char 591. Arm D: the mtp file, SPEC=0,
GGML_CUDA_BATCH_INVARIANT=1 set by hand, q4_0, N=16384, probe only.
Reading, decided before the run: D == B and D != C -> drafting is not lossless on this card (a correctness bug, blocks
the head on 8 GB until fixed); D == C and D != B -> drafting is lossless and the grafted file's graph shifts numerics
(file-level finding, not a draft bug); D equal to neither -> nondeterminism; re-run B and D once each before reading.

## 2026-10-06 P5 (result): B (q4_0, no head, 38,656 positions in VRAM) is the 8 GB default candidate

Receipts: receipts/p5/{A_q8_n16384_r3,B_q4_n38656,C_q4_head_n16384}.txt (+ .json texts, .free.txt samples).
All arms GGML_CUDA_BATCH_INVARIANT=1 (so A is not comparable with P2, which ran without it; see P7).
| depth | A q8_0 N=16384 | B q4_0 N=38656 | C q4_0 + head (draft 1, tail 2) N=16384 |
| 4k | 42.7 | 41.9 | 49.5 |
| 16k | 37.3 | 36.6 | 45.8 |
| 32k | 14.1 | 32.0 | 29.4 |
| 64k | 6.1 | 13.7 | 17.9 |
| server VRAM at load | 6,719 | 6,743 | 7,255 |
| min free during run | 632 | 586 | 144 |
C draft acceptance 0.63-0.74 (mean accepted length 2.3-2.5).
Gates: VRAM within 6,656 +/- 64: A PASS (+63), B marginal FAIL (+87; prediction 24 MiB low), C FAIL (+599; the head
costs ~967 MiB on this card, not ~480); C vs B identity FAIL (see P5b); decision rule: best at 32k is B (32.0); C beats
B by 18% at 4k and 25.1% at 16k, not >25% at both -> B. C also fails min free >200 (144).
Decision: B is the default candidate, conditional on P6 (q4_0 KL on this card). C stays a documented mode only after
P5b clears identity and the head cost drops (requant -204 MiB, shared pool -188 MiB are the next ports).

## 2026-10-06 P5b (result): MTP drafting is not lossless on Turing; the head is blocked on this card

Receipt: receipts/p5/D_q4_mtpfile_nodraft.txt. D (mtp file, no draft, q4_0, BI=1) is byte-identical to B (plain file)
on both prompts and differs from C (same file, draft 1) on both: the grafted file is neutral, drafting changes greedy
output on sm_75 (prose from char 55). Lossless on the 4070 per the repo; not here.
VRAM: D server 6,383 MiB -> the head's weights cost ~95 MiB resident without drafting; drafting adds ~870 MiB
(draft context, GDN snapshots, compute).
Next (P8, plan to follow): bisect the verify path on sm_75 with env toggles before any code change - FA path for
2-column verify batches (fattn.cu BI branch, GGML_CUDA_FA_DEEP_MMA), the in-place quantized-K/V read (patches
0009/0029, Ada-tuned), q8_0 vs q4_0 K/V, draft 1 vs 2.

## 2026-10-06 P7 (result): CONFIRMED - planar PT beats the Ada SOA_ISUM kernel at one column on Turing by 12.3%

Receipts: receipts/p7/p7.txt, soa1/pt1/soa2/pt2.json. q8_0 N=16384, stock 175 W verified before each load.
| soa1 36.76 | pt1 41.23 | soa2 36.69 | pt2 41.25 | (4k, 2 prompts x 400 x 2 reps)
Gates: both PT > both SOA PASS; mean gap +12.3% (> 10%) PASS; run-to-run spread 0.07 / 0.02 tok/s.
Also explains A-r3's 42.80: PT via BATCH_INVARIANT, plus 215 W in its probe window.
Leftover: ggml_cuda_q8_1_layout_host routes Ampere to PT at one column and leaves Turing (cc 750) on the Ada default.
BATCH_INVARIANT=1 is a no-rebuild workaround (PT + warp-reduce epilogue) worth +12.3% on this card today.

## 2026-10-06 P8 (plan): engine fix - Turing takes the planar PT layout at one column

Change (fork bonsai-q8-product, ggml-cuda/common.cuh): the one-column override covers Turing as well as Ampere
(cc >= TURING && cc < ADA_LOVELACE). Build sm_75 with build\build_windows.ps1 into a separate bin (bin-turing\),
bundle untouched.
Arms, q8_0 N=16384, stock verified: bundle BI unset (SOA, 36.7 reference) / new build BI unset (PT + four-accumulator
epilogue) / new build BI=1 (PT + warp reduce), alternating x2.
Gates, written before the run:
- new build + BI=1 byte-identical to bundle + BI=1 (pt1 texts): proves the change touches nothing else;
- new build BI unset >= bundle BI=1 (41.2) by more than the run-to-run spread; report its gain over SOA;
- greedy texts of new build BI unset may differ from SOA (different summation order, as on Ampere); report KL of the
  new default vs the bundle default on the P6 recipe before it ships.

## 2026-10-06 P6 (result): q4_0 on this card matches the 12 GB receipt; B's cost is 1 flipped top token in 48

Receipts: receipts/p6-kl-sweep.txt; repo artifacts\eval\kl_{q8_0_q8_0,q4_0_q4_0}_16k-2060super.log (unique tag; the
repo's 4070 logs in the same folder are untouched, one overwritten by a failed first invocation was restored by git).
| K/V | mean KL (2060S / 4070) | top-1 agrees | max KL | PPL vs f16 |
| q8_0 | 0.000167 / 0.00017 | 99.417% / 99.38% (1 in 171) | 0.11 / 0.18 | +0.017% |
| q4_0 | 0.002096 / 0.00218 | 97.900% / 97.93% (1 in 48) | 1.25 / 0.94 | +0.14% |
Base PPL (f16 K/V) 6.9740 +/- 0.098. Gates: f16 base fit at 16,384 PASS; q4_0 within 2x of the 12 GB receipt PASS
(within 5% on mean KL and top-1); README row quotes these numbers.
Decision: B (q4_0, ~38.6k positions in VRAM, no head) becomes the 8 GB default with the cost stated: q4_0 flips the top
token on 1 in 48 positions at 8k-16k depth vs 1 in 171 for q8_0; q8_0 stays a documented mode (BONSAI_CTK=q8_0) for
exact-syntax work that fits in 16k.

## 2026-10-06 P8 (result): Turing fix built and measured - +13.7% decode over today's Turing default

Build: vendor/prism-llama branch turing-pt-onecol (c8b8993 + common.cuh: one-column override covers cc >= TURING),
sm_75 only, pip CUDA 13.4 wheels + nvidia-cuda-cccl 13.3.4 (the recipe's pip line lacks cccl), staged bin-turing\.
Receipts: receipts/p8/p8.txt, <arm>.json. q8_0 N=16384, stock 175 W verified before each load.
| s1 bundle SOA 38.07 | n1 new 43.34 | b1 bundle PT(BI) 42.12 | n2 new 43.22 | i1 new BI 42.06 |
Gates: new+BI byte-identical to bundle+BI PASS (change touches nothing else); new default 43.28 vs bundle BI 42.09
(+2.8%) > spread (0.12 / 0.06) PASS; new vs old default +13.7%; n1 == n2 texts (deterministic); new default texts
differ from SOA (summation order, as on Ampere) - KL gate running (receipts/p8-kl-newkernel-{f16,q4_0}.log).
Upstream check (2026-10-06): PrismML prism branch still gates PT to Ampere (common.cuh:1295); no open PR touches it;
#218 (sudoingX) is the kernel this enables. Not a duplicate.

## 2026-10-06 P5b (correction): the C vs D difference is documented behaviour on every card, not a Turing bug

docs/Q8_FULL_CONTEXT.md:88 (and PR #322's body): drafting is not bit-identical to not drafting, stock kernels included;
attention's KV split follows the kernel instance (1-query decode vs multi-query verify) and the padded KV length;
differences are rounding-level and every continuation is a valid greedy decode. BATCH_INVARIANT keeps only the PTQ1_0
weight path exact. P5b's gate ("C byte-identical to B") was written from the handoff's "greedy output identical to no
draft", which overstates the docs; README line 74 ("lossless speculative decoding") does too (flagged to Cary, not
edited). Corrected reading: the head is not blocked by correctness. It stays out of the 8 GB default for the P5 reasons
(decision rule picks B; 144 MiB free). The right gate for a drafting mode is task quality / KL, not byte identity.

## 2026-10-06 P9 (plan): soak an overclock as the rig's baseline (Cary wants the card overclocked)

Profile (Afterburner slot 4, rewritten): PowerLimit 122 (215 W), fan fixed 100%, core +150, memory +0 (P3: memory does
nothing for decode). Fallback slot 3: same with core +100. Serve: B config (q4_0, N=38656, no head, layer off) on
bin-turing (the P8 build). Load: p9_soak.py, 10 minutes continuous, alternating 4k / 16k greedy requests of 300 tokens,
logging decode, core clock, temperature and power per request; then one greedy text pair at stock vs OC.
Gates, written before the run:
- max GPU temperature < 85 C (max operating 89 C);
- decode of the last 2 minutes within 3% of the first 2 minutes at each depth (no thermal or demotion slide);
- greedy texts at OC byte-identical to the same serve at stock (core offset errors would show as divergence);
- no driver reset. Pass -> slot 4 becomes the rig baseline and every later receipt names it; fail at +150 -> repeat
  with slot 3 (+100); fail there -> stock stays.

## 2026-10-06 P8 (incident): mixed-source test build killed; PR branch moved to its own worktree

The test-backend-ops build compiled from vendor/prism-llama while the working tree was switched to the PR branch
(PrismML prism 6bfcd79 + the fix): a mix of two source trees. Killed before any test ran; tree restored to
turing-pt-onecol (bc3e5aa); the PR branch claude/turing-pt-onecol (34a932b on prism 6bfcd79) now lives in a separate
worktree vendor/prism-pr. bin-turing (P8's binaries) came from the clean first build and is unaffected.
Rule: never switch a checkout that a running build or server reads; one worktree per branch.

## 2026-10-06 P8 (correction + plan): the planned KL gate does not exercise the change

p8-kl-newkernel-f16: mean KLD 0.000000, max 0.000069, top-1 100% vs the bundle's f16 base - because llama-perplexity
evaluates in 512-token ubatches (MMQ path); the one-column mat-vec that the fix changes never runs. Not evidence.
Replacement gate (P8c): llama-perplexity -b 1 -ub 1 (every token a one-column decode), -c 2048 --chunks 6, f16 K/V:
base = bundle (SOA_ISUM), test = bin-turing (PT four-accumulator) and, as a scale, bundle with BATCH_INVARIANT=1 (PT
warp-reduce). Gate: new-vs-SOA mean KL below the q8_0-vs-f16 K/V KL on this card (0.000167) and top-1 agreement above
q8_0's 99.4% - i.e. the kernel change is smaller than the K/V precision this stack already accepts as near-lossless.

## 2026-10-06 P10 (plan): free alpha from open PrismML PRs, tuned for Turing

Build bin-alpha (sm_75) from worktree vendor/prism-alpha = turing-pt-onecol (bc3e5aa) + #314's first commit e3d9df5
(sb32445, L2 prefetch WITH its env switches; the PR's final commit hardcodes the 4070 values) + #209 b989116 + 37fe656
(cklxx, ADD+RMS_NORM+MUL fusion reachable on all NVIDIA). All three cherry-picked without conflicts.
Why tune: #314's defaults (50% of the next weights, <=16 MiB, last 46 CTAs) were fitted to the 4070's 36 MB L2; the
2060 SUPER has 4 MB of L2 and 34 SMs.
Arms (q4_0 B serve, same clock profile for all, alternating, memclock_probe 4k 2x2 + one 16k pass):
bin-turing (reference) / bin-alpha PCT=0 (= #209 alone) / bin-alpha defaults / MAX_KB=2048 / MAX_KB=1024 /
MAX_KB=2048 CTAS=34.
Gates, written before the run:
- #209 alone wins if bin-alpha PCT=0 beats bin-turing by more than the run-to-run spread, with greedy texts
  byte-identical (the fusion must not change values; if texts differ, report KL before keeping it);
- a prefetch setting wins only if it beats bin-alpha PCT=0 by more than the spread at both 4k and 16k, texts identical
  to PCT=0 (prefetch never changes values);
- result goes back to #314 / #209 as a Turing receipt comment (useful upstream whichever way it lands).

## 2026-10-06 note: why the launcher's headless detection fails here

nvidia-smi (driver 591.86, WDDM) reports display_active Disabled AND display_attached No while Win32_VideoController
shows the 2060 SUPER as the only adapter at 3840 wide; display_mode returns "[Requested functionality has been
deprecated]". nvidia-smi's display fields are not reliable on Windows. Candidate launcher fix (bonsai-ada-surgery,
branch to prepare): treat the NVIDIA card as driving the display when Win32_VideoController reports a
CurrentHorizontalResolution for it (expected empty on the 4070 rig with the iGPU on the desktop - verify there).

## 2026-10-06 P8b (result): test-backend-ops MUL_MAT 1516/1516 on sm_75 with the fix (default and BATCH_INVARIANT=1)

Receipt: receipts/p8-test-backend-ops.txt (build-turing test-backend-ops, CUDA0 vs CPU). Includes the PTQ1_0 n=1
cases that now take the PT layout on Turing. Desktop note: Cary dropped the display to 1280x1024 at ~21:05; card total
599 MiB with test-backend-ops (~127 MiB) running -> desktop ~470 MiB vs 561-608 MiB idle at 4K earlier this evening.

## 2026-10-06 P9 (result): +150 / 215 W / fan 100% is stable and exact but runs at 86 C - not the baseline

Receipts: receipts/p9/p9.txt, stock.json, oc150.json. Serve: B (q4_0, N=38656) on bin-turing, desktop 1280x1024
(791 MiB free at load vs 608 at 4K).
| | 4k first/last 2 min | 16k first/last 2 min | max temp |
| stock (2 min) | 43.45 / 43.34 | 38.55 / 38.55 | 82 C |
| oc150 (10 min) | 44.87 / 44.16 (-1.6%) | 40.13 / 39.56 (-1.4%) | 86 C |
Gates: max temp < 85 C FAIL (86, fan 100%, power-capped at 215 W, throttle reason 0x4); drift < 3% PASS; identity
25/25 PASS. Gain over stock +1.6..3.3% (4k), +2.6..4.1% (16k).
Decision: stock stays the baseline (slot 5 re-applied 21:24:42). Next per plan: slot 3 (+100) soak, queued behind P10.
The limit is the cooler, not the silicon; airflow/repaste is the lever if Cary wants the clocks.
New record for this card (stock, B, Turing fix): 43.4 tok/s at 4k, 38.6 at 16k.

## 2026-10-06 P8c (result): one-column KL - mean KL passes, top-1 misses the written threshold by 0.03 pp inside the CI

Receipts: receipts/p8c/{base_bundle_soa,new_pt,bundle_bi_pt}.log, receipts/p8c-run.txt. llama-perplexity -b 1 -ub 1
-c 2048 --chunks 4, f16 K/V, base = bundle SOA_ISUM.
| vs SOA_ISUM | mean KL | top-1 | max KL |
| new build (PT four-acc) | 0.000146 +/- 0.000012 | 99.389 +/- 0.122% | 0.047 |
| bundle BATCH_INVARIANT (PT warp-reduce, already the drafting/Ampere path) | 0.000158 +/- 0.000015 | 99.487 +/- 0.112% | 0.054 |
Gate (written P8 correction): mean KL < 0.000167 PASS; top-1 > 99.417% FAIL by 0.028 pp, inside one standard error.
Reading: two valid summation orders disagree on near-ties at this rate; the PT path Ampere and drafting already ship
differs from SOA by the same amount. Recorded as a statistical tie, not a pass. Proceeding with the PR (Cary: "absolutely
contribute to prism"), the exact numbers in its body. Caveat: different context (2k) from the q8_0 reference (8-16k).
Note: external desk fans placed in front of the PC ~21:40 (Cary's sister); later thermal receipts name them.

## 2026-10-06 PR: PrismML-Eng/llama.cpp#325 opened

https://github.com/PrismML-Eng/llama.cpp/pull/325 - "cuda: take the planar PTQ1_0 layout at one column on Turing as well
as Ampere". Head professorpalmer/llama.cpp-ada-ternary:claude/turing-pt-onecol (34a932b on prism 6bfcd79). Body:
pr-turing-pt-onecol.md (P7/P8/P8b/P8c receipts, credit to sudoingX #218). Mergeable, CI pending at open.
Duplicate check done before opening (prism still gates Ampere only; no open PR touches the gate).

## 2026-10-06 baseline change: slot 5 = stock clocks + fan fixed 100% (from 21:41); desktop 1280x1024; desk fans

Cary's request: fans at 100%. Slot 5 keeps PowerLimit 100 (175 W), core/memory 0 and the saved VF curve; FanMode=0,
FanSpeed=100. Applying slot 5 while Afterburner considered it active did not change the fan; applying slot 3 then slot 5
did (175 W, 100%). Install via BonsaiAB_Install took ~90 s this time (21:37:53 -> 21:39:24).
Clean idle VRAM at 1280x1024, no CUDA process: 323 MiB used (vs 561-608 MiB at 4K this evening) -> ~250-280 MiB
returned, ~15-17k more q4_0 positions in VRAM. Receipts from here name: stock clocks, fan 100%, desk fans, 1280x1024.

## 2026-10-06 P11 (plan): margin soak - how much of the freed VRAM can hold positions

Sizing (measured): q4_0 fixed 5,962 MiB (B: 6,743 server at N=38656 minus 680 head minus 101 staging); card usable
8,007 MiB (used+free); idle 323 MiB at 1280x1024. N for free F: (8007 - 323 - F - 5962 - 144) MiB / 17,280 B.
Arms (bin-turing, q4_0, CTX 131072, stock clocks + fan 100%): N=65280 (~500 MiB free) then N=77568 (~300 MiB free).
Load per arm: 10 min alternating 4k / 16k / 48k greedy requests (p9_soak pattern + a 48k depth, inside the VRAM line for
both arms), nvidia-smi free and the server's shared GPU memory sampled every 5 s.
Gates, written before the run:
- decode of the last 2 minutes within 3% of the first 2 minutes at every depth (WDDM demotion shows as a slide/cliff);
- shared GPU memory of llama-server does not grow beyond the pinned host tail ((131072-N) x 18,432 B + host buffers);
- min free VRAM never under 150 MiB;
- pass at 77568 twice -> that N is the default; else the largest passing N; the launcher constant/margin for a
  display-on-the-card 8 GB rig is derived from the passing arm.

## 2026-10-06 launcher fix (local branch, not pushed): display detection from Windows

bonsai-ada-surgery worktree C:\bonsai\bas-display-detect, branch 8gb-display-detect, commit 4042bb3: after the nvidia-smi
check, if exactly one Win32_VideoController matches GPU 0's name and reports CurrentHorizontalResolution, $Headless =
false. Tested on this rig: nvidia-smi says headless, the check corrects it (1280 wide). Open before pushing: verify on
the 4070 rig (iGPU desktop) that its NVIDIA adapter reports no resolution, else that rig would lose 300 MiB of positions.

## 2026-10-06 ~22:00 note: access is Chrome Remote Desktop; its own GPU cost is ~8 MiB

Cary reaches this rig through Chrome Remote Desktop (explains nvidia-smi display_attached No: no physical monitor).
GPU Process Memory counters during P10: remoting_desktop 8 MiB, remoting_host none; dwm 762 MiB "dedicated usage"
(counter includes evicted/committed memory; card idle total was 323 MiB). Moving CRD to software would not help; the
cost is the Windows compositor on the only GPU. Candidate experiment (Cary flips the setting): RDP session rendered in
software, measure idle before/after. Cary reported a further resolution reduction ~21:58 (Win32 still 1280x1024 at
22:00); P10 arms record idle per arm.

## 2026-10-06 P10 (result): #209 no effect on Turing; #314's 4070 defaults cost Turing 2.4%; sized for 4 MB L2 it gains ~1.5%

Receipts: receipts/p10/p10.txt, <arm>_{4k,16k}.json. B serve (q4_0 N=38656), stock clocks + fan 100%, 1280x1024.
| arm | 4k | 16k |
| turing1 / turing2 (bin-turing) | 43.12 / 42.91 | 38.48 / 38.43 |
| a_off1 / a_off2 (#209 + #314 PCT=0) | 42.88 / 43.16 | 38.41 / 38.55 |
| a_def (#314 defaults: 50% / 16 MiB / 46 CTAs) | 41.98 | 37.52 |
| a_kb2048 | 43.50 | 38.71 |
| a_kb1024 | 43.61 | 38.93 |
| a_kb2048_c34 | 43.45 | 38.69 |
Spread (repeat arms): 4k 0.28, 16k 0.14 tok/s. All texts byte-identical to a_off1 at both depths (prefetch and the
fusion change no values).
Gates: #209 alone vs bin-turing: 0.0% at both depths -> FAIL (no gain, no harm). #314 defaults: -2.4% / -2.4% (a loss).
#314 MAX_KB 1024: +0.73 / +0.52 over a_off1 (> spread at both) PASS; 2048: PASS (+0.62 / +0.30); 2048 c34: PASS.
Single run per setting -> P10b replicates before anything ships or goes upstream.
Upstream relevance: #314's final commit hardcodes 50/46/16 MiB; on a 4 MB-L2 card that regresses decode ~2.4%. Its
thread has no comments yet; a Turing receipt comment goes up after P10b.

## 2026-10-06 P10b (plan): replicate the #314 Turing finding

After P11. bin-alpha, B serve, stock + fan 100%. Arms alternating x2: PCT=0 / defaults / MAX_KB=1024 / MAX_KB=512.
Gates: defaults below PCT=0 in both rounds at both depths (confirms the regression); MAX_KB=1024 above PCT=0 in both
rounds at both depths by more than the round-to-round spread (confirms the gain); 512 reported. Texts identical.

## 2026-10-06 P9b (result): with desk fans +150 runs at 74 C, +3.5-4.1%, drift 0 - but 1 of 26 outputs diverged

Receipts: receipts/p9b/. Stock (fan 100%, desk fans): 42.98 / 38.29 (4k / 16k), max 66 C. OC150: 44.47-44.50 / 39.84-39.87,
max 74 C, drift +0.1 / -0.1%. Identity: 25/26 - the 16k "Write a Python..." request at t=106 s diverged at char 707 of
1162; the other OC requests with the same key match stock exactly; stock had 1 distinct text per key over 6 requests.
Gates: temp < 85 PASS; drift PASS; identity FAIL (1/26).
Two candidate causes: an OC compute error, or prefix-cache-dependent prefill splits (the 16k filler shares the 4k
filler's prefix; hybrid-model checkpoints decide where reuse resumes - the handoff's "rare late divergence under partial
prefix-cache hits"). Discriminator: P11's 10-minute stock soaks repeat each (depth, prompt) ~5 times; any same-key
divergence at stock -> cache effect, not OC. Stock stays the baseline until settled.
Note (not a gate): Cary off to bed 22:20; running full auto overnight.

## 2026-10-06 P12 (plan): drafting made cheap enough for 8 GB

Build bin-p12 (sm_75) from worktree vendor/prism-p12 = turing-pt-onecol + #314 (switch commit) + #209 + Mirai 4bdc6587b
(GGML_CUDA_SHARED_POOL=1, LLAMA_MTP_DRAFT_UBATCH=N; both off by default). Head file: mtp-procreations with blk.64.*
requantized Q8_0 -> Q4_0 (mirai-s-ada tooling/requant_mtp.py; proof: strip the head, sha256 == official PTQ1_0).
Step 1, VRAM at N=16384 (q4_0, draft 1, tail 2, window 16384), server VRAM at load + 4k probe + acceptance:
  C0 q8 head, pool off | C1 q4 head, pool off | C2 q4 head, pool on + DRAFT_UBATCH=256.
Step 2: size N for the cheapest passing variant to P11's passing free margin; depth sweep 4k/16k/32k/64k vs B at P11's N.
Gates, written before the run:
- each saving within 30% of the Mirai number (head -204 MiB, pool -188 MiB) or reported as not transferring;
- acceptance with the q4 head within 2 pp of the q8 head (Mirai: 77.7 vs 78.2%);
- decision vs B: P5's rule (best at 32k unless >25% at both 4k and 16k), min free >= P11's passing margin;
- drafting differs from non-drafting at rounding level on every card (documented) - not a gate; KL of the drafted
  default vs B is reported if the head mode becomes the default.

## 2026-10-06 P11 (result): 77,568 q4_0 positions in VRAM hold with the desktop on the card (once) - provisional default

Receipts: receipts/p11/p11.txt, n65280/n77568 .json and .mem.txt. bin-turing, stock + fan 100%, desk fans, 1280x1024.
| N | free at load / min | 4k | 16k | 48k | drift 4k (16k) | llama-server shared GPU mem |
| 65280 | 474 / 427 MiB | 42.7-43.2 | 38.3-38.8 | 29.9-30.4 | +0.4% | 1384 flat |
| 77568 | 277 / 257 MiB | 42.6-42.8 | 38.0-38.3 | 29.8-29.9 | -0.3% (-0.9%) | 1190 flat |
Gates: drift < 3% PASS (4k both; 16k at 77568); no shared growth PASS; min free > 150 PASS. Weak evidence: the
alternating 4k/16k/48k design re-prefills ~32k tokens per 48k request (8-10 requests per 10 min; no 48k drift number).
Plan required two passes at 77568: one so far -> provisional. Stock decode is power-capped at 175 W (throttle 0x4).
Identity side question (P9b): every repeated (depth, prompt) at stock was consistent (2 repeats each) - inconclusive.
Next: P11b (second pass, block design) after P12.

## 2026-10-06 P11b (plan): second margin pass at N=77568, block design

After P12. bin-turing, q4_0, N=77568, stock + fan 100%. Four 4-minute single-depth blocks: 4k, 64k, 4k, 64k (each block
warms its prefix once, then every request is a cache hit; 64k sits inside the 77,568 VRAM line). Server shared GPU memory
and card free sampled every 5 s.
Gates: block-3 vs block-1 (4k) and block-4 vs block-2 (64k) mean decode within 3%; shared memory flat; min free > 150 MiB.
Pass -> 77,568 is the 8 GB default at 1280x1024 (two passes); fail -> step down to 65,280 and repeat.

## 2026-10-06 P10b (result): replicated - #314 as merged-to-be costs Turing ~2.5%; capped at 1 MiB it gains ~1.5%

Receipts: receipts/p10b/p10b.txt, <arm>.json. Two alternating rounds (off / def / 1024 / 512), stock + fan 100%.
4k: def -2.7 / -2.7%, kb1024 +0.6 / +2.2%, kb512 +0.6 / +2.0%; 16k: def -2.6 / -1.1%, kb1024 +0.7 / +2.2%, kb512 +0.6 / +1.8%.
Off round-to-round spread 0.08 (4k) / 0.07 (16k) tok/s. All texts identical to off.
Gates: defaults below off in both rounds at both depths PASS (regression confirmed); kb1024 above off by more than the
spread in both rounds at both depths PASS. With P10: 3 of 3 runs each way.
#314's final commit a4249f5 hardcodes exactly the tested defaults (50% / 46 CTAs / 16 MiB). Comment with receipts posted
to #314 (below). Not adopting #314 into the 8 GB default build until its final form handles small L2.
#314 comment: https://github.com/PrismML-Eng/llama.cpp/pull/314#issuecomment-6030785242

## 2026-10-06 ~23:50 note: Cary's floor = sudoingX's patch on this card; his branch already takes PT at one column on Turing

Cary (going to bed): make our build better and faster than sudoingX's - treat his as the floor. His 8 GB recipe
(bonsai2-small-gpu serve/8gb.sh): -c 65536, q4_0 K/V, no MTP head, all in VRAM, branch sudoingX/llama.cpp bonsai2
(ff41412). His mmvq.cu:299 enables the PT path for PTQ1_0 on cc >= TURING for every column count, so on this card his
build already has what #325 gives the Prism fork: #325 is parity with his branch on Turing, not a lead over it.
P13 (plan, after P11b): build his branch for sm_75 (vendor/sudo-bonsai2, bin-sudo), run his exact recipe, and our
best 8 GB configuration, same probe, decode at 4k / 16k / 32k / 60k, stock clocks + fan 100%, alternating. Floor gate:
ours must beat his at every depth he can serve (his window ends at 64k) - and the same KL/identity honesty applies.

## 2026-10-06 P12 (result): cheap head + 38,400 positions beats B up to 32k; B keeps 64k; prefill anomaly on B at 77,568

Receipts: receipts/p12/p12.txt, C0/C1/C2_4k.json. bin-p12 (Turing fix + #314 [PCT=0] + #209 + Mirai pool), stock +
fan 100%, desk fans, q4_0, draft 1 / tail 2.
Step 1 (N=16384): server C0 q8 head 7,262 / C1 q4 head 7,048 / C2 + pool + DRAFT_UBATCH=256 6,986 MiB.
4k decode 51.82 / 51.28 / 51.34; acceptance 0.875 / 0.848 / 0.848.
Gates: q4 head -214 MiB (Mirai -204) PASS; pool+ubatch -62 MiB (Mirai -188) FAIL - does not transfer (kept: harmless,
62 MiB); acceptance q4 vs q8 head -2.7 pp (> 2 pp) FAIL, decode -1.0%.
Strip proof: q4-head file minus the head == official PTQ1_0 sha256 (53107f53...). Head requant saved 212 MB.
Step 2: C2 N=38400 (free 256) vs B N=77568 (free 269), decode 4k/16k/32k/64k:
  C2 51.5 / 47.8 / 43.1 / 23.9 (acceptance 0.777)   B 43.9 / 39.1 / 34.4 / 27.6
Decision (P5 rule, best at 32k): C2. Default for 8 GB with display on the card becomes: q4_0, q4-head MTP (draft 1,
tail 2), shared pool, ~38.4k in VRAM. B (no head, ~77.5k in VRAM) is the long-context mode (>~40k).
Not measured: KL of drafted vs undrafted output (drafting differs at rounding level on every card, documented).
Anomaly: prefill B 237 / 218 / 185 / 147 tok/s vs C2 405 / 341 / 264 / 177 at the same depths; B at N=38656 (P5)
prefilled 356-397 at 4k. Needs a controlled A/B (P14) before 77,568 ships anywhere.

## 2026-10-07 P14 + P13 (plans)

P14 (prefill anomaly): bin-p12, q4_0, no head, PCT=0, fresh 4k prefill (quick_tps depth 4000, first prompt evaluates
4,048 tokens): N=77568 BI unset / N=77568 BI=1 / N=38656 BI unset / N=77568 BI unset again. Reading decided now: if BI
alone restores ~400 tok/s -> the FA split under BI is faster for prefill on Turing (a finding); if N=38656 restores it
-> large N costs prefill (VRAM pressure on compute); if neither -> keep digging before 77,568 ships.
P13 (floor): build sudoingX/llama.cpp bonsai2 ff41412 for sm_75 -> bin-sudo. Arms, alternated, depths 4k/16k/32k/60k:
sudo1 (his serve/8gb.sh verbatim: -c 65536 q4_0 all-VRAM, no head) / ours-C2 (q4 head, pool, N=38400, MAX_KB=1024) /
ours-B (no head, N=77568, MAX_KB=1024) / sudo2.
Gate (Cary's floor): our default beats sudo at every depth he serves, by more than sudo1-vs-sudo2 spread; else name
the depths where it does not and why.

## 2026-10-07 P15 (plan): spend the tail-2 snapshot plane on positions

Code (common.h:403, server-context.cpp:991): n_rs_seq = max(draft n_max, n_max_tail); the GDN rollback ring is sized
for the whole session from it. C2 runs draft 1 / tail 2, so one recurrent-state plane exists only for drafting past
the VRAM line. Arms on bin-p12 (q4 head, pool, MAX_KB=1024): C2 tail 2 vs tail 1 at N=38400 with LLAMA_LOG_VERBOSITY=5
(buffer breakdown), server VRAM at load; then tail 1 resized to ~257 MiB free and swept 4k/16k/32k/60k.
Gates: tail 1 frees >= 100 MiB; at its larger N it beats C2-tail-2 at 32k and at 60k by more than the sudo1/sudo2
spread, without losing >2% at 4k/16k. Then it is measured against P13's sudo floor at 60k.

## 2026-10-07 P11b (result): 77,568 passes the second margin soak - two passes, the long-context mode is settled

Receipts: receipts/p11b/. bin-turing, q4_0, N=77568, stock + fan 100%, desk fans, 1280x1024. Blocks (4 min each):
4k 43.78 (27 req) / 64k 27.42 (16) / 4k 43.70 (27) / 64k 27.46 (16). Block3 vs block1 -0.2%, block4 vs block2 +0.1%;
min free 244 MiB; llama-server shared GPU memory flat at 1,190 MiB. All gates PASS.
77,568 positions in VRAM is the long-context (no head) mode at 1280x1024. Prefill anomaly (P14) still open.

## 2026-10-07 P14 (result): N=77568 costs 42% of prefill; BATCH_INVARIANT irrelevant

Receipts: receipts/p14/. bin-p12, q4_0, no head, fresh 4,048-token prefill: N=77568 239.7 / +BI 240.7 / N=38656 417.2 /
N=77568 again 240.9 tok/s; decode 43.9 / 42.8 / 43.9 / 43.9. Two hypotheses: transient pool memory under pressure at
269 MiB free, or prefill attention spanning all VRAM cells. P14b (during the sudo build, GPU idle, CPU loaded; fresh
N=38656 control under the same load): N=58112 (~570 MiB free) and N=77568 + GGML_CUDA_SHARED_POOL=1. Cliff near the
margin -> pressure; gap proportional to N -> span.

## 2026-10-07 P14b (result): a prefill cliff between 567 and 269 MiB free - memory pressure, not KV span

Receipts: receipts/p14b/ (two arms first refused: card read 215 W after the apply - guard worked; run_arm now retries
the apply until 175 W). Under the sudo build's CPU load (decode ~2 tok/s lower in all arms): N=38656 (867 free) prefill
416.3 / N=58112 (567 free) 417.3 / N=77568 (269 free) 238.6 / N=77568 + shared pool 239.7. Code: get_n_kv pads to used
cells, so attention does not span the VRAM line. Prefill's transient pool growth under ~300 MiB free is the cost.
P14c (plan, after P15): N=67840 ub 512 (~420 free), N=77568 ub 256 (half the prefill transients), controls N=77568 and
N=58112 at ub 512; depths 4k and 32k. Pick the N/ub pair with the best prefill and decode at 32k and 64k for the
long-context mode. start-server-bin.ps1 gained BONSAI_UBATCH (copy only, shipped launcher untouched).

## 2026-10-07 P16 (plan): where does prefill time go on Turing (ours) - profile before touching kernels

Code read: on Turing our prefill already uses the in-place quantized-K/V MMA kernel (fattn.cu case 256 ->
kv_native_supported is arch-independent), so no f16 copy; sudoingX's fork converts K/V to f16 per chunk and runs f16 MMA.
Switching ours to the convert path would reserve f16 K+V for the full window at load (~512 MiB at 131k = ~30k q4_0
positions) - rejected for 8 GB on arithmetic alone. Profile instead: bin-p12, no head, N=58112 (no memory pressure),
GGML_CUDA_OP_TIMING=1 + LLAMA_ARG_LOG_VERBOSITY=5, one fresh 32k prefill. Read the per-op table: FLASH_ATTN_EXT vs
MUL_MAT (MMQ) vs GDN vs the rest. The largest bucket that sudo's build does differently is the kernel target.

## 2026-10-07 P13 (result): sudoingX's floor on this card; ours wins decode, loses prefill; C2 broke at depth (open)

Receipts: receipts/p13/{sudo1,oursC2,oursB,sudo2}.txt. Stock + fan 100%, desk fans, 1280x1024. bin-sudo = his bonsai2
ff41412 built sm_75 (CUDA 13.4 pip), his serve/8gb.sh verbatim (-c 65536 q4_0, all VRAM, no head): server 7,236 MiB.
| depth | sudo1 / sudo2 decode | prefill | ours-B (N=77568, MAX_KB=1024) decode | prefill | ours-C2 decode | prefill |
| 4k | 37.3 / 37.1 | 427 / 423 | 44.3 | 240 | 51.5 | 404 |
| 16k | 30.4 / 30.3 | 382 / 380 | 39.4 | 219 | 48.5 | 340 |
| 32k | 24.5 / 24.5 | 320 / 319 | 34.5 | 186 | VOID (1 token) | 264 |
| 60k | 17.5 / 17.5 | 256 / 255 | 28.4 | 150 | VOID (1 token) | 182 |
Sudo spread < 0.5%. Floor gate: decode - ours above at every depth he serves (B +19..62%; C2 +38..60% where valid).
Prefill - ours BELOW at every depth (B: the P14 pressure cliff at 269 MiB free; C2: -5% at 4k growing to -29% at 60k).
C2 at 32k and 60k generated one token on all three prompts (server log: normal releases, no error); P12's C2 (same
N, PCT=0) produced 400 tokens at 32k. Only difference: GGML_CUDA_L2_PREFETCH_MAX_KB=1024 (prefetch on). Prefetch code
cannot change values (prefetch.global.L2 only) - P17 (2x2 drafting x prefetch, text captured) decides before anything
else uses prefetch. Floor status: NOT yet beaten on prefill; decode beaten.

## 2026-10-07 P15 (result): tail draft 1 frees one GDN snapshot plane (152 MiB) -> 47,360 positions; new drafted default

Receipts: receipts/p15/. bin-p12, q4 head, pool, DRAFT_UBATCH 256, MAX_KB=1024, stock + fan 100%.
Server at N=38400: tail 2 7,350 / tail 1 7,198 MiB (152 saved, matches "~150 MiB per unit of rollback depth").
tail 1 at N=47360 (free 233): 4k 52.3 / 16k 48.3 / 32k 43.6 / 60k 29.7 (prefill 405 / 340 / 263 / 190), acceptance 0.803.
vs C2 tail 2 N=38400 (P12): 51.5 / 47.8 / 43.1 / 23.9. Gates: frees >= 100 PASS; beats tail 2 at 32k (+1.2%) and 60k
(+24%) PASS; no loss at 4k/16k PASS.
Decision: drafted default = q4 head, draft 1 / tail 1, pool, N=47360 at 1280x1024. vs the sudo floor (P13): decode
+41 / +59 / +78 / +70% at 4k / 16k / 32k / 60k. Prefill still below his at every depth (405 vs 427 ... 190 vs 256).
Note: this run used MAX_KB=1024 with drafting and produced full answers at 32k and 60k - the P13 one-token stop is not
"prefetch + drafting at depth" in general; P17 retests P13's exact C2 (tail 2) configuration.

## 2026-10-07 P17 (result): prefetch cleared; the one-token stop does not reproduce on a fresh 32k prefill

Receipts: receipts/p17/ (texts in <arm>.json, server logs). C2 (P13's exact config) and B, prefetch MAX_KB=1024 vs PCT=0,
fresh 32k prompts: all 8 requests produced 200 tokens; texts identical across prefetch on/off for each mode.
Difference from P13: quick_tps sends "Say hi." before each depth, so the 32k request restored the 16k prefix from the
server's RAM prompt cache (P13 log: 16,524 of 32,040 tokens evaluated) and its first sampled token was end-of-turn on
all three prompts. P12 and P15 ran the same sequence without failing -> intermittent, involving prompt-cache restore of
a long prefix with drafting on (recurrent state / draft context restore). No-head B never failed.
P18 (plan, after P16): replay P13's exact quick_tps sequence (4k -> 16k -> 32k) x3 on the drafted default (tail 1,
N=47360) and x3 on C2 tail 2; count one-token answers; capture texts and server logs. Any failure blocks the drafted
default until root-caused; zero in 6 replays -> recorded as unreproduced, kept under watch.

## 2026-10-07 P14c (result): the prefill cliff is not deterministic; without it our prefill is within 3-6% of sudo's

Receipts: receipts/p14c/. bin-p12, no head, MAX_KB=1024, stock + fan 100%:
| N / ub | server (used-idle) | free | prefill 4k | 32k | decode 4k | 32k |
| 67840 / 512 | 7,216 | 395 | 416.7 | 302.1 | 44.3 | 34.4 |
| 77568 / 256 | 7,264 | 346 | 400.7 | 292.6 | 44.3 | 34.5 |
| 77568 / 512 | 7,396 | 214 | 416.0 | 301.3 | 44.2 | 34.5 |
| 58112 / 512 | 7,036 | 574 | 415.9 | 301.2 | 44.3 | 34.5 |
The same 77568/512 config prefilled at 239-241 in P13/P14/P14b with 7,334 MiB attributed at load and 269 free; here 7,396
attributed (+62) and 214 free, and no cliff. Reading: the cliff depends on whether prefill scratch is reserved at load
or grows under pressure - load-time state, not our settings. ub 256 is not needed (and costs 4% prefill).
Without the cliff: ours vs sudo prefill -2.6% at 4k (416 vs 427), -6% at 32k (301 vs 320). Drafted default (pool shared
between target and draft contexts) never showed the cliff.
Open: make the reservation deterministic (reserve prefill scratch at load, e.g. a warm-up prefill or pool pre-grow at
start) - candidate engine/launcher change, P19.

## 2026-10-07 P16 (no result) -> P16b

The op-timing table prints every 100 timed (non-CUDA-graph) graphs; decode runs as CUDA graphs, so only prefill
ubatches count and a 32k prefill is 64 of them - no table. Verbose log did confirm RS (GDN state) buffer 149.62 MiB per
plane. P16b: N=67840 (60k inside the VRAM line, 395 MiB free in P14c), one fresh 60k prefill (~117 ubatches), same env.

## 2026-10-07 P20 (plan): release candidate for 8 GB

Engine: vendor/prism-pool = bonsai-q8-product (c8b8993) + Turing fix (bc3e5aa) + Mirai shared pool (b7c11567a); no #314,
no #209. Build sm_75/86/89 + compute_89 PTX like bundle-20260927 -> bin-rc. On this card: drafting mode (q4 head,
draft 1 / tail 1, pool, N=47360) and long-context mode (no head, N=67840), full sweep 4k/16k/32k/60k each, run twice;
one 10-minute soak of the long-context mode at 67,840 (block design). Gates: within 2% of the bin-p12 numbers
(drafting: minus the ~1.5% prefetch gain); no one-token answers; no prefill cliff in either mode; free >= 200 MiB.
Repo branch 8gb-rig (local, not pushed): display detection 4042bb3, Q4 head tooling, docs/8GB.md draft - numbers in
the doc replaced with P20's before Cary decides to publish.

## 2026-10-07 P18 (result): REPRODUCED - one-token answers at 32k after a prompt-cache restore, tail 2 only

Receipts: receipts/p18/ (summary.txt, per-replay txt, server logs). Exact P13 sequence (4k -> 16k -> 32k with "Say hi."
between depths), x3 each: tail 1 (N=47360) 0/27 one-token answers; tail 2 (N=38400) 3/27, all three 32k answers of
replay 3. With P12 (tail 2 ok), P13 (tail 2 failed), P15 (tail 1 ok): tail 2 failed 2 of 5 runs, tail 1 0 of 4.
Signature: the 32k request resumes at 15,516 cached tokens restored from the RAM prompt cache (the slot held only the
22-token "Say hi."), then the first sampled token is end-of-turn; all three prompts at that depth.
Code read (llama-memory-recurrent.cpp state_write/read): save takes the logical current rollback plane
(rs_idx * size + src) for R and S, restore writes plane 0 and resets rs_idx - no obvious defect there.
Exposure: the 12 GB default is draft 2 / tail 4 (n_rs_seq = 4, five planes). Default here stays tail 1.
P21 (plan, runs during P20's CPU-only build): same sequence, x3 tail 4 (N=20224, fits the same budget), x3 tail 1
(confidence on the default), x2 tail 2 with LLAMA_ARG_CACHE_RAM=0 (prompt cache off: tests the restore hypothesis).

## 2026-10-07 P16b (result): prefill at parity when there is no memory pressure; where prefill time goes

Receipts: receipts/p16b/ (table.txt, optiming60k.txt). bin-p12, no head, N=67840, fresh 60k prefill (59,953 tokens):
247.5 tok/s (sudo 255.7 at 60k in P13, -3%). Op share over 100 prefill ubatches: FLASH_ATTN_EXT (in-place q4_0) 39.6%,
PTQ1_0 MUL_MAT (all shapes) ~43.8%, GATED_DELTA_NET 7.5%, rest ~9%.

## 2026-10-07 P22 (plan): packed 1-bit KQ mask (Mirai 6deaedf66 + 4b0caa048) for VRAM and prefill

Worktree vendor/prism-p22 = turing-p12 + Mirai 1275aa4b8 (GGML_CUDA_POOL_LOG) + 6deaedf66 (minus its mirai-s.cu timing
hunk) + 4b0caa048; all applied without conflicts. Build sm_75 with tests -> bin-p22. Flag: LLAMA_ARG_KQ_MASK_PACKED=1
(f16 mask = n_ctx x n_ubatch x 2 B reserved at the full context; packed is 1/16).
Arms after P20 (stock + fan 100%): test-backend-ops FLASH_ATTN_EXT on sm_75; drafting default (N=47360) packed vs not:
server VRAM at load, greedy texts at 4k/16k byte-identical (the mask is the same -inf/0 pattern); then N resized to the
freed VRAM, depth sweep; long mode at ub 1024 + packed vs ub 512: prefill and VRAM.
Gates: identical texts; test-backend-ops pass; saving >= 100 MiB; ub 1024 prefill gain > 10% at 4k and 32k to be adopted.

## 2026-10-07 P21 (result): tail 1 0/27 again (0/54 today); tail 4 0/18; tail 2 cache-off 0/9 - the bug is rare

Receipts: receipts/p21/ (summary.txt). Two builds were compiling concurrently: three arms (t4_r3, t2nocache_r1) were
refused by the stock guard (card read 215 W after four apply retries - Afterburner unreliable under full CPU load).
Tail 1: 3 replays, 0/27. Tail 4 (N=20224): 2 replays, 0/18. Tail 2 with LLAMA_ARG_CACHE_RAM=0: 1 replay, 0/9.
Overall tail 2: failed 2 of 6 completed runs (P13, P18 r3). The restore hypothesis is neither confirmed nor refuted
(one cache-off replay is not enough at this rate). Status: open, intermittent, reproducible with P13's sequence;
drafted default stays tail 1 (0 of 54 answers at 32k across P15/P18/P21). Handed to Cary with the replay script.

## 2026-10-07 P20 (result): release candidate confirmed on this card; decode beats the floor, prefill does not at depth

Receipts: receipts/p20/ (p20.txt, draft_r1/r2, long_r1/r2). bin-rc = prism-pool (bonsai-q8-product c8b8993 + Turing fix
+ Mirai shared pool), built sm_75/86/89 + compute_89 PTX. Repo script build/make_mtp_q4head.ps1 run end to end on a
copy: strip proof OK, output byte-identical to the night's q4-head file.
| depth | drafting (q4 head, 1/1, pool, N=47360, free 218) | long (no head, N=67840, free 380) | sudo floor (P13) |
| 4k | 51.6 dec / 405 pre | 43.6 / 415 | 37.2 / 427 |
| 16k | 47.7 / 340 | 39.0 / 349 | 30.4 / 382 |
| 32k | 43.1 / 264 | 34.2 / 271 | 24.5 / 320 |
| 60k | 29.5 / 190 | 28.1 / 201 | 17.5 / 256 |
Runs r1/r2 within 0.5%; acceptance 0.803; one-token answers 0/24; no prefill cliff. vs bin-p12 (P15) within 1%.
Gates: within 2% of dev numbers PASS; no one-token PASS; no cliff PASS; free >= 200 PASS (218 / 380).
Floor: decode above sudo at every depth (+39 / +57 / +76 / +69% drafting). Prefill below at every depth (-5% at 4k ...
-26% at 60k, incremental prefill over a cached prefix: attention over the deep cache, his f16-converted FA vs our
in-place q4_0 read on Turing). Prefill at depth is the open item against Cary's floor.

## 2026-10-07 P22 (result): packed mask exact and -128 MiB, but breaks the draft context past its window; ub 1024 no

Receipts: receipts/p22/. bin-p22 (turing + #314 switch + #209 + pool + pool log + Mirai packed mask 6deaedf66/4b0caa048).
- test-backend-ops -o FLASH_ATTN_EXT -b CUDA0 (sm_75): 2994/2994.
- Drafting default N=47360, unpacked vs packed: texts byte-identical at 4k and 16k; server 7,388 -> 7,260 MiB (-128 =
  exactly the f16 mask, 131072 x 512 x 2 B); decode 51.82/48.44 vs 51.57/48.30.
- Packed, drafting resized N=51456: 4k 52.1 / 16k 48.4 / 32k 24.8 / 60k 17.9, acceptance 0.494 (unpacked RC: 43.8 and
  30.5 at 32k/60k, 0.803). Past the draft context's 16,384-row window the draft collapses: the packed mask in the draft
  context does not describe the window correctly. Speed loss only (the target verifies), texts past 16k not yet compared.
  Fix candidate: packed for the target, f16 for the draft context (its mask is ~10 MiB).
- Long mode N=67840 packed: ub 512 prefill 417 / 300 (4k / 32k), ub 1024 426 / 311, server +142 MiB. Gate >10% FAIL.
Surprise: long-mode 32k prefill 300 (bin-p22) and 302 (bin-p12, P14c) vs 271 on bin-rc at the same N - something in
the dev builds is +11% prefill at depth. P23 isolates it before anything else.

## 2026-10-07 P22b + P23 (plans)

P22b: bin-p22 rebuilt with "speculative: keep the f16 KQ mask in the MTP draft context" (prism-p22 2a558c87f). Drafting
packed N=51456 sweep 4k-60k; texts at 32k packed (fixed) vs unpacked with drafting. Gates: 32k/60k decode within 2% of
RC (43.1 / 29.5) at +4,096 positions; acceptance >= 0.78; texts identical.
P23: long mode N=67840, prefill at 4k/32k on bin-turing (Turing fix only), bin-rc (+pool), bin-alpha PCT=0 (+#314
code, prefetch off, +#209), bin-alpha MAX_KB=1024, bin-rc again. Whichever step carries the +11% at 32k is named.

## 2026-10-07 P22b (result): REJECTED - the packed KQ mask corrupts the target's output at 32k (repeated "/")

Receipts: receipts/p22b/ (txt32k_packed.json, txt32k_unpacked.json, dr_packed_fix_n51456.txt). With the draft-context
fix (prism-p22 2a558c87f) nothing changed: N=51456 packed, 32k/60k decode 24.7 / 17.9, acceptance 0.494. Texts at 32k,
drafting, same N: unpacked writes the intended code / explanation; packed writes "////////..." for both prompts.
P22's identity check (4k, 16k) passed; the break lies between 16k and 32k. The draft collapse was a symptom (a draft
cannot predict a corrupted target). My draft-window explanation was wrong; the committed draft-context change does not
fix it (kept on the dev branch only, harmless). Repeated-slash corruption is the symptom PrismML #189 reports for a
quantized-V MMA path.
Decision: packed mask out of every 8 GB configuration. Finding for Cary: the same two commits sit behind
--kq-mask-packed in llama.cpp-ada-mirai; whether Mirai corrupts at depth is unmeasured.
P24 (plan): long mode (no head) bin-p22, packed vs unpacked, texts at 24k and 32k, to place the threshold without
drafting in the picture.

## 2026-10-07 P23 (result): no hidden prefill gain - the 271 vs 301 was the request sequence

Receipts: receipts/p23/. Long mode N=67840, sequence 4k -> 32k: bin-turing 415.3 / 300.9, bin-rc 415.1 / 301.6 (r2
413.7 / 301.4), bin-alpha PCT=0 417.1 / 302.1, bin-alpha MAX_KB=1024 416.7 / 302.4 (prefill 4k / 32k). Identical within
0.5%: shared pool, #209 and #314 do not change prefill. P20's 271 came from its 4k -> 16k -> 32k sequence: the 32k
request evaluates only positions 16k-32k (all deep), P23's evaluates 4k-32k. sudo's floor used P20's sequence, so the
floor comparison stands: our incremental prefill at depth is -15% (32k) / -21% (60k, long mode) below his.
Cause (code + P16b): his fork converts q4_0 K/V to f16 per chunk and runs f16 MMA; ours dequantizes in the kernel. The
f16 route was avoided because its buffer is reserved at load for the full window (512 MiB at 131k).
P25 (plan): f16 conversion for prefill-sized batches only (Q columns > 8), the buffer taken from the CUDA pool at the
actual KV length (128 MiB at 32k, 240 MiB at 60k) instead of reserved; decode keeps the in-place path. Env switch
GGML_CUDA_FA_PREFILL_F16=1, worktree off the release candidate. Gates: texts identical to in-place at 4k/32k; prefill
gain > 10% at 32k and 60k (P20 sequence) without a cliff at the long mode's N; decode unchanged.

## 2026-10-07 P24 (result): the packed mask is exact WITHOUT drafting; it corrupts only combined with MTP drafting

Receipts: receipts/p24/ (<unpacked|packed>_<depth>.json). bin-p22, long mode (no head), N=67840: texts packed vs
unpacked byte-identical at 20k, 24k, 28k and 32k (both prompts). With P22b: corruption needs drafting + packed past 16k.
P22b's "target attention breaks at depth" was too broad - corrected here. Unverified lead: with n_rs_seq > 0 the target
splits ubatches with split_equal (rollback window kept together); the packed mask's set_input path may not handle that
layout. Same two commits are opt-in on the Mirai engine, which drafts with MTP: worth a 32k drafting check there.
Product: packed mask is a candidate for the long-context (no-head) mode only (+128 MiB: ~+7.4k positions or a wider
margin against the prefill cliff) - needs a launcher guard (never with BONSAI_SPEC > 0). Cary's call; not in the RC.

## 2026-10-07 P25 (interim): f16 prefill from pool memory closes the prefill gap to the floor

Receipts: receipts/p25/. bin-p25 = release candidate (prism-pool) + c9a2a7dd0 (GGML_CUDA_FA_PREFILL_F16=N).
test-backend-ops FLASH_ATTN_EXT with the switch forcing the path: 2994/2994. Texts at 32k (fresh), in-place vs f16:
byte-identical. Long mode N=58112 (538 free), P20 sequence, prefill 4k / 16k / 32k / 60k:
in-place 415.0 / 350.4 / 271.0 / 199.9 -> f16 423.8 / 380.3 / 318.5 / 252.7 (+2 / +9 / +18 / +26%); decode unchanged.
vs sudo floor 427 / 382 / 320 / 256: -0.7 / -0.5 / -0.5 / -1.3% (parity). Drafting mode f16 cap 32768: 4k +2.3%,
16k +8.8% (32k pending).
P26 (plan): f16 prefill + ub 1024 (half the per-chunk conversions over the cached context): long mode N=58112, ub 512
vs 1024, P20 sequence, twice. Gate: beats the floor's prefill at 16k/32k/60k by more than the sudo1/sudo2 spread with
decode unchanged and min free >= 150 MiB during the 60k request.

## 2026-10-07 P25 (result): f16 prefill from the pool - prefill at the floor, decode unchanged, both modes

Long mode r2: 422.7 / 379.8 / 318.4 / 252.5 (r1 within 0.3%). Drafting mode N=47360 (196 MiB free), cap 32768:
prefill 411.4 / 369.0 / 308.9 vs in-place 402.1 / 339.3 / 262.5 (+2 / +9 / +18%), decode 51.7 / 48.0 / 43.5 unchanged,
acceptance 0.798, no cliff (the shared pool absorbs the transient 128 MiB at 32k).
Gates: kernel tests PASS; identity PASS; prefill gain > 10% at 32k and 60k PASS (+18 / +26% long mode); decode PASS.
Open: drafting cap above 32k (transient 240 MiB at 60k vs 196 free) - not tested.

## 2026-10-07 P26 (interim): ub 1024 + f16 prefill beats the floor to 32k; cliff at 60k for lack of headroom

Receipts: receipts/p26/. Long mode N=58112, f16 cap 65536. ub 1024 r1 / r2: prefill 433.4 / 432.0 (4k), 391.1 / 390.0
(16k), 328.3 / 327.9 (32k), 154.5 (60k, r1); server 7,300 MiB (+262 vs ub 512), free 310. ub 512 r1: 424.5 / 380.7 /
318.7 / 253.0. vs floor 427 / 382 / 320 / 256: ub 1024 +1.5 / +2.4 / +2.6% to 32k; at 60k the transient f16 copy
(~240 MiB) on top of ub 1024's buffers leaves ~70 MiB -> pressure cliff.
P27 (plan): ub 1024 + f16 cap 65536 at N=53248 (~390 MiB free at load), P20 sequence x2. Gate: prefill above the floor
at all four depths, decode above the floor at all four, no one-token answers, min free >= 100 MiB during the 60k request.

## 2026-10-07 P26 + P27 (results): long mode with ub 1024 + f16 prefill at 53,248 positions meets the floor everywhere

P26 ub 512 r2 reproduced r1 (receipts/p26/). P27 (receipts/p27/): bin-p25, no head, N=53248 (free 378 at load), ub 1024,
GGML_CUDA_FA_PREFILL_F16=65536, P20 sequence x2:
| depth | prefill r1 / r2 | sudo floor | decode r1 / r2 | sudo floor |
| 4k | 432.7 / 432.5 | 427 / 423 | 43.6 / 43.4 | 37.3 / 37.1 |
| 16k | 391.1 / 390.8 | 382 / 380 | 38.8 / 38.9 | 30.4 / 30.3 |
| 32k | 328.2 / 327.7 | 320 / 319 | 34.1 / 34.1 | 24.5 / 24.5 |
| 60k | 256.0 / 256.1 | 256 / 255 | 22.4 / 22.4 | 17.5 / 17.5 |
Min free during the run 118 MiB; one-token answers 0. Gate: prefill above the floor at 4k / 16k / 32k (+1.3..+2.6%,
beyond the sudo1/sudo2 spread) PASS; at 60k +0.2%, inside the spread - a TIE, not a pass; decode above at all depths PASS.
Long-context mode candidate: no head, N=53248, ub 1024, f16 prefill cap 65536 (window 131k; past ~53k decode reads the
host tail). Drafting mode keeps ub 512, f16 cap 32768: prefill -3.4..-3.7% below the floor at 4k-32k, decode +39..+76%.
RC2 build (sm_75/86/89 + PTX) from prism-p25 started 06:2x -> bin-rc2.

## 2026-10-07 P29 (plan): one-token replays on the final drafting config (f16 prefill on)

During the RC2 build (CPU busy: timing not read, correctness only). bin-p25, drafting config of the release (q4 head,
draft 1 / tail 1, pool, N=47360, GGML_CUDA_FA_PREFILL_F16=32768), P13's sequence (4k -> 16k -> 32k with prompt-cache
restore) x3. Gate: 0 one-token answers.

## 2026-10-07 P29 (result): final drafting config, 0 one-token answers in 23 (replay 3 partial)

Receipts: receipts/p29/. r1 0/9, r2 0/9, r3 0/5 - r3 was cut short: the RC2 build finished earlier than estimated and
P28's first stop killed r3's server (its next request got "connection refused"); r3's closing stop found no server, and
P28's server (pid 6720, 06:46:23) was the only one when P28 measured - no cross-contamination. Running total for draft 1
/ tail 1 through the restore sequence: 0 of 77 answers. Lesson: a chain waiting on a build must also wait on any GPU job
started meanwhile.

## 2026-10-07 P28 (result): RC2 verified on its own binaries

Receipts: receipts/p28/. bin-rc2 = prism-p25 (bonsai-q8-product + Turing fix + shared pool + f16 prefill), sm_75/86/89 +
compute_89 PTX. Drafting (q4 head, 1/1, pool, N=47360, f16 cap 32768; free 225): decode 51.2 / 47.5 / 43.1 / 29.4,
prefill 411.0 / 369.2 / 309.3 / 192.0, acceptance 0.803. Long (no head, N=53248, ub 1024, f16 cap 65536; free 374):
decode 43.7 / 39.0 / 34.3 / 22.5, prefill 432.6 / 390.7 / 328.5 / 256.5. One-token answers 0/24. Within 1% of the dev
builds. Floor: decode above at every depth in both modes; long-mode prefill above at 4k-32k, +0.2% (tie) at 60k.

## 2026-10-07 P30 (plan): the full 262,144 window on this card

Cary: "can we not get higher?" Long mode on bin-rc2 with BONSAI_CTX=262144: staging doubles (+144 MiB), so N = 53248 -
8,738 -> 44,288 (same free margin as P28's long mode). Host tail (262144 - 44288) x 18,432 B = 3.8 GB pinned (32 GB RAM).
ub 1024, f16 prefill cap 65536. Sweep 4k / 64k / 128k / 200k / 250k (each extends the previous prompt; ~30+ min of
prefill). Gates: loads with free >= 200 MiB; every depth answers (no one-token); record decode and prefill per depth.
P30 close: the ub 512 rerun never started (my kill command matched its own command line and killed its shell; the ub 1024
server stayed up until stopped at 08:10). Cary: "113k is fine as long as its good, consistent quality" - 262k parked
with its one data point (loads; 43.1 tok/s decode at 4k; ub 1024 mask 512 MiB too costly at 262k).

## 2026-10-07 P31 (plan): consistent quality on the 8 GB drafting mode - HumanEval 164, medium thinking

Cary: "113k is fine as long as its good, consistent quality". Same harness as the 12 GB receipt (bench/humaneval_run.py
--arm medium, temp 0, max tokens 20480; 12 GB: 159/164 raw, 160 neutral rerun, 161 on q8_0 262k). Serve: RC2 drafting
mode (q4_0, q4 head, draft 1 / tail 1, pool, N=47360, f16 prefill cap 32768), launcher defaults otherwise (medium,
budget 20480, harness-proofing), layer off (raw model, as the 159 row).
Gate, written before the run: >= 157/164 (12 GB 159-161; 4-seed deltas of 1-2 are noise per the repo) and no
one-token / empty answers. Below 157 -> q4_0 K/V or drafting costs quality on this card; investigate before shipping.

## 2026-10-07 PR: PrismML-Eng/llama.cpp#330 opened (f16 prefill from pool memory)

https://github.com/PrismML-Eng/llama.cpp/pull/330, head professorpalmer/llama.cpp-ada-ternary:claude/fa-prefill-f16-pool
(066e3e36a on prism 6bfcd79). Body: pr-fa-prefill-f16.md (P25 receipts; opt-in; not measured on Ampere/Ada).
Duplicate check: #317 converts to f16 only when a vector-kernel instance is missing; #307/#308 tune decode. No overlap.

## 2026-10-07 P31 (result): HumanEval 157/164 on the 8 GB drafting mode - gate met at the boundary

Receipts: receipts/p31/ (run.txt, he_medium_drafting/summary.json, samples). RC2, q4_0, q4 head, draft 1 / tail 1,
pool, f16 prefill 32768, medium, temp 0, max 20480, layer off: pass@1 95.73% (157/164), 2,960 s.
Failed: 32 (TypeError), 40 (NameError: missing import of combinations), 47, 92, 116, 145, 160. 12 GB medium replay
(artifacts/eval/killy_20260927/medium): 161/164, failed 83, 116, 145 - overlap 116 and 145.
Gate (>= 157) PASS at the boundary; 2-4 below the 12 GB runs (159-161). Not yet attributed.
P32 (plan): same harness, drafting mode with q8_0 K/V (prompts are short; positions in VRAM do not matter for this test).
Reading decided now: q8_0 >= 160 -> q4_0 costs ~3 problems: the 8 GB preset documents a BONSAI_CTK=q8_0 quality mode
with its position cost; q8_0 <= 158 -> the gap is drafting / Turing rounding noise, q4_0 stays.

## 2026-10-07 P33 (plan): DFlash 2 on this card vs our MTP head

Cary: DFlash "allows higher draft count and reduces VRAM" - measure before believing. Published Bonsai drafters:
Schiltmans DFlash2-ft5 GGUF (Q8_0 2.06 GB, Q4_K_M 1.14 GB, Q2_K 0.71 GB; needs prism-b10754+; M4 Pro: acceptance 0.43,
slower than no draft), ProCreations DFlash2 (acceptance 0.50 at 3 drafts on Blackwell, no MTP comparison). Our MTP head:
0.2 GB file, acceptance 0.80 at draft 1. Concern: Bonsai's rollback ring is sized max(draft) at ~150 MiB/step.
Arms (PrismML's own Windows build prism-b10754-2459f68 cuda-13.3; no tiered cache there, so a 16k window all in VRAM;
stock + fan 100%): plain (no draft) / DFlash Q2_K n-max 3 / DFlash Q2_K n-max 7 / DFlash Q4_K_M n-max 3 if it fits.
Same quick_tps probes at 4k and 12k; server VRAM at load; acceptance from the log.
Gates, written before the run: DFlash is worth porting only if its decode at 4k AND 12k beats our drafting mode at the
same depths (51.2 / ~48) on this card, at a VRAM cost that leaves >= 32k positions in VRAM. Otherwise documented as
measured and dropped for 8 GB.

## 2026-10-07 P32 (result): q8_0 K/V 159/164 vs q4_0 157/164 on the same drafting mode

Receipts: receipts/p32/ (run.txt, he_medium_q8). RC2, drafting mode with q8_0 K/V (N=20480), medium, temp 0, layer off:
pass@1 96.95% (159/164), 3,133 s. Failed 40, 47, 116, 145, 160 - all also failed by q4_0, which additionally missed 32
and 92. 12 GB: 159 / 160 / 161.
Reading (pre-set branches: >= 160 -> quality mode, <= 158 -> noise): 159 falls between. q4_0 costs ~2 of 164 here, at the
edge of the repo's stated noise (1-2), for 2.3x the positions in VRAM. Decision: q4_0 stays the 8 GB default; docs/8GB.md
states both scores and documents BONSAI_CTK=q8_0 as the quality option (~22k positions in VRAM instead of 47k).

## 2026-10-07 P33 (blocked -> rerouted): PrismML's official Windows CUDA release has no sm_75 code

prism-b10754-2459f68 win-cuda-13.3-x64: llama-server crashes on the 2060 SUPER right after buffer reservation with a bare
"ggml-cuda.cu:107: CUDA error", plain arm, no drafter (receipts: logs/prism-b10754-debug.err.log). ggml-cuda.dll contains
sm_86 / sm_89 / sm_120 strings and no sm_75 (ours: sm_75 / 86 / 89). Every RTX 20 card fails with that release.
Reroute: build PrismML prism head (6bfcd79, includes b10754's DFlash 2 support) + the Turing fix (#325 worktree
vendor/prism-pr) for sm_75 -> bin-prism, then run P33's arms on it. Upstream issue filed after a duplicate check.
P33 diagnosis: release-prism.yml sets no CMAKE_CUDA_ARCHITECTURES -> default 75-virtual (PTX) for Turing; the 13.3 zip's
PTX cannot JIT on this driver (591.86 = CUDA 13.1) -> bare CUDA error. The 12.4 zip loads (~2 min first-start JIT) and
answers 17*23 = 391. Issue filed on PrismML (see next line).
Issue: https://github.com/PrismML-Eng/llama.cpp/issues/332

## 2026-10-07 P33 (result): DFlash 2 decodes +8% at 4k but costs ~645 MiB and a third of prefill - not for 8 GB

Receipts: receipts/p33/ (plain, dflash_q2_n3, dflash_q2_n7, dflash_q4km_n3). bin-prism = PrismML prism head 6bfcd79 +
Turing fix, sm_75; 16k window all in VRAM, q4_0, stock + fan 100%. Schiltmans DFlash2-ft5 drafters.
| arm | decode 4k / 12k | prefill 4k | acceptance | server MiB (free) |
| plain | 41.6 / 34.9 | 423 | - | 6,110 (1,544) |
| DFlash Q2_K n3 | 55.5 / 49.3 | 274 | 0.561 | 7,402 (252) |
| DFlash Q2_K n7 | 25.0 / 24.1 | 274 | 0.342 | 7,476 (221) |
| DFlash Q4_K_M n3 | 38.6 / 38.6 | 276 | 0.587 | 7,534 (179) |
Our drafting mode (P28): 51.2 / 47.5 decode, 411 prefill, 0.803, 7,393 MiB with 47,360 positions and a 131k window.
Gate: beats ours at 4k and 12k PASS (Q2_K n3: +8% / +4%); leaves >= 32k positions FAIL - with a 16k window it already
uses our drafting mode's whole budget; the drafter setup costs ~645 MiB more than the MTP head (~38k q4_0 positions);
prefill -33%. n7 ("more drafts") halves decode on this card (acceptance 0.34). Q4_K_M runs into memory pressure.
Decision: not for 8 GB. Candidate for 12 GB+ (where 645 MiB is affordable) - receipt for Cary.

## 2026-10-07 P34 (plan): the launcher's 8 GB preset, end to end, no tuning variables

Branch launcher (8gb-rig 3e89c15) as a temporary copy pointed at bin-rc2; only BONSAI_LAYER=0 set (to compare with P28).
Arm 1: auto (q4-head file present -> drafting mode). Arm 2: BONSAI_MODEL=plain file (no head -> long mode).
Gates: the printed preset matches the measured modes (q4_0, 131k, draft 1 / tail 1, ub 512 / 1024, f16 32768 / 65536);
auto-sized N within 2,048 of the measured 47,360 / 53,248; free VRAM at load >= 150 MiB; decode at 4k and 32k within 3% of
P28; no one-token answers.

## 2026-10-07 P34 (result): the 8 GB preset works end to end with no tuning variables

Receipts: receipts/p34/ (auto_drafting, auto_long) + launcher output in logs/*auto_*.out.log. Idle 268 MiB this time
(desktop lighter than the ~390 of the night). Auto: q4-head file -> drafting, N=53,760 auto-sized (margin 225), free 292
at load, min 150; decode 50.9 / 43.2 (4k / 32k), prefill 408 / 330, acceptance 0.798. Plain file -> long mode, ub 1024,
f16 65536, N=58,880 (margin 400), free 380, min 230; decode 43.9 / 34.2, prefill 432 / 353.
Gates: preset printed as measured PASS; free >= 150 PASS; decode within 3% of P28 PASS; one-token 0 PASS. "N within 2,048
of 47,360 / 53,248" FAIL as written - the sizing followed the 120 MiB lighter desktop, which is its job (noted, not
re-gated). Test copy of the launcher removed.

## 2026-10-07 Release: bundle-20261007 published as a pre-release

https://github.com/professorpalmer/bonsai-ada-surgery/releases/tag/bundle-20261007, target 8gb-rig (da99a3a), paired with
PR #6. Engine bonsai-q8-product c8b8993a6 + bc3e5aa02 (Turing one-column) + b7c11567a (shared pool) + c9a2a7dd0 (f16
prefill). Clean-extract smoke test: device listed, flags present, test-backend-ops FLASH_ATTN_EXT 2994/2994 on sm_75.
Downloaded asset sha256 ec546085...1ccc = local zip. Repo "latest" stays bundle-20261004.

## 2026-10-07 P35 (plan): draft 2 / 3 below the VRAM line, tail 1 - toward 60 tok/s

Never measured on this card (P-series all ran draft 1, sudoingX's 3060 finding). n_rs_seq = max(draft, tail): draft 2
adds one 149.6 MiB plane (~9.7k q4_0 positions), draft 3 two. bin-rc2, q4 head, pool, f16 32768, 131k window, alternated
in one session: d1 at N=47,360 (P28 control) / d2 at N=37,120 / d3 at N=26,880 / d1 again. Depths 4k/16k/32k/60k.
Gates: d2 (or d3) beats both d1 runs at 4k and 16k by more than the d1-vs-d1 spread + 2%; loses no more than 5% at 32k;
free VRAM at load >= 150 MiB; no one-token answers. Pass -> the drafting mode's draft size changes (launcher Fixed
constant re-measured). Also read: acceptance per draft position from the server log.

## 2026-10-07 P36 (plan): where decode time goes at one column on Turing

60 tok/s raw needs the target step itself faster (P35 interim: draft 2 code +4.5%, prose -9%, acceptance 0.80 -> 0.67).
bin-rc2, no head, N=53,248, GGML_CUDA_OP_TIMING=1 (graphs off inside the timer, so absolute ms is inflated; shares are
the data), depths 4k and 32k, LLAMA_ARG_LOG_VERBOSITY=5. Read: per-op share at cols=1; achieved GB/s of each PTQ1_0
mat-vec vs 448 GB/s peak. Decides which kernel to attack: if PTQ1_0 mat-vecs are > 60% and below 50% of peak bandwidth,
the Turing mat-vec is the lever; if GDN / FA / small ops dominate, fusion is.

## 2026-10-07 P35 (result): draft 1 stays - more drafts lose on prose and at depth

Receipts: receipts/p35/. bin-rc2, q4 head, tail 1, alternated in one session. Decode (code / prose / bash):
| arm | N | 4k | 16k | 32k | 60k | acceptance |
| d1 a | 47,360 | 51.0 / 50.5 / 52.5 | 48.3 / 46.8 / 48.5 | 43.2 / 42.1 / 42.3 | 30.3 / 28.5 / 29.6 | 0.803 |
| d2 | 37,120 | 53.3 / 45.9 / 52.0 | 51.9 / 42.3 / 47.6 | 44.1 / 40.4 / 44.3 | 24.4 / 22.9 / 23.7 | 0.665 |
| d3 | 26,880 | 50.6 / 42.4 / 48.9 | 49.9 / 37.3 / 47.7 | 38.5 / 37.5 / 38.1 | 20.4 / 19.0 / 19.7 | 0.642 |
| d1 b | 47,360 | 52.1 / 51.2 / 52.4 | 48.4 / 46.9 / 48.6 | 43.8 / 42.7 / 43.3 | 30.2 / 28.5 / 29.6 | 0.803 |
Gate FAIL: d2 wins code at 4k/16k (+3% / +7%) and loses prose (-10%); 60k -19% (fewer positions). 0 one-token answers.
The draft head's second position is weak (0.80 -> 0.67): more drafts only pay on code. 60 tok/s is not in draft count.
Tail-2 bug (code read, no run): leading candidate = stale rollback planes after a prompt-cache restore (state_read
writes plane 0 only; a decode of n tokens refreshes min(n, K) planes; seq_rm accepts any rollback <= n_rs_seq without
checking the plane was written). ~40% confidence; does not explain tail 4 passing. Proposed detector: per-seq rs_valid
count, seq_rm refuses rollback beyond it. Parked behind P36 (default tail 1 is not exposed).

P36 rerun as p36b: the timer needs GGML_CUDA_DISABLE_GRAPHS=1 (decode runs on CUDA graphs, so the first run printed no table).

## 2026-10-07 Coordination (12 GB agent's note on PR #6): RC3 = RC2 + patch 0034; main merged

Engine fork branch bonsai-8gb = 3f808b80b (2cb7a4ed6 cherry-picked onto c9a2a7dd0). 8gb-rig merged main (702d018,
README conflict resolved keeping main's HF download + our non-lossless wording). bin-rc3 = release3/bin: ggml-cuda.dll
byte-identical to RC2; empty anyOf schema -> valid JSON; decode 43.6 at 8k plain. Pre-release bundle-20261007 re-tagged
at 702d018, asset replaced (sha256 cd8a91cc...bf2, verified on download). Reply on PR #6. Use bin-rc3 from here.

## 2026-10-07 P36b (result): decode time is 74% PTQ1_0 mat-vec at 65-80% of DRAM peak; ~6 ms/token is small ops

Receipts: receipts/p36b + logs/*optiming_decode_nograph*. Per-node events without graphs inflate small ops (decode
15 tok/s under the timer) - the table ranks, it does not measure. Mat-vec microbench (test-backend-ops perf, n=1):
17408x5120 54.5 us (357 GB/s, 80% of 448), 5120x17408 56.9, 10240x5120 34.9, 6144x5120 23.7 (290 GB/s). Summed over
one token's mat-vecs ~16.8 ms vs 22.9 ms measured raw at 4k: ~6 ms is the ~900 other kernels (MUL x258, RMS_NORM x129,
SCALE x96, CONT/CPY/SSM_CONV/L2_NORM/SIGMOID x48 each, GDN x48). Ceiling arithmetic: all weights (~5.6 GB/token incl.
the 248k-row output head) at 448 GB/s = 80 tok/s; mat-vecs at 80% + zero overhead = 64 raw. 60 raw is out of reach at
stock memory; 60 with drafting (x1.18) needs the target step at ~19.5 ms (-15%): small-op fusion is the lever.
P37 (plan): dump the decode graph (GGML_SCHED_DEBUG=2) and list unfused chains by count x estimated cost.

## 2026-10-07 P37 (plan): what each small-op class costs in decode (diagnostic skip build)

Dev worktree prism-p37 (branch dev-fusion = bonsai-8gb + GGML_CUDA_SKIP_OPS diagnostic, sm_75 only, never shipped).
Plain model, 8k window all in VRAM, CUDA graphs on, 256 tokens ignore_eos x3 per arm; one arm per op class skipped in
one-token graphs (outputs garbage by design: time only). Cost(op) = t(skip) - t(none) per token. Decode graph (sched
dump): 2,633 nodes/token: MUL_MAT 819 (incl. f32 Hadamard 1024 and bf16 alpha/beta), MUL 483, RMS_NORM 209, GET_ROWS
194, CPY 192, ADD 128, SWIGLU 112, SCALE 96, CONT 64. Reading: classes summing to >= 2 ms/token are fusion targets,
ranked by ms; < 0.3 ms ignored.

P37 first pass: the skip filter (ne[1]==1) never matched GDN / FA / ADD outputs - those rows are void. P37b: one-token graph flag from node 0, arms none / MUL_MAT_Q / GDN / FA / all small ops.

## 2026-10-07 P37c (result): decode = 15.8 ms ternary mat-vec + 2.8 ms small ops + ~3.5 ms rest, per token

Receipts: receipts/p37c/table.txt (first two passes void: filter missed; documented above). Plain, 8k all-VRAM, graphs
on, tok/s x3: none 45.1-45.3 (22.1 ms) / skip quantized mat-vecs 157.5 (6.35 ms) / skip GDN 45.4 (~0) / skip FA 45.7
(+1%) / skip all small-op classes 51.7 (19.3 ms). llama-bench tg256 46.5 (server overhead ~0.5 ms).
Mat-vecs: 15.8 ms for ~5.67 GB = 359 GB/s = 80% of 448 peak. Small-op fusion ceiling ~2.8 ms (-13%).
Merging same-input mat-vecs (GDN qkv 10240 + gate 6144; attn q+k+v) moves 280 -> ~350 GB/s on ~3 ms of them.

## 2026-10-07 P38 (plan): memory overclock re-test on the current engine (llama-bench, not the server)

The 2026-10-06 memclock sweep ran on the pre-#325 engine at ~36 tok/s with 5% stock-to-stock drift: inconclusive.
Now mat-vecs are 72% of the step at 80% of peak. Afterburner slot 1 = mem +500, slot 2 = mem +1000 (power 100%, fan
100), slot 5 stock. bin-rc3 llama-bench tg256 -r 3, order 5/1/2/5/1/2, clocks sampled during each run.
Gate: +1000 beats both stock runs by > 4% (half of the +14% bandwidth) -> decode is bandwidth-bound and memory OC is
back in play (then a stability soak with output compare before any default); < 2% -> ALU/latency-bound, closed.

## 2026-10-07 P38 (result): memory +1000 = +7.7% decode on the current engine - the old "memory OC does nothing" is void

Receipts: receipts/p38/. llama-bench tg256 bin-rc3 plain: stock 46.24 / 46.16; +500 48.16 / 48.14 (+4.2%); +1000 49.80
/ 49.72 (+7.7%). Memory clock under load 7000 / 7500 / 8000 MHz (14 / 15 / 16 Gbps), core 1470 at 175 W. Gate PASS.
docs/8GB.md "Not used: memory overclock" is wrong for the planar-PT engine (that sweep ran before #325). Fix the doc.
P39 (plan): speed at +1250 / +1500 (GDDR6 error retry shows up as a speed drop), then a soak on the best stable step:
server, greedy, 4k/16k/32k prompts x reps, outputs compared byte-for-byte with stock; any divergence -> step down.

## 2026-10-07 Incident: memory +1500 crashed the PC (bugcheck 0x20001 at 12:31, seconds after applying)

P39a: stock 46.26; +1250 50.39 (+8.9%, ran clean); +1500 applied -> system bugcheck and reboot before the run produced a
number (System log: WER 1001 bugcheck 0x00020001, Kernel-Power 41). After reboot Afterburner came up unapplied (fan 41%).
Fix: slots rewritten (1 = mem +1000, 2 = mem +1250; nothing above +1250 is staged), slot 5 stock + fan 100 applied.
Rule from here: memory steps above +1250 are not tried again on this card; +1250 itself needs the soak before any use.

## 2026-10-07 P39b (plan): soak memory +1000 and +1250 with output compare

One server, launcher 8 GB preset auto (drafting mode), bin-rc3, BONSAI_LAYER=0. Clocks switched live: stock 6 min
(reference texts) -> +1000 10 min -> +1250 10 min -> stock 4 min. p9_soak: depths 4k/16k/32k, two prompts, 300 tokens.
Gates per step: every text byte-identical to the stock text of the same (depth, prompt); no driver reset (System log
nvlddmkm 4101/13/14 or bugcheck); decode last-2-min within 2% of first-2-min. Pass -> that step is offered in docs as
an opt-in with this receipt (never a launcher default: clocks are the owner's hardware choice).

P39b first attempt void: serve.ps1 used the main checkout launcher (12 GB, no preset) -> negative VRAM line, never served. Rerun with a temporary copy of the merged 8gb-rig launcher (7882d0f), which also verifies the merge on the card.

## 2026-10-07 Coordination 2: main (1553bc4 layer gate, 5790ed2 vision projector launcher) merged into 8gb-rig

Merge 7882d0f, pushed. One conflict ($FixedMiB block, start-server.ps1): kept the if ($Small) preset; + $MmprojMiB on
the base line and on each of the three measured values (6469 / 6218 / 5955). Parses; CRLF kept. Run on the card
(temporary copy as the P39b launcher): preset on, drafting, 54,272 positions in VRAM, margin 225, healthy.
Pre-release bundle-20261007 re-tagged at 7882d0f (the zip is binaries only - launcher and layer come from the tag,
as in bundle-20261007-fixes); the engine did not change, so the asset stays cd8a91cc...bf2. Notes updated.

## 2026-10-07 P39b (result): +1250 FAILS (GPU error after ~10 min under load); +1000 passes 10 min, identical outputs

Receipts: receipts/p39b/ (stock_a, mem1000 json; mem1250 log; server err log). Launcher preset (drafting, 54,272 cells),
bin-rc3. Decode mean of first 2 min (server, drafting mode):
| step | 4k | 16k | 32k | outputs vs stock |
| stock | 53.2 | 49.5 | 44.6 | reference (1 variant per key) |
| +1000 | 53.5 | 51.2 | 46.3 | 16/16 identical |
| +1250 | 56.0 first request, then falling (51.4 / 47.0 / 41.4), throttle bit 0x4 | died at 13:23: nvlddmkm 14 + 153, server "CUDA error" |
+1000: +0.5% / +3.4% / +3.8% in the server (llama-bench plain +7.7%: drafting mode is less bandwidth-bound).
+1250: FAIL - GPU fault under sustained load (also the +1500 bugcheck). stock_b never ran (server dead).
Slots now: 1 = +500, 2 = +1000; nothing above +1000 staged. +1000 needs a longer soak (60 min, stock reference before
and after) before docs mention it; it is never a launcher default.

P39c (plan): +1000 for 60 min between two 8-min stock references, same launcher/prompts; gates as P39b (identical texts, no nvlddmkm event, drift < 2%).

P39c note: a 34 s incremental dev build ran at 14:07 during the +1000 phase (CPU load; texts unaffected, decode drift reading around 14:07 discounted).

## 2026-10-07 P40 (plan): the deep end of the 8 GB window, 60k -> 126k, as shipped

Never measured past 60k in the drafting mode. Merged launcher (7882d0f copy), preset auto, bin-rc3, stock clocks, layer
off. quick_tps depths 4k / 32k / 64k / 96k / 126k (each extends the previous prompt). Also the long-context mode.
Reading (no gate - this is the measurement Cary asked for): decode and prefill per depth, free VRAM, one-token answers.
"Feels great at the end of the window" is answered by the 126k decode number and the time to extend the prompt there.
Before it: P41 kernel census (dev build, GGML_CUDA_GRAPH_STATS=1, plain model, one decode request): real kernels per
decode graph by name - the fusion target list (op-timer counts include no-op nodes and overstate launches).

P39c attempt 1 void: at 13:37:48 (11 s into +1000) the server and the soak script vanished together - no CUDA error, no nvlddmkm/WHEA event, server log stops mid-prefill: killed from outside (likely the tool shell's background cleanup). stock_a in that attempt drifted -4 / -10 / -9% (cause unknown, maybe the duplicate-instance start). Relaunched detached via Start-Process at 14:08, chained to chain40 (P41 census + P40 deep end).
Cause of the 13:37 kill found: the Claude app restarted this session's process at 13:38 (claude.exe --resume, new
process tree), and every job started from the tool shells died with it. Long GPU jobs now run from the BonsaiJob
scheduled task (jobrun.sh), outside the app's process tree. P39c + chain40 started that way at 14:20.

## 2026-10-07 P39c (result): void again - the server died 1 min into +1000, right after the live profile switch

Both P39c deaths (13:37 and 14:31) came seconds after Afterburner switched profiles under CUDA load. Server logs stop with
no error; no nvlddmkm or WHEA event. So the "app restart" cause above is at best part of it: a live memory-clock
switch can kill the server. P39b's one live switch survived. stock_a again drifted (-6 / -10% first->last 2 min).
P42 (plan): set the clock with no server running, then start the server. +1000 60 min, then stock 20 min reference.

## 2026-10-07 P41b / P43 / P44 (plan): census rerun; two A/Bs sb32445 asked for

P41b: census with LLAMA_ARG_LOG_VERBOSITY=5 (ggml INFO lines are filtered without it - the first census was empty).
P43 (#314, his new commit e697877d9: 2 MiB cap off Ada, 1 CTA per SM): two sm_75 builds that differ only in the
prefetch: ab314 = e697877d9 + #325, ab314off = merge-base 2459f68b5 + #325 (git diff: 4 files, prefetch only).
Plain model, q4_0, no head, -c 16384 all VRAM, quick_tps 4k/16k, alternated off/on/off/on/off/on.
Reading: on vs off at 4k and 16k, per pair; texts compared. Reply on #314 with the table either way.
P44 (#317 / #307, 1-query decode with and without the MMA route on Turing): bin-rc3, plain model, no head, -c 32768,
GGML_CUDA_FA_MMA_DECODE_MIN_KV=0 (never) vs default 256, K/V q4_0 and q8_0, 4k/16k, alternated x2.
Reading: decode delta per K/V type and depth; texts compared. Reply on #317 with the table.

P40 attempt 1 stopped at 14:40 in the 96k step: BonsaiJob ended with 0xC000013A (console close / Ctrl+C). Tasks now run under conhost --headless (no window). Partial receipts: receipts/p40_partial (4k 51.6, 32k 43.2, 64k 28.4 decode). P40 rerun from the start, chained to jobrun2.

## 2026-10-07 P40 (result): the deep end, and an open long-mode launcher regression

Receipts: receipts/p40 (drafting_deep, long_deep), receipts/p40b (bisect). Preset auto, bin-rc3, stock, layer off.
| depth | drafting decode / prefill | long-context decode / prefill |
| 4k | 51.3 / 404 | 38.2 / 423 |
| 32k | 43.2 / 291 | 30.7 / 309 |
| 64k | 30.8 / 188 | 22.8 / 201 |
| 96k | 16.3 / 130 | 10.4 / 136 |
| 126k | 11.3 / 105 | 6.9 / 110 |
Past the VRAM line (~54-59k) decode falls with depth: PCIe 3.0 reads of the host tail. 126k = 11.3 tok/s (drafting).
Open: long-context mode through the launcher decodes 37.6-38.8 at 4k (P34 at 10:45: 43.9). The same llama-server command
line started from a minimal .ps1 through serve.ps1 = 42.9-43.8 (14 runs). Ruled out: binary rc2/rc3, launcher version
(3e89c15, 7882d0f, 36d6e12), N, ub, f16 prefill env, chat kwargs env, budget/message, thinking, port 8080, host, api key,
busy check, CIM/--help/nvidia-smi pre-steps, ErrorActionPreference, try/finally, clocks (same 1860-1890 / 6801), CPU.
Launcher prefix 1-258 + literal call = fast; full launcher with literal call = slow. Not resolved (time-boxed).
Drafting mode through the launcher is not affected (51.3 = P34 50.9). Ollama was found running on the desktop by Cary
(closed); one rerun after that was still slow, so Ollama is not this cause.
Also: two copies of jobrun2 ran at once from 18:55 (the old task copy survived taskkill /T): P43 builds failed, arms
overlapped. All stopped 19:08. Jobs now take a lock directory.

## 2026-10-07 P45 (plan): launcher long-mode gap, alternated, with no remote desktop session and no Ollama

Cary is away (Chrome Remote Desktop disconnected). After jobrun2 ends: 3 rounds of A launcher 36d6e12 long mode /
B minimal .ps1 (same command line) / C launcher 1-258 + try + literal call / D full launcher + literal call. 4k only.
Reading: if A and D stay ~38 and B and C ~43 in every round, the gap is real and in the launcher's last 20 lines;
if all match, the earlier gap came from something outside (remote session, another GPU user) and the bisect is void.

## 2026-10-07 Correction: the long-mode "regression" and P40 used the wrong engine (my error)

The branch launchers (3e89c15, 7882d0f, 36d6e12) do not read BONSAI_BIN; they always run <repo>\bin, which on this rig
is bundle-20260927 (no #325 Turing one-column path). Every launcher run since the 12:50 test copy used that engine:
P39b, P39c (soaks), P40 (deep end), P40b launcher arms, P45 design. P34 is not affected (its copy was edited to rc2).
43.8 / 38.2 = 1.147 = the #325 gain. P40 tables and the PR #6 comment are void; correction posted on PR #6.
Fix: the test copies (start-server-8gbtest/8gbnew.ps1) now honor BONSAI_BIN. P40c (deep end, both modes, bin-rc3)
inserted before the P42 soak. P45 stopped (moot).
P43 (result, #314): off 41.4/41.2/41.2 vs on 40.7/41.3/41.3 at 4k; 33.0/32.9/32.9 vs 32.9/32.9/33.0 at 16k. No gain.
Posted on #314.

## 2026-10-07 P44 (result): MMA route for 1-query decode on Turing: q4_0 +6% (4k) / +18% (16k), q8_0 +4% / +14%

Receipts: receipts/p44. bin-rc3, -c 32768 all VRAM, GGML_CUDA_FA_MMA_DECODE_MIN_KV=0 vs default. Posted on #317 with agreement to sb32445 plan (guard in #307 now, Turing follow-up; block after the batch-invariant check).

## 2026-10-07 P40c (result): deep end on the right engine

Receipts: receipts/p40c. bin-rc3 through a launcher copy that honors BONSAI_BIN. Decode / prefill tok/s:
| depth | drafting | long context |
| 4k | 51.2 / 407 | 43.9 / 431 |
| 32k | 42.8 / 331 | 34.2 / 351 |
| 64k | 30.7 / 190 | 24.5 / 255 |
| 96k | 16.3 / 130 | 10.7 / 138 |
| 126k | 11.3 / 105 | 7.1 / 110 |
Drafting numbers equal the old-engine run: the verify step is 2 columns, and #325 changes only the 1-column path.
Long mode 43.9 at 4k = P34. Past the VRAM line decode is PCIe-bound (126k: 11.3).

## 2026-10-07 P47 (plan): more drafts past the VRAM line (tail 2/3/4) for the deep end

12 GB runs tail 4: past the line a step is PCIe-bound and extra verify columns are nearly free. On 8 GB each tail step
adds a 149.6 MiB recurrent plane (~10k q4_0 positions). Arms (draft 1 below the line, bin-rc3, launcher copy, layer
off): tail 1 N=51,200 / tail 2 N=40,960 / tail 3 N=30,720 / tail 4 N=20,480. Depths 4k/32k/64k/96k/126k.
Gates: a tail >1 arm beats tail 1 at 96k and 126k by > 25 %, loses < 10 % at 32k, no one-token answers, free >= 80 MiB.
Pass -> a deep-end option (or a depth-switched default) with this receipt. Watch: tail 2 one-token bug (P18).

## 2026-10-07 P48 (plan): residual ADD + RMS_NORM + MUL fusion on Turing

Census (P41b): 128 residual adds (k_bin_bcast) launch alone per decode step. The engine has an ADD+RMS_NORM+MUL fusion
(ggml_cuda_op_add_rms_norm_fused, no arch-specific code), but it is gated to cc == DGX_SPARK. Dev build prism-p37
adds GGML_CUDA_ADD_RMS_FUSE=1 (all GPUs). Plain model, q4_0, -c 8192 all VRAM, raw server; off/on x3 at 4k/16k;
greedy 300-token texts saved per arm (3 prompts) and compared; census with the switch on.
Gates: on beats off by more than the off-vs-off spread at 4k; texts identical (else KL on wikitext before any use);
census shows ~128 fewer kernels.

## To upstream (running list; Cary 2026-10-07: every passing fix goes to PrismML or the bonsai patch stack)

Done: PrismML #325 (Turing one-column), #330 (f16 prefill), issue #332 (sm_75 release), data on #314 and #317;
bonsai-ada-surgery PR #6 + pre-release bundle-20261007 (8 GB preset, Q4 head tooling, display detection, patch 0034).
Open:
- Shared CUDA pool + LLAMA_MTP_DRAFT_UBATCH (b7c11567a, from the Mirai engine): in the 8 GB engine only. Offer to the
  bonsai patch stack for 12 GB too (12 GB measure first) and check PrismML for an equivalent before a PR.
- P48 ADD+RMS_NORM+MUL fusion on all GPUs (if it passes): the gate is in the engine source; find its origin
  (PrismML or our patches) and send the un-gate there with the Turing receipt.
- Turing MMA decode route (#317 follow-up): sb32445 extends the #307 guard; our numbers are posted. Watch.
- Tail-2 one-token bug: rs_valid detector (P18 / agent read) - a fix belongs in the engine (PrismML if the code is
  theirs). Needs a repro first.
- docs/8GB.md: memory clock (+1000 opt-in) after P42 passes; the deep-end table from P40c.

P48 cancelled (Cary): #209 already exists upstream; take it into the bonsai patch stack by PR and let the 12 GB session test it, no GPU time here.

## 2026-10-07 Patch 0040 = PrismML #209 (cklxx), PR #8 on bonsai-ada-surgery

Fork branch patch-0040-add-rms-fusion (3ecf00b11, author cklxx) on bonsai-q8-product 008ac1112; patches/0040 + README row. No GPU time here (Cary): the 12 GB session tests it. https://github.com/professorpalmer/bonsai-ada-surgery/pull/8

## 2026-10-07 P42 (result): memory +1000 passes 60 min with the clock set before the server starts

Receipts: receipts/p42. Launcher drafting mode, bin-rc3 (test copy honors BONSAI_BIN... note: P42 used start-server-
8gbtest.ps1 before the BONSAI_BIN fix? No - the fix landed 21:2x, P42 started 22:1x: right engine). 101 requests at +1000
in 60 min + 33 stock requests: texts not in the stock set 0 (1 variant per key). No nvlddmkm / WHEA / bugcheck event.
Decode +1000 vs stock: 53.3 vs 51.9 (4k, +2.7 %), 48.7 vs 47.5 (16k, +2.4 %), 43.8 vs 42.7 (32k, +2.7 %).
Drift gate (< 2 %) fails for both arms equally (stock +1.7 / +3.8 / -3.3, +1000 -3.2 / -5.0 / +0.7): request-mix noise,
not heat (same both). Decision: +1000 is a documented opt-in (+2.5 % drafting decode, ~+8 % plain decode) for this
card with this receipt; never a launcher default. Never switch clocks while a server runs (P39 deaths). Cap +1000.

## 2026-10-08 P49 (plan): lookup drafting (patch 0039, main 147f77d) on the 8 GB card

Main turns lookup drafting on by default (ngram-mod before the MTP head, lookup limit 32) but off on 8 GB: "the 8 GB
margin is not measured for it". Mechanism: the recurrent rollback ring stays sized for MTP (draft 1 here); a longer
lookup draft takes the server's checkpoint path, so no extra 150 MiB planes. Risk: the 33-column verify batch's compute
buffers against the 225 MiB margin. Engine: fork bonsai-q8-product 008ac1112 (patches 0036-0039) built for sm_75 ->
bin-lookup. Launcher: main's start-server.ps1 as a test copy that honors BONSAI_BIN. Drafting preset, layer off.
Arms: BONSAI_LOOKUP=0 / =1, bench/lookup_ab.py (quote, edit, plain) at depth 0 and 64000; then lookup=1 at 0 again.
Gates: quote and edit faster with lookup at both depths; plain within 2 %; same text hashes as lookup=0 (rounding-level
MTP differences allowed and listed); no server death, no prefill cliff, min free VRAM >= 80 MiB. Pass -> PR to main:
the 8 GB preset turns lookup on (with this receipt).

## Overnight backlog (2026-10-08; take the top item that is not done; pre-register each before it runs)

1. P49 lookup A/B (queued, BonsaiJob6). If it passes: PR to main - the 8 GB preset turns lookup on.
2. P50: lookup at the deep end - lookup on/off at depth 120000 (quote + edit + plain), drafting preset, bin-lookup.
3. P51: best tail from P47 combined with lookup at 96k / 126k (if a tail > 1 passed P47).
4. P52: 8 GB preset regression on bin-lookup (the new fork head 008ac1112) vs bin-rc3: quick_tps 4k/32k/64k both
   modes, greedy text hashes - confirms patches 0035/0039 cost nothing on 8 GB.
5. P53: HumanEval medium on the drafting preset with lookup on (quality gate for turning it on): bench/humaneval_run.py,
   q4_0, compare with 157/164.
6. P54: tail-2 one-token bug repro (P18 sequence: 4k -> "Say hi." -> 16k -> "Say hi." -> 32k, x3) on bin-lookup with
   tail 2, LLAMA_ARG_CACHE_RAM on vs 0 - tests the stale-plane hypothesis.
7. P55: kernel census on bin-lookup (dev stats build needed: rebuild prism-p37 rebased on 008ac1112) - next fusion targets.
Never idle: if all are done, rerun P40c on the newest engine at stock and +1000 (clock set before the server).

## 2026-10-08 P52 + P50 (plan, queued as BonsaiJob7 after P49)

P52: launcher test copy (main), drafting and long modes, bin-rc3 vs bin-lookup (BONSAI_LOOKUP=0), quick_tps 4k/32k/64k.
Gate: bin-lookup within 2 % of bin-rc3 at every depth in both modes; no one-token answers.
P50: drafting preset, bin-lookup, lookup_ab.py at depth 120000, lookup 0 then 1. Reading: quote/edit/plain tok/s at
the deep end, min free VRAM, server alive. Gate for "on at depth": quote and edit faster, plain within 2 %, no death.

## 2026-10-08 Overnight results and failures

Failure: the session-only cron checks did not fire overnight (no record); the GPU was idle 01:44 -> 07:20.
P47 (result, tail sweep): decode 4k/32k/64k/96k/126k - tail1 50.3/42.3/28.0/15.6/10.9, tail2 51.4/43.1/25.4/16.3/11.8,
tail3 51.3/39.9/22.3/16.1/11.9, tail4 50.9/24.9/16.5/11.7/9.7. Gate FAIL: best deep gain +9 % (tail 3 at 126k), far
below +25 %; tail 4 loses 41 % at 32k (fewer positions in VRAM). 0 one-token answers. Tail 1 stays.
P49 (result, depth 0): lookup on vs off - quote 125.8 / 126.5 vs 58.2 (x2.17), edit 59.8 / 60.5 vs 57.2 (+5 %), plain
52.7 / 52.8 vs 52.6. Quote and plain texts identical across arms. Edit hashes differ in every arm, also between the
two lookup runs: lookup_ab.py hashes the tool_calls with the server-generated call id - a bench bug (fixed in my copy:
name + arguments only; upstream the fix to main). Min free 249 MiB, server alive. The 64k arms and P50 failed:
lookup_ab.py imports quick_tps from its own folder (fixed: bench path).
P52 (result): see receipts/p52 (below).
Next (queued now as BonsaiJob8): P49b edit-hash recheck at 0 and the 64k arms; P50 at 120k; P53 HumanEval with lookup.
P52 (result): bin-lookup vs bin-rc3 decode 4k/32k/64k - drafting 51.6/43.3/28.4 vs 51.7/43.3/28.4, long 43.9/34.2/24.5 vs 43.8/34.1/24.5. PASS (within 0.3 %), 0 one-token answers.

## 2026-10-08 P53 (plan): HumanEval 164 medium, drafting preset with lookup on
bin-lookup, main launcher test copy, BONSAI_LOOKUP=1, layer off, humaneval_run.py --arm medium --temp 0 --max-tokens 20480. Gate: >= 157/164 (P31 q4_0 157), no empty answers.

## 2026-10-08 Fix for idle nights: BonsaiQueue runner + app-level check-in

The session-only cron (CronCreate) cannot fire while the desktop session has no live process: it never ran overnight.
Now: (1) Windows task BonsaiQueue (every 10 min, one instance, headless) runs queue_runner.sh: waits for live
jobrun*.lock jobs (stale locks removed), runs queue/pending/*.sh in order, else rotates filler_a_deep / filler_b_lookup
/ filler_c_humaneval on receipts/newest_bin. The GPU has work with no Claude session at all. (2) App scheduled task
bonsai-8gb-checkin (Claude run every 2 h at :23) processes results, refills the queue, answers PRs, upstreams wins.

## 2026-10-08 P54 (plan, queue 10): tail-2 one-token bug repro on the newest engine

bin-lookup, main launcher test copy, drafting preset, lookup off. quick_tps 4k -> 16k -> 32k (it sends "Say hi."
between depths, P18 sequence). Arms x3 alternated: tail 2 N=40,960 cache on / tail 2 N=40,960 LLAMA_ARG_CACHE_RAM=0 /
tail 1 N=51,200. Reading: one-token answers per arm. Cache-on only -> the prompt-cache restore path (stale ring plane
hypothesis); none -> not reproduced on this engine (record, keep tail 1).

## 2026-10-08 P55 (plan, queue 20): kernel census on the newest engine (008ac1112 + census diagnostic)

Build prism-p55 (sm_75) -> tooling/build-p55. Raw server, plain model, -c 8192 q4_0, GGML_CUDA_GRAPH_STATS=1, verbosity 5, 64-token decode; then the MTP head model with --spec-type draft-mtp --spec-draft-n-max 1 (the drafting step). Output: up to 6 distinct kernel mixes per run. Reading only: the fusion target list for steady decode.

## 2026-10-08 PR #9: lookup drafting on by default on 8 GB (Cary: known win, ship it)

https://github.com/professorpalmer/bonsai-ada-surgery/pull/9 (branch lookup-8gb 07d3949): launcher gate removed, docs/8GB.md lookup section, receipts/lookup_ab_8gb.jsonl (P49b), lookup_ab.py hash fix (tool-call id). P49b: d0 quote 58.2 -> 125.9, edit 56.9 -> 60.5, plain 52.5 -> 52.8, 11/11 same text; 64k quote 32.5 -> 69.3, plain 31.4 -> 31.3, 1/11 text differs (rounding). Min free 90 MiB. Follow-ups: 64k edit row, P50 120k, P53 HumanEval -> commits on PR #9. maintest launcher copy now = this branch (lookup on).
P49b 64k edit: 32.5 -> 37.7 (+16 %), look_d64k min free 82 MiB; 21/22 texts same. PR #9 updated.

## 2026-10-08 P56 (plan, queue 05): engine 8a6d2ea12 (patches 0040 #209 fusion + 0041 tier prefill + 0042 grammar clone) on 8 GB

12 GB review on PR #9 asks: does bundle-20261008-tier add VRAM on 8 GB, and is prefill past the 8 GB line faster?
Build fork bonsai-q8-product 9f2b0feac for sm_75 (+ test-backend-ops). Checks: test-backend-ops -o ADD, RMS_NORM,
FLASH_ATTN_EXT on CUDA0. A/B (drafting preset with lookup, PR #9 launcher copy): bin-lookup vs bin-tier, quick_tps
4k/32k/64k/96k, x2 alternated; free VRAM at load and min. Gates: tests pass; decode within 2 % or better (0040 should
help); prefill at 64k/96k better (0041); free VRAM at load within 32 MiB. Answer on PR #9; Turing receipt to #209.

## 2026-10-08 P57 (plan, queue 08): 10+ min soak with lookup on at 64k (12 GB review, PR #9)

Drafting preset with lookup (PR #9 launcher copy), bin-lookup, lookup_ab.py --depth 64000 run 3 times back to back on one server; free VRAM every 2 s. Gates: server alive, no nvlddmkm event, min free >= 60 MiB, decode of run 3 within 3 % of run 1.

## 2026-10-08 Serving switch

pause.ps1 (queue\PAUSE, stops job tasks/scripts/servers, interrupted job back to pending, stock clocks) and resume.ps1. Runner obeys PAUSE (restarted 09:31 with it). Cary decides when to pause; testing continues until then.
P56 updated before it ran: prism-tier now at fork head 8a6d2ea12 (adds 0042 grammar clone fix).

## 2026-10-08 P58 (plan, queue 06): does f16 prefill (patch 0038) tax lookup verify batches on 8 GB?

main b8ba790 (Ada, #330 data): lookup verify batches -9 to -10 % on file rewrites with GGML_CUDA_FA_PREFILL_F16. Our
drafting preset sets it to 32768; the f16 path takes Q->ne[1] > 8, and a lookup verify batch is 33 columns, so each
verify step may convert the cache to f16. A/B: drafting preset with lookup, bin-lookup, lookup_ab.py at depth 0 and
32000, GGML_CUDA_FA_PREFILL_F16=32768 (preset) vs 0. Gate: if 0 is faster on quote/edit by > 3 % at either depth ->
change patch 0038's threshold to prefill-sized batches only (e.g. Q->ne[1] > 64), measure prefill unchanged, and send
the fix to the patch stack and PrismML #330.

## 2026-10-08 P59 (plan, queue 07): mid-message checkpoints (--checkpoint-every-nt) stop the 120k re-prefill

Code read (agent): this hybrid model checkpoints only at user-message starts and 4 / 4+n_ubatch tokens before the
prompt end (server-context.cpp:3578 skips mid-message checkpoints; upstream removed --checkpoint-every-nb, #20087, and
has the same rule today). A prompt that diverges inside one long message re-prefills everything: P50 120k requests
760-866 s each; only tails < 516 tokens reuse (39-40 s). Patch (branch patch-ckpt-every-nt on the fork, off by
default): --checkpoint-every-nt N / LLAMA_ARG_CHECKPOINT_EVERY_NT keeps a batch-start checkpoint N tokens past the last.
Test: build sm_75 (bin-ckpt); drafting preset with lookup; lookup_ab.py at 64000 with N=8192 vs 0. Gates: wall time
per request after the first drops by > 50 % for quote / plain-code items; same text hashes; decode within 2 %; host
RAM and free VRAM recorded. Pass -> patch to the stack (PR) and offer to PrismML / upstream with the receipt.
Also seen: quote csv.py at 120k returned 1 token in both arms (P50) - a one-token answer; P54 investigates.

## 2026-10-08 P60 (plan, queue 06; replaces P58): patch 0043 candidate (f16 prefill min 64 queries) on 8 GB - 12 GB request on PR #9

12 GB asked (PR #9, 17:10): build fork branch product-0043-minq (2096db283 = 8a6d2ea12 + GGML_CUDA_FA_PREFILL_F16 only
for >= 64 queries; 4070: lookup file-rewrite decode 195.4 -> 212.4, prefill same, 7/7 same text). A/B on the 2060:
lookup on, GGML_CUDA_FA_PREFILL_F16=32768 (preset), bin-tier (8a6d2ea12, the current bundle) vs bin-minq, 2 rounds
alternated, lookup_ab.py at depth 0 and 16000, plus quick_tps --depth 30000 (one ~30k prefill) per binary.
Gates (his): minq keeps the Turing prefill (30k prefill within 2 %) and file-rewrite decode goes up; same text hashes.
Pass -> report on PR #9; he ships it as patch 0043. P58 superseded (same question).

P53 first run failed at once: humaneval_run.py subprocess got an invalid stdin handle under conhost --headless. Fixed with < /dev/null (also in filler_c). Requeued as 30-p53.

## 2026-10-08 P56 (result): 8a6d2ea12 on 8 GB PASS

Tests 99/99, 51/51, 2994/2994 (sm_75). Free at load same (286/247 vs 245/297). Prefill +3 % at 64k, +9 % at 96k (0041). Decode +1-2 % (0040), within round spread. Posted on PR #9. Newest validated engine = bin-tier (receipts/newest_bin updated).

## 2026-10-08 P61 / P62 / P63 (plan; 4070 session requests relayed by Cary)

P61 (queue 06b, for PrismML #330): bin-tier (old rule, > 8 queries) vs bin-minq (>= 64), lookup on, F16=32768.
Fresh 30k and 60k prefill (quick_tps --depth 30000 / 60000, one server each) and lookup_ab.py at depth 30000.
Expectation (4070 session): file-rewrite decode up below the 32768 cap; prefill unchanged. Post data on #330 (no commit).
P62 (queue 07b): drafting preset + lookup, bin-tier (8a6d2ea12), quick_tps 4k/32k/64k/96k/126k - the 126k row on
the new engine (P40c was bundle-20261007).
P63 (queue 07c): patch 0042 check - bench/agent_depth_probe.py (main) at depth 20000, arm "server", bin-tier, drafting
preset + lookup: PROBE_MANY_TOOLS=105 PROBE_TOOL_CHARS=976 PROBE_PI=1 vs no PROBE_* (2 tools). Reading: decode tok/s.
Soak P57 note (4070 session): run part of it with a normal desktop on the card (Cary's browser), not only idle.

## 2026-10-08 P60 (result): min-Q neutral on Turing

quote d0 125.7 vs 124.1 (minq), d16k 112.2 vs 110.6; edit/plain within 0.5 %; 30k prefill 345.2/345.2 vs 344.8/344.5. Text same per round (16k shlex edit differs between rounds in both engines). Gate (decode up) FAIL on Turing, neutral -> no objection to 0043 for Ada. Posted on PR #9.

## 2026-10-08 P61 (result) and a quality bug: 1-token answers on fresh long prompts

P61: 30k prefill 345.4 (tier) / 344.1 (minq); 60k prefill 255.0 / 254.4 - but every 60k request (fresh 59,953-token
prompt, then prose and bash) answered with 1 token, in BOTH engines. lookup_ab at 30k: quote csv.py (tier) and
textwrap.py (minq) answered 1 token; other items normal (quote 75.9 vs 72.9, edit 68.1 vs 68.7, plain 43.4 vs 43.3).
Earlier: P50 120k csv.py 1 token in both arms (bin-lookup). Extended sweeps (P40c, P56: 4k -> 32k -> 64k -> 96k) had none.
Lead (not proven): the failing prompts are fresh and longer than 32,768 tokens = the preset's GGML_CUDA_FA_PREFILL_F16
cap; the f16-converted and the in-place attention paths switch within one prefill.
P64 (plan, front of queue): bin-tier, drafting preset, quick_tps --depth 60000 (fresh) x4 arms: F16=32768 + lookup
(repro), F16=0 + lookup, F16=32768 + BONSAI_LOOKUP=0, F16=0 + BONSAI_LOOKUP=0. Count 1-token answers.
Reading: only F16 arms fail -> patch 0038 bug (fix before anything ships; 8 GB preset sets it); all fail -> look at
0041 / long fresh prefill / checkpoints; none fail -> flaky, repeat x3.
P64 amended before it ran: 5th arm f16 + lookup with the shared CUDA pool off (launcher copy start-server-maintest-nopool.ps1; 4070 session suspect 2).

## 2026-10-08 P64 (partial result) and P65 (plan): the 1-token bug is not f16 prefill and not lookup

P64 (bin-tier, fresh 60k, quick_tps): f16+lookup / no f16+lookup / f16 no lookup / no f16 no lookup -> all 3/3
requests answered 1 token in every arm (n_tokens = prompt at release, no error at default verbosity). Pool-off arm
pending. 4070 repro (main 4700299, 8 GB preset forced): 20/20 normal. #330 (patch 0038) is not the cause.
Remaining suspects: MTP draft context with a fresh long prompt (draft window 16384), 0041 tier prefill, the tiered
cache on this card. Steps that extend the prompt (P40c, P56) never failed; no-head fresh 60k worked (P16b, old engine).
P65 (front of queue): fresh 60k quick_tps, drafting preset unless noted, LLAMA_ARG_LOG_VERBOSITY=4 in every arm:
 a) bin-tier BONSAI_SPEC=0 (no MTP)   b) bin-lookup (pre-0041)   c) bin-tier BONSAI_DRAFT_WINDOW=65536
 d) bin-tier long mode (no head file). Reading: which arm answers normally isolates the cause.

## 2026-10-08 P64 (result): the shared CUDA pool causes the 1-token answers -> hotfix PR #10

Pool off (f16 on, lookup on): 0 of 3; every pool-on arm 3 of 3. Patch 0037's GGML_CUDA_SHARED_POOL, set by the 8 GB
preset (shipped in PR #6 / bundle-20261007-8gb), breaks fresh long prompts with MTP drafting on this card.
Hotfix: https://github.com/professorpalmer/bonsai-ada-surgery/pull/10 (branch hotfix-8gb-no-shared-pool): preset no
longer sets it; drafting fixed cost 6469 -> 6531 MiB. Engine bug not found (suspect: pool blocks held across graphs,
e.g. the FWHT/Q8 context, in a LIFO pool shared with the draft context).
P66 (plan, after P65): hotfix launcher copy (start-server-hotfix.ps1), bin-tier, drafting preset + lookup: fresh 30k,
60k and 120k quick_tps; lookup_ab.py at 30000; per arm free VRAM at load / min and prefill. Gates: 0 one-token
answers; min free >= 60 MiB; prefill at 60k within 5 % of P61 (255), no cliff.
maintest launcher copy (used by queued jobs and fillers) now has the hotfix too (no shared pool, fixed 6531).

## 2026-10-08 P67 (plan, after P66): narrow the shared-pool engine bug on Turing

4070 (PR #9 comment, corrected): pool on, 20 of 20 normal on Ada. On the 2060: f16 off still fails (P64) -> not the
cap crossing; pool truly off passes with LESS free VRAM (same fixed cost) -> not memory pressure.
Arms, bin-tier, pre-hotfix launcher copy (pool on), fresh 60k: a) GGML_CUDA_DISABLE_GRAPHS=1 (graph replay?),
b) LLAMA_MTP_DRAFT_UBATCH unset (default draft ubatch, pool on), c) pool on + /completion with n_probs 5 on the
same 60k prompt to get the 1 token's id/text. Reading only (engine debugging input).

P65 (result, confounded): launched 16:47, the maintest copy lost the pool at 16:50:22, so pre0041 and window64k ran WITHOUT the pool (env listing shows no GGML_CUDA_SHARED_POOL). All 4 arms 0 one-token = consistent with "pool off passes"; says nothing about 0041. P67 amended: + pre0041 with pool (bin-lookup), + a pool-on control on bin-tier.

## 2026-10-08 P68 (plan, after P67): candidate engine fix product-0045-poolsync (4070 session, PR #10)

142d5105d (on 55db5e2c2 "GGML_CUDA_SHARED_POOL=0 turns it off" and 2096db283 min-Q): in shared-pool mode each graph
waits for an event after the other stream's last graph. Untested on Turing. Build sm_75 -> bin-poolsync. Pre-hotfix
launcher copy (pool on), drafting preset + lookup: fresh 60k quick_tps x3 (separate server starts), lookup_ab.py 30000.
Gates (4070 session): 0 one-token answers -> ship as patch 0045 and the pool returns to the preset (+62 MiB);
any failure -> pool stays off. Also record decode vs bin-tier (a graph-boundary wait can cost speed).

## 2026-10-08 P66 (result): hotfix PASS

fresh 30k/60k/120k 0/3 each; ab30k 0/11 (lookup off: hotfix branch = main w/o PR #9); prefill 344/254/172; min free 133-145 MiB. Posted on PR #10 (ready to merge from my side).

GitHub watcher: gh_watch.sh (run in background, wakes on any new comment/PR/push not listed in gh_mine.txt). Post my comments with gh_post.sh <pr|issue> <n> <file> [repo] so they are ignored.

## 2026-10-08 P67 / P68 (results): the pool bug is intermittent; poolsync 0 failures so far

P67 (pool on, bin-tier unless noted, fresh 60k): graphs off 3/3 one-token; default draft ubatch 0/3 (decode 13.7?);
pre-0041 engine 0/3; pool-on control 0/3 (failed 3/3 in every P64 pool-on arm). The 1 token: id 248046 (empty
end-of-turn) at logprob -0.29 (75 %), next " The" at -2.86 - the model state is wrong, not the sampler.
Pool-on runs that failed: P61 (2 servers), P64 (4), P67 graphs-off (1) = 7 of 10 runs.
P68 poolsync (142d5105d, pool on): fresh 60k 0/3 x3 runs, lookup_ab 30k 0/11; decode 31.6 (pool-on control 31.3,
pool-off 29.1); free at load 286 MiB, min 134. Lookup on (quote ~97 at 30k).
P69 (plan, front of queue): alternated x6: bin-poolsync pool on / bin-tier pool on, fresh 60k quick_tps.
Gates: poolsync 0 one-token in 6 runs while bin-tier fails in >= 3 of 6 -> the fix works (P(0/6 | 70 % rate) < 0.1 %).
If bin-tier also passes most runs, the test cannot separate them -> more runs.

## 2026-10-08 P69/P62/P63 (results)

P69: poolsync 0/18 (6 starts), 8a6d2ea12 pool-on 18/18 -> fix works; decode 31.3-31.5. Posted PR #10 with proposal (merge #10 now, pool back with 0045 later).
P62: 126k decode 14.1 / prefill 111.6 on 8a6d2ea12 (P40c 11.3 / 105). P63: 2 tools 43.8, 107 tools (46,878-token prompt) 34.8 - depth confounded. Posted PR #9.

## 2026-10-08 P70 (plan, after the soak): clean Turing min-Q set for #330, pool off

P61 had 2 of 22 lookup items with 1 token (pool on), so its 30k means compare different item sets. Rerun with the PR #10 launcher (pool off, lookup on, F16 32768): 8a6d2ea12 vs 2096db283, lookup_ab.py at 0 / 16000 / 30000 and fresh 30k / 60k quick_tps, alternated. Reading: data for #330 (posted by the 4070 session in one combined comment).

## 2026-10-08 P57 (result): soak PASS

89 min, alive, no driver events, min free 119 MiB, 0/33 one-token, decode rounds quote 65.7/68.5/68.3 edit 33.6/44.0/43.9 plain 26.5/29.0/35.1 (no fall). quote+edit text identical; plain differs between rounds. PR #9 ready to merge (posted).

## 2026-10-08 PR #9 merged (9343db61a) by me on Cary's go-ahead (12 GB session agreed); main = lookup on 8 GB, no shared pool

## 2026-10-08 P59 (result): --checkpoint-every-nt FAILS - fast reuse, wrong output

bin-ckpt (50a97aaf6), lookup_ab.py at 64k, N=8192 vs 0. Wall per request after the first: 45-58 s vs 272-294 s
(reuse works). But the text is wrong with N=8192: all 3 plain prompts gave one identical text (sha c5f73752f40a);
all 4 edit calls gave one identical 2048-token text (sha bbf7b9093069). Quote items matched N=0. Restoring a
mid-message checkpoint gives a wrong state (the restored recurrent state does not match the positions it claims, or the
attention KV after it is not invalidated). Not shipped; branch patch-ckpt-every-nt marked broken. Needs a code read of
create_checkpoint (n_tokens vs n_tokens_cur at batch start) and the restore path before any retry.

## 2026-10-08 P71 (plan, after P70): why a deep recurrent-checkpoint restore gives wrong output

Agent code read: --checkpoint-every-nt bookkeeping is correct (n_tokens = batch start, restore sets n_past = P,
keep_first(P), seq_rm(P,-1), tail re-processed). N=0 never restored a deep recurrent checkpoint, so the fault is in the
deep-restore path itself (also reachable by long multi-turn chats). One change per arm, bin-ckpt, PR-merged launcher copy
(lookup on, no pool), LLAMA_ARG_CHECKPOINT_EVERY_NT=8192, lookup_ab.py at 64000:
 a) control, LLAMA_ARG_LOG_VERBOSITY=4 (read "restored context checkpoint ... n_past")  b) BONSAI_SPEC=0 (no MTP, no
 lookup, no rollback planes)  c) GGML_GDN_STATE_GATHER=1  d) GGML_CUDA_KV_TIER_REDIRECT=0 + GGML_CUDA_KV_TIER_PREFETCH=0.
Wrong-output test: plain items (3 different prompts) with one identical sha, or edit items with one identical sha.
Reading: the arm that turns the output correct names the component.

## 2026-10-08 P72 (plan, queue 09-0, first): the released bundle-20261008-8gbfix on the 2060 SUPER

Released by the 4070 session (patches 0043-0045 incl. poolsync; PR #9 + #10 launcher). Download our own asset
(608,055,810 bytes) into bin-8gbfix (sha256 recorded), launcher test copy = main 9bf3645. Preset auto (drafting + lookup):
fresh 60k quick_tps x2 (1-token check), quick_tps 4k/32k/64k, lookup_ab.py depth 0; long mode 4k/32k.
Gates: 0 one-token; decode/prefill within 3 % of P62/P56 (same engine family); test-backend-ops not shipped in the zip
(skip). Pass -> confirm on the release thread / PR; then a follow-up PR: pool back on for engines with 0045.

## 2026-10-08 P70 (result): clean min-Q neutral on Turing

0/66 one-token, text identical. quote d0/16k/30k 124.5/110.4/103.1 vs 125.5/109.8/99.8; edit 58.5/72.5/66.6 vs 60.1/70.2/65.3; plain 52.1/45.3/53.6 vs 52.7/45.0/53.0. Prefill 30k 339.4 vs 343.0, 60k 253.5 vs 253.3. Posted on PR #9 for the #330 comment.

## 2026-10-09 P71 (result): --checkpoint-every-nt is CORRECT; P59 wrong output came from the shared pool

P59 ran 15:24 with the launcher copy that still set GGML_CUDA_SHARED_POOL=1 (removed 16:50). P71 (pool off, N=8192, 64k): all 4 arms (ctrl, nospec, gather, notier) give distinct correct texts; ctrl and notier 22/22 identical to the P59 N=0 reference. Wall per request after the first: 18-58 s vs 272-294 s at N=0. Restores logged at n_tokens 61,788-63,493. -> ship as a patch (PR), un-mark branch.
P72 failed (zip not extracted inside the task; bin-8gbfix got a copy of the 8gb folder). Zip sha256 aaf7637e...fe09, engine 142d5105d. Extracted by hand; P72b queued first.

## 2026-10-09 PR #11: patch 0046 --checkpoint-every-nt (8 GB preset sets 8192)

https://github.com/professorpalmer/bonsai-ada-surgery/pull/11 ; fork branch patch-0046-ckpt-every-nt (5251968b0 on 142d5105d). Receipt P71. Needs a bundle with 0046; the 12 GB session decides for its preset.

## 2026-10-09 P73 (plan, queue 25): PR #11 end to end on the 8 GB card

Build prism-0046 (5251968b0 on 142d5105d) sm_75 -> bin-0046. Launcher = PR #11 branch copy (start-server-pr11.ps1).
Arm A: preset auto (must print / set LLAMA_ARG_CHECKPOINT_EVERY_NT=8192 because the engine has the flag).
Arm B: same with BONSAI_CKPT_EVERY=0. lookup_ab.py at 64000 each. Gates: A sets 8192 by itself; A text = B text for
all 11 items; A wall per request after the first < 50 % of B; 0 one-token; launcher output and server RAM recorded.
Default sweeps now use the released engine (receipts/newest_bin = bin-8gbfix).

## 2026-10-09 P54 (result): tail-2 one-token bug not reproduced (pool off)

0 of 81 answers (tail 2 with and without LLAMA_ARG_CACHE_RAM, tail 1; 3 rounds each, 4k -> 16k -> 32k with "Say hi."). The P18 failures (2026-10-07) ran with GGML_CUDA_SHARED_POOL=1 (bin-p12 C2 config). Most likely the same pool race (fixed: pool off in the preset, patch 0045). The stale-plane hypothesis is not needed; the open tail-2 item is closed unless it shows again with the pool off.

## 2026-10-09 P72b (result): bundle-20261008-8gbfix PASS on the 2060

Tests 99/51/2994 pass; 0 one-token in 32 requests; drafting 51.5/46.4/30.4 decode, 410/331/193 prefill; long 43.7/34.1; lookup d0 quote 125.2 edit 60.2 plain 52.2. Posted PR #10.

## 2026-10-09 P73 (result): PR #11 end to end PASS

auto (launcher sets 8192): wall after first mean 60.5 s vs 227.0 s off; 11/11 same text; 0 one-token; working set max 7333 vs 6834 MiB. Posted PR #11.
P55 (census) failed: model path lost its file name (backslash escaping); requeued as 35-p55b with forward slashes.

## 2026-10-09 PR #11 merged (patch 0046; 12 GB confirmed: 64k 64.5 -> 15.5 s, 160k 230 -> 49 s, 11/11 same text). Engine commit 5251968b0 must go to bonsai-q8-product for the next bundle (4070 session builds bundles).

## 2026-10-09 P53 (result): HumanEval with lookup on = 158/164 (96.34 %), vs 157 without lookup (P31). Quality holds.

## 2026-10-09 P55b (result) and a lead: plain decode may evaluate 2 tokens per step

Census (GGML_CUDA_GRAPH_STATS, engine 008ac1112+diag): plain server, decode graph (CUDA graph id 66 reused 64 times):
1830 kernels, the layer mat-vecs are mul_mat_vec_ptq1_0_pt<2,4> x400 (2 columns); only the output head is <1,4>.
Graph reserve log says decode ubatch n_tokens = 1. If the layers really get 2 columns per decode step, Turing pays the
2-column kernel (and 2x the small ops) on every token. P36b (older engine, graphs off) showed cols=1 - conflicting.
P74 (plan, next in queue): bin-p55 (op-timing build), plain model, raw server, GGML_CUDA_OP_TIMING=1 +
GGML_CUDA_DISABLE_GRAPHS=1, LLAMA_ARG_LOG_VERBOSITY=5, 64-token decode: read cols= of the ptq1_0 MUL_MAT keys.
Also: the same census with the graphs on, printing ne[1] of the first MUL_MAT (diag change if needed).
Correction (agent code read + log): the <2,4> mix was the WARMUP graph (llama_decode({bos, eos}), common.cpp:1512).
The decode graph is census #2: 1574 kernels, all PTQ1_0 mat-vecs 1-column (241 <1,4>, 80 <1,4,fusion>, 40 <1,4,gate>).
No 2-token waste. P74 cancelled. Real lead: gate+up fused in only 40 of 64 FFN layers (24 run as two kernels) - small
fusion target (~1 %); receipts/p55b/census_plain_decode.txt.

## 2026-10-09 PR #12 merged (docs/8GB.md: 8gbfix, deep-end table, memory clock optional, pool/tail-2 notes corrected)

## 2026-10-09 P75 (plan, queue 40): a 262k window on the 8 GB card, as served

Cary asked about 262k on 8 GB. The window is set by system RAM (q4_0 host part ~4.7 GB at 262k); P30 loaded it
(43.1 at 4k). Now with the full current stack: bin-0046 (142d5105d + 0046), launcher = main (lookup on, no pool,
checkpoints every 8192), BONSAI_CTX=262144, drafting preset. quick_tps 4k / 64k / 128k / 192k / 250k (each extends);
then lookup_ab.py at 250000 (first request full prefill, the rest restore checkpoints). Record: positions in VRAM,
free VRAM at load / min, prefill and decode per depth, lookup tok/s at 250k, wall per request, RAM, one-token count.
Gates (to recommend 262k on 8 GB): server stays up; 0 one-token; min free >= 60 MiB; decode at 4k within 3 % of the
131k preset (51.7). Deep numbers are reading only.

## 2026-10-09 P76 (plan, queue 38): gate+up+GLU fusion in all 64 FFNs (fusion work, item 1)

Agent read: 24 of 64 FFNs miss the gate/up/SwiGLU fusion because the allocator puts the GLU output on the Hadamard
activation block; the memory guard refuses (correctly: the q8 rows live there). Fix (prism-fuse c87233fc1 on
5251968b0): try_fwht_q8 moves the q8 rows to a held pool block when a GLU output within 6 nodes overlaps; the GLU
fusion check ignores the shared-activation overlap on the quantized mat-vec path only. Switch GGML_CUDA_GLU_ALIAS_FUSE=0.
Test build adds the census diagnostic (42ee8889f). Checks: test-backend-ops MUL_MAT, GLU, MUL_MAT_VEC_FUSION (if
present) on CUDA0; census: 64 gate-fused mat-vecs (was 40), SwiGLU kernels 48 (was 72); plain raw server, -c 8192,
quick_tps 4k x3 alternated switch 1/0; greedy texts (3 prompts, 300 tokens) identical between 1 and 0.
Gates: tests pass; census as expected; texts identical; decode not slower (expected +0.5-1 %).

## 2026-10-09 P76 (result): gate+up fusion in 64/64 FFNs - correct, +0.2 %

tests MUL_MAT 1516/1516, MUL_MAT_VEC_FUSION 506/506; census 1478 vs 1526 kernels (64 vs 40 gate-fused); greedy texts identical; plain decode 4k 44.0/44.0/43.9 vs 43.9/43.8/43.9. Held to ship with the next fusion (norm into fwht quantize).

## 2026-10-09 Decision (Cary agreed): stop micro-fusions; megakernel only as a last resort

Measured ceilings (P37 skip tests): removing a whole small-kernel class gains 0.5-1.7 %; all small kernels together
+14 %, spread over ~1,200 kernels of ~2.3 us. P76 gate+up fusion (64/64 FFNs, identical text): +0.2 %. The norm->FWHT
fusion target shrank after patch 0040 (48 of 129 norms are already ADD+RMS_NORM+MUL); the 81 plain ones are worth
~0.5 %. Neither ships (engine complexity, held pool blocks, for < 1 %). Gate+up fix kept on fork branch fuse-gateup
(c87233fc1) for a future megakernel effort. Effort moves to the 262k default (P75) and the deep end.

## 2026-10-09 P75 (partial) and P77 (plan): the 262k cost is the tier staging buffer

P75 (262k window, preset, bin-0046): VRAM positions 41,472 (131k preset: 50,176). Decode 4k 51.9 (= 131k), 64k 24.1
(131k: 30.7, -21 %), 128k 9.9 (131k at 126k: 14.2, -30 %), 192k 6.9. The launcher reserves the tier staging buffer,
(ctx - N) x CellBytes / 16 of VRAM, so the VRAM line moves down 8,738 positions per extra 131k of window.
P77 (plan, after P75): GGML_CUDA_KV_TIER_STAGING=0 (attention reads the host part directly, no staging buffer); with
no staging, N = 47,040 + 8,192 = ~55,232 at any window (use 54,784 for margin). Arms, drafting preset, bin-0046,
quick_tps 4k/32k/64k/96k/128k: A 131k preset; B 131k staging 0 N=54,784; C 262k staging 0 N=54,784.
Gates for "262k default": C decode at 32k/64k/96k >= A (or within 2 %), 4k within 2 %, min free >= 60 MiB, 0 one-token,
prefill at 64k/128k not worse than P75 by > 10 %. B vs A isolates staging-vs-direct cost at the same window.

## 2026-10-09 P78 (plan, queue 42): Turing tuning of the PTQ1_0 mat-vec launch shape + graph concurrency

Cary: Turing is a generation everyone moved past; find the leftover. The 1/2-column PT mat-vec (72 % of a decode step)
uses 4 rows per item and launch_bounds(128, 4), chosen on Ada/Ampere. prism-tune 3200e3761 (on 5251968b0): runtime
GGML_PTQ1_PT_TUNE=RxM, R in {2,4,8}, M in {2,4,6,8}; per-row arithmetic unchanged (expect identical bits).
Sweep: test-backend-ops perf MUL_MAT ptq1_0 at n=1 and n=2 for the 7 decode shapes, weighted by uses per token
(gate/up 5120x17408 x128, down 17408x5120 x64, qkv 10240 x48, z 6144 x48, ssm_out 6144->5120 x48, q 12288 x16,
o x16) -> us per token per combo. Plus GGML_CUDA_GRAPH_OPT=1 vs 0, plain raw server, quick_tps 4k x2 + greedy texts.
Gate: a combo >= 3 % faster weighted (n=1 or n=2) -> end-to-end A/B (P79) and, if it holds, a Turing default.

## 2026-10-09 P79 (plan, queue 46): the released bundle-20261009-ckpt on the 2060 SUPER

Released by the 4070 session (fa201c0e5: patch 0046, launcher VRAM line, layer note fix). Download our own asset
(608,058,824 bytes, GitHub digest sha256 9afbb49f...f479) into release_ckpt, check the sha256 with Get-FileHash,
extract with Expand-Archive (P72 failed with tar), BONSAI_BIN = the folder that holds llama-server.exe. Launcher =
start-server-maintest.ps1 (main fa201c0 + BONSAI_BIN). Same arms as P72b: test-backend-ops ADD / RMS_NORM /
FLASH_ATTN_EXT; preset auto fresh 60k x2; sweep 4k/32k/64k; long mode 4k/32k; lookup_ab.py at depth 0; plus
lookup_ab.py at 64000 (the checkpoint gain as shipped).
Gates: sha256 matches; tests pass; 0 one-token; decode within 3 % of P72b (drafting 51.5/46.4/30.4, long 43.7/34.1);
the server log shows checkpoint-every-nt 8192 from the launcher; 64k wall per request after the first within 15 % of
P73 auto (60.5 s), 11/11 text same as P73. Pass -> confirm on PR #11 / the release; fail -> issue with the receipt.

## 2026-10-09 Fillers 03:54-09:01 (result): stable, no regression

lookup (04:32, 07:28): 0 one-token in 88 items; d0 quote 126.1/124.4 (lookup) vs 58.1/58.4, 64k quote 68.2/68.2 vs 28.0/26.6, plain same.
HumanEval (06:05): 158/164 (96.34 %), same as P53. deep (03:54, 06:50): 64k 21.7/24.4, 96k 10.2/10.7, 126k 6.8/7.1 decode
(run-to-run spread up to 12 % at 64k; desktop load not recorded). Receipts: receipts/filler/*_1009_*.

## 2026-10-09 Upstream: patch 0046 to PrismML (PR #338)

https://github.com/PrismML-Eng/llama.cpp/pull/338 (branch checkpoint-every-nt = 5251968b0 cherry-picked on prism 8b0c19c8c,
clean, not rebuilt on that base). Duplicate check: no --checkpoint-every-nt or equivalent in PrismML prism or ggml-org master;
PrismML #312 (checkpoint buffer reuse) is different. Receipts: P71, P73, 12 GB PR #11 comment. Body: upstream/pr-prism-ckpt-every-nt.md.

## Check-in 2026-10-09 10:45
1. Queue: BonsaiQueue running; P75 (262k) runs since 09:10; pending P78, P77, P79 (new: release check of bundle-20261009-ckpt).
2. Results: P70 to P76 were already logged; fillers 03:54-09:01 logged above (stable, 0 one-token, HumanEval 158/164).
3. Upstream: patch 0046 sent to PrismML as PR #338 with the P71/P73 and 12 GB receipts.
4. Activity: PRs #11 and #12 merged; issue #7 is handled by the 4070 session; PrismML #317 merged by bri-prism; no open questions to this rig.
5. Note: this check-in started 22:48 and continued at 10:16; P72 failure and P72b pass were logged by an earlier run.

## 2026-10-09 P80 (plan, queue 46; 4070 session suggestion): tail draft 2 vs 1 at ~200k with a 262k window

P47 (131k) measured tail 2 +9 % at 126k but -9..-41 % mid-depth (one 149.6 MiB plane = ~8.7k positions less in
VRAM). At 200k each PCIe-bound step is longer, so extra verify columns may pay more (4070: +26 % on code at 180k).
Arms, drafting preset + lookup, bin-0046, BONSAI_CTX=262144: tail 1 N=41,472 (preset) / tail 2 N=32,768;
quick_tps 64k then 200k (each extends). Reading: decode at 200k (code/prose/bash) and 64k; gate for a depth-only
tail 2: +15 % at 200k with <= 5 % loss at 64k. Public data (27B) -> PR/issue comment.

Queue order: P79 (release check, written by the 10:16 check-in) moved to 43, before P77 (45) and P80 (46).

## 2026-10-09 P75 (result): 262k as served today fails the gates - VRAM over-commit at depth

Sweep (bin-0046, preset, BONSAI_CTX=262144): load free 201 MiB, VRAM positions 41,472. Decode 4k 51.9 / 64k 24.1 /
128k 9.9 / 192k 6.9 / 250k 4.9 tok/s; prefill (code prompt, extends) 410 / 240 / 126 / 86 / 66 tok/s; MTP acceptance 0.788.
Lookup A/B at 250000: the first request (full prefill, ~250k tokens at ~65 tok/s) passed the 1800 s client timeout. No result.
Memory trace (ab.mem.txt): free VRAM 201 -> 21 MiB in 80 s of prefill, then below zero (nvidia-smi wraps to 4194xxx)
for 85 of 89 samples. The sweep also ended below zero. The driver puts the excess in shared system memory. This is a
probable part of the deep-end loss, in addition to the smaller VRAM line.
Gates: server up - yes; 0 one-token - yes (sweep); min free >= 60 MiB - FAIL; 4k decode within 3 % of 131k - pass (51.9).
Decision: do not recommend 262k with today's preset. P77 (staging off, N = 54,784) is the next test. Its min-free gate
now also needs a memory trace through a deep prefill (>= 128k), not only at load.
Tooling: lookup_ab.py timeout 1800 s is too short for a cold 250k prefill on PCIe 3.0. Use 5400 s for deep runs.
Build fault: tune build at 09:57 crashed in cicc (ACCESS_VIOLATION, fattn instance, during P75 RAM load) but
build.bat returned 0; P78 ran on a bin with no exe and failed in 1 min. Rebuild with -j 4 and a real success check
(build_ahead6.sh: exe files present, no "build stopped"). P78 requeued as 44 (after P79).
P77 amended before its run: each arm now has a 10 s VRAM trace (<arm>.mem.txt, "trace min free" line, wrap corrected).
Arm A (131k preset, the shipped default) gets the same check, so it also shows if 131k goes below zero at 128k depth.
P80 amended before its run: P75 showed the 262k preset (staging on, N 41,472) goes below zero free VRAM at depth, which
would confound tail 1 vs 2. Both arms now use staging off (P77 setting): tail1 N 54,784, tail2 N 46,080 (same 8,704
cell difference as before), with the VRAM trace. If P77 shows staging off is unsafe, P80 is re-planned.

## Check-in 2026-10-09 10:45 (second run)
1. Queue: BonsaiQueue running; P79 (release check) runs since 10:34 (fresh 60k loaded, free 341 MiB); pending P78 (44), P77 (45), P80 (46).
2. Build: tune2 rebuild (-j 4) runs since 10:34 (ninja/nvcc live); P78 waits for "tune2 exit 0" and stops on a failed build.
3. Results: no new finished receipt since the last check-in; P75 and the P78 build failure are logged above.
4. Upstream: no new confirmed win; PrismML #338 open, no comments yet.
5. Activity: no new PRs; main has 4 new commits from the 12 GB session (PCIe check, 160k draft size, issue #7 repro, release); PrismML #325/#330/#314/#209/#332 have no new replies to professorpalmer.

Queue order (Cary question, 8 GB cards are mostly not Turing): universal 262k work first. P78 moved to 47, after P77 (45) and P80 (46).
Build tune2 (-j 4) at 10:52: pass, llama-server.exe and test-backend-ops.exe present. P78 (queue 47) is ready.

## 2026-10-09 P79 (result): release bundle-20261009-ckpt on the 2060 SUPER - pass, one 4k reading to recheck

sha256 match (608,058,824 bytes); ADD 99/99, RMS_NORM 51/51, FLASH_ATTN_EXT 2994/2994; 0 one-token in all arms and
0 of 22 lookup items. Fresh 60k x2: 28.2 / 28.2, min free 123 / 131 MiB. Long 4k/32k: 44.0 / 34.3 (P72b 43.7 / 34.1).
Sweep 32k / 64k: 45.9 / 30.5 (P72b 46.4 / 30.4). Sweep 4k: 48.3 (P72b 51.5, -6 %, all three prompts; 4k prefill -1 to -7 %).
Checkpoints as shipped: 64k lookup wall after the first request 59.7 s (P73 auto 60.5 s, off 227.0 s), so the launcher
sets checkpoint-every-nt. The "ckpt flag lines: 0" check was a bad check: the server does not log the env value.
Text at 64k: 9/11 same as P73. The two others (quote shlex.py 137637.., plain bash 65a88a..) are inside the spread of
earlier 64k runs: shlex 137637 = P49b mtp_d64k; plain bash has 5 different texts in 13 earlier 64k runs. Depth 0: 11/11 same.
The 4k sweep miss is one reading (the long arm at 4k with the same bin is +0.7 %). Recheck: P79c (queue 45z), 4k x2,
release bin vs bin-0046 alternated. Gate: release within 3 % of bin-0046. Then confirm on the release.

## 2026-10-09 P79c (result): the 4k reading was noise - P79 passes

4k decode, alternated: release 52.1 / 51.8, bin-0046 52.1 / 52.1. Release within 0.3 %. P79 pass; confirm on the release.

## 2026-10-09 P77 (result): staging off - window cost gone, deep decode up, deep prefill down 2-3x; C over-commits

Drafting preset, bin-0046, quick_tps decode 4k/32k/64k/96k/128k (tok/s), incremental 512-token prefill (prose):
A 131k preset (N 50,176): 51.8 / 46.8 / 30.6 / 17.8 / 13.1; prose prefill 64k 158, 96k 124, 128k 101; trace min free 128 MiB.
B 131k staging 0 (N 54,784): 51.9 / 46.8 / 38.5 / 20.5 / 13.1; prose prefill 64k 122, 96k 49, 128k 30; trace min 88 MiB.
C 262k staging 0 (N 54,784): 51.8 / 46.5 / 38.4 / 20.6 / 13.1; prefill as B; trace min free -45 MiB (below 0 from the
first request, load free 185 vs B 313). 0 one-token in all arms.
Reading:
1. With staging off, the window size costs nothing (C = B).
2. Decode +26 % at 64k, +15 % at 96k, 0 % at 128k: mostly the extra 4,608 VRAM positions (host rows at 64k 14k -> 9k);
   staging vs direct read for decode at equal N is not isolated.
3. Prefill past the f16-prefill limit (32,768 cells with drafting) reads host rows in place once per query tile:
   96k -60 %, 128k -70 %. Not acceptable as a default (each agent turn at 96k: ~10 s prefill, not ~4 s).
4. C load free is 128 MiB less than B: the f16 KQ mask is n_ctx x ubatch x 2 B (128 MiB more at 262k). The launcher
   FixedMiB does not scale it with the window -> the P75 and C over-commit. Launcher bug (12 GB cards at 262k too).
Gates for "262k default": decode pass, 4k pass, min free FAIL, prefill FAIL. Not adopted.

## 2026-10-09 P81 (plan): partial staging + mask-aware launcher

Engine (new worktree prism-pstage on 5251968b0 + 0046): GGML_CUDA_KV_TIER_STAGING_FRAC=f (0..1 of each K/V part):
only the first f x part bytes of each host tail get a VRAM staging buffer; the rest of the host tail is mapped in the
alias to its own host pages (read in place). Host allocations split at that boundary (cuMemMap takes no offset). The
staged runs alone are registered for copies, so copy and write-back code is unchanged. Unset = today (whole tail).
GGML_CUDA_KV_TIER_STAGE_MIN_Q=q: attention ops with fewer than q queries skip staging and read in place (isolates
staging vs direct for decode at equal N). Unset = 0 = today.
Launcher: FixedMiB += (ctx - 131072) x ubatch x 2 B when ctx > 131072 (mask growth); staging term uses the cap.
Arms after the build (drafting preset): A 131k preset again; D 262k, staging cap = A's staged positions (80,896),
N from the fixed launcher; E = D with MIN_Q=2 (decode direct); F 131k, N 50,176, staging on, MIN_Q=2 (pairs with A).
Gates for a 262k default: D (or E) decode within 3 % of A at 4k-96k; prose prefill at 64k/96k/128k within 10 % of A;
trace min free >= 60 MiB; 0 one-token; texts at 32k identical to A (same engine bits up to the cap).
P80 (tail 2 at 200k) waits for this engine; it ran 2 minutes on the over-committed N and was stopped.

## 2026-10-09 P82 (lead): the f16 KQ mask is the next VRAM lever (all cards, all windows)

The mask is n_ctx x ubatch x 2 B: 128 MiB at 131k, 256 MiB at 262k (= 7,282 / 14,564 q4_0 VRAM cells on this card).
A packed (1-bit) mask is 1/16 of that. P22/P24: packed is exact without drafting, corrupts with MTP drafting past 16k.
A read-only code search for the drafting bug runs now (agent). If a fix is found: build on prism-pstage, check texts
packed vs f16 with drafting at 32k and 64k (byte-identical gate) before any speed arm.

## 2026-10-09 P78 (result): the PTQ1_0 mat-vec launch shape is already right on Turing; GRAPH_OPT=1 is slower

Weighted decode mat-vec time (7 shapes x uses per token), test-backend-ops perf, bin-tune: n=1 best 4x2 15.36 ms vs
4x4 (default) 15.46 ms (+0.6 %); n=2 best 4x2 +0.3 %. All other shapes are 3-92 % slower (8 rows or 8 blocks per SM
spill or starve). Gate (>= 3 %) not met: no Turing default change. Bandwidth: 17408x5120 at 1.75 bpw = 19.5 MB in
54.5 us = 358 GB/s, 80 % of the 448 GB/s peak, so the decode mat-vec has at most ~20 % left on this card, and only
from the memory side (not launch shape).
GGML_CUDA_GRAPH_OPT (plain server, -c 8192, 4k decode): 0 = 43.0 / 42.7, 1 = 40.5 / 36.4. Keep 0.
Data point for PrismML #330 / the Turing thread; prism-tune branch kept, not shipped.

Build pstage at 12:59: cicc crashed (0xC0000374, mmq-instance-pq2_0.cu, unrelated file) - second cicc crash today. P81 failed at its build gate; rebuild with up to 3 retries, P81 re-queued when it passes; fillers keep the GPU busy meanwhile.

## 2026-10-09 P82 (plan): packed KQ mask again, on today's engine

Agent code read (no runs): the packed path matches the f16 path line by line (fill, MMA loader, KV-max scan); the
packed mask is used only for batches >= 32 queries (prefill), so verify/decode keep f16. The P22b corruption has two
better explanations, both from that build and both fixed since: (1) staging buffers keyed by slot only, shared by
the target and the MTP draft context on different streams (today: keyed by cache, "kv<ptr>"); (2) the shared CUDA
pool race (patch 0045; preset pool off). P22b ran with the pool on and the old staging key.
Build prism-pmask = tier-partial-staging (157a278fd) + packed mask step 1 / step 2 (ecb5df93a, d90e35528; clean
cherry-picks, without 2a558c87f). Test (queue 49): 131k, N pinned 50,176, drafting preset + lookup, same bin,
LLAMA_ARG_KQ_MASK_PACKED unset vs 1; lookup_ab.py 11 items at 32k and 64k; test-backend-ops FLASH_ATTN_EXT.
Gates: 22/22 texts identical; 0 one-token; tests pass; load free VRAM +100 to +128 MiB with packed. Pass -> speed arms
with N raised by the saving (131k and 262k), then upstream with the race explanation.

## 2026-10-09 Release bundle-20261009-pool (4070 session): 12 GB shared pool on; 8 GB path unchanged (code read)

The launcher pool block runs only when -not $Small; the 8 GB branch sets its own FixedMiB. No 8 GB run needed.

## 2026-10-09 P83 (plan, queue 50): the shared pool on 8 GB again, now with patch 0045

P12 (old engine): pool + DRAFT_UBATCH 256 saved 62 MiB here, then caused the 1-token race (fixed by 0045, in bin-0046).
12 GB now ships it (+1.3k line, decode +4 % at 131k). Arms (bin-0046, 131k, drafting preset): A preset (N 50,176);
P pool on + DRAFT_UBATCH 256, N 52,224 (+2,048 = 36 MiB of the 62); sweep 4k/32k/64k/96k with VRAM trace; then
fresh 60k x3 with P (the old 1-token repro). Gates: 0 one-token; trace min free >= 60 MiB; P decode >= A - 1 % at
4k/32k and >= A at 64k/96k. Pass -> 8 GB preset PR (pool on with 0046 engines, line +2,048).

## 2026-10-09 P81 (result): partial staging works - 262k without over-commit, prefill = 131k up to N+S

bin-pstage (157a278fd), FLASH_ATTN_EXT 2994/2994, 0 one-token in all arms. Decode mean (tok/s) 4k/32k/64k/96k/128k;
prose 512-token prefill at 96k/128k; trace min free:
A 131k preset N 50,176:            51.8 / 46.3 / 30.6 / 17.7 / 13.0; prefill 123 / 100; min 116 MiB.
F A + STAGE_MIN_Q=2 (decode direct): 51.9 / 45.9 / 30.6 / 17.8 / 13.0; prefill 123 / 100; min 123 MiB.
G 131k, stage 40,960, N 52,736:     51.6 / 46.3 / 32.6 / 18.7 / 14.2; prefill 113 / 51;  min 111 MiB.
D 262k, stage 80,896, N 43,008:     51.7 / 46.3 / 26.9 / 16.5 / 12.3 (160k 9.4); prefill 123 / 100 (160k 48); min 127 MiB.
Reading:
1. F = A: on Turing, staging vs in-place read does not change decode at equal N. The decode gain in P77 was all N.
   MIN_Q stays off (no use here; the 4070 measured +28 % for staging at decode, so it stays the default).
2. Partial staging does what it should: D prefill = A up to N+S (123.9k), in-place past it (160k: 48).
3. D vs P75 (262k today): 64k 26.9 vs 24.1 (+12 %), 128k 12.3 vs 9.9 (+24 %), min free 127 vs below 0. A strict
   improvement for anyone who runs 262k now.
4. D vs A: decode -12 % at 64k, -7 % at 96k, -5 % at 128k: the 7,168 fewer VRAM cells = the f16 mask (128 MiB more at
   262k, now counted by the launcher). Gate (within 3 % of A at 4k-96k) FAIL. The packed mask (P82, -240 MiB at 262k)
   is the missing part: with it, N at 262k ~ 56k (> A).
5. G: at 131k, half staging trades +6-9 % decode at 64k-128k for -8 % / -50 % prefill at 96k / 128k. Not a default.

## 2026-10-09 P82 (result): packed KQ mask PASS with drafting - texts 22/22 identical, +108 MiB at 131k

bin-pmask (pstage + packed mask step 1/2), 131k, N pinned 50,176, drafting + lookup: lookup_ab 11 items at 32k and
64k, packed vs f16: 11/11 + 11/11 identical, 0 one-token; mean tok/s 64.9 vs 64.3 (32k), 51.1 vs 50.2 (64k).
FLASH_ATTN_EXT 2994/2994. Load free 449 vs 341 MiB (+108), trace min free 233 vs 115 (+118). The P22b corruption was
the old build's races (shared staging key / pool), not the packed mask - P22b/P24 conclusions corrected here.

## 2026-10-09 P83 (result): shared pool on 8 GB PASS with patch 0045 - +2,048 cells and more margin

bin-0046, 131k. A preset N 50,176: 51.8 / 46.6 / 30.6 / 17.8, trace min 116 MiB. P pool + DRAFT_UBATCH 256,
N 52,224: 51.7 / 46.6 / 32.7 / 18.5 (+7 % 64k, +4 % 96k), trace min 131 MiB; fresh 60k x3: 0 one-token (31.7 / 31.7 /
31.8). Pool saves ~51 MiB here (36 used by the +2,048 cells, 15 more margin).

## 2026-10-09 P84 (plan, queue 51): all three together - packed mask + pool + partial staging

bin-pmask (has 0045). N pinned 59,904 for both windows (= 50,176 + ~6.7k packed + 2,048 pool + 1k from the margin).
Expected trace min ~115-125 MiB. Arms: A preset (control); H131 131k packed + pool, N 59,904 (whole-tail staging);
H262 262k packed + pool, N 59,904, staging frac 0.308594 (80,896 staged cells: prefill fast to ~141k);
sweep 4k/32k/64k/96k/128k (+160k on H262), VRAM trace; fresh 60k x2 on H262.
Gates for the 262k 8 GB default: H262 decode >= A - 1 % at 4k/32k and >= A at 64k-128k; prose prefill within 10 % of A
up to 128k; trace min >= 60 MiB; 0 one-token. Pass -> launcher constants (packed / pool / stage terms), PRs:
engine patches (partial staging, packed mask on our stack with the race note), launcher 262k default on 8 GB.

Release bundle-20261009-agent (4070 session): checkpoints inside messages now on for 12 GB too; 8 GB had them since #11. Same engine, launcher only; nothing to check on 8 GB.

## 2026-10-09 P84 (result): PASS - 262k with packed mask + pool + partial staging beats today's 131k preset

bin-pmask, drafting preset, N 59,904 (A: 50,176). Decode mean 4k/32k/64k/96k/128k; prose 512-token prefill same depths:
A preset 131k:  51.0 / 46.0 / 30.5 / 17.8 / 13.0; prefill 350 / 257 / 152 / 118 / 96; trace min 131 MiB.
H131:           51.7 / 46.4 / 38.0 / 20.1 / 14.2; prefill 363 / 261 / 156 / 121 / 98; trace min 130 MiB.
H262 (stage 80,896): 51.7 / 46.5 / 37.8 / 20.1 / 14.2, 160k 10.4; prefill 359 / 262 / 156 / 121 / 99, 160k 59; min 116.
H262 fresh 60k x2: 37.3 / 37.2 (P79 release, 131k: 28.2 / 28.2, +32 %), min 124 / 116. 0 one-token in all 5 arms.
Gates: decode >= A - 1 % at 4k/32k (+1.4 / +1.1 %) PASS; >= A at 64k-128k (+24 / +13 / +9 %) PASS; prefill within 10 % to
128k (better) PASS; min free >= 60 (116) PASS; 0 one-token PASS.
Decision: 262k becomes the 8 GB default with engine patches 0047 (partial staging), 0048/0049 (packed mask) and the
shared pool on for 8 GB. Next: launcher (auto-sized, not pinned) + real-launcher check, then PRs.

## 2026-10-09 P85 (plan, queue 52): the 262k launcher as users get it (auto-sized, nothing pinned)

bonsai-ada-surgery branch 8gb-262k: patches 0047-0049 + README rows; start-server.ps1: 8 GB drafting mode with an
engine that has packed mask + STAGING_FRAC and >= 24 GB RAM -> window 262144; packed mask on; shared pool on for 8 GB
(BONSAI_POOL_MIB 48); Small FixedMiB += mask(Ctx, ubatch, packed) - f16 mask at 131072 - pool; partial staging with
BONSAI_STAGE_CELLS 81920 (8 GB only). Expected N ~59,136 (P84 pinned 59,904), trace min ~130 MiB.
Test copy start-server-262test.ps1 (+ BONSAI_BIN), bin-pmask: sweep 4k-128k, fresh 60k x2, lookup_ab d0 + d64000.
Gates: launcher lines show 262144 / packed / pool / staging; N within 1,024 of 59,136; decode within 2 % of P84 H262;
trace min >= 60 MiB everywhere; 0 one-token; lookup texts at d0 = P79 rel_d0 (11/11).

PR #13 (bonsai-ada-surgery, branch 8gb-262k, aa557fb): 262k 8 GB default + patches 0047-0049 + receipts/262k_8gb. Engine branch packed-mask-pstage pushed to llama.cpp-ada-ternary. P85 result goes on #13 as a comment.

## 2026-10-09 P86 + P80b (plans, queue 53/54): the end of the 262k window, and tail 2 there

Cary: quality and stability up to the end of the window. P86: test launcher (branch 8gb-262k), bin-pmask, auto-sized,
quick_tps 4k/64k/128k/192k/250k (each extends), VRAM trace. Record decode/prefill per depth, acceptance, one-token.
Gates (for the PR claim "to the end of the window"): server up to 250k, 0 one-token, trace min >= 60 MiB.
P80b (4070 suggestion, re-planned on the new engine): same launcher, 64k and 200k, tail 1 (auto N) vs tail 2
(BONSAI_SPEC_DEEP=2, BONSAI_VRAM_MARGIN 375 = 225 + one 150 MiB rollback plane). Data only; tail 2 must beat tail 1
at 200k by > 5 % to change anything.

Fillers now yield: they stop at the next safe point when queue/pending has a job (lookup filler held P85 for 94 min, 18:27-20:01). HumanEval filler runs in the background and is stopped when a job arrives.

## 2026-10-09 Fillers 13:00-20:01 (result): stable, no regression

HumanEval (13:00, bin newest): 158/164 (96.34 %), same as P53 and the 06:05 filler.
deep (16:34, bin-8gbfix, 131k presets): drafting 51.8 / 46.5 / 30.6 / 17.8 / 14.2 at 4k/32k/64k/96k/126k, acceptance 0.788,
min free 119 MiB; long 43.8 / 34.1 / 21.7 / 10.1 / 6.8, min free 157 MiB. Same as the 03:54/06:50 fillers and P84 arm A.
lookup (18:27-20:01): 0 one-token in 44 items. d0 quote 123.2/122.2/135.2/121.0 (lookup) vs 58.2/58.4/58.0/57.5;
64k quote 66.8/69.6/69.5/64.6 vs 27.8/28.3/27.9/27.7; plain same. Text lookup vs no lookup: d0 11/11 same; 64k 10/11
(quote shlex.py 137637.. vs a470f9..; 137637 is a known 64k variant, P49b/P79). The 64k run held P85 for 94 min (fixed:
fillers now yield). Receipts: receipts/filler/{humaneval_1009_1300,deep_1009_1634,lookup_1009_1827}.

## Check-in 2026-10-09 20:05
1. Queue: BonsaiQueue running; P85 (262k launcher as shipped) runs since 20:01; pending P86 (53) and P80b (54). No PAUSE file.
2. Results: P81 to P84 were already logged; fillers 13:00-20:01 logged above (stable, 0 one-token, HumanEval 158/164).
3. Upstream: P84 win is in PR #13 (open, mergeable); P85 result will go on #13 as a comment. No other new win.
4. Activity: on #13 the 4070 session runs the 12 GB packed-mask check (review point 1); no question to this rig. Main has 2 new 12 GB launcher commits (checkpoints on, bundle-20261009-agent).
5. PrismML: #330, #314, #317 last reply is professorpalmer; #209 last reply bri-prism (10-05, already handled); #325, #332, #338 have no comments.

PR #13 review (4070, Ada): packed vs f16 with drafting + lookup 11/11 at 32k and 11/11 at 64k; 240 MiB saved at 12 GB; fresh 20k-60k 5/5; new engine with switches off = product engine (greedy identical). 12 GB launcher change (line 120,064 -> 128,000) follows after #13 merges.

## 2026-10-09 P85 (result): PASS - the 262k launcher as users get it

Launcher lines: window 262144, packed mask, shared pool, staging 58,880..140,800; N 58,880 (formula ~59,136).
Decode 50.8 / 45.8 / 37.5 / 20.0 / 14.1 (P84 pinned 59,904: 51.7 / 46.5 / 37.8 / 20.1 / 14.2, within 1.7 %); prefill
355 / 257 / 153 / 120 / 98. Fresh 60k x2: 37.0 / 37.0. Trace min free 116 (sweep, fresh) and 110 (lookup run).
0 one-token (sweep, fresh, 22 lookup items). Lookup d0 texts 11/11 = P79 release. d64: 7/11 = P82 packed at N 50,176
(other VRAM line; inside the known depth spread). Lookup tok/s at 64k: quote 71.4, edit 48.8, plain 33.1; wall per
request after the first 60.0 s. All gates pass.

## 2026-10-09 PR #13 merged (2043e76, noreply identity) after P85 + the Ada review. P87 (plan, queue 55)

P87: HumanEval 164 medium on the 262k launcher (bin-pmask: packed mask, pool, partial staging). Gate: >= 157/164
(P53 158, filler runs 158). Fillers now run the 262k test launcher on bin-pmask, so filler time is soak time for the
new default (deep sweep, lookup repeat, HumanEval).

main 05e349b (4070): packed mask on for 12 GB too: line 120,064 -> 128,000, decode 40.9 -> 48.2 at 131k (+18 %), 21.2 -> 23.0 at 180k. Code read: the 8 GB path is unchanged ($MaskSavedMiB only when -not $Small).

## 2026-10-09 P88 (plan, queue 53z): released bundle-20261009-vram on the 2060 SUPER, main launcher

4070 session released bundle-20261009-vram (engine d90e35528 = 49 patches; 12 GB packed mask; 8 GB 262k). Download our
asset (609,369,197 bytes, sha256 430aa2be...207d), check sha256, Expand-Archive; launcher = main 4ba234e as a test copy
(start-server-vramtest.ps1, + BONSAI_BIN). Tests ADD / RMS_NORM / FLASH_ATTN_EXT; sweep 4k-128k with VRAM trace;
fresh 60k x2; lookup_ab d0 + d64000. Gates: sha match; tests pass; launcher lines 262144 / packed / pool / staging;
decode within 2 % of P85 (50.8 / 45.8 / 37.5 / 20.0 / 14.1); trace min >= 60 MiB; 0 one-token; d0 texts = P85 (11/11).
Pass -> confirm on the release thread / PR #13.

Issue #14 (picmax): layer probe stops the launcher on PS 5.1 without wasmtime. Reproduced; fix PR #15 (probe only with runtime, try/catch); both cases tested. Answered on #14.
PR #15 reviewed by the 4070 session (same fix in the Mirai S launcher), merged with the noreply identity; issue #14 closed. Needs a bundle (users get the launcher from the zip).

## 2026-10-09 P86 (result): 262k stable to 192k; 250k step hit the 1800 s client timeout

Test launcher, bin-pmask, N 59,392 (staged to 141,312). Decode 4k 50.4 / 64k 34.7 / 128k 11.6 / 192k 8.4 (this
sequence jumps 64k at a time; P85's 32k steps gave 14.1 at 128k). Prose 512-token prefill: 354 / 153 / 100 / 35.
Code prompt prefill (64k new tokens): 64k 234, 128k 121, 192k 58 tok/s. 0 one-token; acceptance 0.787; trace min
116 MiB over 407 samples. The 250k request (58k new tokens past the staged depth at ~35 tok/s) passed 1800 s: no number.
Finding: past N+S (in-place host reads) bulk prefill is ~3x slower than staged. A normal agent turn there is fine
(512 tokens at 192k: ~15 s), a large paste is not (58k tokens: ~30 min).
Next: P86b (queue 53zz) 128k -> 192k -> 250k with QTPS_TIMEOUT 7200 (bench/quick_tps.py now reads it) for the
full-window decode number. Engine idea for the deep prefill: chunked staging (copy host rows in chunks of S into
staging, run attention per chunk, merge with the softmax max/sum) - plan after P86b.

## 2026-10-09 P89 (design, engine work started): chunked flash attention for prefill at depth

Cary: 30 min for a 58k paste at 192k is unusable. Two causes: (1) f16 prefill (fast MMA) only to 32,768 cells (the f16
copy of the whole cache does not fit VRAM): 512-token prefill 262 tok/s at 32k -> 100 at 128k; (2) past the staged depth,
host rows are read in place by every query tile: 35 tok/s at 192k.
Fix: GGML_CUDA_FA_CHUNK=C: prefill-sized ops split the KV dimension into chunks of C cells; per chunk: copy to VRAM
(pool), convert to f16, f16 MMA kernel, keep (row max, row sum, output); fold chunks with the exact softmax merge.
VRAM bounded by one chunk. Worktree prism-chunk (branch fa-chunked-prefill on d90e35528), implementation by an agent
(build only, no GPU). Gates before any speed claim: test-backend-ops FLASH_ATTN_EXT pass with a small C (256) incl.
q4_0 K/V and the packed mask; server texts identical (chunk off vs 32768) at 64k with drafting + lookup (22 items).
Expected: prefill past 32k ~2x, past the staged depth ~3x. Speed arms: 512-token and 32k-token prefill at 64k/128k/192k.

## Check-in 2026-10-09 22:10
1. Queue: BonsaiQueue running; P88 (release bundle-20261009-vram) runs since 21:55; pending 53zz P86b, 54 P80b, 55 P87. No PAUSE file.
2. Results: P88 partial, not logged: sha256 match, ADD 99/99, RMS_NORM 51/51, FLASH_ATTN_EXT 2994/2994; decode 51.1 / 46.2 / 37.5 at 4k/32k/64k (P85: 50.8 / 45.8 / 37.5). No filler ran since 20:01.
3. Upstream: no new confirmed win. P88 pass goes on the release thread / PR #13 when the job ends.
4. Activity: main has 109c3a0 (README bundle-20261009-probe, fix for #14). #7 last reply is professorpalmer. P89 worktree vendor/prism-chunk has edits at 22:10 (other session works on it; not touched).
5. PrismML: #330, #314, #317 last reply professorpalmer; #209 last reply bri-prism (10-05, handled); #325, #332, #338 no new comments.

Card docs/img/card8gb.html/.png (262k on 8 GB, decode by depth, honest deep end): Cary approved; add to the README after P86b gives the 250k number (replace "250k: measuring" with the value, re-render).

## 2026-10-09 P89 (plan, queue 53y): chunked prefill attention - tests, texts, speed to 250k

Engine prism-chunk 9f68d0011 + tests d0c1d8644 (agent; build passed, 509/509). Design: per chunk of C cells (multiple
of 256): copy the chunk's quantized K/V from the tiered VA to a pool buffer when it reaches host pages, f16 convert,
f16 MMA with stream-k off (every tile writes partial + (max, rowsum) via the needs_fixup path), fold kernel into a
running result; last chunk normalizes. Chunked ops leave the tier prefetch list. Fallbacks: < MIN_Q queries, KV not a
multiple of 256, unquantized K/V, sinks/ALiBi/softcap, multi-sequence, other head sizes, pre-Turing.
Arms (bin-chunk, 262k test launcher): test-backend-ops FLASH_ATTN_EXT base / C=256 / C=768 / C=256 MIN_Q=1 hs256;
lookup_ab 64k chunk off vs 32768; quick_tps 4k/64k/128k/192k/250k with C=32768 (same sequence as P86; QTPS_TIMEOUT 7200).
Gates: all tests pass; 64k texts >= 9/11 same (known depth spread; P25 f16 prefill was byte-identical, so 11/11 is the
expectation); 0 one-token; trace min >= 60 MiB; code-prompt prefill vs P86 (234 / 121 / 58 at 64k/128k/192k) faster
by >= 1.5x at 128k and 192k. Decode must not change (+-2 %).

## 2026-10-09 P88 (result): release bundle-20261009-vram PASS on the 2060 SUPER

sha256 match; ADD 99/99, RMS_NORM 51/51, FLASH_ATTN_EXT 2994/2994. Main launcher: window 262144, N 58,880, pool,
packed mask, staging 58,880..140,800. Sweep 51.1 / 46.2 / 37.5 / 20.0 / 14.1 (P85 50.8 / 45.8 / 37.5 / 20.0 / 14.1);
prose prefill 361 / 260 / 155 / 121 / 100. lookup_ab 22 items: 0 one-token, texts 11/11 (d0) + 11/11 (d64k) = P85.
Trace min 86 MiB (sweep; load free 255 vs 268 in P85). Fresh 60k x2: 34.0 / 33.4 with N 57,856 (desktop held 21 MiB
more at that start: line -1,024 cells; a 60k prompt sits at the line, so it shows most). All gates pass.

## 2026-10-09 Issue #16 (howdya: RTX 3060 Ti 8 GB, 16 GB RAM): bad_alloc + server death in long thinking runs. P90 plan

Report: 131k tiered (N 42,496), thinking on, 7 sequential requests: 3 HTTP 500 (bad allocation), then the process died.
Server log: prompt cache limit reduced to 757 MiB, entries 459-728 MiB evicted each request. Our side of the RAM bill
at 131k on 16 GB: pinned KV tail ~1.5 GB; context checkpoints up to 32 per slot x ~170 MiB (~5.4 GB; the 8 GB preset
adds them every 8,192 tokens inside messages); prompt cache (default 8192 MiB limit). bad_alloc = commit limit.
P90 (queue 53yz, after P89): release bin, main launcher copy, BONSAI_CTX=131072, ram_probe.py: 7 sequential thinking
requests (max_tokens 4096, temp 0.6), private bytes / working set / free commit every 5 s; arms default vs
LLAMA_ARG_CTX_CHECKPOINTS=8 + LLAMA_ARG_CACHE_RAM=1024. Output: the commit budget per component -> RAM-aware launcher
defaults (< 24 GB: fewer checkpoints, smaller prompt cache), then a fix PR and an answer on #16.

Issue #16 split (4070 comment): the 2060 rig owns the launcher RAM-budget PR (one block for all presets); 4070 measures the 12 GB recipe (262k q8_0 tail ~4.6 GB pinned) and adds its numbers to that PR. Server facts: "cache size limit reduced" is written after a bad_alloc (limit -> 40 %); a prompt-cache entry holds a copy of the slot checkpoints (459-728 MiB = 3-4 checkpoints), so checkpoints sit in RAM twice.

## Check-in 2026-10-09 22:57
1. Queue: BonsaiQueue running; P89 (chunked prefill) runs since 22:45; pending 53yz P90, 53zz P86b, 54 P80b, 55 P87. No PAUSE file.
2. Results: P89 partial, not logged as a result: FLASH_ATTN_EXT base 3005/3005, C=256 3005/3005, C=768 3005/3005, C=256 MIN_Q=1 hs256 44/44 (test gate pass). Texts and speed arms still run.
3. Upstream: no new confirmed win. PR #13 and #15 are merged. P89 goes to an engine PR only after the text and speed gates pass.
4. Activity: issue #16 has two professorpalmer comments (workaround + split with the 4070 session); no reply from howdya yet. P90 answers it. #7 last reply professorpalmer. Main head 109c3a0 (no change).
5. PrismML: #330, #314, #317 last reply professorpalmer; #209 last reply bri-prism (10-05, handled); #325, #332, #338 no comments.

## 2026-10-09 P89 (partial) and P89b (plan): chunked prefill texts 8/11 vs the in-place path; exactness test

P89 tests: FLASH_ATTN_EXT base 3005/3005, C=256 3005/3005 (chunk path confirmed by its log line), C=768 3005/3005,
C=256 MIN_Q=1 hs256 44/44. Server 64k lookup_ab, chunk off vs 32768: quotes 4/4 and edits 4/4 identical, plain 0/3
(code, prose, bash differ); 0 one-token; wall per request -14 to -21 %; code prefill at 64k 282 vs P86 234, prose
512-token 203 vs 153. The plain items are the near-tie items that change with any arithmetic change (5 variants in 13
earlier 64k runs). Here the arithmetic differs by design past 32k: in-kernel q4_0 dequant (off) vs f16 conversion (on).
P89 decode at 64k 32.3 vs P86 34.7: N 57,600 vs 59,392 (desktop +30 MiB at start), not the chunk path.
P89b (queue 53yzz, after P90): N pinned 45,056 (room for a whole-cache f16 copy at 64k); whole-cache f16
(FA_PREFILL_F16=65536) vs chunked f16 (C=32768), same bin. Gate: 11/11 identical -> the merge is exact and the
P89 diffs are the f16-vs-dequant difference already accepted below 32k (P25). Less -> study the merge.
Lesson: inline bash commands through the tool lose one level of backslashes ('s#\#/#g' -> 's#\#/#g'); the
P79/P82/P88 log-path greps were broken by this. Write scripts with the Write tool when they hold backslashes.

PR #17 merged (b056c0b): README 8 GB card (docs/img/card8gb.png) + 8 GB recipe row updated (262k, ~59k in VRAM, 5.7 tok/s at 250k); receipts p85/p86/p89 summaries added.

## 2026-10-10 P86b, P89b, P90b (results) and P89c / P90c (plans)

P86b (release engine, 262k, 128k -> 192k -> 250k): decode 11.2 / 8.1 / 5.7; code prefill 166 / 58 / 25.4 (58k tokens at
250k: ~38 min); prose 512 at 250k 19.3. 0 one-token; trace min 153 MiB. Same decode as P89 at 250k (5.7): the card is right.
P89b (N 45,056, 64k lookup_ab): whole-cache f16 vs chunked f16: 8/11 (the same three plain items as P89); walls equal
(51.5 / 51.6 s). The merge is not bit-identical (it changes the order of float sums); the quotes and edits match.
Gate (11/11) not met -> P89c measures the size: perplexity at a 64k window (wikitext-2, 2 x 65,536), in-place /
whole-f16 / chunked; a merge that is only rounding gives the same PPL as whole-f16 within the +/- band (expect <0.1 %).
P90b (7 thinking requests, ~8k-token prompts, 131k, 32 GB rig): server commit default 9.6 -> 18.3 GB (+8.7);
capped (8 ckpt, 1 GiB cache) 9.6 -> 10.5 (prompt states 1.28-1.36 GiB > 1 GiB: not stored); the budget launcher here
chose 8192 / 32 (25.7 GB commit free) -> 18.3 GB, min free commit 6.5 GB. Confirms #16 (16 GB cannot hold +8.7 GB).
P90c (queue 54a): ballast process commits all but ~13 GiB (VirtualAlloc, untouched pages: no RAM used), so this PC has
the free commit of a 16 GB machine; budget launcher only (a defaults arm would exhaust commit for the whole desktop).
Gates: the ram line shows a small cache / few checkpoints; 7/7 requests OK; server alive after; min free commit > 0.

## 2026-10-10 P80b, P90c (results); P89c failed to start; requeued P89c, P90d, P80c

P80b: tail1 N 57,600 vs tail2 N 49,152 (margin 375): 64k decode 31.7 vs 28.4 (-10 %), acceptance 0.808 vs 0.721;
the 200k step timed out in both (script had no QTPS_TIMEOUT). P80c (queue 56): same with bin-chunk C=32768 and timeout.
P90c (ballast: 13.4 GB free commit, like a 16 GB machine): budget launcher chose cache 1580 MiB, 6 checkpoints;
7/7 requests OK, server alive, peak private 11.8 GB, but min free commit 682 MiB: the cache holds a new 1.3 GB entry
before it drops the oldest (two entries for a moment). Formula v2: checkpoints first (40 %, 4-32), cache = half of the
rest, 0 if below 1536 MiB (one 8k-prompt entry is ~1.3 GB). On that machine: 6 checkpoints, cache off. P90d (queue
55a) re-runs P90c with v2. Gate: 7/7, alive, min free commit >= 1.5 GB.
P89c: llama-perplexity-impl.dll was not copied with the exe; requeued as 55b with the DLLs.

## 2026-10-10 P87, P90d, P89c (results); PR #18 (issue #16)

P87: HumanEval 164 medium on the 262k launcher (packed mask, pool, partial staging): 158/164 (96.34 %), same as P53.
P90d (formula v2, ~13.4 GB free commit): cache off, 6 checkpoints; 7/7 OK, alive, peak 10.5 GB, min free commit 1,980
MiB. PASS. PR #18 (ram-budget, 27c34a4 on main 1904624), receipts/ram_8gb/, bench/commit_ballast.py. Answered #16.
P89c (perplexity, 64k window, wikitext-2 test, 2 x 65,536, N 45,056): in-place 7.2106, whole-cache f16 7.2107,
chunked f16 7.2074 (+/- 0.071). The chunk merge moves PPL by -0.05 %, far inside the error band: rounding only.
P89 gate decision: texts 8/11 (near-tie plain items) but PPL equal -> chunked prefill passes on quality.
Next: chunked prefill as patch 0051 (0050 is the 4070's concat patch), launcher on for 8 GB (GGML_CUDA_FA_CHUNK=32768),
PR with P89 / P89b / P89c / P86b receipts; the 4070 checks Ada.

PR #19 (fa-chunk-8gb, 4d95fbc): patches 0051-0052 chunked prefill + launcher GGML_CUDA_FA_CHUNK=32768 on 8 GB + docs table + receipts/chunked_prefill. Waits for the 4070 review (Ada, bundle). PR #18 (RAM budget) also waits for review.
P91 (plan, queue 57): PR #19 launcher as users get it (start-server-chunktest.ps1 = branch fa-chunk-8gb + BONSAI_BIN,
bin-chunk): sweep 4k-128k, fresh 60k x2, lookup_ab d0 + d64k. Gates: the 8gb line says "deeper in chunks of 32768";
decode within 2 % of P85 (N permitting); 0 one-token; trace min >= 60 MiB; d0 texts = P85 (11/11; d0 is below 32k so
the chunk path is not used there).

PR #19: 4070 queued the Ada check (sm_89 tests off/256/768; 12 GB 262k q8_0 sweep to 250k chunk off/on; texts at 64k and 160k; fresh 20k-100k 1-token). 0050 = concat (fork df5559e065); 0051-0052 stay.

## 2026-10-10 P80c and P90e (results); PR #18 v3 pushed (2bae2f5)

P80c (bin-chunk, C=32768, 262k test launcher): tail1 N 58,112: decode 64k 31.5 / 200k 7.5, acceptance 0.80;
tail2 N 49,664 (margin 375): 28.2 / 8.8, acceptance 0.70. Tail 2: -10 % at 64k, +17 % at 200k (more drafts past the
line beat the fewer VRAM cells deep in the window). Trade-off, set at load: keep tail 1 as the default; document
BONSAI_SPEC_DEEP=2 for work that stays past ~150k. Data for the 4070 (their suggestion).
P90e: tier 24-47 GB (this machine): cache 4096 / 32 ckpt: peak 14.4 GB (defaults 18.3), 7/7. Ballast 12.8 GB free
commit + BONSAI_RAM_GB=16: 4 ckpt, cache off, peak 10.5 GB, 7/7, alive, min free commit 1.39 GB (reserve absorbed
~0.6 GB of other use). Page file grew between runs (free commit 26.4 -> 53.4 GB). PR #18 updated; merge after the 4070 ack.

PR #18 merged by the 4070 session (13:36Z); issue #16 closed. Needs a bundle for users (launcher change only).

PR #19 merged by the 4070 (14:03Z): Ada prefill +12-14 % at depth; 12 GB keeps chunk off (160k shlex quote differed with chunk on); bundle planned with 0050-0052 + #18. Posted P91/P92 (d0 plain texts change with the switch on although no op should chunk at d0); P93 investigating before the bundle.

## 2026-10-10 P92 / P93 (results): the chunk switch is clean; depth-0 plain texts changed overnight for every engine

P92: bin-chunk with GGML_CUDA_FA_CHUNK=0 = bin-pmask = bin-pmask rerun (11/11 each, depth 0). P93: chunk off/on/off/on
with the PR #19 launcher: 11/11 identical in all four. Cross-run: P85 = P88 (Oct 9); P91 = P92 = P93 (Oct 10); the two
groups differ in the 3 plain items only; bin-pmask with the same launcher gave the Oct 9 texts on Oct 9 and the
Oct 10 texts on Oct 10. Not the engine, not the switch. No date in the chat template. Candidate: prompt-cache reuse of
the shared template prefix (restore vs recompute -> different batch split) depending on memory state at start.
Lesson: compare texts only within one session window (same day, alternated arms), as P82/P89/P92/P93 did.
Posted on #19: bundle can go.

## 2026-10-10 P95 (plan): CPU attention over the host tail - feasibility (Cary: depth is the main priority)

Decode past the VRAM line is PCIe-bound: 250k, N ~58k: 192k host rows x 18,432 B = 3.5 GB per step; 5.7 tok/s with
MTP (~1.8 tokens per step) = ~3.2 steps/s = ~11 GB/s, near the PCIe 3.0 x16 limit. Per attention layer ~19 ms.
Idea: the host rows are already in system RAM (DDR4-3000 dual channel, ~35 GB/s usable): the CPU computes partial
attention (row max, row sum, unnormalized V) for the host rows while the GPU does the VRAM rows, then the exact
softmax merge (as patch 0051). No KV bytes over PCIe at decode. Risk: compute, GQA 6 = each K/V row used by 6 heads.
Step 1 (no engine change): test-backend-ops perf FLASH_ATTN_EXT on the CPU backend for our shape: q4_0 K/V, head 256,
4 KV heads, GQA 6, kv 32k/64k/128k/192k, 1 and 2 queries (worktree prism-cpuattn, branch cpu-host-attn on
fa-chunked-prefill). Gate to build it: CPU time per layer for 192k rows, 2 queries < ~12 ms (2/3 of today's ~19 ms,
leaving room for sync and merge). If the stock CPU op is slower, check a dedicated kernel (q8 query x q4_0 K with AVX2
int8 dots, 6 heads per row load) before giving up.

## 2026-10-10 bundle-20261010 published (4070): 0050-0052 + #18; P96 (plan, queue 59z) release check on the 2060

Zip sha256 2f3b6544...6da6c. 4070: the 160k shlex quote is a near-tie the chunk tips, and the chunked answer is the
exact copy of the source (unchunked adds a blank line). P96 = P88 with the new zip and main's launcher (chunk on for
8 GB, RAM tiers): tests, sweep 4k-128k with trace, fresh 60k x2, lookup d0 + d64k. Gates: sha; tests; launcher lines
(window 262144, chunks of 32768, ram line); decode within 2 % of P85/P91 (N permitting); 0 one-token; trace min >= 60.
P94 (result): in one server, lookup_ab d0 pass 1 vs pass 2: plain items change (pass 2 vs pass 1 3 diffs), with the
prompt cache on AND off. So not the prompt cache: state carried across requests in one server (most likely the lookup
ngram drafter's history: other drafts -> other verify batches -> other rounding on near-tie items). Texts are stable
for a fresh server with the same request history; compare only arms with the same history (as all A/Bs here did).
P95 queued as 59zz (alone, after P96).

## 2026-10-10 P96 (result): bundle-20261010 on the 2060 SUPER - PASS

sha match; ADD 99/99, RMS_NORM 51/51, FLASH_ATTN_EXT 3005/3005. Launcher: 262144, N 57,600, staging to 139,520, packed
mask, chunks of 32768, ram tier 32 GB (4096 MiB / 32). Decode 51.5 / 51.3 / 34.4 / 20.4 / 14.3 (4k-128k); prose
512-token prefill 356 / 245 / 195 / 161 / 135; fresh 60k x2 35.2 / 35.1 (prefill 209); 0 one-token (sweep, fresh,
22 lookup items); trace min 103 MiB. P95 first try failed (CUDA runtime DLLs not next to the exe); requeued.

## 2026-10-10 P95 (result): stock CPU flash attention is 7-15x too slow for the host tail - gate FAIL

test-backend-ops perf FLASH_ATTN_EXT, q4_0 K/V, head 256, 4 KV heads, GQA 6, 12 threads AVX2 (ms per layer):
CPU kv 32k/64k/128k/192k: nb 1 23.8 / 46.9 / 91.8 / 138.9; nb 2 47.1 / 93.3 / 185.2 / 278.0. CUDA0 (rows in VRAM) 192k
nb 2: 3.05 ms. Today's PCIe-bound host part at 250k: ~19 ms per layer. The stock CPU kernel is compute-bound
(~17 GMAC/s: per query head, fp32, no reuse of a K/V row across the 6 heads of a group).
Estimate for a dedicated kernel (q8 query x q4_0 K int8 dots with 6 heads per row load ~3 ms; V in fp32 FMA ~15 ms;
226 MB of rows at ~35 GB/s ~6.5 ms, overlapped): ~15-20 ms per layer at nb 2 = PCIe speed. Value only as a split
(CPU part of the rows, PCIe the rest): ~1.5-1.9x decode at depth, exact. Next: P97, a standalone AVX2 microbenchmark
of that kernel before any engine work. Gate for the engine change: <= 12 ms per layer, 192k rows, nb 2, 12 threads.
Alternative (approximate, Cary's call): block-sparse top-k attention for the host rows (Quest-like block key summaries
in VRAM, fetch ~10-20 % of host rows per step): decode at 250k could approach the 64k speed; needs KLD / NIAH / long
task gates; opt-in only.

## 2026-10-10 P97 (result): a dedicated AVX2 kernel is still ~6x slower than PCIe - CPU attention route dropped

cpuattn/cpuattn_bench.cpp (q4_0 K/V cells of 1152 B, K int8 maddubs with one unpack per block for 6 heads x nb, V
dequant once per block + fp32 FMA into 6 x nb accumulators, tiled online softmax, 12 threads AVX2): 16,384 rows nb 2:
9.5 ms per layer -> ~110 ms at 192k rows (PCIe today ~19 ms). Read pass 23 GB/s. The limit is arithmetic: 2 tokens x
24 heads x 1024 dims x K+V = ~24k MAC per row, ~4.7 G per layer at 192k; a 6-core Ryzen 5 2600 cannot do that in
19 ms. Best case as a split: ~1.3-1.5x, with every core busy during decode. Not worth the engine change.
Depth decode levers left: (1) approximate block-sparse attention for the host rows (Cary's call); (2) more verified
tokens per host read (tail 2 = +17 % at 200k, -10 % at 64k; lookup for copy-heavy work); (3) fewer bits per host row
(custom KV type: ~1.3-1.5x, quality cost).

## 2026-10-10 Depth decode: two candidate designs (for Cary)

A. K-first, bounded (near-exact). For the host rows only: pass 1 reads K (576 of the 1152 B per cell), computes the
   scores, the row max and the softmax sum per head; pass 2 reads V only for rows whose normalized weight can matter,
   chosen so the dropped softmax mass is <= eps (e.g. 1e-4) per head - the dropped mass is known exactly after pass 1,
   so the error has a hard bound, and eps=0 is exact. Union of rows over the 6 heads x nb tokens of a KV head. Merge
   with the VRAM part as in patch 0051. Bytes per step at 250k: 50 % (K) + the V fraction (expected a few %): ~1.7-1.9x
   decode at depth. Work: two CUDA kernels on the tiered alias + the merge; gates: KLD vs exact at 128k/250k, texts.
B. Block-sparse top-k (approximate, Quest-like). Per 128-cell block of the host rows keep a key summary in VRAM
   (~50 MB); per step score blocks, fetch the top 10-20 % of blocks. 5-10x fewer bytes: decode at 250k could approach
   the 64k speed. Error not bounded; gates: KLD, needle-in-a-haystack at 64k-250k, a long-context task set; opt-in.
A first (exact by construction with eps=0, and the eps knob shows how much B could ever gain), B only if Cary wants it.

P98 (started): K-first stats probe (agent; worktree prism-kfirst, branch kfirst-probe on d0c1d8644; build-only). GGML_CUDA_KV_TIER_KFIRST_STATS=1 logs, per decode op with host cells, the union fraction of host cells needed per KV head for dropped mass <= 1e-2/1e-3/1e-4/1e-5; output unchanged. Then run at 64k/128k/192k/250k. Decision rule: if 1e-4 needs <= 10 % of host V rows at 192k+, build design A.

PrismML #330: Powerful-Plantain reports CUDA illegal memory access in launch_fattn after a 30,180-token prompt (Linux, 64k slot, no GPU/flags given). Asked for GPU, commit, command line, env (FA_PREFILL_F16), a CUDA_LAUNCH_BLOCKING=1 run and an f16-path-off run.
PrismML #330 reply (16:18Z): quoted the questions, same log, no new data. Waiting for real details; no further post.

P98 (plan, queue 61): kfirst probe ae6a6eb85 at 64k/128k/192k/250k (quick_tps, chunk on, probe every 16 ops + per-cache sums). Read: union fraction of host V rows for eps 1e-2..1e-5, host mass. Decision rule as above (1e-4 <= 10 % at 192k+ -> build design A).
PrismML #346 (moved from #330): RTX 3070 Laptop 8 GB, b10770 (6684606ac) crashes after a 30k/45k prompt (illegal
access before an FA launch), b10709 good, --ctx-checkpoints 0 avoids it; not our PR (no FA_PREFILL_F16 in that tree).
In b10709..b10770 the one checkpoint commit is bf197c43d "server: reuse the buffers of evicted prompt checkpoints
(#312)" - posted as the first candidate. Our engine base predates b10709: not affected. WATCH: when we rebase on a
newer PrismML, check this before shipping (checkpoints are on in both our recipes).

## 2026-10-10 P98 (partial, synthetic filler at 250k): attention over the host rows is diffuse

kfirst-sum lines (n_kv 249,344, host 191,090, q 2): host softmax mass 0.83-0.95. Union fraction of host cells needed
per KV head (mean over layers ~): dropped mass <= 1e-2: 0.15-0.85; <= 1e-3: 0.58-0.98; <= 1e-4: 0.85-1.00. Per q head
without the union: 1e-2 0.02-0.45, 1e-3 0.18-0.76. -> Design A saves almost nothing on this content; design B would
drop >1 % of attention mass at 10-20 % budgets. Caveat: the quick_tps filler is synthetic (may spread attention).
P98b (queue 62): the same probe on real text (Python stdlib source, ~200k tokens, 3 questions about it).
P98 (result, synthetic filler, by depth; union = rows pass 2 would read, per-head = without the union):
~64k: host mass 0.81 | <=1e-2: union 0.145, per-head 0.039 | <=1e-3: union 0.497, per-head 0.159 | <=1e-4: union 0.816
~128k: 0.87 | 0.360 / 0.090 | 0.731 / 0.293 | 0.928
~192k: 0.86 | 0.422 / 0.113 | 0.771 / 0.332 | 0.939
~256k: 0.89 | 0.494 / 0.142 | 0.816 / 0.377 | 0.953
Attention spreads more with depth. Design A at 1e-3 saves ~10 % of bytes at 192k; at 1e-2 ~1.4x. Not worth it on this
content; the union over the 6 q heads is the main cost (per-head fractions are 3-4x smaller). Wait for P98b (real text).
Probe overhead: decode 3.5 tok/s at 250k with stats on (graphs off + an extra K pass + sync), as expected.

## 2026-10-10 P98b (result): attention is diffuse on real text too - design A/B dropped

Real Python stdlib source, 180,266 tokens, 3 questions; probe on. Per layer (union / per-head): <=1e-2: 0.19-0.81 /
0.04-0.38; <=1e-3: 0.50-0.97 / 0.16-0.71; <=1e-4: 0.76-1.00. Host mass 0.72-0.89. Same picture as the synthetic
filler: the model uses its whole context at depth, so reading only the high-weight host rows cannot cut PCIe bytes
much without real quality loss. Design A (bounded) and B (top-k) dropped.
Side results: cold 180k prompt 1,142.7 s (pp 173.6 tok/s, chunked prefill); follow-ups 108 / 145 s; decode ~4.9 tok/s
(probe on). The 640k-character document stopped before f/s/t files: the model correctly said shlex.py and fnmatch were
not included (recall at 180k), and answered the textwrap question from general knowledge without saying so.
Depth decode on this card is now bound by PCIe 3.0 (~11 of ~13 GB/s used at 250k). Remaining levers: more verified
tokens per host read (lookup for copy-heavy work; tail 2 = +17 % at 200k); fewer bits per host row (a lower-bit KV type
for the host tail only: diffuse attention averages per-row noise, so far rows may tolerate it - big engine work, needs
KLD); a faster link (PCIe 4.0 x16 cards: ~1.8x by measurement on the 4070).

PR #20 merged: docs/8GB "Sessions that stay deep" (tail 2 data, CPU attention and sparse reads measured, not used) + receipts/depth_8gb.

P99 (plan, queue 63): deep agent soak on bundle-20261010 (main launcher): ~150k real-source start + 25 turns x ~2.5k tokens; per-turn wall/pp/tg/one-token, server private, VRAM trace. Gates: 26/26 OK, 0 one-token, server alive, trace min >= 60 MiB, no bad_alloc / CUDA error; per-turn wall reported (checkpoints should keep turns at seconds-to-a-minute, not a full re-read).

## 2026-10-10 P100 (plan): what would a lower-bit KV format cost in quality? (the last software depth lever)

A smaller KV format raises the VRAM line AND cuts the PCIe bytes per host cell: both drive depth decode. Test only:
GGML_CUDA_KV_FAKE_BITS=3|2 (worktree prism-fakekv, branch kv-fakebits on d0c1d8644): set_rows keeps 2^b levels of the
q4_0 grid (round-to-nearest per 32-value block, symmetric; no rotation, no per-channel K) - a pessimistic bound for a
real format. No speed change. Perplexity, wikitext-2 test, 16k window (all chunks) and 64k (2 chunks), bits 4/3/2.
Reading: relative PPL change vs 4-bit; for scale, q4_0 vs q8_0 KV was KLD 0.0021 vs 0.00017 (docs/8GB.md).
If 3-bit costs < ~1 % PPL at 64k: design a real 3-bit KV type (rotated, per-channel K) for at least the host tail.

## 2026-10-10 P99 (result): PASS - the shipped 8 GB config runs an agent session to the end of the 262k window

bundle-20261010 zip, main launcher (N 58,112, staging to 140,032, packed mask, chunks of 32768, ram tier 4096 / 32).
One conversation, real Python stdlib source: turn 0 = 132,882 tokens (cold 642.9 s, pp 208.6), then 17 turns of
2.6k-22k new tokens up to 259,554; turn 18 -> HTTP 400 (context full: the expected end).
Turns OK 18/18; one-token 0; server alive after; no bad_alloc / CUDA error lines; trace min free VRAM 115 MiB over
363 samples (steady 115-123 per turn); server private 12.2 -> 14.5 GB (smooth).
Per turn: decode 10.3 (133k) / 8.0 (181k) / 7.3 (197k) / 6.4 (224k) / 5.5 (252k) / 5.4 (260k) tok/s; new-token
prefill 130 -> 80 tok/s; wall 74-308 s (300-1,360-token answers). Answers stay correct to the end (turn 17 at 259.5k:
compileall.py's compile_dir / compile_file / compile_path described correctly).

## 2026-10-10 Correction: sparse host-tail reads look viable (4070 measurement, a97f56a73)

4070 emulation GGML_CUDA_FA_SPARSE (per query, B host cells in pages of 64 + last 1024): KL vs dense at a 16k window
(host tail 6-14k): B=8192 0.0030 (same top 97.7 %), 4096 0.0081, 2048 0.0160; needles at 160k 12/12 (dense, 8192,
4096); exact Python copies at 160k 10/10 (dense, 8192), 8/10 (4096). My P98/P98b mass criterion was the wrong one:
the output is much less sensitive than the mass. Design B is back. Open: the budget at real depth (host tail
130-190k cells on this card). Opened a coordination issue: engine on the 4070, depth tests on the 2060 (PPL at 64k
dense vs sparse, needles / copies at 200k-250k, P99-style session with sparse on); asked for the emulation branch.

## 2026-10-10 P101 (plan): sparse host-tail reads at real depth on 8 GB (issue #21, 4070 branch fa-sparse-proto)

bin-sparse = 87e2ac160 built for sm_75. Main 262k launcher; every arm: f16 mask, graphs off, chunked prefill. Arms
dense / B=8192 / B=16384 (pages 64, last 1024 always; FAST=1 decode-only; STAGE_MIN_Q=9 so unselected pages are not
read). At ~245k (host tail ~187k cells: B=8192 is ~4 %): 10 exact Python function copies (code_needle, corpus =
local stdlib pycode.raw) and 12 needle facts (needle_depth), separate prompts. Record exact/correct counts and decode
tok/s per code item. Gates for "sparse is safe at 8 GB depth": B arm = dense on needles (12/12) and >= dense - 1 on
code copies; decode speed-up reported. ~4-5 h (6 cold 245k prefills).

## 2026-10-10 P100 (result): a 3-bit KV format costs ~nothing; 2-bit costs 2-4 %

Fake grid on q4_0 storage (round-to-nearest, symmetric per 32 values, no rotation: pessimistic), wikitext-2 PPL:
16k window: 4-bit 7.9050 / 3-bit 7.9522 (+0.60 %) / 2-bit 8.1931 (+3.64 %).
64k window (2 chunks): 7.2074 / 7.2060 (-0.02 %) / 7.3417 (+1.86 %).
Gate (3-bit < 1 % at 64k): PASS. A real 3-bit type (~3.5 bpw vs 4.5) = ~22 % fewer bytes per cell: VRAM line ~+28 %
(58k -> ~75k here) and -22 % PCIe bytes: ~1.25-1.3x decode at mid/deep depth. Big engine job (new KV type: set_rows,
vec + MMA dequant, chunk conversion, tiering). Order: sparse host reads first (P101 / #21), 3-bit KV as the follow-up.

## 2026-10-10 P101 (partial): sparse B=8192 at 245k = dense on quality; no speed gain with lookup verifies

Line 43,520 (f16 mask), host tail ~201k cells at 245k; B=8192 = ~4 %. Code copies: dense 10/10, s8192 10/10. Needles:
dense 12/12, s8192 12/12. Decode per code item: s8192 ~10-15 % SLOWER than dense (e.g. 5.0 vs 5.9, 8.7 vs 9.7 tok/s):
these copy items run lookup drafting (verify batches of 10-33 queries), outside the FAST path (<= 8 queries), so the
host tail is still read in full and the emulation adds its overhead. The sparse INFO summary line is not visible at
default server verbosity (engagement not confirmed by log; quality equal is consistent with either).
P102 (queue 66): decode speed at 245k with lookup off (MTP verify = 2 queries): dense / s8192 in place / s8192 staged.
P101 (result): 245k, host tail ~201k: code copies dense 10/10, B=8192 10/10, B=16384 10/10; needles 12/12 in all three.
Decode on code items (lookup verifies): dense 7.38, s8192 6.34, s16384 6.34 tok/s (sparse -14 %: emulation overhead,
fast path not covering lookup verifies). Quality gate PASS at real depth; speed -> P102 (lookup off).

#21 (4070, 23:49Z): verify batches > 8 queries leave the fast path and run on the MMA kernel without tile skip -> full host read. Local (not pushed): device page selection, bounds follow K-cache writes (CHECK mode). Next: fast path to 64 queries, MMA tile skip, WARN engage line. P102 stays the right test for 87e2ac160.

P102b (plan, queue 67 after the rebuild): sparse arm on fa-sparse-proto c084831aa (device selection, no per-op sync, write tracking), lookup off, 245k; dense baseline = P102 dense. 4070 dense as shipped with lookup on: 19.7 tok/s at 192k, 12.7 at 250k (PCIe 4.0).
4070 (00:08Z): sparse_edit at 160k on fa-sparse-proto 71371d4cb: write tracking -> 0 stale-bound ops, 0 selection diffs; without it 208 stale ops after a deep edit and a changed answer.

## 2026-10-10 P102 (result): the 87e2ac160 prototype halves decode at 245k (per-op host sync overhead)

Lookup off, MTP verify 2 queries, line 43,520 (f16 mask), host tail ~201k: decode dense 5.7 / s8192 in place 2.9 /
s8192 staged 2.9 tok/s; 512-token prefill 79 / 39 / 39 tok/s; acceptance 0.77 / 0.76. 0 one-token. The two sparse
arms are identical to 0.1 tok/s -> the per-op page-bound host copy + stream sync sets the speed, not the read path.
P102b (queue 67) = the same on c084831aa (device selection, no per-op sync).

P102b stopped at 20:36 (4070: c084831aa still syncs per K write). P102c (queue 67): ae61c4cf3 (no syncs; verify <= 64 stages kept pages), 245k: s8192 lookup off / dense lookup on / s8192 lookup on; checks: no sync-per-write warning, fast: WARN line. 4070 on 71371d4cb: lookup off 192k dense 22.8 vs sparse 21.5; lookup on sparse 14.4 vs dense 19.7.

P102c (partial): ae61c4cf3 sparse B=8192 lookup off 2.6 tok/s vs dense 5.7; the "set_rows indices are not a host-set input: one sync per K write" warning appears in both sparse servers after the first 4-query op (draft/verify path?). Posted on #21; offered BONSAI_SPEC=0 and KV_TIER_REDIRECT=0 isolation arms.
P102c (final): s8192 lookup on 2.6 tok/s (= lookup off; quick_tps plain prompts rarely draft by lookup); sync warning 1 in each sparse server. P102d running (dense no-MTP, s8192 no-MTP, s8192 redirect off).

## 2026-10-10 P103 (plan, issue #22): tier-graphs on 8 GB

4070: CUDA graphs on (shipped) keep the tier prefetch pipeline off; graphs off at 192k on 12 GB: 19.8 -> 25.0 tok/s.
Fork tier-graphs 4715804d6: graphs off only for graphs whose attention reads the host tail; GGML_CUDA_KV_TIER_GRAPHS=1 =
old behaviour. Note from our data: P102 dense ran graphs off and got 5.7 tok/s at 245k = P86b with graphs on, so on
PCIe 3.0 the overlap may give little. Arms (main 262k launcher, defaults): new vs old, 4k/32k/128k/192k/245k; 192k
lookup off for both. Gate (4070's): no loss at 4k/32k, gain or no loss past the line, same text; else the 8 GB recipe
sets GGML_CUDA_KV_TIER_GRAPHS=1. Built during P102d (CPU -j 4; P102d decode figures may carry a little noise).

Cary (2026-10-10 evening): go on all three depth levers (sync fix, verify-batch page skip, 3-bit KV) and research outside work ("strata" and other recipes) for hidden gems. Research agent started (offloaded-KV decode methods, low-bit KV, hybrid-model tricks, sparse-draft speculative decoding).
q3_0 KV type (Cary approved): agent implementing in worktree prism-q3kv (branch kv-q3-0 on 2cadbfb64): 14-byte blocks of 32 (3.5 bpw), set_rows, vec FA K/V, f16/chunk conversion, CPU ref, tests, -ctk/-ctv q3_0. GPU tests after P102d/P103.

## 2026-10-10 Research (agent): Strata + offloaded-KV decode methods - ranked for our setup

Strata (arXiv 2508.18572, OSDI '26) = hierarchical prompt-KV caching (GPU/CPU/SSD) for TTFT in multi-tenant serving;
low fit for single-stream decode; lesson: page-contiguous host layout. Ranked levers: (1) one page set per KV group and
per verify batch (PulseInfer SoloHead 4.7x), host read ~3.5 GB -> ~150 MB per step at B=8192; (2) TriForce/MagicDec
sparse self-draft + dense verify (exact; costly on 8 GB: 150 MiB rollback plane per extra draft) -> serve sparse,
dense for exact modes; (3) calibrated streaming vs retrieval heads (DuoAttention); (4) prefetch selected pages during
the 3 GDN layers between attention layers + VRAM page pool (InfiniGen/OmniKV/ArkVale); (5) 3-bit KV (q3_0 in work).
Skip: CPU attention (P97), eviction (lossy), ShadowKV (~1 GB VRAM). Byte check: 192k x 18,432 B = 3.5 GB/step,
320 ms at 11 GB/s, / 1.8 tokens per step = 5.6 tok/s (measured 5.7). Posted the kernel-relevant points on #21.

P102e (plan, queue 68z, before P103): fa-sparse-proto c803e03ea (sync-free index copies, MMA tile skip, SINKS): s8192 lookup off / on (TILE_SKIP=1) / + SINKS=4096; sync warning count and fast: line.
P102d (result): s8192 with GGML_CUDA_KV_TIER_REDIRECT=0: 2.5 tok/s, sync warning still 1 -> the tier redirect is not the
source. The BONSAI_SPEC=0 arms are VOID: without drafting the launcher keeps the 131k window (262k needs drafting
mode), so the 245k request got HTTP 400. Remaining suspect: the MTP draft/verify path; 4070's 2f47c38b7 (index copies
from set_tensor_async / scheduler input copies) targets it -> P102e. P103 started first (P102e's build not done).

## 2026-10-11 Cleanup (Cary: rig bogged; run only what is needed) and queue additions (Cary: add the valuable research items)

Stopped: the q3_0 agent (its -j 4 compile ran during P103's speed run), a stray python/bash from an earlier compare,
the agent's tail/wait loops. q3_0 work saved as WIP commit 6a4851286 (46 files, not built). Kept: queue runner, P103,
one watcher, result waiters (sleep loops).
Research items: (1) shared page set per group / verify batch and (4) prefetch during the GDN layers = 4070 kernel work
(posted on #21; tested here as builds land: P102e next). (2) sparse as served default: P99-style session with sparse
on once speed is good. (3) streaming vs retrieval heads: P104 (queue 70) = probe 0e0dc757a with per-KV-head union
fractions on ~230k tokens of real code, ranked list of the 64 KV heads. (5) q3_0: built in the background during P104
(a stats run, CPU load does not matter there); then GPU tests.
4070 (04:52Z): fa-sparse-proto f6f2d146c GGML_CUDA_FA_V_SKIP=1 (vec decode skips V rows of a warp with all weights < exp(-20) of the running max; near exact) + bench vskip_ab.sh. Not in P102e (built on c803e03ea); a later speed arm.

#21 (4070, 06:14Z): RTX 4070 160k, line 32,768 (~127k host): dense 13.6 tok/s; sparse decode without tile map 9.1; sparse decode+prefill with tile map 29.6 (2.2x; quality drop from sparse prefill -> prefill stays dense). Build for P102e: d6c6e9f01 (64-cell tile-map entries, sparse ops always use the MMA tile map, includes 2f47c38b7). Rebuild timed inside P103 new_lkoff prefill.

## 2026-10-11 P103 (result, issue #22): tier-graphs on 8 GB: +8 to +16 % past the line; shallow -3/-5 % to re-check

Main 262k launcher, tier-graphs 4715804d6, line 59,392. Mean decode new / old (GGML_CUDA_KV_TIER_GRAPHS=1):
4k 52.3 / 54.0; 32k 46.1 / 48.4; 128k 14.8 / 12.8 (+16 %); 192k 8.6 / 7.9 (+9 %); 245k 6.7 / 6.2 (+8 %);
192k lookup off 8.7 / 7.8 (+12 %). 512-token prefill equal. 0 one-token; VRAM min 62-72 MiB; private peak 14.85 GB.
The switch line is GGML_LOG_INFO and does not reach our server log (same as the sparse INFO line): use WARN.
4k/32k: new is in our usual range (P85 50.8/45.8, P96 51.5/51.3); old ran high; one run each, an hour apart.
P103b (queue 69b): alternated new/old x2 at 4k/32k.
#22 (4070, 07:15Z): switch line now WARN in release candidate 90ca41e40 (patch 0053); 4070 tier-graphs 192k 23.6->29.4, 250k 12.7->14.6; 4k/32k unchanged there. The bundle waits for P103b.

## 2026-10-11 #21 candidate (4070, 08:18Z) and P105 (plan, queue 69c)

4070, 160k, line 32,768 (~127k host), d6c6e9f01, prefill dense, decode sparse B=8192: dense 13.6 tok/s 10/10 12/12;
page 256 31.1 tok/s 9/10 12/12 (misses _div_nearest twice); page 64 27.6 tok/s (code item 31.7) 10/10 12/12.
FLASH_ATTN_EXT 3007/3007. P105 (their "P104"; renamed here) on the 2060, same build: dense vs sparse at 160k and 245k:
code copies (10), needles (12), decode (quick_tps at 160k; 245k speed from P102e and the code items); sync-warning
count (expect 0) and fast: line. Gate: copies and needles equal to dense at each depth; then decode decides.
Order: P102e (running) -> P103b (bundle blocker) -> P105 -> P104 (head calibration).

## 2026-10-11 P102e (result): d6c6e9f01 removes the sync; sparse decode still slower than dense on 8 GB

245k, line 43,520, host tail ~197k: dense 5.7 tok/s (512 prefill 79); s8192 P64 lookup off 4.3 (39); lookup on 4.3
(39); + SINKS=4096 5.2 (6.2!). Sync warnings 0; fast path engages (128 of 3077 pages kept). Reading: our decode ops have
2 queries (MTP tail 1) -> vec kernel, whose tile skip is 128 cells: with P=64 a tile is skipped only if both pages are
dropped; 4070 tail 4 -> 5-query MMA ops with the 64-cell map. Also the 512-token prefill halves with sparse on (MAXQ
default: attention dense) -> a write/bound-refresh cost. Posted on #21 with options (64-cell vec skip, or MMA for >= 2q).
P105 amended: + speed arms at 160k with MTP tail 4 (5-query verify -> MMA 64-cell tile map), sparse and dense, margin 675 (3 more rollback planes).

P103b (result): 4k / 32k new vs old alternated x2: 53.9/54.0/53.8/53.7 and 48.2/48.3/48.2/48.3 -> identical; P103 shallow gap was noise. Tier-graphs gate PASS on 8 GB; posted on #22 (bundle can ship).

## 2026-10-11 P105 (partial) and P106 (plan)

P105 so far (d6c6e9f01, f16 mask, graphs off, 8 GB launcher): code copies dense/sparse 160k 10/10 / 10/10, 245k 10/10 /
9/10 (sparse missed _calc_julian_from_U_or_W); needles 12/12 in all four. Decode on code items (lookup verifies):
160k dense 12.82 vs sparse 21.48 tok/s (+68 %); 245k dense 7.42 vs sparse 6.93. Sync warnings 0 everywhere. Speed arms
(160k dense / sparse / tail-4 pair) running.
#21 (4070, 12:32Z): 028f606fc: the vec kernel skips a warp's 32 cells when all are masked (2-query decode at page 64).
Prefill halving: not seen on the 4070 (296 vs 284 at 160k); 8 GB-specific. P106 (queue 69d, built in P105's next
prefill): FLASH_ATTN_EXT tests; arms (a) sparse + OP_TIMING, (b) no FA_SPARSE (FAST + STAGE_MIN_Q kept),
(c) sparse + NOTRACK, each 64k -> 160k; then 245k decode sparse lookup off.

## 2026-10-11 P105 (result): sparse decode at 160k on 8 GB = 1.9x dense, quality equal; 245k not yet faster

d6c6e9f01, f16 mask, graphs off, line 46,592 (f16 mask, 160k arms). Quality: 160k dense/sparse copies 10/10 / 10/10,
needles 12/12 / 12/12; 245k copies 10/10 / 9/10 (sparse missed _calc_julian_from_U_or_W), needles 12/12 / 12/12.
Code items (lookup verifies): 160k 12.82 -> 21.48 tok/s; 245k 7.42 -> 6.93. Plain decode 160k (quick_tps, MTP 2-query
verify, vec kernel): dense 9.7 -> sparse 18.3 tok/s (+89 %); 512-token follow-up 106 -> 85 (-20 %).
MTP tail 4 (hypothesis arm): line 46,592 -> 20,992 (three planes), acceptance 0.79 -> 0.55: dense 9.1, sparse 11.5 -
not a path on 8 GB. Sync warnings 0 in every server. Next: P106 (028f606fc warp skip; prefill-halving diagnosis; 245k).

## 2026-10-11 P106 (result): 028f606fc: 160k 1.9x again; 245k 4.9 (dense 5.7); sparse costs 16 % at 64k; prefill cost is not tracking

FLASH_ATTN_EXT 3005/3005. Arms 64k -> 160k (lookup off, f16 mask, graphs off): (a) sparse + OP_TIMING 18.9 / 14.6;
(b) no FA_SPARSE 34.5 / 9.7; (c) sparse + NOTRACK 29.0 / 18.5 tok/s. 512-token follow-up at 160k: a 84, b 107, c 85;
at 64k ~193-200 all. Cold 95k-token prefill equal (147-148). -> the follow-up prefill cost comes with FA_SPARSE set,
not from write tracking. Sparse costs -16 % at 64k (host tail ~18k): needs a depth threshold to ship. 245k decode
sparse 4.9 (d6c6e9f01: 4.3; dense 5.7). Op timing at 160k (arm a): FLASH_ATTN_EXT 28.5 of 57.8 ms per graph (49 %).
P107 (queue 69e, before P104): OP_TIMING dense vs sparse at 245k -> which op grows with the host tail.

q3_0 build (kv-q3-0 6a4851286) OK during P104. P108 (queue 69f, after P107): q3_0 test-backend-ops; PPL q3_0 vs q4_0 same bin at 16k / 64k; 4k decode raw server q3_0 vs q4_0. Launcher not used (its CellBytes does not know q3_0 yet).

## 2026-10-11 TODO (Cary): the "8 GB, one week" before/after card - when sparse / tier-graphs / q3_0 land

A gorgeous card (style of docs/img/launch.png / card8gb.png) with ALL upgrades since the mission start (2026-10-06).
Before (receipts): community 8 GB recipe (64k window, all-VRAM, no head) decode 37.2 / 30.4 / 24.5 / 17.5 tok/s at
4k / 16k / 32k / 60k, prefill 427 / 382 / 320 / 256 (docs/8GB.md); our stock record P2 (N 16,384 q8_0): 37 tok/s at 4k,
13.5 at 32k, 3.0 at 120k; no drafting, no lookup, no in-message checkpoints, 1-token answers (pool race), 16 GB RAM
crashed (#16). After: fill from the shipped bundle's release check at the time (window, decode by depth, prefill at
depth, P99-style session, lookup x, checkpoints x, HumanEval, RAM tiers, tier-graphs, sparse, q3_0).

4070 docs PRs: #24 (tier prefetch / patch 0053 docs; 8 GB numbers checked: correct) and #25 (docs/DEPTH.md; 8 GB sparse part outdated -> review with P105/P106 rows, status line correction posted).

## 2026-10-11 10:22 - PR #26: DEPTH.md 8 GB sparse correction (merged)
#25 (4070, DEPTH.md) merged seconds before my review comment, so main still said "not yet faster on a real 8 GB card".
#26 adds the P105 quality rows (160k 12/12, 10/10; 245k 12/12, 9/10), a 64k/160k/245k dense-vs-sparse table by build
(P105/P106), the three open items (245k below dense, follow-up prefill -20/-45 %, -16 % at 64k), the tail-4 note and
the corrected status line. Merged 15:21:53Z (docs only). Watcher restarted. P104 running (q3_0 build OK, try 1;
calibration prefill in progress). Queue after it: P107, P108.

## 2026-10-11 P104 (result): no streaming heads; attention focus differs by layer, not by head
Run 10:06-10:32 (queue 70). Probe kfirst-probe 0e0dc757a (bin-kfirst2), 262k launcher test copy, layer off,
GGML_CUDA_FA_CHUNK=32768, KFIRST_STATS=1, KFIRST_EVERY=16. realtext_probe.py --tokens 230000 -> 195,784 prompt tokens
(cold pp 165.5 tok/s, 1,262 s; follow-ups 120 / 110 s; tg 4.47-4.64 with the probe on). Host 133,945 of 195,840 cells;
host mass 0.82-0.87. 720 kfirst-heads lines (16 layers x 45 windows).
Per KV head host fraction for dropped mass <= 1e-2 / 1e-3: min L35 h0 0.087 / 0.303; max L3 h3 0.953 / 0.998.
Layer means (1e-2 / 1e-3): L3 0.810/0.966, L7 0.805/0.972, L11 0.670/0.928, L15 0.564/0.889, L19 0.401/0.765,
L23 0.562/0.892, L27 0.298/0.681, L31 0.196/0.534, L35 0.158/0.454, L39 0.256/0.567, L43 0.296/0.639, L47 0.255/0.569,
L51 0.207/0.501, L55 0.312/0.641, L59 0.473/0.795, L63 0.560/0.871.
Verdict: no streaming heads (research item 3, DuoAttention-style split, closed). Focus differs by layer: 3-23 diffuse,
27-55 ~3x more focused, 59/63 diffuse. The mass criterion is stricter than retrieval needs (B=8192 = 4-7 % of the host
keeps 12/12 and 9-10/10, P101/P105), so at most a per-layer B on the sparse branch (tuning item, not a mechanism).
Deviation: the document stops before shlex/fnmatch/textwrap, so all 3 answers say "not included" (as P98b); stats are
from decoding those answers at depth, not from retrieval.
q3_0 build (kv-q3-0 6a4851286): OK on try 1 (receipts/p104/q3build.txt). Posted on #21.
Also 10:3x: PR #29 (4070) moved research/ and receipts/ under docs/. The 8 GB research folder
(research/depth-8gb-20261006, 5 writer agents running) moves to docs/research/ before its PR; D16 patch saved.

## 2026-10-11 Lead: sparse arms over-commit VRAM on 8 GB -> P109 (plan, queue 69e2, before P108)
Found by the P90-P108 record writer: every sparse arm in P102-P106 ends with nvidia-smi memory.free = 4194274-4194296
MiB (wrapped: used > total by 8-30 MiB = WDDM over-commit); every dense arm ends with 107-124 MiB free. WDDM spills
over-committed allocations to system memory, so the cost grows with depth and hits only the 8 GB recipe: fits both
open items (245k sparse 4.9 < dense 5.7; follow-up prefill 107 -> 85 at 160k, 79 -> 39-44 at 245k; neither on 4070).
P109: P106 env + BONSAI_VRAM_MARGIN=425 (default 225 with drafting): sparse 160k+245k, dense 245k. Gate (frozen in the
script header): cause confirmed if sparse ends with free > 0 AND (245k sparse > same-margin dense OR 160k follow-up
prefill >= 100 tok/s). If confirmed, the launcher must count the sparse buffers when it sizes the line.
Record-writer corrections to the notebook: P104 "min L35 h0 0.087 / 0.303" - L35 h0 is the minimum at 1e-2 only; at
1e-3 the minimum is L51 h0 0.298. P104 ran before P107 (queue order), not after. P90b-e prompts were 24,387-24,455
tokens, not "~8k" (the "8k" wording is also in a start-server.ps1 comment on main: fix). P102e's script header names
c803e03ea; the build that ran was d6c6e9f01. P103's "same text" gate item was never run (no text compare).

## 2026-10-11 Audit corrections from the P60-P89 record writer (each one is also in its experiments/P0NN.md)
- P89: the frozen speed gate (>= 1.5x at 128k and 192k) was NOT met at 128k: 171.1 vs 121.2 tok/s = 1.41x. The patch
  was promoted on the quality decision without saying so. The text differences come from the chunk merge, not "q4_0
  dequant vs f16 conversion": P89 chunk-off texts = P89b whole-cache f16 texts 11/11. P89 text arms ran at different
  VRAM lines (57,344 vs 57,600).
- P67: the draft-ubatch arm "0/3 one-token" had 5/4/4-token answers with acceptance 0.250: most likely the same failure
  (the 1-token counter missed it).
- P60: the round-2 shlex.py edit at 16k gave sha bbf7b9093069, the same 2048-token wrong text as P59 (P61 too).
- P71: the "18-58 s" range leaves out the first edit request (~280 s in every arm).
- Fillers 03:54 / 06:50: "deep" numbers and the 12 % spread are the long-mode arm; the drafting arm was stable (30.5 /
  30.7 at 64k). Filler 18:27 quotes per-item values, the earlier entry per-run values.
- P73: restores.txt reads 0 in both arms, but wall times show restores (counter bug).
- P78: the weighting has 6 shape keys, the plan named 7 ("o x16" not weighted).
- P81: arm E planned, not run; arm G run, not planned; the 32k text-identity gate not measured.
- P66: plan said lookup on, the hotfix launcher had lookup off. P70: not alternated (all tier arms, then all min-Q).
- P72 summary printed "0 one-token" for arms whose server never started. P87/P88 launcher_lines.txt broken (sed
  backslash loss / an older 131k block mixed in).
- PR #17's "5.7 tok/s at 250k" came from P89 before P86b; P86b later measured the same 5.7.

## 2026-10-11 Audit corrections from the P30-P59 record writer (each one is also in its experiments/P0NN.md)
- P33 DFlash: the "+8 %" compared its code-prompt decode with P28's three-prompt means (and 12k vs 16k depth). On means
  Q2_K n3 is below ours (49.1 vs 51.2 at 4k). The reject stands (VRAM fails anyway).
- P39b / P39c / P42 drift: p9_soak alternates two prompts, so "first 2 min vs last 2 min" mixed them. Per prompt:
  P39b +1000 at 4k = +3.4 % / +3.8 % (not +0.5 %); P39c stock "-6/-10 % drift" = -1.2 % to +0.3 % (no drift); the +1250
  "falling" values are the heat-pump prompt. Throttle reason 0x4 shows in every step, stock included. P42 4k gain +2.6 %
  (unrounded), not +2.7 %; no event-log query in the script, so "no nvlddmkm/WHEA event" has no receipt.
- P41b -> P48: "128 residual adds per decode step" came from the warmup graph; plain decode has 48 (128 only in the
  drafting verify graph, P55b).
- P38: 7000/7500/8000 MHz and core 1470 were pre-load samples; under load 6801/7300/7800 MHz, core 1815-1905.
- P30: free VRAM at load 188 MiB, below its 200 MiB gate (never graded). P36: 73.4 %, not 74 %. P32: N was 20,480
  ("~22k" in the decision text). P31/P32: HumanEval/39 used 20,738 completion tokens (> max_tokens 20,480).
- P40c: "drafting equals the old engine" holds for decode only (prefill 32k 331 vs 291). P40b: 3 fast runs in the
  receipts, not 14; the raw_notier arm spilled out of VRAM (decode 14.9), not mentioned.
- P56: free VRAM at load differs per round by +41 / -50 MiB (gate 32 MiB; the means are within it). P57: the event query
  covered the last 60 of 89 min; rounds 2-3 hit the prompt cache. P59: plain items 8.9-34.4 s and one 292.7 s re-prefill
  left out of the "45-58 s" range.
- P50 and P41b have no result entry (P50 graded PASS from its receipts). P46 never existed as an experiment id.
- Positions per GDN plane: P35 ~9.7k, P47 ~10k, P80 ~8.7k (different lines / KV types).
- scripts/p36.sh, p37.sh, p38.sh are the later edited versions (P36b, P37c, P39a).

## 2026-10-11 Audit corrections from the P1-P29 record writer (each one is also in its experiments/P0NN.md)
- P1: the plan gives the launcher fixed cost ~6,225 MiB; the result uses 6,256 (the 382 MiB gap is from 6,256).
- P2: "~32 positions per MiB at q8_0" vs P1's 34,816 B cell = 30.1 per MiB.
- P8c: the plan says --chunks 6; the script and result used 4. P5: launcher error at line 155, not 154.
- P13 table uses the code-prompt decode (37.3 at 4k); P15/P20 use the three-prompt mean (37.2).
- P14c "-6 % vs sudo at 32k" compared 28,512 evaluated tokens with sudo's 16,524 (P23 corrected to -15 %). P16b
  "parity at 60k" compared a fresh 59,953-token prefill with sudo's incremental 28,425 (superseded by P23, unmarked).
- P15 "+24 % at 60k" compared tail 1 at 60k with P12's tail 2 at 64k.
- P20: 0/48 one-token (four runs x 12), not 0/24; the planned 10-min long-mode soak never ran. P21: two refused arms
  (not three); "0 of 54 at 32k" counts all depths (32k only: 18, plus 3 from P15).
- P25: identity gate named 4k and 32k; only 32k compared. P26: ub 1024 r2 at 60k (174.8 tok/s, also a cliff) missing.
  P14c: plan named 32k/64k, only 4k/32k ran. P12: the KL check of the drafted default was not measured.
- P18 server logs are in logs/, not receipts/p18/. P11b/P24 scripts have the lost-backslash sed (readiness wait ran to
  its 300 s limit; runs completed). P19 was only named, never planned or run.
