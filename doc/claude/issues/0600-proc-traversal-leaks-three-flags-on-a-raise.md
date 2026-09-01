# 0600 - `proc traversal` (core xschem.tcl) leaks keep_symbols / no_draw / no_undo on a raise

STATUS: FIXED (2026-08-22) - `proc traversal` split into a wrapper + `traversal_body`
(`src/xschem.tcl:3590-3613` wrapper, `:3614` body). The wrapper captures `keep_symbols`
and `currsch` before the body runs, restores `keep_symbols` / `no_draw` / `no_undo` and
unwinds the hierarchy level unconditionally, and re-raises the body's error with its
original errorInfo via `return -options`. Guardian:
`tests/headless/test_traversal_flag_leak.tcl` (11 checks; 3 FAILED / 8 passed with the
fix reverted, ALL PASS with it in). Tcl only - no C change.

(All line numbers below are PRE-FIX.) `src/xschem.tcl:3572-3576` sets `keep_symbols`,
`no_draw` and `no_undo` around its hierarchy
walk and restores them at `:3596-3598` **on the normal path only** - no `catch`, no `finally`.
Any error raised between those points leaks all three for the rest of the session.

This is the same shape as issue 0431, but 0431's text covers only the two PDK add-ons
(`sky130A/sky130_procs.tcl:99-108`, `ihp-sg13g2/sg13g2_procs.tcl:351-361`). This one is in
**core** `xschem.tcl`, so it ships to every user with no PDK installed.

Why it matters after X0498: X0498 made a leaked `no_undo` unable to corrupt or crash the
netlisters (the undo shield, `src/netlist.c`), so this leak is no longer a data-loss defect -
but it still leaves `no_draw=1` (a dead screen) and `keep_symbols=1` behind, and violates
spec `doc/claude/specs/op_annotation.md` section 5 invariant I6.

No menu wiring for `traversal` was found on this tree; it is reachable by name from any rc or
script.

## Measured

`src/xschem.tcl:3572-3576` sets the three flags; `:3596-3598` restores them. There is no
`catch` and no `finally` between those points, so the restore is reachable only when the body
completes normally. Read and confirmed twice during X0498 (Scout and Measure agents,
independently).

No menu wiring for `traversal` was found on this tree, which is why this is filed rather than
fixed: the reachable-from-a-click argument that made 0431 urgent does not apply here. It is
still shipped core Tcl and still violates I6.

## Fix direction

`catch {…} err`, restore all three flags **and** the entry hierarchy level unconditionally,
then re-raise. `xschem get no_undo` does not exist (setter only, `scheduler.c:12030`), so
`no_undo` can only be restored to `0` — which is the pre-existing issue **0432** residual, not
something this fix can close.

Taken as written. Note `xschem get no_draw` DOES exist (`src/scheduler.c:4926`), which is what
lets the guardian assert that flag directly; only `no_undo` lacks a getter, so it is witnessed
behaviourally instead (`push_undo` returns at `src/save.c:4713` and `pop_undo` at `:4795` when
`xctx->no_undo` is set, so a leaked `no_undo` makes `xschem undo` a silent no-op).

The raise the guardian uses needs no error injection: `toplevel .trav` raises
`window name "trav" already exists in parent` on a second call, because `.trav` is destroyed
only by its `<Escape>` binding, by the `Upd` button, or by the WM.

## Still open

Whether the same shape exists in the other core-Tcl walks. Only `proc traversal` was audited.
