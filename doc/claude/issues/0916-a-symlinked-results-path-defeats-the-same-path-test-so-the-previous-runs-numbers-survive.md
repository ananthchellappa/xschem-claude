# 0916 — when the sheet's results path is a SYMLINK to the file the menu attached, issue 0910's repair does not fire and the previous run's numbers survive forever

STATUS: **OPEN — measured 2026-08-28 on the delivered item-B1 tree, filed not
fixed.** This is issue **0910's own defect**, alive in one spelling of the path.
It is PRE-EXISTING in the sense that it was broken before 0910 too — 0910 was
broken for *every* spelling — but it is newly interesting, because 0910 is now
recorded as FIXED and this is the state in which it is not.
FOUND IN: `op_annot::db_current`, `src/op_annot.tcl` — both path comparisons,
the new same-path test in guard **G3a-2** and the long-standing different-path
arm of guard **G4**, decide with `file normalize` and `eq`.
RELATED: [0910](0910-an-operating-point-attached-from-outside-is-trusted-forever-at-the-same-path.md)
(the fix this hole is in),
[0908](0908-the-annotate-tick-can-show-another-corners-operating-point.md) (the
arm that must keep answering "not mine" for a genuinely different file — the
reason this cannot be fixed by simply comparing less),
[0810](0810-annot-root-is-compared-with-a-bare-strcmp-so-a-respelled-path-false-clears.md)
(the same class one layer down: a path compared as text, in C, about the
schematic rather than the results file),
[0915](0915-a-re-run-inside-the-same-second-at-the-same-byte-length-is-invisible-to-the-freshness-stamp.md)
(the other way this question answers "unchanged" about a file that changed).

---

## 1. What the user does, and what they see

The bench is one people really run: `<netlist_dir>/<cell>.raw` is a **symlink**
to where the results actually live — a results area on another volume, a
per-corner directory, a "latest" link maintained by a run script. The user picks
`Waves > Op Annotate` (or `Simulation > Graphs > Annotate Operating Point into
schematic`) and chooses the real file. Numbers appear. The simulation is re-run
over that same real file. They press `6`. And `6` again.

Measured 2026-08-28, `--nogui`, on the delivered tree:

```
Z2| the sheet's own candidate is a SYMLINK to the file the menu attached
Z2|   candidate  .../sc/ndl/mos.raw
Z2|   Waves > Op Annotate  -> id = 10u | gm = 100u | gds = 1u
Z2|   ---- the simulation is RE-RUN over the same file: disk holds id=9e-03 ----
Z2|   press 6              -> id = 10u | gm = 100u | gds = 1u
Z2|   status line          : Showing device operating-point values and DC node voltages on the schematic. These results were already loaded.
Z2|   press 6 again        -> id = 10u | gm = 100u | gds = 1u
```

Word for word issue 0910 §1, on a tree where 0910 is marked FIXED.

## 2. Why

Both comparisons in `op_annot::db_current` are `file normalize` plus string
equality, and **Tcl's `file normalize` does not resolve a symlink in the final
component**. Measured in the interpreter this runs in:

```
norm link  >>.../slt/link.raw<<
norm real  >>.../slt/real.raw<<
equal? 0
```

So the attached path (the real file) and this surface's candidate (the link)
normalise to two different strings. The new same-path test in guard G3a-2 does
not fire, control falls through to stamp-and-trust, and from then on guard G4's
different-path arm answers "current" — the arm that exists so a press about one
corner never destroys another corner's operating point (**0908**). Every joint
is behaving as designed; the answer is wrong.

The same hole is symmetric: attach through the link and let the candidate be the
real file, and it misses the other way round.

## 3. Why it cannot be fixed by comparing less

The different-path arm is not slack, it is 0908's promise: the numbers a user
deliberately loaded from somewhere else must not be swapped out from under them,
and `xschem annotate_op` **deletes** the 1-point operating point it replaces, so
a wrong "same file" answer would not hide a database, it would destroy one. Any
repair must make the comparison see *more* — resolve the final component the way
the filesystem does — while still answering "different" for two genuinely
different files.

## 4. The likely shape of a fix, not done here

Compare **file identity** rather than path text: resolve the last component
(`file readlink` in a loop, or `file stat` and compare `dev`+`ino` when both
paths exist) and fall back to the normalized-string comparison when either side
cannot be stat'ed — a path that does not exist yet is an ordinary state on this
surface and must keep answering "different" rather than raising. Both call sites
in `op_annot::db_current` must move together, and `cadence::_annot_op_target`'s
candidate must not be resolved anywhere else, or the two halves will disagree
about what the same file is.

⚠ It wants its own acceptance rows and its own 0908 twin, which is exactly why
it is filed rather than slipped into item B1: the same "look green, re-open
0908" trap that item's brief was written around.

## 5. Not covered by any row

Every path row in `tests/headless/test_annot_stale_0684.tcl` — F36 through F47,
F40 and F41 leg b included — stages real files with plain spellings. Nothing in
the tree creates a symlink, so the whole suite is green in the state above.

## 6. Repro

`/tmp` probe, delivered tree, headless: `ln -s <real>/actual.raw
<netlist_dir>/mos.raw`, set `::netlist_dir` to the link's directory, load the
sheet, `xschem set annot_show 3` + `xschem annotate_op <real>/actual.raw` (which
is exactly what both menu items do), sleep, rewrite the real file, then
`cadence::annot_mode op`. The probe prints the candidate and its normalization
so the premise is visible rather than assumed.
