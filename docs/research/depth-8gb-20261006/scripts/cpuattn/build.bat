@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d C:\bonsai\8gb\cpuattn
cl /nologo /O2 /arch:AVX2 /EHsc /std:c++17 cpuattn_bench.cpp /Fe:cpuattn_bench.exe
