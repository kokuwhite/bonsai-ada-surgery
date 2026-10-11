# Events, P60 to P89 range (2026-10-08 to 2026-10-09)

Non-experiment notebook entries from the P60 plan (2026-10-08) to just before "2026-10-10 P86b, P89b, P90b": PRs,
merges, releases, decisions, check-ins, fillers, incidents, tooling and coordination notes. Experiment entries in this
stretch that belong to other ranges (P53, P54, P55, P55b, P56, P57, P59 results; P90 plan) are in their own P files
and are only cross-referenced here. Times are rig local time unless marked Z (UTC) or quoted from a PR comment.

Common links: bonsai-ada-surgery = https://github.com/professorpalmer/bonsai-ada-surgery ; engine fork =
professorpalmer/llama.cpp-ada-ternary ; PrismML = https://github.com/PrismML-Eng/llama.cpp .

---

## 2026-10-08 - Incident: P53 first run failed (invalid stdin handle)

- What happened: the P53 HumanEval job failed at once. humaneval_run.py started a subprocess that got an invalid stdin
  handle under `conhost --headless` (the queue runs jobs headless).
- Fix: run the harness with `< /dev/null`. The same fix went into filler_c (scripts/filler_c_humaneval.sh). P53 was
  requeued as 30-p53.
- Changed: all later HumanEval runs (P53, P87, fillers) use `< /dev/null`.
- Links: P053; scripts/queue/30-p53-humaneval-lookup.sh, scripts/filler_c_humaneval.sh.

## 2026-10-08 - Coordination note: run part of the P57 soak with a normal desktop

- Written with the P61/P62/P63 plans: "Soak P57 note (4070 session): run part of it with a normal desktop on the card
  (Cary's browser), not only idle."
- Links: P057.

## 2026-10-08 ~16:50 - Hotfix PR #10: the 8 GB preset stops setting the shared CUDA pool

- What happened: P64 found that GGML_CUDA_SHARED_POOL (patch 0037), set by the 8 GB preset (shipped in PR #6 /
  bundle-20261007-8gb), breaks fresh long prompts with MTP drafting on the 2060 (1-token answers).
- Fix: https://github.com/professorpalmer/bonsai-ada-surgery/pull/10 (branch hotfix-8gb-no-shared-pool): the preset no
  longer sets the pool; drafting fixed cost 6469 -> 6531 MiB.
- Rig change: "maintest launcher copy (used by queued jobs and fillers) now has the hotfix too (no shared pool, fixed
  6531)". The change landed at 16:50:22 while P65 was running, which made P65 void (see P065).
- Engine bug not found at that time; suspect "pool blocks held across graphs, e.g. the FWHT/Q8 context, in a LIFO pool
  shared with the draft context". The fix came later as patch 0045 (poolsync, P68/P69).
- Status later: P66 verified it ("ready to merge from my side"); P69 result posted on PR #10 with the proposal "merge
  #10 now, pool back with 0045 later"; P72b posted on PR #10.
- Links: P064, P065, P066, P068, P069, P072.

## 2026-10-08 - Tooling: GitHub watcher and own-comment filter

- gh_watch.sh runs in the background and wakes on any new comment / PR / push not listed in gh_mine.txt.
- Own comments are posted with `gh_post.sh <pr|issue> <n> <file> [repo]`, which records them so the watcher ignores
  them.
- Links: scripts/gh_watch.sh, scripts/gh_post.sh.

## 2026-10-08 - PR #9 merged (lookup drafting on by default on 8 GB)

- "PR #9 merged (9343db61a) by me on Cary's go-ahead (12 GB session agreed); main = lookup on 8 GB, no shared pool."
- Basis: P49b (lookup A/B), P57 soak PASS ("PR #9 ready to merge"), P60/P61/P62/P63/P70 data posted on #9.
- Links: https://github.com/professorpalmer/bonsai-ada-surgery/pull/9.

## 2026-10-09 - PR #11: patch 0046 --checkpoint-every-nt (8 GB preset sets 8192)

- Opened: https://github.com/professorpalmer/bonsai-ada-surgery/pull/11 ; fork branch patch-0046-ckpt-every-nt
  (5251968b0 on 142d5105d). Receipt P71. "Needs a bundle with 0046; the 12 GB session decides for its preset."
- Follow-up test: P73 (end to end, PASS).
- Links: P071, P073; scripts/tools/0046-server-checkpoint-every-nt-N-also-checkpoints-inside.patch.

## 2026-10-09 - Rig baseline: default sweeps use the released engine

