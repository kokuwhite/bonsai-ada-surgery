The Windows CUDA 13.3 release zip crashes on RTX 20 (Turing, sm_75) cards whose driver supports less than CUDA 13.3, with only `ggml-cuda.cu:107: CUDA error` and no message.

## Reproduce

RTX 2060 SUPER 8 GB, driver 591.86 (`nvidia-smi`: CUDA Version 13.1), Windows 11, `prism-b10754-2459f68`:

```
llama-server -m Ternary-Bonsai-2-27B-PTQ1_0.gguf -c 16384 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0
```

- `llama-prism-b10754-2459f68-bin-win-cuda-13.3-x64.zip`: buffers reserve normally (5,971 MiB projected of 7,000 free), then `ggml-cuda.cu:107: CUDA error` at the first kernel launch. Same with or without a draft model.
- `llama-prism-b10754-2459f68-bin-win-cuda-12.4-x64.zip`, same command: loads (about 2 minutes of PTX JIT on first start), answers correctly.

## Cause

`release-prism.yml` does not set `CMAKE_CUDA_ARCHITECTURES`, so `ggml/src/ggml-cuda/CMakeLists.txt` uses its default: `75-virtual 80-virtual 86-real 89-real 90-virtual ...`. Turing gets PTX only, and a driver cannot JIT PTX produced by a newer toolkit than it supports (13.3 PTX on a 13.1 driver). The 12.4 PTX JITs on the same driver. `ggml-cuda.dll` from the 13.3 zip has machine code for sm_86 / sm_89 / sm_120 only.

## Suggestion

Build the Windows (and Linux) CUDA release legs with `75-real` added (for example `-DCMAKE_CUDA_ARCHITECTURES="75-real;80-virtual;86-real;89-real;90-virtual;120a-real"`, or whatever list the release wants plus `75-real`). That also removes the first-start JIT on Turing with the 12.4 zip. Until then, RTX 20 users on older drivers can use the 12.4 zip or update the driver.

For reference, a build of the same tree with `-DCMAKE_CUDA_ARCHITECTURES="75-real"` (CUDA 13.4 toolkit) runs on this card and driver without JIT.
