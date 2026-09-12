# 1417 — the form offered an entry for everything, and said "Points:" for both AC sweeps

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C4** of Stage 3 of `doc/claude/ase_analyses_batch/`.

## What ships

The **typed form**. `ase::ui::chana_field_row` builds each control from its declared `kind`;
`ase::ui::form_label` puts the declared label and its unit on it; `ase::ui::chana_mode_changed`
relabels a mode field's declared neighbour; `ase::ui::chana_adv_toggle` hides the optional fields
behind `▸ Advanced`. New: `ase::ui::chana_form`, `ase::ui::form_has`, `ase::ui::form_get`,
`ase::ui::form_is_absent`, `ase::ui::dialog_status`. `chana_ok` refuses **in the dialog** and
**focuses the offending widget**.

## The defect this is named for

`dec 10` is ten points **per decade**. `lin 10` is ten points **in total**. `lin 2` yields
**one point**. The form said `Points:` for all three, because every field of every type was an
`entry` labelled `[string totitle $f]:` — no unit, no hint, and a bool the user had to know to type
`1` into.

A `mode` field now declares `relabels <field>`, and the field it governs declares a `labels` table
keyed by the mode's value. `ase::ui::dialog_row` already names its label `$w.l$ename`, so the whole
operation is one `configure`.

⚠ **The relabel runs at build time as well as on a pick.** Otherwise the form opens reading
*Points per decade* for a bench that stored `lin` — which is the exact sentence the relabel exists
to stop being wrong.

## The write-back rule, and it is a byte-identity rule

**A field writes a key only when its value differs from what the deck would have said without it.**

⚠ **This was measured the hard way, twice, inside this commit.** Making `uic` a checkbutton made it
answer `0` where an untouched entry answers the empty string, so the door stored `uic 0` — a key
**none** of the 104 committed benches carries. Making `sweep` a combobox has exactly the same shape:
it answers `dec` where a bench stores nothing, and `dec` is already what the emitter resolves from
the field's own `default`. Neither key changes a single deck line, and both break the round trip this
batch is measured against **the first time a user opens the dialog and presses OK**.

So "absent" is a per-field question: empty for a text field, **off** for a bool, and **the declared
default** for anything that has one.

## Where a refusal appears

Before this, a refusal went only to `ase::echo` — the action log, which lands in **another window**.
From the user's seat, OK "did nothing". It now also writes the sentence to the dialog's own status
line, and **focus lands on the offending widget**: measured, there was no `focus` call anywhere in
`ase::ui::choose_analyses` or any proc it calls.

⚠ **The refusal does NOT rebuild the form to reach a hidden field.** `chana_show` destroys and
recreates every widget, so a door that reopened the disclosure to point at a field behind it would
**discard everything the user had typed in order to show them what was wrong with it**. The sentence
says *"It is under Advanced."* instead. A **group** offence names no widget at all, so it focuses
nothing — it names the group, because naming one of its three empty fields would send the user to
fill that one and leave the other two missing.

## A defect C3 shipped, that only building the control could find

⚠ **`ase::analysis_emit_check`'s number check was a DENY-list, and issue 1416 gave it a field whose
legal values are words.** It read *"parse anything that is not one of two named kinds"*. `sweep` is
`kind mode`, its values are `dec`, `oct` and `lin`, and every one of them came back
`bad notanumber` — so a bench storing `sweep lin` was refused at the gate with

> cannot read 'lin' as a number for 'sweep'

**a control the window offers and the gate then rejects**, which is precisely the shape this whole
batch exists to delete. No committed bench stores a `sweep` key, so nothing in the corpus rows
noticed; it took building the combobox and pressing OK.

It is now an **allow-list**: `real`, `int`, `time`, `freq`. A deny-list is wrong here by
construction — it assumes every kind nobody has thought of yet is numeric, so the next `kind` any
adapter invents is born broken, and born broken in the direction that **refuses legal work**. Row
**GR8** pins the set of declared kinds, so adding one is a decision somebody makes rather than a
default somebody inherits.

## The disclosure is remembered for the window, and that is a choice

`advopen` is keyed by the window and outlives any one opening of the dialog, so a user who reaches
for `tmax` once does not reach for the triangle again every time. The cost is that
`chana_adv_toggle` **toggles** — anything driving it must read the current state rather than assume
a fresh dialog is closed. Two of this commit's own fixtures were wrong about that before the row
that says so existed.

## One address for the form

Eight sites used to spell `[dict get $wins $key].chana.form.$f` by hand. Issue **1405** is what that
costs: Stage 1 moved `$w.$field` to `$w.form.$field`, a suite driving the old path through a
**variable** was invisible to the path survey, and the display arm raised `invalid command name`
and silently lost nine rows while the headless arm read ALL PASS. `chana_form`, `form_has` and
`form_get` are the only readers now.

⚠ **`form_get` reads by widget class rather than calling `get`.** A checkbutton has no `get`; reading
one the old way raises, and the raise lands inside `chana_ok`'s commit path where the only visible
symptom is an OK button that does nothing.

## What you see when the window reopens

1. The **tran** form shows its **two required** fields and a `▸ Advanced` triangle; opening it adds
   `Start recording at (s)`, `Maximum time step (s)` and a **checkbutton** for Use initial conditions.
2. Every label carries its **unit**: `Stop time (s):`, not `Stop:`.
3. The **AC sweep type is a readonly combobox** offering `dec oct lin`, and picking `lin` relabels
   its neighbour to **`Number of points (2 gives ONE point):`**.
4. A bench storing no sweep key still **shows `dec`**, because the deck it renders carries `dec`.
5. A refusal appears **in the dialog**, and the cursor lands on the field it names.

## What this does NOT ship

**Apply**, and ⚖ **R5** (keep what you typed across a type switch) — both **C5**. The derived
point-count readout (`61 points`) and the Initial-conditions sub-dialog remain later items.

## Suites

`test_ase_dialogs.tcl` display **242 → 257** (rows **G2c**, **G2d**, **G2e**, **G2f**, **G2g** — G2c
and G2d rewritten, because their C3 fixtures reached fields that are now behind the disclosure).
`test_ase_core.tcl` **333 → 335** (**GR7**, **GR8**).

⚠ **G2e alone could not have caught the build-time relabel.** Its fixture uses a bench with no
stored sweep key, so the label it reads is the one the *default* produces — which a pick-only
relabel also produces. **G2g** stores `lin`, closes the dialog and reopens it, and that is the only
row in the suite that fails when the relabel runs only on `<<ComboboxSelected>>`.
