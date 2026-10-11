# Experiments D01-D17

Format per entry: **question**, **gate** (and where it was declared), **setup** (hardware, engine commit, root, env,
script), **result**, **verdict**, **receipts**. RTX 4070 12 GB, 12 GB recipe (262k window, q8_0 KV, tiered cache,
MTP + lookup drafting, layer off) unless stated. "Mean decode" is `bench/quick_tps.py`'s mean over its code / prose /
bash items (400 tokens each). Retrieval: `bench/needle_depth.py` (12 facts) and `bench/code_needle.py` (exact copies
of 10 short Python functions from `artifacts/eval/pycode.raw`).

---

## D01 Side request re-reads the whole prompt (2026-10-10 09:30-11:51)

- **Question.** Coding agents send short side requests (titles, summaries) between turns. With one slot, does the next
  turn re-read the whole prompt?
- **Gate.** None (diagnosis). Fix gate declared in chat: turn 2 reuses the cached prompt.
- **Setup.** 120k-token prompt, then a 25-146-token side request, then turn 2 (`bench/side_request.py`,
  `bench/side_ab.sh`). Arms: `np1` (product), `np2` (`BONSAI_SLOTS=2`, unified KV, idle-slot cache off), `np2keep`
  (same + `LLAMA_SLOT_KEEP_TOKENS=4096`, engine `87e2ac160`).
- **Result.**

  | arm | turn 2 tokens read | cached | turn 2 wall |
  | --- | ---: | ---: | ---: |
  | np1 | 119,995 | 121 | 178.8 s |
  | np2 | 120,116 | 0 | 232.3 s |
  | np2keep | **19** | **120,097** | **0.7 s** |

  The first np2keep run (11:16) is void: two test chains ran on the GPU at the same time (out of memory).
- **Verdict.** Cause found: the side request takes the only slot (np1), or the similarity rule gives it the deep slot
  (np2). `LLAMA_SLOT_KEEP_TOKENS` keeps a deep slot for its conversation. Prototype only; see D02 for its cost.
- **Receipts.** `receipts/side_ab.log`, `receipts/side_ab.jsonl`.

## D02 Cost of a second slot (2026-10-10 12:24-12:32)

- **Question.** What does `-np 2` cost at 32k?
- **Gate.** None (measurement).
- **Setup.** `bench/slots_prefill.sh`, code item at 32k, `BONSAI_VRAM_MARGIN=1300` in all arms.
- **Result.** Mean decode / prefill: np1 85.5 / 1045.5, np1 unified 86.0 / 1041.8, np2 not unified 12.6 / 161.4
  (broken), **np2 unified 71.9 / 819.9 (-16 % / -22 %)**, np1 again 86.1 / 1040.6.
- **Verdict.** Unified KV is required for two slots; the remaining -16 % is unexplained (open). D01's fix is not
  shipped until this cost is understood.
- **Receipts.** `receipts/slots_prefill.log`.

## D03 Sparse host-tail reads: retrieval, emulation (2026-10-10 11:23-12:12)

- **Question.** If each query reads only the top pages of the host tail (Quest page bounds), does retrieval hold?
- **Gate.** Declared in chat and #21: needles equal to dense.
- **Setup.** Engine `f5f273aed` (emulation: every host row still read, the mask hides the rest). 160k, VRAM line
  pinned at 32,768 cells (`BONSAI_KV_VRAM_CELLS`), graphs off, f16 mask, `GGML_CUDA_FA_SPARSE=B,64,1024`
  (`bench/needle_ab.sh`).
- **Result.** Needles: dense 12/12, B = 8192 12/12, B = 4096 12/12. (The first dense arm at 11:23 did not start:
  health = 0; rerun at 11:51.)
- **Verdict.** Pass at both budgets.
- **Receipts.** `receipts/needle_ab.log`, `.jsonl`.

