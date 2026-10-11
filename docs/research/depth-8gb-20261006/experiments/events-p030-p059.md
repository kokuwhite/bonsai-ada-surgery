# Events, P30 to P59 range (2026-10-07 to 2026-10-08)

Non-experiment notebook entries between the P30 plan and the P60 plan: releases, PRs, issues, coordination with the
12 GB (RTX 4070) session, incidents, process changes, decisions and plans for the queue. Times are local rig time.
Source: the notebook (NOTEBOOK.md = C:\bonsai\8gb\DECISIONS.md) and the receipts named per section.

---

## 2026-10-07 - PR: PrismML-Eng/llama.cpp#330 opened (f16 prefill from pool memory)

- What: https://github.com/PrismML-Eng/llama.cpp/pull/330, head
  professorpalmer/llama.cpp-ada-ternary:claude/fa-prefill-f16-pool (066e3e36a on prism 6bfcd79).
- Body: drafts/pr-fa-prefill-f16.md (P25 receipts; opt-in, off by default; "not measured on Ampere/Ada").
- Duplicate check: "#317 converts to f16 only when a vector-kernel instance is missing; #307/#308 tune decode. No
  overlap."
- What changed: the f16 prefill switch (`GGML_CUDA_FA_PREFILL_F16=N`, our c9a2a7dd0) offered upstream.
- Later: P58 / P60 / P61 / P70 measured a min-Q variant (patch 0043) for #330 (other range).

## 2026-10-07 - Issue: PrismML-Eng/llama.cpp#332 (official Windows CUDA 13.3 release has no sm_75 code)

- What happened: during P33, `prism-b10754-2459f68 win-cuda-13.3-x64` crashed on the 2060 SUPER right after buffer
  reservation with a bare `ggml-cuda.cu:107: CUDA error` (plain arm, no drafter). Receipt:
  receipts/p33/FAILED-release-cu133-plain.txt; rig log logs/prism-b10754-debug.err.log.
- Cause (notebook): ggml-cuda.dll contains sm_86 / sm_89 / sm_120 code and no sm_75. release-prism.yml sets no
  CMAKE_CUDA_ARCHITECTURES, so Turing gets only 75-virtual PTX; the 13.3 zip's PTX cannot JIT on driver 591.86
  (CUDA 13.1). The 12.4 zip loads (~2 min first-start JIT) and answers 17*23 = 391. "Every RTX 20 card fails with that
  release."
- Fix / action: duplicate check, then issue https://github.com/PrismML-Eng/llama.cpp/issues/332 (body:
  drafts/issue-sm75-release.md). P33 rerouted to our own sm_75 build of prism 6bfcd79 + Turing fix (bin-prism).
- Status in the notebook (2026-10-09 20:05 check-in): "#325, #332, #338 have no comments."

## 2026-10-07 - Release: bundle-20261007 published as a pre-release

- What: https://github.com/professorpalmer/bonsai-ada-surgery/releases/tag/bundle-20261007, target 8gb-rig (da99a3a),
  paired with PR #6.
- Engine: bonsai-q8-product c8b8993a6 + bc3e5aa02 (Turing one-column) + b7c11567a (shared pool) + c9a2a7dd0 (f16
  prefill).
- Checks: "Clean-extract smoke test: device listed, flags present, test-backend-ops FLASH_ATTN_EXT 2994/2994 on sm_75.
  Downloaded asset sha256 ec546085...1ccc = local zip. Repo "latest" stays bundle-20261004."
- Numbers in the notes: the P34 preset table (drafting 50.9 / 43.2 decode, 408 / 330 prefill; long 43.9 / 34.2,
  432 / 353), HumanEval q4_0 157 / q8_0 159 (P31 / P32). Release notes: releases/release-notes.md; PR body:
  drafts/pr-bonsai-8gb.md.
- Later: re-tagged twice (next two sections).

## 2026-10-07 - Coordination 1 (12 GB agent's note on PR #6): RC3 = RC2 + patch 0034; main merged

