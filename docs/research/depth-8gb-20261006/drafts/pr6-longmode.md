Open finding on the 8 GB long-context mode (no head). It is not resolved. Please read it before more launcher changes.

RTX 2060 SUPER, `bin-rc3` (= `bundle-20261007`), stock clocks, layer off, `bench/quick_tps.py` at 4k:

| how the server starts | decode tok/s |
| --- | --- |
| launcher, long mode (3e89c15, 7882d0f and 36d6e12) | 37.6 - 38.8 (9 runs) |
| same llama-server command line, from a 2-line .ps1 through the same `serve.ps1` | 42.9 - 43.8 (14 runs) |
| launcher, long mode, 2026-10-07 10:45 (P34, before a reboot) | 43.9 |

The command lines are identical (captured from the process). The environment is identical except `BONSAI_*` (the engine reads none). Clocks during decode are identical (1860-1890 MHz core, 6801 MHz memory).

These do not change the result: binary rc2 or rc3, N, `-ub`, `GGML_CUDA_FA_PREFILL_F16`, chat template kwargs, reasoning budget and message, thinking on or off, port, host, API key, the GPU-busy check, the CIM / `--help` / `nvidia-smi` steps, `$ErrorActionPreference`, `try`/`finally`.

The first 258 lines of the launcher plus a literal server call is fast. The full launcher with the same literal call is slow.

The drafting mode through the launcher is not affected: 51.3 tok/s (P34: 50.9).

Deep end of the 131k window, launcher preset, same rig (decode / prefill tok/s):

| depth | drafting | long context |
| --- | --- | --- |
| 4k | 51.3 / 404 | 38.2 / 423 |
| 32k | 43.2 / 291 | 30.7 / 309 |
| 64k | 30.8 / 188 | 22.8 / 201 |
| 96k | 16.3 / 130 | 10.4 / 136 |
| 126k | 11.3 / 105 | 6.9 / 110 |

Past the VRAM line (about 54k-59k positions), decode is bound by PCIe 3.0 reads of the host tail.
