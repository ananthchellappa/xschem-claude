# 1302 — the RDW pick mode has no on-canvas indicator; ASE Direct Plot has one

**Status: FILED, NOT FIXED.** Found by item **B4**. Carries a `look` debt.

> **⚠ ITEM B4 WAS REVERTED (status F, 2026-09-04)**, so the pick mode described
> here is not in the tree — it is in
> `doc/claude/op_param_batch/B4_working_tree_REVERTED.patch`. The finding
> stands for whoever applies that patch, and issue **1304** makes it sharper:
> a mode with no on-canvas indicator that *also* lets a drifted click change
> the selection is a mode the user cannot tell they are in.

## What was measured

`ase::ui::select_on_design` (`src/ase_window.tcl:1877`) puts a prompt on the
schematic window's own bottom status line and keeps it there with
`sod_prompt_pump`, because **the C engine blanks `.statusbar.10` on every
event** — a one-shot write disappears immediately. That pump, and
`sod_prompt_set` / `sod_prompt_clear`, live in `src/ase_window.tcl`, which item
B4's Files cell does not include.

So item B4's verb-noun pick mode announces itself with **one CIW line at entry
and nothing after that**. A user who looks away has no way to tell from the
canvas that the next click will dump a device rather than select one — which is
exactly the state the user's own requirement ("clicking will not change selected
set") makes surprising.

## Options

* **(a) recommended** — lift the three prompt procs out of `ase_window.tcl` into
  a small shared helper (they know nothing about ASE) and have both modes use
  it. One pump, one place the blanking workaround lives.
* (b) duplicate the pump inside `src/rdw.tcl`. Cheap, and a second copy of a
  workaround for a C behaviour is the drift shape invariant I1 is about.
* (c) leave the CIW line as the only signal.

## Why B4 did not take it

`src/ase_window.tcl` is outside B4's Files cell, and (b) is the option this
batch has been punished for three times.

## The eyeball

Recorded as a `look` debt: a green suite cannot tell whether one CIW line is
enough of a mode indicator. Keys and clicks are the most eyeball-shaped thing
in this batch.
