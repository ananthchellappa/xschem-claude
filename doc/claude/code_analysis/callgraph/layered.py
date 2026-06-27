#!/usr/bin/env python3
"""
Build a LAYERED architecture diagram from edges_func.csv.

Call graphs have cycles (mutual recursion between modules), so a plain
topological sort is impossible. Standard fix: condense each strongly-connected
component (SCC) to a single node, which yields a DAG, then assign layers by
longest-path from the sources. Drivers land at the top, leaf services at the
bottom; intra-cycle "back" edges are drawn dashed so the hierarchy stays
readable.
"""
import csv, sys
from collections import defaultdict

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
# Edge-weight floor. At >=5 the core is one 17-file SCC (thin back-edges); at
# >=30 only the {actions,draw,save,select} editing cycle remains, exposing the
# dominant-flow hierarchy. Default to 30 for the legible architecture diagram.
MINW = int(sys.argv[2]) if len(sys.argv) > 2 else 30

LEAF = lambda n: (n in {"dbg","strboolcmp","dtoa","my_itoa"}
                  or n.startswith("my_") or n.startswith("tcl"))

# ---- build core file-level graph ----
w = defaultdict(int)
nodes = set()
for r in csv.DictReader(open(f"{OUT}/edges_func.csv")):
    if r["cross_file"] != "1": continue
    if LEAF(r["callee"]): continue
    a, b = r["caller_file"], r["callee_file"]
    w[(a, b)] += int(r["count"])
    nodes.add(a); nodes.add(b)

edges = {e: c for e, c in w.items() if c >= MINW}
# keep only nodes that participate in a surviving edge (drop isolated leaves)
nodes = {x for e in edges for x in e}
adj = defaultdict(set)
for (a, b) in edges:
    adj[a].add(b)

# ---- Tarjan SCC ----
idx = {}; low = {}; onstk = {}; stk = []; counter = [0]; sccs = []
import sys as _s; _s.setrecursionlimit(10000)
def strong(v):
    idx[v] = low[v] = counter[0]; counter[0]+=1
    stk.append(v); onstk[v]=True
    for w_ in adj[v]:
        if w_ not in idx:
            strong(w_); low[v]=min(low[v],low[w_])
        elif onstk.get(w_):
            low[v]=min(low[v],idx[w_])
    if low[v]==idx[v]:
        comp=[]
        while True:
            x=stk.pop(); onstk[x]=False; comp.append(x)
            if x==v: break
        sccs.append(comp)
for v in list(nodes):
    if v not in idx: strong(v)

scc_of = {}
for i, comp in enumerate(sccs):
    for v in comp: scc_of[v] = i

# ---- condense to DAG, longest-path layering ----
dag = defaultdict(set)
indeg = defaultdict(int)
for (a, b) in edges:
    ca, cb = scc_of[a], scc_of[b]
    if ca != cb and cb not in dag[ca]:
        dag[ca].add(cb); indeg[cb]+=1

layer = {i: 0 for i in range(len(sccs))}
# Kahn topo order, layer = max(layer[pred])+1
from collections import deque
q = deque(i for i in range(len(sccs)) if indeg[i]==0)
order = []
ind = dict(indeg)
while q:
    u = q.popleft(); order.append(u)
    for v in dag[u]:
        layer[v] = max(layer[v], layer[u]+1)
        ind[v]-=1
        if ind[v]==0: q.append(v)

# ---- group files by layer ----
by_layer = defaultdict(list)
for i, comp in enumerate(sccs):
    by_layer[layer[i]].append((i, comp))
maxL = max(layer.values()) if layer else 0

LAYER_NAME = {
    0:"entry / drivers", 1:"high-level ops", 2:"mid services",
    3:"core services", 4:"data & parsing", 5:"leaves",
}

# ---- emit DOT ----
with open(f"{OUT}/file_graph_layered.dot","w") as f:
    f.write('digraph layered {\n')
    f.write('  rankdir=TB; ranksep=0.9; nodesep=0.3;\n')
    f.write('  node [shape=box,style=filled,fillcolor=lightyellow,fontsize=11];\n')
    f.write('  edge [color=gray40];\n')
    f.write('  labelloc=t; fontsize=14;\n')
    f.write('  label="xschem core architecture — layered by SCC-condensed call graph\\n'
            '(leaf utils excluded, edges >=%d calls; dashed red = cycle/back-edge)";\n' % MINW)
    # rank groups
    for L in range(maxL+1):
        f.write(f'  {{ rank=same; ')
        for i, comp in by_layer[L]:
            for v in comp:
                f.write(f'"{v}"; ')
        f.write('}\n')
    # invisible layer-label spine
    for L in range(maxL+1):
        nm = LAYER_NAME.get(L, f"layer {L}")
        f.write(f'  "L{L}" [label="{L}: {nm}",shape=plaintext,fillcolor=none,fontcolor=blue];\n')
    f.write('  ' + ' -> '.join(f'"L{L}"' for L in range(maxL+1)) + ' [style=invis];\n')
    # SCC clusters (cycles) get a box
    for i, comp in enumerate(sccs):
        if len(comp) > 1:
            f.write(f'  subgraph cluster_scc{i} {{ style=dashed; color=red; '
                    f'label="cycle";\n    ')
            for v in comp: f.write(f'"{v}"; ')
            f.write('}\n')
    # edges
    for (a, b), c in edges.items():
        up = layer[scc_of[a]] >= layer[scc_of[b]] and scc_of[a]!=scc_of[b]
        same = scc_of[a]==scc_of[b]
        attrs = f'label={c},penwidth={min(5,0.6+c/40):.1f}'
        if up or same:
            attrs += ',color=red,style=dashed,constraint=false'
        f.write(f'  "{a}" -> "{b}" [{attrs}];\n')
    f.write('}\n')

# ---- text summary ----
with open(f"{OUT}/layers.txt","w") as f:
    f.write("LAYERED ARCHITECTURE (SCC-condensed core call graph, edges >=%d)\n" % MINW)
    f.write("="*70+"\n")
    for L in range(maxL+1):
        nm = LAYER_NAME.get(L, f"layer {L}")
        files = sorted(v for _,comp in by_layer[L] for v in comp)
        f.write(f"\nLayer {L} — {nm}\n  " + ", ".join(files) + "\n")
    cyc = [comp for comp in sccs if len(comp)>1]
    f.write("\nCycles (mutually-recursive file groups):\n")
    if cyc:
        for comp in cyc: f.write("  { " + ", ".join(sorted(comp)) + " }\n")
    else:
        f.write("  none — the core file graph is a DAG.\n")

print("layers:", maxL+1, "| nodes:", len(nodes),
      "| cycles:", sum(1 for c in sccs if len(c)>1))
