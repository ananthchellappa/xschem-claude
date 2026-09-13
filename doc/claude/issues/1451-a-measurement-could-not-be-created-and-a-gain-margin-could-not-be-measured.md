# 1451 — a measurement could not be created, and a gain margin could not be measured

**Status:** fixed
**Branch:** `fluid-editing`
**Area:** ASE-L — the Measurements sub-dialog, the template picker and the
Value column (`src/ase_window.tcl`); the template SHAPE and the one-line handle
renderer (`src/ase.tcl`, `ase::`); the eight templates and the 19th kind
(`src/ase.tcl`, `ase::backend::ngspice::`)
**Suites:** `tests/headless/test_ase_dialogs.tcl` section **MS** (display arm),
`tests/headless/test_ase_core.tcl` section **MT** (both arms),
`tests/headless/test_ase_meas_1443.tcl` section **TP** (both arms)
**Batch:** `doc/claude/ase_analyses_batch/`, Stage 8 task 2 (`PLAN.md` §8b)
**Rulings:** ⚖ **R9** (every new sentence below), ⚖ **R6** (the handle the
dropdown writes), ⚖ **R5** (the form remembers)

---

## The defect

**Issue 1443 shipped the whole deck half of Stage 8 and built no widget.** A
`measurements` state list, eighteen kinds, a four-verdict refusal evaluator, the
`meas` speller, five producers and a sidecar — and:

* nothing in the tree read a kind's `label`, so all eighteen were declared and
  shown nowhere;
* `ase::meas_report` had **no caller anywhere in the tree**;
* `grep -rn 'measurements' src/ase_window.tcl` returned **nothing**, so a user
  could not create one measurement row without hand-editing a `.state` file.

Two of the six benchmark ADE-L tasks — *read back the phase margin*, and the
spread of one measurement over 200 runs — still ended at *"you are on your
own"*, which is the bar `PLAN.md` opened by condemning.

---

## ⚠ AND THE PLAN'S GAIN-MARGIN LINE ANSWERS NOTHING

`PLAN.md` §8b's table writes the gain margin as

```
meas ac gm find vdb(out) when vp(out)=-180
```

**Measured 2026-09-13 on BOTH binaries** — `/usr/bin/ngspice` (apt 45.2) and
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (the fork) — on a three-pole
amplifier whose phase really does pass through −180 (60 dB, UGF 915 kHz, two
poles at 3 MHz):

```
meas ac gm FIND vdb(out) WHEN vp(out)=-180
    -> Error: measure  gm  find(AT) : out of interval        (both binaries)

meas ac gm FIND vdb(out) WHEN cph(v(out))=-180
    -> Error: no such vector as cph(v(out)).                 (both binaries)

let gmph = cph(v(out))
meas ac gm FIND vdb(out) WHEN gmph=-180
    -> gm = -1.556922e+01   at f = 3.001137e+06              (both binaries)
```

**Two separate facts, and the first is the sharper one.**

1. **`vp()` is WRAPPED.** On that same sweep the point whose *continuous* phase
   reads `-2.36596e+02` has `vp(out)` reading `+1.234040e+02`. So −180 is exactly
   the discontinuity: the value never crosses it and no crossing detector can
   ever see it. A gain margin written against `vp()` is silent on every
   amplifier it is for.
2. **`meas`'s `WHEN` operand must be a vector NAME, not an expression.** So the
   unwrapped phase has to exist as a named vector first.

---

## ⚠ AND THE 57.2958× TRAP, MEASURED ON THE FINAL NUMBER THIS TIME

Issue 1443 measured the radians trap through one `meas` line. This item measured
it **through the whole rendered block**, twice, on both binaries — the same deck
with and without the one line `ase::opt_line` emits:

```
with `set units=degrees`      pm = 5.614170e+01      <- 56.1 degrees
without it                    pm = 1.778383e+02      <- 177.8, rc 0, nothing said
```

A 56-degree phase margin reported as 178, at exit code 0, with the gain-margin
row silently vanishing beside it. That is the number the Measurements pane now
shows, and `test_ase_meas_1443` row **TP3b** is the row that is about the
**number** rather than about the deck line: it renders the block, decides from
the block which of the two measured runs it would have been, and asserts 56.

---

## The fix

### 1. The Measurements sub-dialog — `Outputs > Measurements…`

A list with an **Enable / Name / Kind / Analysis / Value** grid, Add / Delete /
Up / Down, a **Kind picker** rendering the adapter's own declared labels, a form
built from the picked kind's declared fields, a **`Measured on`** control so a
row measured on a producer's plot is showable, and the selected row's **verdict
sentence** under it.

* **The commit model is `Options…`'s, not Choose Analyses'.** A working copy of
  the whole list lives in `ase::ui::dlg($key,mrows)` and **OK writes it back in
  one `ase::session_update`**. Choose Analyses' per-row cache exists because that
  dialog edits ONE row of a list it never otherwise touches (`GR6e` holds that
  line and nothing here widens it); a list editor that must reorder and delete
  cannot be built that way.
* **What it does inherit from ⚖ R5 is the remembering, through one door.**
  `ase::ui::meas_harvest` reads the live form into the working copy, and every
  rebuild — picking another line, changing the kind, Add, Delete, a move, OK —
  goes through it first.
* **The analysis is picked by HANDLE.** The row stores `id <handle>` — ⚖ R6's
  word, `ase::analysis_handles`' answer, the same string the Choose Analyses grid
  shows and `Analyses > List` prints — **never `row <index>`**. That closes
  issue **1444**'s first surface (*"pick, don't type"*).

