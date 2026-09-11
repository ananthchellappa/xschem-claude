# 1405 — Stage 1 moved a widget path, and a hundred checks vanished without a red

**Status:** fixed
**Branch:** fluid-editing
**Filed:** 2026-09-11
**Found by:** the Stage 2 recon crews of `doc/claude/ase_analyses_batch/`, as correction **C47**

## What happened

Stage 1 of the analyses batch (issue **1401**) rebuilt the Choose Analyses form. The quick
fields stopped being a hardcoded `foreach f {source start stop step points} {destroy $w.$f}`
list and became a `destroy $w.form` + `frame $w.form` rebuild, which is exhaustive by
construction and is what lets a later stage register an analysis with eight fields. That move
relocated every quick field from `$w.<field>` to `$w.form.<field>`, deliberately.

Six lines of `tests/headless/test_ase_dialogs.tcl` were moved with it. **One suite was not.**

`tests/headless/test_ase_persist.tcl` row **G2** drives the same widgets, but through a
variable:

```tcl
set w $top.chana
...
foreach {fld val} {source V2 start 0 stop 1.8 step 0.01} {
  $w.$fld delete 0 end
```

So the survey that Stage 1 rested on — recorded in `PLAN.md` §0.2 as *"No other suite in the
tree touches a Choose Analyses quick field by path"*, and repeated verbatim in a comment
inside `ase::ui::chana_show` — was **false**, and it was false in a way its own method could
not detect: the grep was for `chana\.`, and this block never writes that string.

## Why nothing went red

**Three independent reasons, and all three had to hold.** That is what made it survive a
green Stage 1 commit.

1. **The whole G-block is inside a skip.** `test_ase_persist.tcl` waits for a real, mapped
   main canvas (`main_ready`) and, when one never appears, prints
   `SKIPPED: G1-G11 acceptance legs` instead of failing. On the headless arm the window never
   becomes usable, so G1–G11 never run. **Headless reports `ALL PASS (44 checks)` with the
   defect live.**
2. **`run_regression.tcl` — the one suite whose baseline is ZERO — does not run this file at
   all.** Not in `cases`, not in `dcases`. Measured: `grep ase_persist tests/run_regression.tcl`
   is silent.
3. **A raise is not a verdict.** `$w.source` raised `invalid command name ".ase4.chana.source"`,
   the enclosing `catch ... bigerr` swallowed it, and **G3–G11 and everything after them
   disappeared** — with no row naming what had gone.

## The measurement

```
display arm, before   RESULT: 1 FAILED (46 passed)    UNEXPECTED ERROR: invalid command name ".ase4.chana.source"
display arm, after    RESULT: ALL PASS (148 checks)
headless arm, either  RESULT: ALL PASS (44 checks)
```

**The break cost 100 checks**, and the only signal anywhere in the tree was a single
`UNEXPECTED ERROR` line on an arm no driver walks. Reproduce with the command CLAUDE.md
names for exactly this purpose:

```sh
tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog \
  --script tests/headless/test_ase_persist.tcl
```

## The fix

Three lines in `tests/headless/test_ase_persist.tcl` take the `$w.form.` prefix, and the
false claim inside `ase::ui::chana_show` is corrected to say that **two** files move with
that path and that one of them reaches it through a variable.

**A new row, G2p, asserts WHERE the fields live before anything drives them:**

```tcl
check "G2p quick fields are children of the rebuilt .form frame, not of .chana" \
  [list [winfo exists $w.form.source] [winfo exists $w.form.step] \
        [winfo exists $w.source]      [winfo exists $w.step]] {1 1 0 0}
```

It is written with **both** halves — the new paths present *and* the old paths absent — so it
cannot pass by accident on a tree where both exist. Sabotage-verified by putting the fields
back on `$w` (one edit: `ase::ui::dialog_row $w.form` → `$w`): G2p reds with exactly the
inverse, `{0 0 1 1}`.

⚠ **G2p does not save the block; it names the loss.** A future move still raises inside the
`catch` and still costs G3–G11. What changes is that the report now carries one named red with
the old and the new path both printed in it, instead of a bare `UNEXPECTED ERROR` a reader
has to reverse-engineer.

## What this says about method, beyond the one path

* **A path survey must grep the widget NAMES, not the toplevel's spelling.** `$w.source` and
  `$w.step` are findable; `$w.$fld` behind `set w $top.chana` is not. Searching for the leaf
  name is the check that would have caught this.
* **An arm that skips a block reports ALL PASS for it.** `test_ase_persist` headless is 44 and
  display is 148 — the headless number is not a weaker measurement of the same thing, it is a
  measurement of a **different, much smaller** thing. The same shape is already recorded for
  `test_ase_dialogs` (37 headless / 215 display) and `test_ase_window` (56 / 295).
* **A suite outside `run_regression.tcl`'s case list has no floor at all.** T1 being at zero
  says nothing about it.

## Related

* **1401** — Stage 1 of the analyses batch, the commit that moved the paths.
* **1375** — `test_ase_optier_0963`'s GUI arm hangs for ever; it is why that suite is excluded
  from any display-arm family run.
* **1403** — the two-layer stall protection; the in-suite watchdog covers event-loop hangs
  only, which is a sibling lesson about a bound that looks more general than it is.
