Pre-release for 8 GB cards; pairs with #6 (launcher preset, Q4_0 head tooling, `docs/8GB.md`). The repo's latest release is unchanged until #6 merges.

Engine: fork branch `bonsai-8gb` (`3f808b80b`) = `bonsai-q8-product` (`c8b8993a6`) plus
- `bc3e5aa02` Turing takes the planar PTQ1_0 one-column decode path (PrismML-Eng/llama.cpp#325): +13.7% decode on an RTX 2060 SUPER
- `b7c11567a` `GGML_CUDA_SHARED_POOL=1`, `LLAMA_MTP_DRAFT_UBATCH=N` (off by default)
- `c9a2a7dd0` `GGML_CUDA_FA_PREFILL_F16=N` (PrismML-Eng/llama.cpp#330): prefill from an f16 copy in pool memory; off by default
- `3f808b80b` patch 0034, empty JSON-schema unions (#3), as in `bundle-20261007-fixes`

Source: `8gb-rig` at `7882d0f`, with `main` merged through `5790ed2`: the layer fixes from `bundle-20261007-fixes` (including `1553bc4`, the run sentence only when a coding tool is offered and the user asks for code) and the vision projector launcher. On 8 GB the preset's measured fixed costs also count `BONSAI_MMPROJ_GPU=1`'s projector (`+ $MmprojMiB` in each mode); the default keeps the encoder on the CPU. The merged launcher was run on the 2060 SUPER: preset on, drafting mode, 54,272 positions in VRAM, server healthy.

Machine code for sm_75 / sm_86 / sm_89, plus compute_89 PTX for newer cards. `test-backend-ops -o FLASH_ATTN_EXT -b CUDA0`: 2994/2994 on sm_75 (CUDA library unchanged by 0034, byte-identical). An empty `anyOf` in `response_format` returns valid JSON.

RTX 2060 SUPER 8 GB, launcher preset with no tuning variables, 131k window, q4_0 K/V:

| mode | decode 4k / 32k | prefill 4k / 32k |
| --- | --- | --- |
| drafting (Q4_0 head, 1/1) | 50.9 / 43.2 | 408 / 330 |
| long context (no head) | 43.9 / 34.2 | 432 / 353 |

`bonsai-bundle-win-x64.zip` sha256 `cd8a91cc0e3411cbb27af0c84df477d32453d68d947382e06c5e1d13ffbdebf2`
