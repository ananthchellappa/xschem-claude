# 0468 — the `Live annotate probes with 'b' cursor` menu checkbutton has no `-command`, so toggling it changes nothing on screen

Status: **OPEN, source-verified, NOT fixed.** ⚠ **ITS PREMISE INVERTED ON
2026-08-27 (issue 0864) — IT DID NOT GO MOOT, IT GOT WORSE.** See the section at
the bottom before reading the rest, which describes the pre-0864 tree.
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

## ⚠ THE PREMISE INVERTED — issue 0864, 2026-08-27

Everything above describes a tree in which `live_cursor2_backannotate` was the
FIRST gate of `op_annot::_annotated` and the first term of all six `token.c`
sites. **0864 removed it from every one of them.** The switch means only "follow
cursor B and re-annotate as it moves", and it now **ships OFF**.

So the two claims above no longer hold as written:

* *"flipping it changes what every annotated text would render"* — it does not.
  Rows **S16**, **O29** and **D3** now assert the opposite: clicking the entry
  changes not one painted character. The 14th epoch term this issue cites was
  removed with it (row **O29b**).
* *"once a redraw DOES happen the block is correct"* — there is nothing for the
  redraw to correct in the operating-point block.

**What is left is sharper, not smaller.** The missing `-command` used to be a
papercut on a default-on switch that most users never touched. It is now the
first thing an opting-in user meets: they tick the box precisely because they
want the schematic to follow cursor B, and **nothing happens until they next move
the cursor.** 0864 considered fixing it and deliberately deferred: it fixes
neither defect 0864 measured and widens the blast radius into the menu's command
path. The fix is a one-line `-command` plus a Tk row in
`tests/headless/test_annot_show_menu.tcl` — where section D already owns the
widget — and row **D3** must be read first, because it asserts the entry as
SHIPPED (no `-command`) on purpose.
