# Experiments R01-R10

Format per entry: **question**, **gate** (and where it was declared), **setup**, **result**, **verdict**,
**receipts**. RTX 4070 12 GB, 12 GB recipe (262k window, q8_0 KV, tiered cache, MTP + lookup drafting, layer off)
unless stated. "Mean decode" is `bench/quick_tps.py`'s mean over its code / prose / bash items.

---

## R01 Which shipped setting costs decode at depth (2026-10-10 21:30-22:28)

- **Question.** The depth research's "dense-fair" arm (CUDA graphs off + f16 mask) beat the shipped settings at 192k
  (22.8 vs 19.8). Which of the two settings does it?
- **Gate.** None (measurement).
- **Setup.** Release bin (`2cadbfb64`), 192k, `bench/depth_arms.sh bench/arms/release_graphs_mask.txt` (tag `relgm`).
- **Result.** Mean decode, lookup off / on: shipped 19.8 / 19.8; `GGML_CUDA_DISABLE_GRAPHS=1` only **25.0 / 24.9**;
  `LLAMA_ARG_KQ_MASK_PACKED=0` only 18.3 / 18.1. Same VRAM line (129,024) and prefill in the graphs arms.
- **Verdict.** CUDA graphs off alone gives +26 %; the f16 mask gives nothing.
- **Receipts.** `docs/receipts/depth_arms.log` (tag relgm).

## R02 Cause and change (2026-10-10 22:40-23:30)

- **Question.** Why does turning CUDA graphs off help past the line?
- **Gate.** None (reading the source).
- **Result.** `ggml_cuda_tier_graph_begin` is called with `enable = !use_cuda_graph && !should_launch_concurrent_events`:
  the prefetch (patch 0041) runs only without a CUDA graph. Change: `ggml_cuda_graph_check_compability` returns false
  when an attention node reads the host tail of a tiered buffer (`ggml_cuda_tier_graph_wants_pipeline`), one log line
  per switch, `GGML_CUDA_KV_TIER_GRAPHS=1` for the old behaviour.
- **Verdict.** Patch 0053 (`tier-graphs` `4715804d6`; `product-0053` `90ca41e40`).
- **Receipts.** `patches/0053-*.patch`.

## R03 Gate 1: decode by depth on the 4070 (2026-10-10 23:07-00:07)

- **Gate.** Declared in chat before the run: no loss at 4k / 32k (graphs stay on), gain past the line, lookup on and off.
- **Setup.** `bench/depth_arms.sh bench/arms/tier_graphs_gate.txt` (tag `tgate`) and `..._lkoff.txt` (`tgateoff`);
  the patched sm_89 build in a copy of the release root.
- **Result.** Mean decode shipped -> patched: 4k 95.2 -> 95.4, 32k 101.8 -> 102.3, 128k (below the line) 71.9 ->
  71.8, 192k 23.6 -> 29.4, 250k 12.7 -> 14.6; 192k lookup off 19.8 -> 25.0.
- **Verdict.** Pass.
- **Receipts.** `docs/receipts/depth_arms.log` (tags tgate, tgateoff).

## R04 Gate 2: same text (2026-10-11 00:07-02:15)

