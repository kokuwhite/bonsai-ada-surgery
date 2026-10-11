# Open points, inferred dates and computed numbers (W01-W48)

Written while drafting this log from the receipts (read only; nothing was rerun). Every number that was
computed for the log, every date that was inferred, and every point that is not resolved.

## A. Scope and inclusions
- No receipt in docs/receipts/ was first added 2026-10-04 to 2026-10-06. The earliest uncited ones are from
  2026-10-07, so the log covers 2026-10-07 to 2026-10-10.
- Extra uncited receipts found and added (not in the given list): he_ab_release.log (W42), pr19_ada.log/.jsonl (W44),
  release_smoke_1010.log (W45), pr19_depth0.log/.jsonl (W46), pr19_quote160k.log/.jsonl (W47), prism346.log (W48),
  and the four 8 GB rig folders 262k_8gb/, chunked_prefill/, depth_8gb/, ram_8gb/ (W32, W36, W41, W43). docs/8GB.md
  and README describe their results, but no doc names these files.
- Receipts that were already cited and appear only as companions: head_ab.log, tier_ab.log, depth_table_0041.log,
  tail_draft_ab.jsonl, issue7_fix_ab.log.
- Several receipts added 2026-10-11 (sparse_*.jsonl, gdn_prefill_ab.jsonl, vskip_ab.jsonl, code_needle_ab.jsonl,
  needle_ab.jsonl) are not cited by full name, but docs/research/depth-20261010 cites them as ".jsonl" next to the
  .log. I treated them as cited and left them out.
- agent_depth.jsonl and one_token_ab.log / one_token_repro.jsonl are shared files appended by many runs. I split them
  over W05-W07, W17, W19, W21 and W24, W26, W29, W33, W34, W37, W44, W45 by tag.

## C. Dates and times I inferred
- Receipt timestamps are HH:MM without a date. Dates come from the commit that added each receipt and the order of
  neighbouring runs.
- issue7_tools_aborted.log (W02): added on 2026-10-11 (commit 21e4c55) but shows 15:00 with the same 95,000 / 138,000
  setup as issue7_tools.log (15:18, 2026-10-07). I dated it 2026-10-07. Its end time is not logged, so wall_s is null.
- release_smoke_1010.log (W45) and pr19_depth0.log (W46): added 2026-10-11 (21e4c55). I dated them 2026-10-10 09:05
  and 09:14: they fit between pr19_ada (to 09:02) and pr19_quote160k (09:23), and on 2026-10-11 at that time the GPU
  ran vskip_ab (08:48-09:23). Not proven.
- cache_reuse_repro.jsonl (W30) has no clock times. The commit is 2026-10-09 08:23; I placed it after W29.
- 8 GB rig: P80c (06:00) and P98 (11:26) are dated 2026-10-10 from the commit (75bd71e, 12:37) and the run order;
  P95 and P89b/P89c have no times; P90b-e have only relative times. P86b (01:32) is dated 2026-10-10.
- The rig's clock may differ from the 4070 machine's clock.
- frag_ab.sh says "Issue #7 (2026-10-09)" in its header, but frag_ab.log came with commit 9bf3645 on 2026-10-08
  22:21. I used 2026-10-08.
- "Repo bin (by date: bundle-...)" in EXPERIMENTS.md is my inference from the commit history; the receipts do not
  name the product bundle.

## D. wall_s
- Total of non-null wall_s: 67,562 s (18.77 h) over 43 entries. Null: W02, W30, W32, W36, W43.
- Minute resolution: each value can be off by up to ~60 s at each end.
- The sum double-counts overlaps: W11 (00:46-00:55) and W12 (00:50-01:16) overlap; W14 (02:22-02:24) is inside W13's
  span; W26 (22:08-22:16) and W27 (22:09-22:12) overlap; W21/W22 and W22/W23 share a minute.
- Some spans include idle gaps: W13 (02:29-02:46 idle), W48 (12:53-14:16 idle; the active parts sum to ~24 min),
  W12 and W34 include their VOID first passes.
- W38 uses 22:56-23:13 (b12 arms only; the next arm in the log starts 23:13).
- W41 (8 GB) is the sum of the seven arms' last relative sample times (809.3 + 853.0 + 814.6 + 825.2 + 837.1 + 820.9
  + 922.3 = 5882.4 s), without server starts. W21's span is from issue7_fix_ab.log, because
  toolcall_identity.jsonl has no times.
- For W32, W36, W43 the rig summaries give arm start times only, with long gaps; I set wall_s to null.

## E. Numbers I am unsure of, or that I computed
- W12: in head_ab.jsonl the edit-call hashes differ between every arm, also q8 vs q8b (same model). Likely cause:
  lookup_ab.py hashed tool calls with the server-generated call id until commit 07d3949 (2026-10-08 08:47). Not
  verified. The log's identity line covers quote + plain only.
