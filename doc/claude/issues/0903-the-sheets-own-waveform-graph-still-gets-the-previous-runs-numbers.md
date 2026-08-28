# 0903 — with no ASE waveform window open, a second Alt+Shift+6 still paints the previous run's numbers

**Status:** 🔴 **OPEN — filed, not fixed.** A **live RULING D5-1 violation**: a
number that was not measured for the thing it is displayed next to reaches the
schematic under an authoritative caption, with no refusal and no warning.

**Filed:** 2026-08-28 by the item A14 write-up, from A14's adversarial
verification pass, and **reproduced by the write-up agent on both arms before
filing** rather than inherited.

**This is the other half of issue 0900.** 0900 is fixed for the case it was
measured on — a waveform window is open and the cursor is read out of it. The
fix revalidates the design window's cached database against **the ASE waveform
window**, and only against that. When there is no ASE waveform window, the
revalidation deliberately answers *"keep the cache"*, and on that path the
original defect is untouched.

## What the user does — and no ASE waveform window is involved anywhere

XSCHEM draws waveforms **on the schematic sheet itself** (a graph object, cursors
A and B toggled on the sheet), and the transient annotation supports that on
purpose: `cadence::_annot_tran_cursor` falls back to the sheet's own
`graph_flags` bits 2 and 4 and returns a cursor tagged `sheet` when no viewer
window answers. The chord is bound with no ASE dependency at all
(`src/cadence_style_rc`). So:

1. Run a transient, turn on cursor B **on the sheet's own graph**, press
   **Alt+Shift+6**. It works — the node voltages land, from
   `$netlist_dir/$cell.raw`.
2. Re-run the simulation. The same results path is rewritten with the new run,
   and the sheet's graph re-plots it.
3. Press **Alt+Shift+6** again.

## What happens

The **first** run's numbers are repainted, under *"Showing each node's voltage at
3 ns, where cursor B is on the waveform."* Measured by the write-up agent,
**byte-identical on both arms** — headless, and on the persistent dev display
(`:99`, 1920x1080x24, **openbox 3.6.1** live per `devdisplay.sh status`):

```
X1 press1=0 ok  supply_calls=1
X1 paint_after_press1=d 3 g 0.9 0 0.0 0 0.0     <- run 1, correct
X1 cursor_source=3e-09 B sheet                  <- the SHEET's own graph, no viewer
X1 design_loaded_before_press2=0                <- press 1 left its database attached
X1 press2=0 ok  supply_calls=0                  <- THE WHOLE SUPPLY IS SKIPPED
X1 loaded=0 mask=4
X1 msg=Showing each node's voltage at 3 ns, where cursor B is on the waveform.
X1 paint=d 3 g 0.9 0 0.0 0 0.0                  <- run 1 AGAIN
X1 oob_disk=0 ... v(d)@last=28                  <- the file on disk is run 2
```

`supply_calls=0` is the same signature issue 0900 was filed on: the
waveform-window consult, the deleted-file and no-values-yet guards, the
out-of-date check and the two-window compare are **all** skipped, and the press
answers `ok`.

## The measured cause, at the statement

`utils/annot_mode.tcl`:

```tcl
proc cadence::_annot_tran_db_current {} {
  set vw [cadence::_annot_viewer_db]
  if {![llength $vw]} { return 1 }          ;# <- this line
  ...
}
```

`cadence::_annot_viewer_db` returns `{}` when `::ase::session_for_current`
yields no key, or `::wviewer::window_for` yields no live toplevel — i.e.
whenever **no ASE waveform window** is showing a transient for this sheet. The
currency test then answers *"current"* without having consulted anything, the
gate in `cadence::annot_tran` stays shut, and the cached database is believed.

**That line is a deliberate decision, and it is the right one for the case it was
written for**: a user who pressed the chord, got their numbers and then *closed*
the waveform window must not have them stripped off the sheet by the next press
(row **V70**), and rebuilding a results path out of the preferences instead would
answer with a file the user may not be looking at — issue 0881's own defect from
the other side. What the decision missed is that `{}` covers **two** situations
that are not alike:

* nothing is on screen to disagree with — the closed-window case, where keeping
  the cache is right; and
* the **sheet's own graph** is on screen, plotting the new run, and it disagrees
  loudly — where keeping the cache is RULING D5-1.

The feature cannot currently tell them apart, because the only thing it asks is
the ASE waveform window.

## Why no row sees it

Every one of item A14's new rows — V66, V67, V68, V70, V71, V72, V73, V75, and
B12j/B12k on the display arm — stages its disagreement through an ASE waveform
window, because that is the surface the driver's ruling named. Row **V70** is the
only row on the `{}` arm and it asserts the cache is *kept*, which is the correct
assertion for the closed-window case and is exactly what makes this face
invisible. `test_op_annot.tcl` has no row that puts a cursor on the **sheet's**
graph and presses twice.

## The shape of a fix — not attempted here

The honest question is *"does anything on the user's screen disagree with what
the design window is holding"*, and the sheet's own graph is on the user's
screen. Sketches, none of them costed:

* When the consult answers `{}` **and** the cursor resolver reports a `sheet`
  cursor, compare the cached database's `_annot_db_print` against the file the
  sheet's graph is actually plotting. The cursor resolver already knows which
  case it is in — it returns the tag `sheet` or `viewer` as its third element —
  so the two halves of the mode need only agree on the same answer.
* Or: treat the results **file's mtime** as part of currency on the `{}` arm, so
  a rewritten file is re-read once. Cheaper, and it also covers the case where
  nothing at all is plotted. It is the same remedy already recommended for
  **0684**.

Either changes what a press does on a path the driver has not ruled on, needs
its own rows on both arms and its own sabotage pass, and **must not be done as a
drive-by** — the same sentence issue 0900 carried, for the same reason.

## Related

* **0900** — the same defect through the ASE waveform window. **Fixed** by item
  A14; this is the door that fix does not reach.
* **0684** — the identical *"is SOME database attached"* predicate on the
  operating-point surface, and its recommended mtime re-read is one of the
  sketches above. Open.
* **0881** — the ruling that the answer must come from what the user is looking
  at. The sheet's own graph is something the user is looking at.
* **0885** — the compare is a sample, not a proof. Open, and orthogonal.

## Evidence

`/tmp/claude-1000/-home-analog-dev-xschem-claude/3722da05-e61e-4d11-903c-80c3d1bb943c/scratchpad/vc2/x.tcl`,
row **X1**, run by the write-up agent against the already-built `src/xschem`
(Aug 27 14:58) with item A14's fix in the tree, on both arms. Source of record:
`utils/annot_mode.tcl`, `cadence::_annot_tran_db_current` and
`cadence::_annot_tran_cursor`.
