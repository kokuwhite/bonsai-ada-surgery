Docs only (`docs/8GB.md`): the 8 GB page now matches the receipts from 2026-10-08/09.

- **Engine line:** `bundle-20261008-8gbfix` or later is recommended (no 1-token answers, lookup drafting, patches 0041-0045). The shared pool is no longer listed as a preset switch.
- **New table, the deep end on the current engine** (release check P72b for 4k-64k, P62 on `8a6d2ea12` for 96k-126k): decode 51.5 / 46.4 / 30.4 / 17.7 / 14.1 tok/s and prefill 410 / 331 / 193 / 140 / 112 tok/s at 4k / 32k / 64k / 96k / 126k. Lookup file rewrites: 69 tok/s at 64k, 42 at 120k.
- **Memory clock, moved from "Not used" to "Optional".** The old line ("moved decode by less than drift") was measured before the Turing one-column fix and is wrong now:
  - llama-bench: +500 MHz +4.2 %, +1000 MHz +7.7 %;
  - drafting preset: +2.4-2.7 % at 4k-32k, 60-minute soak with identical text;
  - +1250 MHz faulted after about 10 minutes, and +1500 MHz stopped the PC;
  - set the clock before the server starts.
- **Corrected notes:** the tail-2 one-token answers and the packed-mask run both had the shared CUDA pool on. With the pool off, tail 2: 0 of 81. New line for the shared pool: 18 of 18 failures without patch 0045, 0 of 38 with it. Tail 2 is still not used, because more drafts past the line cost positions (P47: at most +9 % at 126k, -41 % at 32k).
