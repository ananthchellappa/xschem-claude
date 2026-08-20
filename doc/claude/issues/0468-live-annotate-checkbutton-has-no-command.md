# 0468 — the `Live annotate probes with 'b' cursor` menu checkbutton has no `-command`, so toggling it changes nothing on screen

Status: **OPEN, source-verified, NOT fixed.**
Filed by the S9b crew (op-annotation, branch `annotate`).

`src/xschem.tcl:15360` (Simulation > Graphs) is a checkbutton on the global
`live_cursor2_backannotate` with **no `-command`**. The variable is the FIRST gate
in `op_annot::_annotated` (`src/op_annot.tcl:561`) and is read by six C sites
(`token.c:4318/4824/4915/5002/5097/5170`), so flipping it changes what every
annotated text would render — and nothing redraws. The screen keeps showing the
previous state until an unrelated redraw happens.

Promised as "filed separately" by row **O29** of `tests/headless/test_op_annot.tcl`.
That row deliberately drives the variable directly rather than the widget, so it
holds whether or not this is ever fixed.

Related: S9b makes `live_cursor2_backannotate` the **14th term** of the draw-time
overlay's cache epoch (decision D6, ladder rung L2 — a Tcl `trace add variable`
bumping `::op_annot::gen` was rejected, because it installs a trace on a shipped
global that C also writes at `scheduler.c:2409`, and a trace body that errors
makes the variable **write** fail). So once a redraw DOES happen the block is
correct. **This issue is the missing redraw, not the stale cache.**

## Confirmed after S9b (2026-08-20)

Row **O29** is green, and sabotage variant `live_gate_epoch_off` (the term forced
to a constant 0) reds **exactly O29** — with element 2 rendering a stale
`{ZZOA = 10u}` while element 4 (`op_annot::text`'s own answer) is correctly
blank. So the variable's effect on the rendered block is proven end to end; what
is still missing is a `-command` that redraws when the user clicks the menu item.

⚠ The S9b Measure agent could NOT isolate the toggle headless (`B5 P3`): with no
raw loaded, `op_annot::_annotated`'s `xschem raw loaded` guard
(`op_annot.tcl:564`) already returns 0 and dominates the gate. Row O29 publishes
a raw first, which is why it can see the toggle at all.

Still open.
