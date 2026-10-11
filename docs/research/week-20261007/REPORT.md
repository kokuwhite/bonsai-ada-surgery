# Serving research: report (2026-10-07 to 2026-10-10)

Serving work on one RTX 4070 12 GB (PCIe 4.0), plus the RTX 2060 SUPER 8 GB rig runs whose receipts are in
`docs/receipts/{262k_8gb,chunked_prefill,depth_8gb,ram_8gb}/`. 48 entries in `EXPERIMENTS.md` (W01-W48), one line
each in `runs.jsonl`. Most of these receipts are first cited here. Where a doc already has the result, the entry
names that doc. No receipt in `docs/receipts/` was first added between 2026-10-04 and 2026-10-06.

## Bottom line

1. **Issue #7 (slow agent sessions) had several causes, and lookup drafting was not one of them.** Lookup on and off
   gave the same speed at 60k (W17), with 107 tools (W19), and on a real 27-tool session with identical greedy text
   (W20). A long session was not slower than a fresh server (W27: 30.4 vs 31.3 ms per draft step). Causes found: the
   grammar copy on each draft step with a long tool list (patch 0042, same tool calls: W21), and a lower VRAM line
   when other programs held VRAM at start (the launcher now shows free VRAM). MTP roughly doubles decode at 138k
   (W01: 24.7 vs 11.6; W16: 36.3 vs 20.2).
2. **Prefill past the VRAM line lost a fixed cost (patch 0041).** Line at 16k, prefill to 40k: 717.0 -> 983.4 tok/s
   (W13). Served recipe: 258k 368.7 -> 436.1, 180k 484.3 -> 546.9 (W15). The first build changed text (4/7
   identical); the fixed build gave 7/7 before release.
3. **More context fits in VRAM on 12 GB.** Shared pool: line 118,784 -> 120,064, decode at 131k 39.3 -> 41.0 (W33).
   Packed KQ mask: 240 MiB saved, line 120,064 -> 128,000, decode at 131k 40.9 -> 48.2, at 180k 21.2 -> 23.0 (W35),
   22/22 identical texts (W34).
4. **Edited long messages no longer cost a full prefill.** Checkpoints every 8192 tokens: 64.52 -> 15.52 s per
   request at 64k, 230.40 -> 49.34 s at 160k, text 11/11 identical (W28). A stop and a new message reuse the cache
   (W30).
5. **The 8 GB card got the full 262k window and faster deep prefill.** 262k decodes as fast as the 131k preset or
   faster (64k: 30.5 -> 37.8, W32). Chunked prefill: code prefill at 250k 25.4 -> 90.3 tok/s, decode the same,
   perplexity 7.2106 in place vs 7.2074 chunked (+/- 0.0712) (W36).
