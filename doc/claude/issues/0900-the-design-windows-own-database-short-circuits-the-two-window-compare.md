# 0900 — a second Alt+Shift+6 skips every safety check, and the previous run's numbers stay on the schematic

**Status:** 🔴 **OPEN — measured, filed, NOT fixed.** This is a **live RULING
D5-1 violation**: a number that was not measured for the thing it is displayed
next to reaches the schematic, under an authoritative caption, with no refusal
and no warning.

Filed 2026-08-28 by the item A13 write-up, from the A13 adversarial
verification pass. Measured on **both** arms, byte-identical.

**Not introduced by item A13.** The expression at fault arrived with issue 0881
(commit `1d466364`), one item earlier. A13 is filing it because A13's own fix
lives *inside* the block this expression guards, and because A13 shipped a
comment claiming a skipped compare is now impossible — which this measurement
disproves. See *"What this costs the A13 comment"* below.

## What the user does — and it is the ordinary sequence, not a corner

1. Runs a transient, puts a cursor on, presses **Alt+Shift+6**. It works: the
   node voltages land on the sheet. **That press leaves the results database
   attached to the design window** — a successful press never unwinds it, by
   design.
2. Changes something, re-runs the simulation. The waveform window re-plots and
   is now showing the **new** run.
3. Presses **Alt+Shift+6** again.

## What happens

The schematic is painted with the **first** run's numbers, under the caption
*"Showing each node's voltage at 3 ns, where cursor B is on the waveform."*,
while the waveform window is showing the second run. No refusal, no warning, no
compare. Measured, both arms:

```
P1 press1=0 ok
P1 after_press1_loaded=0 mask=4
P1 paint_after_press1=d 3 g 0.9 0 0.0 0 0.0     <- run 1, correct
P1 viewer_now v(d)@last=28 v(g)=0.1             <- the waveform window now holds run 2
P1 design_loaded_before_press2=0                <- the design window still holds run 1
P1 press2=0 ok
P1 loaded=0 mask=4
P1 msg=Showing each node's voltage at 3 ns, where cursor B is on the waveform.
P1 paint=d 3 g 0.9 0 0.0 0 0.0                  <- run 1 again, on a sheet describing run 2
```

The same door reaches issue 0896's own forbidden literal. With the design window
holding a finished run and the waveform window showing a **still-filling**
zero-point run — 0896's headline scenario, with A13's fix in place:

```
P5 design_loaded=0 design_v(d)@last=28 design_v(g)=0.1
P5 viewer_points=0 viewer_simtype=tran
P5 annot_tran=0 ok
P5 loaded=0 mask=4
P5 msg=Showing each node's voltage at 3 ns, where cursor B is on the waveform.
P5 paint=d 21 g 0.1 0 0.0 0 0.0
```

`d 21 g 0.1 0 0.0 0 0.0` is the literal item A13's brief names as the one that
must not appear. A13 closed the door it was chartered to close; this is a
different door onto the same room.

## The measured cause, at the statement

`utils/annot_mode.tcl`, `cadence::annot_tran`:

```tcl
set loaded -1
catch {set loaded [xschem raw loaded]}
if {![string is integer -strict $loaded] || $loaded < 0} {
  set sup [cadence::_annot_tran_supply]
  ...
}
```

**The entire supply is inside that `if`.** The waveform-window consult, the
`filegone` and `nopoints` guards item A13 just added, the staleness check, the
`viewerunread` guard and the **two-window compare** are all skipped whenever the
design window already holds *any* database. The test asks *"is some database
attached?"*, never *"is it the one the user is looking at?"*.

This is the identical predicate mistake already filed as **0684** against
`annot_ensure_loaded` — *"it guards on `xschem raw loaded` >= 0, which asks 'is
SOME database attached' rather than 'are THIS session's CURRENT results
attached'"*. 0684 is open, on the operating-point surface. This is the same
fault on the transient surface, reached by a different caller, and neither
issue's fix covers the other.

## What this costs the A13 comment, and why that matters here

`utils/annot_mode.tcl` shipped this claim above the compare:

> ⚠ GATED ON `$vseen`, WHICH MAKES A SKIPPED COMPARE STRUCTURALLY IMPOSSIBLE.

It is true **inside `cadence::_annot_tran_supply`** and false as a statement
about the feature, because the supplier is not always called. The same overclaim
went into `doc/claude/issues/0896-*.md` and
`doc/claude/specs/op_annotation.md`. All three were corrected in the A13
write-up commit — a comment that overstates its own coverage is exactly what
hid a guard for a whole item in **0899**, and this is the same shape one level up.

## The shape of a fix — not attempted here

The honest gate is not *"is a database attached"* but *"is the attached
database the one the waveform window is showing"*. The consult already computes
the fingerprint that answers this. Sketch:

* run the consult **before** the `loaded < 0` test, and take the supply path
  whenever the consult reports a viewer file that disagrees with what the
  current window holds; or
* keep the short-circuit but add the two-window compare to it, so an
  already-attached database is still checked against the viewer's fingerprint
  before a single number is believed.

Either is a real change to the mode's control flow with its own unwind
consequences — a successful earlier press owns the attached database, so a
refusal on the second press must decide whether to detach it — and it needs its
own item, its own rows on both arms and its own sabotage pass. **It must not be
done as a drive-by.**

## Rows

**None, and that is the finding.** Every existing row that exercises
`cadence::annot_tran` starts from a design window holding nothing, so all of
them enter the guarded block and none can see this path. Rows V58–V65, V50, V51
and V37 included. A fix owes at minimum:

* a two-press row on both arms — press, re-run, press again, and assert the
  sheet does **not** still carry the first run's numbers;
* the 0896 fixture with the design window pre-loaded (probe `P5` above), which
  is the `d 21 g 0.1` case.

## Related

* **0896 / 0895** — the same D5-1 family, through the consulted path. Fixed by
  item A13; this is the unconsulted path.
* **0684** — the same "is SOME database attached" predicate, on the OP surface. Open.
* **0885** — the compare that runs but samples only the last point. Open.
* **0899** — a comment that overstated what its rows pinned. The A13 comment
  corrected here is that shape again.

## Evidence

Probes, re-run by the write-up agent rather than inherited, against the
already-built `src/xschem` (Aug 27 14:58) with the A13 fix in the tree:

* `.../scratchpad/vc/p.tcl` row **P1** — the two-press sequence.
* `.../scratchpad/vc/q.tcl` row **P5** — the `d 21 g 0.1` case.

Both reproduce byte-identically headless and on the persistent dev display
(`:99`, 1920x1080x24, **openbox 3.6.1** live per `devdisplay.sh status`).
