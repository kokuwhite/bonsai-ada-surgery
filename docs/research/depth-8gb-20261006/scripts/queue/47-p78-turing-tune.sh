#!/usr/bin/env bash
cd /c/bonsai/8gb; R=receipts/p78; mkdir -p $R
until grep -q "tune2 exit 0" receipts/build_ahead.log; do grep -q "tune2 exit [1-9]" receipts/build_ahead.log && { echo "build failed" > $R/summary.txt; exit 1; }; sleep 60; done
rm -rf /c/bonsai/bonsai-ada-surgery/bin-tune && cp -r /c/bonsai/bonsai-ada-surgery/tooling/build-tune/bin /c/bonsai/bonsai-ada-surgery/bin-tune
for f in /c/bonsai/bonsai-ada-surgery/bin-8gbfix/*.dll; do b=$(basename $f); [ -f /c/bonsai/bonsai-ada-surgery/bin-tune/$b ] || cp $f /c/bonsai/bonsai-ada-surgery/bin-tune/; done
powershell -NoProfile -ExecutionPolicy Bypass -File stop.ps1 >/dev/null 2>&1
T=/c/bonsai/bonsai-ada-surgery/bin-tune/test-backend-ops.exe
for rm in 4x4 4x2 4x6 4x8 2x2 2x4 2x6 2x8 8x2 8x4 8x6 8x8; do
  for n in 1 2; do
    GGML_PTQ1_PT_TUNE=$rm $T perf -o MUL_MAT -b CUDA0 -p "type_a=ptq1_0,type_b=f32,m=[0-9]+,n=$n,k=[0-9]+,bs=" > $R/raw_${rm}_n$n.txt 2>&1
  done
done
python - > $R/perf.txt <<'PY0'
import glob, re, os
for f in sorted(glob.glob('receipts/p78/raw_*.txt')):
    rm, n = re.match(r'raw_(\w+)_n(\d)', os.path.basename(f)).groups()
    name = None
    for line in open(f, errors='ignore'):
        m = re.search(r'MUL_MAT\(type_a=ptq1_0,type_b=f32,m=(\d+),n=(\d+),k=(\d+),bs=\[1,1\]', line)
        if m: name = (m.group(1), m.group(3))
        t = re.search(r'([0-9.]+) us/run', line)
        if t and name:
            print(rm, 'n'+n, name[0], name[1], t.group(1)); name = None
PY0
python - > $R/weighted.txt <<'PY'
import collections
w={(17408,5120):128,(5120,17408):64,(10240,5120):48,(6144,5120):48,(5120,6144):48,(12288,5120):16}
best=collections.defaultdict(dict)
for line in open('receipts/p78/perf.txt'):
    p=line.split()
    if len(p)!=5: continue
    rm,n,m,k,us=p[0],p[1],int(p[2]),int(p[3]),float(p[4])
    if (m,k) in w: best[(rm,n)][(m,k)]=us
for n in ('n1','n2'):
    base=sum(best[('4x4',n)].get(s,0)*c for s,c in w.items())
    rows=[]
    for (rm,nn),d in best.items():
        if nn!=n or len(d)<len(w): continue
        tot=sum(d[s]*c for s,c in w.items()); rows.append((tot,rm))
    for tot,rm in sorted(rows): print(n, rm, round(tot/1000,3),'ms/token', f"{(base/tot-1)*100:+.1f}% vs 4x4")
PY
B='C:\bonsai\bonsai-ada-surgery\bin-tune\llama-server.exe'; M='C:/bonsai/bonsai-ada-surgery/models/Ternary-Bonsai-2-27B-PTQ1_0.gguf'
COM="-m $M -c 8192 -ngl 99 -fa on -np 1 -ctk q4_0 -ctv q4_0 --host 127.0.0.1 --port 8899"
for r in 1 2; do for g in 0 1; do bash run_arm.sh $R graphopt${g}_r$r "GGML_CUDA_GRAPH_OPT=$g" "raw:$B $COM" "4000"; done; done
grep -H "mean decode" $R/graphopt*.txt | sed "s#$R/##" > $R/graphopt.txt
