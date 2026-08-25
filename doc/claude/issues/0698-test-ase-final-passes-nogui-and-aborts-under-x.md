# 0698 — `test_ase_final` passes `--nogui` and ABORTS under X

Status: OPEN (stub claimed 2026-08-25 by the 0695+0696 crew; measured, NOT fixed here)
Area: `tests/headless/test_ase_final.tcl` and/or `ase::netlist`'s design-window guard
Related: 0683, 0684 (annotation reachable with no bound design window — OPEN, awaiting
the user's ruling; **do not touch them from here**), 0695+0696 (the item that found this)

## What was measured

The suite is green headless and dies on the tenth check under a real X display:

```
$ ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_final.tcl
RESULT: ALL PASS (78 checks)

$ GUI_GATE=0 DISPLAY=:99 ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_final.tcl
UNEXPECTED ERROR: ase: design sky130_tests/test_nfet_final is not the current schematic;
                  open its design window first (Session > Design Window)
RESULT: 1 FAILED (9 passed)
```

`:99` is Xvfb 1920x1080x24 with openbox 3.6.1 live (`devdisplay.sh status`:
`wm: openbox (Openbox)`), which is the environment every other suite in this batch
was measured on.

## It is PRE-EXISTING, and that was proved rather than assumed

Two agents of the 0695+0696 crew confirmed it independently by restoring
`git show HEAD:src/ase_window.tcl` over the working tree, re-running on `:99`, and
getting the **identical** `RESULT: 1 FAILED (9 passed)` and the identical error
line, then restoring with `cp` + `touch` and re-verifying the checksum and
`git diff --stat`. None of `save_all_*` is on the failing path.

## Why nobody had seen it

The measured baseline of record for this branch only ever ran `test_ase_final`
under `--nogui`, where it reports `ALL PASS (78 checks)`. The `--nogui` arm
self-skips whatever leg needs a bound design window, so the abort has no headless
symptom at all. **A suite that passes headless and aborts under X is a suite whose
green is a partial measurement** — the same "a report that lies" family this branch
keeps meeting.

## Shape of the defect (not yet decided which half is wrong)

Either the suite fails to open/bind a design window before the leg that netlists,
or `ase::netlist`'s "is not the current schematic" guard is over-strict under X
where headless leaves it unreachable. That guard is adjacent to the OPEN 0683/0684
family (annotation reachable with no bound ASE-L session / `annot_ensure_loaded`
guarding on the wrong predicate), which is why this is filed and not fixed: those
two are awaiting the user's ruling and a fix here could pre-empt it.

## Acceptance (when it is taken)

1. `test_ase_final` gives the SAME check count and verdict under `--nogui` and on
   `:99`, or the X-only legs are explicitly gated and counted as skips.
2. Whichever side is wrong is named: the suite's missing bind, or the guard's
   predicate.
3. Whatever lands does not contradict the 0683/0684 ruling once the user gives it.