- Written with the P73 plan: "Default sweeps now use the released engine (receipts/newest_bin = bin-8gbfix)."
  (bundle-20261008-8gbfix, engine 142d5105d, checked by P72b.)

## 2026-10-09 - Incident: P55 census failed (backslash escaping in the model path)

- "P55 (census) failed: model path lost its file name (backslash escaping); requeued as 35-p55b with forward slashes."
- Links: P055; scripts/queue/20-p55-census.sh, scripts/queue/35-p55b-census.sh.

## 2026-10-09 - PR #11 merged

- "PR #11 merged (patch 0046; 12 GB confirmed: 64k 64.5 -> 15.5 s, 160k 230 -> 49 s, 11/11 same text). Engine commit
  5251968b0 must go to bonsai-q8-product for the next bundle (4070 session builds bundles)."
- Result: release bundle-20261009-ckpt (checked by P79).

## 2026-10-09 - PR #12 merged (docs)

- "PR #12 merged (docs/8GB.md: 8gbfix, deep-end table, memory clock optional, pool/tail-2 notes corrected)."
- The pool / tail-2 note correction follows P54 (tail-2 1-token reports were the pool race) and P64-P69.

## 2026-10-09 - Decision (Cary agreed): stop micro-fusions; megakernel only as a last resort

- Data (notebook): "Measured ceilings (P37 skip tests): removing a whole small-kernel class gains 0.5-1.7 %; all small
  kernels together +14 %, spread over ~1,200 kernels of ~2.3 us. P76 gate+up fusion (64/64 FFNs, identical text):
  +0.2 %. The norm->FWHT fusion target shrank after patch 0040 (48 of 129 norms are already ADD+RMS_NORM+MUL); the 81
  plain ones are worth ~0.5 %."
- Decision: "Neither ships (engine complexity, held pool blocks, for < 1 %). Gate+up fix kept on fork branch
  fuse-gateup (c87233fc1) for a future megakernel effort. Effort moves to the 262k default (P75) and the deep end."
- Links: P076, P037, P055b.

## 2026-10-09 03:54-09:01 - Fillers (result): stable, no regression

- Fillers keep the GPU busy between queued jobs (deep sweep, lookup A/B, HumanEval), on bin-8gbfix with the 131k
  presets.
- lookup (04:32, 07:28): 0 one-token in 88 items. d0 quote mean 126.1 / 124.4 (lookup) vs 58.1 / 58.4 (no lookup);
  64k quote 68.2 / 68.2 vs 28.0 / 26.6; plain same.
- HumanEval (06:05): 158/164 (96.34 %), 2717.9 s, same as P53 (same 6 failed tasks).
- deep (03:54, 06:50): notebook "64k 21.7/24.4, 96k 10.2/10.7, 126k 6.8/7.1 decode (run-to-run spread up to 12 % at
  64k; desktop load not recorded)".
- Receipt detail and a correction: those deep numbers are the long-mode arm (long.txt: 43.9 / 34.3 / 21.7 / 10.2 / 6.8
  and 44.0 / 34.3 / 24.4 / 10.7 / 7.1 at 4k / 32k / 64k / 96k / 126k; min free at end 134 / 97 MiB). The drafting arm
  of the same fillers was stable: 51.8 / 46.6 / 30.5 / 17.8 / 14.2 and 51.7 / 46.7 / 30.7 / 17.8 / 14.2 (acceptance
  0.788; min free at end 108 / 131 MiB). The 12 % spread is in long mode only.
- Receipts: results-raw.zip: receipts/filler/deep_1009_0354/, deep_1009_0650/, lookup_1009_0432/, lookup_1009_0728/,
  humaneval_1009_0605/.

## 2026-10-09 - Upstream: patch 0046 to PrismML (PR #338)

- https://github.com/PrismML-Eng/llama.cpp/pull/338 (branch checkpoint-every-nt = 5251968b0 cherry-picked on prism
  8b0c19c8c, clean, not rebuilt on that base).
- Duplicate check: no --checkpoint-every-nt or equivalent in PrismML prism or ggml-org master; PrismML #312 (checkpoint
  buffer reuse) is different.
- Receipts: P71, P73, the 12 GB PR #11 comment. Body: upstream/pr-prism-ckpt-every-nt.md (copy in
  drafts/pr-prism-ckpt-every-nt.md).
- Status at the next check-ins: open, no comments (10:45 second run, 20:05, 22:10, 22:57).

## Check-in 2026-10-09 10:45

