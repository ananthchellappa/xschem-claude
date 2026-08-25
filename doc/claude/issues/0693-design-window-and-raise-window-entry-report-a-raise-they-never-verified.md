# 0693 — `design_window` and `raise_window_entry` report a raise they never verified

Status: OPEN, FILED NOT FIXED. Filed 2026-08-25 by the 0691+0692 crew, from the
sweep clause of that item's brief ("sweep src/ase_window.tcl and src/ase.tcl for
EVERY other proc whose last statement is an unconditional `return 1` ... FILE the
ones that are out of scope").
Related: 0691 (the same class, fixed), 0679, 0652 (a report that lies), 0664, 0677.

⚠ STUB, claimed to reserve the number. The measurement below is complete; the
write-up pass may expand the prose but must not renumber.

## The shape, two procs deep

`src/ase_window.tcl:4180` (`:3995` before the 0691+0692 edit; the proc starts
at `:4167`) — `ase::ui::raise_window_entry` ends in an
unconditional `return 1` after a bare `xschem new_schematic switch` with **no
verify**. `src/wave_viewer.tcl:11026-11029` already documents that such a switch
silently no-ops under a raised semaphore.

`src/ase_window.tcl:4215` (`:4030` before the 0691+0692 edit; the proc starts
at `:4196`) — `ase::ui::design_window` discards a **second**
`raise_design_editor` rc at `:4212` and then returns 1 unconditionally. It is the
consumer of the proc above, so the two are one defect: fixing either alone proves
nothing.

## Measured (headless, at HEAD 1144f22a)

```
SWEEP raise_window_entry(bogus entry)= 0/1     <- catch=0, rc=1
SWEEP design_window(BOGUS key)       = 0/0     <- honest, a DIFFERENT arm fires
DW design_window(unloadable design) catch=0 rc=0
```

`raise_window_entry` was driven with a bogus entry `{99999 .nosuchtoplevel}`: the
`xschem new_schematic switch` inside it did not throw, nothing was raised, and
it reported success.

`design_window`'s `:4215` arm could NOT be forced by ordinary means: deleting the
design `.sch` makes `ase::ui::design_path` return `{}`, so that proc's first guard fires
first and the proc honestly returns 0. Reaching the trailing arm needs `design_path` to
resolve **and** the load+raise to fail. Reachable, not falsifiable without
sabotage — which is why this is filed rather than fixed inside 0691's scope.

## ⚠ IT REFUTES A SENTENCE OF 0691

Issue 0691's "Cleared by measurement, do NOT re-file" section says:

> `raise_window_entry` has an unconditional `return 1` but performs no key lookup
> and no write — it is a "done" signal, not a witness.

That is **right about the key lookup and wrong about the mechanism**. It performs
no lookup, but it does perform an *action that can silently fail*, and it is the
engine behind `design_window`'s claim. Re-filed deliberately, not by oversight.

## Who reads the lie

Two live consumers read `design_window` as "could I reach the design window":
`src/ase_window.tcl:1689` and `src/wave_viewer.tcl:11020`.

## Sweep receipt (after the 0691+0692 fix)

`raise_window_entry` is now the LAST remaining proc in `src/ase_window.tcl` +
`src/ase.tcl` whose trailing `return 0/1` has no other return anywhere in the
body — i.e. a witness that structurally cannot fail. Before the fix there were
two; `ase::session_close` was the other and is repaired.

## Acceptance (when scheduled)

1. `raise_window_entry` verifies the switch (e.g. `xschem get current_win_path`
   or the schematic path) and returns 0 when nothing was raised.
2. `design_window` returns its callee's measured answer, in a tuple with a
   registered-key arm so a proc hardwired to either value fails one half.
3. Both consumers audited for what they do with a 0.
