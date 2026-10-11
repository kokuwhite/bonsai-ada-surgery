@sb32445 I ran the test again on the RTX 2060 SUPER with your new commit. The 2 MiB cap gives no gain on this card.

Two sm_75 builds. The only difference between them is the prefetch (`git diff`: 4 files, prefetch code only):

- on: `e697877d9` + #325 (one-column PT on Turing)
- off: merge-base `2459f68b5` + #325

Bonsai 2 27B PTQ1_0, q4_0 K/V, no MTP head, `-c 16384`, all in VRAM, stock clocks, greedy. Each run is 3 prompts x 400 tokens per depth. The server restarts for each run. The runs alternate off / on, 3 rounds.

| | 4k decode tok/s | 16k decode tok/s |
| --- | --- | --- |
| off | 41.4 / 41.2 / 41.2 | 33.0 / 32.9 / 32.9 |
| on (2 MiB, 1 CTA per SM) | 40.7 / 41.3 / 41.3 | 32.9 / 32.9 / 33.0 |
| on vs off, mean | -0.4 % | 0.0 % |

The difference is in the run-to-run noise. Turning the prefetch off outside Ada is correct for this card. Thank you for the fix and for the 4070 data.
