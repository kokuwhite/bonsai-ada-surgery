# P8c: KL of one-column decode (every token its own ubatch) - bundle SOA_ISUM base vs new build vs bundle + BATCH_INVARIANT.
$ErrorActionPreference = 'Continue'
Set-Location C:\bonsai\bonsai-ada-surgery
$out = 'C:\bonsai\8gb\receipts\p8c'
New-Item -ItemType Directory -Force $out | Out-Null
$base = Join-Path $out 'kl_base_bundle_soa_f16_ub1.bin'
$common = @('-m', 'models\Ternary-Bonsai-2-27B-PTQ1_0.gguf', '-f', 'artifacts\eval\wiki.test.raw', '-c', '2048', '--chunks', '4',
            '-b', '1', '-ub', '1', '-ngl', '99', '-fa', 'on', '-ctk', 'f16', '-ctv', 'f16')
Remove-Item Env:GGML_CUDA_BATCH_INVARIANT -ErrorAction SilentlyContinue
& .\bin\llama-perplexity.exe @common --kl-divergence-base $base *>&1 | Out-File -Encoding utf8 "$out\base_bundle_soa.log"
& .\bin-turing\llama-perplexity.exe @common --kl-divergence --kl-divergence-base $base *>&1 | Out-File -Encoding utf8 "$out\new_pt.log"
$env:GGML_CUDA_BATCH_INVARIANT = '1'
& .\bin\llama-perplexity.exe @common --kl-divergence --kl-divergence-base $base *>&1 | Out-File -Encoding utf8 "$out\bundle_bi_pt.log"
Remove-Item Env:GGML_CUDA_BATCH_INVARIANT
foreach ($n in 'new_pt', 'bundle_bi_pt') {
    "== $n"
    Select-String -Path "$out\$n.log" -Pattern 'Mean PPL\(Q\) |Mean +KLD|Maximum KLD|Same top p' | ForEach-Object { $_.Line }
}
'p8c done'
