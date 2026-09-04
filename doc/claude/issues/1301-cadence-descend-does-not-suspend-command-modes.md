# 1301 — the cadence profile's own descend never suspends a canvas command mode

**Status: FILED, NOT FIXED.** ⚠ **PREDATES item B4 and SURVIVES its revert** —
`cadence::descend_into_inst` and ASE Direct Plot are both in the tree at
`735ea26e`. Only the pinning row (`D2` of the reverted
`tests/headless/test_rdw_keys_1245.tcl`) went away with the revert, so this is
now measured and **unfenced**. Measured by item **B4**; pinned by row **D2** of
`tests/headless/test_rdw_keys_1245.tcl`, which asserts today's behaviour so the
fix reds it rather than passing in silence.

## What was measured

`cmdmode::suspend_all` / `resume_all` (`src/cmdmode.tcl`, issue 0201) are called
from exactly two places: `hi_descend_do` (`src/xschem.tcl:7585`) and
`hi_descend_pick_arm` (`:7707`).

`cadence::descend_into_inst` (`utils/cadence_nav.tcl:260`), bound to **Ctrl-x**
at `src/cadence_style_rc:202`, calls `xschem descend -fallback` **directly** and
never suspends. So does `cadence::descend_into_inst_new_window`
(Ctrl-Shift-X).

Driven on the B4 fixture with the RDW pick mode live:

    xschem select instance X1
    cadence::descend_into_inst
    ->  currsch          1        (the descend happened)
        suspend arm hits 0        (cmdmode was never told)
        is_suspended     0
        seized           1        (the mode is still holding the canvas)

## Why it matters

1. `cmdmode::register` buys a mode the **E-key** descend and *not* the chord the
   cadence user actually presses. The same gap affects **ASE Direct Plot**
   (Ctrl-4) identically today — this is not new with B4, it is newly *visible*.
2. With **Ctrl-Shift-X** it is worse than a no-op: `clone_canvas_bindings`
   (`src/xschem.tcl:15889`) copies `.drw`'s bindings verbatim onto the new
   canvas, so a still-seized mode is cloned onto the child with the parent's
   substituted script. `src/cmdmode.tcl:44-50` records that ordering — every
   suspend site must run BEFORE `schematic_in_new_window` — as the reason the
   contract exists at all.

## Options

* **(a) recommended** — make the two `cadence::descend_into_inst*` procs wrap
  their `xschem descend` in `cmdmode::suspend_all` / `resume_all`, the way
  `hi_descend_do` does (wrapper + `_body`, so the resume is a finally and covers
  every failure path).
* (b) push the suspend down into the `xschem descend` dispatcher branch, which
  would cover every caller at once — larger blast radius, and it puts a Tcl
  contract inside a C-dispatched verb that scripts call for other reasons.
* (c) leave it, and document that command modes survive a Ctrl-x descend.
  Defensible only if that is what the user wants; nobody has asked.

## Not fixed here because

`utils/cadence_nav.tcl` is outside item B4's Files cell
(`doc/claude/op_param_batch/PLAN.md`, B4), and the defect predates B4 by the
whole life of ASE Direct Plot.

## ✅ RE-FENCED in item **B4-3**, 2026-09-04 — still not fixed, but no longer silent

The revert of B4-2 took the fence with it. It is back in the tree:

> `ok:   D2 MEASURED GAP PINNED (issue 1301): the cadence profile's own Ctrl-x
> descend never calls cmdmode::suspend_all, so the mode stays seized straight
> across it`

Row **`D2`** of `tests/headless/test_rdw_keys_1245.tcl` (`:99` arm), which pins
today's behaviour — `currsch > 0`, `cmdmode::suspend_all` hits **0**,
`cmdmode::is_suspended` **0**, `seized` **1**. It is a *pin*, not a fix: whoever
takes option (a) or (b) above will red this row, which is exactly what it is for.

No code changed for this; the row arrived with the B4-2 patch B4-3 re-applied.