## D04 Sparse host-tail reads: exact code copies, emulation (2026-10-10 13:24-13:49)

- **Question.** Does exact recall of code hold? Needles are easy; copying a function needs every token.
- **Gate.** Declared in chat: copies equal to dense.
- **Setup.** As D03, `bench/code_needle_ab.sh`.
- **Result.** Exact copies: dense 10/10, B = 8192 **10/10**, B = 4096 8/10.
- **Verdict.** B = 8192 (page 64) passes; B = 4096 fails. B = 8192 is the budget from here on.
- **Receipts.** `receipts/code_needle_ab.log`, `.jsonl`.

## D05 Sparse reads: KL on wikitext and Python source (2026-10-10 12:54-13:23), VOID

- **Question.** KL divergence of sparse vs dense logits at depth.
- **Gate.** None declared.
- **Setup.** `llama-perplexity --kl-divergence-base` at `-c 65536` (`bench/sparse_kl.sh`).
- **Result.** No numbers. The PC froze twice (12:55 and about 13:10). From the Windows event log: low virtual memory
  naming `llama-perplexity`. The KL base keeps about n_ctx / 2 x 248,320 vocab x 4 bytes = ~32 GB of logits on a
  32 GB machine. A rerun at the safe size (`-c 16384`) still wrote nothing usable before it was abandoned.
- **Verdict.** Void. Lasting changes: `tools/ramguard.ps1` (kills `llama-server` / `llama-perplexity` when free
  commit < 6 GB or free RAM < 1.5 GB) in every heavy script, and the rule "estimate a run's RAM first; KL at most
  16k context with this vocab". Quality is measured with retrieval (D03, D04) instead.
- **Receipts.** `receipts/sparse_kl.log`.

## D06 Vec kernel skips fully masked tiles (2026-10-10, `346b123b5`)

- **Question.** Can the decode attention kernel skip a 128-cell tile whose mask is `-inf` for every cell and column,
  so unselected host pages are not read?
- **Gate.** Exactness: all `FLASH_ATTN_EXT` op tests pass.
- **Result.** `test-backend-ops -o FLASH_ATTN_EXT -b CUDA0`: 3007 ok, 0 fail.
- **Verdict.** Exact; kept. (Its 128-cell size later turned out too coarse for 64-cell pages on 2-query steps, D17.)
- **Receipts.** `receipts/sparse_speed.log` (first line).

## D07 Sparse decode speed, first fast builds (2026-10-10 18:55-20:23)

- **Question.** Does reading only the kept pages speed up decode at 192k and 250k?
- **Gate.** None (measurement).
- **Setup.** `bench/sparse_speed.sh`, 12 GB recipe's own VRAM line. Arms: dense as shipped (graphs on, packed mask),
  dense-fair (graphs off, f16 mask), sparse `8192,256,1024` fast. Lookup off: engine `c084831aa`; lookup on: engine
  `71371d4cb` (fast path up to 64 queries, page staging).
- **Result.** Mean decode at 192k / 250k:

  | arm | lookup off | lookup on |
  | --- | --- | --- |
  | dense as shipped | 19.8 / 12.3 | 19.7 / 12.7 |
  | dense-fair (graphs off) | 22.8 / 13.4 | |
  | sparse | 21.5 / 13.5 | 14.4 / 9.2 |

- **Verdict.** No gain; slower with lookup. Two findings came out of it: dense-fair beat dense as shipped by 15 %,
  which led to the CUDA graphs finding (patch 0053, `research/release-20261011/`); and the sparse arms paid a host
  sync per K write (fixed in `2f47c38b7`, D09) and read masked tiles (D11).
- **Receipts.** `receipts/sparse_speed.log`.

## D08 Cached page bounds after a deep prompt edit (2026-10-10 18:55-19:07)

