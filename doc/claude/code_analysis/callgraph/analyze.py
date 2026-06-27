#!/usr/bin/env python3
"""
Function-level call-graph extractor for the xschem C sources.

Heuristic (no external deps): strip comments/strings, find top-level function
definitions by scanning for the brace that opens each body, then resolve
identifier-followed-by-'(' tokens inside each body against the set of known
function names. Produces:

  - functions.csv      every detected definition: name,file,line,static
  - edges_func.csv     caller -> callee at function granularity (cross-file flag)
  - file_matrix.txt    file x file call-count matrix + fan-in/out summary
  - hubs.txt           most-called functions and most-depended-on files
  - file_graph.dot     file-level dependency graph (graphviz)

Generated parsers (parselabel.c, expandlabel.c, eval_expr.c) are excluded:
their .c is flex/bison output, not human architecture.
"""
import os, re, sys, csv
from collections import defaultdict, Counter

SRC = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = sys.argv[2] if len(sys.argv) > 2 else "."
EXCLUDE = {"parselabel.c", "expandlabel.c", "eval_expr.c"}  # generated
KEYWORDS = {"if","for","while","switch","do","return","sizeof","else",
            "case","defined","void","int","char","double","float","long",
            "short","unsigned","signed","const","struct","union","enum",
            "static","typedef","goto"}

def strip(text):
    """Replace comment + string/char contents with spaces, preserve newlines."""
    out = []
    i, n = 0, len(text)
    state = None  # None, 'line', 'block', 'str', 'chr'
    while i < n:
        c = text[i]
        nxt = text[i+1] if i+1 < n else ''
        if state is None:
            if c == '/' and nxt == '/': state='line'; out.append('  '); i+=2; continue
            if c == '/' and nxt == '*': state='block'; out.append('  '); i+=2; continue
            if c == '"': state='str'; out.append(' '); i+=1; continue
            if c == "'": state='chr'; out.append(' '); i+=1; continue
            out.append(c); i+=1; continue
        if state == 'line':
            if c == '\n': state=None; out.append('\n')
            else: out.append(' ')
            i+=1; continue
        if state == 'block':
            if c == '*' and nxt == '/': state=None; out.append('  '); i+=2; continue
            out.append('\n' if c=='\n' else ' '); i+=1; continue
        if state == 'str':
            if c == '\\': out.append('  '); i+=2; continue
            if c == '"': state=None
            out.append(' '); i+=1; continue
        if state == 'chr':
            if c == '\\': out.append('  '); i+=2; continue
            if c == "'": state=None
            out.append(' '); i+=1; continue
    return ''.join(out)

IDENT_PAREN = re.compile(r'([A-Za-z_]\w*)\s*\(')

def line_of(text, pos):
    return text.count('\n', 0, pos) + 1

# A definition header starts at column 0 (function bodies are always indented in
# this codebase), so anchoring on ^ sidesteps brace-depth corruption from
# unbalanced #if-0 blocks. group(1)=return type+qualifiers, group(2)=name.
HEADER = re.compile(r'^([A-Za-z_]\w[\w \t\*]*?)\b([A-Za-z_]\w*)[ \t]*\(', re.M)

def _match_paren(s, i):
    """i is index of '('; return index of matching ')', or -1."""
    d = 0
    while i < len(s):
        if s[i] == '(': d += 1
        elif s[i] == ')':
            d -= 1
            if d == 0: return i
        i += 1
    return -1

def _match_brace(s, i):
    d = 0
    while i < len(s):
        if s[i] == '{': d += 1
        elif s[i] == '}':
            d -= 1
            if d == 0: return i
        i += 1
    return -1

def find_funcs(clean):
    """Return list of (name, body_start, body_end, is_static, line)."""
    funcs = []
    n = len(clean)
    accepted = []   # (start,end) bodies, to skip headers nested inside
    for m in HEADER.finditer(clean):
        name = m.group(2)
        if name in KEYWORDS:
            continue
        start = m.start()
        if any(a <= start <= b for a, b in accepted):
            continue
        paren = clean.find('(', m.end()-1)
        if paren < 0:
            continue
        close = _match_paren(clean, paren)
        if close < 0:
            continue
        # next non-space char after the arg list must be '{' for a definition
        j = close + 1
        while j < n and clean[j] in ' \t\r\n':
            j += 1
        if j >= n or clean[j] != '{':
            continue  # prototype / declaration / call, not a definition
        end = _match_brace(clean, j)
        if end < 0:
            continue
        is_static = 'static' in m.group(1).split()
        funcs.append((name, j, end, is_static, line_of(clean, start)))
        accepted.append((start, end))
    return funcs

