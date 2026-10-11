# Index, P30 to P59

Events of this range (releases, PRs, incidents, process changes): `events-p030-p059.md`.

| ID | date | title | status | one-line result |
| --- | --- | --- | --- | --- |
| [P030](P030.md) | 2026-10-07 | The full 262,144 window, long mode, ub 1024 | PARTIAL | Loads with 44,288 positions in VRAM but free 188 MiB (< 200 gate); 4k decode 43.1, prefill 243.7; sweep stopped, parked |
| [P031](P031.md) | 2026-10-07 | HumanEval 164 on the 8 GB drafting mode (q4_0) | PASS | 157/164 (95.73 %), gate >= 157 met at the boundary; 12 GB 159-161 |
| [P032](P032.md) | 2026-10-07 | HumanEval with q8_0 K/V on the same mode | PASS | 159/164; between the pre-set branches; q4_0 stays default, q8_0 documented as quality option |
| [P033](P033.md) | 2026-10-07 | DFlash 2 drafters vs our MTP head | REJECTED | Q2_K n3 code decode +8 % at 4k but mean below ours, ~645 MiB more VRAM, prefill -33 %; official release has no sm_75 (issue #332) |
| [P034](P034.md) | 2026-10-07 | 8 GB launcher preset end to end | PASS | Auto modes match: drafting 50.9 / 43.2, long 43.9 / 34.2 decode; N gate failed as written (lighter desktop) |
| [P035](P035.md) | 2026-10-07 | Draft 2 / 3 below the VRAM line | FAIL | d2 +3-7 % on code, -10 % prose, -19 % at 60k; acceptance 0.80 -> 0.67; draft 1 stays |
| [P036](P036.md) | 2026-10-07 | Where decode time goes at one column (op timer, P36b) | PASS | Mat-vecs ~16.8 of 22.9 ms at 65-80 % of DRAM peak; ~6 ms small ops; 60 raw out of reach at stock memory |
| [P037](P037.md) | 2026-10-07 | Small-op class cost by skip build (P37, P37b, P37c) | PASS (P37/P37b void) | 15.8 ms mat-vec + 2.8 ms all small ops + ~3.5 ms rest per token; no class near 2 ms |
| [P038](P038.md) | 2026-10-07 | Memory overclock re-test (llama-bench) | PASS | +500 +4.2 %, +1000 +7.7 % plain decode; "memory OC does nothing" void |
| [P039](P039.md) | 2026-10-07 | +1250 / +1500 speed and soak (P39a, P39b, P39c) | FAIL / VOID | +1500 crashed the PC; +1250 GPU fault after ~10 min; +1000 10 min identical text; P39c void twice |
| [P040](P040.md) | 2026-10-07 | Deep end 4k -> 126k as shipped (P40, P40b, P40c) | PASS (P40c); P40/P40b void | P40c drafting 51.2 / 42.8 / 30.7 / 16.3 / 11.3, long 43.9 / 34.2 / 24.5 / 10.7 / 7.1; P40 ran the wrong engine |
| [P041](P041.md) | 2026-10-07 | Kernel census of the decode graph (P41b) | PASS (P41 void) | Decode graph 1,574 kernels; the 1,830-kernel table is the warm-up graph (found in P55b) |
| [P042](P042.md) | 2026-10-07 | +1000 soak 60 min, clock set before the server | PASS | 101 + 33 requests, 0 texts differ; +2.4-2.7 % drafting decode; documented opt-in, never default |
| [P043](P043.md) | 2026-10-07 | PrismML #314 prefetch on Turing | FAIL | off 41.4 / 41.2 / 41.2 vs on 40.7 / 41.3 / 41.3 at 4k; no gain; posted on #314 |
| [P044](P044.md) | 2026-10-07 | MMA route for 1-query decode on Turing (#317) | PASS | MMA route q4_0 +6 % (4k) / +18 % (16k), q8_0 +4 % / +14 %; posted on #317 |
| [P045](P045.md) | 2026-10-07 | Launcher long-mode gap, alternated | OPEN -> stopped | Never ran; moot after the wrong-engine correction |
| [P047](P047.md) | 2026-10-08 | Tail 2 / 3 / 4 past the VRAM line | FAIL | Best deep gain +9 % (tail 3 at 126k), tail 4 -41 % at 32k; tail 1 stays |
| [P048](P048.md) | 2026-10-07 | ADD + RMS_NORM + MUL fusion on Turing | SUPERSEDED | Cancelled; PrismML #209 taken as patch 0040 (PR #8) |
| [P049](P049.md) | 2026-10-08 | Lookup drafting on 8 GB (P49, P49b) | PROMOTED (PR #9) | Quote x2.17 (d0), x2.1 (64k); edit +5 % / +16 %; plain flat; 21/22 same text; min free 82 MiB |
| [P050](P050.md) | 2026-10-08 | Lookup drafting at depth 120,000 | PASS (by gate; no notebook verdict) | Quote 12.5 -> 42.5 (x3.4), edit +30 %, plain +2.8 %; csv.py 1-token in both arms; 746-866 s per request |
| [P051](P051.md) | 2026-10-08 | Best P47 tail + lookup at 96k / 126k | NOT RUN | Conditional on P47 passing; P47 failed |
| [P052](P052.md) | 2026-10-08 | Preset regression bin-lookup vs bin-rc3 | PASS | Within 0.3 % in both modes at 4k / 32k / 64k; 0 one-token |
| [P053](P053.md) | 2026-10-09 | HumanEval with lookup on | PASS | 158/164 (96.34 %) vs 157 without lookup; first run failed on a headless stdin handle |
| [P054](P054.md) | 2026-10-09 | Tail-2 one-token bug repro | PASS (not reproduced) | 0 of 81 with the pool off; P18 failures attributed to the shared-pool race |
| [P055](P055.md) | 2026-10-09 | Kernel census on the newest engine (P55b) | PASS (P55 void) | Decode 1,574 kernels, all 1-column; "2 tokens per step" lead was the warm-up graph; gate+up fused in 40/64 FFNs |
| [P056](P056.md) | 2026-10-08 | Engine 8a6d2ea12 (0040-0042) on 8 GB | PASS | Tests pass; prefill +3 % at 64k, +9 % at 96k; decode +1-2 %; free at load same |
| [P057](P057.md) | 2026-10-08 | 89-min soak with lookup at 64k | PASS | Alive, min free 119 MiB, 0/33 one-token, no decode fall |
| [P058](P058.md) | 2026-10-08 | f16 prefill vs lookup verify batches | SUPERSEDED | Replaced by P60 before it ran |
| [P059](P059.md) | 2026-10-08 | Mid-message checkpoints (--checkpoint-every-nt) | FAIL -> CORRECTED by P71 | Wall 45-58 s vs 272-294 s, but wrong text; P71: the shared pool caused it; shipped as patch 0046 (PR #11) |

Numbers with no file: P46 does not appear anywhere in the notebook (no plan, no result); the numbering skips from P45
to P47.
