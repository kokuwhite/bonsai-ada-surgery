# Experiments W01-W48 (2026-10-07 to 2026-10-10)

Format per entry: **question**, **gate** (and where it is written), **setup**, **result**, **verdict**,
**receipts**. The time range comes from the receipt's own timestamps (local time, minute steps). The date comes from
the commit that added the receipt; where the receipt does not show the date, OPEN.md says so.

Common setup unless stated: RTX 4070 12 GB (PCIe 4.0 x16), the launcher's 12 GB recipe (262k window, q8_0 KV,
tiered cache, MTP drafting; lookup drafting from bundle-20261008-lookup), layer off. "Repo bin" means the product
binaries in the repo at that time; the bundle name after "by date" is our inference from the commit history, not
written in the receipt. "Mean decode" is `bench/quick_tps.py`'s mean over its code / prose / bash items (400
tokens each). "Lookup jobs" are the 7 or 11 items of `bench/lookup_ab.py` (file quotes, plain items, edit calls).
The 8 GB entries (W32, W36, W41, W43) ran on the RTX 2060 SUPER 8 GB rig (PCIe 3.0 x16, Ryzen 5 2600, 32 GB); their
scripts are on that rig, not in this repo.

Most receipts here are first cited by this log. Where a doc already describes the result, the entry names the doc
section and gives only the numbers that the doc does not have.

---

## W01 Issue #7: decode at 138k with a 95k VRAM line (2026-10-07 14:48-14:59)

- **Question.** With the VRAM line where a desktop on the 4070 puts it (95,000 cells), how fast is decode at 138k
  with MTP on and off?
- **Gate.** None (measurement).
- **Setup.** `bench/issue7_repro.sh 95000 138000`, arms `mtp` (launcher default: draft 2, 4 past the line) and
  `nomtp` (`BONSAI_SPEC=0`). Repo bin (by date: bundle-20261007-fixes).
- **Result.**

  | arm | code | prose | bash | mean decode | code prefill | VRAM used |
  | --- | ---: | ---: | ---: | ---: | ---: | ---: |
  | mtp | 28.3 | 20.4 | 25.5 | 24.7 | 559.7 | 10933 MiB |
  | nomtp | 11.6 | 11.6 | 11.6 | 11.6 | 572.8 | 9723 MiB |

  Draft acceptance (mtp, last 3 requests): 0.59660, 0.35616, 0.51149.
- **Verdict.** Not stated.
- **Receipts.** `docs/receipts/issue7_repro.log`.

## W02 Issue #7: tools in the request, first attempt (2026-10-07 15:00, end not logged), PARTIAL

- **Question.** Does a request with `tools` decode slower at 138k?
- **Gate.** None (measurement).
- **Setup.** As W01, mtp arm only, `bench/issue7_tools.py` with an earlier item order (code, code, prose, prose).
- **Result.** 4 items, then the log stops.

  | item | decode | evaluated |
  | --- | ---: | ---: |
  | code, tools 0 | 25.2 | 137,341 |
  | code, tools 1 | 27.3 (50 tok, 1 tool call) | 137,648 |
  | prose, tools 0 | 19.4 | 137,337 |
  | prose, tools 1 | 19.5 | 137,644 |

  Each item read the whole prompt again (evaluated ~137k).
- **Verdict.** Aborted; W03 is the full run. The commit that added the file calls it "issue 7 aborted tool
  calls" (21e4c55). The script now puts tools on the outer loop, because "each switch costs a full prefill"
  (`bench/issue7_tools.py` comment); that this caused the abort is our reading, not stated.
- **Receipts.** `docs/receipts/issue7_tools_aborted.log`.

## W03 Issue #7: tools and thinking at 138k (2026-10-07 15:18-15:48)

