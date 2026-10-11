#!/usr/bin/env bash
# Build bin-alpha after P8c finishes (CPU-heavy; keeps it off the soak and the KL runs). Do not edit while running.
until grep -q "p8c done" /c/bonsai/8gb/receipts/p8c-run.txt 2>/dev/null; do sleep 30; done
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Location C:\bonsai\bonsai-ada-surgery; & .\build\build_windows.ps1 -Arch 75 -Src 'C:\bonsai\bonsai-ada-surgery\vendor\prism-alpha' -Build 'C:\bonsai\bonsai-ada-surgery\tooling\build-alpha' -Out 'C:\bonsai\bonsai-ada-surgery\bin-alpha'" > /c/bonsai/8gb/logs/build-alpha.log 2>&1
echo "build-alpha exit $?" >> /c/bonsai/8gb/logs/build-alpha.log
ls /c/bonsai/bonsai-ada-surgery/bin-alpha >> /c/bonsai/8gb/logs/build-alpha.log 2>&1