### 2. The eight named templates

`ase::backend::ngspice::meas_templates`, with the SHAPE in core
(`ase::meas_template_expand` and friends). The user picks one, fills two or three
fields, and the rows it writes are **ordinary measurement rows afterwards** —
nothing remembers which template made them.

**`@n@`, the batch suffix, is the load-bearing part.** A template writes rows
that refer to each other — a phase margin is three rows deep and ends in
`let pm = 180 + pmph` — so one suffix is chosen for the WHOLE batch and the
template spells it into both the names it mints and the references it makes. A
second phase margin on one bench becomes `ugf2` / `pmph2` / `pm2`, with
`let pm2 = 180 + pmph2`.

### 3. The Value column

`ase::meas_results`' answer, rendered. **The number is the simulator's printed
text, verbatim** — measured on both binaries, apt 45.2 prints `9.149274e+05`
where the fork prints `9.14927e+05` for the same measurement — and **a failed
measurement renders its sentence**, because an empty cell reads as zero and a
failed `meas` is silent on every other channel (rc 0, `$sim_status` 0, no vector,
`print` prints nothing).

### 4. `ase::meas_report` finally has a caller

`ase::ui::run_finished` appends it to the run log. It is silent on a bench with
no measurement rows, which is why no committed bench's log moves.

---

## Three corrections to `PLAN.md` §8b's table

| # | the plan | what shipped, and why |
|---|---|---|
| **1** | `meas ac gm find vdb(out) when vp(out)=-180` | it answers nothing — `vp()` is wrapped. The template emits `let gmph = cph(v(out))` (the 19th kind, `cphase`) and measures against that vector |
| **2** | phase margin names two rows `pm` (`meas ac pm find …` + `let pm = 180 + pm`) | ASE-L refuses a duplicate name outright — the sidecar lookup is case-insensitive and the second answer would silently overwrite the first. The measured phase is `pmph@n@` and the margin is `pm@n@` |
| **3** | *"Slew rate"* emits `trig … targ …`, which answers **seconds** | reporting a time under the name `sr` is the silent-wrong-answer class this batch exists to delete. The template writes the delay as `srt@n@` and a `param` row `sr@n@ = (hi - lo)/srt@n@` beside it |

and one to §8b's *"fills two fields"*: three of the eight need a third
(`-3 dB bandwidth` the passband gain, `THD` the fundamental, `Settling time` the
final value and tolerance, `Slew rate` the two levels). Named here rather than
trimmed, because the missing field is the one that decides the answer.

---

## The 19th kind, and the two shipped rules it moved

`cphase` — *Unwrapped phase* — is a `meas`-form `letform` kind that
**`yields vector`**. It is not a user-facing measurement: it exists so a gain
margin has a vector name to ask about. Two of issue 1443's own rules moved with
it, both narrowly and both measured:

* **`meas_group` prints a `let`-form row only when its kind yields a NUMBER.**
  A `print gmph` would put one line per frequency point into the sidecar.
  `ase::meas_kind_yields` is the question a producer already answers for exactly
  this reason, and `ase::meas_results` reports such a row as `produced` rather
  than complaining that the simulator said nothing about it.
* **`ase::meas_schema_errors` now permits `yields` on a `letform` kind** as well
  as on a producer. The sentence moved with it and `KN4b` carries both halves.

⚠ And `ase::backend::ngspice::meas_needs_degrees` gained a **kind** clause: a
`cphase` row reads a phase without spelling one, and `cph()` is evaluated under
whatever `units` is in force at that moment. Without the clause the gain margin
below it would look for −180 in a vector whose values run to −4.7.

---

## What is still owed

* **`owed.sh add rule 1451`** — every new sentence is ⚖ R9's; the receipt lists
  them verbatim.
* **`owed.sh add look ase_measurements_dialog_1451`** — a whole sub-dialog, a
  template picker and a new column are pixels. **Suites green, please look.**
  `PLAN.md` §8's *"no look debt is filed"* is the stale half of that paragraph,
  decided by measurement exactly as the ledger asked.
* **`owed.sh add suite test_ase_dialogs`** — one `:0` run before the feature is
  called done.
* **`Settling time` reports two rows and no single answer, DELIBERATELY** —
  and this is now measured rather than deferred. `tslo@n@` and `tshi@n@` are the
  two band edges. Measured 2026-09-13 on both binaries:

  ```
  let m1 = max(a,b)          -> m1 = 7.000000e+00   BOTH binaries
  let m2 = (a > b) ? a : b   -> apt 45.2: PPerror: syntax error in line segment
                                          Error: RHS "(a ? a : b" invalid
                                the fork: m2 = 7.000000e+00
  ```

  So a third `param` row `ts@n@ = max(tslo@n@, tshi@n@)` **would** be portable —
  and it is still not shipped, for a reason the measurement made visible: a
  step that does not overshoot never crosses the upper edge, `tshi` then fails,
  and `let ts = max(tslo, tshi)` fails with it. **The single number would vanish
  in exactly the common case**, taking the one edge that WAS measured with it.
  Two rows, both reported, is the robust shape.

  ⚠ **And the ternary is a NEW two-binary difference**, of the class
  `evidence/binary-differences.md` exists for: `? :` inside `let` is a
  **fork-only** feature and is a hard syntax error on the binary a downloading
  user has. Nothing in ASE-L emits one today; recorded so nothing starts.