- W13: "7/7" for v2fix and v2fix2 is my count from tier_ab.jsonl hashes (the log has no identity line for them).
  The q4_0 pair ran on root-tier2 after the fix; I assume the fixed build.
- W15: the decode means are from the receipts; the prefill numbers are the code item's prefill of the new depth.
- W18: "-1.9 % faster" in the receipt means f16 is 1.9 % slower at 131072.
- W19: "46 vs 30 ms per draft step" is only in the commit message, not in the receipt.
- W24: answers had 34-52 completion tokens (my count over the 20 rows).
- W28: means after the first request are my computation from ckpt_every_nt_12gb.jsonl (they match the commit).
  "checkpoints created 0, restored 0" in ckpt_ab.log for all arms conflicts with the 4x faster requests; probably
  the log grep did not match. Not resolved.
- W31: the group means are my computation. Draft 8 vs 4: quotes -15.0 %, plain -19.3 %, edits -10.7 %. The doc
  (Q8_FULL_CONTEXT item 5) says -15 % to -19 % "in all three groups"; the edit group does not fit. Not resolved.
- W32: P75 and P77's 262k arm print "min free 4194283 MiB" / "4194267 MiB" (an unsigned wrap) and "trace min free
  -45 MiB". I read these as VRAM over-commit (the commit says "P75 over-commit"). Their speed numbers are not valid
  for the preset.
- W32: docs/8GB.md "Fresh 60k prompts ... (before: 28.2 / 28.2)": no receipt in the repo has these two numbers.
- W34: pr13_ada.log's one-token rows: the 60k answer starts "The records above are signal, harbor, violet, ..."
  (52 tokens). Not a 1-token answer, but the text looks odd. Counted as normal.
- W34: release_smoke_pr13.log has two "old" blocks (20:21, 20:22); per pr13_ada.log the first overlapped a 12 GB A/B.
  I treated the first block as VOID.
- W36: P86's summary has a Python traceback line ("t = go(...)") after the 192k step. I read it as a client error
  that stopped the 250k step; P86b reran 128k-250k. The 250k "before" numbers are from P86b.
- W36: p89c_ppl_summary.txt has three "failed to fit params to free device memory ... abort" warnings. The PPL lines
  are complete, so I took them as valid.
- W43: P95 (generic CPU kernel, 2 queries, 196,608 rows) is 278.04 ms per layer. docs/8GB.md says a dedicated AVX2
  kernel needs "~110 ms per layer for 192k rows and 2 tokens". No receipt in the repo shows the 110 ms (maybe from
  cpuattn_bench.cpp output, which is not in the repo).
- W43: p98b_realtext_kfirst.txt contains model answers saying shlex.py and fnmatch are "not included" in a 180k
  prompt of Python source. I cannot tell from the receipt whether these files were in the prompt. Not interpreted.
- W43: I did not interpret the P98 per-layer "kfirst-sum" columns beyond the 0.191-0.809 range that the doc uses.
- W44: decode at 192k 23.7 off vs 21.4 on, 250k 12.6 vs 11.8; one run each. The README's "+12-14 % prefill" matches
  the code-prefill numbers (128k +14.2 %, 192k +13.8 %, 250k +11.7 %).
- W47: the shlex.py hash with chunking off (a470f9e5143e) is the same hash as in every other receipt (tier_ab,
  head_ab, ckpt, tail_draft). The commit says the chunked answer (137637372fa4) is the exact copy. That would mean
  all the other runs have a near-tie deviation. I cannot check this from the repo (texts are local). Not resolved.
- W48: "content=''" and "AMBERFALCON=False" in every row: the answer was empty (3000 tokens of reasoning). The commit
  says the reasoning budget was not applied on b10770. So the repro did not test the needle answer, only the crash.
- W11: the base perplexity file line says "PPL = 8.3884 +/- 0.12310", the KL summary says "Mean PPL(base) :
  8.386014". Both are quoted from the receipt; I do not know why they differ.
- W20: the replay summary table rounds (104.2, 22.1); the jsonl has 104.15 and 22.11. I used the table values in the
  table and the jsonl values in runs.jsonl.

## F. Gates
- Gates are given only where a script header, docstring, doc or commit states one: release_smoke.sh output (W04 type),
  INT8_ATTENTION.md (W11), toolcall_identity.py (W21), pr320_two_slot_check.py (W25), cache_reuse_repro.py
  expectations (W30), he_ab_release.sh "release gate" without a written pass rule (W42). For the 8 GB runs,
  docs/8GB.md says the plans and gates were written on the rig; they are not in this repo.

## G. Other observations
- There is no bench/pr19_depth0.sh on origin/main; the script for W46 is unknown.