1. Queue: BonsaiQueue running; P75 (262k) runs since 09:10; pending P78, P77, P79 (new: release check of
   bundle-20261009-ckpt).
2. Results: P70 to P76 were already logged; fillers 03:54-09:01 logged.
3. Upstream: patch 0046 sent to PrismML as PR #338.
4. Activity: PRs #11 and #12 merged; issue #7 handled by the 4070 session; PrismML #317 merged by bri-prism; no open
   questions to this rig.
5. Note: "this check-in started 22:48 and continued at 10:16; P72 failure and P72b pass were logged by an earlier run."

## 2026-10-09 - Queue order: P79 before P77 and P80

- "P79 (release check, written by the 10:16 check-in) moved to 43, before P77 (45) and P80 (46)."

## 2026-10-09 ~09:57-10:52 - Incidents and tooling from the P75 result

- lookup_ab.py client timeout 1800 s is too short for a cold 250k prefill on PCIe 3.0: use 5400 s for deep runs
  (lookup_ab.py now uses 5400).
- Build fault: "tune build at 09:57 crashed in cicc (ACCESS_VIOLATION, fattn instance, during P75 RAM load) but
  build.bat returned 0; P78 ran on a bin with no exe and failed in 1 min. Rebuild with -j 4 and a real success check
  (build_ahead6.sh: exe files present, no "build stopped"). P78 requeued as 44 (after P79)."
- Plan amendments in the same entry: P77 got a 10 s VRAM trace per arm (wrap corrected) and arm A got the same check;
  P80 moved to staging off (tail1 N 54,784, tail2 N 46,080) with the trace.
- Links: P075, P077, P078, P080; scripts/build_ahead6.sh.

## Check-in 2026-10-09 10:45 (second run)

1. Queue: P79 (release check) runs since 10:34 (fresh 60k loaded, free 341 MiB); pending P78 (44), P77 (45), P80 (46).
2. Build: tune2 rebuild (-j 4) runs since 10:34; P78 waits for "tune2 exit 0" and stops on a failed build.
3. Results: no new finished receipt since the last check-in; P75 and the P78 build failure logged.
4. Upstream: no new confirmed win; PrismML #338 open, no comments yet.
5. Activity: no new PRs; main has 4 new commits from the 12 GB session (PCIe check, 160k draft size, issue #7 repro,
   release); PrismML #325/#330/#314/#209/#332 have no new replies to professorpalmer.
- Queue order (Cary question, "8 GB cards are mostly not Turing"): universal 262k work first. P78 moved to 47, after
  P77 (45) and P80 (46).
- "Build tune2 (-j 4) at 10:52: pass, llama-server.exe and test-backend-ops.exe present. P78 (queue 47) is ready."

## 2026-10-09 12:59 - Incident: second cicc crash (pstage build)

- "Build pstage at 12:59: cicc crashed (0xC0000374, mmq-instance-pq2_0.cu, unrelated file) - second cicc crash today.
  P81 failed at its build gate; rebuild with up to 3 retries, P81 re-queued when it passes; fillers keep the GPU busy
  meanwhile."
- Links: P081; scripts/build_ahead*.sh.

## 2026-10-09 - Release bundle-20261009-pool (4070 session): 12 GB shared pool on; 8 GB path unchanged

- Code read: "The launcher pool block runs only when -not $Small; the 8 GB branch sets its own FixedMiB. No 8 GB run
  needed."

## 2026-10-09 - Release bundle-20261009-agent (4070 session)

- "checkpoints inside messages now on for 12 GB too; 8 GB had them since #11. Same engine, launcher only; nothing to
  check on 8 GB."

## 2026-10-09 - PR #13 opened: 262k 8 GB default

- "PR #13 (bonsai-ada-surgery, branch 8gb-262k, aa557fb): 262k 8 GB default + patches 0047-0049 +
  receipts/262k_8gb. Engine branch packed-mask-pstage pushed to llama.cpp-ada-ternary. P85 result goes on #13 as a
  comment."
- Basis: P84 (PASS). Launcher details in P085.
- Links: https://github.com/professorpalmer/bonsai-ada-surgery/pull/13.

## 2026-10-09 ~20:01 - Rig change: fillers yield to queued jobs

- "Fillers now yield: they stop at the next safe point when queue/pending has a job (lookup filler held P85 for 94 min,
  18:27-20:01). HumanEval filler runs in the background and is stopped when a job arrives."
- Links: scripts/fillers/, scripts/filler_*.sh.

## 2026-10-09 13:00-20:01 - Fillers (result): stable, no regression