- **Question.** The fast path caches page bounds per K tensor. After a deep prompt edit, are they stale?
- **Gate.** Declared in chat: 0 stale-bound ops with tracking on.
- **Setup.** `bench/sparse_edit.sh`, engine `71371d4cb` with `GGML_CUDA_FA_SPARSE_CHECK=1` (recomputes all bounds every
  op and logs differences). 160k of Python files; then the file at 91 % replaced (24,966 tokens written again in the
  host tail); then the same request again. Arms: tracking on, `GGML_CUDA_FA_SPARSE_NOTRACK=1`.
- **Result.** Stale-bound ops (base / edit / again): tracking on 0 / 0 / 0, off 0 / 208 / 208 (for example 312 of 576
  page-heads differ from page 60). Device vs host page choice: 0 differences in all ops. The answer changed after the
  edit with tracking off, and stayed changed.
- **Verdict.** Pass. Tracking is required, and the device selection equals the host selection.
- **Receipts.** `receipts/sparse_edit.log`.

## D09 Where a step's time goes at 192k: op timing (2026-10-11)

- **Question.** Is attention a large share of a decode step at 192k on 12 GB?
- **Gate.** Declared in chat: if attention is a small share, skip the whole-context and V-skip runs.
- **Setup.** `GGML_CUDA_OP_TIMING=1` (an event before every node, graphs off, printed every 100 graphs at WARN),
  engine `2f47c38b7` (no sync per K write), 12 GB line 121,344, f16 mask (`bench/depth_arms.sh`, tag `optime6`).
- **Result.** Dense: 21.7 tok/s, 25.1 ms per graph, ROPE 22 %, FLASH_ATTN_EXT 13 %. The ROPE share is the stream
  waiting for the staged host rows. Sparse without the tile map: 13.1 tok/s, 43.1 ms per graph, FLASH_ATTN_EXT 71 %.
  No "one sync per K write" warnings.
- **Verdict.** Attention plus the copy wait is ~35 % of a dense step: worth more work. Sparse without the tile map
  reads all masked tiles in place.
- **Receipts.** `receipts/depth_arms.log` (tag `optime6`), `receipts/op_timing_decode_bonsai.txt`.

## D10 Sparse reads at depth, 8 GB-like layout (2026-10-11 00:17-03:18)

- **Question.** With an 8 GB-like layout (VRAM line pinned at 32,768 cells, ~127k cells of host tail at 160k), what
  do the tile maps, the page size and sparse prefill do?
- **Gate.** Declared in chat and #21: copies 10/10 and needles 12/12 (equal to dense); then decode decides.
- **Setup.** `bench/sparse_prefill.sh`, 160k, `GGML_CUDA_FA_SPARSE_FAST=1 GGML_CUDA_KV_TIER_STAGE_MIN_Q=9`, graphs
  off, f16 mask. FA op tests on each new engine: 3007 / 0.
- **Result.**

  | arm (engine) | prefill | mean decode | copies | needles |
  | --- | ---: | ---: | --- | --- |
  | dense (`2f47c38b7`) | 583.8 | 13.6 | 10/10 | 12/12 |
  | sparse 8192,256, no tile map (`2f47c38b7`) | 583.7 | 9.1 | 9/10 | 12/12 |
  | sparse 8192,256 + sparse prefill (`MAXQ=4096`, tile map) | 618.4 | 29.6 | 8/10 | 11/12 |
  | sparse 8192,256, tile map (`85d949f5e`) | | 31.1 | 9/10 | 12/12 |
  | sparse 8192,64, 256-cell map (`85d949f5e`) | | 18.9 | 10/10 | 12/12 |
  | **sparse 8192,64, 64-cell map (`d6c6e9f01`)** | **583.6** | **27.6** | **10/10** | **12/12** |

  Page 256 misses the same copy (`_div_nearest`, 7 lines at 65 % depth) in both runs; page 64 gets it.
