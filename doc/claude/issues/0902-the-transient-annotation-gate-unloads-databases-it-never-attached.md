# 0902 — the transient annotation gate unloads databases it never attached

**Status:** RULING SETTLED 2026-08-29 (see the RULING section at the foot of this file) — it OVERTURNS the first draft above and IMPLIES A CODE CHANGE, not yet done. FIXED for the digital case in the same commit as issue 0900's repair (item A14); the headline defect remains LIVE for a foreign ANALOG database (a waveform graph on the user's own sheet).
**Filed:** 2026-08-28, by item A14's sabotage pass, reproduced in place on the
shipped tree by the repair pass.

## What the user sees

A design window is holding more than one results database — the ordinary
mixed-signal case is one analog transient plus one co-simulation VCD, the shape
`doc/claude/specs/mixed_signal_signal_browser.md` D5 is written about. The user
presses `Alt-Shift-6`. The waveform window has moved on to a newer run, so the
press correctly decides the numbers on the sheet cannot be believed and goes and
gets the run on screen.

On its way it takes **every** database off the window, including the VCD nobody
asked it about. The digital back-annotation the user had on their sheet goes
blank, and nothing says why.

## Measured

`cadence::_annot_tran_unwind` (utils/annot_mode.tcl) opened with a bare
`catch {xschem raw clear}`. `src/scheduler.c` documents that spelling verbatim:
*"if no file is given unload all raw files."*

Probe on the shipped tree, 2026-08-28, one window, two databases:

```
slots_after_both   = 2
free_rawfile(): clearing data
free_rawfile(): clearing data
slots_after_unwind = 0
xschem raw loaded  : 0  ->  -1
```

Before item A14 that call was reachable only on a press that had itself attached
the one database it then took off, so it could only ever destroy its own. A14's
new gate preamble calls it whenever **anything** is attached, so from that item
on it destroys other people's.

## The fix

`cadence::_annot_tran_unwind` now goes through `cadence::_annot_db_release`,
which

* takes off **one** database, by name — `xschem raw clear <file> <type>`, the
  spelling `ase::attach_dbs` (src/ase.tcl) already uses; and
* never takes off a **digital** one. RULING D5-3: a digital database publishes
  nothing to a schematic, `xschem annotate_op` refuses one before it loads
  anything, so this surface can never have attached a VCD and has nothing of its
  own to put back.

`cadence::_annot_tran_supply`'s "did my own read work" test moved from
`xschem raw loaded` to `cadence::_annot_db_analog_loaded` at the same time. With
a VCD legitimately left attached, `xschem raw loaded` answers 0 whether the
supplier's read worked or not, and the user would be told the file is "from a
different simulation run" when the truth is that it could not be read — a wrong
reason, which is the same defect class as a wrong number.

Rows: V72 and V73 (behavioural, both arms), V74 (structural).

## Boundary, stated rather than left to be discovered

`_annot_db_release` takes off the **current** database. A design window holding a
second, non-current *analog* database would keep it. No shipped path puts one
there — every VCD attach in the tree runs inside the waveform window's own
context, and `xschem annotate_op` replaces rather than appends — so this is the
edge of the claim, not a known defect.

The same bare `xschem raw clear` is still in the operating-point surface's 0872
unwind (utils/annot_mode.tcl, in `cadence::annot_mode`). It is **not** changed
here and it is not the same defect: that arm is reachable only when
`xschem raw loaded` was < 0 on entry, so it can only ever take off the database
that press attached itself.

## RULING — 2026-08-29, decided under the user's "decide the 23" instruction

**Option (a) as shipped is RATIFIED, and it is now the rule for every surface
that takes results off a window, not a local choice made here.**

> When `Alt-Shift-6` decides the numbers on the sheet can no longer be believed
> and goes to fetch the run the waveform window is showing, it takes off **the
> one database it is replacing, named explicitly** (`xschem raw clear <file>
> <type>`), and **never a digital one**. It does not take off every non-digital
> database (option b) and it never goes back to the bare whole-registry
> `xschem raw clear` (option c). Any future surface that detaches results
> inherits this: take off only what this press attached, by name.

**Why this is not a trade-off the user had to weigh.**

* **Cadence.** In Virtuoso, results you have loaded stay loaded. Annotating
  operating points or transient values at a cursor replaces *its own* numbers; it
  does not close the other results in your session. Options (b) and (c) both
  close results the annotation never opened. That settles it on the standing
  CADENCE OR NOTHING ruling alone.