- What happened: the 12 GB session asked for patch 0034 (empty JSON-schema unions, #3) and a merge of main.
- Done: engine fork branch bonsai-8gb = 3f808b80b (2cb7a4ed6 cherry-picked onto c9a2a7dd0). 8gb-rig merged main
  (702d018; README conflict resolved keeping main's Hugging Face download + our non-lossless wording). bin-rc3 =
  release3/bin.
- Checks: ggml-cuda.dll byte-identical to RC2; an empty `anyOf` schema returns valid JSON; decode 43.6 at 8k plain.
- Release: pre-release bundle-20261007 re-tagged at 702d018, asset replaced (sha256 cd8a91cc...bf2, verified on
  download). Reply on PR #6 (drafts/pr6-coord.md).
- What changed: "Use bin-rc3 from here."

## 2026-10-07 12:31 - Incident: memory +1500 MHz crashed the PC

- What happened: during P39a, slot 5 stock gave 46.26 tok/s; +1250 gave 50.39 (+8.9 %, clean); "+1500 applied ->
  system bugcheck and reboot before the run produced a number (System log: WER 1001 bugcheck 0x00020001, Kernel-Power
  41)". Receipts: receipts/p39a/table.txt (two rows), receipts/p39a/clk_16790.txt (empty, 12:31:16).
- After the reboot: Afterburner came up unapplied (fan 41 %).
- Fix: slots rewritten (1 = mem +1000, 2 = mem +1250; nothing above +1250 staged); slot 5 stock + fan 100 applied.
- Rule: "memory steps above +1250 are not tried again on this card; +1250 itself needs the soak before any use."
- Later: +1250 faulted under sustained load in P39b (13:23, nvlddmkm 14 + 153); slots then 1 = +500, 2 = +1000; cap
  +1000; never switch clocks while a server runs (P39c, P42).

## 2026-10-07 - Coordination 2: main (1553bc4 layer gate, 5790ed2 vision projector launcher) merged into 8gb-rig

- Merge 7882d0f, pushed. One conflict ($FixedMiB block, start-server.ps1): kept the `if ($Small)` preset; added
  `+ $MmprojMiB` on the base line and on each of the three measured values (6469 / 6218 / 5955). Parses; CRLF kept.
- Verified on the card (temporary copy as the P39b launcher): preset on, drafting, 54,272 positions in VRAM, margin
  225, healthy.
- Release: pre-release bundle-20261007 re-tagged at 7882d0f ("the zip is binaries only - launcher and layer come from
  the tag, as in bundle-20261007-fixes"); the engine did not change, so the asset stays cd8a91cc...bf2. Notes updated
  (releases/release-notes.md).

## 2026-10-07 13:38 - Process: an app restart killed the jobs; long GPU jobs move to the BonsaiJob scheduled task

- What happened: P39c attempt 1 died at 13:37:48 (server and soak script together; no CUDA error, no driver event).
- Cause found: "the Claude app restarted this session's process at 13:38 (claude.exe --resume, new process tree), and
  every job started from the tool shells died with it." (Later the notebook adds that a live memory-clock switch was
  also seconds before both P39c deaths: "the app restart cause above is at best part of it".)
- Fix: "Long GPU jobs now run from the BonsaiJob scheduled task (jobrun.sh), outside the app's process tree." P39c and
  chain40 started that way at 14:20. receipts/detach-test.txt ("ok-14:19:10") is the detach test.
- Note: a Start-Process relaunch at 14:08 was not recorded as stopped; the P39c receipts suggest two soak processes ran
  against one server after 14:20 (see P039).

## 2026-10-07 14:40 - Process: BonsaiJob ended with 0xC000013A; tasks run under conhost --headless

- What happened: "P40 attempt 1 stopped at 14:40 in the 96k step: BonsaiJob ended with 0xC000013A (console close /
  Ctrl+C)." Partial receipts: receipts/p40_partial (4k 51.6, 32k 43.2, 64k 28.4 decode).
- Fix: "Tasks now run under conhost --headless (no window)." P40 rerun from the start, chained to jobrun2.
- Side effect found on 2026-10-08: under the headless console a Python subprocess gets an invalid stdin handle (P53;
  fixed with `< /dev/null`).

## 2026-10-07 18:55-19:08 - Process: two copies of jobrun2 ran at once; jobs take a lock directory

- What happened: "two copies of jobrun2 ran at once from 18:55 (the old task copy survived taskkill /T): P43 builds
  failed, arms overlapped. All stopped 19:08." receipts/jobrun2.log shows every step twice (p40 done 18:55:40 and
  18:55:56; census done 18:55:59 and 18:56:15); receipts/jobrun2-run.out shows the failed copies and "did not start".
- Fix: "Jobs now take a lock directory" (`mkdir receipts/jobrunN.lock` or exit; removed on exit). Later the queue
  runner treats a lock whose script is not running as stale.

## 2026-10-07 ~20:00 - Ollama found running on the desktop

- What happened: during the P40b bisect, Cary found Ollama running on the desktop and closed it.
- Effect: "one rerun after that was still slow, so Ollama is not this cause" (receipts/p40b/long_noollama.txt: 37.6).
- The real cause of the slow long mode was the wrong engine (next section).