- **Verdict.** Page 64 with the 64-cell map passes the gate at 2.0x dense decode. Sparse prefill is rejected (+6 %
  prefill, quality loss). The no-map slowdown explained: 5-query verify ops run the MMA kernel, which read every
  masked host tile in place (slower than the dense DMA).
- **Receipts.** `receipts/sparse_prefill.log`, `.jsonl`.

## D11 Whole-context selection (2026-10-11 06:03-06:56)

- **Question.** If the selection also covers the VRAM part (sinks kept), does attention cost follow the budget?
- **Gate.** Declared in chat: copies 10/10 and needles 12/12.
- **Setup.** `bench/sparse_whole.sh`, engine `85d949f5e`, 12 GB line 121,344, speed at 192k, quality at 160k; arms
  dense, host tail (`8192,256,1024`, tile skip), whole context (`SINKS=1024`).
- **Result.** Mean decode: dense 22.8, host tail 25.2, whole context **36.3**. Quality: dense 10/10 12/12, host tail
  10/10 12/12, whole context **8/10, 7/12**.
- **Verdict.** Rejected at this budget and page size. A page-64, B = 16384 retry is queued (`root-sparse10`).
- **Receipts.** `receipts/sparse_whole.log`, `.jsonl`.

## D12 V skip in the vec decode kernel (2026-10-11 08:48-09:23)

- **Question.** Skip the V rows of 32-cell groups whose weights are all below exp(-20) of the running maximum
  (`GGML_CUDA_FA_V_SKIP=1`, engine `f6f2d146c`)?
- **Gate.** Exactness (op tests, copies, needles), then decode.
- **Result.** FA op tests 3007 / 0; copies 10/10 and needles 12/12 in both arms; mean decode at 192k 19.7 / 19.7.
- **Verdict.** Exact, no gain on this engine: it lacks patch 0053, so the host copy limits decode there. Parked; retest
  on top of 0053 is optional.
- **Receipts.** `receipts/vskip_ab.log`, `.jsonl`.

## D13 Prefill micro-batch at depth (2026-10-11 07:56-08:47)

- **Question.** Each micro-batch reads the whole prefix K/V once per attention op. Does a larger ubatch speed up deep
  prefill?
- **Gate.** None (measurement).
- **Setup.** `bench/ubatch_depth.sh`, release engine, `BONSAI_UBATCH`, cold prefill of a 128k / 192k prompt.
- **Result.** Prefill tok/s at 128k / 192k: ub 512 **654 / 524**, ub 1024 418 / 361, ub 2048 100 / (stopped).
- **Verdict.** 512 (the default) is best; larger loses VRAM to the compute buffer and moves more of the cache to
  system RAM. No change.
- **Receipts.** `receipts/ubatch_depth.log`.

## D14 Chunked gated-delta-net prefill (2026-10-11 01:11-10:20)

