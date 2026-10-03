# 1641 — `test_fluid_editing` is registered only on the arm that runs nothing, and its display arm has been RED at `FE8`

**STAMP:** `v1 claim=partial tree=1271721f stamped=2026-10-03 fix=taken open=1`

⚠ **TWO OF THREE ITEMS CLOSED 2026-10-03** (`1271721f`), and the record of how is in
`doc/claude/code_analysis/1641_fe8_repair_and_the_dcases_registration.md`.
**Item 1, `FE8`'s aim — CLOSED.** Repaired red-first: a new row `FE8a` asserts the press landed
and was added *before* the press point moved; the press point is now computed from the arc
(4 px outward, biased inward by twice one pixel's worst-case angular rounding) rather than
written down. **Item 2, the registration — CLOSED.** A `dcases` entry landed in the same commit,
derived by lifting `summarize_all` out of `run_regression.tcl`'s own text: `cases` 124 → 125,
`blocks` 123 → 124, `wc -l` 371 → 374, `counted_failures` and `skips` unchanged, with
`planned_cases=125` agreeing independently. The `hcases` entry **stays**, as the crash guard.
Display arm 26 → **28** checks.
**Item 3, the product ruling on `find_closest_arc` — STILL OPEN**, and now filed as a `rule`
debt on the `owed.sh` ledger so the user can answer it. ⚠ One measurement sharpens it: derived
over `src/findnet.c`, **all five** `find_closest_*` functions scale their radial threshold with
`xctx->zoom`, and `find_closest_arc` is the **only** one that then adds a zoom-**independent**
predicate. A second mechanism also surfaced and is not in the original write-up:
`edit_arc_point` tests the `a+b` handle box **first**, and at `FE8`'s zoom the handle half-size
is 128.1 schematic units against a radius of 100, so the two handle boxes overlap nearly the
whole arc — escaping the `a+b` box needs an angle under 38.7° while one pixel spans about 7°.
⚠ **And the adversaries found a hole nobody assigned them**: a *constant garbage angle*
committed on every arc `a`-control-point drag **passed all 27 rows**, because the band asserted
that the angle CHANGED and not that it changed CORRECTLY. Closed by new row `FE8b`; rows
`FE3`, `FE3c` and `FE6` still carry that weakness at the default zoom and are **declared, not
fixed**.

Status: **PARTIAL**, found 2026-10-03 by the calculator batch while auditing which suites actually
gate a commit. Pre-existing, and independent of the Calculator.

Area: `tests/headless/test_fluid_editing.tcl` (the suite, rows `FE1`–`FE10b`, `FE7`, `FE8`),
`tests/run_regression.tcl` (`hcases`), `find_closest_arc` in `src/findnet.c` (open item 3).
Found: ran both arms of the suite and counted the rows each one executes.

## The defect

**The suite named after this project's public branch has 26 gesture rows, all 26 run only on the
display arm, and the display arm is registered nowhere.** It is in `hcases`, whose loop hard-codes
`--nogui`, where the suite self-skips to **zero** rows. So all 26 rows gate no commit — and one of
them has been failing.

Measured at this tree:

```
hcases entries                                     : 96
dcases entries                                     : 24
tcases entries                                     : 3
occurrences of "fluid_editing" in run_regression.tcl: 1   (one hcases entry, none in dcases)
```

96 + 24 + 3 + `xschemtest` is 124, the case count in the current baseline trailer, so the lists were
counted correctly. (Counted the way CLAUDE.md prescribes — locate `set hcases [list` by text, take
the bracketed quoted words. The naive `grep -c '"headless/'` and `grep -cE '\.log$'` spellings
miscount, and four registered entries are bare names living in `tests/` rather than
`tests/headless/`.)

### The two arms, measured

Display arm, `tests/headless/run_suites.sh test_fluid_editing` (attached to the dev display `:99`):

```
FAIL     | test_fluid_editing           run 1/1  RESULT: 1 FAILED (25 passed)
         | FAIL: FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean) (mod=0 a=30) : FAIL
RESULT: 0/1 runs passed
exit 1
```

Headless arm, `tests/headless/run_suites.sh --nogui test_fluid_editing`:

```
SKIP     | test_fluid_editing           run 1/1 (self-skipped: no X -- nothing ran)
RESULT: 0/0 runs passed (1 skipped)
exit 0
```

Scored over each arm's raw captured output:

| | display arm | `--nogui` arm |
|---|---|---|
| `ok:` / `FAIL:` lines (rows that ran) | **26** | **0** |
| exit code | 1 | 0 |
| `OVERALL:` line | `OVERALL: notok` | `OVERALL: ok` |
| `banner_complete` | 0 | 1 |
| last `RESULT:` line | `RESULT: 1 FAILED (25 passed)` | `RESULT: SKIP (no X)` |
| lowercase `^skip:` / uppercase `^SKIP` | 0 / 0 | 0 / **1** |

### What the gate sees, and why nobody noticed

`run_regression.tcl`'s own preamble to `dcases` says the `hcases` loop *"hard-codes --nogui, where
there is no Tk at all"*. So T1 runs this suite on the arm where its X gate fires first:

```tcl
if {!$HASX} {
  puts "SKIP: no viewable X window ($WIN) -- fluid-editing gesture test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
```

Exit 0, the completion banner present — so the case **passes**. `summarize_all` publishes a case's
last `RESULT:` line into the verdict, so the verdict block for this case reads `RESULT: SKIP (no
X)`, which is not a counted shape (it does not end in `FAIL`, `GOLD?` or `RESULT?`). The skip is
announced **uppercase**, and `summarize_all` counts `^skip:` lowercase, so it adds **0** to the
trailer's `skips=`. The verdict therefore carries the words *"SKIP (no X)"* and no number anywhere
says a registered case measured nothing.

⚠ **The suite's own header is how this happened**, and the sentence is still there: *"this test
SELF-SKIPS … when `.drw` is not viewable, and is **safe to register in hcases**"*. That is true as
a **crash guard** — the gesture path dereferences the absent `.drw` canvas and SIGSEGVs under
`--nogui`, so the gate must not run it there — and it was read as a registration decision. The
header then names a **bare** `./src/xschem --pipe -q --script …` as the way to *"run it for real
with a display"*, i.e. by hand. Nothing automates that, so the 26 rows have been hand-run only.

This is the same structural family as issues **1615**, **1626** and **1638**: fenced rows that are
display-only, a registration that only ever runs the headless arm, and a fence that therefore
measures nothing and rots. `banner_rule.tcl`'s own header records that one such defect was *"filed
FOUR times and waved through as furniture each time"*. `fluid-editing` being the branch the work is
meant to land on is what makes this instance the worst-placed one.

## `FE8` — the row is the suspect, and the behaviour it fences is intact

This is measured, not inferred, and the measurement took four probe variants because the row's own
failure detail is misleading.

`FE8`'s subject, in its own comment: *"an arc control-point drag that changes geometry must leave
the buffer MODIFIED even when the release snaps to the press cell. The arc move reference is its
CENTER (not the mouse), so the old 'release-cell==press-cell' no-op test wrongly reset the modified
flag to clean after a real change (a lost edit on close-without-save)."* Its predicate is
`$fe8_mod == 1 && ![feq $fe8_a 30]`.

It reports `(mod=0 a=30)`. **`a=30` is the arc's starting angle**, so nothing changed at all — this
is not the false-clean the row is written to catch (which would read `mod=0` with `a` *changed*). It
is "the gesture never happened".

Four variants of `FE8`'s own setup, run with `xschem get lastsel` read immediately after the press:

| variant | arc | press point | `lastsel` after press | result |
|---|---|---|---|---|
| **A** — `FE8` verbatim (drag away, drag back, release in press cell) | `a=30` | the row's own | **0** | `mod=0`, `a` stays 30 |
| **B** — one-way drag, released at the far point | `a=30` | the row's own | **0** | `mod=0`, `a` stays 30 |
| **C** — same gesture on the `a=0` fixture arc, its `(1300,0)` endpoint | `a=0` | endpoint | **1** | `mod=1`, `a` 0 → 95 |
| **D** — press the `a=30` arc's centre | `a=30` | centre | **1** | `mod=1`, `b` 90 → 45 |

**B is the one that rules out the row's own subject**: a drag that never returns to the press cell
fails identically, so the release-cell no-op logic is not involved. **C and D** show that arc
endpoint grab works and that *this* arc is selectable. The press simply misses.

### Why it misses, exactly

`FE8` zooms out with `xschem zoom_box -6000 -6000 6000 6000`, giving `zoom = 17.316`, at which the
arc's radius of 100 is **5.775 screen pixels**. `sch2scr` rounds to an integer pixel. So:

```
centre (1200,0)          -> pixel (416,346)
FE8's press (1286.6,-50) -> pixel (421,344)
pixel (421,344) maps BACK to (1290.0,-43.3) : r=99.9  angle=25.7 deg
the arc spans 30..120 deg
```

The point is on the ring (`r=99.9` against 100) and **4.3° short of the arc's start**, so it is not
on the arc. A scan of the 5×5 pixel neighbourhood puts the boundary exactly at the arc's own start
angle — `(+0,-1)` at 34° selects, `(+0,0)` at 26° does not — i.e. one pixel of `y` is 5–7° of this
arc.

The `a=0` fixture arc survives the identical rounding because the **sign** of the error points
inward: its endpoint `(1300,0)` rounds to a pixel that maps back to 4.6°, which is *inside* `0..90`.
For `a=30` the same rounding pushes the angle *below* 30, i.e. out. **So the failure is
deterministic and specific to an arc whose start angle is nonzero — which is the one thing `FE8`
deliberately chose** (`xschem arc 1200 0 100 30 90 4  ;# start angle a=30 (nonzero)`).

### The measurement that settles "row or product"

`FE8`'s own gesture, run from a press pixel **one pixel higher** — `(421,343)`, which lands inside
the span:

```
LAND post-press: lastsel=1 ui_state=40
LAND result: mod=1 arc=1200 0 100 64 90   (FE8 predicate would be 1)
```

**The product behaviour `FE8` fences is intact.** `mod=1` after a drag-and-return that changed the
arc — no false-clean. The row fails because its press point rounds off the end of the arc, and for
no other reason measured here.

### Archaeology

`FE8` was introduced by `2afe5d29` *("fix(fluid-editing): address adversarial-review findings on
C1–C3")*. The `zoom_box` line inside the `FE8` band was added later, by `ddc70a75` *("C4 polish —
fluid_editing toggle, endpoint tolerance, dispatch refactor")*, with the comment *"zoom out: big
grab zone + precise-enough endpoint select"*. **The zoom-out added to make the endpoint easier to
hit is what makes it unhittable** — see open item 3 for the mechanism. Whether `FE8` passed at
either of those commits is **not measured here**: it needs a build at each, which this crew did not
do.

## Open items

1. **Fix `FE8`'s press point, red-first.** The row must press a pixel that lies inside the arc's
   angular span. Two shapes, and the choice is a measurement rather than a preference: press the
   *interior* of the span (e.g. the midpoint at 75°, or the endpoint biased one pixel inward) and
   keep the zoom; or drop the `zoom_box` so the arc is large enough that one pixel is a fraction of
   a degree, which re-opens whatever `ddc70a75` added the zoom for and must be re-measured, not
   assumed. ⚠ **Whichever is chosen, assert that the press landed** — a row that checks only
   `modified` and the geometry cannot distinguish "the fix regressed" from "the click missed", which
   is exactly the hour this characterisation cost. `xschem get lastsel` immediately after the press
   is the readout; `FE8` currently has no such check, and nor do `FE1`–`FE10b`.
2. **Register the display arm in `dcases`, in the same change as item 1, and gate it.** The
   epilogue is **not** an obstacle: the suite emits a computed sentinel (`puts "OVERALL: [expr
   {$::fails ? {notok} : {ok}}]"`), one of the 13 computing suites row `RB4` of
   `test_registered_banner_1626` re-measures, so `banner_complete` is 1 on a green run and the 0 in
   the table above is only the current failure. ⚠ **Do not register before `FE8` is green**: a
   `dcases` entry today is a standing counted red in T1 — `banner_complete=0` and exit 1 — which is
   issue **1615**'s incident verbatim. Keep the `hcases` entry: it is the crash guard that proves
   the `--nogui` self-skip still works, and it costs no `skip:` because it announces uppercase. The
   trade-off is therefore *"26 rows gate nothing"* against *"one standing red until `FE8` is
   fixed"*, and the ordering that avoids both is item 1 first.
3. **A product question nobody has decided: `find_closest_arc` has zoom-scaled radial slack and
   zero angular slack.** In `src/findnet.c` the radial test is
   `threshold = CADWIREMINDIST*CADWIREMINDIST * zoom*zoom * tk_scaling*tk_scaling` — it grows as you
   zoom out — while the span test is exact, `angle >= angle1 && angle <= angle2`, with no tolerance
   at all. The consequence a user meets: the further out you zoom, the wider the ring you may click
   and the *narrower*, in screen pixels, the stretch of it that counts, until an arc's own endpoint
   is a pixel outside its own arc. Whether the span should get slack of the same order as the radial
   test (and whether the grab should then clamp to the nearest span end) is **user-visible
   behaviour** and so is the project owner's call, not a crew's. It is filed here because it is the
   mechanism behind item 1, and because `FE8` is evidence that it surprises people who know the
   code.

## What this is NOT

Not a claim that fluid editing is broken. 25 of the 26 rows pass on the display arm, and the
specific behaviour `FE8` fences was measured intact (see "the measurement that settles it").

Not a claim that `full_audit.sh` misses the suite: it globs `test_*.tcl` and runs it, on the Xvfb
arm, where it would see the `FE8` red. The claim is the narrower one CLAUDE.md says to make — **it
does not gate a commit**.

Not an instance of issue **1488** (`test_wave_markers` timing out when `run_suites.sh` attaches to
the dev display). This is a deterministic `FAIL`, not a `TIMEOUT`, and it reproduces identically
with the suite run directly on `:99`.

## Noted in passing, not part of the claim

`set ::RBTMP "/tmp/xschem_fluid_rb_[pid].sch"` puts the suite's geometry-readback scratch directly
in `/tmp`, which is tmpfs here, i.e. RAM. It is deleted at the end of a completed run and never
created on the self-skip path, so the only leak is from a run killed mid-way. Mentioned because
CLAUDE.md's *"your own scratch is charged to RAM until you delete it"* applies to suites too.

Nothing in the tree was changed for this issue beyond this file and `NUMBERING.md`'s pointer.

**What `tree=` means here, precisely.** Every figure above was taken against the **working tree** at
`580f7968`, which carried one uncommitted hunk in this suite from a sibling crew: a comment block
plus `source [file join [file dirname [info script]] scratch.tcl]`, arming the in-suite watchdog for
row `W20h` of `test_suite_watchdog_1403.tcl`. It is `+11` lines, it sits below the X gate, and it
touches neither the `FE8` band nor any helper `FE8` uses (`sch2scr`, `gpress`, `gmotion`,
`grelease`, `records`, `arc_geom`), so the `FE8` result is the committed suite's. Said plainly
because a reader re-measuring at a clean `580f7968` will get a suite that does not source
`scratch.tcl` and should not read that as a difference that mattered.
