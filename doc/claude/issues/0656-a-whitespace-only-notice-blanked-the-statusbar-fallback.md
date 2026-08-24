# 0656 — a whitespace-only notice blanked the `.statusbar.12` fallback (and could blank a live `*BUSY*`)

Status: **FIXED** in the same pass that found it (src/ciw.tcl, `xschem::notify`).
Filed by: the 0650 write-up pass, 2026-08-23, from the adversary leg's finding.

## What the old `ase::echo` did, and what the move lost

`ase::echo` returned **twice**: once on an empty argument, and again *after*
`string trimright`. Issue 0650 moved that body into `xschem::notify` and kept only
the first return, narrowing the second to guard the **log** sink alone
(`if {$lmsg ne {}}`). Sinks 3 and 4 — added by the same step — therefore ran for a
message that renders as nothing. `xschem::notify_statusbar` is
`configure -text`, which is a **replace**, not an append.

## Measured, BEFORE (on :99, CIW withdrawn through its real WM_DELETE_WINDOW handler)

```
D-a parked text                                'A REAL PARKED NOTICE'
D-a after whitespace-only notify               '  '
```

i.e. `::xschem::notify "\n\n"` overwrote a live notice with two spaces. The same
hole blanks a live `*BUSY*` (`src/hilight.c:2201` writes it into this very field).

## Measured, AFTER

```
D-a parked text                                'A REAL PARKED NOTICE'
D-a after whitespace-only notify               'A REAL PARKED NOTICE'
```

## The fix

`xschem::notify` records and returns before sinks 3/4 when `[string trim $line]`
is empty — restoring, for the Tk sinks, the second early return the moved body
had. The pane sink is untouched: it still runs first and unconditionally, so the
blank-line contract that the ASE suites depend on (`::ase::echo {}` yields one
empty `::ciw_echo` call and no log line) is unchanged. Verified: test_ase_core
146/146, test_ase_log_seam_0207 32/32, test_ase_locked_wire_pick_0160 16/16.

## Decision, ladder rung L1 (invariant I3)

I3 says a missing value renders **blank, not a plausible wrong one**. Its converse
is what bit here: a notice that renders as nothing must not *destroy* a value that
was there. Rejected alternative: filtering whitespace at the top of `notify`
alongside the empty check — that would have changed the pane contract for
whitespace-only messages, which is exactly the load-bearing behaviour PS-rows and
the ASE capture suites assert.

## Still open

Nothing from this defect. The wider properties of the field are issue 0654; the
fallback's volume behaviour is issue 0660.
