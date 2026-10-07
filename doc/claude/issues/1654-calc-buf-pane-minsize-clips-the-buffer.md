# 1654 — `.calc.pw.buf` carries a `-minsize` below what its contents need, so dragging that sash to its own legal floor clips the buffer at the shipped font

**STAMP:** `v1 claim=open tree=81dfbcf9 stamped=2026-10-07 fix=none open=1`

Status: **OPEN**, measured 2026-10-07 while building the Calculator's font-size control (spec
R114). Nothing to do with fonts: it is true at the shipped font, today, and was true before that
stage started. Filed rather than fixed because it is a different subject, and because changing a
pane floor moves literals that `tests/headless/test_calc_skeleton.tcl` row S4 reads.

Area: `calc::pane_floors` and `calc::apply_pane_minsize` in `src/calculator.tcl`; landmine D3.

## The defect

Landmine D3's contract is that a pane's `-minsize` is *"the smallest height (or width) at which
the contents are still usable"*, so that a drag cannot hide a region outright. `.calc.pw.buf`
ships a floor of **70** against a measured `reqheight` of **124** — the buffer pane holds the
four-line text widget plus the toolbar strip. Drag that sash down to its own legal floor and the
pane is given 70 px for contents asking for 124.

That is the same shape the comment above `calc::build_panes`' floors already records for the
keypad, and which `calc::apply_pane_minsize` was written to fix — but that proc's population is
deliberately the **two** panes item 4 filled (`.calc.pw.bot` and `.calc.pw.bot.pad`), so
`.calc.pw.buf` is not raised by anything.

## What makes it awkward, and why it is not fixed here

`calc::apply_pane_minsize` widening from two panes to six is the obvious fix and it moves **four**
frozen phase-0 literals that row S4 of `test_calc_skeleton` reads (`.calc.pw.buf` 70 → 124,
`.calc.pw.stk` 80 → 133, and two more). Phase-0 layout is otherwise frozen, so that is a decision
about the frozen numbers rather than a repair, and it wants its own stage.

⚠ Note what the fix is **not**: raising a `-minsize` on a live panedwindow does not re-allocate
the pane. It constrains a drag and the initial distribution. The clip a user sees at a larger font
comes from where the **sash** sits, which `calc::place_panes` owns (R114). So this issue is
specifically about the DRAG floor, and a reader who conflates the two will fix the wrong thing.

## Measured

Both figures read off a live `calc::build` on an Xvfb at 1920x1080 with openbox, at the shipped
font, through `winfo reqheight .calc.pw.buf` and `.calc.pw panecget .calc.pw.buf -minsize`.

## Fix sketch

Widen `calc::apply_pane_minsize`'s population to all six quadruples `calc::pane_floors` names —
the table already exists and the raise is already recomputed from the floor rather than from the
live value, so the ratchet hazard is already handled. Then re-derive S4's four literals and say in
the commit that the frozen phase-0 numbers were re-judged, with the measurement.
