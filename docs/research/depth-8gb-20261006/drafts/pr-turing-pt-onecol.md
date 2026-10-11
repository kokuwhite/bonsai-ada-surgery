One-line change: one-column PTQ1_0 decode on Turing (sm_75) takes the planar PT layout from #218, as Ampere already does. Single commit on current `prism` (`6bfcd79`), applies without conflicts. Ada and newer keep SOA_ISUM; Ampere is unchanged.

## What it does

`ggml_cuda_q8_1_layout_host` sends the one-column case to `GGML_CUDA_Q8_1_PT` on NVIDIA cc 800-889 and leaves every other NVIDIA card on the Ada-tuned `SOA_ISUM`. Turing (cc 750) fell through to SOA_ISUM. The condition now starts at `GGML_CUDA_CC_TURING` instead of `GGML_CUDA_CC_AMPERE`. No kernel changes.

## Receipts

RTX 2060 SUPER 8 GB (sm_75, PCIe 3.0, stock clocks, power limit 175 W verified before every load), Windows, CUDA 13.4, Bonsai 2 27B `Ternary-Bonsai-2-27B-PTQ1_0.gguf`, q8_0 K/V, 4k context, greedy, 2 prompts x 400 tokens x 2 reps per arm, arms alternated, server restarted per arm:

| arm | one-column layout | decode tok/s |
| --- | --- | ---: |
| before | SOA_ISUM | 38.07 |
| after | PT (four-accumulator epilogue) | 43.34 |
| before, `GGML_CUDA_BATCH_INVARIANT=1` | PT (warp-reduce epilogue) | 42.12 |
| after | PT | 43.22 |
| after, `GGML_CUDA_BATCH_INVARIANT=1` | PT (warp-reduce epilogue) | 42.06 |

+13.7% decode. An earlier alternated pair on the same card (SOA 36.76 / 36.69 vs PT via `BATCH_INVARIANT` 41.23 / 41.25) is what pointed at the gate.

- `test-backend-ops -o MUL_MAT -b CUDA0` on sm_75: 1516/1516, default and with `GGML_CUDA_BATCH_INVARIANT=1`.
- With `GGML_CUDA_BATCH_INVARIANT=1` the greedy output is byte-identical before and after the change (both already took PT).
- Without it, greedy text differs from SOA_ISUM (different summation order, as on Ampere). One-column KL on wikitext-2 (`llama-perplexity -b 1 -ub 1 -c 2048 --chunks 4`, f16 K/V, base = SOA_ISUM): mean KL 0.000146, top-1 agreement 99.39 +/- 0.12%, max KL 0.047. The PT path that `GGML_CUDA_BATCH_INVARIANT=1` already selects measures 0.000158 / 99.49% against the same base, so this is the usual near-tie disagreement between two summation orders. For scale, q8_0 vs f16 K/V on this card is mean KL 0.000167, top-1 99.42%.

Thanks to @sudoingX for the PT kernel (#218); this only widens where it is used.
