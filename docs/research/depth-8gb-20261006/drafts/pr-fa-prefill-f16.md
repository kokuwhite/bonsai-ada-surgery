Opt-in, off by default: `GGML_CUDA_FA_PREFILL_F16=N` lets prefill-sized flash-attention batches (more than 8 queries) over a quantized K/V cache of at most N cells convert K/V to f16 in pool memory sized by the actual KV length and run the f16 MMA kernel. Decode keeps the in-place quantized read from #221. Single commit on current `prism` (`6bfcd79`), applies without conflicts.

## Why

The in-place q4_0/q8_0 read (#221) is the right default: it saves the f16 copy that `ggml_cuda_flash_attn_ext_get_alloc_size` would otherwise reserve behind `dst` for the full context at load (512 MiB at a 131k window for Bonsai 2 27B), and it wins decode. On Turing it costs prefill at depth: the dequantization inside the kernel is slower there than one bulk conversion per chunk. Taking the copy from the pool for prefill only gets both: nothing reserved at load, the f16 kernel for prefill, and the cap keeps the transient copy within the free memory the deployment has.

## What it does

- `ggml_cuda_fattn_prefill_f16(dst)`: true when the variable is set, `Q->ne[1] > 8`, `K->ne[1] <= N`, and K/V are the same quantized type.
- `ggml_cuda_fattn_mma_kv_native_supported` returns false for those batches, so dispatch takes the f16 MMA path.
- `ggml_cuda_flash_attn_ext_get_alloc_size` reserves nothing for them; `launch_fattn` allocates the f16 copies from the pool (`ggml_cuda_pool_alloc<half>`) instead of the space behind `dst`.

## Receipts

RTX 2060 SUPER 8 GB (sm_75, PCIe 3.0, stock clocks), Windows, CUDA 13.4, Bonsai 2 27B `PTQ1_0`, q4_0 K/V, 131,072 window with 58,112 cells on the device, greedy, `bench/quick_tps.py`-style requests at 4k -> 16k -> 32k -> 60k (each extending the previous prompt), two runs:

| depth | prefill, in-place (tok/s) | prefill, `GGML_CUDA_FA_PREFILL_F16=65536` | decode, both |
| ---: | ---: | ---: | ---: |
| 4k | 415.0 | 423.8 / 422.7 | 43.7 |
| 16k | 350.4 | 380.3 / 379.8 | 39.0 |
| 32k | 271.0 | 318.5 / 318.4 | 34.2 |
| 60k | 199.9 | 252.7 / 252.5 | 25.4 |

- `test-backend-ops -o FLASH_ATTN_EXT -b CUDA0` on sm_75 with the variable set to 1048576 (path forced): 2994/2994.
- Greedy output at 32k byte-identical to the in-place path (both read the same f16 values; only where they are formed differs).
- With MTP drafting (draft 1) and the cap at 32768, prefill at 32k 262.5 -> 308.9 tok/s, decode and draft acceptance unchanged.

Not measured on Ampere or Ada, where the in-place read may already win prefill; the variable keeps the current behaviour unless set.
