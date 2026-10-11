## Overview

The server makes context checkpoints only where a user message starts and near the end of the prompt. A hybrid / recurrent model cannot roll back its state without a checkpoint. When an agent client changes a prompt inside one long message (for example, a tool result that is edited or cut, or a stop and a new message in the middle of a long turn), the nearest checkpoint can be tens of thousands of tokens back, and the server processes the whole prompt again.

This change adds `--checkpoint-every-nt N` (env `LLAMA_ARG_CHECKPOINT_EVERY_NT`). With N > 0, the server also makes a checkpoint at the start of a prompt batch when N or more prompt tokens are after the last checkpoint. A later prompt that diverges inside a long message then restores the nearest checkpoint. The default is 0: the behavior does not change. The existing limits (`--ctx-checkpoints`, `--checkpoint-min-step`) still apply.

## Additional information

Bonsai 2 27B PTQ1_0 with the MTP head (hybrid: Gated DeltaNet + attention), our fork with the same commit (applies to `prism` 8b0c19c8c without changes), a bench that sends 11 agent-like requests (quote a file, edit it with a tool call, plain answers) after a long first message. Wall time of each request after the first, mean (min-max):

| card, depth | N = 0 | N = 8192 | text |
| --- | --- | --- | --- |
| RTX 2060 SUPER 8 GB, 64k | 227.0 s (18.4-290.6) | 60.5 s (18.4-280.9) | 11 of 11 identical |
| RTX 4070 12 GB, 64k | 64.5 s (6.3-82.1) | 15.5 s (6.3-79.7) | 11 of 11 identical |
| RTX 4070 12 GB, 160k | 230.4 s (17.8-288.5) | 49.3 s (17.7-281.8) | 11 of 11 identical |

- Decode speed does not change (4070 at 64k: 250.8 / 250.3 tok/s).
- Restores are logged at n_tokens 61,788-63,493 at 64k (verbose log, 2060).
- The first request and a request that changes the start of the prompt (a new tool list) still process the whole prompt. This is expected.
- Cost: system RAM for the extra checkpoints. The upper bound is `--ctx-checkpoints` x the state size (32 x about 170 MiB for this model). On the 2060 the server working set went from 6834 to 7333 MiB at 64k.
- Correctness of the restore path (2060, 64k, N = 8192): the control arm and an arm without KV tiering give 22 of 22 texts identical to N = 0. Arms without speculative decoding and with a different state gather give a different, correct text for each prompt (no repeated output).

## Requirements

- I have read and agree with the [contributing guidelines](https://github.com/ggml-org/llama.cpp/blob/master/CONTRIBUTING.md)
- AI usage disclosure: YES. An AI coding assistant (Claude), working for the account owner at the owner's request, wrote the change and ran the A/B tests on both cards.
