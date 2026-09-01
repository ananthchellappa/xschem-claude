# 0908 — ASE-L's `Results > Annotate` tick can show ANOTHER corner's operating point

STATUS: OPEN — filed 2026-08-28 by item A15 (the issue 0684 fix). This is a
deliberate, measured residual of that fix, not an oversight.
FOUND IN: `op_annot::db_current`'s guard G4 (`src/op_annot.tcl`), reached from
`ase::ui::annot_ensure_loaded` (`src/ase_window.tcl`) and from
`cadence::annot_mode` (`utils/annot_mode.tcl`).
RELATED: [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md) §7,
[0685](0685-annotate-op-reuses-a-stale-registry-database-at-the-same-path.md).

---

## 1. The state

The user loads an operating point by hand — `Waves > Op Annotate`, an xschemrc
line, another corner's `.raw` — and then ticks ASE-L's
`Results > Annotate > Operating Point info`, or presses `6`. The tick goes on,
the numbers render, and they are the HAND-LOADED database's numbers, not the
session's. Nothing says which.

## 2. Why 0684's fix does it on purpose

`op_annot::db_current` answers "current, leave it alone" whenever the attached
database sits at a path other than this surface's own candidate. That arm exists
because replacing it would DESTROY it: `xschem annotate_op` deletes the
previously loaded database when that one is a 1-point `op`/`dc`
(`scheduler.c:2410-2414`). Row W1a16 of `tests/headless/test_ase_window.tcl`
stages exactly that — a 1-point sentinel operating point, ticked over — and
requires the sentinel to survive. Measured 2026-08-28: a fix that re-attaches
unconditionally drives `xschem raw index v(sentinel16)` from 0 to -1, i.e. the
user's database is gone.

So the choice was: leave a possibly-foreign database showing (this), or destroy
databases the surface did not attach (the 2026-08-25 attempt's data loss, issue
0685 §4). The first is a wrong LABEL, the second is lost DATA.

## 3. What would close it properly

Naming the file in the `live` sentence is the cheap half —
[0907](0907-the-already-loaded-line-does-not-name-the-file-it-loaded.md). The
full close is a way to REPLACE another database without destroying it, which is
a C change inside `annotate_op` / `extra_rawfile` and is the same place issue
0685 says the real fix belongs.

## 4. Ruling needed

Should the tick REPLACE a database the user loaded from a different file? Filed
as unratified: `owed.sh add rule 0908`.