- HumanEval (13:00, bin newest): 158/164 (96.34 %), 2808.8 s, same as P53 and the 06:05 filler (same 6 failed tasks).
- deep (16:34, bin-8gbfix, 131k presets): drafting 51.8 / 46.5 / 30.6 / 17.8 / 14.2 at 4k/32k/64k/96k/126k, acceptance
  0.788, min free 119 MiB; long 43.8 / 34.1 / 21.7 / 10.1 / 6.8, min free 157 MiB. "Same as the 03:54/06:50 fillers and
  P84 arm A."
- lookup (18:27-20:01): 0 one-token in 44 items. Notebook: "d0 quote 123.2/122.2/135.2/121.0 (lookup) vs
  58.2/58.4/58.0/57.5; 64k quote 66.8/69.6/69.5/64.6 vs 27.8/28.3/27.9/27.7; plain same." Receipt note: these four
  values are the four quote items of one run (means 125.4 vs 58.0 at d0, 67.6 vs 27.9 at 64k), not four runs as in
  the 03:54-09:01 entry.
- Text lookup vs no lookup: d0 11/11 same; 64k 10/11 (quote shlex.py 137637.. vs a470f9..; "137637 is a known 64k
  variant, P49b/P79").
- Receipts: results-raw.zip: receipts/filler/humaneval_1009_1300/, deep_1009_1634/, lookup_1009_1827/.

## Check-in 2026-10-09 20:05

1. Queue: P85 (262k launcher as shipped) runs since 20:01; pending P86 (53) and P80b (54). No PAUSE file.
2. Results: P81 to P84 already logged; fillers 13:00-20:01 logged (stable, 0 one-token, HumanEval 158/164).
3. Upstream: P84 win is in PR #13 (open, mergeable); P85 result will go on #13 as a comment.
4. Activity: on #13 the 4070 session runs the 12 GB packed-mask check (review point 1); main has 2 new 12 GB launcher
   commits (checkpoints on, bundle-20261009-agent).
5. PrismML: #330, #314, #317 last reply is professorpalmer; #209 last reply bri-prism (10-05, already handled); #325,
   #332, #338 have no comments.

## 2026-10-09 - PR #13 review (4070, Ada)

- "packed vs f16 with drafting + lookup 11/11 at 32k and 11/11 at 64k; 240 MiB saved at 12 GB; fresh 20k-60k 5/5; new
  engine with switches off = product engine (greedy identical). 12 GB launcher change (line 120,064 -> 128,000) follows
  after #13 merges."

## 2026-10-09 - PR #13 merged; fillers move to the 262k default

- "PR #13 merged (2043e76, noreply identity) after P85 + the Ada review." P87 planned (HumanEval on the 262k launcher).
- "Fillers now run the 262k test launcher on bin-pmask, so filler time is soak time for the new default (deep sweep,
  lookup repeat, HumanEval)."

## 2026-10-09 - main 05e349b (4070): packed mask on for 12 GB

- "line 120,064 -> 128,000, decode 40.9 -> 48.2 at 131k (+18 %), 21.2 -> 23.0 at 180k. Code read: the 8 GB path is
  unchanged ($MaskSavedMiB only when -not $Small)."

## 2026-10-09 - Issue #14 and PR #15: layer probe stops the launcher on PowerShell 5.1 without wasmtime

- Issue #14 (picmax): the layer probe stops the launcher on PS 5.1 when wasmtime is missing. Reproduced here.
- Fix PR #15: probe only with the runtime present, inside try/catch; both cases tested. Answered on #14.
- "PR #15 reviewed by the 4070 session (same fix in the Mirai S launcher), merged with the noreply identity; issue #14
  closed. Needs a bundle (users get the launcher from the zip)." Main 109c3a0: README bundle-20261009-probe, fix for
  #14 (22:10 check-in).
- Links: https://github.com/professorpalmer/bonsai-ada-surgery/issues/14 , /pull/15.

## Check-in 2026-10-09 22:10

1. Queue: P88 (release bundle-20261009-vram) runs since 21:55; pending 53zz P86b, 54 P80b, 55 P87. No PAUSE file.
2. Results: P88 partial, not logged: sha256 match, ADD 99/99, RMS_NORM 51/51, FLASH_ATTN_EXT 2994/2994; decode 51.1 /
   46.2 / 37.5 at 4k/32k/64k (P85: 50.8 / 45.8 / 37.5). No filler ran since 20:01.