# ---- pass 1: collect all definitions ----
files = sorted(f for f in os.listdir(SRC)
               if f.endswith('.c') and f not in EXCLUDE)
clean_cache = {}
file_funcs = {}           # file -> list of func dicts
defs_by_name = defaultdict(list)   # name -> [(file, is_static)]

for f in files:
    txt = open(os.path.join(SRC, f), encoding='utf-8', errors='replace').read()
    cl = strip(txt)
    clean_cache[f] = cl
    fl = []
    for name, sb, eb, st, ln in find_funcs(cl):
        fl.append({'name':name,'sb':sb,'eb':eb,'static':st,'line':ln})
        defs_by_name[name].append((f, st))
    file_funcs[f] = fl

def resolve(name, in_file):
    cand = defs_by_name.get(name)
    if not cand: return None
    # prefer a static def in the same file
    for fl, st in cand:
        if fl == in_file and st: return fl
    # else a non-static (global) def
    for fl, st in cand:
        if not st: return fl
    return cand[0][0]

# Ubiquitous leaf utilities: memory/string wrappers, debug, and the Tcl bridge.
# Calls to these say nothing about architecture (everyone uses them), so the
# "core" graph excludes them to reveal real module-to-module dependencies.
LEAF = {"dbg","strboolcmp","dtoa","my_itoa"}
def is_leaf(name):
    return name in LEAF or name.startswith("my_") or name.startswith("tcl")

# ---- pass 2: extract call edges ----
func_edges = Counter()    # (cf, cfunc, tf, tfunc) -> count
file_edges = Counter()    # (cf, tf) -> count  (cross-file only, all)
core_file_edges = Counter()  # cross-file, leaf utilities excluded
callee_count = Counter()  # name -> times called
for f in files:
    cl = clean_cache[f]
    for fn in file_funcs[f]:
        body = cl[fn['sb']:fn['eb']]
        for m in IDENT_PAREN.finditer(body):
            callee = m.group(1)
            if callee in KEYWORDS: continue
            if callee not in defs_by_name: continue
            tf = resolve(callee, f)
            if tf is None: continue
            func_edges[(f, fn['name'], tf, callee)] += 1
            callee_count[callee] += 1
            if tf != f:
                file_edges[(f, tf)] += 1
                if not is_leaf(callee):
                    core_file_edges[(f, tf)] += 1

# ---- write functions.csv ----
with open(os.path.join(OUT,'functions.csv'),'w',newline='') as fh:
    w = csv.writer(fh); w.writerow(['name','file','line','static'])
    for f in files:
        for fn in file_funcs[f]:
            w.writerow([fn['name'], f, fn['line'], int(fn['static'])])

# ---- write edges_func.csv ----
with open(os.path.join(OUT,'edges_func.csv'),'w',newline='') as fh:
    w = csv.writer(fh); w.writerow(['caller_file','caller','callee_file','callee','count','cross_file'])
    for (cf,cfn,tf,tfn),c in sorted(func_edges.items(), key=lambda x:-x[1]):
        w.writerow([cf,cfn,tf,tfn,c,int(cf!=tf)])

# ---- per-file metrics ----
total_funcs = sum(len(v) for v in file_funcs.values())
internal = Counter(); external_out = Counter(); external_in = Counter()
for (cf,cfn,tf,tfn),c in func_edges.items():
    if cf==tf: internal[cf]+=c
    else: external_out[cf]+=c; external_in[tf]+=c
fan_out = defaultdict(set); fan_in = defaultdict(set)
for (cf,tf),c in file_edges.items():
    fan_out[cf].add(tf); fan_in[tf].add(cf)

