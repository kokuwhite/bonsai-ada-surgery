Turing data point, since the final commit hardcodes the 4070 tuning (50% / 46 CTAs / 16 MiB): on a 4 MB-L2 card it is a loss.

RTX 2060 SUPER (sm_75, 4 MB L2, 34 SMs), stock clocks, Bonsai 2 27B PTQ1_0, q4_0 K/V, no MTP head, greedy, 2 prompts x 400 tokens per arm, server restarted per arm, three alternated runs per setting (first commit `e3d9df5`, so the switches were available; plus the one-column PT fix from #325):

| setting | 4k decode vs prefetch off | 16k decode vs prefetch off |
| --- | --- | --- |
| 50% / 46 CTAs / 16 MiB (as in `a4249f5`) | -2.4 / -2.7 / -2.7% | -2.4 / -2.6 / -1.1% |
| `GGML_CUDA_L2_PREFETCH_MAX_KB=1024` | +1.4 / +0.6 / +2.2% | +1.2 / +0.7 / +2.2% |
| `GGML_CUDA_L2_PREFETCH_MAX_KB=512` | +0.6 / +2.0% | +0.6 / +1.8% |

Round-to-round spread with prefetch off was under 0.1 tok/s (~0.2%). Greedy output byte-identical in every arm, as expected for a prefetch. 2048 KB and 2048 KB with 34 CTAs landed between (+0.7..1.4%).

So the byte cap wants to scale with the device: a quarter of `l2CacheSize` (1 MiB here) works on Turing; I have not measured what that rule does on the 4070, where you found 16 MiB best.