3. Upstream: no new confirmed win. P88 pass goes on the release thread / PR #13 when the job ends.
4. Activity: main has 109c3a0 (README bundle-20261009-probe, fix for #14). #7 last reply is professorpalmer. "P89
   worktree vendor/prism-chunk has edits at 22:10 (other session works on it; not touched)."
5. PrismML: #330, #314, #317 last reply professorpalmer; #209 last reply bri-prism (10-05, handled); #325, #332, #338
   no new comments.
- README card: "Card docs/img/card8gb.html/.png (262k on 8 GB, decode by depth, honest deep end): Cary approved; add to
  the README after P86b gives the 250k number (replace "250k: measuring" with the value, re-render)."

## 2026-10-09 - Issue #16 (howdya): RTX 3060 Ti 8 GB, 16 GB RAM: bad_alloc and server death in long thinking runs

- Report: 131k tiered (N 42,496), thinking on, 7 sequential requests: 3 HTTP 500 (bad allocation), then the process
  died. Server log: prompt cache limit reduced to 757 MiB, entries 459-728 MiB evicted each request.
- Analysis (notebook): "Our side of the RAM bill at 131k on 16 GB: pinned KV tail ~1.5 GB; context checkpoints up to
  32 per slot x ~170 MiB (~5.4 GB; the 8 GB preset adds them every 8,192 tokens inside messages); prompt cache (default
  8192 MiB limit). bad_alloc = commit limit."
- Plan: P90 (queue 53yz, after P89; see P090) measures the commit budget per component -> RAM-aware launcher defaults
  (< 24 GB: fewer checkpoints, smaller prompt cache), then a fix PR and an answer on #16.
- Split (4070 comment): "the 2060 rig owns the launcher RAM-budget PR (one block for all presets); 4070 measures the
  12 GB recipe (262k q8_0 tail ~4.6 GB pinned) and adds its numbers to that PR. Server facts: "cache size limit
  reduced" is written after a bad_alloc (limit -> 40 %); a prompt-cache entry holds a copy of the slot checkpoints
  (459-728 MiB = 3-4 checkpoints), so checkpoints sit in RAM twice."
- Outcome (later, outside this range): PR #18 (ram-budget) merged by the 4070 session, issue #16 closed (2026-10-10).
- Links: https://github.com/professorpalmer/bonsai-ada-surgery/issues/16 ; P071/P073 (the checkpoint feature whose
  RAM cost is part of the bill); P090.

## Check-in 2026-10-09 22:57

1. Queue: P89 (chunked prefill) runs since 22:45; pending 53yz P90, 53zz P86b, 54 P80b, 55 P87. No PAUSE file.
2. Results: P89 partial, not logged as a result: FLASH_ATTN_EXT base 3005/3005, C=256 3005/3005, C=768 3005/3005,
   C=256 MIN_Q=1 hs256 44/44 (test gate pass). Texts and speed arms still run.
3. Upstream: no new confirmed win. PR #13 and #15 are merged. P89 goes to an engine PR only after the text and speed
   gates pass.
4. Activity: issue #16 has two professorpalmer comments (workaround + split with the 4070 session); no reply from
   howdya yet. P90 answers it. #7 last reply professorpalmer. Main head 109c3a0 (no change).
5. PrismML: #330, #314, #317 last reply professorpalmer; #209 last reply bri-prism (10-05, handled); #325, #332, #338
   no comments.

## 2026-10-09 - Lesson: inline bash through the tool loses one level of backslashes

- Logged with the P89 partial result: "inline bash commands through the tool lose one level of backslashes
  ('s#\#/#g' -> 's#\#/#g'); the P79/P82/P88 log-path greps were broken by this. Write scripts with the Write tool when
  they hold backslashes."
- Effects found in this range: P79 ckpt_flag.txt empty, P82 mask-line counts missing, P88 launcher_lines.txt mixed
  with an older log, P87 launcher_lines.txt empty ("sed: -e expression #1, char 12: unknown option to `s'"). P55
  failed earlier the same day from backslash escaping in a model path.
- Links: P055, P079, P082, P087, P088.

## 2026-10-09 - PR #17 merged: README 8 GB card

- "PR #17 merged (b056c0b): README 8 GB card (docs/img/card8gb.png) + 8 GB recipe row updated (262k, ~59k in VRAM,
  5.7 tok/s at 250k); receipts p85/p86/p89 summaries added."
- Note: the 250k value 5.7 came from P89's deep arm (chunked engine) before the P86b result was logged; P86b then
  measured the same 5.7 on the non-chunked engine ("the card is right").
- Links: P085, P086, P089.
