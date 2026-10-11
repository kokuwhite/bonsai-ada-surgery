# One sample: llama-server shared and dedicated GPU memory (MiB) and card free VRAM.
$p = (Get-Process llama-server -ErrorAction SilentlyContinue | Select-Object -First 1).Id
$t = Get-Date -Format HH:mm:ss
$free = (& nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits).Trim()
if ($p) {
    $c = (Get-Counter "\GPU Process Memory(pid_${p}*)\Shared Usage", "\GPU Process Memory(pid_${p}*)\Dedicated Usage").CounterSamples
    '{0} shared {1:F0} dedicated {2:F0} free {3}' -f $t, ($c[0].CookedValue / 1MB), ($c[1].CookedValue / 1MB), $free
} else {
    '{0} no-server free {1}' -f $t, $free
}
