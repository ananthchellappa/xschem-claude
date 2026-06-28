# Function-level call graph

Reproducible who-calls-whom analysis of the xschem C sources.

## Regenerate

```sh
python3 analyze.py ../../src .
# optional, if graphviz is installed:
dot -Tsvg file_graph_backbone.dot -o file_graph_backbone.svg
```

## How it works

Pure-Python heuristic (no cflow/ctags needed): strips comments/strings, detects
top-level function definitions by **column-0 signature anchoring** (function
bodies are always indented in this codebase, which avoids brace-miscounting on
`#if 0` dead-code blocks), then resolves `identifier(` tokens in each body
against the known function set. Static defs resolve same-file; others to the
global definition. Generated parsers (`parselabel/expandlabel/eval_expr.c`) are
excluded.

## Outputs

| File | Contents |
|---|---|
| `functions.csv` | every detected definition: `name,file,line,static` (754) |
| `edges_func.csv` | function-level edges: `caller,callee,count,cross_file` (12,046) |
| `file_matrix.txt` | per-file coupling **including** leaf utilities |
| `core_coupling.txt` | per-file coupling **excluding** leaf utilities (the meaningful view) |
| `hubs.txt` | most-called functions; most depended-on / most dependent files |
| `file_graph.{dot,png,svg}` | full core graph, edges ≥8 calls (dense) |
| `file_graph_backbone.{dot,png,svg}` | backbone, edges ≥30 calls (legible) |
| `layered.py` | SCC-condense + topological layering (`python3 layered.py . 30`) |
| `layers.txt` | tier assignment + the mutually-recursive cycle list |
| `file_graph_layered.{dot,png,svg}` | layered architecture diagram, drivers→spine |

## Headline results

- **60% of cross-file calls are leaf-utility noise** (`my_*`, `tcl*`, `dbg`).
  Strip them and real coupling drops 10,053 → 4,044 calls.
- **`token.c` is the true spine** (969 core incoming): every module reads
  symbol/instance properties through it — not `editprop.c` (which only looked
  central because the allocator lives there) nor the drawing code.
- **`scheduler.c` + `callback.c` are pure drivers** (high fan-out, ~zero fan-in):
  correctly positioned as entry points at the top of the call tree.
- **Netlist backends are independent** of each other and delegate to `netlist.c`.
- **The core is one big cycle of thin edges, not a strict hierarchy.** At ≥5
  calls, 17 files form a single strongly-connected component; raising the floor
  peels it apart (17→14→12→9→8→4→0 by ≥50 calls). Only two cycles are
  structural: `spice_netlist ↔ token` (to ≥40) and the editing quartet
  `{actions, draw, save, select}` (≥30). `token.c` is the floor everything
  bottoms out at. See `file_graph_layered.png`.

See `../dependency_graph_analysis.txt` for the full write-up.

**Caveat:** heuristic, not a compiler front end. Function-pointer dispatch (e.g.
`xctx->push_undo()`) and macro-generated calls are not resolved, so dynamic
dispatch is under-counted. Directionally accurate, not exact.