6. **RAM is now sized from the machine (issue #16).** 12 GB recipe, 7 thinking requests: server private peak 21724 MiB
   with defaults, 17534 MiB with the 32 GB tier (W38, W40). 8 GB rig with ~13 GB free commit: 7/7, peak 10485 MiB,
   1980 MiB commit left (W41).
7. **Rejected or kept off:**
   - int8 score step: KL 0.000314 > 0.00017 (W11).
   - Q4_0 MTP head on 12 GB (W12).
   - Tail draft 6 or 8 (W31).
   - f16 prefill for small batches (W18): a 64-query minimum instead (W23).
   - Chunked prefill on 12 GB (W44): +14.2 % code prefill at 128k, but 192k decode 23.7 -> 21.4 and 7/11 identical
     texts at 160k.
   - CPU attention for host rows on 8 GB (W43).
8. **Every release check passed.** 11 release smokes (W04, W08, W09, W10, W14, W22, W26, W29, W34, W37, W45) gave
   identical greedy text and a passing budget probe. Fresh 20k-60k prompts: 70 of 70 normal answers on the 4070
   (VOID tries not counted). HumanEval 160/164 before and after patch 0050 (W42).

## Promoted / rejected

| item | entries | status |
| --- | --- | --- |
| patch 0035, reasoning budget report | W04 | released (bundle-20261007-budget) |
| patches 0036-0038, 8 GB | W08 | released (bundle-20261007-8gb) |
| patch 0039, lookup drafting on | W09 | released (bundle-20261008-lookup) |
| patch 0040, ADD+RMS_NORM+MUL fusion (PR #8) | W10 | merged; neutral on the 4070 |
| int8 score step in prefill attention | W11 | rejected (two gates fail) |
| Q4_0 MTP head on 12 GB | W12 | rejected on 12 GB (stays the 8 GB choice) |
| patch 0041, prefill writes past the line | W13-W15 | released (bundle-20261008-tier) |
| patch 0042, grammar copy by binary search | W19-W22 | released (bundle-20261008-tools) |
| patch 0043, f16 prefill only for 64+ queries | W18, W23 | released (bundle-20261008-8gbfix) |
| patches 0044-0045, shared pool switch and stream order | W24, W26 | released (bundle-20261008-8gbfix) |
| launcher shows free VRAM at start | W27 | shipped (commit cae8298) |
| patch 0046, checkpoints inside long messages | W28, W29 | released; on for 12 GB from bundle-20261009-agent |
| tail draft 6 or 8 past the line | W31 | rejected; 4 stays |
| 262k window on 8 GB (patches 0047-0049) | W32 | released (bundle-20261009-vram) |
| shared pool on 12 GB | W33 | released (bundle-20261009-pool) |
| packed KQ mask on 12 GB | W34, W35 | released (bundle-20261009-vram) |
| chunked prefill on 8 GB (patches 0051-0052) | W36 | released (bundle-20261010) |
| chunked prefill on 12 GB | W44, W46, W47 | off by default; `GGML_CUDA_FA_CHUNK=32768` turns it on |
| RAM sizing from free commit, RAM tiers | W38-W41 | released (bundle-20261010) |
| patch 0050, concat transpose path | W42 | released (bundle-20261010) |
| tail draft 2 on 8 GB | W43 | opt-in past ~150k; tail 1 stays the default |
| CPU attention for host rows on 8 GB | W43 | rejected |
| PrismML #320 review, two slots | W25 | pass |
| PrismML #346 repro | W48 | not reproduced on Ada (root cause found later: PrismML #350) |

## Order of the work

1. 2026-10-07 afternoon: issue #7 probes at 138k (W01-W03); smoke 0035 (W04).
2. 2026-10-07 evening: agent-like decode at 45k (W05-W07); smokes 0038, 0039 (W08, W09); PR #8 A/B (W10).
3. 2026-10-08 night: int8 stopped (W11); Q4_0 head not adopted (W12); patch 0041 built, fixed, released (W13-W15).
4. 2026-10-08 morning-midday: issue #7 (W16, W17, W19, W20) -> patch 0042 (W21, W22); PrismML #330 (W18, W23).
5. 2026-10-08 afternoon-evening: PR #9 1-token repro (W24); PrismML #320 (W25); bundle-20261008-8gbfix (W26); long
   session vs fresh (W27).
6. 2026-10-09 night-morning: patch 0046 on 12 GB (W28); bundle-20261009-ckpt (W29); cache reuse (W30); tail draft (W31).
7. 2026-10-09 day: 8 GB 262k window (W32); 12 GB shared pool (W33).
8. 2026-10-09 evening: PR #13 packed mask (W34, W35); 8 GB chunked prefill starts (W36); bundle-20261009-vram (W37);
   issue #16 RAM (W38, W39).
9. 2026-10-10: RAM tiers (W40, W41); patch 0050 gate (W42); 8 GB deep sessions (W43); PR #19 on Ada (W44, W46, W47);
   bundle-20261010 checks (W45); PrismML #346 (W48).

## Open items

- Gates: only the release smokes, W11, W21, W25, W30 and W42 have a written gate. Write `<ID>-plan.json` first.
- W28: `ckpt_ab.log` counts "checkpoints created 0, restored 0" in every arm; fix the count in `bench/ckpt_ab.sh`.
- W30: cases c and d still read ~115k tokens; the run was on the 0045 engine. Run again on the current bundle.
- W44: 192k decode lower with chunking on (23.7 vs 21.4), one run per arm. Repeat before any default change.
- W47: which `shlex.py` text is the exact copy cannot be checked from the repo. Add a receipt line that shows it.
- W19: "46 vs 30 ms per draft step" is only in the commit message. Add the log lines to the receipt.
- W39: the `LLAMA_ARG_MMAP=1` arm did not start; rerun if needed.
- W31 vs `docs/Q8_FULL_CONTEXT.md`: draft 8 edit calls are -10.7 %, not -15 to -19 %. Check and correct the doc.
- `docs/8GB.md`: "~110 ms per layer" (CPU attention; the P95 receipt has 278.04 ms for the generic kernel) and
  "before: 28.2 / 28.2" have no receipt in the repo.
