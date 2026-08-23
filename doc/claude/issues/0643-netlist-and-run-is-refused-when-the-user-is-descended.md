# 0643 — Netlist and Run is REFUSED (Status: Error, no run) when the user is descended into the design

STATUS: **OPEN — measured 2026-08-23 by the 0616 crew.** Deliberately not fixed
in 0616 (rung L2 plus a named hazard, see below). **This is now the largest
remaining defect on the Netlist-and-Run button**, and it sits exactly where the
OP-annotation workflow puts the user.

## What happens

Descend one level into the design (`xschem descend` into `x1` of `tb_bandgap`,
`currsch` 0 → 1) — i.e. stand exactly where "run, then descend and press 6"
leaves you — and press **Netlist and Run**. Measured:

```
CASE C — DESCENDED: user is one level down (where "press 6" happens)
  xschem get schname = .../sky130_tests_ase/bandgap/schematic/bandgap.sch   currsch=1
  do_run GUARD (... ne design_path) = 1
  <<< UNMAP toplevel . >>>
  <<< MAP   toplevel . >>>
  status = 'Status: Error'  background=red
  run_id = ''
  >>> RESULT: toplevel . UNMAPPED 1 time(s), re-MAPPED 1 time(s)
```

No simulation runs. The status segment goes red and `run_id` stays empty.

## Why

`do_run`'s guard `[file normalize [xschem get schname]] ne $dpath` fires (you are
on `bandgap.sch`, not `tb_bandgap.sch`). It routes through
`ase::ui::design_window`, and `raise_design_editor`'s **second** loop — the
issue-0168 descended-window match, which matches the design anywhere in a
window's `sch` stack — finds this window and returns **1 without ascending**.
`design_window` therefore reports success, `do_run`'s post-check re-tests the
same guard, it is still true, and the run is refused:

> ase: design is not the current schematic; open it via Session > Design Window first

So the user gets the flash **and** no simulation. After 0616's fix the flash is
gone (the `ifhidden` arm skips the re-map on a visible window) but the refusal is
untouched.

## Why 0616 did not fix it

Rung **L2** (smallest blast radius) plus a named hazard. Making the guard pass by
**ascending** would change `currsch` immediately before a run, which is issue
**0608**'s ordering trap — *read the raw at the TOP, then descend; descending
first empties `sim_sch_path` and every device row goes blank*. 0616's fix
deliberately changes window/tab context only and never touches `currsch`, so it
leaves 0608 alone. Fixing this one cannot.

**Rejected in 0616:** relaxing `do_run`'s guard to accept a descendant. That only
moves the same refusal down into `ase::netlist`'s own guard ("design is not the
current schematic"), which is a real guard with real callers.

## What a fix has to decide

1. Should a descended user's **Netlist and Run** netlist the *design* (ascend,
   netlist, and put them back where they were), or should it refuse *clearly*
   instead of with a bare red status?
2. If it ascends, `sim_sch_path` / descend-state ordering must be re-checked
   against 0608 before and after — that is the whole point of the hazard.
3. Either way the user needs a sentence, not a red rectangle. Today the echo goes
   to the status line and names a menu item, which is the same detour 0616 was
   about.

## Acceptance

- Pressing **Netlist and Run** while descended either runs the design's deck, or
  reports in words what it did and why, with `run_id` and the status segment
  consistent with each other.
- 0608's rows stay green either way.
- A regression row in `tests/headless/test_ase_window.tcl` descends first and
  asserts the outcome (there is none today; the W6m rows cover the *foreign
  window context* case, not the *descended* case).
