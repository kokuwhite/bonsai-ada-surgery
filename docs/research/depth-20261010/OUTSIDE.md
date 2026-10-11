# Outside work considered (2026-10-10 / 11)

Techniques from papers, upstream llama.cpp and other inference projects, surveyed while planning this round, with what
we did about each. Numbers are the sources' own (not reproduced here unless an experiment ID is given).

## Long-context decode with a cache in host memory

| technique (source) | mechanism | what we did |
| --- | --- | --- |
| Quest (arXiv 2406.10774) | per-page min/max of K bounds each page's score; read the top pages only | implemented (`fa-sparse-proto`); D03, D04, D08, D10, D16 |
| FreeKV (arXiv 2505.13109) | choose pages from the previous step's query so the copy can be prefetched | not built; candidate if the selection cost shows in op timing |
| Whole-context selection with sinks (Quest-style, applied to all cells) | attention work follows the budget, not the context length | `SINKS`; rejected at page 256 (D11), retry queued |
| CPU attention for the host part, merged by log-sum-exp (HGCA arXiv 2507.03153, ScoutAttention arXiv 2603.27138) | GPU attends the VRAM part, CPU the host part | measured earlier on the 8 GB rig: a 6-core CPU needs ~110 ms per layer for 192k rows (`docs/8GB.md`); not pursued |
| Low-bit KV for the host tail (KIVI arXiv 2402.02750, rotated 3-4-bit KV in community llama.cpp forks) | fewer bytes per cell over PCIe | not built; quality reports for 3-bit are mixed |
| "Sparse V" skip (community llama.cpp forks) | skip V work where softmax weights are ~0 | `GGML_CUDA_FA_V_SKIP`; exact, no gain here (D12) |
| Eviction (SnapKV, PyramidKV) | drop cells permanently after the prompt | not tried: cannot be recalled, breaks exact copies |
| Engine paging with a model-native sparse indexer (one MoE engine whose full-attention layers pick 2,048 cells per step) | page cache works because the model reads few cells | not portable to dense attention; our sparse selection is the approximate equivalent |

## Long-context prefill

| technique (source) | mechanism | what we did |
| --- | --- | --- |
| Block-sparse prefill (MInference arXiv 2407.02490, FlexPrefill 2502.20766, XAttention 2503.16428, RBS-Attention 2609.20971) | each query block attends to selected key blocks | MMA tile skip built; sparse prefill with Quest page bounds lost exact copies (D10) |
| Selector ablation (RBS-Attention) | at equal density, Quest-style bounds score like other selectors; cumulative-mass thresholds and always-kept sink / local / column blocks matter more | informs any retry |
| Speculative prefill (arXiv 2502.02789) | a small model scores tokens; the big model prefills only the important spans | not tried: lossy for every later turn of an agent session |
| Chunked gated-delta-net prefill (ggml-org/llama.cpp#29353) | MMA kernel for the delta rule over chunks, BF16 hi/lo split, fp32 state | ported with three changes for this model (D14) |
| fp16 accumulation or INT8 for QK in the attention kernel (SageAttention arXiv 2411.10958) | GeForce tensor cores run fp32 accumulation at half rate; our QK accumulates in fp32, PV in fp16 | not built; SageAttention itself does not support head dim 256 or Turing |
| Larger prefill micro-batches (several community guides) | fewer reads of the prefix per prompt | measured: 512 is best here (D13) |

## Serving and agents

| technique (source) | what we did |
| --- | --- |
| Prefix and recurrent-state reuse across agent turns (SGLang hybrid radix cache; exact-boundary state snapshots in new hybrid-model engines) | our checkpoints already reuse prefixes; the side-request fix (D01) keeps a deep slot for its conversation |
| Tape-replay rollback for speculative decoding on hybrid models (closed llama.cpp PR #29763; ReplaySSM idea) | not built; would remove the ~150 MiB per draft token of state snapshots on 8 GB |
| Gate/up + GLU fusion in the MMQ kernel (llama.cpp PR #29948, +2-7 % prefill on 27B models) | not ported: conflicts with the ternary matmul path |
| Thinking length and the system turn, thinking budgets (community reports on Qwen3.x) | measured in `docs/research/thinking-20261010/` |
