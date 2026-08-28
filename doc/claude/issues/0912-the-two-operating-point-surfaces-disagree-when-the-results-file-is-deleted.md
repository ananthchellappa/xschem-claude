# 0912 — when the results file is DELETED, the `Results > Annotate` tick keeps the numbers and `6` blanks them

STATUS: OPEN — measured 2026-08-28 by item A15's adversary pass and re-measured
by A15's write-up agent on the delivered tree before filing.
FOUND IN: `op_annot::db_current` guard **G4**'s no-candidate arm
(`src/op_annot.tcl`, `if {$cand eq {}} { return 1 }`), reached from
`ase::ui::annot_ensure_loaded` (`src/ase_window.tcl`) because
`ase::last_rawfile` (`src/ase.tcl:689`) answers a path **only if the file
exists**.
RELATED: [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md) §9
(the sabotage round independently flagged this arm as live in the product and
untested), [0838](0838-ase-annotate-stays-live-after-a-failed-run-and-paints-the-previous-runs-numbers.md).

---

## 1. What the user does, and what they see

Tick `Results > Annotate > Operating Point info`; the numbers appear. Re-run —
and the simulator deletes the old results file and then dies before writing a new
one, which is what ngspice does on a fatal deck error. Measured, delivered tree,
headless:

```
B1| after the tick goes ON     -> id = 9m | gm = 7m | gds = 50u   exists on disk = 1
B1| ---- the simulator DELETES the old raw and the run dies ----
B1| with NO further gesture    -> id = 9m | gm = 7m | gds = 50u   exists on disk = 0
B1| after untick + re-tick     -> id = 9m | gm = 7m | gds = 50u   exists on disk = 0
B1| after 6 (the chord)        -> id = | gm = | gds =
B1|     status line : ... There is no results file at /tmp/m684/nd/mos.raw yet. Run a simulation first.
```

**The two operating-point surfaces disagree about the same state**, and only one
of them says anything. The tick keeps painting numbers whose file no longer
exists and offers no way to find that out — untick-and-re-tick does not clear it.

## 2. Mechanism

`ase::last_rawfile` returns `{}` when the file is gone, so
`annot_ensure_loaded` asks `op_annot::db_current {}`, which hits G4's
`if {$cand eq {}} { return 1 }` and early-returns **above** guard G13, the
"re-attach or BLANK" detach. The chord takes the other door: its `netlist_dir`
candidate is a path, not `{}`, so the stamp mismatch (the file is gone, so
`_db_stat` answers empty) sends it down the selector, which refuses and blanks.

The no-candidate arm is not wrong in itself — it is what stops the tick throwing
away good numbers when there is nothing to re-attach from. What is wrong is that
"there is nothing to re-attach from" and "these numbers are still the run you are
looking at" are being answered by the same `1`.

## 3. Not a wrong NUMBER — a wrong LABEL that cannot be corrected

The numbers on screen are a real run's real numbers, so this is not RULING D5-1.
It is the neighbouring failure: an authoritative control (a ticked menu item)
asserting a live relationship to a file that is gone, with no gesture that
resolves it. That is the same shape as
[0907](0907-the-already-loaded-line-does-not-name-the-file-it-loaded.md).

## 4. Ruling needed before it is fixed

Should a vanished results file BLANK the schematic (matching `6`), or keep the
last good numbers and SAY the file is gone? Blanking loses information the user
may still want; keeping it silently is what ships today. The two surfaces must
agree either way — that is the part that is not a matter of taste.
