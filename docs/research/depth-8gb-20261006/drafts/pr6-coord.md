Done on this branch:

- `main` merged (`702d018`); README conflict resolved: `main`'s Hugging Face download for the head file, with this branch's wording ("every token is the target model's greedy choice ... not bit-identical", per `docs/Q8_FULL_CONTEXT.md`). `start-server.ps1` merged without conflict and parses.
- Engine: `2cb7a4ed6` cherry-picked onto the 8 GB engine as `3f808b80b`, pushed as fork branch `bonsai-8gb` (`c8b8993a6` + `bc3e5aa02` + `b7c11567a` + `c9a2a7dd0` + 0034).
- Pre-release `bundle-20261007` rebuilt from it and re-tagged at `702d018`. `ggml-cuda.dll` is byte-identical to the previous upload (0034 touches only `common/`). On the RTX 2060 SUPER: an `anyOf: []` property in `response_format` returns `{"name": "Bob"}`; decode 43.6 tok/s (unchanged). Asset sha256 `cd8a91cc0e3411cbb27af0c84df477d32453d68d947382e06c5e1d13ffbdebf2`, verified on download.
