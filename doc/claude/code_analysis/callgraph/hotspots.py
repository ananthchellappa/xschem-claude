#!/usr/bin/env python3
"""
Readability/maintainability hotspot scan: function length, max nesting depth,
and a crude branch count per function. Reuses the column-0 signature detection
from extract_util.py. Prints the worst offenders — the objective targets for
readability-focused refactoring.
"""
import os, re, sys
SRC = sys.argv[1] if len(sys.argv) > 1 else "."
EXCLUDE = {"parselabel.c","expandlabel.c","eval_expr.c"}  # generated
KW = {"if","for","while","switch","do","return","sizeof","else"}

def strip(t):
    out=[];i=0;n=len(t);st=None
    while i<n:
        c=t[i];nx=t[i+1] if i+1<n else ''
        if st is None:
            if c=='/'and nx=='/':st='line';out.append('  ');i+=2;continue
            if c=='/'and nx=='*':st='blk';out.append('  ');i+=2;continue
            if c=='"':st='str';out.append(' ');i+=1;continue
            if c=="'":st='chr';out.append(' ');i+=1;continue
            out.append(c);i+=1;continue
        if st=='line':
            out.append('\n' if c=='\n' else ' ');st=None if c=='\n' else st;i+=1;continue
        if st=='blk':
            if c=='*'and nx=='/':st=None;out.append('  ');i+=2;continue
            out.append('\n' if c=='\n' else ' ');i+=1;continue
        if st=='str':
            if c=='\\':out.append('  ');i+=2;continue
            if c=='"':st=None
            out.append(' ');i+=1;continue
        if st=='chr':
            if c=='\\':out.append('  ');i+=2;continue
            if c=="'":st=None
            out.append(' ');i+=1;continue
    return ''.join(out)

HDR=re.compile(r'(?m)^([A-Za-z_]\w[\w \t\*]*?)\b([A-Za-z_]\w*)[ \t]*\(')
def mbrace(s,i):
    d=0
    while i<len(s):
        if s[i]=='{':d+=1
        elif s[i]=='}':
            d-=1
            if d==0:return i
        i+=1
    return -1

rows=[]
file_lines={}
for f in sorted(os.listdir(SRC)):
    if not f.endswith('.c') or f in EXCLUDE: continue
    t=open(os.path.join(SRC,f),encoding='utf-8',errors='replace').read()
    file_lines[f]=t.count('\n')+1
    cl=strip(t)
    for m in HDR.finditer(cl):
        if m.group(2) in KW: continue
        p=cl.find('(',m.end()-1)
        if p<0:continue
        d=0;q=p
        while q<len(cl):
            if cl[q]=='(':d+=1
            elif cl[q]==')':
                d-=1
                if d==0:break
            q+=1
        j=q+1
        while j<len(cl) and cl[j] in ' \t\r\n':j+=1
        if j>=len(cl) or cl[j]!='{':continue
        e=mbrace(cl,j)
        if e<0:continue
        body=cl[j:e+1]
        lines=body.count('\n')+1
        # max nesting depth and branch count
        depth=mx=0;branches=0
        for ch in body:
            if ch=='{':depth+=1;mx=max(mx,depth)
            elif ch=='}':depth-=1
        branches=len(re.findall(r'\b(if|else if|case)\b',body))
        rows.append((lines,mx,branches,m.group(2),f))

rows.sort(reverse=True)
print("=== 25 LONGEST FUNCTIONS (lines, maxNest, branches) ===")
print(f"{'lines':>5} {'nest':>4} {'br':>4}  function / file")
for lines,mx,br,name,f in rows[:25]:
    print(f"{lines:>5} {mx:>4} {br:>4}  {name}  [{f}]")

print(f"\n=== functions over 200 lines: {sum(1 for r in rows if r[0]>200)} "
      f"| over 100: {sum(1 for r in rows if r[0]>100)} | total: {len(rows)} ===")
print(f"=== deepest nesting (top 8) ===")
for lines,mx,br,name,f in sorted(rows,reverse=True,key=lambda r:r[1])[:8]:
    print(f"  nest={mx}  {name} [{f}] ({lines} lines)")
print(f"\n=== largest files (lines) ===")
for f,l in sorted(file_lines.items(),key=lambda x:-x[1])[:10]:
    print(f"  {l:>5}  {f}")