with open(os.path.join(OUT,'file_matrix.txt'),'w') as fh:
    fh.write("Per-file coupling summary (generated parsers excluded)\n")
    fh.write("="*92 + "\n")
    fh.write("%-22s %5s %7s %7s %7s %6s %6s %6s\n" % (
        "file","funcs","intCall","extOut","extIn","fanOut","fanIn","selfRatio"))
    fh.write("-"*92 + "\n")
    rows=[]
    for f in files:
        ic=internal[f]; eo=external_out[f]; ei=external_in[f]
        tot=ic+eo
        ratio = (ic/tot) if tot else 0.0
        rows.append((f,len(file_funcs[f]),ic,eo,ei,len(fan_out[f]),len(fan_in[f]),ratio))
    for r in sorted(rows, key=lambda x:-(x[3]+x[2])):
        fh.write("%-22s %5d %7d %7d %7d %6d %6d %7.2f\n" % r)
    fh.write("-"*92 + "\n")
    fh.write("selfRatio = internal calls / (internal+outgoing external). "
             "1.00 = fully self-contained.\n")
    fh.write("Totals: %d functions, %d call-edges (%d cross-file), %d file-pairs coupled.\n" % (
        total_funcs, sum(func_edges.values()), sum(file_edges.values()), len(file_edges)))

# ---- hubs.txt ----
with open(os.path.join(OUT,'hubs.txt'),'w') as fh:
    fh.write("MOST-CALLED FUNCTIONS (call sites; high = central utility / hub)\n")
    fh.write("-"*60+"\n")
    loc = {}
    for f in files:
        for fn in file_funcs[f]: loc[(fn['name'])]=f
    for name,c in callee_count.most_common(30):
        fh.write("%6d  %-28s [%s]\n" % (c, name, defs_by_name[name][0][0]))
    fh.write("\nMOST DEPENDED-ON FILES (distinct caller files = fan-in)\n")
    fh.write("-"*60+"\n")
    for f in sorted(files, key=lambda x:-len(fan_in[x]))[:15]:
        fh.write("%3d callers  %-22s (%d incoming calls)\n" % (
            len(fan_in[f]), f, external_in[f]))
    fh.write("\nMOST DEPENDENT FILES (distinct callee files = fan-out)\n")
    fh.write("-"*60+"\n")
    for f in sorted(files, key=lambda x:-len(fan_out[x]))[:15]:
        fh.write("%3d deps     %-22s (%d outgoing calls)\n" % (
            len(fan_out[f]), f, external_out[f]))

# ---- core coupling matrix (leaf utilities excluded) ----
core_out = Counter(); core_in = Counter()
core_fan_out = defaultdict(set); core_fan_in = defaultdict(set)
for (cf,tf),c in core_file_edges.items():
    core_out[cf]+=c; core_in[tf]+=c
    core_fan_out[cf].add(tf); core_fan_in[tf].add(cf)
with open(os.path.join(OUT,'core_coupling.txt'),'w') as fh:
    fh.write("CORE module coupling — leaf utilities (my_*, tcl*, dbg) excluded.\n")
    fh.write("This is the architecturally meaningful dependency structure.\n")
    fh.write("="*78 + "\n")
    fh.write("%-22s %7s %7s %7s %7s\n" % ("file","coreOut","coreIn","fanOut","fanIn"))
    fh.write("-"*78 + "\n")
    for f in sorted(files, key=lambda x:-(len(core_fan_in[x]))):
        if not (core_out[f] or core_in[f]): continue
        fh.write("%-22s %7d %7d %7d %7d\n" % (
            f, core_out[f], core_in[f], len(core_fan_out[f]), len(core_fan_in[f])))
    fh.write("-"*78 + "\n")
    fh.write("Total core cross-file calls: %d (vs %d incl. utilities — %.0f%% was util noise)\n" % (
        sum(core_file_edges.values()), sum(file_edges.values()),
        100*(1 - sum(core_file_edges.values())/max(1,sum(file_edges.values())))))

# ---- file_graph.dot (core edges only, thresholded) ----
THRESH = 8
with open(os.path.join(OUT,'file_graph.dot'),'w') as fh:
    fh.write('digraph xschem {\n  rankdir=LR;\n  node [shape=box,fontsize=10];\n')
    fh.write('  label="xschem core file dependencies (leaf utils excluded, >=%d calls)";\n' % THRESH)
    for (cf,tf),c in core_file_edges.items():
        if c >= THRESH:
            fh.write('  "%s" -> "%s" [label=%d,penwidth=%.1f];\n' % (
                cf, tf, c, min(6, 0.5+c/30.0)))
    fh.write('}\n')

print("functions:", total_funcs)
print("call-edges:", sum(func_edges.values()),
      "cross-file:", sum(file_edges.values()))
print("coupled file-pairs:", len(file_edges))
