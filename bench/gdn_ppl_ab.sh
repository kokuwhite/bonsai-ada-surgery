#!/usr/bin/env bash
# Chunked gated-delta-net prefill (MMA) vs the recurrent kernel on the same binary: perplexity on wikitext-2 (no KL
# base file, so RAM stays at one chunk of logits, ~2 GB at -c 2048). Every chunk is prefilled in 512-token micro-batches,
# so the MMA path runs on every GDN layer. Gate: the two estimates agree within ~0.1 % and the chunks track.
#   bash bench/gdn_ppl_ab.sh <root with llama-perplexity>   -> receipts/gdn_ppl_ab.log
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd -W)"; ROOT="$(cygpath -u "${1:?root}")"; LOG=receipts/gdn_ppl_ab.log
MODEL="$REPO\\models\\Ternary-Bonsai-2-27B-PTQ1_0-mtp-procreations.gguf"; TEXT="$REPO\\artifacts\\eval\\wiki.test.raw"
CTX=${CTX:-2048}; CHUNKS=${CHUNKS:-32}
say() { echo "$(date '+%H:%M') $*" | tee -a "$LOG"; }
rm -f logs/ramguard.stop
powershell -NoProfile -ExecutionPolicy Bypass -File tools/ramguard.ps1 -Names llama-perplexity -StopFile logs/ramguard.stop &
GUARD=$!
trap 'touch logs/ramguard.stop; wait $GUARD 2>/dev/null' EXIT
say "=== GDN perplexity A/B: root $ROOT, -c $CTX, $CHUNKS chunks"
for A in "recurrent|GGML_CUDA_GDN_MMA_DISABLE=1" "mma|"; do
  NAME=${A%%|*}; ENVS=${A#*|}
  env $ENVS "$ROOT/bin/llama-perplexity.exe" -m "$MODEL" -f "$TEXT" -c $CTX --chunks $CHUNKS -b 2048 -ub 512 \
      -ngl 99 -fa on -ctk q8_0 -ctv q8_0 > "logs/gdnppl_$NAME.log" 2>&1
  say "$NAME: $(grep -o 'Final estimate: PPL = [0-9.]* +/- [0-9.]*' logs/gdnppl_$NAME.log); engaged lines $(grep -c 'chunked GDN prefill (MMA) engaged' logs/gdnppl_$NAME.log)"
  grep -o '\[[0-9]*\][0-9.]*' "logs/gdnppl_$NAME.log" | tr '\n' ' ' | sed "s/^/$NAME chunks: /" | tee -a "$LOG"; echo | tee -a "$LOG"
done
say "=== done"