## 2026-10-07 ~21:2x - Correction: the long-mode "regression" and P40 used the wrong engine (my error)

- What happened: P40 and the P40b bisect showed long mode through the launcher at ~38 tok/s at 4k vs ~43.8 from a
  minimal script; a 14-run bisect did not localize it (drafts/pr6-longmode.md was posted on PR #6).
- Cause: "The branch launchers (3e89c15, 7882d0f, 36d6e12) do not read BONSAI_BIN; they always run <repo>\bin, which on
  this rig is bundle-20260927 (no #325 Turing one-column path). Every launcher run since the 12:50 test copy used that
  engine: P39b, P39c (soaks), P40 (deep end), P40b launcher arms, P45 design. P34 is not affected (its copy was edited
  to rc2). 43.8 / 38.2 = 1.147 = the #325 gain."
- Fix: "the test copies (start-server-8gbtest/8gbnew.ps1) now honor BONSAI_BIN. P40c (deep end, both modes, bin-rc3)
  inserted before the P42 soak. P45 stopped (moot)." "P40 tables and the PR #6 comment are void; correction posted on
  PR #6" (drafts/pr6-correction.md).
- What did not change: the shipped launcher is correct for users (it runs its own bin folder).
- The same entry logs the P43 result (#314: no gain; posted on #314).

## 2026-10-07 - To upstream (running list; Cary: every passing fix goes to PrismML or the bonsai patch stack)

- Done: PrismML #325 (Turing one-column), #330 (f16 prefill), issue #332 (sm_75 release), data on #314 and #317;
  bonsai-ada-surgery PR #6 + pre-release bundle-20261007 (8 GB preset, Q4 head tooling, display detection, patch 0034).
- Open at that time:
  - Shared CUDA pool + LLAMA_MTP_DRAFT_UBATCH (b7c11567a, from the Mirai engine): in the 8 GB engine only. Offer to the
    bonsai patch stack for 12 GB too (measure first) and check PrismML for an equivalent before a PR.
  - P48 ADD+RMS_NORM+MUL fusion on all GPUs (if it passes): find the gate's origin and send the un-gate there.
  - Turing MMA decode route (#317 follow-up): sb32445 extends the #307 guard; our numbers are posted. Watch.
  - Tail-2 one-token bug: rs_valid detector (P18 / agent read); needs a repro first.
  - docs/8GB.md: memory clock (+1000 opt-in) after P42 passes; the deep-end table from P40c.
- What happened next: P48 became patch 0040 (PR #8); the shared pool turned out to cause 1-token answers (P64, hotfix
  PR #10, patch 0045 poolsync); the tail-2 item closed (P54); the docs items went into PR #12 (2026-10-09).

## 2026-10-07 - Decision: P48 cancelled; patch 0040 = PrismML #209 (cklxx), PR #8 on bonsai-ada-surgery

- Cary: "#209 already exists upstream; take it into the bonsai patch stack by PR and let the 12 GB session test it, no
  GPU time here."
- Done: fork branch patch-0040-add-rms-fusion (3ecf00b11, author cklxx) on bonsai-q8-product 008ac1112; patches/0040 +
  README row. https://github.com/professorpalmer/bonsai-ada-surgery/pull/8
- jobrun5.sh (the P48 job, started 23:28:19 and waiting) produced no receipts.
- Later: the 12 GB bundle with 0040-0042 was measured on 8 GB in P56 (decode +1-2 %).

## 2026-10-08 - Overnight backlog (take the top item that is not done; pre-register each before it runs)

1. P49 lookup A/B (queued, BonsaiJob6). If it passes: PR to main - the 8 GB preset turns lookup on.
2. P50: lookup at the deep end - lookup on/off at depth 120000 (quote + edit + plain), drafting preset, bin-lookup.
3. P51: best tail from P47 combined with lookup at 96k / 126k (if a tail > 1 passed P47).
4. P52: 8 GB preset regression on bin-lookup (the new fork head 008ac1112) vs bin-rc3: quick_tps 4k/32k/64k both
   modes, greedy text hashes - confirms patches 0035/0039 cost nothing on 8 GB.
5. P53: HumanEval medium on the drafting preset with lookup on (quality gate for turning it on).
6. P54: tail-2 one-token bug repro (P18 sequence) on bin-lookup with tail 2, LLAMA_ARG_CACHE_RAM on vs 0.
7. P55: kernel census on bin-lookup (dev stats build: prism-p37 rebased on 008ac1112) - next fusion targets.

Rule: "Never idle: if all are done, rerun P40c on the newest engine at stock and +1000 (clock set before the server)."
Outcome: P49 PASS (PR #9), P50 PASS by its gate, P51 not run (P47 failed), P52 PASS, P53 PASS (158), P54 not
reproduced, P55 done as P55b.

## 2026-10-08 01:44-07:20 - Failure: the session cron did not fire; the GPU was idle overnight

- What happened: "the session-only cron checks did not fire overnight (no record); the GPU was idle 01:44 -> 07:20."
  receipts/jobrun7.log: P52 done 01:43:15, P50 failed at once 01:44:11 (lookup_ab.py import bug), end 01:44:11.
  receipts/jobrun8.log: start 07:19:17.
- Cause: "The session-only cron (CronCreate) cannot fire while the desktop session has no live process: it never ran
  overnight."
- Fix: next section.

## 2026-10-08 - Fix for idle nights: BonsaiQueue runner + app-level check-in

- (1) Windows task BonsaiQueue (every 10 min, one instance, headless) runs queue_runner.sh: waits for live jobrun*.lock
  jobs (stale locks removed), runs queue/pending/*.sh in name order (moved to running/, then done/ or failed/), else
  rotates filler_a_deep / filler_b_lookup / filler_c_humaneval on receipts/newest_bin. "The GPU has work with no Claude
  session at all." receipts/queue.log: first "runner start" 10-08 07:21:06.
- (2) App scheduled task bonsai-8gb-checkin (a Claude run every 2 h at :23): processes results, refills the queue,
  answers PRs, upstreams wins.
- Scripts: scripts/queue_runner.sh, scripts/filler_a_deep.sh, scripts/filler_b_lookup.sh, scripts/filler_c_humaneval.sh
  (the copies in scripts/ are later versions: they use the 262k test launcher and yield to queued jobs, changes made
  on 2026-10-09).
- What changed: from here, experiments are queue files (scripts/queue/NN-pNN-*.sh) with receipts/queue-<name>.out.

## 2026-10-08 - PR #9: lookup drafting on by default on 8 GB (Cary: known win, ship it)

- https://github.com/professorpalmer/bonsai-ada-surgery/pull/9 (branch lookup-8gb 07d3949): launcher gate removed,
  docs/8GB.md lookup section, receipts/lookup_ab_8gb.jsonl (P49b), lookup_ab.py hash fix (tool-call id).
- Numbers in the PR: P49b d0 quote 58.2 -> 125.9, edit 56.9 -> 60.5, plain 52.5 -> 52.8, 11/11 same text; 64k quote
  32.5 -> 69.3, plain 31.4 -> 31.3, 1/11 text differs (rounding); min free 90 MiB. Then: "P49b 64k edit: 32.5 -> 37.7
  (+16 %), look_d64k min free 82 MiB; 21/22 texts same. PR #9 updated."
- Follow-ups planned on the PR: 64k edit row, P50 120k, P53 HumanEval. "maintest launcher copy now = this branch
  (lookup on)."
- 12 GB review on PR #9 then asked for P56 (tier engine on 8 GB) and P57 (soak); later P60 (min-Q).
- Merged 2026-10-08 (9343db61a) "by me on Cary's go-ahead (12 GB session agreed); main = lookup on 8 GB, no shared pool"
  (entry after the P60 plan).

## 2026-10-08 09:31 - Serving switch: pause.ps1 and resume.ps1

- What: pause.ps1 creates queue\PAUSE, stops the BonsaiJob tasks, the job scripts (jobrun*, queue/running, fillers,
  run_arm, lookup_ab, quick_tps, humaneval_run, p9_soak) and the servers, moves the interrupted job back to pending,
  removes job locks, applies stock clocks (slot 3 then 5), and logs "PAUSED for serving". resume.ps1 removes PAUSE,
  starts BonsaiQueue if needed and logs "RESUMED".
- "Runner obeys PAUSE (restarted 09:31 with it). Cary decides when to pause; testing continues until then."
  receipts/queue.log: "10-08 09:31:49 runner start".
- Scripts: scripts/pause.ps1, scripts/resume.ps1, scripts/queue_runner.sh.
- Same entry: "P56 updated before it ran: prism-tier now at fork head 8a6d2ea12 (adds 0042 grammar clone fix)."

## 2026-10-08 - Bench fixes in lookup_ab.py (found in P49)

- Bug 1: "lookup_ab.py hashes the tool_calls with the server-generated call id" - edit hashes differed in every arm,
  even between two identical lookup runs. Fix: hash name + arguments only. Sent upstream in PR #9.
- Bug 2: "lookup_ab.py imports quick_tps from its own folder" - every run with depth > 0 failed (P49 64k arms, first
  P50). Fix: add the bench path.
- Script: scripts/lookup_ab.py (fixed version).
