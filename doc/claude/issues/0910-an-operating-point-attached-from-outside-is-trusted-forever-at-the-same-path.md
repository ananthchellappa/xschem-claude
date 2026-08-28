# 0910 — an operating point attached from OUTSIDE the annotation surface is trusted FOREVER, so the previous run's numbers survive at the very same path

STATUS: OPEN — measured 2026-08-28 by item A15's adversary pass, on the tree that
ships the 0684 fix, and RE-MEASURED by A15's write-up agent on the delivered tree
before filing. This is issue **0684's own defect**, still alive on two shipped
menu items.
FOUND IN: `op_annot::db_current` guard **G3a**, `src/op_annot.tcl:984`
(`if {![info exists _db_src($key)]} { ::op_annot::_db_stamp $np ; return 1 }`).
RELATED: [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md) §8
(whose route table this refutes — corrected there),
[0908](0908-the-annotate-tick-can-show-another-corners-operating-point.md) (a
DIFFERENT path; this one is the SAME path).

---

## 1. What the user does, and what they see

`Simulation > Graphs > Annotate Operating Point into schematic`
(`src/xschem.tcl:16091`) or the waveform window's `Waves > Op Annotate`
(`src/xschem.tcl:15713`) — both a bare `xschem annotate_op`. Numbers appear. Then
the simulation is re-run, rewriting **the same file**. Press `6`, `6` again, `6` a
third time: the sheet keeps repainting the FIRST run's numbers, under a sentence
saying the results were already loaded. Measured, delivered tree, headless:

```
G3| USER PICKS  Waves > Annotate Operating Point  (a hand attach: no press of 6 yet)
G3| ---- the simulation is RE-RUN: the same path now holds id=9e-03 ----
G3| after the FIRST press of 6
G3|     sheet paints : id = 10u | gm = 100u | gds = 1u        (disk holds id=9e-03 = 9m)
G3|     status line  : Showing device operating-point values on the schematic. These results were already loaded.
G3| after the SECOND press of 6   -> id = 10u | gm = 100u | gds = 1u
G3| after the THIRD press of 6    -> id = 10u | gm = 100u | gds = 1u
```

ASE-L's `Results > Annotate` tick, and `ase::ui::annot_refresh_here`, behave the
same way in the same state (adversary probe `g4.tcl`). It does not self-correct,
ever. This is RULING **D5-1** and invariant **I3** — *"not the previous run's
number"* — in their own words, which is exactly what 0684 was filed about.

## 2. Why the 0684 fix does not catch it

Guard G3a stamps at the first **observation**, not at the **attach**:
`op_annot::db_current` calls `_db_stat $np`, which stats the file *now*. When the
attach happened outside `op_annot::db_attach` — which is the only place that
stamps at attach time (`src/op_annot.tcl:1088`) — the first question is asked
AFTER the re-run, so the stamp minted describes **run 2's file** while the
in-memory database is **run 1's**. From then on G3b (`the stamp still matches`)
answers "current" forever.

"Trusted on first sight and revalidated from then on" is the property 0684 §8
claims. Measured, it is **trusted forever** whenever the first sight lands after
the change.

## 3. Why the trust arm exists at all, so nobody deletes it blind

G3a is what keeps rows N5, N10 and V31b of `tests/headless/test_op_annot.tcl`
green: they hand-attach a database and expect the `live` arm. A predicate that
answered 0 on first sight would also re-read a good file, for nothing, on the
first press after every attach (58 ms at 40 000 vectors — 0684 §8's cost table).

## 4. The narrow fix, and why it is believed safe

When the attached path **equals this surface's own candidate**, first sight
should RE-ATTACH rather than trust. A re-read of a file that has not changed is
correct and costs one read. G3a's stated reason for trusting does not require
trusting the *same* path — it only requires trusting a database whose path is
**not** the candidate, and that is the arm guard G4 already owns (issue 0908).
Not done here: it is a behaviour change on the surface item A15 had just
stabilised, and it wants its own acceptance row (attach from the menu, re-run,
press `6` once — the row A15's suite does not have, because row F7 takes its
first look *before* the rewrite).

## 5. Not covered by the existing rows

`tests/headless/test_annot_stale_0684.tcl` row **F7** stages
`annotate_op` → ask → rewrite → ask, i.e. it observes while the file is still
run 1, so its stamp is correct. The user's order is attach → walk away → re-run →
**first** observation. No row in the tree stages that order.
