@sb32445 Turing numbers for 1-query decode, with and without the MMA route. On this card the MMA route is a clear gain, and the gain increases with depth.

RTX 2060 SUPER (sm_75), our 8 GB engine (`bonsai-8gb`, which contains the FA commit from #285), Bonsai 2 27B PTQ1_0, GQA 6, no MTP head, `-c 32768`, all in VRAM, stock clocks, greedy, 3 prompts x 400 tokens per depth. The server restarts for each run. Two rounds, alternated. "no MMA" is `GGML_CUDA_FA_MMA_DECODE_MIN_KV=0`. The default (256) takes the MMA route.

| K/V | route | 4k decode tok/s | 16k decode tok/s |
| --- | --- | --- | --- |
| q4_0 | MMA | 43.5 / 43.8 | 38.9 / 39.0 |
| q4_0 | no MMA | 41.2 / 41.3 | 32.9 / 32.9 |
| q8_0 | MMA | 43.7 / 43.7 | 38.9 / 38.9 |
| q8_0 | no MMA | 42.2 / 42.2 | 34.3 / 34.2 |

MMA vs no MMA, mean: q4_0 +6 % at 4k and +18 % at 16k. q8_0 +4 % at 4k and +14 % at 16k. I did not compare the output texts in this test.

On the batch-invariant point you are correct. With `GGML_CUDA_BATCH_INVARIANT=1` the block must not change the route, so it belongs after the check. I agree with your plan: keep the guard that is in #307 now, and extend it to Turing (and Ampere, when somebody measures it) in a follow-up. These numbers are for that follow-up. I can run more shapes or depths on this card if you need them.
