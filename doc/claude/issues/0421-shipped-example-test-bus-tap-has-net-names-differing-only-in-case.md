# 0421 — the shipped example `test_bus_tap.sch` has net names differing only in case, so item 14's warning fires on it

**Status:** OPEN. Measured on branch `fluid-editing` at `a7f56fa6` (casemode batch item 14).
Documentation only — nothing changed.
**Area:** `xschem_library/examples/test_bus_tap.sch` (a shipped library file), and
`netlist_case_collision_check()` in `src/node_hash.c`.
**Found:** 2026-08-17, by the casemode batch item 14 crew. Recorded in
`doc/claude/casemode_batch/receipts/14-netlister-collision-warning.md` §2 as
"ruled, then deliberately left alone", and in `doc/claude/specs/raw_case_mode.md` §14,
whose earlier premise "no committed fixture collides" is corrected there. Filed here by
the driver because it is a **user-visible change to a shipped file's behaviour**, which
is the driver's to surface rather than a receipt's to absorb.

**The warning is correct. That is the point.** This is not a false positive to suppress.

---

## What

Item 14 added a netlist-time warning that fires where xschem and the simulator disagree
about how many nets a design has (`DECISIONS.md` C2). Under `fold` — the default, and
what a stock `apt` ngspice does — two net names differing only in case are **one** node
to the simulator and **two** nets to xschem, because xschem's net table compares with
`strcmp` (`node_hash.c:82`).

`xschem_library/examples/test_bus_tap.sch` carries both spellings of two supplies:

```
lab=VCC   and   lab=vcc
lab=VSS   and   lab=vss
```

So netlisting that example under the default mode now emits the warning. Twice.

## Why this was not "fixed" in item 14

Two reasons, both sound:

1. **The warning is true.** Those really are two nets in xschem and really will merge
   into one node in the simulator. Silencing it would mean silencing a correct
   diagnostic to keep an example quiet, which is the wrong way round.
2. **A shipped library file is not a casemode item's to edit.** Item 14's audit contract
   was an empty diff, and editing `xschem_library/` is outside the scope it was given.

It also did not move any audit row — no committed test asserts on netlisting that
example — which is why the empty-diff contract held even though behaviour changed.

## What has to be decided

**This is a judgment call about a shipped file, not a bug to fix mechanically.**

1. **Rename in the example, or leave it?** Renaming `vcc`→`VCC` and `vss`→`VSS` (or the
   reverse) makes the example clean and demonstrates the good habit. Leaving it means
   every user who netlists that example meets the new warning on day one — which is
   arguably a *useful* demonstration of what the warning is for, and arguably just noise
   in a file whose subject is bus taps.
2. **If renamed, check what else the file's `T` records and any golden output reference**
   — the pins, the labels and any doc text that names the supplies.
3. **Sweep the rest of `xschem_library/`** before deciding. Nobody has checked whether
   other shipped schematics collide; this one was found because item 14's check fired on
   it, not by a search. A sweep turns "one example is noisy" into a known number.

## What is NOT claimed here

Only `test_bus_tap.sch` has been observed to collide. The rest of `xschem_library/` is
**unswept** — there may be more, or this may be the only one. Nobody has looked at how
the warning reads in situ on this example either; that is part of item 14's outstanding
`look` debt, not something this issue establishes.