- **Gate.** Declared in chat: HumanEval 164 at medium, 160/164 with the same 4 fails.
- **Setup.** `bench/he_template_one.sh -` with `HE_ROOT` = the unzipped bundle-20261011 zip.
- **Result.** Two void attempts: the root had no `models\` (00:15), then its launcher made its own API key and every
  request got HTTP 401 (01:10). Both fixed in the script (`BONSAI_MODEL`, the key copied into the root). Third run:
  **160/164, the same 4 fails, and all 164 outputs identical** to the bundle-20261010 run (token counts and text).
- **Verdict.** Pass.
- **Receipts.** `docs/receipts/release_20261011.log`, `docs/receipts/he_template_ab.log` (tiergraphs).

## R05 Gate 3: the switch line

- **Gate.** Declared in chat: one line per crossing, no switching back and forth.
- **Result.** At INFO the line never reached the server log (0 lines in the gate-1 logs). Raised to WARN
  (`6493bbca4`, in the squash). The release build's servers log it once at start ("does not read the host tail ...:
  CUDA graphs on"); no repeated switching in the gate-2 run.
- **Verdict.** Pass after the WARN change.
- **Receipts.** `docs/receipts/release_20261011.log` (switch lines).

## R06 Release build, stack verify, smoke (2026-10-10 23:30-01:10)

- **Result.** 53 patches `git am` onto PrismML `adfffbe` give tree `c1865c46` = `product-0053`. Release build sm
  75/86/89 in `tooling/build-release-20261007` (reconfigured, build info `90ca41e405`). Bundle zip: same 66 entries as
  20261010. Smoke on the zip's own binaries: `FLASH_ATTN_EXT` 3007/0.
- **Verdict.** Pass.
- **Receipts.** `docs/receipts/release_20261011.log`.

## R07 Gate 4: the 8 GB recipe (issue #22, P103 / P103b, RTX 2060 SUPER)

- **Gate.** Declared on #22 before the run: no loss at 4k / 32k, a gain or no loss past the line; else the 8 GB recipe
  keeps `GGML_CUDA_KV_TIER_GRAPHS=1`.
- **Result.** New / old in one binary: 128k 14.8 / 12.8 (+16 %), 192k 8.6 / 7.9 (+9 %), 245k 6.7 / 6.2 (+8 %), 192k
  lookup off 8.7 / 7.8 (+12 %). P103 showed -3 / -5 % at 4k / 32k; P103b alternated new / old twice: 53.9 / 54.0 /
  53.8 / 53.7 and 48.2 / 48.3 / 48.2 / 48.3, so noise. 0 one-token answers.
- **Verdict.** Pass.
- **Receipts.** Issue #22 (P103, P103b).

## R08 PrismML #346: out-of-bounds write with prompt checkpoints (2026-10-11 07:45-09:15)

- **Question.** The reporter's `compute-sanitizer` trace: an invalid write in `dequantize_block_q4_0` from
  `launch_fattn`, `ggml_cuda_flash_attn_ext_mma_f16_case<256, 256, 8, 8, F16>`, on PrismML `b10770`.
- **Gate.** Declared in the PR: the failing case trips a reservation assert without the fix and passes with it; the
  whole `FLASH_ATTN_EXT` suite passes.
- **Result.** With a quantized V and 3-4 queries, `ggml_cuda_flash_attn_ext_mma_f16_switch_ncols1` takes PrismML
  #189's 64-column f16 route, which converts K/V to f16 even when the in-place quantized kernel exists, while
  `get_alloc_size` (PrismML #221) reserved no f16 buffer on the in-place path. Prompt checkpoints evaluate the last 4
  tokens as their own batch, which reaches the route. With a GGML_ASSERT on the reservation: `FLASH_ATTN_EXT(hsk=256,
  ..., kv=16384, nb=3, type_K=q4_0, type_V=q4_0)` asserts without the `get_alloc_size` change and passes with it;
  `FLASH_ATTN_EXT` 4007/4007.
- **Verdict.** Fix opened as PrismML #350 (waiting on the reporter's test on a 3070). The Bonsai engine has no #189
  route, so the bundles are not affected.
- **Receipts.** PrismML #346 and #350.

## R09 The same change on the Mirai engine (2026-10-11)

- **Result.** `ggml_cuda_tier_graph_begin` has the same gating in `llama.cpp-ada-mirai` (`f16e386f6`); patch 0053
  applies cleanly (`cd4e9d8dd`, built for sm_89). The A/B (Mirai launcher, 32k / 128k / 192k) runs on the Mirai side;
  its results are in the Mirai repo's receipts, not here.

## R10 Earlier this week (2026-10-09 / 10), for the record

- **PR #19 (8 GB chunked prefill attention), Ada check before merge.** On the 4070 the 12 GB recipe keeps it off; a
  160k exact-quote difference was traced to a benign token-level divergence (chunked attention gives an exact copy on
  re-run). Receipts: `docs/receipts/pr19_ada.log`, `docs/receipts/pr19_quote160k.log`, `docs/receipts/pr19_depth0.log`.
- **Bundle-20261010** (issue #16 RAM sizing, #19, patch 0050): release smoke `docs/receipts/release_smoke_1010.log`;
  HumanEval release gate `docs/receipts/he_ab_release.log` (160/164 before and after 0050).
