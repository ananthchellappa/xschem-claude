# 0896 — the two-window compare is skipped while a simulation is still filling, and another run's numbers land on the schematic

**Status:** ✅ **FIXED 2026-08-28 (item A13), together with issue 0895 — they
are one conflation wearing two faces.** First measured 2026-08-28 at the item
A12 write-up, on **both** arms, and re-measured independently before the fix.
**It was a live RULING D5-1 violation** — a number that was not measured for the
thing it is displayed next to reached the schematic, under an authoritative
caption, with no refusal and no warning.

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
* **0900** — the *unconsulted* path onto the same D5-1 room, still open: an
  already-attached database skips the supplier and with it this compare, so
  `d 21 g 0.1` remains reachable on a second press. Filed with the A13
  write-up; not fixed by A13.
* **0901** — the sentence this fix minted gives the wrong remedy when the run
  has finished behind the waveform window's back. Filed with the A13 write-up.

## The fix, as it shipped (item A13, 2026-08-28)

`utils/annot_mode.tcl`, three edits and no C change:

1. **`cadence::_annot_viewer_db` now classifies its own answer.** It returns
   `{path print why}` where `why` is `ok`, `filegone` or `nopoints`; a bare
   `{}` is reserved for the one meaning it should always have had — *no
   waveform window is showing a transient for this sheet*.
2. **`cadence::_annot_tran_supply` keys every guard on `$vseen`**, a separate
   flag saying the consult succeeded, and refuses `nopoints` with the new state
   **`viewerfilling`** *before* the `annotate_op` hand-off. The two-window
   compare is now gated on `$vseen` rather than on `[llength $vprint]`, so it
   **cannot be skipped once the supplier runs**, rather than merely being
   unlikely to be. ⚠ Read that scope literally, and see issue **0900**: the
   supplier itself is called only when the design window holds no database, so
   a *second* press — the design window still holding what the first press
   attached — skips the consult, both new guards and this compare together. An
   earlier revision of this bullet, of the code comment and of the spec claimed
   a skipped compare was "structurally impossible" full stop. That was an
   overclaim, it is corrected in all three places, and the remaining door is
   filed as 0900 rather than left to a future reader to rediscover.
3. **`cadence::annot_tran`** dispatches the new state above `set attached 1`, so
   nothing is ever attached, no unwind is owed, the mask is untouched and the
   sheet stays bare.

### The driver's option 2, answered rather than skipped

The driver ruled *"prefer what the waveform window already holds in memory, and
caption it"*. It is **not reachable here and the reason is measured**: on a
zero-point transient the viewer's memory holds **zero samples** — every other
term of `cadence::_annot_db_print` succeeds (`sim_type` tran, `datasets` 1,
`list` 6 columns, `value v(d) -1` = 0) and only `points` = 0 fires the `np < 1`
test. There is nothing to prefer. So option 3 (refuse and say why) is what
option 2 **degenerates to** in this case, not a shortcut past it.

### Before / after, same fixture, both arms

| | before | after |
|---|---|---|
| state | `ok` | `viewerfilling` |
| mask | `4` (transient bit armed) | `0` |
| `xschem raw loaded` | `0` | `-1` |
| painted | `d 21 g 0.1 0 0.0 0 0.0` — **another run** | nothing |
| sentence | *Showing each node's voltage at 3 ns, where cursor B is on the waveform.* | *The waveform window is showing the results file v_a10_vrun.raw, but the run has not produced any values yet, so nothing was placed on the schematic. Wait for the simulation to finish, then try again.* |

### A third face closed for free

Measurement **M4**, recorded in neither issue file: a run still filling with
**nothing** overwritten — viewer and disk holding the same zero-point file —
answered `ok`, armed the transient bit and printed *"Showing each node's voltage
at 3 ns"* over a **completely bare** schematic. A live false success on its own.
The same repair closes it before `xschem annotate_at` is reached, so
`backannotate_at_time()`'s unconditional `1` (issue 0888) needed no change.

### Rows

* **V58** — the acceptance: zero-point file in the waveform window, the
  finished DIFFERENT run at the same path. Ten legs, including a non-vacuity
  control proving the decoy really does paint 21 V through the product's own
  supply, and an explicit leg that `d 21 g 0.1 0 0.0 0 0.0` is **not** on the
  sheet.
* **V59** — the quieter face above (nothing overwritten).
* **V62** — structural: the consult classifies, the supplier never reads
  `llength $vprint` again, the compare line carries `$vseen`, and both new
  refusals return **before** the first `annotate_op` (a line-index comparison,
  which is the "no unwind owed" invariant made measurable).
* **V63** — the consult's four answers asked directly, in both arms.
* **B12h** (`tests/headless/test_annot_show_menu.tcl`, display arm) — the same
  scenario through the product's own `wviewer::open` + `wviewer::attach_raw`,
  i.e. the real supply chain rather than a hand-built state.
* **V42d / V42c / V42c2 / V43 / V52 / V53 / A11-7 / A11-11** — the sentence,
  the roll-call, RULING D5-4, the unwind roll-call and the plain-English sweep.

V50 (the ordinary consult), V51 (the compare that does run) and V37 (no viewer
at all) are all still green, in both arms.
