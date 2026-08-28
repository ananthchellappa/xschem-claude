# 0896 — the two-window compare is skipped while a simulation is still filling, and another run's numbers land on the schematic

**Status:** **OPEN**. Measured 2026-08-28 at the item A12 write-up, on **both**
arms. **This is a live RULING D5-1 violation** — a number that was not measured
for the thing it is displayed next to reaches the schematic, under an
authoritative caption, with no refusal and no warning.

**Not introduced by item A12.** The expression at fault predates it (it arrived
with issue 0881). A12 is filing it because A12 reused that same expression as
the gate for a new user-facing sentence, and because A12's whole subject is this
guard.

## What the user does

1. Runs a transient and watches the waveform window fill. While a run is in
   progress ngspice writes a well-formed header with **`No. Points: 0`** —
   issue 0836 measured this and its own suite calls it *"THE ORDINARY CASE, NOT
   A CORNER"*. The read succeeds and the database **attaches**, which is exactly
   how the waveform window can watch a run fill.
2. The simulator finishes and writes the completed run over the same path.
3. The user presses **Alt+Shift+6** (or picks **Results > Annotate > Transient
   Node Voltages**).

## What happens

The schematic is painted with the **completed** run's numbers while the waveform
window is still showing the in-progress one, and the caption asserts those
numbers describe what is on the waveform. Measured, both arms, in a `/tmp`
symlink shadow tree with the repository untouched:

    PROBEB consult_len=2 print=.../v_a10_vrun.raw {}
    PROBEB state=ok
    PROBEB msg=Showing each node's voltage at 3 ns, where cursor B is on the waveform.
    PROBEB ld=0 0 mask=4 paint=d 21 g 0.1 0 0.0 0 0.0

`d 21 g 0.1` is the *other* run. There is no refusal and no warning.

This is verbatim the defect the two-window compare exists to prevent — row V51's
own comment describes it as *"the waveform screen showing 3 V at the cursor and
the schematic painting 30 V, no refusal, no warning"* — reached on a path V51
cannot see.

## The measured cause, at the statement

`cadence::_annot_db_print` returns `{}` when `xschem raw points` is `< 1`:

    if {![string is integer -strict $np] || $np < 1} { return {} }

`cadence::_annot_viewer_db` then still answers `[list $path {}]` — **length 2**,
so the consult reads as a success and the viewer's file wins. But the
fingerprint is empty, and the D5-1 compare in `cadence::_annot_tran_supply` is
gated on it:

    if {[llength $vprint] && [cadence::_annot_db_print] ne $vprint} {
      return [list $after viewerdiff $path]
    }

`[llength $vprint]` is `0`, so **the comparison never runs** and the supply
returns `ok`.

## The root conflation, and why it is one bug with 0895

`$vprint` is being used as a proxy for *"the consult succeeded"*, and it is
empty in **two** unrelated situations:

* there is no waveform window showing a transient for this sheet — the consult
  genuinely failed; and
* there is one, this is the file it is showing, but its fingerprint could not be
  computed.

Item A12's issue 0893 arm (`if {[llength $vprint]} { return [list -1
viewerunread $path] }`) inherits the same conflation, so this case also cannot
reach the truthful sentence. Issue **0895** is the third face of it.

## The shape of a fix

Have `cadence::_annot_viewer_db` say **whether it succeeded** as its own answer,
separate from the path and the fingerprint. Then:

* consult failed → today's fallback and today's `noraw`, unchanged;
* consult succeeded, fingerprint present → today's compare, unchanged;
* **consult succeeded, fingerprint absent → refuse.** The two windows cannot be
  compared, so no number may be published. RULING D5-1 is not satisfied by "we
  could not check"; it is satisfied by not painting. The sentence should say
  the waveform window is still filling and to try again when the run finishes.

Do **not** fix it by making the consult return `{}` on an empty fingerprint —
that would send this case to `noraw` ("no simulation results are loaded") with
traces on screen, which is issues 0893 and 0895 all over again.

## Rows

None. Row **V51** covers a *changed* file with a computable fingerprint on both
sides; nothing covers an **uncomputable** one. A fix owes a behavioural row in
both arms whose fixture is a zero-point transient in the waveform window and a
different, completed run at the same path — and it must leave V50 (the ordinary
consult) and V37 (no viewer at all) green.

## Related

* **0836** — the zero-point read that makes this reachable, and calls it ordinary.
* **0885** — the same compare, weak for a different reason (it samples the last
  point). 0885 is about a compare that runs and can miss; this is about a
  compare that does not run at all.
* **0895** — the third face of the same conflation.