- **Question.** Does a chunked MMA kernel for the 48 gated-delta-net layers (port of ggml-org/llama.cpp#29353) speed
  up prefill, also with speculative decoding on?
- **Gate.** Declared in chat: op tests pass; copies and needles equal; HumanEval 164 parity (160/164); sm_75 builds.
- **Setup.** Branch `gdn-chunked`: raw gates activated into temporaries; with K > 1 rollback snapshots the MMA kernel
  runs n - K tokens and the recurrent kernel the last K; the fused state gather copies the live rows first.
  `bench/gdn_prefill_ab.sh`, same binary, `GGML_CUDA_GDN_MMA_DISABLE=1` for the recurrent arm.
- **Result.**
  - Op tests: `GATED_DELTA_NET` 57 / 0 (7 new cases in this model's shape).
  - First A/B (`ce27b9d14`): no change, because the kernel never engaged (the served graph uses the fused gather,
    which the first port excluded).
  - Second A/B (`31c337bbb`), engaged (log: 121 tokens, 116 by MMA, K 5, raw 1, gather 1). Prefill recurrent -> MMA:
    4k 1203.9 -> 1280.9 (+6.4 %), 32k 1021.3 -> 1080.5 (+5.8 %), 128k 581.1 -> 600.7 (+3.4 %). Decode unchanged.
    Copies 10/10, needles 12/12 at 32k in both arms.
  - sm_75 build of `ggml-cuda`: clean (on Turing the runtime check falls back to the recurrent kernel).
  - HumanEval 164, medium: **158/164** (release engine 160/164). New fails: #10 (release thought 18,077 tokens,
    MMA 1,000 and a wrong loop) and #132 (10,435 vs 20,632 tokens); no new passes; tokens unchanged (mean 2313).
- **Verdict.** Below the parity gate as written. The two flips are long-thinking items, where greedy trajectories
  diverge on tiny numeric differences, so a token-level measure decides: wikitext-2 perplexity, MMA vs recurrent on the
  same binary (`bench/gdn_ppl_ab.sh`), queued.
- **Receipts.** `receipts/gdn_prefill_ab.log`, `.jsonl`, `artifacts/humaneval-gdnmma` (local).

## D15 A third-party "sharp" chat template on tool work (2026-10-10 13:50-18:27)

- **Question.** Does a user's template with a different tool prompt help tool work?
- **Gate.** None declared (exploration).
- **Setup.** `bench/tool_template_ab.sh`: the GGUF's own template vs the third-party template file (kept local, not
  in this repo); suite plan `bench/plans/tools_template.json` (12 coding + 10 workspace items), then
  `bench/toolcall_stress.py --n 6`.
- **Result.** Suite: own template 9/22 (workspace 9/10, coding 0/12), third-party 6/22 (workspace 6/10, coding 0/12).
  Stress (native grammar arm): parsed 17/18 vs 18/18, payload ok 13 vs 14. Completion tokens 653,178 vs 562,661.
- **Verdict.** Rejected for tool work. The coding items are too hard for both (0/12), so later template tests use the
  workspace items only (`bench/plans/tools_workspace.json`).
- **Receipts.** `receipts/tool_template_ab.log`.

## D16 RTX 2060 SUPER runs on the sparse branch (#21, 2026-10-10 to 2026-10-11)

Run by the 8 GB rig (numbers from its posts on #21; P-numbers are its run ids). Main 262k launcher, 245k context,
VRAM line 43,520 (f16 mask), host tail ~197k cells, graphs off.

| run | engine | result |
| --- | --- | --- |
| P101 | `87e2ac160` (emulation) | copies 10/10, needles 12/12 at B = 8192 and 16384 (page 64): quality holds at 4 % of the host tail |
| P102 | `87e2ac160` | decode dense 5.7, sparse 2.9; 512-token follow-up prefill 79 -> 39 |
| P102c | `ae61c4cf3` | sparse 2.6; one sync per K write still logged |
| P102d | `ae61c4cf3`, `GGML_CUDA_KV_TIER_REDIRECT=0` | 2.5; warning still there (not the redirect) |
| P102e | `d6c6e9f01` | sync gone (0 warnings); decode sparse 4.3 (lookup off and on), with `SINKS=4096` 5.2; prefill 39, with sinks 6.2 |

- **Verdict so far.** Not faster on the real 8 GB card. Causes found: the 2-query decode ops run the vec kernel, whose
  128-cell tile skip lets a kept 64-cell page pull its neighbour in (fixed in `028f606fc`, a 32-cell warp skip, not yet
  run there); and an unexplained prefill halving with the sparse settings on this recipe only (an isolation run is
  proposed on #21). P105 (dense vs sparse at 160k / 245k on `d6c6e9f01`) is running.

## D17 Tile skip at warp granularity (2026-10-11, `028f606fc`)

- **Question.** Can the vec kernel skip 32-cell groups, so 64-cell pages skip on 2-query steps?
- **Gate.** Exactness (op tests).
- **Result.** Built; op test queued (`root-sparse11`), 2060 run pending.