- **Question.** Does decode change with `tools` in the request and with thinking on?
- **Gate.** None (measurement).
- **Setup.** As W01, mtp arm, `bench/issue7_tools.py` (greedy, max_tokens 400, two prompts that say "do not call
  any tool").
- **Result.**

  | think | tools | code decode (tokens) | prose decode (tokens) |
  | --- | --- | --- | --- |
  | 0 | 0 | 25.2 (400) | 19.5 (400) |
  | 1 | 0 | 34.2 (6283) | 20.6 (1188) |
  | 0 | 1 | 27.3 (50, finish tool_calls, 1 call) | 20.2 (400) |
  | 1 | 1 | 31.5 (22947) | 32.0 (8680) |

  With thinking on, the cap of 400 was raised (6283 and 22947 tokens). The code item with tools and thinking off
  made a tool call although the prompt said not to.
- **Verdict.** Not stated.
- **Receipts.** `docs/receipts/issue7_tools.log`.

## W04 Release smoke 0035 (2026-10-07 16:51-16:53)

- **Question.** Does bundle-20261007-budget (patch 0035, reasoning budget report) give the same greedy text?
- **Gate.** `bench/release_smoke.sh`: greedy text identical on code / prose / think, and the budget report probe
  prints PASS.
- **Setup.** Old = repo bin, new = clean unzip `bundle-0035`.
- **Result.** Decode old / new: code 90.6 / 91.5, prose 87.0 / 88.3, think 105.4 / 105.5. Text identical 3/3.
  Budget probe PASS (budget 64: reasoning_n 71, exhausted True; easy: 32, False; budget 40960: 33, False).
- **Verdict.** Released as bundle-20261007-budget (commit 2daa817).
- **Receipts.** `docs/receipts/release_smoke_0035.log`.

## W05 Issue #7: agent-like decode at 45k, MTP on and off (2026-10-07 20:24-20:31)

- **Question.** With thinking on and tools in the request (as an agent client sends), what decode does MTP give
  at 45k?
- **Gate.** None (measurement).
- **Setup.** `bench/issue7_repro.sh` with `TOOL=agent_depth_probe`, cells 112,896, depth 45,000, 2 tools, two asks,
  max_tokens 1500, seed 7. Arms greedy (temp 0) and sampled (0.6 / 0.95 / top_k 20). Repo bin (by date:
  bundle-20261007-budget).
- **Result.** Decode (acceptance):

  | arm | greedy ask 0 | greedy ask 1 | sampled ask 0 | sampled ask 1 |
  | --- | --- | --- | --- | --- |
  | mtp | 86.1 (0.764) | 69.9 (0.521) | 82.7 (0.712) | 67.4 (0.481) |
  | nomtp | 53.5 | 53.8 | 53.7 | 53.8 |

  VRAM used: 11459 MiB (mtp), 10251 MiB (nomtp).
- **Verdict.** Not stated.
- **Receipts.** `docs/receipts/agent_depth_45k.log`, `docs/receipts/agent_depth.jsonl` (rows 1-8).

## W06 Issue #7: sampler settings at 45k (2026-10-07 20:32-20:36)

- **Question.** Do top_k 0 or min_p change MTP decode and acceptance?
- **Gate.** None (measurement).
- **Setup.** As W05, mtp only; arms sampled (top_k 20), sampled-topk0, sampled-minp (min_p 0.05, top_p 1.0).
- **Result.** Decode (acceptance):

  | arm | ask 0 | ask 1 |
  | --- | --- | --- |
  | sampled | 81.1 (0.683) | 67.6 (0.483) |
  | sampled-topk0 | 74.7 (0.688) | 62.7 (0.482) |
  | sampled-minp | 80.3 (0.694) | 68.1 (0.503) |

- **Verdict.** Not stated.
- **Receipts.** `docs/receipts/agent_depth_45k_samplers.log`, `docs/receipts/agent_depth.jsonl` (rows 9-14).

## W07 Issue #7: 50 MCP-like tools at 45k (2026-10-07 20:37-20:40)

- **Question.** Does a long tool list change decode at 45k?
- **Gate.** None (measurement).
- **Setup.** As W06, sampled arm, 50 MCP-like tools (prompt 55,517 tokens instead of 45,397).
- **Result.** Ask 0: 71.4 tok/s (acceptance 0.715, 7082 tokens). Ask 1: 56.6 (0.453). With 2 tools (W06): 81.1 and
  67.6.
- **Verdict.** Not stated. The cause (grammar copy per draft step) was found later (W19, W21).
- **Receipts.** `docs/receipts/agent_depth_45k_tools50.log`, `docs/receipts/agent_depth.jsonl` (rows 15-16).

## W08 Release smoke 0038 (2026-10-07 20:44-20:48)

- **Question.** Does bundle-20261007-8gb (patches 0036-0038) give the same greedy text on the 12 GB recipe?
- **Gate.** As W04.
- **Result.** Decode old / new: code 92.0 / 92.1, prose 88.6 / 88.5, think 106.6 / 106.9. Text identical 3/3,
  budget probe PASS.
- **Verdict.** Released (commit abca2e2: "greedy identical on the 12 GB recipe, budget probe pass, margin 1000 with
  the display on the iGPU").
- **Receipts.** `docs/receipts/release_smoke_0038.log`.

## W09 Release smoke 0039 (2026-10-07 23:19-23:21)

- **Question.** Does bundle-20261008-lookup (patch 0039, lookup drafting on) give the same greedy text?
- **Gate.** As W04.
- **Result.** Decode old / new: code 91.8 / 92.0, prose 88.2 / 88.2, think 105.0 / 106.0. Text identical 3/3,
  budget probe PASS.
- **Verdict.** Released as bundle-20261008-lookup (commit 20cfcc8).
- **Receipts.** `docs/receipts/release_smoke_0039.log`.

## W10 PR #8: engine A/B for patch 0040 (2026-10-07 23:45-23:58)

- **Question.** Does patch 0040 (ADD+RMS_NORM+MUL fusion on every NVIDIA GPU) change decode or text on the 4070?
- **Gate.** None stated.
- **Setup.** `bench/engine_ab.sh`, A = repo bin, B = `root-0040`, alternated A B A B, MTP on and off, 4k and 32k;
  then `release_smoke.sh` (tag `ab_pr8`).
- **Result.** Mean decode, two rounds each:

  | arm | 4k | 32k |
  | --- | --- | --- |
  | A mtp | 94.7, 93.9 | 100.9, 100.6 |
  | B mtp | 94.5, 94.3 | 100.5, 99.1 |
  | A nomtp | 65.0, 64.8 | 56.4, 56.3 |
  | B nomtp | 65.2, 65.1 | 56.6, 56.7 |

  Smoke: text identical 3/3, budget probe PASS.
- **Verdict.** "Neutral on the 4070, greedy identical" (commit 3e4bf98); patch 0040 merged (README: 40 patches).
- **Receipts.** `docs/receipts/engine_ab_pr8.log`, `docs/receipts/release_smoke_ab_pr8.log`.

## W11 Int8 score step: evaluation (2026-10-08 00:46-00:55)

Described in `docs/INT8_ATTENTION.md`, section "Result (2026-10-08): stopped, two gates fail".

- **Question.** Does an int8 score step in prefill attention pass its gates?
- **Gate.** `docs/INT8_ATTENTION.md`, section "Gates": op tests pass; KL against today's kernel at most 0.00017;
  no HumanEval or suite loss; prefill at least +25 % at 128k.
- **Setup.** `bench/int8_eval.sh`, build `build-int8` (`GGML_CUDA_FA_INT8_KQ=1`), KL at ctx 32768, 2 chunks.
- **Result.** Op tests 2994/2994. Kernel time 1005.31 / 9728.00 / 19703.49 / 39714.27 us per run at KV 4k / 32k /
  64k / 128k (51.27 / 42.38 / 41.85 / 41.53 TFLOPS). KL mean 0.000314 ± 0.000105, max 3.334385, 99.9 % 0.004955,
  same top p 99.243 ± 0.048 %. PPL(Q) 8.384131 ± 0.123003, PPL(base) 8.386014 ± 0.122992. The first KL step (00:48)
  wrote nothing; the 00:55 rerun has the numbers.
- **Verdict.** Stopped: the KL gate and the prefill gate fail (doc).
- **Receipts.** `docs/receipts/int8_eval.log`.

## W12 MTP head Q8_0 vs Q4_0 on 12 GB (2026-10-08 00:50-01:16)

Decision in `docs/HYPERQWEN.md` (row "Smaller draft head"), which cites `head_ab.log`.

- **Question.** Does the Q4_0 MTP head (smaller) help the 12 GB recipe?
- **Gate.** None (measurement).
- **Setup.** `bench/head_ab.sh`, same engine and launcher, model file with the Q8_0 head vs the Q4_0 head, order
  q8, q4, q8b, q4b. Lookup jobs at depth 0 into `head_ab.jsonl`.
- **Result.** The first run (00:50-00:55) is VOID: another serve held port 8080, so the q8 lines came from it.
  Rerun:

  | arm | VRAM line | 4k | 32k | 100k | acceptance (3 requests) |
  | --- | ---: | ---: | ---: | ---: | --- |
  | q8 | 119,040 | 93.8 | 100.3 | 87.7 | 0.89943, 0.56883, 0.75568 |
  | q4 | 125,696 | 96.9 | 100.4 | 86.3 | 0.88352, 0.53518, 0.70765 |
  | q8b | 119,040 | 93.4 | 99.8 | 87.4 | same as q8 |
  | q4b | 125,696 | 97.0 | 100.7 | 86.2 | same as q4 |

  Greedy text q4 vs q8 (quote + plain): identical. In `head_ab.jsonl` the edit-call hashes differ between every
  run, also q8 vs q8b (see OPEN.md).
- **Verdict.** Not adopted on 12 GB; it stays the 8 GB choice (doc).
- **Receipts.** `docs/receipts/head_ab.jsonl` (new here), `docs/receipts/head_ab.log` (cited by the doc).

## W13 Prefill writes past the VRAM line: patch 0041 A/B (2026-10-08 01:25-02:55)

Described in `docs/Q8_FULL_CONTEXT.md` item 2 ("Prefill writes past the line") and `docs/INT8_ATTENTION.md`
(end of "Result"), which cite `tier_ab.log`. This entry adds the per-request file and the arms the docs leave out.

- **Question.** Do the write redirect and the next-layer prefetch remove the fixed cost of prefill past the line,
  with the same text?
- **Gate.** None stated.
- **Setup.** `bench/tier_ab.sh 40000`, line pinned at 16,384 cells, one prefill to 40k, then 7 lookup jobs at 30k.
  Base `root-0040`; candidates `root-tier` (pre), `root-tier2` (v2, later v2fix).
- **Result.** Code prefill at 40k (tok/s) and text vs base:

  | arm | prefill | text vs base |
  | --- | ---: | --- |
  | base (0040) | 717.0 | - |
  | pre | 745.3 | not compared |
  | v2 | 982.9 | 4/7 |
  | v2, `KV_TIER_REDIRECT=0` | 721.2 | 0/7 |
  | v2, `KV_TIER_PREFETCH=0` | 966.9 | 7/7 |
  | v2fix | 983.4 | 7/7 (our count from `tier_ab.jsonl` hashes) |
  | v2fix2 | 987.3 | 7/7 (our count, same way) |
  | base, served line, 160k | 542.0 | - |
  | v2fix, served line, 160k | 584.6 | 7/7 |
  | base, q4_0 K/V | 850.9 | - |
  | v2, q4_0 K/V | 1018.5 | 7/7 |

  VOID parts: in the first round (01:25-01:32) the base arm stopped with a Python error and the copy-kernel arm
  (`prek`) logged nothing; the round restarted at 01:32.
- **Verdict.** Patch 0041 shipped in bundle-20261008-tier.
- **Receipts.** `docs/receipts/tier_ab.jsonl` (new here), `docs/receipts/tier_ab.log` (cited).

## W14 Release smoke 0041 (2026-10-08 02:22-02:24)

- **Question.** Does bundle-20261008-tier give the same greedy text?
- **Gate.** As W04.
- **Result.** Decode old / new: code 91.9 / 91.6, prose 88.2 / 88.3, think 106.3 / 106.6. Text identical 3/3,
  budget probe PASS.
- **Verdict.** Released as bundle-20261008-tier (commit 3450a44: "decode and greedy output unchanged (release smoke
  identical)").
- **Receipts.** `docs/receipts/release_smoke_0041.log`.

## W15 Speed table before and after patch 0041 (2026-10-08 02:57-03:56)

The 0041 table is cited in `docs/Q8_FULL_CONTEXT.md` ("Result", 2026-10-08 note). This entry adds the 0040 table.

- **Question.** What do prefill and decode by depth look like on 0040 and on 0041?
- **Gate.** None (measurement).
- **Setup.** `bench/depth_table.sh`, one fresh prefill to 258k, then lower depths from the cache. Line 119,040.
  `root-0040` 02:57-03:28, `bundle-0041` 03:28-03:56. An earlier 0041 start (02:21-02:22) wrote no numbers.
- **Result.**

  | depth | code prefill 0040 / 0041 | mean decode 0040 / 0041 |
  | --- | --- | --- |
  | 258k | 368.7 / 436.1 | 10.7 / 10.7 |
  | 180k | 484.3 / 546.9 | 22.9 / 23.3 |
  | 131k | 628.1 / 649.3 | 45.2 / 46.5 |
  | 112k | 697.5 / 697.5 | 78.3 / 78.2 |
  | 64k | 866.0 / 866.7 | 96.4 / 96.2 |
  | 32k | 1031.9 / 1030.7 | 116.0 / 115.4 |
  | 4k | 1177.8 / 1173.4 | 107.8 / 106.9 |

  Cumulative prefill at 180k: 487 / 546 tok/s.
- **Verdict.** README and HF card tables measured again with 0041 (commit 3450a44).
- **Receipts.** `docs/receipts/depth_table_0040.log` (new here), `docs/receipts/depth_table_0041.log` (cited).

## W16 Issue #7: decode at 138k with a 121k VRAM line (2026-10-08 05:53-06:02)

- **Question.** As W01, with the line at 121,344 cells and lookup drafting on.
- **Gate.** None (measurement).
- **Setup.** `bench/issue7_repro.sh 121344 138000`. Repo bin (by date: bundle-20261008-tier).
- **Result.**

  | arm | code | prose | bash | mean decode | code prefill | VRAM used |
  | --- | ---: | ---: | ---: | ---: | ---: | ---: |
  | mtp | 41.6 | 29.8 | 37.4 | 36.3 | 633.5 | 11713 MiB |
  | nomtp | 20.2 | 20.1 | 20.2 | 20.2 | 648.3 | 10501 MiB |

- **Verdict.** Not stated.
- **Receipts.** `docs/receipts/issue7_121k.log`.

## W17 Issue #7: lookup on and off in an agent session at 60k (2026-10-08 10:06-10:13)

- **Question.** The reporter saw 37.8 tok/s at acceptance 0.378 with lookup on (45 tok/s at 0.49 before). Does
  lookup drafting slow an agent session?
- **Gate.** None (diagnosis).
- **Setup.** `bench/issue7_lookup_ab.sh`, layer on, 30 MCP-like tools, depth 60k, thinking on, greedy and sampled.
- **Result.** Decode (acceptance):

  | arm | greedy ask 0 | greedy ask 1 | sampled ask 0 | sampled ask 1 |
  | --- | --- | --- | --- | --- |
  | lookup | 82.3 (0.731) | 67.1 (0.566) | 73.8 (0.653) | 64.6 (0.522) |
  | no lookup | 79.7 (0.774) | 67.4 (0.57) | 75.3 (0.701) | 64.6 (0.516) |

- **Verdict.** "Lookup is not the cause of the low acceptance" (commit c6e1d02).
- **Receipts.** `docs/receipts/issue7_lookup_ab.log`, `docs/receipts/agent_depth.jsonl` (tags `i7-*`).

## W18 PrismML #330: f16 prefill switch on Ada (2026-10-08 10:14-10:33)

- **Question.** Is the attention kernel faster on an f16 copy than on q8_0 in place, at a served shape, and does
  `GGML_CUDA_FA_PREFILL_F16` help serving?
- **Gate.** None stated.
- **Setup.** `bench/fa_prefill_f16_ada.sh`: `test-backend-ops perf` (head 256, 4 KV heads x 6, 512 queries) on
  `build-0040`; serving A/B with `bench/tier_ab.sh` on the repo bin.
- **Result.**

  | KV | q8_0 us/run | f16 us/run | f16 kernel vs q8_0 |
  | ---: | ---: | ---: | --- |
  | 4096 | 1276 | 1129 | +13.0 % faster |
  | 32768 | 11157 | 10811 | +3.2 % faster |
  | 65536 | 22605 | 22358 | +1.1 % faster |
  | 131072 | 45576 | 46464 | -1.9 % (slower) |

  - Tiered 12 GB recipe, 100k: switch off prefill 735.3, lookup jobs mean 208.8. Switch on: VOID, the server
    stopped when its pool grew (`cuMemSetAccess` failed, per the script header).
  - All-VRAM 64k window, 60k: off prefill 888.7 / on 898.2; lookup jobs mean 211.6 / 194.9; text 7/7. File quotes
    with the switch on: 263.2 vs 289.5, 270.9 vs 299.3, 290.7 vs 324.1, 243.6 vs 269.2 tok/s (`tier_ab.jsonl`).
- **Verdict.** Data for PrismML #330 (commit b8ba790: "+13% at 4k, +3% 32k, +1% 64k, -2% 128k, serving 60k prompt
  +1.1%, lookup verify batches -9 to -10% on file rewrites"). Led to W23.
- **Receipts.** `docs/receipts/fa_prefill_f16_ada.log`, `docs/receipts/tier_ab.jsonl` (tags `tierab-f16*`).

## W19 Issue #7: 107 tools and server-default sampling (2026-10-08 10:47-11:01)

- **Question.** The reporter's client sends 107 tools (104k characters) and no sampler fields. Does lookup cost
  speed under that load?
- **Gate.** None (diagnosis).
- **Setup.** `bench/issue7_tools_ab.sh`, layer on. t107: 105 varied tools padded to 976 characters each (106.7k
  characters in all) at 36k filler (about 63k tokens in all); t2: 2 tools at 63k. Arms "server" (no sampler
  fields: temperature 1.0, top_k 20) and greedy.
- **Result.** Decode ask 0 / ask 1 (acceptance ask 0):

  | | t107 server | t107 greedy | t2 server |
  | --- | --- | --- | --- |
  | lookup | 72.4 / 41.7 (0.718) | 65.2 / 47.6 (0.713) | 70.7 / 63.5 (0.566) |
  | no lookup | 72.5 / 41.8 (0.718) | 64.2 / 47.6 (0.785) | 75.9 / 63.5 (0.655) |

- **Verdict.** "Lookup on = off; 107 tools cost 46 vs 30 ms per draft step at the same depth" (commit 29a77eb; the
  ms numbers are not in the receipt). Led to patch 0042 (W21).
- **Receipts.** `docs/receipts/issue7_tools_ab.log`, `docs/receipts/agent_depth.jsonl` (tags `i7b-*`).

## W20 Issue #7: replay of a real 27-tool agent session (2026-10-08 11:01-11:38)

- **Question.** On real agent requests, does lookup change speed or text?
- **Gate.** None (diagnosis).
- **Setup.** `bench/issue7_replay_ab.sh` with `bench/capture_replay.py`, layer on, captured requests (27 tools,
  47k characters of tool definitions), requests -1 / -3 / -5, greedy and the client's sampling, max_tokens 1500.
- **Result.**

  | request | mode | lookup on: tok/s, acc | lookup off: tok/s, acc | same text |
  | --- | --- | --- | --- | --- |
  | -5 | greedy | 112.7, 0.735 | 106.6, 0.932 | True |
  | -5 | server | 84.2, 0.609 | 75.9, 0.526 | False |
  | -3 | greedy | 78.1, 0.780 | 79.2, 0.780 | True |
  | -3 | server | 76.3, 0.642 | 83.3, 0.783 | False |
  | -1 | greedy | 104.2, 0.983 | 22.1, 0.559 | True |
  | -1 | server | 22.1, 0.423 | 22.1, 0.420 | False |

  Request -1 is a 161,070-token prompt (prefill 581.2 / 580.9 tok/s, TTFT 277.3 / 277.5 s); greedy ran to 24,576
  tokens (finish length). Sampled texts differ by design.
- **Verdict.** "Greedy text identical 3/3, lookup 104 vs 22 tok/s on a repeating 161k answer, same speed otherwise"
  (commit 280ac27).
- **Receipts.** `docs/receipts/issue7_replay_ab.log`, `docs/receipts/issue7_replay_ab.jsonl`.

## W21 Patch 0042: tool-call identity with 107 tools (2026-10-08 11:38-11:54)

The speed side is in README (bundle-20261008-tools paragraph), which cites `issue7_fix_ab.log`.

- **Question.** With the binary-search grammar copy, are the tool calls the same?
- **Gate.** `bench/toolcall_identity.py` docstring: "two engines that copy the grammar correctly give the same
  hash".
- **Setup.** `bench/issue7_fix_ab.sh` runs `bench/toolcall_identity.py` per arm: one greedy request with the 107-tool
  list that must call tools. Arms base (repo bin), fix (`root-fix`), fix-gate (`LLAMA_SPEC_LOOKUP_GATE=1`),
  fix-nolookup.
- **Result.**

  | arm | calls | hash | tok/s | tokens | acceptance |
  | --- | --- | --- | ---: | ---: | ---: |
  | base | read, read, github_search_issue | f544aac5db5c | 60.1 | 401 | 0.69 |
  | fix | same | f544aac5db5c | 87.7 | 401 | 0.69 |
  | fix-gate | same | f544aac5db5c | 87.4 | 401 | 0.69 |
  | fix-nolookup | same | f544aac5db5c | 88.6 | 369 | 0.75 |

- **Verdict.** Pass. Patch 0042 shipped in bundle-20261008-tools (README).
- **Receipts.** `docs/receipts/toolcall_identity.jsonl`, `docs/receipts/agent_depth.jsonl` (tags `i7f-*`); times
  from `docs/receipts/issue7_fix_ab.log` (cited).

## W22 Release smoke 0042 (2026-10-08 11:54-11:55)

- **Question.** Does bundle-20261008-tools give the same greedy text?
- **Gate.** As W04.
- **Result.** Decode old / new: code 93.2 / 92.7, prose 89.6 / 89.4, think 108.0 / 107.3. Text identical 3/3,
  budget probe PASS.
- **Verdict.** Released as bundle-20261008-tools (commit f278528).
- **Receipts.** `docs/receipts/release_smoke_0042.log`.

## W23 PrismML #330: f16 switch only for 64+ query batches (2026-10-08 11:55-12:09)

- **Question.** If the f16 conversion runs only for batches of 64+ queries, does the decode loss from W18 go away?
- **Gate.** None stated.
- **Setup.** `bench/tier_ab.sh 60000`, all-VRAM 64k window; f16off (repo bin), `root-minq` with min-Q 64, and with
  min-Q 9 (the old rule).
- **Result.**

  | arm | prefill | lookup jobs mean | text vs off |
  | --- | ---: | ---: | --- |
  | f16 off | 887.6 | 212.3 | - |
  | min-Q 64 | 898.0 | 212.4 | 7/7 |
  | min-Q 9 | 896.3 | 195.4 | 7/7 |

- **Verdict.** Patch 0043 (README patch table: "Ada: 195.4 -> 212.4 tok/s on copy-heavy decode with the switch on").
- **Receipts.** `docs/receipts/fa_minq_ada.log`, `docs/receipts/tier_ab.jsonl` (tags `tierab-*-64k`).

## W24 PR #9: 1-token answers, Ada repro (2026-10-08 16:28-16:41)

- **Question.** The 8 GB card gave 1-token answers to fresh long prompts. Does the 4070 show it with the 8 GB preset
  forced?
- **Gate.** None (repro).
- **Setup.** `bench/one_token_ab.sh` with `bench/one_token_repro.py`: fresh prompts at 20k / 30k / 33k / 40k / 60k,
  greedy, 64 tokens. Arms 8gb-preset, 8gb-nopool (`GGML_CUDA_SHARED_POOL=0`), 8gb-nof16
  (`GGML_CUDA_FA_PREFILL_F16=0`), q4-f16cap32k.
- **Result.** 20 of 20 answers normal (34-52 completion tokens, finish stop).
- **Verdict.** Not reproduced on Ada (commit 4700299: "20/20 normal answers"). The 8 GB preset dropped the shared
  pool the same day, from the 2060 data (commit b5cacf9).
- **Receipts.** `docs/receipts/one_token_ab.log`, `docs/receipts/one_token_repro.jsonl` (tags `8gb-*`, `q4-*`).

## W25 PrismML #320: draft window with two slots (2026-10-08 16:41-16:47)

- **Question.** With `--spec-draft-window` and two slots, does slot 1 keep its draft rows while slot 0 runs deep?
- **Gate.** Script docstring: B2 greedy text and draft acceptance match the one-slot run.
- **Setup.** `bench/pr320_two_slot_check.py`, `build-sdw`, window 1024, deep request ~8000 tokens, own server on
  port 8899. A first start at 16:41 logged only its header; the run at 16:46 has the numbers.
- **Result.** Two slots: B1 85.1 tok/s (0.452), A 91.5 (0.585, 8869 prompt tokens), B2 87.9 (0.495, 26 prompt
  tokens, c3ae1c5a9f45). One slot: B1 83.7 (0.452), B2 88.6 (0.495, 26, c3ae1c5a9f45). B2 text same: True.
- **Verdict.** Pass (commit dd767d6: "B2 identical to one slot, same acceptance").
- **Receipts.** `docs/receipts/pr320_two_slot.log`.

## W26 Release checks for bundle-20261008-8gbfix (2026-10-08 22:08-22:16)

- **Question.** Same greedy text, and normal answers to fresh long prompts with the 8 GB preset?
- **Gate.** As W04 for the smoke. None stated for the 1-token check.
- **Setup.** `release_smoke.sh` (`bundle-0045`), then `one_token_ab.sh` arm 8gb-bundle0045 (8 GB preset forced, 131k).
- **Result.** Smoke: decode old / new code 90.6 / 91.7, prose 88.8 / 88.2, think 107.4 / 106.5; text identical
  3/3; budget probe PASS. 1-token check: the first try (22:09) is VOID (HTTP 401, no API key in the stage); the
  rerun (22:12-22:16) gave 5/5 normal answers (31-44 tokens).
- **Verdict.** Released as bundle-20261008-8gbfix (commit 9bf3645).
- **Receipts.** `docs/receipts/release_smoke_0045.log`, `docs/receipts/one_token_ab.log`,
  `docs/receipts/one_token_repro.jsonl` (tag `8gb-bundle0045`).

## W27 Issue #7: long session vs fresh server (2026-10-08 22:09-22:12)

- **Question.** Is a long session past the VRAM line slower than a fresh server at the same context?
- **Gate.** None (diagnosis).
- **Setup.** `bench/frag_ab.sh` with `bench/frag_session.py`, line pinned at 16,384, a growing chat of ~2.5k-token
  turns to 46.5k; the tool list changes at turn 6 (6 -> 26 tools); then the last request on a fresh server.
- **Result.** Turn 17 (ctx 46,546): 82.7 tok/s, 30.4 ms per draft step. Fresh server, same request: 80.4 tok/s,
  31.3 ms per step. Turn 6 read the whole prompt again (17,250 tokens, cached 0) after the tool change.
- **Verdict.** No difference. The slowdown in the issue came from a lower VRAM line at that start (105k vs 243k,
  other programs held 2.3 GB: `bench/frag_session.py` docstring); the launcher now shows free VRAM at start (commit
  cae8298).
- **Receipts.** `docs/receipts/frag_ab.log`, `docs/receipts/frag_session.jsonl`.

## W28 PR #11 / patch 0046 on the 12 GB recipe (2026-10-09 02:08-03:21)

README describes the result (bundle-20261009-agent and bundle-20261009-ckpt paragraphs) without the receipt.

- **Question.** Do checkpoints inside a long message (`--checkpoint-every-nt 8192`) save time when the end of that
  message changes, with the same text?
- **Gate.** None stated.
- **Setup.** `bench/ckpt_ab.sh`, candidate root with patch 0046, `lookup_ab.py` (11 requests, each changes only the
  end of one long user message), 64k and 160k.
- **Result.**

  | arm | mean wall after the first request | peak working set | private bytes | text |
  | --- | ---: | ---: | ---: | --- |
  | 0, 64k | 64.52 s | 11473 MiB | 18560 MiB | - |
  | 8192, 64k | 15.52 s | 13364 MiB | 20454 MiB | 11/11 same |
  | 0, 160k | 230.40 s | 14638 MiB | 21733 MiB | - |
  | 8192, 160k | 49.34 s | 11237 MiB | 18194 MiB | 11/11 same |

  Means computed by us from `ckpt_every_nt_12gb.jsonl`; they match the commit (64.5 -> 15.5 s, 230.4 -> 49.3 s).
  The log says "checkpoints created 0, restored 0" for every arm (see OPEN.md).
- **Verdict.** On for the 12 GB recipe from bundle-20261009-agent (README).
- **Receipts.** `docs/receipts/ckpt_ab.log`, `docs/receipts/ckpt_every_nt_12gb.jsonl`.

## W29 Release checks for bundle-20261009-ckpt (2026-10-09 08:03-08:07)

- **Question.** Same greedy text, and normal answers to fresh long prompts with the 8 GB preset?
- **Gate.** As W04 for the smoke.
- **Result.** Smoke: decode old / new code 93.4 / 93.2, prose 89.9 / 89.8, think 108.4 / 108.9; text identical 3/3;
  budget probe PASS. 1-token check (8gb-bundle0046, 08:04-08:07): 5/5 normal (32-52 tokens).
- **Verdict.** Released as bundle-20261009-ckpt (commit fa201c0).
- **Receipts.** `docs/receipts/release_smoke_0046.log`, `docs/receipts/one_token_ab.log`,
  `docs/receipts/one_token_repro.jsonl` (tag `8gb-bundle0046`).

## W30 Issue #7: cache reuse after a stop (2026-10-09, before 08:23; no times in the receipt)

- **Question.** After a stop (ESC) and a new message, does the server read a long agent session again from token 0?
- **Gate.** Expectations in the script docstring: (a) a new message reads only the new tail; (c) a change at the end
  of the first user message reads from there.
- **Setup.** `bench/cache_reuse_repro.sh` (layer off) with `bench/cache_reuse_repro.py`: 111 tools, a first user
  message, 35 synthetic agent steps (6000-character tool results), then four follow-ups from the same state. Tag
  `product-0045`.
- **Result.**

  | event | prompt tokens read | cached | wall |
  | --- | ---: | ---: | ---: |
  | start | 29,929 | 0 | 28.9 s |
  | step 35 | 3,322 | 141,717 | 8.6 s |
  | a: new message | 535 | 144,523 | 1.9 s |
  | b: stopped answer, then new message | 26 | 145,052 | 0.9 s |
  | c: first user message changed at its end | 115,678 | 29,413 | 211.2 s |
  | d: thinking removed from every assistant message | 114,509 | 29,894 | 207.9 s |

- **Verdict.** "Stop + new message reuses the cache; a change near the start restores the nearest checkpoint"
  (commit ce7fd26). Related fix the same morning: the layer adds its note from the first user message only (commit
  c86f267).
- **Receipts.** `docs/receipts/cache_reuse_repro.jsonl`.

## W31 Draft size past the VRAM line at 160k (2026-10-09 08:26-09:16)

Described in `docs/Q8_FULL_CONTEXT.md` item 5, which cites `tail_draft_ab.jsonl`. This entry adds the log.

- **Question.** Is a tail draft of 6 or 8 better than 4 at 160k?
- **Gate.** None stated.
- **Setup.** `bench/tail_draft_ab.sh 4 6 8`, `BONSAI_SPEC_DEEP=N`, checkpoints every 8192, lookup on, line 118,784.
- **Result.** Group means from the jsonl (our computation):

  | tail | file quotes | plain | edit calls |
  | ---: | ---: | ---: | ---: |
  | 4 | 125.28 | 24.63 | 56.75 |
  | 6 | 130.03 | 23.87 | 60.38 |
  | 8 | 106.47 | 19.87 | 50.70 |

  The log has one line per arm (the csv.py edit: 66.9 / 67.9 / 58.8 tok/s).
- **Verdict.** 4 stays (commit b3446a4; doc).
- **Receipts.** `docs/receipts/tail_draft_ab.log` (new here), `docs/receipts/tail_draft_ab.jsonl` (cited).

## W32 8 GB: the 262k window (2026-10-09 09:10-20:25, arm start times)

Described in `docs/8GB.md` section "The 262k window" and README (bundle-20261009-vram). This entry lists the runs.

- **Question.** With partial staging, the packed KQ mask and the shared pool, can the 8 GB drafting preset use the
  full 262k window, and is it as fast as the 131k preset?
- **Gate.** Not in this repo (`docs/8GB.md`: plans and gates were written before each run, on the rig).
- **Setup.** RTX 2060 SUPER 8 GB, q4_0 KV, Q4_0 MTP head, rig bins `bin-0046` and `bin-pmask`.
- **Result.**

  | run | what | result |
  | --- | --- | --- |
  | P75 | 0046 bin, `BONSAI_CTX=262144` | over-commit: "min free 4194283 MiB at end" (free VRAM below zero); decode 51.9 / 24.1 / 9.9 / 6.9 / 4.9 at 4k / 64k / 128k / 192k / 250k |
  | P77 | 131k preset vs 131k without staging vs 262k without staging | 64k mean decode 30.6 / 38.5 / 38.4; 128k code prefill 112.3 / 38.1 / 37.9; the 262k arm: "trace min free -45 MiB" |
  | P81 | 131k preset, decode direct, staging 40k, 262k staging 81k | op tests 2994/2994; 64k mean decode 30.6 / 30.6 / 32.6 / 26.9; 128k follow-up prefill 100.3 / 100.4 / 50.7 / 100.0 |
  | P82 | packed vs f16 mask, drafting | 32k 11/11 and 64k 11/11 same text; loaded free VRAM 341 -> 449 MiB |
  | P83 | shared pool, line 52,224 | 64k decode 30.6 -> 32.7; fresh 60k 3 of 3 normal (31.7-31.8 tok/s) |
  | P84 | 131k preset vs H131 vs H262 | decode 4k-128k: 51.0 / 46.0 / 30.5 / 17.8 / 13.0 vs 51.7 / 46.4 / 38.0 / 20.1 / 14.2 vs 51.7 / 46.5 / 37.8 / 20.1 / 14.2, 160k 10.4; fresh 60k on H262: 37.3 / 37.2 |
  | P85 | auto 262k from the launcher | decode 50.8 / 45.8 / 37.5 / 20.0 / 14.1; fresh 60k 37.0 / 37.0; "one-token: 0 of 22" |

- **Verdict.** 262k window by default on 8 GB (commit aa557fb). P75 and the P77 262k arm are over-committed; the
  launcher now counts the KQ mask for the window (commit aa557fb: "P75 over-commit").
- **Receipts.** `docs/receipts/262k_8gb/` (p75_sweep.txt, p77_summary.txt, p81_summary.txt,
  p82_packed_vs_f16_ab.jsonl, p82_summary.txt, p83_summary.txt, p84_A_preset.txt, p84_H131.txt, p84_H262.txt,
  p84_summary.txt, p85_summary.txt).

## W33 12 GB: shared CUDA pool (2026-10-09 12:31-12:59)

Described in README (bundle-20261009-pool paragraph) without the receipt.

- **Question.** How much VRAM does the shared pool + 256-token draft micro-batch save, what does it do to decode past
  the line, and are fresh long prompts still normal?
- **Gate.** None stated.
- **Setup.** `bench/pool_ab.sh`, checkpoints every 8192. Phase 1: line pinned at 110,592, VRAM after a 32k request.
  Phase 2: `BONSAI_POOL_MIB=42`, line by the launcher.
- **Result.**
  - Phase 1: used 11422 MiB off, 11348 MiB on (74 MiB saved). Mean decode at 32k 85.3 / 84.9.
  - Phase 2: line 118,784 -> 120,064. Mean decode 131k 39.3 -> 41.0, 180k 20.7 -> 21.2. Code prefill 131k
    646.2 / 645.7, 180k 544.7 / 544.3.
  - Fresh prompts 20k-60k with the pool on: 5/5 normal (36-52 tokens).
- **Verdict.** On by default for the 12 GB recipe with a 0046+ engine (commit 13b5ec1).
- **Receipts.** `docs/receipts/pool_ab.log`, `docs/receipts/one_token_ab.log`, `docs/receipts/one_token_repro.jsonl`
  (tag `pool-on`).

## W34 PR #13 on Ada: packed KQ mask (2026-10-09 19:27-20:26)

- **Question.** With MTP drafting and lookup, does the packed mask give the same text as the f16 mask, and how much
  VRAM does it save?
- **Gate.** None stated.
- **Setup.** `bench/pr13_ada_check.sh`, `root-0049`, engine commit 142d5105d. The first pass (19:27-20:01) is VOID:
  the candidate root had no models folder and `BONSAI_MODEL` was not passed (health 0 in every arm).
- **Result.**
  - VRAM at line 110,592 after a 32k request: 11348 MiB (f16 mask), 11108 MiB (packed): 240 MiB saved. Mean decode
    85.4 / 85.5.
  - Text at 32k: 11/11 same; at 64k: 11/11 same (hash count from `pr13_ada.jsonl`).
  - Fresh prompts with the packed mask: 5/5 normal (41-52 tokens).
  - Release smoke: the first "old" block (20:21) overlapped a 12 GB A/B and is VOID; the rerun (20:22-20:26) gave
    text identical 3/3, budget probe PASS.
- **Verdict.** "Packed vs f16 mask 22/22 identical, 240 MiB saved, fresh prompts normal, smoke identical" (commit
  af529d0).
- **Receipts.** `docs/receipts/pr13_ada.log`, `docs/receipts/pr13_ada.jsonl`, `docs/receipts/release_smoke_pr13.log`,
  `docs/receipts/one_token_ab.log` (tag `pr13-mask1`).

## W35 12 GB recipe: packed mask moves the VRAM line (2026-10-09 20:26-20:48)

Described in README (bundle-20261009-vram paragraph) without the receipt.

- **Question.** If the launcher adds the 240 MiB to the VRAM line, what changes at 131k and 180k?
- **Gate.** None stated.
- **Setup.** `bench/mask12_ab.sh`, PR #13 engine, f16-mask launcher vs packed-mask launcher, shared pool on.
- **Result.**

  | arm | line | mean decode 131k | mean decode 180k | code prefill 131k | code prefill 180k |
  | --- | ---: | ---: | ---: | ---: | ---: |
  | f16 mask | 120,064 | 40.9 | 21.2 | 641.3 | 539.4 |
  | packed | 128,000 | 48.2 | 23.0 | 640.0 | 538.8 |

- **Verdict.** Packed mask on for the 12 GB recipe (commit 05e349b: "decode +18% at 131k, +8.5% at 180k").
- **Receipts.** `docs/receipts/mask12_ab.log`.

## W36 8 GB: chunked prefill attention (2026-10-09 20:47 to 2026-10-10 01:32, arm start times)

Described in `docs/8GB.md` ("The 262k window", chunked prefill paragraph) and README (bundle-20261010).

- **Question.** Past the f16 prefill limit, does prefill attention in 32k-cell chunks speed up deep prefill on the
  8 GB card, with the same quality?
- **Gate.** Not in this repo (as W32).
- **Setup.** RTX 2060 SUPER, 262k preset. P86 / P86b: before (`bin-pmask`); P89: `bin-chunk`
  (`GGML_CUDA_FA_CHUNK=32768`); P89b: whole-cache f16 copy vs chunked; P89c: wikitext-2 perplexity at a 64k window.
- **Result.**

  | depth | code prefill before / chunked | 512-token prose follow-up before / chunked | mean decode before / chunked |
  | --- | --- | --- | --- |
  | 64k | 234.0 / 282.1 | 153.0 / 203.5 | 34.7 / 32.3 |
  | 128k | 121.2 / 171.1 | 99.6 / 135.8 | 11.6 / 11.8 |
  | 192k | 57.7 / 116.0 | 34.7 / 97.1 | 8.4 / 8.1 |
  | 250k | 25.4 / 90.3 (P86b) | 19.3 / 79.9 | 5.7 / 5.7 |

  - Op tests: 3005/3005 base, chunk 256, chunk 768; 44/44 for min-Q 1, head 256.
  - Text at 64k: chunk off vs on 8/11 (the three plain items differ); whole-cache f16 vs chunked also 8/11.
  - Perplexity (2 x 65,536): in place 7.2106, whole f16 7.2107, chunked 7.2074 (± 0.0712).
  - P86 stopped with a client error after 192k; P86b reran 128k-250k.
- **Verdict.** Patches 0051-0052; on in the 8 GB preset (commit 4d95fbc). The 12 GB recipe keeps it off (W44).
- **Receipts.** `docs/receipts/chunked_prefill/` (all 7 files), `docs/receipts/262k_8gb/p86_summary.txt` (same as
  p86_before_summary.txt), `docs/receipts/262k_8gb/p89_chunk_deep_250k.txt`.

## W37 Release checks for bundle-20261009-vram (2026-10-09 21:07-21:20)

- **Question.** Same greedy text; normal start and normal answers with the 8 GB preset (131k default and 262k) and
  the 12 GB recipe?
- **Gate.** As W04 for the smoke.
- **Result.** Smoke: decode old / new code 92.7 / 92.9, prose 89.0 / 89.2, think 107.3 / 107.3; text identical 3/3;
  budget probe PASS. 12 GB start: line 128,000 (margin 1000 MiB). Fresh prompts 20k-60k: 8gb-vram 5/5, 12gb-vram
  5/5, 8gb-vram262 5/5 normal.
- **Verdict.** Released as bundle-20261009-vram (commit 4ba234e).
- **Receipts.** `docs/receipts/release_smoke_0049.log`, `docs/receipts/release_vram_checks.log`,
  `docs/receipts/one_token_ab.log`, `docs/receipts/one_token_repro.jsonl` (tags `8gb-vram*`, `12gb-vram`).

## W38 Issue #16: RAM under 7 thinking requests (2026-10-09 22:56-23:13)

- **Question.** How much system RAM do the prompt cache and the checkpoints take over 7 sequential thinking
  requests, and how much do caps save?
- **Gate.** None (measurement).
- **Setup.** `bench/ram_ab.sh` with `bench/ram_probe.py` (each request its own ~24k preamble, thinking on,
  max_tokens 4096), 12 GB recipe at 262k, line 128,000. Arms default and caps (`LLAMA_ARG_CTX_CHECKPOINTS=8`,
  `LLAMA_ARG_CACHE_RAM=1024`). The log also has arms of another recipe, not part of this entry.
- **Result.**

  | arm | requests | server private peak | system commit start -> peak |
  | --- | --- | ---: | --- |
  | default | 7/7 status 200 | 21724 MiB | 15.61 -> 41.45 GiB (+25.84) |
  | caps | 7/7 status 200 | 15124 MiB | 15.40 -> 35.04 GiB (+19.64) |

- **Verdict.** Not stated in the commit (eeac900). Led to the RAM sizing in bundle-20261010 (W40, W41).
- **Receipts.** `docs/receipts/ram_ab.log`, `docs/receipts/ram_ab.jsonl` (tags `b12-default`, `b12-caps`).

## W39 Issue #16: RAM at load (2026-10-09 23:19-23:28)

- **Question.** How much RAM does the server hold right after load, per launcher setting?
- **Gate.** None (measurement).
- **Setup.** `bench/ram_load.sh`, no request, 8 s after health.
- **Result.** Private / working set: default 13590 / 6463 MiB; `BONSAI_SPEC=0` 11715 / 5969; all-VRAM 64k
  10870 / 6440; tiered 131k 13061 / 6447. The arm `nommap-check (LLAMA_ARG_MMAP=1)` is VOID (health 0).
- **Verdict.** Not stated.
- **Receipts.** `docs/receipts/ram_load.log`.

## W40 Issue #16: 12 GB recipe with the 32 GB tier (2026-10-10 05:03-05:12)

- **Question.** With a 4096 MiB prompt cache and 32 checkpoints, what is the RAM peak?
- **Gate.** None (measurement).
- **Setup.** As W38, `bench/ram_ab_b12_tier.sh`, arm b12-tier32 (`LLAMA_ARG_CACHE_RAM=4096`).
- **Result.** 7/7 status 200. Server private peak 17534 MiB. Commit 16.39 -> 38.38 GiB (+21.99).
- **Verdict.** "Peak 17.5 GB vs 21.7" (commit 1904624); README bundle-20261010: "24-47 GB, a 4 GiB cache and 32
  checkpoints ... 21.7 -> 17.5 GB peak".
- **Receipts.** `docs/receipts/ram_ab.log`, `docs/receipts/ram_ab.jsonl` (tag `b12-tier32`).

## W41 Issue #16 on 8 GB: RAM budget from free commit (2026-10-10, before 07:20; no clock times)

Described in README (bundle-20261010 paragraph) without the receipts.

- **Question.** Can the launcher size the prompt cache and the checkpoints from the free commit, so a 16 GB machine
  does not run out?
- **Gate.** Not in this repo (as W32).
- **Setup.** RTX 2060 SUPER, 131k, q4_0, 7 thinking requests per arm. P90c / P90d / P90e-b16 hold commit down with a
  ballast (12 GiB or 39 GiB).
- **Result.**

  | run | free commit at start | cache / checkpoints | private peak | min free commit | requests |
  | --- | --- | --- | ---: | ---: | --- |
  | P90b default | - | server defaults | 18311 MiB | 6510 MiB | 7/7 |
  | P90b capped | - | cache limit 1024 MiB | 10484 MiB | 14362 MiB | 7/7 |
  | P90b budget | 25737 MiB | 8192 MiB / 32 | 18307 MiB | 6465 MiB | 7/7 |
  | P90c budget | 13433 MiB | 1580 MiB / 6 | 11829 MiB | 682 MiB | 7/7 |
  | P90d budget | 13434 MiB | 0 / 6 | 10485 MiB | 1980 MiB | 7/7 |
  | P90e t32 | 32 GB tier | 4096 MiB / 32 | 14433 MiB | 37506 MiB | 7/7 |
  | P90e b16 | 12821 MiB (16 GB) | 0 / 4 | 10486 MiB | 1392 MiB | 7/7 |

  In the capped arm the server skipped each prompt state (1278-1356 MiB > the 1024 MiB limit).
- **Verdict.** The launcher sizes the cache and the checkpoints from free commit, with RAM tiers (commits 27c34a4,
  2bae2f5; README bundle-20261010).
- **Receipts.** `docs/receipts/ram_8gb/` (all 11 files).

## W42 Patch 0050: HumanEval release gate (2026-10-10 05:54-07:41)

- **Question.** Does patch 0050 (concat transpose path) change HumanEval?
- **Gate.** `bench/he_ab_release.sh` header: "Release gate: HumanEval 164 at medium on the raw server". The pass rule
  is not written.
- **Setup.** Product root vs `bonsai-root-concat`, medium, temp 0, max_tokens 24576, layer off.
- **Result.** Old 160/164 (97.56 %) in 3229.7 s. New 160/164 (97.56 %) in 3175.3 s.
- **Verdict.** Commit df64f02: "160/164 on both engines, same items passed". Patch 0050 in bundle-20261010. The
  decode side (+1.4 %) is in `docs/decode-efficiency.md`.
- **Receipts.** `docs/receipts/he_ab_release.log`.

## W43 8 GB: sessions that stay deep (2026-10-10 06:00-11:26, arm start times; date inferred)

Described in `docs/8GB.md` section "Sessions that stay deep (150k and more)" without the receipts.

- **Question.** What helps decode when a session stays past ~150k on the 8 GB card?
- **Gate.** Not in this repo (as W32).
- **Setup.** RTX 2060 SUPER, 262k preset. P80c: tail draft 1 vs 2 (`BONSAI_SPEC_DEEP=2`, margin 375). P95: CPU
  attention timing (`cpuattn_bench.cpp`). P98 / P98b: attention-mass probe at depth (filler, then 180k of Python
  source).
- **Result.**
  - P80c: tail 1 vs tail 2: mean decode 64k 31.5 vs 28.2, 200k 7.5 vs 8.8; acceptance 0.799 vs 0.702; line 58,112 vs
    49,664.
  - P95: CPU, KV 196,608, 2 queries: 278.04 ms per layer; CUDA0 same shape: 3.05 ms. CPU, 1 query: 138.93 ms.
  - P98: with the probe on, decode 17.2 / 8.2 / 4.6 / 3.5 at 64k / 128k / 192k / 250k. P98b: per layer, the "1e-2
    union mean" column spans 0.191-0.809.
- **Verdict.** Tail 2 only for sessions past ~150k; CPU attention does not help (doc).
- **Receipts.** `docs/receipts/depth_8gb/` (p80c_tail2_summary.txt, p95_cpu_fa_perf.txt, p98_filler_kfirst.txt,
  p98b_realtext_kfirst.txt, cpuattn_bench.cpp).

## W44 PR #19 on Ada: chunked prefill attention (2026-10-10 07:41-09:02)

README (bundle-20261010) gives the decision without the receipt.

- **Question.** On the 12 GB recipe (q8_0, 262k), does `GGML_CUDA_FA_CHUNK=32768` help, with the same text?
- **Gate.** None stated.
- **Setup.** `bench/pr19_ada_check.sh`, engine commit 2f213ff96, one binary, one server session per arm through
  4k -> 64k -> 128k -> 192k -> 250k.
- **Result.**
  - `test-backend-ops FLASH_ATTN_EXT`: 3007 OK, 0 fails at chunk 0, 256 and 768.

  | depth | code prefill off / on | mean decode off / on |
  | --- | --- | --- |
  | 4k | 1201.3 / 1204.6 | 96.1 / 95.8 |
  | 64k | 855.9 / 898.6 | 87.1 / 88.0 |
  | 128k | 524.1 / 598.5 | 70.6 / 74.9 |
  | 192k | 375.6 / 427.3 | 23.7 / 21.4 |
  | 250k | 443.9 / 496.0 | 12.6 / 11.8 |

  - Lowest free VRAM: 361 MiB off, 165 MiB on.
  - Text: 64k 9/11 same (plain prose, plain bash differ); 160k 7/11 same (quote shlex.py, plain code / prose / bash
    differ).
  - Fresh prompts with chunking on: 5/5 normal.
- **Verdict.** The 12 GB recipe keeps chunking off for now; `GGML_CUDA_FA_CHUNK=32768` turns it on ("+12-14 %
  prefill at 128k-249k", README bundle-20261010). The 160k quote is followed up in W47.
- **Receipts.** `docs/receipts/pr19_ada.log`, `docs/receipts/pr19_ada.jsonl`, `docs/receipts/one_token_ab.log` (tag
  `pr19-chunk`).

## W45 Release checks for bundle-20261010 (2026-10-10 09:05-09:14)

- **Question.** Same greedy text; normal answers to fresh long prompts on the 12 GB recipe and the 8 GB preset at
  262k?
- **Gate.** As W04 for the smoke.
- **Result.** Smoke: decode old / new code 92.4 / 93.7, prose 88.8 / 90.1, think 107.2 / 108.7; text identical 3/3;
  budget probe PASS. Fresh prompts: b1010-12gb 5/5, b1010-8gb 5/5 normal.
- **Verdict.** Not stated in a commit (the receipts came with commit 21e4c55 on 2026-10-11). bundle-20261010 is the
  release in README.
- **Receipts.** `docs/receipts/release_smoke_1010.log`, `docs/receipts/one_token_ab.log`,
  `docs/receipts/one_token_repro.jsonl` (tags `b1010-*`).

## W46 PR #19: chunking at depth 0 (2026-10-10 09:14-09:18; date inferred)

- **Question.** At depth 0, does the chunk switch change anything?
- **Gate.** None stated.
- **Setup.** Four runs: off, on, off, on (`GGML_CUDA_FA_CHUNK` 0 / 32768), 11 lookup jobs each. The script is not in
  this repo.
- **Result.** "Chunk-path lines in the server log: 0" in all four runs. Text 11/11 same for r1 vs r3, r2 vs r4 and
  r1 vs r2. csv.py edit: 150.6 / 150.6 / 152.8 / 151.3 tok/s.
- **Verdict.** Not stated.
- **Receipts.** `docs/receipts/pr19_depth0.log`, `docs/receipts/pr19_depth0.jsonl`.

## W47 PR #19: the 160k shlex quote (2026-10-10 09:23-09:47)

- **Question.** The shlex.py quote at 160k differed with chunking on (W44). Is it repeatable?
- **Gate.** None stated.
- **Setup.** `bench/pr19_quote160k.sh`, bundle bin, drafting + lookup, quote items only at 160k, runs off / on /
  off / on, texts saved to `artifacts/pr19_quote160k/` (local).
- **Result.** shlex.py hash: off a470f9e5143e (runs 1 and 3), on 137637372fa4 (runs 2 and 4). The other three quotes
  have the same hash in all four runs. First request (the 160k prefill): 287.0 / 287.7 s off, 258.5 / 258.2 s on.
- **Verdict.** "The 160k shlex quote is a deterministic near-tie; the chunked answer is the exact copy" (commit
  ed7c34b).
- **Receipts.** `docs/receipts/pr19_quote160k.log`, `docs/receipts/pr19_quote160k.jsonl`.

## W48 PrismML #346: repro on Ada (2026-10-10 12:34-14:24)

`docs/Q8_FULL_CONTEXT.md` ("Not affected: PrismML #346") gives the later cause, without this receipt.

- **Question.** Does the reported illegal memory access after a long q4_0 prefill (prism-b10770) happen on the 4070?
- **Gate.** None (repro).
- **Setup.** `bench/prism346_repro.sh`: the reporter's command (no drafter, default batch sizes, 65k slot), base
  `Ternary-Bonsai-2-27B-PTQ1_0.gguf`, q4_0 K/V, needle prompts of ~30k and ~45k tokens, max_tokens 3000. Arms
  b10770, b10770 with #312 reverted, and (with 4 GiB of VRAM held by `tools/vram-ballast`) the same, the reporter's
  prompt sizes (~31,768 / ~47,367), an sm_86 build and a 40-SM schedule.
- **Result.** Every request: "ok ... server alive=1 | no CUDA error". In every request the content was empty and the
  needle word was not found (completion 3000 tokens).
- **Verdict.** No crash on Ada; "reasoning budget not applied on b10770" (commits 128e0bc, 7d1bedf, cbf6324).
- **Receipts.** `docs/receipts/prism346.log`.
