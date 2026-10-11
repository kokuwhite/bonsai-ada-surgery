8 GB cards, measured on an RTX 2060 SUPER that also draws the desktop (Turing, PCIe 3.0, stock clocks). Seven commits; the 12 GB defaults are unchanged.

## What changes

- **`start-server.ps1` 8 GB preset**, detected from total VRAM (`BONSAI_8GB=1` forces, `0` turns it off): q4_0 K/V, a 131k window, the Q4_0 MTP head with draft 1 / tail 1 when its file is present (else no head and micro-batch 1024), `GGML_CUDA_SHARED_POOL=1` + `LLAMA_MTP_DRAFT_UBATCH=256`, `GGML_CUDA_FA_PREFILL_F16`, and the VRAM line sized from fixed costs measured per mode. `BONSAI_UBATCH` sets the micro-batch.
- **Display detection**: `nvidia-smi` reports `display_active: Disabled` / `display_attached: No` on WDDM (driver 591.86) for a card that draws the desktop, so the headless margin was chosen. The launcher now also asks Windows (`Win32_VideoController.CurrentHorizontalResolution` of the adapter matching GPU 0); a single match with a resolution means a display. Please check the 4070 rig with the desktop on the iGPU: its NVIDIA adapter should report no resolution and keep the 1000 MiB margin.
- **`build/make_mtp_q4head.ps1` + `build/requant_mtp.py`**: the grafted head requantized Q8_0 -> Q4_0 (ported from mirai-s-ada), with the strip proof (head removed = official PTQ1_0 sha256). Output reproduced byte for byte in a second run.
- **`docs/8GB.md`**: the two modes, quality, margin, what was not used and why.
- **README**: the 8 GB row; "lossless speculative decoding" replaced by what `docs/Q8_FULL_CONTEXT.md` says (each token is the target's greedy choice; not bit-identical to decoding without the head).

## Receipts (preset launched with no tuning variables, release-candidate bundle)

| mode | positions in VRAM (auto) | decode 4k / 32k | prefill 4k / 32k |
| --- | ---: | --- | --- |
| drafting | 53,760 | 50.9 / 43.2 | 408 / 330 |
| long context | 58,880 | 43.9 / 34.2 | 432 / 353 |

Full sweeps, quality (HumanEval medium: q4_0 157/164, q8_0 159/164) and the negative results are in `docs/8GB.md`. Engine pieces: PrismML #325 (Turing one-column) and #330 (f16 prefill); the shared pool is the Mirai engine's `4bdc6587b`.