* **The stated cost of (a) cannot produce a wrong number.** The boundary above
  says a second, non-current *analog* database would be kept, so the supplier's
  `xschem annotate_op` could **switch** to a stale run rather than re-read the
  file. Traced end to end: that press can only get past the gate because the
  waveform window disagreed, so `$vseen` is 1, so
  `cadence::_annot_tran_supply`'s two-window compare
  (`[cadence::_annot_db_print] ne $vprint`) runs unconditionally and returns
  `viewerdiff` — a refusal, with the sheet bare. The corner is at worst a
  spurious refusal in a state no shipped path reaches, never a number displayed
  next to a thing it was not measured for. If a second reachable analog database
  ever appears, that is a new measurement and a new issue.
* **The sibling surface already agrees.** The operating-point unwind in
  `cadence::annot_mode` has since split the same way for issue 0914: the bare
  clear survives only where the registry was empty when the key was pressed, and
  every other path goes through `op_annot::db_detach`. Ratifying (b) or (c) here
  would put the two surfaces back into disagreement.

**One correction to this file's own prose, which does not change the ruling.**
"The digital back-annotation the user had on their sheet goes blank" overstates
what a VCD can do to a schematic: mixed-signal RULING D5-1 says a digital
database publishes **nothing** to the sheet's voltage overlay, and
`xschem annotate_op` refuses one outright. What the bare clear actually
destroyed is the **loaded co-simulation results themselves** — readable through
`xschem raw value` (which is what row V72 leg 7 measures), plotted by any
waveform graph drawn on the sheet itself (the loss issue 0914's note names), and
listed by the signal browser. That is still data loss, and it is still the reason
the ruling goes this way.

**Verified in the tree, 2026-08-29** (read-only; no build, no suite run):

* `src/op_annot.tcl:1221-1233` — `op_annot::db_detach` reads `xschem raw
  rawfile` / `sim_type`, returns 0 on `xschem raw is_digital`, and clears by
  name. `utils/annot_mode.tcl:1844-1846` — `cadence::_annot_db_release` is the
  one-line delegate; `:2290-2298` — `_annot_tran_unwind` calls it.
* `src/scheduler.c:10369-10372` — `xschem raw clear` with no file "unload[s] all
  raw files"; `src/save.c:1797+` — `extra_rawfile()` `what==3` with no file frees
  every slot, and the `what==1` read arm appends and switches, which is what
  makes the "switch to a stale run" corner real in principle.
* `src/scheduler.c:2460-2481` — the `annotate_op` arm refuses a digital file
  *before* anything is loaded or cleared (D5-3 enforcement point 2).
* `src/ase.tcl:2100-2148` — `ase::attach_dbs` leaves exactly ONE analog database,
  current, plus N VCDs non-current; `src/wave_viewer.tcl:3715-3730` —
  `wviewer::attach_raw` does `wviewer::switch_ctx` first ("never clear a foreign
  ctx"), so every shipped VCD attach happens in the waveform window's context.
* `utils/annot_mode.tcl:2173-2176` — the two-window compare, gated on `$vseen`,
  which is what makes the boundary harmless.
* `tests/headless/test_op_annot.tcl:15014-15236` — rows V72, V73, V75
  behavioural and V74 structural exist and assert the named-clear spelling, the
  digital skip, and the supplier asking `_annot_db_analog_loaded`.

**Code change: NONE.** This ratifies what already ships.

## RULING, 2026-08-29 — decided on the user's instruction

> **"decide the 23, leave 0861 and 0299 for me"** — the user, 2026-08-29.

The ruling queue had reached 57 entries and the user said the reading burden was
too heavy. A read-only audit classified 25 of them as questions whose answer is
cheap and obvious — things that should be DECIDED, not put to the user. **This
debt was one of those 23.** (0861 and 0299 stay with the user.)

⚠ **This section SUPERSEDES the earlier `## RULING — 2026-08-29, decided under
the user's "decide the 23" instruction` section above.** That section was a first
draft; it ratified option (a) and closed the issue with "Code change: NONE". An
adversarial pass overturned it. It is left above, unedited, as the record of what
was tried — but the decision below is the one that stands.

### The ruling

**Keep option (a)'s two wins — the named clear and the never-a-digital-one skip —
and add the term that is missing: a press takes a results database off the window
only when it OWNS it or is REPLACING it.**

> When `Alt-Shift-6` decides the numbers on the sheet can no longer be believed
> and goes to fetch the run the waveform window is showing, it may take a results
> database off the design window in exactly two cases:
>
> 1. **This surface put those numbers there** — `xschem raw annot` says so; that
>    is the `op_annot::_annotated` term the operating-point sibling already uses
>    as its guard at `src/ase_window.tcl:2386-2389`; or
> 2. **It is the very file the press is about to replace** — the path the
>    waveform window just named, which the press is about to re-read from disk.
>
> **Anything else is left alone**, and the press attaches its own results
> *beside* it. A run the user loaded into a waveform graph drawn on the schematic,
> a co-simulation VCD, anything another window attached: untouched. This holds on
> a **refusal** too — a press that ends in "that file is no longer on disk" must
> leave the window holding exactly what it was holding when the key went down.
>
> It is still `xschem raw clear <file> <type>`, never the bare whole-registry
> `xschem raw clear` (option c), and never "take off every non-digital database"
> (option b). Any future surface that detaches results inherits this: **take off
> only what this press attached or is replacing, by name.**

In what the user sees: **pressing `Alt-Shift-6` to pick up a newer run takes off
the numbers it put on the sheet and the run it is replacing, and nothing else.
Results you loaded yourself — a co-simulation run, or a waveform graph you drew
on the schematic — stay loaded, including when the press ends in a refusal.**

### Why

* **CADENCE OR NOTHING.** In Virtuoso the results you have loaded stay loaded.
  Pointing ADE at a different run does not close the data in your plot window.
  Options (b) and (c) both close results the annotation never opened, so neither
  is Cadence-compatible; (c) is the data loss this issue was filed on. But option
  (a) *also* still closes one, which is why it is not the whole answer.
* **This issue's own headline is still true for analog results.**
  `op_annot::db_detach` (src/op_annot.tcl:1221-1233) never asks who attached
  anything: it reads whatever is **current** and clears that. Currency was being
  used as a stand-in for ownership, and the stand-in is false. Take the ordinary
  bench — a waveform graph drawn on the schematic itself, loaded with one run,
  while the waveform window shows another. The two disagree, the gate opens,
  `_annot_tran_unwind` runs *before anything has been attached*, and the user's
  graph is cleared by name. If its path differs from the waveform window's it
  does not come back: the supply loads the window's file, not theirs.
* **INTENT OVER MECHANISM, at its sharpest on a refusal.** Row V73 face (a)
  stages the waveform window's file being deleted: the gate opens, the unwind
  runs, the press then refuses with `viewergone` and a bare sheet. Today that
  refusal also takes the user's own graph off the window. A press that could not
  deliver anything, destroying results it was never asked about, and saying
  nothing — that is exactly the shape the standing ruling forbids.
* **The sibling surface does not already agree — it disagrees in the
  load-bearing place.** `ase::ui::annot_ensure_loaded`
  (src/ase_window.tcl:2386-2389) guards its `op_annot::db_detach` with `$ann`,
  and its GUARD G13 says why in the tree: that database "is not something this
  surface attached or can paint from, so defect B is repaired by ADDING ours
  beside it, not by destroying theirs." G13 also warns that without a dedicated
  row, an unconditional detach "still renders the numbers ... so every other gold
  in every suite is satisfied while the trace the user was looking at has been
  unloaded from under their waveform window." That paragraph describes the
  transient gate as it ships today.
* **The earlier draft inspected the wrong corner.** Its boundary paragraph worried
  about a *second, non-current* analog database. The reachable hole needs no
  second database: it is the **first and only one being somebody else's**.

### The one honest cost, recorded rather than discovered later

When the sheet graph and the waveform window name the **same file**, leaving it
attached makes `xschem annotate_op` switch to the in-memory copy instead of
re-reading it (`src/save.c`, `extra_rawfile()` `what==1`: *"file found: switch to
it"*), which ends in a spurious `viewerdiff` refusal. **That is why the second
half of the guard is keyed on the path being replaced**: same path, take it off
and re-read; different path, hands off. This is the same tension
`op_annot::db_attach`'s G6 already navigates for issue 0685, and it is settled
here the same way rather than re-argued.

### One correction to this file's own prose, which does not change the ruling

"The digital back-annotation the user had on their sheet goes blank" overstates
what a VCD can do to a schematic: mixed-signal RULING D5-1 says a digital
database publishes **nothing** to the sheet's voltage overlay, and
`xschem annotate_op` refuses one outright. What the bare clear actually destroyed
is the **loaded co-simulation results themselves** — readable through
`xschem raw value` (which is what row V72 leg 7 measures), plotted by any
waveform graph drawn on the sheet, and listed by the signal browser. Still data
loss, still the reason the ruling goes this way.

### Verified in the tree, 2026-08-29 (read-only; no build, no suite run)

* `src/op_annot.tcl:1221-1233` — `op_annot::db_detach` reads `xschem raw
  rawfile` / `sim_type`, returns 0 when `xschem raw is_digital` is 1, and clears
  by name. **It never consults `xschem raw annot`,** i.e. it has no notion of who
  attached the database. This is the gap the ruling closes.
* `utils/annot_mode.tcl:1844-1846` — `cadence::_annot_db_release` is a one-line
  delegate to `::op_annot::db_detach`; `:2290-2298` — `_annot_tran_unwind` calls
  it unconditionally once `$attached` is true, i.e. **before** the supply has
  attached anything of its own. No bare clear remains on this path.
* `src/ase_window.tcl:2386-2389` — the sibling's guard is
  `set ann [::op_annot::_annotated]` … `if {$ann} { ::op_annot::db_detach }`;
  `op_annot::_annotated` (src/op_annot.tcl:791-797) is `xschem raw loaded` >= 0
  **and** `xschem raw annot` >= 0. That second term is the ownership test the
  transient gate is missing.
* `utils/annot_mode.tcl:1302-1330` — the operating-point (0872/0914) unwind
  splits on `$entry_loaded`: bare clear only when the registry was empty on
  entry, otherwise `::op_annot::db_detach`. Note this is **not** the same shape:
  there the detach is reached in a state where currency and ownership coincide;
  on the 0900 gate the unwind runs before the supply, so there is no ownership
  at all.
* `src/scheduler.c:10369-10372` — `xschem raw clear` with no file "unload[s] all
  raw files"; `src/save.c` `what==3` no-file arm frees every slot, confirming the
  measured 2 -> 0 above.
* `src/save.c:1907-1950` — `extra_rawfile()`'s `what==1` read arm APPENDS when
  `(file,type)` is not already registered, and otherwise does *"file found:
  switch to it"* with **no disk read**. That is the same-path cost recorded above.
* `src/scheduler.c:2460-2481` — the `annotate_op` arm refuses a digital file
  before anything is loaded or cleared, so this surface can never have attached a
  VCD (the D5-3 premise the digital skip rests on). The digital skip stays.
* `src/ase.tcl:2100-2148` — `ase::attach_dbs` leaves exactly one analog database
  current plus N VCDs non-current; `src/wave_viewer.tcl:3715-3730` —
  `wviewer::attach_raw` switches context first ("never clear a foreign ctx"), so
  every shipped VCD attach happens in the waveform window's context.
* `utils/annot_mode.tcl:2173-2176` — the two-window compare, gated on `$vseen`.
* `tests/headless/test_op_annot.tcl:15014-15236` — rows V72, V73, V75
  (behavioural) and V74 (structural) exist. **Every one of them stages the
  foreign database as a VCD.** Not one stages a foreign *analog* database, which
  is why the suites are green over the hole — exactly as GUARD G13 predicted.

### This IMPLIES A CODE CHANGE — follow-up work, NOT YET DONE

1. **Guard the detach.** In `cadence::_annot_tran_unwind`
   (utils/annot_mode.tcl:2290-2298), stop calling `cadence::_annot_db_release`
   unconditionally. Take the database off only when (i) `xschem raw annot` shows
   this surface published the numbers on it — the `op_annot::_annotated` term the
   sibling already uses — or (ii) its file is the very path the waveform window
   just named and the press is about to re-read. Otherwise leave it and let the
   supply attach beside it. Keep the named `xschem raw clear <file> <type>`
   spelling and the digital skip exactly as they are.
2. **A row that can see the hole.** Add a row staging a **foreign ANALOG**
   database — a waveform graph drawn on the sheet, loaded with a different run
   from the one the waveform window is showing — and assert that graph is still
   in the registry after **both** a successful press **and** a `viewergone`
   refusal. Without it, item 1 is untestable and a regression is invisible;
   with the VCD-only rows we have, an unconditional detach passes everything.
3. **Correct the user-facing sentence.** The line published with the superseded
   draft — *"your co-simulation (digital) results and anything else you loaded
   stay put"* — is **not true today**: an analog run the user loaded into a sheet
   graph does not stay put, and when its path differs from the waveform window's
   the press is not replacing it, it is simply deleting it. That promise becomes
   true only when item 1 lands, and the sentence should ship with it, not before.

Until items 1-3 land, this issue is **fixed for the digital case only**; the
headline "unloads databases it never attached" remains true for an analog one.

**An adversary ran against the first draft of this ruling and OVERTURNED it** —
option (a) repairs the digital half only, `op_annot::db_detach` never asks who
attached anything, and a waveform graph on the user's own sheet is still
destroyed by the same key press; the ruling above is the adversary's better
answer, adopted in full.

**The user may reverse this at any time; it was decided to spare their attention,
not to bind them.**
