# ⚖ R9 — every user-facing sentence this batch has added, for ratification

**Status: WAITING ON THE USER.** This is the last open ruling in the ASE-L
analyses batch. Everything else — ⚖ R1 through ⚖ R8, ⚖ R10 and ⚖ R11 — is
answered and recorded in `DECISIONS.md`.

## What this is

Every stage of this batch has put new words on the user's screen, and each time
the crew filed a `rule` debt rather than deciding the wording itself. Those debts
have been accumulating since stage 2. This document is all of them in one place,
so they can be read once instead of nineteen times.

**449 strings, from 26 issues, grouped by where the user sees them** — not by
issue number, because the question "is this the right word?" is answered by
reading the four sentences that appear on the same line of the same dialog, not
by reading one issue's worth of unrelated surfaces.

## How it was built, and why the strings can be trusted

Twelve agents read the 19 issue files in parallel and returned one record per
string. They were given one instruction above all others: **the text is verbatim,
including placeholders, capitalisation, punctuation and any oddity.** Nothing was
tidied on the way in.

The load-bearing finding from that pass is that **the issue files could not be
the source.** Most of them only *describe* their copy — *"every label carries its
unit"*, *"mints three frames"*, *"four precondition sentences with their four
remedies"* — and several quote a draft that was superseded before the commit
landed. So every string here was taken from the **committed source at HEAD**
(`git show HEAD:src/ase.tcl`, `git show HEAD:src/ase_window.tcl`), cross-checked
against the commit that introduced it, with continuation-joined Tcl strings
rendered through `tclsh` so the text is what the widget actually shows rather
than what the source lines look like.

### What the driver re-measured, independently

The extraction was checked rather than trusted. Every string was searched for in the committed source at HEAD, with Tcl line-continuations joined
the way the interpreter joins them:

* **341 are present as a single literal**, byte for byte — the 262 of the first pass, plus all 79 of issue 1443's, each of which the driver found byte-for-byte in the committed source.
* **38 arrived after the first version** — issue **1452**'s 18 and issue **1454**'s 20, appended
  when stage 9 was collected. Each was verified individually by the driver against the working
  tree at collection: **12 are present as a single literal** (the two `sp` field labels, the four
  matrix formats, `Format`, `This analysis reports no matrix yet.`, and the adapter's four
  headings `Source` / `Port` / `Noise` / `Z0 (ohm)`) and **26 are rendered** — composed from the
  contract's declared `min` and `noun`, from the row's own numbers, or from a `\u2026` escape.
* **31 are not, and all 31 are RENDERED rather than wrong** — the code composes
  them from pieces. `Time step (s):` is `label {Time step}` plus `unit s` plus
  the colon `form_label` appends. *"Stopping this run discards it — ngspice in
  batch mode writes nothing on a stop."* is an ASE-L frame plus a clause the
  ngspice adapter supplies. A few show a readable placeholder (`<node>`,
  `<outv>`) where the code writes a variable, or expand a branch variable into
  the two sentences it can produce.

Those 31 carry a **`Rendered:`** line in their entry. The distinction matters
only if you want one changed: the words are what the user reads, but the edit
lands on the pieces, and in two cases one of the pieces belongs to the **ngspice
adapter** rather than to ASE-L.

Nothing was found that the source does not say.

No working-tree copy of `src/ase.tcl`, `src/ase_window.tcl`,
`tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_persist.tcl` or
`tests/run_regression.tcl` was read, because a crew holds those five files while
this document is being written.

## How to answer

Every string has a **handle** — `R9-001` … `R9-410`. Mark up whatever you want
changed, by handle, in any form: *"R9-011: drop the shouting"*, *"R9-046/047:
Voltage and Current"*, *"R9-003 → Stop value"*.

**Anything you do not mark is ratified as it stands**, and that is a normal
answer — a lot of these are ordinary field labels that are already right.

Section A below is the part worth reading first: nine choices that recur across
many strings at once. Answering those nine settles most of the document.

The last two handles, **R9-292 and R9-293**, were added after the first version by
a completeness sweep of the commits themselves — the section at the end says how.

## What is deliberately NOT here

* ~~**Issue 1443's strings.**~~ ✅ **They are here now** — the crew finished, the work
  landed as commit `3f31a33b`, and its 79 strings are the last section of this document,
  **R9-294 … R9-372**. Every handle above them kept its meaning.
* **ngspice's own text.** Where ASE-L quotes a simulator error back to the user
  verbatim, the wording is ngspice's and is not ours to ratify. Those are noted
  in place where they matter.
* **Deck cards and netlist lines.** `.tran 1n 100n`, `pz in 0 out 0 vol pz` and
  the like are SPICE syntax, not copy. Four strings that *do* land on disk are
  here, because a user reading the deck or the run directory meets them as
  English: R9-161 (a comment ASE-L writes into the deck), R9-288, R9-289 (the
  plotmap sidecar's record format) and R9-290 (a sidecar filename).
* **Test-only strings** and internal `dbg` output.
* **The batch's other standing rule debts** — 1397, 1400, 1408, 1423, 1425,
  1431, 1439, 1440 and 1444. Those are rulings about *mechanism* or about
  *defects*, not about wording, and each will be put separately.

---

# Section A — the nine choices that recur

Each of these appears in many strings at once. Answering here is worth more than
marking up individual handles, and the rest of the document is mostly the
consequence.

## A1 — Shouted words in the middle of a sentence

Nine strings shout a word in capitals mid-sentence for emphasis:
`ONE` (R9-011, R9-030, R9-051, R9-153), `VOLTAGE` (R9-118), `DEGREES` (R9-138),
`SEGFAULTS` (R9-135), and `NOT` (R9-078, R9-171).

`ONE` is the one to look at: **`Number of points (2 gives ONE point)`** is a
field label containing an arithmetic claim and the only uppercase word in any
label in the tree — and the *same* caption on the `noise` form reads
**`(1 gives ONE point)`**, a different number in the same dialog. Both are
measured and both are correct; ngspice really does count them differently.

*My recommendation:* drop the shouting everywhere, and move the arithmetic out of
the label into the detail line or the tooltip, where a sentence has room. A label
is a name, not a warning.

Separately, `NOT OFFERED:` and `NOT MEASURED:` (R9-190 and R9-212–R9-221,
eleven strings) are **prefixes**, not shouting mid-sentence — they mark a whole
class of row in the options sheet, the way a column heading would. Those I would
keep.

## A2 — Acronyms shipped lowercase in pickers

The combobox values are the deck words: `dc ac` (R9-053), `dec` `oct` `lin`
(R9-054), `vol` / `cur` (R9-046, R9-047), `pz` / `pol` / `zer` (R9-048–R9-050).
The combobox renders `-values` with no display mapping, so what SPICE calls it is
what the user reads.

**Your standing rule already answers half of this** — UI copy spells acronyms in
uppercase — so `dc ac` should be `DC AC` regardless. The open part is the
*abbreviations*: `vol`/`cur` are not acronyms, they are truncations, and
`Voltage`/`Current` would read better; `pol`/`zer` likewise for `Poles`/`Zeroes`.

*My recommendation:* display the readable word, emit the deck word. The mapping
costs one dictionary per picker.

## A3 — Internal slot names shown where the form shows a label

R9-062 and R9-159 say **`needs a value for '$f'`**, which renders as
*"needs a value for 'stop'"* — while the box it is pointing at is captioned
**`Stop time (s):`**. R9-075 and R9-076 are worse: **`needs '<field>' to be at
least <min>`** tells a user who typed 0 into the field captioned *"Report every N
points:"* that the row *"needs 'ptssum' to be at least 1"*.

*My recommendation:* the sentence names the label the user can see. The slot name
is ours, not theirs.

## A4 — `Stop` / `Stop time` / `Stop frequency`, and `Step` / `Time step`

The same concept is captioned three ways across three forms in the same dialog:
`Stop` (R9-003, dc), `Stop time` (R9-016, tran), `Stop frequency` (R9-013, ac);
and `Step` (R9-004, dc) against `Time step` (R9-015, tran).

The qualified ones are arguably better — a dc sweep's `Stop` is a source value,
not a time — so this is not simply an inconsistency to flatten.

*My recommendation:* qualify all three: `Stop value` for dc. Then every form
reads `<quantity> <role>`, and nothing is bare.

## A5 — Units in parentheses, and one label that is a sentence

Every tran and ac label carries its unit: `Time step (s):`, `Stop time (s):`,
`Start frequency (Hz):`. That is consistent and good. Two exceptions:

* **R9-017 / R9-025 — `Start recording at (s):`** is a verb phrase where every
  other label is a noun phrase, and the only label that reads as an instruction.
  It is carrying real information (ngspice still *simulates* from 0 — the defect
  the whole issue is named for), but it is doing it in the label.
* The dc form's labels carry no unit at all, because the unit depends on what is
  being swept.

*My recommendation:* keep the units; move R9-017's meaning into the detail line
and name the field `Start time (s):`.

## A6 — Developer vocabulary on the user's screen

Four phrases say what the code calls something rather than what the user calls
it: **`this simulator backend`** (R9-077, R9-065, R9-160 — the user chose a
*simulator*; "backend" is ours), **`readable list of non-blank lines`** (R9-080 —
Tcl vocabulary in front of a circuit designer), and **`verbatim`** (R9-157,
R9-158) as the name of a feature with no editor, reachable only by hand-editing
the state file.

*My recommendation:* `this simulator` for the first; plain English for the
second; leave `verbatim` until it has a UI, then name it there.

## A7 — Two frames for the same event

The OK-button validator logs **`ase: enabled $type analysis $_clause`**
(R9-059) while the status line under the same form says
**`This $type analysis $_clause.`** (R9-061, and R9-068/R9-069 from a different
issue). Same class of problem, two voices — *"enabled"* vs *"this"*, period vs no
period.

*My recommendation:* one frame, used both places.

## A8 — Sibling sentences that drifted apart

Several pairs open with the same words and diverge mid-sentence, which reads as a
typo even when both are deliberate:

* R9-078's gate refusal and its near-twin twenty lines above it: *"the run would
  have **completed, produced no result for it, and said nothing**"* against
  *"the run would have **started and produced nothing for it**"*.
* R9-262 ends **`… on a stop.`** with a full stop; its sibling R9-264 ends
  **`… nothing of this run was written`** with none.
* R9-098 is plural — **`name nodes that are in the circuit`** — where the
  equivalent `tf` and `sens` sentences, R9-089 and R9-115, are singular:
  **`name a node that is in the circuit`**. And R9-119 and R9-123 say the same
  thing two more ways again: `name a node, as \`v(out)\` or \`v(out,ref)\`` and
  `name a node this netlist has`.

*My recommendation:* make each pair identical except for the part that genuinely
differs.

## A9 — Placeholders the user is meant to read as placeholders

R9-138's `<mag>` and `<phase>` are **literal text on screen** — the user is meant
to read *"type a magnitude and a phase"* — while `<outv>`, `$type` and
`[join …]` elsewhere are substituted before display. Two kinds of angle bracket,
one screen.

*My recommendation:* spell the literal ones as words (*"add `distof1` to the
input source with a magnitude and a phase in degrees"*), so every remaining
`<…>` on screen is a real value.

## A10 — one idea wearing three names, inside one dialog

The measurements copy (R9-294 onward) ships the same concept under different words
in forms the user will switch between:

* **"ignore the signal until"** is `Ignore before` on the find and when forms
  (R9-328) and **`Trigger delay` / `Target delay`** on the delay form
  (R9-316, R9-321) — and `Ignore before` is also the only verb-phrase label in the
  set, which is §A5's complaint again.
* **"the level a signal must reach"** is `Value` on the when form (R9-331),
  **`reaches`** on the find form (R9-325) and **`Trigger value` / `Target value`**
  on the delay form (R9-313, R9-318).

*My recommendation:* one word per concept, chosen once — `Ignore before` for the
first (it says what it does) and `Value` for the second, qualified only where two
appear in one form.

⚠ **R9-325 `reaches` is the one to look at closely.** It is the only lowercase
label in the tree, and it only reads correctly if the form lays `When signal` and
`reaches` out on one line. Ratifying it also ratifies a layout constraint on a
dialog that does not exist yet.

## A11 — a C source file and a line number, in a refusal

R9-355 tells the user that ngspice *"names DERIV and refuses it at run time
(com_measure2.c:2156, `function 'deriv' currently not supported`)"*. The options
sheet already does this — it cites `cktntask.c:68` — so this is a **consistency**
question, not a one-off: either ASE-L cites the simulator's source when it knows
exactly where a limit lives, or it never does.

*My recommendation:* keep it, and keep it in parentheses at the end where it is
now. A designer who hits a refusal they think is wrong can check it in ten
seconds, and nobody else has to read it.

## A12 — acronyms: expanded, or not?

§A2 asks about **case**. This asks about **expansion**, and the same set of
strings answers it three ways: **`RMS`** (R9-298), **`FFT spectrum`** (R9-309)
and **`Power spectral density`** (R9-310) — acronym, acronym-plus-noun, and the
words instead of the acronym.

*My recommendation:* the acronym where an analog designer would say the acronym —
`RMS`, `FFT`, `PSD`, `THD` — since that is how they are spoken at a bench.

⚠ **And §A3's family grew.** The measurements refusals show the *internal kind
token* where a picker shows a label: R9-356 says a row is bound wrong by naming
`'fft'`, and R9-361 tells a `Delay (TRIG ... TARG)` row (R9-294) that it segfaults for
**`TRIGTARG`** — a word that appears nowhere on screen. Answering §A3 answers
these.

---

# The strings

Read the rest at whatever depth you like; the handles are stable, so a note like
*"R9-118: lose the caps"* is a complete answer.

Each entry gives the string verbatim, **where** it appears, **what it is for**,
and — where the extraction found something a reader needs — a **note**.


## Where to find things

| section | strings |
|---|---|
| Choose Analyses — field labels on the per-analysis forms | 41 |
| Choose Analyses — the words inside the pickers | 13 |
| Choose Analyses — the ▸ Advanced disclosure | 2 |
| Choose Analyses — the status line, and what OK says when it refuses | 20 |
| The precondition banner under the form, and the pre-run block in the run log | 80 |
| The Analyses pane — the Arguments column cell | 4 |
| The Deck preview pane | 12 |
| Simulation > Options… — the sheet itself | 17 |
| Simulation > Options… — the detail line under the grid | 46 |
| Simulation > Options… — the speller's refusals, and the inert reasons they quote | 18 |
| Simulation > Options… — catalogue prose (the per-option help text) | 5 |
| Simulation > Options… — the delivery report | 3 |
| The run log and the CIW notice channel | 26 |
| What lands on disk — the deck, the sidecar, the run directory | 3 |
| Everything else | 1 |
| Added after the first version — found by a completeness sweep | 2 |
| Issue 1443 — measurements, added after the crew's work landed | 79 |
| Issue 1447 — how a user names one analysis among several | 5 |
| Issue 1448 — the handle made visible | 4 |
| Issue 1451 — the Measurements dialog, and the eight templates | 29 |
| **total** | **410** |

---

## Choose Analyses — field labels on the per-analysis forms

*41 strings.*

### from issue 1416 (stage 3b)

**R9-001** · label

```text
Sweep variable
```

*Where:* Choose Analyses dialog -> dc form, label on the first entry row

*For:* Names the dc entry holding the source (or `temp`) whose value is swept. Shown whenever the dc analysis form is open.

*Note:* Renders as `Sweep variable:` via ase::ui::form_label. Replaces the auto-derived `Source:` the form used to show. Declared in this commit; first rendered in C4.


**R9-002** · label

```text
Start
```

*Where:* Choose Analyses dialog -> dc form, label on the second entry row

*For:* Names the dc entry holding the first sweep's start value.

*Note:* Identical to the text the old `[string totitle $f]` auto-title produced, so nothing changed on screen for this one. Carries no unit, unlike the tran and ac rows beside it.


**R9-003** · label

```text
Stop
```

*Where:* Choose Analyses dialog -> dc form, label on the third entry row

*For:* Names the dc entry holding the first sweep's stop value.

*Note:* Same as the previous auto-title. Note `Stop` here vs `Stop time` on the tran form and `Stop frequency` on the ac form -- the reviewer may want the three consistent.


**R9-004** · label

```text
Step
```

*Where:* Choose Analyses dialog -> dc form, label on the fourth entry row

*For:* Names the dc entry holding the first sweep's increment.

*Note:* Same as the previous auto-title. Note `Step` here vs `Time step` on the tran form.


**R9-005** · label

```text
Second sweep variable
```

*Where:* Choose Analyses dialog -> dc form, label on the fifth entry row (the second-sweep nest; under Advanced once C4 lands)

*For:* Names the entry holding the second, outer dc sweep's source. Appears on the dc form only.

*Note:* One of four fields carrying `group {second sweep}`; the group phrase is user-visible, see the group refusal below.


**R9-006** · label

```text
Second start
```

*Where:* Choose Analyses dialog -> dc form, label on the sixth entry row (second-sweep nest)

*For:* Names the entry holding the second dc sweep's start value.

*Note:* Reads as an ordinal-modified fragment rather than a noun phrase; `Second sweep start` would parallel `Second sweep variable`. Same for the two below.


**R9-007** · label

```text
Second stop
```

*Where:* Choose Analyses dialog -> dc form, label on the seventh entry row (second-sweep nest)

*For:* Names the entry holding the second dc sweep's stop value.

*Note:* See the note on `Second start`.


**R9-008** · label

```text
Second step
```

*Where:* Choose Analyses dialog -> dc form, label on the eighth entry row (second-sweep nest)

*For:* Names the entry holding the second dc sweep's increment.

*Note:* See the note on `Second start`.


**R9-009** · label

```text
Points per decade
```

*Where:* Choose Analyses dialog -> ac form, label on the points row -- the field's base label, and the text shown when Sweep type is `dec`

*For:* Names the ac entry holding the frequency-resolution count, when the sweep is decade-logarithmic. Also the fallback label before any mode is picked.

*Note:* Replaces the old `Points:` which was shown for all three modes -- the trap this relabelling exists to fix.


**R9-010** · label

```text
Points per octave
```

*Where:* Choose Analyses dialog -> ac form, points row, text shown when Sweep type is `oct`

*For:* Names the same ac points entry when the sweep is octave-logarithmic.


**R9-011** · label

```text
Number of points (2 gives ONE point)
```

*Where:* Choose Analyses dialog -> ac form, points row, text shown when Sweep type is `lin`

*For:* Names the same ac points entry when the sweep is linear, and warns in the label itself that ngspice's linear count is a total, not a per-decade rate, and is off by one.

*Note:* THE ONE THE REVIEWER WILL STOP ON. Three problems: (a) shouting `ONE` mid-label, which is the only uppercase word in any label in the tree; (b) an arithmetic claim embedded in a field label rather than in help text; (c) it does not match its siblings -- the IDENTICAL field on the `noise` form reads `Number of points (1 gives ONE point)` and on the `disto` form reads plain `Number of points`. Those two other types were added by later commits, but the three ship side by side today and only this one is in 1416's scope.


**R9-012** · label

```text
Start frequency
```

*Where:* Choose Analyses dialog -> ac form, label on the start row

*For:* Names the ac entry holding the lowest swept frequency.

*Note:* Renders as `Start frequency (Hz):` -- the unit is appended by form_label, see the `Hz` entry.


**R9-013** · label

```text
Stop frequency
```

*Where:* Choose Analyses dialog -> ac form, label on the stop row

*For:* Names the ac entry holding the highest swept frequency.

*Note:* Renders as `Stop frequency (Hz):`.


**R9-014** · unit

```text
Hz
```

*Where:* Choose Analyses dialog -> ac form, appended in parentheses to the Start frequency and Stop frequency labels

*For:* Tells the user the unit the ac frequency entries are read in.

*Note:* Composed by form_label as ` ([dict get $fd unit])`, giving `Start frequency (Hz):`. Correct capitalisation for hertz; contrast the tran form's lowercase `s`, which is also correct -- so the inconsistency is only apparent.


**R9-015** · label

```text
Time step
```

*Where:* Choose Analyses dialog -> tran form, label on the first entry row

*For:* Names the tran entry holding the printing/integration step. Renders as `Time step (s):`.

*Note:* Replaces the auto-derived `Step:`. Note the dc form's equivalent stayed plain `Step`.


**R9-016** · label

```text
Stop time
```

*Where:* Choose Analyses dialog -> tran form, label on the second entry row

*For:* Names the tran entry holding the end of the simulated interval. Renders as `Stop time (s):`.

*Note:* Replaces the auto-derived `Stop:`.


**R9-017** · label

```text
Start recording at
```

*Where:* Choose Analyses dialog -> tran form, label on the tstart row (under Advanced once C4 lands)

*For:* Names the tran entry holding tstart -- the time before which results are computed but not saved. Appears only on the tran form.

*Note:* A verb phrase where every other label in the batch is a noun phrase, and the only label that reads as an instruction. It is trying to convey that ngspice still SIMULATES from 0 -- the defect this whole issue is named for. `Start recording at (s):` when the unit is appended.


**R9-018** · label

```text
Maximum time step
```

*Where:* Choose Analyses dialog -> tran form, label on the tmax row (under Advanced once C4 lands)

*For:* Names the tran entry bounding the integrator's internal step. Renders as `Maximum time step (s):`.

*Note:* Sits directly under `Time step`, and the two are easy to confuse -- which is precisely the confusion the positional defect exploited.


**R9-019** · label

```text
Use initial conditions
```

*Where:* Choose Analyses dialog -> tran form, label on the uic row (a plain 1/0 entry at C3, a checkbutton from C4)

*For:* Names the control that appends the `uic` keyword to the transient card.

*Note:* At C3 this is an ENTRY the user types `1` or `0` into, so the label reads as a question the control cannot answer in kind; the issue says the checkbutton is C4. Spells out the acronym `uic`, which the deck still shows verbatim.


**R9-020** · unit

```text
s
```

*Where:* Choose Analyses dialog -> tran form, appended in parentheses to all four time labels

*For:* Tells the user the tran time entries are read in seconds.

*Note:* Lowercase `s`, correct SI; sits beside `Hz` on the ac form. Gives `Time step (s):`, `Stop time (s):`, `Start recording at (s):`, `Maximum time step (s):`.


### from issue 1417 (stage 3b)

**R9-021** · button

```text
▸ Advanced
```

*Where:* Choose Analyses dialog → the per-analysis form, the disclosure button gridded below the basic fields (closed state)

*For:* Collapsed toggle hiding a type's optional fields (tran's tstart/tmax/uic, dc's second-sweep group). Shown whenever the selected type declares at least one `advanced 1` field and the disclosure is closed.

*Note:* Glyph + word deliberately, per the source comment: "the triangle says which way it goes and the word says what is behind it". The open/closed state is remembered per WINDOW, so the user may meet either spelling on first opening the dialog.


**R9-022** · button

```text
▾ Advanced
```

*Where:* Choose Analyses dialog → the per-analysis form, the same disclosure button (open state)

*For:* Expanded toggle; the optional fields are listed beneath it.

*Note:* Same widget as the row above, re-texted on toggle. Two distinct Unicode triangles (U+25B8 / U+25BE) — worth confirming both render in the user's chosen dialog font.


**R9-023** · label

```text
Time step (s):
```

*Where:* Choose Analyses dialog → per-analysis form, tran, basic field label (column 0)

*For:* The tran required step size. One of the two fields shown before the disclosure is opened.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Constant declared by 1416; 1417 is the commit that first renders it, and the " (s)" comes from 1417's `form_label` appending the declared unit. Before 1417 this read "Step:".


**R9-024** · label

```text
Stop time (s):
```

*Where:* Choose Analyses dialog → per-analysis form, tran, basic field label

*For:* The tran required stop time; the second of the two always-visible fields.

*Note:* Quoted by the issue as the point of the unit suffix: "`Stop time (s):`, not `Stop:`". Constant from 1416, rendered first by 1417.


**R9-025** · label

```text
Start recording at (s):
```

*Where:* Choose Analyses dialog → per-analysis form, tran, behind ▸ Advanced

*For:* Optional tran tstart — the time before which output is discarded.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Constant from 1416, first rendered by 1417. Phrased as an instruction rather than a noun, unlike its neighbours.


**R9-026** · label

```text
Maximum time step (s):
```

*Where:* Choose Analyses dialog → per-analysis form, tran, behind ▸ Advanced

*For:* Optional tran tmax — the ceiling on the solver's internal step.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Constant from 1416, first rendered by 1417. Sits directly under "Time step (s):" when the disclosure is open; the two are easy to confuse at a glance.


**R9-027** · label

```text
Use initial conditions:
```

*Where:* Choose Analyses dialog → per-analysis form, tran, behind ▸ Advanced — label beside a checkbutton whose own -text is empty

*For:* Optional tran uic flag, now a checkbutton rather than an entry the user had to type `1` into.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Ships WITH the trailing colon even though it labels a checkbox rather than a value field — `form_label` appends ":" unconditionally. The checkbutton itself has `-text {}`, so the colon is the last thing before an unlabelled box.


**R9-028** · label

```text
Points per decade:
```

*Where:* Choose Analyses dialog → per-analysis form, ac/noise/disto, the points field label while Sweep type is `dec` (also the label a bench with no stored sweep key opens with)

*For:* The count field, labelled for the decade sweep — where the number is points PER DECADE, not in total.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Also the field's plain `label`, so it is what sens (dec-only) always shows.


**R9-029** · label

```text
Points per octave:
```

*Where:* Choose Analyses dialog → per-analysis form, ac/noise/disto, the points field label after picking `oct`

*For:* Same field, relabelled for the octave sweep.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Relabel is one `configure` on the neighbour's label widget; it runs on a pick AND at build time.


**R9-030** · label

```text
Number of points (2 gives ONE point):
```

*Where:* Choose Analyses dialog → per-analysis form, AC, the points field label after picking `lin`

*For:* Same field, relabelled for the linear sweep — where the number is a TOTAL, and ngspice's off-by-one means 2 yields a single point. This relabel is the defect issue 1417 is named for.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* ⚠ THE ONE THE REVIEWER MOST LIKELY WANTS TO CHANGE. Shouty caps mid-label, a parenthetical that is a warning rather than a unit, and it is INCONSISTENT ACROSS TYPES at HEAD: noise ships "Number of points (1 gives ONE point):" and disto ships a bare "Number of points:" for the same `lin` pick. The parenthetical constants are 1416/1432 text; 1417 is the commit that renders them.


**R9-031** · label

```text
Start frequency (Hz):
```

*Where:* Choose Analyses dialog → per-analysis form, ac/noise/disto/sens, basic field labels

*For:* Sweep start. Paired with "Stop frequency (Hz):".

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Constant from 1416, unit suffix supplied by 1417's `form_label`. Its partner ships as "Stop frequency (Hz):" — same shape, listed here once.


### from issue 1426 (stage 5)

**R9-032** · label

```text
Output
```

*Where:* Choose Analyses dialog -> the `tf` row's edit form, left-hand field label of the output entry box

*For:* Names the entry box that holds the transfer function's output expression (v(node), v(node,ref) or i(source)); visible whenever a tf row's form is open.

*Note:* `ase::ui::form_label` appends a colon, so it ships on screen as `Output:`. Same word is also `sens`'s output label (pre-existing there).


**R9-033** · label

```text
Input source
```

*Where:* Choose Analyses dialog -> the `tf` row's edit form, left-hand field label of the input-source entry box

*For:* Names the entry box that holds the independent source the transfer function is driven from; visible whenever a tf row's form is open.

*Note:* Ships on screen as `Input source:` (colon added by `ase::ui::form_label`).


### from issue 1427 (stage 5)

**R9-034** · label

```text
Input +
```

*Where:* Choose Analyses dialog -> the `pz` row's edit form, field label of the first node entry box

*For:* Names the positive input node of the pole-zero analysis; required field.

*Note:* Renders as `Input +:` — label plus the colon `ase::ui::form_label` appends, so the shipped run of characters is `+:`.


**R9-035** · label

```text
Input -
```

*Where:* Choose Analyses dialog -> the `pz` row's edit form, field label of the second node entry box

*For:* Names the input reference node; optional, defaults to ground.

*Note:* Renders as `Input -:`. The box is left blank when unset — the `0` default is not pre-filled into the widget, it is only written into the deck.


**R9-036** · label

```text
Output +
```

*Where:* Choose Analyses dialog -> the `pz` row's edit form, field label of the third node entry box

*For:* Names the positive output node of the pole-zero analysis; required field.

*Note:* Renders as `Output +:`.


**R9-037** · label

```text
Output -
```

*Where:* Choose Analyses dialog -> the `pz` row's edit form, field label of the fourth node entry box

*For:* Names the output reference node; optional, defaults to ground.

*Note:* Renders as `Output -:`.


### from issue 1428 (stage 5)

**R9-038** · label

```text
Output
```

*Where:* Choose Analyses dialog — the per-analysis form for `sens`, left-column label of the first (required) form row

*For:* Names the text box where the user types the node or source whose sensitivity is wanted; visible whenever `sens` is the selected analysis type in the grid.

*Note:* Shipped in the registry as bare `Output`, but `ase::ui::form_label` (src/ase_window.tcl:5001) unconditionally appends a colon, so ON SCREEN it reads `Output:`. Ratify the bare word; the colon is the frame's.


**R9-039** · label

```text
Parameters
```

*Where:* Choose Analyses dialog — the per-analysis form for `sens`, left-column label of the second (optional) form row

*For:* Names the free-text box where the user lists which device/model parameters to perturb (the ngspice filter globs); blank means all of them.

*Note:* Reads `Parameters:` on screen (same colon rule). Worth a reviewer's eye: the field is `kind filter` and what the user types are ngspice FILTERS/globs over device names, not parameter names — `Parameters` may undersell that. The other four analyses' second field is not called this.


### from issue 1432 (stage 6)

**R9-040** · label

```text
Number of points
```

*Where:* Choose Analyses form, `disto` — left-column field label, shown only while Sweep type is `lin`

*For:* Captions the distortion sweep's point-count entry when the sweep is linear.

*Note:* The third spelling of one caption across three analyses: `ac` says "(2 gives ONE point)", `noise` says "(1 gives ONE point)", `disto` says nothing at all. Rendered as "Number of points:".


**R9-041** · label

```text
Report every N points
```

*Where:* Choose Analyses form, `noise` — field label inside "▸ Advanced", and only while "Per-device contributor table" is ticked (it is `depends`-gated and vanishes otherwise)

*For:* Captions the decimation factor for the contributor table — the table is written every Nth frequency point.

*Note:* The "N" is a literal capital N in the caption, not a substituted number, and the field it captions is where the user types that N. Rendered as "Report every N points:". This is the field whose below-minimum message names it as 'ptssum'.


---

## Choose Analyses — the words inside the pickers

*13 strings.*

### from issue 1416 (stage 3b)

**R9-042** · label

```text
Sweep type
```

*Where:* Choose Analyses dialog -> ac form, label on the sweep-mode row (a plain entry at C3, a combobox from C4)

*For:* Names the control choosing between logarithmic-per-decade, logarithmic-per-octave and linear frequency spacing.

*Note:* Its three selectable values are the bare ngspice keywords `dec`, `oct`, `lin` -- unlabelled and lowercase; the picker that displays them is C4. Picking one RELABELS the points row below it (`relabels points`), which is why that row has three texts.


### from issue 1417 (stage 3b)

**R9-043** · label

```text
Sweep type:
```

*Where:* Choose Analyses dialog → per-analysis form, ac/noise/disto/sens, label of a readonly combobox offering dec oct lin

*For:* Picks the AC-family frequency sweep mode. Picking a value relabels the neighbouring points field.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* The combobox is readonly and its three values ship verbatim as `dec`, `oct`, `lin` — lowercase ngspice keywords shown to the user as-is, not spelled out. sens offers only `dec`.


### from issue 1427 (stage 5)

**R9-044** · label

```text
Input type
```

*Where:* Choose Analyses dialog -> the `pz` row's edit form, field label of the first readonly combobox

*For:* Labels the picker that chooses whether the excitation is a voltage or a current.

*Note:* Renders as `Input type:`. Only the label is sentence-cased; the values it offers are lowercase ngspice keywords (below).


**R9-045** · label

```text
Find
```

*Where:* Choose Analyses dialog -> the `pz` row's edit form, field label of the second readonly combobox

*For:* Labels the picker that chooses whether to search for poles, zeros, or both.

*Note:* Renders as `Find:`. One word, imperative — the only field label in the form that is a verb.


**R9-046** · label

```text
vol
```

*Where:* `Input type` readonly combobox, first item in the drop-down list

*For:* The selectable value meaning a voltage-driven input; it is also the default shown when the row stores nothing.

*Note:* Raw ngspice keyword, shipped unexpanded — the combobox shows the emitted deck word rather than "Voltage". Reviewer may want `Voltage`/`Current`.


**R9-047** · label

```text
cur
```

*Where:* `Input type` readonly combobox, second item in the drop-down list

*For:* The selectable value meaning a current-driven input (input admittance of a node).

*Note:* Raw ngspice keyword, shipped unexpanded.


**R9-048** · label

```text
pz
```

*Where:* `Find` readonly combobox, first item in the drop-down list

*For:* The selectable value meaning "find both poles and zeros"; it is also the default.

*Note:* Raw ngspice keyword. Note the picker value `pz` is spelled identically to the analysis type name shown in the grid, so the form reads `Find: pz` inside the pz row.


**R9-049** · label

```text
pol
```

*Where:* `Find` readonly combobox, second item in the drop-down list

*For:* The selectable value meaning "find poles only".

*Note:* Raw ngspice keyword, shipped unexpanded.


**R9-050** · label

```text
zer
```

*Where:* `Find` readonly combobox, third item in the drop-down list

*For:* The selectable value meaning "find zeros only".

*Note:* Raw ngspice keyword. Measured in the issue: this choice can legitimately produce no vectors at all at rc 0.


### from issue 1432 (stage 6)

**R9-051** · label

```text
Number of points (1 gives ONE point)
```

*Where:* Choose Analyses form, `noise` — left-column field label, shown only while Sweep type is `lin` (the Sweep type combobox relabels this field live)

*For:* Captions the noise sweep's point-count entry when the sweep is linear, and warns that a linear noise sweep of 1 collapses to a single frequency (which also suppresses the Integrated Noise plot).

*Note:* ⚠ The identical field on the `ac` analysis reads "Number of points (2 gives ONE point)" — same caption, different number, in the same dialog. Both are measured-correct (the two analyses step differently), but seen side by side they read like a typo in one of them. Rendered with a trailing colon: "Number of points (1 gives ONE point):". "ONE" shouted.


**R9-052** · label

```text
Mode
```

*Where:* Choose Analyses form, `sens` — field label on a readonly combobox, main (non-Advanced) section

*For:* Picks DC or AC sensitivity. The choice gates four further fields (Sweep type, Points per decade, Start/Stop frequency), which only appear in AC mode.

*Note:* Rendered as "Mode:". Terse to the point of being unqualified — the `pz` analysis has a same-shaped picker captioned "Find" and another captioned "Input type".


**R9-053** · button

```text
dc ac
```

*Where:* Choose Analyses form, `sens` — the items inside the "Mode:" readonly combobox

*For:* The two selectable values of the sens Mode picker, shown to the user exactly as the registry spells them.

*Note:* ⚠ Both acronyms ship LOWERCASE in a user-facing picker. The combobox renders `-values` verbatim with no display mapping. Pre-existing pickers in the same dialog do the same (`dec oct lin`, `vol cur`, `pz pol zer`), so this is a house-wide question rather than a one-line fix — but this commit is the first to put `dc`/`ac` themselves in front of the user as choices.


**R9-054** · button

```text
dec
```

*Where:* Choose Analyses form, `sens` in AC mode — the items inside the "Sweep type:" readonly combobox

*For:* The only selectable sweep for AC sensitivity. `lin` and `oct` are deliberately not offered because both are broken in ngspice (measured: `oct` yields ~48% of the points asked for).

*Note:* A one-item readonly picker: the user sees a combobox they cannot change. Nothing on screen says why the other two sweeps are missing — the reasoning lives only in a source comment. Lowercase, as above.


---

## Choose Analyses — the ▸ Advanced disclosure

*2 strings.*

### from issue 1432 (stage 6)

**R9-055** · label

```text
Per-device contributor table
```

*Where:* Choose Analyses form, `noise` — field label on a checkbox, inside the "▸ Advanced" disclosure

*For:* Turns on the per-device noise contributor table. It is a checkbox named for what the user wants; the raw ngspice parameter (`ptspersummary`, a spectrum decimation factor whose side effect is the table) is hidden behind it.

*Note:* Rendered as "Per-device contributor table:" with the tickbox to its right — the trailing colon on a checkbox caption is the form's uniform treatment, not a per-field choice.


**R9-056** · label

```text
F2/F1 ratio (switches to intermodulation)
```

*Where:* Choose Analyses form, `disto` — field label inside the "▸ Advanced" disclosure

*For:* Captions the optional second-tone ratio. Filling it changes the whole analysis from harmonic distortion (2nd/3rd harmonic plots) to intermodulation (f1+f2, f1-f2, 2f1-f2 plots) — the parenthetical is the only place the user is told that.

*Note:* Rendered as "F2/F1 ratio (switches to intermodulation):". The longest field caption in the dialog, and the only one whose parenthetical announces a mode change rather than a unit or a hint. Must stay in step with the disto_f2src fix string, which calls the same control "the F2/F1 ratio".


---

## Choose Analyses — the status line, and what OK says when it refuses

*20 strings.*

### from issue 1416 (stage 3b)

**R9-057** · refusal

```text
needs every value of the $f, or none of them
```

*Where:* ase::analysis_emit_msg `group` clause -- a bare clause with NO frame; the caller supplies the frame

*For:* Says a declared all-or-none group of fields is partly filled. `$f` is the group's user-visible PHRASE, not a field name -- deliberately, because naming one field would send the user to fill it and leave the others missing.

*Note:* REWORDED BY THIS COMMIT. It previously read `needs every value of '$f' or none of them` -- the quotes were dropped, `the` was added in front and a comma before `or`. The only group declared today is `second sweep`, so the only text that can render is: `needs every value of the second sweep, or none of them`.


**R9-058** · other

```text
second sweep
```

*Where:* the phrase substituted into the group refusal -- the only user-visible text of the `group {second sweep}` declaration on dc's four nest fields

*For:* Names, in prose inside the refusal sentence, the set of four dc fields that must be all filled or all empty.

*Note:* Lowercase and unquoted inside the sentence, so it can read as ordinary prose rather than as a named group -- `the second sweep` could be parsed as 'the second sweeping action'. It does not match any label on the form either; the four labels say `Second sweep variable` / `Second start` / `Second stop` / `Second step`.


**R9-059** · refusal

```text
ase: enabled $type analysis $_clause
```

*Where:* Choose Analyses dialog -> the OK button's refusal, written to the ACTION LOG (a different window) via ase::echo at error level; the dialog stays up

*For:* Frames whatever ase::analysis_emit_check found wrong with the row the user is about to commit. `$type` is the analysis name (`tran`, `dc`, `ac`, `op`, ...); `$_clause` is the unframed clause from ase::analysis_emit_msg.

*Note:* The FRAME is not new, but what it now carries is: this commit deleted the door's own loop and made it ask analysis_emit_check, so the sentence a user sees for a blank required field changed from `ase: enabled tran analysis needs a non-empty 'step'` to `ase: enabled tran analysis needs a value for 'step'`, and four further clauses became reachable here for the first time (`'$f' must be on or off`, `cannot read '<v>' as a number for '$f'`, `is not one this simulator backend can set up`, and the group one). At C3 this went ONLY to the action log -- from the user's seat OK appeared to do nothing; the in-dialog status line is issue 1417, not this commit.


**R9-060** · refusal

```text
ase: enabled dc analysis needs every value of the second sweep, or none of them
```

*Where:* Choose Analyses dialog -> the OK refusal as it actually composes for a half-filled dc second sweep -- action log line

*For:* The headline sentence of this commit: what the user reads when they fill in, say, a second sweep variable and leave its start, stop and step blank. The full composition of the two entries above; shown verbatim here because neither half reads as a sentence alone.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Composed, not a single literal in the source -- frame from ase_window.tcl:5311, clause from ase.tcl:4646. Grammar of the whole: `enabled dc analysis needs every value of the second sweep` has the analysis as the subject that `needs`, which the reviewer may or may not want.


### from issue 1417 (stage 3b)

**R9-061** · refusal

```text
This $type analysis $_clause.
```

*Where:* Choose Analyses dialog → status line (grid row 1, beside the Enable checkbutton), written when OK is pressed on an enabled analysis that fails validation

*For:* Tells the user why OK did nothing, in the dialog itself rather than only in the action log. `$type` is the analysis type name (tran, ac, dc, noise…); `$_clause` is one clause from `ase::analysis_emit_msg`, listed separately below.

*Note:* NEW SENTENCE FRAME, minted by 1417. Renders as e.g. "This tran analysis needs a value for 'stop'." Note the frame repeats the type the user just clicked, and that it writes over `$w.status` — which on a fresh bench already carries a capability sentence for the selected cell, so the capability line is evicted by the refusal.


**R9-062** · refusal

```text
needs a value for '$f'
```

*Where:* Choose Analyses dialog → status line (and the action log), composed into the frame above

*For:* A required slot of the enabled analysis is empty. `$f` is the field's internal NAME (stop, tmax, insrc), not its label.

*Note:* Clause text predates 1417 (issue 1404/1416 era) but 1417 is what puts it in front of the user in the dialog. ⚠ The clause names the raw field name while the form beside it shows the human label — the user reads "needs a value for 'stop'" next to a box labelled "Stop time (s):". Flagged already in the source as ⚖ R9 "recommended shapes, not ratifications".


**R9-063** · refusal

```text
'$f' must be on or off
```

*Where:* Choose Analyses dialog → status line (and the action log), composed into the frame above

*For:* A bool-kind field carries a stored value that is neither 1 nor 0 nor absent (only reachable from a hand-edited or older bench, since the form now offers a checkbutton).

*Note:* Pre-1417 clause, newly surfaced in the dialog by 1417. Same raw-field-name concern as the row above.


**R9-064** · refusal

```text
cannot read '[lindex $args 1]' as a number for '$f'
```

*Where:* Choose Analyses dialog → status line (and the action log), composed into the frame above

*For:* A numeric field's value will not parse in the simulator's own SI alphabet. First placeholder is the offending value, second is the field name.

*Note:* Pre-1417 clause, newly surfaced in the dialog by 1417 — and it is the sentence issue 1417 quotes as the live defect it fixed: a bench storing `sweep lin` was refused with "cannot read 'lin' as a number for 'sweep'" because the number check was a deny-list. The check is now an allow-list (real, int, time, freq); the wording is unchanged.


**R9-065** · refusal

```text
is not one this simulator backend can set up
```

*Where:* Choose Analyses dialog → status line (and the action log), composed into the frame above

*For:* The enabled analysis type has no renderable emit template for this backend.

*Note:* Pre-1417 clause, newly surfaced in the dialog by 1417. Reads as a fragment by design (the caller owns the frame): "This pss analysis is not one this simulator backend can set up."


**R9-066** · refusal

```text
needs every value of the $f, or none of them
```

*Where:* Choose Analyses dialog → status line (and the action log), composed into the frame above

*For:* A declared all-or-none field group is partly filled — e.g. dc's second sweep. `$f` is the group's declared name, e.g. `second sweep`.

*Note:* Pre-1417 clause, newly surfaced in the dialog by 1417. Renders "This dc analysis needs every value of the second sweep, or none of them." — the definite article plus the group name is the awkward part. A group offence focuses NO widget (naming one of its four empty fields would send the user to fill only that one), so this sentence is the entire pointer.


### from issue 1418 (stage 3b)

**R9-067** · refusal

```text
has a setting named '$f' that ASE-L cannot emit
```

*Where:* `ase::analysis_emit_msg` clause — reaches the user through the two rows below, and through any future caller of the emit check

*For:* The row carries a key that is neither `type`, nor `enabled`, nor a declared field of that type — so nothing can spend it and it would never reach the deck. `$f` is the key name the user typed.

*Note:* NEW CLAUSE, minted by 1418. "setting" is the user-facing word for what the code calls a key and the dialog calls Name; "ASE-L" is spelled out in a sentence no other refusal names a product in. The clause deliberately carries no frame.


**R9-068** · refusal

```text
This $_ty analysis $_c.
```

*Where:* Choose Analyses dialog → status line — written when Add is pressed in the `Options…` sub-dialog (the sub-dialog is a child toplevel sitting on top of the dialog whose status line this is)

*For:* Refuses a name/value pair at the Add gesture, before it can appear in the Options list and be believed. `$_ty` is the analysis type; `$_c` is the unknownkey clause above.

*Note:* ⚠ SURFACE ODDITY WORTH A RULING: the gesture happens in the `Options…` sub-dialog but the sentence lands on the PARENT Choose Analyses dialog's status line, which the sub-dialog may be covering. Renders as "This tran analysis has a setting named 'foo' that ASE-L cannot emit."


**R9-069** · refusal

```text
This $type analysis $_c.
```

*Where:* Choose Analyses dialog → status line — written when OK is pressed in the `Options…` sub-dialog and the stored row carries a key Add never saw

*For:* Second refusal at commit time, for keys seeded from an older or hand-edited bench rather than typed. Same rendered sentence as the Add arm.

*Note:* Two separate literals in the source (different variable names, identical output), so a reviewer changing one must change both. Same parent-status-line placement caveat as the row above. This arm is a dead end for the user: the offending key is in the stored bench, and the sentence does not say that, nor how to remove it.


**R9-070** · status

```text
ase: this $_ty analysis $_c
```

*Where:* ASE-L action log / run log (`ase::echo … error`), emitted alongside both status-line refusals above

*For:* The log witness of the same refusal, for headless assertions and for the user scanning the log window.

*Note:* NEW FRAME, minted by 1418 — and note it differs from the log frame the OK-button validator uses for the same class of problem, which reads "ase: enabled $type analysis …". "this" vs "enabled", and no terminating full stop here where the dialog copy has one.


### from issue 1420 (stage 3b)

**R9-071** · refusal

```text
'$f' must be on or off
```

*Where:* Analyses pane, Arguments column cell — enabled row with a boolean field set to something other than on/off (also the dialog status line and the log)

*For:* Refuses a boolean analysis field (e.g. tran's `uic`) carrying a value that is neither 1 nor 0; shown for an enabled row that therefore cannot render.

*Note:* Wording minted earlier in the stage (issue 1416's typed-field work), listed here because 1420 makes it reachable in the Arguments column. Reviewer point: the stored values are `1`/`0` but the sentence says `on or off` — deliberate, but it is a place where the message and the file spelling differ.


**R9-072** · refusal

```text
cannot read '[lindex $args 1]' as a number for '$f'
```

*Where:* Analyses pane, Arguments column cell — enabled row with a numeric field that does not parse in this simulator's suffix alphabet (also the dialog status line and the log)

*For:* Refuses a value ASE-L cannot read as a number for a numeric field, quoting back exactly what the user typed and the field it was typed into.

*Note:* Pre-existing clause surfaced in the column by 1420. `[lindex $args 1]` is the offending value and `$f` the field, so it renders e.g. `cannot read 'lin' as a number for 'sweep'` — that exact rendering is quoted in the source as a live defect that this stage fixed, so it is a real user-seen string.


**R9-073** · refusal

```text
needs every value of the $f, or none of them
```

*Where:* Analyses pane, Arguments column cell — enabled row with a partially-filled field group, e.g. ngspice's second DC sweep nest (also the dialog status line and the log)

*For:* Refuses a row that filled some but not all of a group of fields that only mean anything together (a half-filled second DC sweep is a parse error ngspice reports mid-run).

*Note:* Pre-existing clause surfaced in the column by 1420. `$f` is the GROUP name, not a field name, so the sentence reads e.g. `needs every value of the second sweep, or none of them` — the article `the` before an interpolated group name is the fragile part of this wording.


**R9-074** · refusal

```text
has a setting named '$f' that ASE-L cannot emit
```

*Where:* Analyses pane, Arguments column cell — enabled row carrying a state-file key no template can spend (also the dialog status line and the log)

*For:* Refuses a row holding a leftover free-text key from the old Options editor — the keys that used to round-trip and confirm on screen while emitting nothing.

*Note:* Minted by issue 1418 (the door-closing commit), reachable in the column from 1420. It is the one clause that spells the product name; `ASE-L` in the middle of a treeview cell is worth the reviewer's eye.


**R9-075** · refusal

```text
needs '$f' to be at least [lindex $args 1]
```

*Where:* Analyses pane, Arguments column cell — enabled row with a numeric field below a registry-declared minimum (also the dialog status line and the log)

*For:* Refuses a value the simulator itself would reject late, mid-run (measured: a noise sweep with 0 steps), at the moment it is typed instead.

*Note:* POSTDATES BOTH ISSUES — minted by issue 1432, after 1420 — but it lands in the same cell and the same dialog line, so it belongs in any one-pass read of this surface. Flagged so the reviewer does not attribute it to 1419/1420.


### from issue 1432 (stage 6)

**R9-076** · refusal

```text
needs '<field>' to be at least <min>
```

*Where:* Choose Analyses dialog status line on OK (framed "This <type> analysis <clause>."), the action log ("ase: enabled <type> analysis <clause>"), the pre-run gate ("ase: the <type> analysis <clause>"), and the Analyses grid's settings/deck-line column, where the bare clause is printed as the whole cell

*For:* Stops the commit and the run when a numeric field is below the lower bound the simulator itself enforces — noise `points` and `ptssum`, disto `points`, sens `points`, each declared `min 1`. ngspice otherwise only refuses after the deck is written and the process has started.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* ⚠ <field> is the INTERNAL SLOT NAME, not the form label: a user who typed 0 into the field captioned "Report every N points:" is told "needs 'ptssum' to be at least 1". The sibling clauses `missing` and `fill` have the same defect and predate this commit, so fixing this one alone would make the set inconsistent. Clause carries no frame and no trailing period by design.


---

## The precondition banner under the form, and the pre-run block in the run log

*80 strings.*

### from issue 1401 (stage 2)

**R9-077** · refusal

```text
ase: analysis type '$type' is not one this simulator backend can render
```

*Where:* CIW / ASE-L message area, red (error) — the preflight refusal prints one of these per unrenderable enabled row before the deck is written; the same string is also the text of the error raised out of render_deck (ase::analysis_emit_order), so it surfaces again in whatever reports that error.

*For:* Tells the user that an enabled analysis row carries a type this simulator's backend has no way to emit, so the run is refused instead of completing and silently doing nothing. Appears at Run/Netlist time, before anything is written.

*Note:* Minted once in ase::analysis_unrenderable_msg (src/ase.tcl:4105) and said by both refusal sites, so changing it here changes both. The code interpolates $type; the issue file spells the placeholder <t>, and the measured real instance reads: ase: analysis type 'noise' is not one this simulator backend can render. Note it says "this simulator backend" — the user picked a simulator, not a backend, so the word may be developer vocabulary leaking out.


**R9-078** · caution

```text
ase: it is enabled on this bench, so the run would have completed, produced no result for it, and said nothing. Nothing was generated: no deck, no raw, no log. Any files already in [file normalize $rd] are from an earlier run. `set ase_preflight 0` does NOT disable this check.
```

*Where:* CIW / ASE-L message area, red (error) — the second line of the same preflight refusal, printed once after the per-type lines above, and joined into the raised error text.

*For:* Explains what the refusal saved the user from (a run that would have finished with nothing to show), states that nothing was written this time, disambiguates any leftover files in the run directory, and closes off the usual escape hatch.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Assembled in ase::preflight_gate (src/ase.tcl ~:11230) from a continued string plus $rdnote. THE RUNDIR SENTENCE IS CONDITIONAL: when the rundir does not yet exist the middle sentence is absent entirely and the text reads "...no deck, no raw, no log. `set ase_preflight 0` does NOT disable this check." The path shown is [file normalize $rd], i.e. an absolute directory path. The backticks around set ase_preflight 0 are literal characters in the shipped message, and the shouted NOT is literal too. ⚠ Reviewer should see this beside its near-twin ~20 lines above in the same proc (a DIFFERENT issue, not 1401): "ase: it is enabled on this bench, so the run would have started and produced nothing for it. Nothing was generated: no deck, no raw, no log. `set ase_preflight 0` does NOT disable this check." — two refusals that open with the same nine words and diverge at "completed, produced no result for it, and said nothing" vs "started and produced nothing for it". Also: "it" has no antecedent in this line on its own; the antecedent is the analysis type named in the line before it.


### from issue 1417 (stage 3b)

**R9-079** · refusal

```text
 It is under Advanced.
```

*Where:* Choose Analyses dialog → status line, appended to the refusal sentence above when the offending field is behind the Advanced disclosure

*For:* Points the user at a field the refusal names but the form is not currently showing.

*Note:* Verbatim INCLUDING the leading space — it is `append`ed, so it ships as one run-on line: "This tran analysis needs a value for 'tmax'. It is under Advanced." The dialog deliberately does NOT open the disclosure (that would destroy and rebuild the form and discard what the user typed), so the sentence is the only pointer they get.


### from issue 1419 (stage 3b)

**R9-080** · refusal

```text
has verbatim lines that are not a readable list of non-blank lines
```

*Where:* Choose Analyses dialog status line (the sentence under the form, after pressing OK) — and the same clause verbatim in the action log and in the preflight refusal before a run

*For:* Refuses to commit or run an analysis row whose verbatim hatch is malformed — either not parseable as a Tcl list, or containing a blank line (a blank would emit an empty line into .control, which ngspice accepts and which makes the deck unreadable).

*Note:* THE CLAUSE CARRIES NO FRAME; the caller supplies one, so the user actually reads three different composed sentences: in the dialog `This tran analysis has verbatim lines that are not a readable list of non-blank lines.` (trailing period added by the caller), in the action log `ase: enabled tran analysis has verbatim lines that are not a readable list of non-blank lines`, and at the preflight gate `ase: the tran analysis has verbatim lines that are not a readable list of non-blank lines`. Reviewer-visible awkwardness: one clause covers two distinct faults (unreadable list vs. a blank line among readable ones), so the user is not told which; and `readable list` is Tcl vocabulary surfaced to a circuit designer. src/ase.tcl, ase::analysis_emit_msg, token `verbatim`.


### from issue 1426 (stage 5)

**R9-081** · advice

```text
'$nm' is not an independent source, and a transfer function can only be driven from one
```

*Where:* tf precondition banner under the Choose Analyses form (as `⊘ <sentence>. Fix: …`), and the pre-run advice line in the run log (`ase: the tf analysis: <sentence>. Fix: …`)

*For:* Fires when the Input source field names a device that exists in the circuit but is not a v/i card; warns before the run that ngspice will abort with "not of proper type".

*Note:* Verdict `blocked`; on a static netlist pass issue 1423 demotes it to `caution` and appends " (read from the netlist text, which cannot see inside an .include)" to this exact sentence. `$nm` is the user's own typed name.


**R9-082** · advice

```text
name a voltage source or a current source
```

*Where:* the `Fix:` clause of both tf_insrc findings — banner line and run-log advice line alike

*For:* The remedy offered with either input-source complaint.

*Note:* One string used by BOTH tf_insrc findings (wrong-kind and not-present).


**R9-083** · advice

```text
this circuit has no '$nm' to drive the transfer function from
```

*Where:* tf precondition banner under the Choose Analyses form, and the pre-run advice line in the run log

*For:* Fires when the Input source field names something the netlist has no card for at all.

*Note:* Verdict `blocked`, so on a static pass it ships with the " (read from the netlist text, which cannot see inside an .include)" caveat appended.


**R9-084** · refusal

```text
'$outv' is not an output this simulator can read
```

*Where:* the preflight REFUSAL that aborts the run — `ase: the tf analysis cannot run: <sentence>` on the error stream, and the raised error text — plus the ⊘ banner under the form

*For:* Fires when the Output expression is malformed (e.g. `v mid`, `x(mid)`); stops the whole run, because ngspice's syntax error would make it quit part-way through the deck.

*Note:* Verdict `fatal`, deliberately exempt from the static demotion, so it never carries the `.include` caveat. `$outv` is the user's typed expression.


**R9-085** · advice

```text
write it as `v(node)`, `v(node,reference)` or `i(source)` -- the parentheses are not optional
```

*Where:* the remedy line of that refusal, printed as `ase:   fix: <text>` (and as `. Fix: <text>` in the banner)

*For:* Tells the user the legal output-expression forms after a malformed output is refused.

*Note:* Ships with backticks around the three forms and a bare ASCII double hyphen `--`, not an en dash. The closing clause exists because the commonest mistake is the missing parenthesis.


**R9-086** · advice

```text
'$outv' names no voltage source to read a current through, and this analysis reports three numbers either way
```

*Where:* tf precondition banner under the Choose Analyses form, and the pre-run advice line in the run log

*For:* Fires when the Output is an `i(...)` form naming anything but a voltage source; warns that ngspice will silently return zeros rather than complain.

*Note:* Verdict `blocked` -> demoted to `caution` with the `.include` caveat appended on a static pass. "three numbers" = Transfer_function, input impedance, output impedance.


**R9-087** · advice

```text
name a voltage source, or measure a voltage with `v(node)` instead
```

*Where:* the `Fix:` clause of that current-output finding

*For:* The remedy offered when an i() output cannot be read.

*Note:* Backticks around `v(node)` ship literally.


**R9-088** · advice

```text
this circuit has no node '[join $missing {' and no node '}]', and this analysis reports three numbers anyway rather than saying so
```

*Where:* tf precondition banner under the Choose Analyses form, and the pre-run advice line in the run log

*For:* Fires when a v() output names one or more nodes the netlist does not have; warns that ngspice answers rc 0 with plausible numbers.

*Note:* The placeholder IS the join expression as written: with two missing nodes it renders `... no node 'a' and no node 'b', and this analysis ...`. Verdict `blocked`, so a static pass appends the `.include` caveat after "saying so".


**R9-089** · advice

```text
name a node that is in the circuit
```

*Where:* the `Fix:` clause of the missing-node finding

*For:* The remedy offered when the output names an absent node.

*Note:* Singular "a node" even when the sentence above it listed two missing nodes.


### from issue 1427 (stage 5)

**R9-090** · refusal

```text
the input of this pole-zero analysis is shorted: '$inp' is both the input and its reference
```

*Where:* the preflight REFUSAL that aborts the run (`ase: the pz analysis cannot run: <sentence>`) and the ⊘ precondition banner under the Choose Analyses form

*For:* Fires when the Input + and Input - boxes hold the same node; ngspice would abort with "Input is shorted".

*Note:* Verdict `fatal` — rests only on what the user typed, so it never carries the `.include` caveat. Starts lowercase, as every sentence in this family does.


**R9-091** · advice

```text
give the input two different nodes
```

*Where:* the remedy line of that refusal (`ase:   fix: <text>`) / the `Fix:` clause in the banner

*For:* The remedy for a shorted input.


**R9-092** · refusal

```text
the output of this pole-zero analysis is shorted: '$outp' is both the output and its reference
```

*Where:* the preflight refusal and the ⊘ precondition banner

*For:* Fires when the Output + and Output - boxes hold the same node; ngspice would abort with "Output is shorted".

*Note:* Verdict `fatal`. Deliberately parallel in wording to the input sentence above.


**R9-093** · advice

```text
give the output two different nodes
```

*Where:* the remedy line of that refusal

*For:* The remedy for a shorted output.


**R9-094** · refusal

```text
the input and the output name the same pair of nodes, so the transfer function is 1 and there is nothing to solve
```

*Where:* the preflight refusal and the ⊘ precondition banner

*For:* Fires (voltage input only) when both node pairs match, which ngspice reports as "Transfer function is unity".

*Note:* Verdict `fatal`. Checked only when Input type is `vol`; the current-input case is a real analysis and is not refused.


**R9-095** · refusal

```text
the output is the input with its nodes swapped, so the transfer function is -1 and there is nothing to solve
```

*Where:* the preflight refusal and the ⊘ precondition banner

*For:* Fires (voltage input only) when the output pair is the input pair reversed, which ngspice reports as "Transfer function is -1".

*Note:* Verdict `fatal`. Ships a bare ASCII hyphen-minus in `-1`.


**R9-096** · advice

```text
name the node you want the poles of as the output
```

*Where:* the `Fix:` clause of BOTH unity/-1 findings

*For:* The remedy when input and output describe the same transfer function.

*Note:* One string, reused by two findings.


**R9-097** · advice

```text
this circuit has no node '[join $missing {' and no node '}]', and ngspice reports that as the input being shorted to the output
```

*Where:* pz precondition banner under the Choose Analyses form, and the pre-run advice line in the run log (`ase: the pz analysis: <sentence>. Fix: …`)

*For:* Fires when any of the four node boxes names a node the netlist has not got; explains that ngspice's own message will blame the wiring instead.

*Note:* Placeholder is the join expression verbatim. Verdict `blocked`, so a static pass demotes it to `caution` and appends " (read from the netlist text, which cannot see inside an .include)". Node `0` is skipped, so ground never triggers it.


**R9-098** · advice

```text
name nodes that are in the circuit
```

*Where:* the `Fix:` clause of the missing-node finding

*For:* The remedy when a node box names an absent node.

*Note:* Plural here, where 1426's equivalent tf sentence is singular ("name a node that is in the circuit") — the two are inconsistent.


**R9-099** · refusal

```text
this circuit has [join $stops { and }], and pole-zero analysis stops before it produces anything when one is present
```

*Where:* the preflight refusal and the ⊘ precondition banner

*For:* Fires when the deck contains a T, O or U line card, all of which make pz abort; refuses the run.

*Note:* Verdict `fatal`. `[join $stops { and }]` interpolates one to three of the noun fragments listed as separate entries below, joined by " and " with NO Oxford comma, e.g. `a transmission line (a `T` card) and a uniform RC line (a `U` card)`.


**R9-100** · advice

```text
run the pole-zero analysis on a copy of the bench with the line replaced by its lumped equivalent
```

*Where:* the remedy line of that refusal

*For:* The remedy when an unsupported line card blocks pz.

*Note:* Says "the line" singular even when the sentence above named two or three families.


**R9-101** · caution

```text
this circuit has [join $quiet { and }], and pole-zero analysis leaves it out of the matrix without saying so -- the roots will be the circuit's without it
```

*Where:* pz precondition banner under the Choose Analyses form, and the pre-run advice line in the run log

*For:* Fires when the deck contains a Y or P card; warns that pz silently omits the device so the roots describe a different circuit.

*Note:* Verdict `caution` and NO `.include` caveat — the issue's "third case": a positive finding the static pass proved. Reads "leaves it out"/"without it" singular even when two families are joined. Ships a bare ASCII `--`.


**R9-102** · advice

```text
replace the line with its lumped equivalent before reading the roots
```

*Where:* the `Fix:` clause of that caution

*For:* The remedy when a silently-skipped line card is present.


**R9-103** · other

```text
a transmission line (a `T` card)
```

*Where:* interpolated into the pz_devices refusal sentence via [join $stops { and }]

*For:* Names the T-card family inside the "pole-zero analysis stops" refusal.

*Note:* Backticks around the card letter ship literally. NOTE the collision: the `Y` fragment below uses the identical noun phrase "a transmission line".


**R9-104** · other

```text
a lossy transmission line (an `O` card)
```

*Where:* interpolated into the pz_devices refusal sentence

*For:* Names the O-card (LTRA) family inside the refusal.

*Note:* Correctly uses "an" before the `O`.


**R9-105** · other

```text
a uniform RC line (a `U` card)
```

*Where:* interpolated into the pz_devices refusal sentence

*For:* Names the U-card (URC) family inside the refusal.

*Note:* "RC" uppercase, in line with the project's acronym rule.


**R9-106** · other

```text
a transmission line (a `Y` card)
```

*Where:* interpolated into the pz_devices CAUTION sentence via [join $quiet { and }]

*For:* Names the Y-card (TransLine) family inside the "leaves it out of the matrix" caution.

*Note:* Same noun phrase as the `T` fragment above — two different cards described identically, differing only by the letter in parentheses.


**R9-107** · other

```text
a coupled transmission line (a `P` card)
```

*Where:* interpolated into the pz_devices CAUTION sentence

*For:* Names the P-card (CplLines) family inside the caution.

*Note:* The netlist-facts table internally calls `p` a port; this sentence deliberately names the device instead.


**R9-108** · refusal

```text
ngspice does not support pole-zero analysis under the KLU solver
```

*Where:* the preflight refusal and the ⊘ precondition banner

*For:* Fires when the bench sets `.options klu` and a pz row is enabled; refuses because ngspice would abort the whole deck.

*Note:* Verdict `fatal`. The only sentence in this batch that names the simulator by name in the message itself; "KLU" uppercase.


**R9-109** · advice

```text
select the `sparse` solver for this run
```

*Where:* the remedy line of that refusal

*For:* The remedy when KLU blocks pz.

*Note:* Byte-identical to the pre-existing `cider_klu` remedy string (not new copy in isolation, but new on this surface). Says "select", which presumes a control the user can find.


### from issue 1428 (stage 5)

**R9-110** · refusal

```text
'$outv' is not an output this simulator can read
```

*Where:* Choose Analyses dialog — precondition banner under the sens form (`$w.note`), prefixed with the glyph `⊘ `; also the pre-run refusal block in the run notice log as `ase: the sens analysis cannot run: <this text>`

*For:* Says the Output box does not parse as an ngspice output at all (e.g. `v mid`, `x(mid)`); severity `fatal`, so ase::preflight_gate refuses the run before any deck is written.

*Note:* `$outv` interpolates the user's own typed string verbatim, quoted in straight single quotes. This arm is `fatal` and therefore EXEMPT from the static demotion, so unlike the three below it never gains the `.include` caveat clause.


**R9-111** · advice

```text
write it as `v(node)`, `v(node,reference)` or `i(source)` -- the parentheses are not optional
```

*Where:* Same banner/refusal, appended to the sentence above as `. Fix: <this text>`; in the run log it is its own line, `ase:   fix: <this text>`

*For:* Tells the user the three legal output spellings after a malformed Output was refused.

*Note:* Backticks are literal in the shipped string (no markup renderer behind them). The dash is a literal double hyphen `--`, not an em dash — the tree mixes both elsewhere.


**R9-112** · caution

```text
'$outv' names no voltage source to read a current through, and this analysis fills in a table of zeros either way
```

*Where:* Choose Analyses dialog — precondition banner under the sens form, glyph `⚠ ` (demoted) or `⊘ ` (exact netlist); also the pre-run advice block in the run notice log as `ase: the sens analysis: <this text>`

*For:* Warns that an `i(...)` output naming anything but a voltage source will not fail — ngspice exits 0 and writes a full table of zeros the user would read as a result.

*Note:* Registered `blocked`; `ase::analysis_needs` demotes it to `caution` on a static pass and APPENDS ` (read from the netlist text, which cannot see inside an .include)` to the sentence, so in practice the reviewer will usually see the two clauses plus that parenthetical. Second clause is the one carrying the real warning; it is long.


**R9-113** · advice

```text
name a voltage source, or measure a voltage with `v(node)` instead
```

*Where:* Same banner / pre-run advice block as above

*For:* The remedy paired with the zero-table warning; appears as `. Fix: <this text>`.

*Note:* Literal backticks again.


**R9-114** · caution

```text
this circuit has no node '[join $missing {' and no node '}]', and this analysis fills in a table of sensitivities anyway rather than saying so
```

*Where:* Choose Analyses dialog — precondition banner under the sens form; also the pre-run advice block in the run notice log

*For:* Warns that the node named in Output is not in the netlist, and that ngspice will still return a ~90-row sensitivity table rather than erroring.

*Note:* The `[join ...]` is the placeholder as the code writes it: one missing node renders `has no node 'mid'`, two render `has no node 'mid' and no node 'out'`. The joiner repeats the whole phrase `' and no node '`, which is deliberate but makes a three-node list read heavily. Also demoted to `caution` + the `.include` parenthetical on a static pass.


**R9-115** · advice

```text
name a node that is in the circuit
```

*Where:* Same banner / pre-run advice block as above

*For:* The remedy paired with the missing-node warning; appears as `. Fix: <this text>`.

*Note:* Terser than the other three remedies; no example spelling.


**R9-116** · caution

```text
nothing in this circuit is named '[join $dead {' or '}]', and a sensitivity filter that matches nothing leaves the run with no results at all rather than failing
```

*Where:* Choose Analyses dialog — precondition banner under the sens form (triggered by the Parameters box); also the pre-run advice block in the run notice log

*For:* Warns that a filter naming no top-level device makes ngspice exit 0 with no sensitivity plot at all — the results file then holds only the twelve mathematical constants.

*Note:* `[join $dead {' or '}]` renders `'nosuch'` for one, `'nosuch' or 'alsonot'` for two. This predicate deliberately stays silent on globs (`r*`) and on dotted hierarchical names, so the sentence only ever names exact spellings. Demoted to `caution` + the `.include` parenthetical on a static pass, which is the common case.


**R9-117** · advice

```text
name a device this netlist has at the top level -- a device inside a subcircuit is named `<letter>.<instance path>.<name>`
```

*Where:* Same banner / pre-run advice block as above

*For:* The remedy paired with the empty-filter warning; teaches the hierarchical vector spelling, because a user filtering on the name they see inside their own subcircuit matches nothing.

*Note:* `<letter>.<instance path>.<name>` is a literal angle-bracket template in the shipped string, inside literal backticks; note `instance path` contains a SPACE inside the angle brackets, unlike the other two placeholders. Longest of the four remedies.


### from issue 1432 (stage 6)

**R9-118** · refusal

```text
a noise analysis measures a VOLTAGE, and '<outv>' is a current
```

*Where:* Choose Analyses precondition banner under the form (fatal, glyph "⊘ "), and the pre-run refusal in the run log framed "ase: the <type> analysis cannot run: …"

*For:* Says the noise Output field names a current (e.g. i(v1)) when noise can only measure a node voltage. Appears as soon as the form/bench is checked against the netlist, and hard-refuses the run.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* <outv> is the user's own typed Output string, inserted verbatim. "VOLTAGE" is shouted in caps mid-sentence — the only all-caps word in the noise clauses. Clause carries no frame and no trailing period; the caller supplies both.


**R9-119** · advice

```text
name a node, as `v(out)` or `v(out,ref)`
```

*Where:* Same banner line, appended as ". Fix: <this>"; in the fatal run-log refusal it is its own line, "ase:   fix: <this>"

*For:* The remedy paired with the "measures a VOLTAGE" refusal above.

*Note:* Backticks are literal in the shipped string — they are not markdown, they render as backticks in a Tk label.


**R9-120** · refusal

```text
'<outv>' is not a node voltage a noise analysis can measure
```

*Where:* Choose Analyses precondition banner (fatal, "⊘ "), and the pre-run refusal in the run log

*For:* Says the noise Output field is neither a voltage nor a current — it could not be parsed at all. Hard-refuses the run.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Near-twin of the previous refusal; a reviewer may want to see them side by side.


**R9-121** · advice

```text
write it as `v(out)` or `v(out,ref)`
```

*Where:* Banner ". Fix: …" clause / run-log "ase:   fix: …" line

*For:* The remedy paired with the "is not a node voltage" refusal.

*Note:* Same content as "name a node, as `v(out)` or `v(out,ref)`" above but a different verb and no comma — two spellings of one instruction, three lines apart in the source.


**R9-122** · caution

```text
this circuit has no '<node>' for the noise analysis to measure, and ngspice answers a missing node with a full spectrum of numbers rather than failing
```

*Where:* Choose Analyses precondition banner (blocked, glyph "⊘ "), and the pre-run advice block in the run log framed "ase: the <type> analysis: … . Fix: …"

*For:* Warns that the node named in Output is not in the netlist, and that ngspice will not complain — it will silently return a whole spectrum computed about ground. Does not stop the run.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* With more than one missing node the list is joined as "no 'a' and no 'b'", i.e. the sentence reads "this circuit has no 'a' and no 'b' for the noise analysis…" — the "no" is repeated inside the join. Verdict is `blocked`, which the grid draws with the same glyph as `fatal` by design.


**R9-123** · advice

```text
name a node this netlist has
```

*Where:* Banner ". Fix: …" clause / run-log advice line

*For:* The remedy paired with the missing-node caution.


**R9-124** · caution

```text
'<name>' carries no AC value, and a noise analysis is referred to its input source's AC magnitude
```

*Where:* Choose Analyses precondition banner (blocked, "⊘ "), and the pre-run advice block in the run log

*For:* Warns that the source named in Input source exists but has no `ac` on its card, so ngspice will abort the run with a message that names neither the analysis nor the source.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* <name> is the user's typed Input source. This is the refusal the generic `ac_source` precondition cannot make — a bench with ten other AC sources still dies here.


**R9-125** · advice

```text
put `ac 1` on '<name>' (any magnitude will do)
```

*Where:* Banner ". Fix: …" clause / run-log advice line

*For:* The remedy paired with the "carries no AC value" caution.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* The parenthetical is doing real work (noise normalises by the AC magnitude), but reads as an aside a user might skip.


**R9-126** · caution

```text
'<name>' is not an independent source, and noise can only be referred to one
```

*Where:* Choose Analyses precondition banner (blocked, "⊘ "), and the pre-run advice block in the run log

*For:* Warns that Input source names a device that exists but is not a voltage/current source (e.g. a resistor).

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* "referred to one" is a term of art from ngspice's own noise model (input-referred noise); it may read oddly to a user who does not know it.


**R9-127** · advice

```text
name a voltage source or a current source carrying `ac`
```

*Where:* Banner ". Fix: …" clause / run-log advice line — shared by the "not an independent source" and "has no '<name>'" cautions

*For:* The remedy for both Input-source cautions that are not about a missing `ac` value.

*Note:* One string, two call sites.


**R9-128** · caution

```text
this circuit has no '<name>' to refer the noise to
```

*Where:* Choose Analyses precondition banner (blocked, "⊘ "), and the pre-run advice block in the run log

*For:* Warns that the Input source name is nowhere in the netlist at all.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Shortest of the three Input-source clauses; "refer the noise to" is the same term of art in a different grammatical shape.


**R9-129** · refusal

```text
ngspice does not support noise analysis under the KLU solver
```

*Where:* Choose Analyses precondition banner (fatal, "⊘ "), and the pre-run refusal in the run log

*For:* Refuses the run when the bench has `.options klu` on and a noise row is enabled — ngspice quits part-way through the deck and every later analysis silently does not happen.

*Note:* The only precondition clause in this set that names the simulator by name in ASE-L's own voice. "KLU" correctly uppercase.


**R9-130** · advice

```text
select the `sparse` solver for this run
```

*Where:* Banner ". Fix: …" clause / run-log "ase:   fix: …" line

*For:* The remedy paired with the noise/KLU refusal.

*Note:* `sparse` is ngspice's own option word, in backticks.


**R9-131** · refusal

```text
AC sensitivity crashes ngspice outright under the KLU solver -- the process dies and nothing is written
```

*Where:* Choose Analyses precondition banner (fatal, "⊘ "), and the pre-run refusal in the run log

*For:* Refuses the run when a sens row is in AC mode and the bench has KLU on — measured SIGSEGV, no exit status and no log to explain it. Fires on the AC mode only; DC sensitivity under KLU is safe and is not refused.

*Note:* The double hyphen `--` is a literal ASCII em-dash substitute and ships as two hyphens. "crashes ngspice outright" is blunter than any other clause here.


**R9-132** · advice

```text
select the `sparse` solver for this run, or use the DC mode, which is safe under KLU
```

*Where:* Banner ". Fix: …" clause / run-log "ase:   fix: …" line

*For:* The remedy paired with the AC-sensitivity/KLU refusal; names the two ways out.

*Note:* Extends the noise/KLU fix string with a second clause — a reviewer changing one will want to change both.


**R9-133** · refusal

```text
this bench saves <n> named outputs and nothing else, and a <type> analysis answers in vectors that are not netlist names -- ngspice refuses to run it at all and every analysis after it in the deck is abandoned with it
```

*Where:* Choose Analyses precondition banner (fatal, "⊘ "), and the pre-run refusal in the run log. Reaches `noise`, `tf` and `sens` rows.

*For:* Refuses the run when the Outputs pane has Save ticked on one or more named signals and "Save all voltages" is off — noise/tf/sens answer in vectors like `onoise_spectrum` that a netlist-derived save list can never contain, so ngspice refuses the analysis outright.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* The plural is computed: with n == 1 it reads "this bench saves 1 named output and nothing else". <type> is the analysis name as the registry spells it, lowercase (`noise`, `tf`, `sens`). Longest sentence in the set at ~230 characters, and it is a single sentence with three clauses joined by commas and a dash.


**R9-134** · advice

```text
tick Save all voltages, or clear the per-output Save ticks so the deck carries no save list
```

*Where:* Banner ". Fix: …" clause / run-log "ase:   fix: …" line

*For:* The remedy paired with the starved-save-list refusal; names the two controls in the Outputs pane.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* "Save all voltages" is quoted bare, with no quotes or capitalisation cue beyond its own capital S — it is the literal checkbox text. "per-output Save ticks" mixes a lowercase compound with a capitalised control name.


**R9-135** · refusal

```text
every saved output names something this circuit does not have (read from the netlist text, which cannot see inside an .include), and a distortion analysis does not fail on that -- ngspice SEGFAULTS, so there is no exit status, no log and no results file to explain it
```

*Where:* Choose Analyses precondition banner (fatal, "⊘ "), and the pre-run refusal in the run log. `disto` rows only.

*For:* Refuses the run when every ticked output resolves to nothing in the netlist and a disto row is enabled — measured SIGSEGV in ngspice with no artefact of any kind left behind.

*Note:* "SEGFAULTS" is shouted, and the parenthetical is an admission of the checker's own blind spot mid-refusal. Longest single string this commit ships (~270 chars) and the parenthetical pushes the main verb a long way from its subject.


**R9-136** · advice

```text
correct the output names, or tick Save all voltages, or switch the distortion analysis off
```

*Where:* Banner ". Fix: …" clause / run-log "ase:   fix: …" line

*For:* The remedy paired with the disto segfault refusal; three ways out.

*Note:* Second use of the bare control name "Save all voltages", spelled identically to the vecsaves fix.


**R9-137** · caution

```text
no source in this circuit carries a `distof1` excitation, and a distortion analysis without one runs to completion and answers zeros
```

*Where:* Choose Analyses precondition banner (blocked, "⊘ "), and the pre-run advice block in the run log

*For:* Warns that the deck has no distortion excitation, so the run will succeed at rc 0 and return a full set of zeros with nothing on either stream to say why.

*Note:* `distof1` is ngspice's netlist keyword, in backticks.


**R9-138** · advice

```text
add `distof1 <mag> <phase>` to the input source (phase is in DEGREES)
```

*Where:* Banner ". Fix: …" clause / run-log advice line

*For:* The remedy paired with the missing-distof1 caution.

*Note:* <mag> and <phase> here are LITERAL placeholder text shown to the user, not substituted values — the user is meant to read them as "type a magnitude and a phase". "DEGREES" is shouted.


**R9-139** · caution

```text
this row asks for intermodulation, which needs a second excitation, and no source in this circuit carries a `distof2`
```

*Where:* Choose Analyses precondition banner (blocked, "⊘ "), and the pre-run advice block in the run log

*For:* Warns that filling the F2/F1 ratio field switched the analysis to intermodulation, which needs a second excitation the netlist does not have; ngspice's own answer is "Error: incomplete or empty netlist", which names nothing.

*Note:* "this row" is the only precondition clause that refers to the user's grid row rather than to the circuit or the analysis.


**R9-140** · advice

```text
add `distof2 <mag> <phase>` to a source, or clear the F2/F1 ratio to measure harmonics instead
```

*Where:* Banner ". Fix: …" clause / run-log advice line

*For:* The remedy paired with the missing-distof2 caution; names the field by its form label.

*Note:* <mag>/<phase> literal again. "F2/F1 ratio" must stay in step with the field label "F2/F1 ratio (switches to intermodulation)" below — two strings, one name.


### from issue 1434 (stage 6)

**R9-141** · caution

```text
a $type analysis answers in vectors that are not netlist names, so it cannot run under a save list made of them -- this run saves everything, and the $nsave per-output Save tick[expr {$nsave == 1 ? {} : {s}}] on this bench will not narrow it
```

*Where:* Choose Analyses dialog — the precheck note line under the form (prefixed `⚠ `, via the row's `caution` glyph in the four-state grid); and `preflight_gate`'s pre-run advice block in the CIW / run log

*For:* Tells the user that enabling noise / tf / pz / sens has silently widened their results file to everything, overriding the per-output Save ticks they set.

*Note:* This REPLACES the `fatal` refusal wording issue 1432 shipped ("this bench saves $nsave named output[s] and nothing else ... ngspice refuses to run it at all and every analysis after it in the deck is abandoned with it"), which no longer exists in the tree. `$type` is the analysis type as spelled in the registry (`noise`, `tf`, `pz`, `sens`); `$nsave` is a count; the inline `[expr ...]` renders "tick" or "ticks". `--` is two hyphens. "Save all voltages" and "Save" (the per-output column) are the window's own labels. In the dialog it renders as `⚠ <sentence>. Fix: <fix>`; in the log as `ase: the <type> analysis: <sentence>. Fix: <fix>`. The issue file names this sentence explicitly as an unratified ⚖ R9 ruling on the user's queue.


**R9-142** · advice

```text
tick Save all voltages to say so explicitly, or switch the $type analysis off to keep the narrowed save list
```

*Where:* Same two surfaces — the remedy half of the `vecsaves` caution, appended after ". Fix: "

*For:* Offers the two ways out of the forced widening: make it explicit, or drop the analysis that forces it.

*Note:* Rendered as `. Fix: <this>` immediately after the sentence above, so the full stop before it comes from the joiner, not from either string. `Save all voltages` is the checkbox label verbatim.


**R9-143** · caution

```text
every saved output names something this circuit does not have, and ngspice will not run the $type analysis at all under a save list that resolves to nothing -- the run fails with `no data saved`
```

*Where:* Choose Analyses dialog precheck note (prefixed `⚠ `) and `preflight_gate`'s pre-run advice block — the NEW `saves_resolve` precondition, which is attached to every analysis type

*For:* Warns before the run that the save list resolves to nothing, so the named analysis will not run at all.

*Note:* New precondition in this commit, and it is a near-twin of the pre-existing `disto_saves` FATAL sentence it sits beside — that one (unchanged, from issue 1432) reads "every saved output names something this circuit does not have (read from the netlist text, which cannot see inside an .include), and a distortion analysis does not fail on that -- ngspice SEGFAULTS, so there is no exit status, no log and no results file to explain it". The reviewer may want the two levelled, since a user with `disto` enabled can see both. Note the backticks around `no data saved` — they ship literally and appear as backticks in a Tk label. The ".include" blind-spot clause present in the disto twin is absent here even though the same blind spot applies. Named in the issue file as an unratified ⚖ R9 ruling.


**R9-144** · advice

```text
correct the output names, or tick Save all voltages
```

*Where:* Same two surfaces — the remedy half of the `saves_resolve` caution, appended after ". Fix: "

*For:* Offers the two ways to make the save list resolve: fix the names, or save everything.

*Note:* Two options here against the disto twin's three ("correct the output names, or tick Save all voltages, or switch the distortion analysis off") — deliberate, since this one is a caution rather than a refusal, but worth a reviewer's eye.


### from issue 1435 (stage 6)

**R9-145** · status

```text
ASE-L has not netlisted this design yet, so it cannot check this analysis against the circuit. Simulation > Netlist > Recreate.
```

*Where:* Choose Analyses dialog — the precondition banner ($w.note), a wrapping label at grid row 7, under the analysis form and above the "Options…" button

*For:* Appears whenever the netlist-facts slot is cold — ASE-L has never netlisted this design in this session, so the banner has nothing to check the selected analysis against. Tells the user why the form is silent about their circuit and names the menu entry that would make it speak.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* The trailing "Simulation > Netlist > Recreate." is a bare menu path used as a sentence — no verb, no "Use"/"Try". Same shape in all three frames. The path is composed at runtime from ase::ui::menu_path_netlist_recreate; the literal fallback in the code is the identical string. "netlisted" is used as a verb. ASE-L is spelled with the hyphen throughout.


**R9-146** · status

```text
The schematic has changed since the last netlist, so these checks are out of date. Simulation > Netlist > Recreate.
```

*Where:* Choose Analyses dialog — the precondition banner ($w.note), same widget, shown when the slot is stale because the schematic moved or has unsaved edits

*For:* Appears when the design's .sch file stamp has moved since capture, or the buffer was clean at capture and is dirty now — i.e. the user edited the schematic after the netlist ASE-L is reading. Warns that anything the banner would otherwise say about the circuit is stale.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* This is the default stale arm — it covers both the `schmoved` and the `unsaved` reasons with one sentence, so a user with unsaved edits reads "the schematic has changed" rather than "you have unsaved edits". "these checks" refers to the banner's own precondition lines, which are not visible while this sentence is showing (the frames are exclusive).


**R9-147** · status

```text
The netlist has changed since ASE-L read it, so these checks are out of date. Simulation > Netlist > Recreate.
```

*Where:* Choose Analyses dialog — the precondition banner ($w.note), same widget, shown when the slot is stale because the netlist file itself moved

*For:* Appears when the .spice deck's mtime:size stamp no longer matches what ASE-L captured — something rewrote or replaced the netlist outside ASE-L's own producer path. Same out-of-date warning as the schematic case, with the different cause named.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Distinguished from the previous sentence only by "The netlist" vs "The schematic" and "since ASE-L read it" vs "since the last netlist". A reviewer may want to check the two read as a deliberate pair. Third-person reference to the product ("since ASE-L read it") appears here and in the cold sentence.


**R9-148** · advice

```text
⚠ <sentence>. Fix: <fix>
```

*Where:* Choose Analyses dialog — each precondition line inside the banner ($w.note), one line per failing check, worst first (fatal, then blocked, then caution)

*For:* The per-check line shape: a glyph, the precondition sentence for the selected analysis type, and — only when the check supplies a remedy — a period and a "Fix:" clause. Multiple lines are joined with newlines.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* PLACEHOLDER ITEM: only the glyph prefix and the literal ". Fix: " are shipped text from this issue. <sentence> is `[lindex $r 2]` and <fix> is `[lindex $r 3]`, both produced by ase::needs_eval and already on the rule queue under issues 1423/1425/1426/1427/1428/1432/1434 — this issue's "content half" is explicitly empty. The ". Fix: " frame itself is reused verbatim from ase::preflight_gate's advice block (issue 1425, ase.tcl:9122 before this commit), so it is new to THIS surface only. Note the frame appends a period before "Fix:", so a clause that already ends in punctuation would double it. Glyph is "⊘ " instead of "⚠ " for blocked and fatal lines.


**R9-149** · glyph

```text
⊘ 
```

*Where:* Choose Analyses dialog — the mark at the head of a blocked-or-fatal precondition line in the banner ($w.note); same vocabulary as the four-state grid cells above it

*For:* Marks a precondition line the user cannot run through — the banner's `fatal` verdict now wears the glyph the grid already uses for `blocked`, so the two read as one meaning (this will not run).

*Note:* New arm added to ase::ui::chana_glyph: `fatal` returns the same "⊘ " as `blocked`. No grid cell is ever `fatal`; the distinction is kept in the verdict, not the mark. Includes a trailing space. The caution glyph "⚠ " and the absent glyph "· " are pre-existing.


**R9-150** · label

```text
Simulation > Netlist > Recreate
```

*Where:* Composed menu path, new proc ase::ui::menu_path_netlist_recreate — appears today only as the trailing fragment of the three banner frames above

*For:* Names the menu door that would produce the netlist the banner needs, composed from the live menu labels so a rename of the menu follows automatically.

*Note:* Listed separately because it is the one new item in the menu-path family and a reviewer grouping by surface may want to rule on the ">" separator and the three-segment form — it is the only path in that family with three segments. Its text is fully contained in the three sentences above; it renders nowhere else yet. Built from ase::ui::lbl_simulation {Simulation}, lbl_netlist {Netlist}, lbl_netlist_recreate {Recreate} — the latter two are new procs wrapping labels that were already on screen, so no menu pixel changed.


### from issue 1442 (stage 7)

**R9-151** · caution

```text
AC sensitivity crashes ngspice outright under the KLU solver, so this run turns KLU off for that one analysis and puts it back immediately after -- every other analysis in this deck still uses it
```

*Where:* Choose Analyses form — precondition banner under the fields (and the pre-run preflight report), caution row

*For:* Rule 1 demoted from a refusal: tells the user ASE-L is overriding their own klu option for one analysis only.

*Note:* The banner renders this as '<glyph><message>. Fix: <advice>'. The pre-existing fatal wording for the no-hook case is unchanged and is not new copy.


**R9-152** · advice

```text
switch this analysis to the DC mode, which is safe under KLU, or clear the `klu` option if you would rather choose the solver yourself
```

*Where:* Choose Analyses form — precondition banner, the 'Fix:' clause of the same row

*For:* The remedy offered beside the KLU suppression caution.

*Note:* Backticks around `klu` survive into the rendered banner.


**R9-153** · caution

```text
a linear sweep of 2 points yields ONE point, and $sim says nothing about it
```

*Where:* Choose Analyses form — precondition banner, caution row for an ac/sp sweep of lin 2

*For:* Rule 3: warns (never refuses) that lin 2 silently halves to a single point.


**R9-154** · advice

```text
use 3 points, or switch the sweep to `dec`
```

*Where:* Choose Analyses form — precondition banner, the 'Fix:' clause of the lin 2 row

*For:* The remedy offered beside the lin 2 caution.


**R9-155** · caution

```text
this analysis asks for about $n points -- gigabytes of results file and a run measured in hours
```

*Where:* Choose Analyses form — precondition banner, caution row for a very large point count

*For:* Rule 4: warns about the size of the run, above 99,999,999 estimated points.


**R9-156** · advice

```text
raise the time step, or lower the stop time, if that is not what you meant
```

*Where:* Choose Analyses form — precondition banner, the 'Fix:' clause of the point-count row

*For:* The remedy offered beside the point-count caution.


---

## The Analyses pane — the Arguments column cell

*4 strings.*

### from issue 1419 (stage 3b)

**R9-157** · status

```text
  + verbatim: 1 line
```

*Where:* Analyses pane, Arguments column cell — appended to the end of the deck line for a row that carries one verbatim `.control` line

*For:* Tells the user this analysis row will push one extra line of their own into the .control block, immediately above its analysis command; it appears whenever such a row is displayed, alongside the line the deck will carry.

*Note:* Two leading spaces are part of the string (the cell reads `tran 1n 1u  + verbatim: 1 line`). Singular and plural are two separate code paths, so both spellings need reviewing. The contents are deliberately NOT shown, only the count — the issue file explains that three pasted control lines would push the analysis line off the right edge of a one-line treeview cell. `verbatim` is the registry's own word for the hatch; there is currently no editor for it, so the only way to create one is hand-editing the .state file. src/ase_window.tcl, ase::ui::arg_summary.


**R9-158** · status

```text
  + verbatim: $nvb lines
```

*Where:* Analyses pane, Arguments column cell — same suffix for two or more verbatim lines

*For:* Same as the singular: names the hatch by count so a deck carrying lines the window never mentions cannot exist; shown on every display of a row with two or more verbatim lines.

*Note:* `$nvb` is the Tcl variable the code interpolates — it renders as a bare integer, e.g. the pinned cell `tran 1n 1u  + verbatim: 2 lines`. Again two leading spaces. src/ase_window.tcl, ase::ui::arg_summary.


### from issue 1420 (stage 3b)

**R9-159** · refusal

```text
needs a value for '$f'
```

*Where:* Analyses pane, Arguments column cell — an ENABLED row that cannot render (this is the cell that previously read `step=1n stop=10u`)

*For:* Answers "what will this run?" for an enabled row that produces no deck line at all, by naming the missing field instead of listing values the deck will never carry; appears in place of the analysis line whenever such a row is shown.

*Note:* 1420 wrote none of these words — the clause is the pre-existing one from ase::analysis_emit_msg (token `missing`); what 1420 changed is WHERE it appears. In the dialog it arrives framed and punctuated (`This tran analysis needs a value for 'step'.`); in this cell it appears bare, lower-case, with no subject and no full stop, so the column reads `needs a value for 'step'` — the pinned value of row AC1. `$f` is the field name, single-quoted by the code. Related oddity for the same surface: a DISABLED incomplete row is deliberately left alone and still shows the old key dump (`stop=10u`, row AC3), so one column now speaks two vocabularies depending on the row's checkbox.


**R9-160** · refusal

```text
is not one this simulator backend can set up
```

*Where:* Analyses pane, Arguments column cell — an ENABLED row whose analysis type the backend cannot emit (today `sp` and `pss`, which are probe-only)

*For:* Tells the user an enabled row of this type will contribute nothing to the deck because ASE-L has no template for it — as distinct from a value being missing, which would send them hunting for a field that does not exist.

*Note:* Pre-existing clause (ase::analysis_emit_msg token `unrenderable`); 1420 routes it to the column. Bare fragment again: the cell reads exactly `is not one this simulator backend can set up`, with no subject, so the sentence's subject is only implied by the row it sits on (pinned by row AC5). Note this clause is deliberately skipped by the preflight gate, which prints its own differently-worded block for the same condition — so the column and the gate do not say the same thing for this one token, unlike every other.


---

## The Deck preview pane

*12 strings.*

### from issue 1433 (stage 6)

**R9-161** · other

```text
* ASE-L checkpointed salvage: a Stop keeps what this run had
```

*Where:* The rendered ngspice deck itself (`<cell>_ase.deck`, and the deck preview / anything the user opens the deck in) — a SPICE comment line immediately above the checkpoint counters, emitted only for a run above the 100,000-point eligibility floor

*For:* Labels the block of checkpoint machinery ASE-L injects into the deck, so a user reading their own deck knows what the extra lines are for and who put them there.

*Note:* `*` is the SPICE comment character, part of the shipped line. Sentence fragment with no full stop, unlike every other string here. The same block also writes three bare marker tokens into the run log — `ASE-CKPT-ARMED`, `ASE-CKPT-DONE`, `ASE-RUN-COMPLETE` — which are protocol tokens rather than prose but are visible to anyone reading the log; they are not listed as separate rows here.


### from issue 1441 (stage 7)

**R9-162** · label

```text
above the analysis block
```

*Where:* Deck preview pane — first slot heading

*For:* Heads the block of lines written as .options cards before the analysis.


**R9-163** · label

```text
inside the analysis block
```

*Where:* Deck preview pane — second slot heading

*For:* Heads the block of lines written inside the .control/analysis block.


**R9-164** · label

```text
on the command line
```

*Where:* Deck preview pane — third slot heading

*For:* Heads the block of arguments passed to the simulator process.


**R9-165** · label

```text
in the run-directory start-up file
```

*Where:* Deck preview pane — fourth slot heading

*For:* Heads the block of lines written into the run directory's start-up file.


**R9-166** · status

```text
    (nothing)
```

*Where:* Deck preview pane — under any slot heading with no lines

*For:* Says explicitly that no line will be written into that slot.

*Note:* Shipped with four leading spaces, lower case, in parentheses.


**R9-167** · label

```text
not delivered
```

*Where:* Deck preview pane — heading of the notes block at the bottom

*For:* Heads the list of stored options that will not arrive, or will arrive somewhere unexpected.

*Note:* Lower case, unlike every other pane heading around it being a phrase rather than a title.


**R9-168** · other

```text
    [lindex $n 0] — [ase::ui::simdlg_plain [lindex $n 2]]
```

*Where:* Deck preview pane — each line of the 'not delivered' block

*For:* Prints one option name, an em dash, and the reason it will not arrive.

*Note:* The first field is the option name; the status word itself (off / suppressed / leaks / refused / error) is NOT printed, only the reason sentence.


**R9-169** · caution

```text
switched off -- absence is the setting, so no line is written
```

*Where:* Deck preview pane — 'not delivered' note for a switched-off flag

*For:* Explains why a flag the user set to 0 produces no line in the deck at all.


### from issue 1442 (stage 7)

**R9-170** · caution

```text
turned off for the $atype analysis, which crashes $sim under it, and put back immediately after
```

*Where:* Deck preview pane — 'not delivered' note for an option ASE-L turns off for one analysis

*For:* Explains the two suppression lines ASE-L itself writes into the deck (rule 1, the AC sens + KLU crash).


**R9-171** · caution

```text
set for the $atype analysis and NOT put back afterwards -- [ase::opt_leak_why $sim $name], so it stays in force for every analysis after it
```

*Where:* Deck preview pane — 'not delivered' note for a scoped row that cannot be restored

*For:* Warns in the preview that a per-analysis setting will outlive its analysis, and why.


**R9-172** · caution

```text
nothing can be written for it inside the $atype analysis block
```

*Where:* Deck preview pane — 'not delivered' note for a row with no in-block spelling

*For:* Says a row scoped to an analysis produces no line at all.


---

## Simulation > Options… — the sheet itself

*17 strings.*

### from issue 1441 (stage 7)

**R9-173** · label

```text
Find:
```

*Where:* Simulation > Options… sheet — the finder bar, leftmost label

*For:* Names the live substring-search entry that narrows the option list as you type.


**R9-174** · label

```text
Show all
```

*Where:* Simulation > Options… sheet — finder bar checkbutton

*For:* Ticked, it opens the other ~240 catalogue rows in groups instead of only the rows this bench stores.


**R9-175** · label

```text
Scope:
```

*Where:* Simulation > Options… sheet — finder bar, second label

*For:* Names the combobox that filters the catalogue to one analysis type.


**R9-176** · label

```text
Global
```

*Where:* Simulation > Options… sheet — Scope combobox, first value

*For:* The scope pick meaning every option this simulator has; the other values are the bench's own analysis type names (tran, ac, …) in lower case.


**R9-177** · label

```text
Results
```

*Where:* Simulation > Options… sheet — treeview column heading (3rd column)

*For:* Heads the badge column that says whether an option changes computed numbers.

*Note:* The tree column #0 (the group column) has NO heading text set — {Group} is passed only to the width helper, so the user sees a blank heading above the group names.


**R9-178** · label

```text
Written
```

*Where:* Simulation > Options… sheet — treeview column heading (4th column)

*For:* Heads the column saying which slot of the deck the option's line goes into.


**R9-179** · label

```text
Deck preview
```

*Where:* Simulation > Options… sheet — labelframe around the preview text pane

*For:* Titles the pane showing the exact lines this bench will emit and where.


**R9-180** · button

```text
Simulator Options…
```

*Where:* Analysis Options (<type>) dialog — button row, between OK and Cancel

*For:* Opens the options sheet with the scope preset to the analysis type being edited.

*Note:* Ships as the literal ellipsis character: "Simulator Options…". Sits beside the pre-existing OK / Cancel / Add / Delete.


**R9-181** · glyph

```text
⚠ CHANGES RESULTS
```

*Where:* Simulation > Options… sheet — Results cell, measured-yes rows (9 of them)

*For:* Badges a row measured to move a printed value.


**R9-182** · glyph

```text
⚠ MAY CHANGE RESULTS — UNVERIFIED
```

*Where:* Simulation > Options… sheet — Results cell, unmeasured rows (10 of them)

*For:* Badges a row the catalogue claims changes numbers but which nobody could make fire on a probe deck.

*Note:* Uses an em dash here; most other new copy in this pair of commits uses a double hyphen (--). Refuted rows draw no badge at all.


**R9-183** · status

```text
DECK
```

*Where:* Simulation > Options… sheet — Written cell

*For:* Says the option's line is written above the analysis block (an .options card).


**R9-184** · status

```text
ANALYSIS BLOCK
```

*Where:* Simulation > Options… sheet — Written cell

*For:* Says the option's line is written inside the .control/analysis block.


**R9-185** · status

```text
COMMAND LINE
```

*Where:* Simulation > Options… sheet — Written cell

*For:* Says the option is delivered as a command-line argument to the simulator.

*Note:* Two different doors (predeck and cmdline) both print this same cell.


**R9-186** · status

```text
START-UP FILE
```

*Where:* Simulation > Options… sheet — Written cell

*For:* Says the option is delivered through the run-directory start-up file.


**R9-187** · status

```text
NO DOOR
```

*Where:* Simulation > Options… sheet — Written cell, when no door can be resolved

*For:* Says this simulator has nowhere to write the option at all.


**R9-188** · label

```text
[string toupper $grp] ([llength $names])
```

*Where:* Simulation > Options… sheet — group header row in the Show all view

*For:* Heads each collapsible group of catalogue rows with the group name and how many rows are in it.

*Note:* Renders as e.g. DISPLAY (66). The 14 shipped group names are: convergence, device, diagnostics, display, integration, iteration, netlist, output, postproc, run, solver, temperature, tolerances, xspice.


### from issue 1442 (stage 7)

**R9-189** · status

```text
[string toupper $an] BLOCK
```

*Where:* Simulation > Options… sheet — Written cell, for a row stamped to one analysis

*For:* Says a per-analysis row is written inside that analysis's block whatever door its catalogue row would otherwise use.

*Note:* Renders as e.g. TRAN BLOCK. Sits in the same column as the pre-existing DECK / ANALYSIS BLOCK / COMMAND LINE cells, so two cells can read 'BLOCK' with different meanings.


---

## Simulation > Options… — the detail line under the grid

*46 strings.*

### from issue 1441 (stage 7)

**R9-190** · caution

```text
NOT OFFERED: [ase::opt_inert $sim $name]
```

*Where:* Simulation > Options… sheet — detail line under the row list

*For:* Prefix stamped on the catalogue's own 'inert in this build' reason for a row ASE-L will not offer.

*Note:* The prefix is new copy; the sentence after the colon is the pre-existing catalogue `inert` text.


**R9-191** · caution

```text
SET ELSEWHERE: [ase::opt_owner $sim $name]
```

*Where:* Simulation > Options… sheet — detail line under the row list

*For:* Prefix saying this option is owned by another part of ASE-L, not by this sheet.

*Note:* Prefix is new; the reason after the colon is the pre-existing catalogue `owner` text.


**R9-192** · caution

```text
CLAMPED: [ase::ui::optsheet_key $sim $name clamp]
```

*Where:* Simulation > Options… sheet — detail line under the row list

*For:* Prefix saying the value the user types will be clamped, with the catalogue's clamp reason.

*Note:* Prefix new; reason pre-existing.


**R9-193** · caution

```text
CAVEAT: [ase::ui::optsheet_key $sim $name defect][ase::ui::optsheet_key $sim $name caveat]
```

*Where:* Simulation > Options… sheet — detail line under the row list

*For:* Prefix carrying the catalogue's defect and caveat prose for a row that works only partly.

*Note:* Two catalogue keys are concatenated with NO separator between them, so a row carrying both prints them run together.


**R9-194** · status

```text
CHANGED from the default [ase::opt_default $sim $name]
```

*Where:* Simulation > Options… sheet — detail line, storage verdict segment

*For:* Says the bench stores a value different from the simulator's declared default, and names that default.

*Note:* Mixed case mid-phrase: an uppercase word followed by lower-case prose, unlike the all-caps siblings below it.


**R9-195** · status

```text
SET to this simulator's own default
```

*Where:* Simulation > Options… sheet — detail line, storage verdict segment

*For:* Says the bench stores this option but at the value the simulator would have used anyway.


**R9-196** · status

```text
SET; this simulator declares no default to compare with
```

*Where:* Simulation > Options… sheet — detail line, storage verdict segment

*For:* Says the row is stored but no default exists to say whether it was changed (true for most of the 247 rows).


**R9-197** · status

```text
SET; this simulator's catalogue has no such option
```

*Where:* Simulation > Options… sheet — detail line, storage verdict segment

*For:* Says the bench stores a name this simulator's catalogue does not contain.


**R9-198** · glyph

```text
  |  
```

*Where:* Simulation > Options… sheet — detail line, separator between segments

*For:* Joins the help text, the offer verdict, the measurement note and the storage verdict into one wrapped line.

*Note:* Two spaces either side of a bare pipe; with a long results_why the line can reach several wrapped rows.


**R9-199** · advice

```text
angle unit for vp() and ph(). RADIANS by default -- a phase margin computed without it is wrong by 57.2958x
```

*Where:* Simulation > Options… sheet — detail line, leading help segment for the `units` row

*For:* The help text for the one option the batch calls the most consequential; it had none before this commit.


**R9-200** · status

```text
MEASURED 2026-09-13 on both binaries: .options scale=0.5 takes @m1[w] 2.000000e-06 -> 1.000000e-06 and @m1[l] 1.5e-07 -> 7.5e-08
```

*Where:* options sheet detail line — measurement note for `scale`

*For:* Names the measurement behind this row's ⚠ CHANGES RESULTS badge.

*Note:* All 21 results_why strings below share this shape: a date, 'on both binaries', and a raw before -> after value pair. They are engineer's transcript, shown verbatim in the GUI.


**R9-201** · status

```text
MEASURED 2026-09-13 on both binaries, two binned BSIM4 models across the W bin edge: .options wnflag=1 takes @m1[vth] 1.088900 -> 0.688900 and i(vd) -7.73196e-05 -> -6.23913e-04. The bare card .options wnflag delivers NOTHING (issue 1438/1439)
```

*Where:* options sheet detail line — measurement note for `wnflag`

*For:* Names the measurement behind the badge and warns the bare card form delivers nothing.

*Note:* Cites an internal issue number (1438/1439) in user-visible text.


**R9-202** · status

```text
MEASURED 2026-09-13 on both binaries: .options sqrnoise takes onoise_total 3.147875e-07 -> 9.909116e-14
```

*Where:* options sheet detail line — measurement note for `sqrnoise`

*For:* Names the measurement behind this row's badge.


**R9-203** · status

```text
MEASURED 2026-09-13 on both binaries: .options cshunt_value=1n moves every AC, TRAN and NOISE value of the probe deck (vdb(mid) -2.74175e-01 -> -2.87193e-01)
```

*Where:* options sheet detail line — measurement note for `cshunt_value`

*For:* Names the measurement behind this row's badge.


**R9-204** · status

```text
MEASURED 2026-09-13 on both binaries, a trnoise source: .options notrnoise takes v(n) to 0.000000e+00 at every timepoint
```

*Where:* options sheet detail line — measurement note for `notrnoise`

*For:* Names the measurement behind this row's badge.


**R9-205** · status

```text
MEASURED 2026-09-13 on both binaries: .options seed=12345 and seed=999 give different trnoise samples, and both differ from the unseeded run
```

*Where:* options sheet detail line — measurement note for `seed`

*For:* Names the measurement behind this row's badge.


**R9-206** · status

```text
MEASURED 2026-09-13 on both binaries, a deck with one .meas: .options autostop takes the transient from 226 data rows to 2
```

*Where:* options sheet detail line — measurement note for `autostop`

*For:* Names the measurement behind this row's badge.


**R9-207** · status

```text
MEASURED 2026-09-13 on both binaries under ngbehavior=ps, delivered through the run-directory start-up file: diode_cj0=10p takes the AC current imaginary part 0.000000e+00 -> 1.066292e-04. -D cannot deliver it (CP_STRING)
```

*Where:* options sheet detail line — measurement note for `diode_cj0`

*For:* Names the measurement behind this row's badge and the door it needed.

*Note:* Ends on a bare C-level type name, CP_STRING, in user-facing copy.


**R9-208** · status

```text
MEASURED 2026-09-13 on both binaries under ngbehavior=ps, delivered through the run-directory start-up file: diode_rser=100 takes i(vb) 5.670347e-03 -> 5.867302e-04
```

*Where:* options sheet detail line — measurement note for `diode_rser`

*For:* Names the measurement behind this row's badge.


**R9-209** · status

```text
⚠ REFUTED. MEASURED 2026-09-13 on both binaries, five resistors over bv_max: .options warn=1 takes the run from 0 to 5 SOA messages and EVERY printed value is byte-identical. It is a diagnostic printer, not a result
```

*Where:* options sheet detail line — measurement note for `warn` (a refuted row, no badge)

*For:* Tells the user the catalogue's own 'changes results' claim for this row was measured false.


**R9-210** · status

```text
⚠ REFUTED. MEASURED 2026-09-13 on both binaries: .options maxwarns=2 takes 5 SOA messages to 2 and changes no printed value
```

*Where:* options sheet detail line — measurement note for `maxwarns` (a refuted row, no badge)

*For:* Tells the user the claim for this row was measured false.


**R9-211** · status

```text
⚠ REFUTED. MEASURED 2026-09-13 on both binaries: num_threads=1 against the default gives byte-identical OP, AC, TRAN and NOISE values. It is an OpenMP thread count
```

*Where:* options sheet detail line — measurement note for `num_threads` (a refuted row, no badge)

*For:* Tells the user the claim for this row was measured false.


**R9-212** · status

```text
NOT MEASURED: needs an event-driven XSPICE circuit for the automatic analog/event bridge to have anything to bridge
```

*Where:* options sheet detail line — 'not measured' note for `auto_bridge`

*For:* Says why the ⚠ MAY CHANGE RESULTS — UNVERIFIED badge on this row could not be settled.


**R9-213** · status

```text
NOT MEASURED: needs an event-driven XSPICE circuit, as auto_bridge does
```

*Where:* options sheet detail line — 'not measured' note for `no_auto_bridge_family`

*For:* Says why this row's badge could not be settled.


**R9-214** · status

```text
NOT MEASURED: needs an XSPICE code model that emits an errmsg
```

*Where:* options sheet detail line — 'not measured' note for `noisyxspice`

*For:* Says why this row's badge could not be settled.

*Note:* 'errmsg' is a bare source identifier in user-facing copy.


**R9-215** · status

```text
NOT MEASURED: overrides a trtol reduction that only XSPICE A devices force
```

*Where:* options sheet detail line — 'not measured' note for `xtrtol`

*For:* Says why this row's badge could not be settled.


**R9-216** · status

```text
NOT MEASURED: needs a BSIM3/BSIM4 model card whose parameters the sanity clamps actually move
```

*Where:* options sheet detail line — 'not measured' note for `ng_nomodcheck`

*For:* Says why this row's badge could not be settled.


**R9-217** · status

```text
NOT MEASURED: read at netlist-read time and only for a B-source-expanded resistor; a constant r= expression stays an ordinary resistor
```

*Where:* options sheet detail line — 'not measured' note for `enable_noisy_r`

*For:* Says why this row's badge could not be settled.


**R9-218** · status

```text
NOT MEASURED: needs an operating point that actually requires gmin stepping
```

*Where:* options sheet detail line — 'not measured' note for `dyngmin`

*For:* Says why this row's badge could not be settled.


**R9-219** · status

```text
NOT MEASURED: the probe circuit failed gmin and source stepping with and without it, so nothing distinguished the two runs
```

*Where:* options sheet detail line — 'not measured' note for `topo_reduce`

*For:* Says why this row's badge could not be settled.


**R9-220** · status

```text
NOT MEASURED: no probe deck made the timestep ceiling the binding constraint -- breakpoints dominated every one tried
```

*Where:* options sheet detail line — 'not measured' note for `nostepsizelimit`

*For:* Says why this row's badge could not be settled.


**R9-221** · status

```text
NOT MEASURED: injects .param SWSOA=1 after every .lib, so it needs a PDK library that reads SWSOA
```

*Where:* options sheet detail line — 'not measured' note for `soacheck`

*For:* Says why this row's badge could not be settled.


### from issue 1442 (stage 7)

**R9-222** · status

```text
SCOPED: set for this analysis and put back after it
```

*Where:* Simulation > Options… sheet — detail line, scope segment (only when a scope is picked)

*For:* Promises the value is restored after the analysis it was set for.


**R9-223** · status

```text
GLOBAL: this option is not offered per analysis
```

*Where:* Simulation > Options… sheet — detail line, scope segment

*For:* Says the option has no per-analysis scope and will apply to the whole run.


**R9-224** · caution

```text
LEAKS: [ase::opt_leak_why $sim $name]
```

*Where:* Simulation > Options… sheet — detail line, scope segment

*For:* Warns that a per-analysis value cannot be put back, followed by one of the five reasons below.


**R9-225** · caution

```text
$sim declares no default for it, so there is nothing to put it back to
```

*Where:* Simulation > Options… sheet — detail line, after 'LEAKS: '

*For:* Reason a scoped option leaks: no default to restore.


**R9-226** · caution

```text
$sim has no way to write it back inside the analysis block
```

*Where:* Simulation > Options… sheet — detail line, after 'LEAKS: '

*For:* Reason a scoped option leaks: no spelling for the restore line.


**R9-227** · caution

```text
it does nothing in this build
```

*Where:* Simulation > Options… sheet — detail line, after 'LEAKS: '

*For:* Reason a scoped option leaks: the option is inert here.


**R9-228** · caution

```text
it is set elsewhere, not from this sheet
```

*Where:* Simulation > Options… sheet — detail line, after 'LEAKS: '

*For:* Reason a scoped option leaks: another part of ASE-L owns it.


**R9-229** · caution

```text
this simulator's catalogue has no such option
```

*Where:* Simulation > Options… sheet — detail line, after 'LEAKS: '

*For:* Reason a scoped option leaks: the name is not in the catalogue.

*Note:* Identical wording to the 1441 storage-verdict tail 'SET; this simulator's catalogue has no such option', so the same clause can appear twice in one detail line behind two different prefixes.


**R9-230** · caution

```text
GATED: [ase::opt_gate_why $sim $name ...]
```

*Where:* Simulation > Options… sheet — detail line, capability-gate segment

*For:* Prefix on the sentence explaining why a listed option may not exist in this build.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* The row is always listed, never hidden; the three sentences it can carry follow.


**R9-231** · caution

```text
this build of $sim does not have this option; it would be written [ase::opt_door_phrase $door]
```

*Where:* Simulation > Options… sheet — detail line, after 'GATED: '

*For:* Says the capability probe found the option absent, and names the door it would have used.


**R9-232** · caution

```text
$sim has not been measured for this option; it would be written [ase::opt_door_phrase $door]
```

*Where:* Simulation > Options… sheet — detail line, after 'GATED: '

*For:* Says the binary was never probed for this capability.


**R9-233** · caution

```text
ASE-L could not find out whether this build of $sim has this option; it is offered anyway, and it would be written [ase::opt_door_phrase $door]
```

*Where:* Simulation > Options… sheet — detail line, after 'GATED: '

*For:* Says the gate could not be evaluated, and that the row is offered regardless.


**R9-234** · other

```text
through no door this simulator offers
```

*Where:* Simulation > Options… sheet — detail line, the door phrase inside the three GATED sentences

*For:* The fallback door phrase when no slot can be resolved; completes 'it would be written …'.

*Note:* The other four door phrases it substitutes are the same four strings the Deck preview uses as slot headings (above the analysis block / inside the analysis block / on the command line / in the run-directory start-up file), here read mid-sentence.


**R9-235** · label

```text
output file format for CIDER's own device dumps
```

*Where:* Simulation > Options… sheet — detail line, leading help segment for the `filetype` row

*For:* Help text for the one genuinely capability-gated catalogue row (present only in a --enable-cider build).


---

## Simulation > Options… — the speller's refusals, and the inert reasons they quote

*18 strings.*

### from issue 1437 (stage 7)

**R9-236** · refusal

```text
ase: simulator '$sim' describes no option '$name'
```

*Where:* options speller refusal — raised by ase::opt_door and again by ase::opt_line; ase::state_option_delivery catches it and passes the message through verbatim as the `refused` note beside that option's row in the deck-preview / options notes pane

*For:* Says the named simulator's option catalogue has no row for this option name, so ASE-L will not write a line for it.

*Note:* Same string is written twice in the file (ase::opt_door and ase::opt_line). Prefix is lowercase `ase:` — every refusal below shares it; the project's own UI-copy rule is acronyms uppercase. $sim is a simulator entry name, $name the option name.


**R9-237** · refusal

```text
ase: option '$name' has no cptype
```

*Where:* options speller refusal — ase::opt_door, when a catalogue row is malformed; reaches the user as the `refused` note text in the options notes pane

*For:* Says the catalogue row for this option is missing its type column, so no door and no spelling can be computed.

*Note:* `cptype` is ngspice's word (CP_NUM / CP_BOOL / …) and is internal vocabulary appearing in a user-reachable sentence.


**R9-238** · refusal

```text
ase: option slot must be 'deck' or 'control', not '$where'
```

*Where:* options speller refusal — ase::opt_door, when a caller asks for a slot that is not one of the two

*For:* Rejects a request to place an option somewhere other than above the analysis block ('deck') or inside it ('control').

*Note:* Purely an API misuse message; 'deck'/'control' are ASE-L's internal slot words, not the phrases the deck preview uses ("above the analysis block" / "inside the analysis block").


**R9-239** · refusal

```text
ase: option '$name' must reach '$sim' before the input file is read, so it cannot be written into the analysis block
```

*Where:* options speller refusal — ase::opt_door, pre-deck phase asked for the in-block slot; shown as the `refused` note beside the option row

*For:* Explains that this option is consumed before the netlist is read, so it cannot be delivered from inside the analysis block.

*Note:* Written in source as a backslash-continued literal; the shipped string is the single line quoted here.


**R9-240** · refusal

```text
ase: option '$name' is read while '$sim' loads the circuit, so it cannot be written into the analysis block
```

*Where:* options speller refusal — ase::opt_door, deck phase asked for the in-block slot; shown as the `refused` note beside the option row

*For:* Explains that this option is read during circuit load, so an in-block line would arrive too late.

*Note:* Backslash-continued literal in source; shipped as this one line.


**R9-241** · refusal

```text
ase: option '$name' is read by '$sim' after the circuit is loaded, so it cannot be written above the analysis block
```

*Where:* options speller refusal — ase::opt_door, run phase asked for the above-block slot; shown as the `refused` note beside the option row

*For:* Explains that this option is read only after load, so a card above the analysis block would be ignored.

*Note:* Backslash-continued literal in source; shipped as this one line. This is the `set units=degrees` class the issue measured as a 57.3x silent error.


**R9-242** · refusal

```text
ase: option '$name' has an unknown phase '$phase'
```

*Where:* options speller refusal — ase::opt_door fall-through, when a catalogue row carries a phase word ASE-L does not know

*For:* Says the catalogue row names a delivery phase outside ASE-L's vocabulary, so no door can be computed.

*Note:* Catalogue-integrity message that can still surface to a user through the notes pane; 'phase' is unexplained.


**R9-243** · refusal

```text
ase: option '$name' does nothing in this build: $reason
```

*Where:* options speller refusal — ase::opt_line, for a catalogue row marked inert; also the `inert` reason row of the delivery report

*For:* Refuses to write a line for an option that this simulator build cannot act on, and appends the catalogue's reason.

*Note:* $reason is substituted from the catalogue's `inert` column — the engineer-prose sentences listed separately below, so this message can end up several clauses long.


**R9-244** · refusal

```text
ase: simulator '$sim' has no way to write a '$cptype' option through the '$door' door ('$name')
```

*Where:* options speller refusal — ase::opt_line, when the (door × cptype) table has no template; shown as the `refused` note beside the option row

*For:* Says this option's value type has no spelling through the route it would have to take, so the request is a type error.

*Note:* Backslash-continued literal; shipped as this one line. Leaks three internal words at once — cptype, door, and the door's raw value ('options', 'control', 'predeck', 'predeck-file', 'cmdline').


**R9-245** · caution

```text
CKTnewTask leaves TSKfixLimit uncopied (cktntask.c:68 is the bare comment /* fixLimit */), so the option is dropped the moment an analysis is issued as a .control command, which is the route ASE-L uses
```

*Where:* catalogue `inert` reason for the option `oldlimit` — appears in the speller's refusal and in the delivery report's `inert` note

*For:* Explains that this option is silently dropped on the route ASE-L runs analyses through.

*Note:* Quotes C identifiers, a file:line and a C comment to a user; longest of the reason strings.


**R9-246** · caution

```text
cktsopt.c:187 assigns the BOOLEAN (val->rValue == 1.2) to a double, so every value but 1.2 sets the factor to 0.0. The CKTnewTask default is already 1.2
```

*Where:* catalogue `inert` reason for the option `klu_memgrow_factor` — speller refusal and delivery-report `inert` note

*For:* Explains that any value other than the default silently zeroes this factor, so the option is not usable.

*Note:* Describes an upstream bug in C terms; BOOLEAN is shouted mid-sentence.


**R9-247** · caution

```text
cktsopt.c:199-207 needs the PREDICTOR preprocessor flag, which is defined nowhere in this tree; the option forces TSKnewtrunc = 0 and warns
```

*Where:* catalogue `inert` reason for the option `newtrunc` — speller refusal and delivery-report `inert` note

*For:* Explains that this option is compiled out of the build, and that asking for it makes ngspice warn.

*Note:* "and warns" trails without saying what warns or where the user would see it.


**R9-248** · caution

```text
read only in src/sharedspice.c, so it is a libngspice variable. The ngspice executable ASE-L runs never reads it
```

*Where:* catalogue `inert` reason shared by the options `addescape` and `nosighandling` — speller refusal and delivery-report `inert` note

*For:* Explains that this variable belongs to the shared-library build of ngspice, not the executable ASE-L drives.

*Note:* Two catalogue rows carry this identical wording.


**R9-249** · caution

```text
read only in src/sharedspice.c, so it is a libngspice variable. Use the simulator entry -n flag instead
```

*Where:* catalogue `inert` reason for the option `no_spiceinit` — speller refusal and delivery-report `inert` note

*For:* Explains the option is libngspice-only and points the user at the ASE-L simulator-entry flag that does the same job.

*Note:* The only inert reason that offers a remedy; names the flag as `-n` with no surrounding words ("the simulator entry -n flag").


**R9-250** · caution

```text
x11.c:707 reads it inside `if (0 && ...)`, so the read is dead -- and spinit sets it, which makes it a visible lie in `set` output
```

*Where:* catalogue `inert` reason for the option `x11lineararcs` — speller refusal and delivery-report `inert` note

*For:* Explains that the option is dead code even though ngspice's start-up file appears to set it.

*Note:* Contains backtick markup and a literal `--` that will render as two hyphens; "a visible lie" is a strong phrase for shipped copy.


**R9-251** · caution

```text
options.c:346-348 warns `compiled without debug messages` because FTEDEBUG is defined nowhere in this tree
```

*Where:* catalogue `inert` reason for the option `debug` — speller refusal and delivery-report `inert` note

*For:* Explains that debug output is compiled out of this build, so the option only produces a warning.

*Note:* Backtick-quoted ngspice warning text embedded in the sentence.


**R9-252** · caution

```text
the .options card is intercepted front-end side (spiceif.c:472-499) and the print it arms happens on the dot-card path only. MEASURED on both binaries: on a deck whose analyses run inside .control it changes nothing at all, while the same option on a dot-card deck does
```

*Where:* catalogue `inert` reason shared by the six front-end print flags `acct`, `list`, `nomod`, `nopage`, `node`, `opts` — speller refusal and delivery-report `inert` note

*For:* Explains that these accounting/print flags do nothing on the route ASE-L uses, because the printing only happens on the dot-card path.

*Note:* Six rows carry this identical wording. "MEASURED on both binaries" is lab shorthand shouted inside a user-visible reason; the closing "while the same option on a dot-card deck does" ends on a dangling verb.


**R9-253** · caution

```text
documented by the ngspice manual as the workaround for savecurrents + AC, and the string appears NOWHERE in the source tree. Tombstone -- do not re-add it
```

*Where:* catalogue `inert` reason for the tombstone row `nosavecurrents` — speller refusal and delivery-report `inert` note

*For:* Explains that a manual-documented option does not exist in the simulator at all.

*Note:* The final clause is addressed to a developer, not to a user, and would read as nonsense in a sheet; also a literal `--` and a shouted NOWHERE.


---

## Simulation > Options… — catalogue prose (the per-option help text)

*5 strings.*

### from issue 1437 (stage 7)

**R9-254** · caution

```text
the live code is inside #ifdef XSPICE_EXP and nothing in this tree defines XSPICE_EXP. It is an XSPICE code-model knob, not a supply ramp
```

*Where:* catalogue `inert` reason for the option `ramptime` — substituted into "ase: option '$name' does nothing in this build: $reason" and into the delivery report's `inert` note

*For:* Explains why setting ramptime has no effect in this ngspice build, and corrects a likely misreading of the name.

*Note:* Reads as a source comment: preprocessor symbol, "in this tree". Starts lowercase, then a second sentence starts capitalised — all the inert reasons share that shape.


**R9-255** · label

```text
add .save lines for every device terminal current
```

*Where:* catalogue `help` (description) text for the four `savecurrents*` rows — the option catalogue's description column, read by the later options sheet / finder

*For:* Describes what the savecurrents family of options does when switched on.

*Note:* Four rows (savecurrents, savecurrents_bsim3, savecurrents_bsim4, savecurrents_mos1) carry this identical description, so the finder shows the same sentence four times. ASE-L's own wording, not ngspice's.


**R9-256** · label

```text
seed for the random number generator; a number, or the word random
```

*Where:* catalogue `help` (description) text for the `seed` row — the option catalogue's description column

*For:* Describes what value the seed option takes.

*Note:* ASE-L's own wording. The bare word `random` is unquoted in the sentence.


**R9-257** · label

```text
print the seed value the random number generator was given
```

*Where:* catalogue `help` (description) text for the `seedinfo` row — the option catalogue's description column

*For:* Describes what switching on seedinfo makes the simulator print.

*Note:* ASE-L's own wording; does not say where it is printed.


**R9-258** · label

```text
file for SOA warnings; pairs with the warn option, which has a different door
```

*Where:* catalogue `help` (description) text for the `soa_log` row — the option catalogue's description column (the one command-line-delivered option)

*For:* Describes the SOA log file option and points at the related warn option.

*Note:* "door" is ASE-L's internal word for a delivery route and is used here with no explanation; ASE-L's own wording.


---

## Simulation > Options… — the delivery report

*3 strings.*

### from issue 1437 (stage 7)

**R9-259** · status

```text
this simulator's catalogue has no such option
```

*Where:* delivery report reason (ase::state_option_delivery) — the `unknown` row; printed as the note beside a stored option in the deck-preview notes pane

*For:* Tells the user a stored option is not in this simulator's catalogue; ASE-L leaves it alone rather than refusing the bench.

*Note:* A later stage added a second, identical copy of this sentence in ase::opt_gate_why's phrase table — two literals, one wording, so a reword must touch both.


**R9-260** · status

```text
this option needs the '$door' door; the deck above the analysis block cannot carry it
```

*Where:* delivery report reason (ase::state_option_delivery) — the wrong-door row; printed as the note beside a stored option in the deck-preview notes pane

*For:* Tells the user a stored option cannot be delivered on the card above the analysis block, and names the route it does need.

*Note:* Backslash-continued literal; shipped as this one line. $door interpolates a raw internal token ('control', 'predeck', 'predeck-file', 'cmdline'); the sentence half-translates — it spells out "the deck above the analysis block" but leaves the destination untranslated.


**R9-261** · status

```text
no line is written for value '$value'
```

*Where:* delivery report reason (ase::state_option_delivery) — the `silent` row; printed as the note beside a stored option in the deck-preview notes pane

*For:* Tells the user that an option they switched on produced no line at all, because the value is not truthy for a valueless template.

*Note:* States what the tool did not do rather than what the user will get; no remedy clause.


---

## The run log and the CIW notice channel

*26 strings.*

### from issue 1404 (stage 3a)

**R9-262** · caution

```text
ase: Stopping this run discards it — ngspice in batch mode writes nothing on a stop.
```

*Where:* CIW / ASE-L message area, plain (not error) — printed once per launch, at the last instant before the simulator is executed, immediately after the "using" report line.

*For:* Warns, before the user has any reason to press Stop, that Stop is not a pause or a partial save: pressing it throws the whole run away. Said only for a simulator whose backend declares what a stop costs; a run that was refused never sees it.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Composed from two halves that a reviewer may want to edit separately: the FRAME is ase::run_stop_warning — "Stopping this run discards it — <clause>." — and the CLAUSE is ngspice adapter content, the `before` key of ase::backend::ngspice::run_stop_cost, literally "ngspice in batch mode writes nothing on a stop". The "ase: " prefix is added at the echo site, not by the proc. The dash is an em dash (U+2014). A backend that declares no run_stop_cost hook prints nothing at all — there is no fallback wording. Sentence-initial capital "Stopping" after the lowercase "ase: " prefix is inconsistent with the other ASE-L CIW lines, which continue lowercase after the prefix.


**R9-263** · status

```text
stop      : Stopping this run discards it — ngspice in batch mode writes nothing on a stop.
```

*Where:* Run log file, header block — the last key/value field, written below deck/directory/command and above the casemode note; the user reads it after the fact, not live.

*For:* Records in the run's own log what pressing Stop would have cost, so a user reading the log a week later knows a missing rawfile means the run was stopped rather than the simulator having failed.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Same sentence as the CIW line, but with the header's fixed-width field label `stop      : ` instead of the `ase: ` prefix — six spaces pad `stop` to the header's column. The whole line is omitted when the backend declares no run_stop_cost hook, keeping the log byte-identical to the older committed format. Reviewer should decide whether the log field wants the same prose as the CIW line or a shorter value.


**R9-264** · status

```text
ase: simulation stopped — nothing of this run was written
```

*Where:* CIW / ASE-L message area, plain (not error) — printed by ase::ui::do_stop the moment a Stop actually kills a running simulator, from either Stop door (menu or strip button).

*For:* Confirms the Stop took effect and, in the same breath, tells the user not to go looking for a rawfile — there is none. Printed only on the path that really killed a process.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Frame is ase::run_stopped_msg — "ase: simulation stopped — <clause>" — and the clause is ngspice adapter content, the `after` key of ase::backend::ngspice::run_stop_cost, literally "nothing of this run was written". Em dash (U+2014). NO TRAILING FULL STOP, unlike its launch-time sibling above which ends in a period — the inconsistency is in the shipped strings. The two early-return paths keep their existing sentences ("ase: no simulation running for this session", "ase: Stop is not available on Windows"), which are pre-existing and not part of this issue. A backend with no run_stop_cost hook stays silent here, so a successful Stop on an unregistered simulator says nothing at all.


### from issue 1429 (stage 5)

**R9-265** · status

```text
ase: results -- a row whose expression names exactly one vector is read from the results file; anything else is read from the print log. This run: [llength $rawrows] from the file, [llength $logrows] from the log.
```

*Where:* Run notice log / CIW — one line per run, emitted by `ase::echo ... note` from the `result_probe` dispatcher as results are read back

*For:* States ⚖ R3's rule on screen and reports how this run's Outputs rows split between the two readers, so the user can tell where each Value came from.

*Note:* This is the only place the R3 rule is stated to the user. The two `[llength ...]` are computed counts (the issue file stresses they are derived, never prose), rendering e.g. `This run: 2 from the file, 1 from the log.` Note the plural `ase: results --` here against the singular `ase: result --` used by the two below; that inconsistency ships.


**R9-266** · refusal

```text
ase: result -- output '$ex' matches [llength $vals] different numbers in the results file ([join [lsort $pls] {, }]), so no value is recorded for it: which one it means cannot be known, and a guess would put a wrong number in the Outputs pane.
```

*Where:* Run notice log / CIW — error-tagged line, one per offending Outputs row, from the rawfile reader

*For:* Explains why an Outputs row's Value column is left EMPTY: the vector name matched more than one distinct number (two `sens` rows write two plots both called `Sensitivity Analysis`; ngspice can also write the same name twice inside one plot).

*Note:* `$ex` is the user's expression; `[join [lsort $pls] {, }]` lists the plot names, e.g. `(Sensitivity Analysis, Sensitivity Analysis)` — the two plots can share a name, so this parenthetical can look like a duplicate to the reader. Deliberately parallel to the older log-reader sentence about case collisions; the tail clause after the colon is identical to it.


**R9-267** · status

```text
ase: result -- the results file holds no single-point value for [join $missing {, }], so [expr {[llength $missing] == 1 ? {that row has} : {those rows have}}] no value: a multi-point vector is not a scalar, and a run that computed nothing writes only the constants plot.
```

*Where:* Run notice log / CIW — note-tagged line, one per run, listing every row that got no value from the rawfile reader

*For:* Explains blank Value cells when the results file has no scalar for those expressions — either the vector is a sweep, or the run computed nothing and wrote only the `constants` plot.

*Note:* Two placeholders: `[join $missing {, }]` is a comma-separated list of expressions, and the `[expr ...]` is a singular/plural switch rendering `that row has` or `those rows have`. Emitted ONLY when a results file actually exists. The reader never falls back to the print log, so this line is the whole explanation the user gets.


### from issue 1430 (stage 6)

**R9-268** · label

```text
ase: results -- $s
```

*Where:* ASE-L run log / notice channel — the common prefix on EVERY reconciliation line below, emitted once per run after the simulator exits (ase::reconcile_report, src/ase.tcl ~7622)

*For:* Prefixes each reconciliation finding so the user can see the line is about the results file rather than the run itself; $s is one of the sentences below.

*Note:* Every sentence in this list ships behind this prefix, so on screen they read e.g. `ase: results -- the plot sidecar tb_ase.plotmap is missing, ...`. The tag is `note` for the fault verdicts (nomap/mislabel/under/over/predmismatch) and empty for ok/norun. The sentences themselves are all lowercase-initial by construction because they are designed to follow this prefix.


**R9-269** · advice

```text
the [join $utypes {, }] analysis also computes '[join $unames {', '}]'. ASE-L leaves it out of the results file: every plot whose name contains 'Operating Point' reads back as the OP and would replace the real one.
```

*Where:* ASE-L run log / notice channel — said WHATEVER the verdict (including `ok`), once per run, when an enabled analysis is predicted to compute a plot the deck deliberately does not write

*For:* Tells the user that an enabled analysis produced a companion plot (e.g. the AC Operating Point) that ASE-L knowingly did not capture, and why keeping it would corrupt Annotate Operating Point.

*Note:* Source literal spans three lines with Tcl backslash-continuations; Tcl collapses each to one space, so the shipped string is as written here. Rendered example: `ase: results -- the ac analysis also computes 'AC Operating Point'. ASE-L leaves it out of the results file: every plot whose name contains 'Operating Point' reads back as the OP and would replace the real one.` With more than one type/name the joins give `the ac, pz analysis also computes 'AC Operating Point', 'Distortion Operating Point'.` — note the singular 'analysis' after a plural list.


**R9-270** · caution

```text
the plot sidecar [file tail $mappath] is missing, so the $actual plot(s) in the results file cannot be matched to the analysis rows that asked for them.
```

*Where:* ASE-L run log / notice channel — `nomap` verdict: plots exist on disk but the plotmap sidecar is absent

*For:* Warns that results were produced but cannot be attributed to the analysis rows that requested them, because the sidecar ASE-L writes alongside the raw file is gone.

*Note:* $mappath renders as the bare filename, e.g. `tb_bandgap_ase.plotmap`. `plot(s)` is the literal parenthesised plural — it is not pluralised by count, unlike the `under` sentence below which does branch on one-vs-many.


**R9-271** · caution

```text
$kw of the [join $lost {, }] analysis $kv not captured: this run recorded $mapped and the results file holds $actual.
```

*Where:* ASE-L run log / notice channel — `under` verdict: fewer plots in the results file than the sidecar recorded (the silent-`write`-abort case)

*For:* Names which analysis type lost a plot when ngspice's `write` aborted silently, a case that produces rc 0 and nothing on either stream today.

*Note:* $kw is the literal `one plot` or `$k plots`; $kv is `was` or `were`. Rendered: `one plot of the tran analysis was not captured: this run recorded 4 and the results file holds 3.` Issue 1430's own table paraphrases this as "one plot of the `tran` analysis was not captured" — that fragment is accurate, the rest of the sentence is not in the issue. Issue 1433 later added a sibling branch for a STOPPED run; that wording is 1433's, not this one's.


**R9-272** · caution

```text
this run captured $actual plots where the registry expected $mapped; the extra ones ([join [lrange $raws $mapped end] {, }]) were ignored.
```

*Where:* ASE-L run log / notice channel — `over` verdict: more plots in the results file than the sidecar recorded

*For:* Tells the user the results file holds plots nothing asked for, names them, and says they were ignored.

*Note:* Rendered: `this run captured 5 plots where the registry expected 4; the extra ones (constants) were ignored.` Issue 1430's table paraphrases it as "this run captured N plots where the registry expected M", dropping the second clause. `$actual plots` is unconditionally plural here (no one/many branch), unlike the `under` sentence.


**R9-273** · caution

```text
the $mty analysis in row $mai recorded '$mgot' where the results file holds '$mwant', so results cannot be matched to the row that asked for them.
```

*Where:* ASE-L run log / notice channel — `mislabel` verdict, FILE side: the sidecar record disagrees with the plot name actually in the results file

*For:* Reports that a recorded plot identity and the results file disagree at the same position, naming the row, so the user knows results cannot be trusted to map back to rows.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Assembled from two literals in the same proc: the sentence is `"the $mty analysis in row $mai recorded '$mgot' where $msay '$mwant', so results cannot be matched to the row that asked for them."` with `set msay "the results file holds"` on this arm. $mai is the ROW INDEX in `analyses` (0-based), printed as a bare number — `in row 2` may read to a user as an ordinal rather than a zero-based index.


**R9-274** · caution

```text
the $mty analysis in row $mai recorded '$mgot' where the registry declares '$mwant', so results cannot be matched to the row that asked for them.
```

*Where:* ASE-L run log / notice channel — `mislabel` verdict, REGISTRY side: the recorded plot name does not match the registry's declared `select` glob (the `setplot previous` over-walk that saturates on ngspice's `constants` plot)

*For:* Reports that a plot was recorded under a name the registry never declared for that analysis — the only signal that an over-walk appended ngspice's twelve mathematical constants under a plausible record.

*Rendered:* the source does not hold this as one literal — it composes it (label plus unit, frame plus adapter clause, a branch variable expanded, or a placeholder shown where the code writes a variable). This is what the user reads; an edit lands on the pieces.

*Note:* Same literal as the previous row with `set msay "the registry declares"`. Here $mwant is a GLOB pattern from the registry's `select` key, so the quoted value may contain `*` and read oddly to a user, e.g. `where the registry declares 'Sensitivity Analysis*'`.


**R9-275** · status

```text
the enabled rows predict $pred plot(s) and this run recorded $mapped: the run stopped before the rest, or the analyses changed between rendering the deck and reading it back.
```

*Where:* ASE-L run log / notice channel — `predmismatch` verdict: the enabled analysis rows no longer account for the number of records written

*For:* Reports the two numbers that disagree and names both causes it cannot distinguish: a run that quit early, or a state edited between deck render and readback.

*Note:* This is the sentence the issue file records as CORRECTED during the work — an earlier draft blamed only "the analyses changed between rendering the deck and reading it back", which was the wrong cause on the day it was measured, so it now names both. Two-cause sentences are the ones worth a reviewer's eye. `plot(s)` again is the parenthesised plural. Issue 1433 later added a one-cause variant for a STOPPED run; that is 1433's wording, not this one's.


### from issue 1432 (stage 6)

**R9-276** · status

```text
NOISE Operating Point
```

*Where:* Post-run reconciliation note in the run log — the "also computes" sentence, which inserts the plot's `select` literal

*For:* New plot name that now reaches the pre-existing sentence "the <types> analysis also computes '<names>'. ASE-L leaves it out of the results file: every plot whose name contains 'Operating Point' reads back as the OP and would replace the real one." — printed after a noise run with `keepopinfo` on.

*Note:* This is ngspice's own plot name quoted back at the user, so it is not ASE-L's wording to change — listed because it is new text on a user's screen and the mixed case ("NOISE" shouted, "Operating Point" title-case) is ngspice's, not a typo. `disto` adds "Distortion Operating Point" to the same sentence, which `pz` already contributed.


### from issue 1433 (stage 6)

**R9-277** · status

```text
this run was stopped before its first checkpoint, so the analysis that was running kept nothing. The analyses that had already finished are in the results file.
```

*Where:* Post-run salvage note, xschem notice channel (CIW / run log) — emitted once by `ase::ckpt_report` when the run verdict is `aborted` and the checkpoint file holds nothing

*For:* Tells the user, right after they press Stop, that the analysis in flight kept nothing but the earlier analyses did survive.

*Note:* Ships lower-cased because it is printed inside the frame `ase: salvage -- <s>` (listed separately below). Source writes it with Tcl backslash-newline continuations; the assembled string is as shown. `src/ase_window.tcl` was NOT touched by this commit, so the window still draws nothing about partial results — this log line is the whole of what the user is told. The issue file records the user's own wording of the requirement as "alert user that her sittings will cause loss of simulation effort 'thus far'"; the shipped sentences do not use the word "salvage" except in the frame.


**R9-278** · status

```text
this run was stopped: the analyses that finished are in the results file, and the '$name' plot the simulator was still filling was kept at $held points$of, in [file tail $ck].
```

*Where:* Post-run salvage note, xschem notice channel (CIW / run log) — `ase::ckpt_report`, verdict `aborted`, checkpoint file holds points

*For:* After a Stop, names which plot was salvaged, how many points survived, and the file it was written to.

*Note:* Placeholders as the code writes them: `$name` is the raw plot name (e.g. `Transient Analysis`), `$held` the salvaged point count, `[file tail $ck]` the checkpoint filename (`<cell>_ase.raw.ckpt`). `$of` is either empty or the literal " of an estimated $est" — so the shipped reading is e.g. "kept at 4800000 points of an estimated 8000008, in tb_bandgap_ase.raw.ckpt." The issue's own comment says points were chosen over a percentage because "a percentage of an estimate reads like a measurement". Single quotes around the plot name, not double.


**R9-279** · label

```text
ase: salvage -- $s
```

*Where:* Frame wrapping both salvage notes above, xschem notice channel

*For:* Prefixes every salvage sentence so the user can tell where the note came from.

*Note:* `--` is two ASCII hyphens, not an em dash. Tag is `note`, so it is not styled as an error. Reviewer may want to compare against the sibling frame `ase: results -- $s` used by reconcile_report (pre-existing) and `ase: the $pty analysis: ...` used by the preflight advice block.


**R9-280** · status

```text
$kw of the [join $lost {, }] analysis $kv not written: this run was STOPPED, and what the analysis had when it stopped is in the checkpoint beside the results file.
```

*Where:* Run-reconciliation line, xschem notice channel — `ase::reconcile_plots` under-count arm, only when the run verdict is `aborted`

*For:* Replaces the defect-sounding "not captured" report when the plot shortfall is explained by the user having pressed Stop.

*Note:* New wording; the non-stopped variant it sits beside ("... $kv not captured: this run recorded $mapped and the results file holds $actual.") pre-dates this issue and is unchanged. `$kw` renders as `one plot` or `<n> plots`; `$kv` as `was` or `were`. Printed through the pre-existing frame `ase: results -- <s>`, and with an EMPTY tag (not `error`) because, per the code comment, "The user pressed Stop; the sentence is telling them what survived, not reporting a fault." STOPPED is shouted in caps in the shipped string.


**R9-281** · status

```text
the enabled rows predict $pred plot(s) and this run recorded $mapped: the run was STOPPED before the rest.
```

*Where:* Run-reconciliation line, xschem notice channel — `ase::reconcile_plots` prediction-mismatch arm, only when the run verdict is `aborted`

*For:* Explains a plot count lower than the enabled analyses predicted by naming the Stop as the single cause.

*Note:* New wording. The non-stopped variant beside it (pre-existing, unchanged) names two causes: "... the run stopped before the rest, or the analyses changed between rendering the deck and reading it back." Note the shipped `plot(s)` parenthetical plural here, where the sibling sentence above pluralises properly via `$kw` — an inconsistency the reviewer may want to level. Again printed via `ase: results -- <s>` with no error tag.


### from issue 1442 (stage 7)

**R9-282** · caution

```text
you asked for $name $want; $sim reports $got
```

*Where:* run log, after the run finishes — each line prefixed 'ase: '

*For:* Post-run read-back: the simulator's effective value differs from the one the bench asked for.


**R9-283** · caution

```text
$name did not reach $sim -- it reports no such setting
```

*Where:* run log, after the run finishes — each line prefixed 'ase: '

*For:* Post-run read-back: a stored option never arrived.


**R9-284** · caution

```text
$sim does not know '$name' and made a variable out of it ($name = $got); $sim never reports a name it does not recognise, so this is the only sign you will get
```

*Where:* run log, after the run finishes — each line prefixed 'ase: '

*For:* Post-run read-back: a misspelled option silently became a variable, and this line is the only error channel there is.

*Note:* Long — three clauses and a parenthetical; the longest new sentence in either commit.


**R9-285** · caution

```text
'$name' is not in this simulator's catalogue, and $sim says nothing about a name it does not recognise -- nothing here can tell you whether it took effect
```

*Where:* run log, after the run finishes — each line prefixed 'ase: '

*For:* Post-run read-back: nothing can be concluded about an option outside the catalogue.


**R9-286** · caution

```text
⚠ neither read-back channel reported any stored option on this run, so nothing below rests on a comparison
```

*Where:* run log — inserted as the FIRST line of the read-back report when nothing could be compared

*For:* The shipped positive control: warns that the report below it has no evidence behind it.


**R9-287** · other

```text
ASE-EFFECTIVE-BEGIN
```

*Where:* run log — the bracket lines the deck echoes around the simulator's own option dump

*For:* Marks the start of the settings dump inside the log the user reads.

*Note:* Raw marker text, visible to anyone reading the log; the matching end marker is ASE-EFFECTIVE-END.


---

## What lands on disk — the deck, the sidecar, the run directory

*3 strings.*

### from issue 1427 (stage 5)

**R9-288** · other

```text
0
```

*Where:* the emitted deck line for a pz row, e.g. `pz in 0 out 0 vol pz`, and the netlist ASE-L writes

*For:* The value written for Input - / Output - when the user leaves those boxes empty — pz's ground default.

*Note:* Listed by issue 1427's own R9 as one of the sixteen new user-facing strings. It is never shown in the form (the entry boxes stay blank); the user only meets it in the deck. Declared as `default 0 whenskipped 0`.


### from issue 1430 (stage 6)

**R9-289** · other

```text
PLOT $type $idx |$name|
```

*Where:* the plotmap sidecar file itself — <rundir>/<cell>_ase.plotmap, one line per `write`, written by the emitted ngspice deck

*For:* The one-line record that ties each written plot back to the analysis row that asked for it; the user sees it only if they open the sidecar beside the results file.

*Note:* NOT prose and probably not for ratification — included because 1430 puts it in a file on disk the user can open. From ase::plotmap_record. Renders as e.g. `PLOT ac 1 |AC Analysis|`. The pipes delimit the name because every ngspice plot literal contains spaces; $idx is the row's position in `analyses`, not a plot counter.


### from issue 1442 (stage 7)

**R9-290** · other

```text
${cell}_ase.effective
```

*Where:* run directory — the sidecar file the deck writes

*For:* Filename of the variables half of the read-back channel, written beside the netlist.

*Note:* User-visible only as a file in the run directory.


---

## Everything else

*1 strings.*

### from issue 1433 (stage 6)

**R9-291** · refusal

```text
ase: state design has no cell (ckpt_path)
```

*Where:* Tcl error raised by `ase::ckpt_path` for a state with no `design cell` — surfaces as an error string rather than as designed copy

*For:* Refuses to compute a checkpoint path for a state that has no design cell to name it after.

*Note:* Included for completeness, flagged as marginal: this is a `return -code error` in internal voice with the proc name in parentheses, not a sentence written for a user. Every caller in `ase::ckpt_report` wraps it in `catch`, so it should normally be unreachable from the GUI — but it is new copy this commit put in the tree and it reads like developer text if it ever does escape.


---

## Added after the first version — found by a completeness sweep

*2 strings.*

The first version of this document came from reading the 19 issues. To check it
for holes, the driver then went at it from the other end: every commit those
issues name was diffed, every **added** string literal of five words or more that
carries no variable was extracted, and the result was matched against the 291.

**29 such literals were added by those commits. 27 were already here. These are
the other two** — and they are the same sentence twice, differing only in the
name of the proc that raises it.

### from issue 1430 (stage 6)

**R9-292** · refusal

```text
ase: state design has no cell (plotmap_path)
```

*Where:* A Tcl error raised by `ase::plotmap_path` for a state whose design has no
`cell`. It surfaces as an error string rather than as designed copy — wherever that
error is reported.

*For:* Refuses to compute the plotmap sidecar's path for a state that does not name
a design cell, and names the proc that could not do it.

*Note:* One of a family of **six** identically-worded raises — `ckpt_path`
(R9-291), `plotmap_path`, `effective_path` (R9-293), `cosim_file`, `log_file` and
`raw_file`. Three of the six predate this batch and are therefore not R9's to
ratify; but the wording is shared, so **if you change one, all six should move
together**, and the parenthesised proc name is developer vocabulary of the kind
§A6 is about.

### from issue 1442 (stage 7)

**R9-293** · refusal

```text
ase: state design has no cell (effective_path)
```

*Where:* A Tcl error raised by `ase::effective_path` for a state whose design has
no `cell`.

*For:* Refuses to compute the effective-options sidecar's path for a state that
does not name a design cell.

*Note:* See R9-292 — same sentence, same family of six, same question.

---

## Issue 1443 — measurements, added after the crew's work landed

*79 strings.*

These are the strings the scope section said were missing: issue **1443** was uncommitted when
this document was built, and landed as commit `3f31a33b`. Every one was taken from the
committed source and **all 79 were then found byte-for-byte in `git show HEAD:src/ase.tcl`**
by the driver — none of them is composed, so an edit lands exactly where the string is.

⚠ **ALMOST NONE OF THEM CAN BE SEEN YET.** That commit is the **deck half**: it builds no
widget, and `src/ase_window.tcl` carries no reference to measurements at all. The eighteen kind
labels are declared and read by nothing; the field labels reach a user through exactly one
sentence today (`'$name' needs a value for $lbl`); the report frames are consumed only by
`ase::meas_report`, **which has no caller anywhere in the tree**. The four that a user can
reach now are the deck refusal and its clause, the sidecar filename, and the `meas_path` raise.
So you are ratifying these **before** the surface exists — which is the right order, because
Stage 8 task 2 builds that surface next and will otherwise mint a second set of words.


### The Measurements list — the eighteen kind labels


*18 strings.*


**R9-294** · label

```text
Delay (TRIG ... TARG)
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `trigtarg`.


*For:* Names the kind that measures the time between one signal crossing a trigger level and another crossing a target level — the propagation-delay / rise-time measurement.


*Note:* The only kind label that puts deck keywords on screen: TRIG and TARG are ngspice's own `meas` words, shouted, with a literal three-dot ellipsis rather than an ellipsis character. §A1 (shouted words) and §A6 (developer vocabulary) both bite here. Every other kind label is plain English.


**R9-295** · label

```text
Value at a point
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `find`.


*For:* Names the kind that reads one signal's value at a given abscissa, or at the moment another signal crosses a value (`FIND ... AT=` / `FIND ... WHEN`).


*Note:* This one kind carries two grammars and two of the adapter's refusals (the `at`/`when` pair) exist to make the user choose one. The label mentions only the first.


**R9-296** · label

```text
Where a signal crosses a value
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `when`.


*For:* Names the kind that reports the abscissa at which a signal reaches a value (`WHEN x=v`).


**R9-297** · label

```text
Average
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `avg`.


*For:* Names the window-average statistic over the measured signal.


*Note:* One of eight labels passed as the sole argument of `meas_stat_kind {label}`, so all eight share one descriptor and an edit lands at the call site in `meas_kinds`, not in `meas_stat_kind`.


**R9-298** · label

```text
RMS
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `rms`.


*For:* Names the root-mean-square statistic over the measured signal.


*Note:* Acronym already uppercase, matching the user's standing UI-copy rule — unlike `Power spectral density` below, which spells its acronym out instead. From `meas_stat_kind`.


**R9-299** · label

```text
Minimum
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `min`.


*For:* Names the minimum-value statistic over the measured signal.


*Note:* From `meas_stat_kind`.


**R9-300** · label

```text
Maximum
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `max`.


*For:* Names the maximum-value statistic over the measured signal.


*Note:* From `meas_stat_kind`.


**R9-301** · label

```text
Where the minimum is
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `min_at`.


*For:* Names the statistic that reports the abscissa at which the minimum occurs, rather than the minimum itself.


*Note:* From `meas_stat_kind`. Reads as a question fragment where its six siblings are noun phrases; pairs with `Where the maximum is` and with `Where a signal crosses a value`, so all three should move together.


**R9-302** · label

```text
Where the maximum is
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `max_at`.


*For:* Names the statistic that reports the abscissa at which the maximum occurs.


*Note:* From `meas_stat_kind`. See `Where the minimum is`.


**R9-303** · label

```text
Peak to peak
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `pp`.


*For:* Names the peak-to-peak (max minus min) statistic over the measured signal.


*Note:* From `meas_stat_kind`. Unhyphenated, where the usual spelling is `Peak-to-peak`.


**R9-304** · label

```text
Integral
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `integ`.


*For:* Names the integral of the signal over the measurement window.


*Note:* From `meas_stat_kind`.


**R9-305** · label

```text
Derivative
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `deriv`.


*For:* Names the derivative kind in the picker.


*Note:* ⚠ The kind it names can NEVER run: the same entry carries an `unsupported` reason, so every row of this kind refuses. A reviewer deciding this label is deciding whether to show a picker entry that always refuses — the alternative the code deliberately rejected is leaving the word out altogether.


**R9-306** · label

```text
Expression over other measurements
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `param`.


*For:* Names the kind that computes a new number from measurements already taken — a phase margin as `180 + <measured phase>`, for example.


*Note:* The longest kind label. It is emitted as a `let`, not a `meas`, because ngspice's `meas` COMMAND supports neither `param=` nor `expr=` nor `par()` — so the label describes the capability rather than the deck word, deliberately.


**R9-307** · label

```text
Fourier / THD
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `fourier`.


*For:* Names the post-processing producer that runs a Fourier analysis on a transient and yields the total harmonic distortion plus the printed harmonic table.


*Note:* Mixes a proper name and an acronym across a spaced slash — the only label of either shape in the commit. Compare `FFT spectrum` and `Power spectral density`, which handle the same question two other ways.


**R9-308** · label

```text
Resample onto a uniform time grid
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `linearize`.


*For:* Names the producer that re-samples adaptive-step transient data onto an even grid, which `FFT spectrum` and `Power spectral density` need before they are accurate.


*Note:* The spectrum caution tells the user to *"Add a Resample row"*, naming this label's first word. Label and caution must move together.


**R9-309** · label

```text
FFT spectrum
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `fft`.


*For:* Names the producer that takes an FFT of a transient signal and makes a spectrum plot to measure on.


**R9-310** · label

```text
Power spectral density
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `psd`.


*For:* Names the producer that computes a power spectral density from a transient signal.


*Note:* The one acronym spelled out rather than shipped as `PSD`, where `RMS` and `FFT spectrum` ship the acronym. Pick one convention across the three.


**R9-311** · label

```text
Spectrum over a frequency band
```


*Where:* The Measurements list — the Kind picker and the Kind column of the Measurements sub-dialog. Declared as the `label` key of one entry of `ase::backend::ngspice::meas_kinds`, so it is the **ngspice adapter's** word, not ASE-L's. Nothing reads the kind `label` at HEAD (`ase::meas_kind_*` read only `form`, `unsupported`, `yields`, `fields` and `counter`): task 1 is the deck half and builds no widget, so these eighteen labels are declared and not yet displayed anywhere. Stage 8 task 2 (§8b) is the surface they are written for. Kind slot `spec`.


*For:* Names the producer that computes a spectrum across a user-given start/stop/step frequency band.


### The Measurements sub-dialog — field labels


*28 strings.*


**R9-312** · label

```text
Trigger signal
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/trig, required`.


*For:* Captions the signal whose crossing starts the delay measurement.


**R9-313** · label

```text
Trigger value
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/trigval`.


*For:* Captions the level the trigger signal must cross.


*Note:* Bare `Value`-family label with no unit, where the analysis forms qualify theirs; the unit here genuinely depends on what is being measured.


**R9-314** · label

```text
Trigger edge
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/trigdir, mode, default rise`.


*For:* Captions the rise/fall/cross picker for the trigger crossing.


**R9-315** · label

```text
Trigger edge number
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/trign, default 1`.


*For:* Captions which crossing counts — the first, second, nth.


*Note:* Four words; the longest field label in the trigtarg form and its twin `Target edge number` sits directly below it.


**R9-316** · label

```text
Trigger delay
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/trigtd, unit s`.


*For:* Captions how long to ignore the trigger signal before looking for a crossing.


*Note:* Carries `unit s`, so a form using the tree's existing `ase::ui::form_label` convention would render `Trigger delay (s):`. `delay` here means 'ignore before', which is what the SAME concept is called `Ignore before` on the find and when forms — see that entry.


**R9-317** · label

```text
Target signal
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/targ, required`.


*For:* Captions the signal whose crossing ends the delay measurement.


**R9-318** · label

```text
Target value
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/targval`.


*For:* Captions the level the target signal must cross.


**R9-319** · label

```text
Target edge
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/targdir, mode, default rise`.


*For:* Captions the rise/fall/cross picker for the target crossing.


**R9-320** · label

```text
Target edge number
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/targn, default 1`.


*For:* Captions which target crossing counts.


**R9-321** · label

```text
Target delay
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `trigtarg/targtd, unit s`.


*For:* Captions how long to ignore the target signal before looking for a crossing.


*Note:* Carries `unit s`. Same wording question as `Trigger delay`.


**R9-322** · label

```text
Signal
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `target on find, when, the eight statistics, deriv, fourier, fft, psd and spec — 13 of the 18 kinds`.


*For:* Captions the vector or expression being measured or transformed. Required on every kind that has it.


*Note:* The single most-shown label in the commit. Any edit to it changes thirteen forms at once, and it is the word that must agree with whatever the Outputs pane calls the same thing.


**R9-323** · label

```text
At
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `find/at`.


*For:* Captions the abscissa at which to read the signal's value.


*Note:* A bare one-word preposition, no unit — the abscissa is time, frequency or a swept source depending on which analysis the row is bound to. §A4's question (`Stop` vs `Stop time` vs `Stop frequency`) applies with the same answer difficulty.


**R9-324** · label

```text
When signal
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `find/when`.


*For:* Captions the second signal whose crossing picks the moment to read the first one.


*Note:* Reads as the opening half of a sentence completed by the `reaches` box beside it — see the next entry.


**R9-325** · label

```text
reaches
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `find/value`.


*For:* Captions the value the `When signal` must reach; it is meant to be read as the middle of the phrase *When signal <x> reaches <v>*.


*Note:* ⚠ THE ONLY LOWERCASE LABEL IN THE COMMIT, and deliberately so. It only reads correctly if the form lays `When signal` / `reaches` out on one line; in a right-aligned label column it appears as a stray lowercase word under `When signal`. Since no form exists yet, ratifying this word also ratifies a layout constraint on Stage 8 task 2.


**R9-326** · label

```text
Edge
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `find/dir and when/dir, mode, NO default`.


*For:* Captions the rise/fall/cross picker for the crossing being looked for.


*Note:* Unlike `Trigger edge` and `Target edge`, this one declares no default, so the box starts empty and the qualifier is omitted from the deck.


**R9-327** · label

```text
Edge number
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `find/n and when/n, default 1`.


*For:* Captions which crossing counts.


**R9-328** · label

```text
Ignore before
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `find/td and when/td, unit s`.


*For:* Captions the time before which crossings are not counted.


*Note:* ⚠ A verb phrase where every neighbour is a noun phrase — §A5's complaint about `Start recording at (s):` exactly. It is also the SAME concept the trigtarg form calls `Trigger delay` / `Target delay`, so the commit ships two names for one idea, one imperative and one nominal. ⚠ And it is deliberately NOT offered on the eight statistics: ngspice honours `TD=` only for WHEN/TRIG/TARG and silently ignores it for AVG, RMS, MIN, MAX, MIN_AT, MAX_AT, PP and INTEG, so a user will meet this box on some kinds and not others.


**R9-329** · label

```text
From
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `find/from, when/from, and the eight statistics`.


*For:* Captions the start of the window the measurement is restricted to.


*Note:* Bare, no unit, on ten kinds. With `To`, it is the window control that actually works on the statistics (see `Ignore before`).


**R9-330** · label

```text
To
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `find/to, when/to, and the eight statistics`.


*For:* Captions the end of the measurement window.


*Note:* Bare, no unit, on ten kinds. ⚠ The commit's own source note records that an `avg`'s echoed `to=` is the last scale value the loop touched rather than the requested one, which is why the sidecar keeps the printed tail as text; the label makes no such claim, and a reviewer may want it to.


**R9-331** · label

```text
Value
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `when/value, required`.


*For:* Captions the level the signal must reach for the `when` kind.


*Note:* Bare `Value` here, but the same idea is `reaches` on the find form and `Trigger value` / `Target value` on the delay form — three spellings of one concept in one dialog. §A8.


**R9-332** · label

```text
Expression
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `param/expr, required`.


*For:* Captions the arithmetic the user writes over measurements already taken, e.g. `180 + phs`.


**R9-333** · label

```text
Fundamental
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `fourier/fund, unit Hz, required`.


*For:* Captions the fundamental frequency the Fourier analysis is taken about.


*Note:* Carries `unit Hz` → `Fundamental (Hz):` under the existing convention.


**R9-334** · label

```text
Points
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `linearize/np`.


*For:* Captions how many points the resampled uniform grid should have.


*Note:* ⚠ Near-twin of the analysis forms' `Number of points (2 gives ONE point)` / `(1 gives ONE point)` captions that §A1 is about, but with no arithmetic caveat and a different, shorter wording. Whatever §A1 decides for those should decide this.


**R9-335** · label

```text
Only these signals
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `linearize/vectors`.


*For:* Captions the optional list restricting which signals are resampled.


*Note:* A sentence fragment used as a caption, and the only label in the commit that begins with an adverb. Compare the Outputs pane's wording for the same idea.


**R9-336** · label

```text
Averaging points
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `psd/avgpts, required, default 1`.


*For:* Captions the number of points averaged in the power-spectral-density estimate.


*Note:* Required AND defaulted to 1, so the refusal `'$name' needs a value for Averaging points` is unreachable unless the user blanks the box.


**R9-337** · label

```text
Start
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `spec/start, unit Hz, required`.


*For:* Captions the first frequency of the spectrum band.


*Note:* ⚠ Renders `Start (Hz):` where the ac analysis form says `Start frequency (Hz):` for the same quantity — §A4's inconsistency, one dialog further on. Same for `Stop` and `Step` below.


**R9-338** · label

```text
Stop
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `spec/stop, unit Hz, required`.


*For:* Captions the last frequency of the spectrum band.


*Note:* See `Start`. §A4 already asks whether `Stop` should be `Stop frequency`; this is a third instance of the same bare word.


**R9-339** · label

```text
Step
```


*Where:* The Measurements sub-dialog — the caption on one entry box of a measurement row's form. Declared as the `label` key of a field descriptor inside `ase::backend::ngspice::meas_kinds`, so the word is the **ngspice adapter's**. No form renders it at HEAD (task 1 builds no widget). The ONE place a field label reaches the user today is composed: ASE-L core's refusal frame `'$name' needs a value for $lbl` takes `$lbl` from this key. Field `spec/step, unit Hz, required`.


*For:* Captions the frequency increment across the spectrum band.


*Note:* See `Start`. §A4 already contrasts `Step` with `Time step`; this is a fourth instance.


### The Measurements sub-dialog — the picker values


*1 strings.*


**R9-340** · label

```text
rise fall cross
```


*Where:* The Measurements sub-dialog — the values inside the rise/fall/cross combobox shown under `Trigger edge`, `Target edge` and `Edge`. Declared as `values {rise fall cross}` on the three `mode` field descriptors in `ase::backend::ngspice::meas_kinds`; the **ngspice adapter's** vocabulary. No combobox renders them at HEAD.


*For:* The three crossing directions the user picks between when saying which edge of a signal a measurement should look for. `rise` is the declared default on the two delay-form pickers; the find/when picker has no default.


*Note:* Shipped lowercase, like the `dc ac` and `dec oct lin` pickers §A2 is about, and for the same reason — the tree's combobox renders `-values` with no display mapping. These are not acronyms, though: they are ordinary words, and the deck spelling is UPPERCASE (`ase::backend::ngspice::meas_edge` emits `RISE=1`), so display and deck already differ and a display mapping costs nothing.


### The Measurements sub-dialog — units


*2 strings.*


**R9-341** · unit

```text
s
```


*Where:* The Measurements sub-dialog — the parenthesised unit a field label wears. Declared as `unit s` on `Trigger delay`, `Target delay` and `Ignore before` in the **ngspice adapter's** kind catalogue. The tree's existing `ase::ui::form_label` appends ` (<unit>)` and a colon, giving `Ignore before (s):` — but that proc resolves through `ase::field_descriptor`, which reads ANALYSIS field tables, so nothing applies it to a measurement field at HEAD.


*For:* Tells the user the three time-window boxes are in seconds.


*Note:* Consistent with §A5's approved convention on the tran and ac forms. Flagged only because the composition is not wired yet: ratifying it also asks Stage 8 task 2 to reuse `form_label`'s rule rather than invent a second one.


**R9-342** · unit

```text
Hz
```


*Where:* The Measurements sub-dialog — the parenthesised unit on `Fundamental` (fourier) and on `Start` / `Stop` / `Step` (spec). Declared as `unit Hz` in the **ngspice adapter's** kind catalogue; same unrendered composition as `s` above.


*For:* Tells the user the Fourier fundamental and the three spectrum-band boxes are in hertz.


*Note:* Uppercase H, lowercase z — matches the ac form's `Start frequency (Hz):`.


### Refusals ASE-L core writes


*12 strings.*


**R9-343** · refusal

```text
this measurement has no name
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a row the user has added but not yet named; the name becomes a vector in the simulator and a key in the sidecar, so nothing can be emitted without it.


*Note:* One of four core refusals written in the impersonal `this measurement …` voice; the other eight name the row as `'$name'`. §A8 (siblings that drifted) — pick one voice.


**R9-344** · refusal

```text
'$name' cannot be a measurement name: the simulator makes a vector of it, so it must start with a letter and hold only letters, digits and underscores
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a name with a space, a leading digit or punctuation in it, and says both why the restriction exists and exactly what is allowed.


*Note:* Rendered: built across three Tcl line-continuations. Says `the simulator` where three sibling refusals say `'$sim'` (i.e. `'ngspice'`) — §A8.


**R9-345** · refusal

```text
another measurement is already called '$name', and the simulator would overwrite the first one's answer with this one's
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses the second and later rows sharing a name, case-insensitively, because the simulator folds the names it prints back and the sidecar lookup would return one number twice. The FIRST row keeps the name.


*Note:* Rendered: joined across two continuations. Does not tell the user that the earlier row is the one that survives, which is the fact that decides which row they should rename.


**R9-346** · refusal

```text
this measurement has no kind
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a row before the user has chosen what sort of measurement it is.


*Note:* Impersonal voice; see `this measurement has no name`.


**R9-347** · refusal

```text
'$sim' describes no measurements, so ASE-L has no way to spell this one
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses every row when the selected simulator's adapter declares no `meas_kinds` hook at all — a second backend that has not implemented measurements yet.


*Note:* Rendered: joined across two continuations. `$sim` is the registered simulator name, single-quoted. Names ASE-L as a product on screen, which has precedent in already-drafted copy (§ options sheet). Unreachable with ngspice selected, which declares eighteen kinds.


**R9-348** · refusal

```text
'$sim' has no measurement of kind '$kind'
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a row whose stored kind is not in the selected simulator's vocabulary — reachable by hand-editing a `.state`, or by switching a bench to a simulator with a smaller catalogue.


*Note:* `$kind` is the INTERNAL kind token (`fft`, `min_at`, `trigtarg`), not the kind's label — §A3.


**R9-349** · refusal

```text
this measurement names no analysis
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a row that has not been pointed at any analysis, so there is no plot for it to read.


*Note:* Impersonal voice; see `this measurement has no name`.


**R9-350** · refusal

```text
no enabled $t analysis for '$name' to read
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a row bound to an analysis type that the bench has switched off or no longer carries. `$t` is the analysis type word.


*Note:* `$t` renders the lowercase deck word (`tran`, `ac`, `dc`) — §A2. This sentence and the one above are the same failure at two depths (no type named vs. no enabled row of that type) and read as unrelated.


**R9-351** · refusal

```text
'$sim' cannot measure a [lindex $bind 0] analysis
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a row bound to an analysis the simulator's measure engine rejects outright. ngspice's `meas_analyses` hook answers `tran dc ac sp`, so a measurement on `noise`, `op`, `pz`, `tf`, `sens` or `disto` lands here.


*Note:* `[lindex $bind 0]` is a command substitution that renders the lowercase analysis type word — §A2 and §A9 (it is a real substitution, not a placeholder the user is meant to read). The verdict is core's, but the LIST it enforces comes from the ngspice adapter's `meas_analyses` hook.


**R9-352** · refusal

```text
'$name' produces a plot, so it cannot itself be measured on '$on'
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a producer row (FFT, PSD, Resample, Spectrum, Fourier) that has been given an `on` target, since a producer makes the plot others are measured on rather than reading one.


*Note:* Rendered: joined across two continuations. `'$on'` is the name of another measurement row.


**R9-353** · refusal

```text
'$name' is measured on '$on', and there is no such post-processing row
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a row pointed at a producer that has been deleted, renamed, disabled, or that is not a producer at all.


*Note:* Rendered: joined across two continuations. `post-processing row` is the internal name for what the picker will call a producer kind (`FFT spectrum`, `Resample onto a uniform time grid`) — §A6, and it should agree with whatever task 2 captions that column.


**R9-354** · refusal

```text
'$name' needs a value for $lbl
```


*Where:* A measurement row's refusal reason, produced by ASE-L core's `ase::meas_verdict` — core's own structural check, with no simulator word in it. ⚠ AT HEAD THE SENTENCE REACHES NOBODY: a `refuse` verdict makes `ase::meas_for` drop the row from the deck silently, and the only consumer of the reason is `ase::meas_report`'s frame `$nm was not measured: $why`, which has no caller anywhere in the tree. Stage 8 task 2 (§8b) is where the Measurements status line and the run-log block will show it. So every entry below is a frame (core) that will one day be wrapped in a second frame (the report).


*For:* Refuses a row with a required box left empty, naming the box.


*Note:* ⚠ THE ONE PLACE A FIELD LABEL REACHES THE USER TODAY, and the one refusal that composes core's frame with the **ngspice adapter's** word: `$lbl` is the field descriptor's `label` when it declares one and the RAW SLOT NAME (`trigtd`, `avgpts`, `targval`) when it does not. All eighteen ngspice kinds label every field, so it currently always shows the label — this is the §A3 defect fixed by construction, but the fallback that reintroduces it is still in the code. Compare the older, unfixed siblings `needs a value for '$f'` (R9-062, R9-159), which quote the slot name and put it in quotes; this one does neither.


### Refusals and the caution the NGSPICE ADAPTER writes


*6 strings.*


**R9-355** · refusal

```text
ngspice names DERIV and refuses it at run time (com_measure2.c:2156, `function 'deriv' currently not supported`). Compute it first with a post-processing expression and measure that instead
```


*Where:* A measurement row's refusal reason, produced by the **ngspice adapter** — `ase::backend::ngspice::meas_rule` (or, for `Derivative`, the `unsupported` key of its kind catalogue entry, which ASE-L core passes straight through as the refusal text). Same delivery as the core refusals: at HEAD the row is dropped from the deck silently and the sentence is only consumed by the uncalled `ase::meas_report` frame `$nm was not measured: $why`.


*For:* Refuses every `Derivative` row, explaining that ngspice recognises the word but rejects it when the measurement runs — so a user who picked it would otherwise get a silently failed measurement with no explanation — and giving the workaround.


*Note:* ⚠ Rendered: joined across three continuations. The sharpest §A6 case in the commit: it puts a C source filename and line number (`com_measure2.c:2156`) and a quoted ngspice source string in front of a circuit designer. There IS precedent for that in already-drafted options-sheet copy (`cktntask.c:68`), so this is a consistency ruling rather than a one-off. The backticked clause is ngspice's own text; the rest is ours.


**R9-356** · refusal

```text
'$kind' reads a transient, and this row is bound to a $type analysis
```


*Where:* A measurement row's refusal reason, produced by the **ngspice adapter** — `ase::backend::ngspice::meas_rule` (or, for `Derivative`, the `unsupported` key of its kind catalogue entry, which ASE-L core passes straight through as the refusal text). Same delivery as the core refusals: at HEAD the row is dropped from the deck silently and the sentence is only consumed by the uncalled `ase::meas_report` frame `$nm was not measured: $why`.


*For:* Refuses a Fourier, Resample, FFT, PSD or Spectrum row attached to anything but a transient analysis — all five read time-domain data.


*Note:* Rendered: joined across one continuation. ⚠ `'$kind'` renders the INTERNAL token (`fft`, `psd`, `linearize`, `fourier`, `spec`) where the picker beside it shows `FFT spectrum`, `Power spectral density`, `Resample onto a uniform time grid` — §A3 exactly. `$type` renders the lowercase deck word — §A2. Note the asymmetry: the kind is quoted, the analysis type is not.


**R9-357** · refusal

```text
a value measurement needs either a point to read at, or a signal and a value to read it when
```


*Where:* A measurement row's refusal reason, produced by the **ngspice adapter** — `ase::backend::ngspice::meas_rule` (or, for `Derivative`, the `unsupported` key of its kind catalogue entry, which ASE-L core passes straight through as the refusal text). Same delivery as the core refusals: at HEAD the row is dropped from the deck silently and the sentence is only consumed by the uncalled `ase::meas_report` frame `$nm was not measured: $why`.


*For:* Refuses a `Value at a point` row that has filled in neither grammar — ngspice's `FIND` needs either `AT=` or `WHEN <sig>=<val>`, and a row with neither spells a line the simulator answers with `bad syntax`.


*Note:* Rendered: joined across one continuation. Describes the boxes by what they do rather than by their captions (`At`, `When signal`, `reaches`); the sibling below does the same. If §A3 is answered 'name the label the user can see', these two are where it lands next.


**R9-358** · refusal

```text
a value measurement reads either at a point or when a signal crosses a value, not both
```


*Where:* A measurement row's refusal reason, produced by the **ngspice adapter** — `ase::backend::ngspice::meas_rule` (or, for `Derivative`, the `unsupported` key of its kind catalogue entry, which ASE-L core passes straight through as the refusal text). Same delivery as the core refusals: at HEAD the row is dropped from the deck silently and the sentence is only consumed by the uncalled `ase::meas_report` frame `$nm was not measured: $why`.


*For:* Refuses a `Value at a point` row that has filled in BOTH grammars, since neither is a default for the other.


*Note:* Rendered: joined across one continuation. Near-twin of the sentence above — same opening four words, diverging mid-sentence, which is the §A8 shape. Here the divergence is deliberate and the pair reads well; worth confirming rather than flattening.


**R9-359** · refusal

```text
a spectrum needs a stop frequency above its start; ngspice answers `Error: bad stop freq $b`
```


*Where:* A measurement row's refusal reason, produced by the **ngspice adapter** — `ase::backend::ngspice::meas_rule` (or, for `Derivative`, the `unsupported` key of its kind catalogue entry, which ASE-L core passes straight through as the refusal text). Same delivery as the core refusals: at HEAD the row is dropped from the deck silently and the sentence is only consumed by the uncalled `ase::meas_report` frame `$nm was not measured: $why`.


*For:* Refuses a `Spectrum over a frequency band` row whose stop frequency is not above its start, and shows the error the simulator would have given.


*Note:* Rendered: joined across one continuation. The backticked half is **ngspice's own error text** quoted forward (not back — ASE-L is predicting it), with `$b` substituted into the middle of the quoted string, so the quotation is reconstructed rather than captured. Says `stop frequency`/`start` where the boxes are captioned `Stop`/`Start` — §A3/§A4.


**R9-360** · refusal

```text
a spectrum's step must fit inside its band; ngspice answers `Error: bad step freq $c`
```


*Where:* A measurement row's refusal reason, produced by the **ngspice adapter** — `ase::backend::ngspice::meas_rule` (or, for `Derivative`, the `unsupported` key of its kind catalogue entry, which ASE-L core passes straight through as the refusal text). Same delivery as the core refusals: at HEAD the row is dropped from the deck silently and the sentence is only consumed by the uncalled `ase::meas_report` frame `$nm was not measured: $why`.


*For:* Refuses a `Spectrum over a frequency band` row whose step is wider than stop minus start.


*Note:* Rendered: joined across one continuation. Same shape and same quoting question as the sentence above; the two should move together.


### The deck refusal — the one a user can reach today


*3 strings.*


**R9-361** · refusal

```text
on a real S-parameter run ngspice's own measure engine reads a complex frequency scale as if it were real and SEGFAULTS for [string toupper $kind]. Measure FIND, MIN, MAX or AVG there, or measure a spectrum produced from a transient instead
```


*Where:* A measurement row's FATAL reason — the reason half of the deck refusal. Produced by the **ngspice adapter's** `ase::backend::ngspice::meas_rule`, collected by ASE-L core's `ase::meas_fatals`, and composed into the render-refusal frame below. Unlike a `refuse`, this one IS reachable today: it stops the whole deck being written, so the user meets it wherever a `render_deck` error surfaces (the Deck preview pane and the run path).


*For:* Refuses to render any deck that would put a `Where a signal crosses a value`, `Delay (TRIG ... TARG)`, `RMS` or `Integral` measurement on a real S-parameter analysis, because ngspice exits 139 on those four. Names the four kinds that are safe there instead.


*Note:* ⚠ Rendered: joined across three continuations, and it is a CLAUSE, not a sentence — it is designed to be read after the frame `ase: measurement '<name>'`, so it opens lowercase with `on a real …`. §A1: `SEGFAULTS` is shouted mid-sentence, the second such in the batch (R9-135 is the first) and they should be answered together. §A3: `[string toupper $kind]` renders the INTERNAL token uppercased — `WHEN`, `TRIGTARG`, `RMS`, `INTEG` — so a `Delay (TRIG ... TARG)` row is told it segfaults for `TRIGTARG`, a word that appears nowhere on screen. And the remedy names ngspice's deck function words FIND/MIN/MAX/AVG rather than the kind labels `Value at a point` / `Minimum` / `Maximum` / `Average`, so a user cannot look up any of the six words in the picker. ⚠ Narrowed to a real `.sp` run on purpose: a spectrum produced by fft/spec/psd has a real scale and is safe, which is what the second half offers.


**R9-362** · refusal

```text
ase: measurement '[lindex [lindex $rmfat 0] 0]' [lindex [lindex $rmfat 0] 1]; nothing was rendered
```


*Where:* The Deck preview pane, and the run path — the Tcl error `ase::backend::ngspice::render_deck` raises when a measurement would crash the simulator, so no deck is produced at all. COMPOSED: the frame is the ngspice adapter's `render_deck` (issue 1424's third refusal tier), the first placeholder is the row's name, and the second is the fatal CLAUSE above, also from the ngspice adapter. Renders as e.g. `ase: measurement 'pm' on a real S-parameter run ngspice's own measure engine reads a complex frequency scale as if it were real and SEGFAULTS for WHEN. Measure FIND, MIN, MAX or AVG there, or measure a spectrum produced from a transient instead; nothing was rendered`.


*For:* Tells the user that one named measurement is dangerous enough that ASE-L wrote no deck whatever, and that nothing was left half-written. Seen when previewing or running a bench whose state carries such a row — including a hand-edited `.state`, which is the reason the check is repeated here rather than trusted from the dialog.


*Note:* Rendered: joined across one continuation; both `[lindex …]` forms are real substitutions, not placeholders the user reads (§A9). ⚠ Near-twin six lines above it in the same proc: `ase: this deck has a precondition the simulator exits on; nothing was rendered` (issue 1424, not among R9's nineteen) — same `…; nothing was rendered` tail, so if that tail is reworded both must move. ⚠ Grammar: the frame butts `'<name>'` straight against a clause that starts `on a real S-parameter run`, and the semicolon then lands after a sentence that already contains a full stop, so the rendered line reads as a run-on. Only one fatal is reported even when several rows are fatal — the first.


**R9-363** · other

```text
ASE-MEAS
```


*Where:* The first line of the `<cell>_ase.meas` sidecar, written into the generated deck as `echo ASE-MEAS >> <path>` by the **ngspice adapter's** `meas_block`, using ASE-L core's `ase::meas_marker`. The user meets it if they open the sidecar, or read the deck in the Deck preview pane.


*For:* Opens the sidecar with a command that cannot fail, so that a measurement which fails costs only its own line instead of truncating the whole file — the measured behaviour is that a failing `meas … > file` leaves the file at zero bytes.


*Note:* Not prose and probably not for ratification, but included on R9-289's precedent (the plotmap record format, listed because it lands in a file the user can open). Hyphenated uppercase; the plotmap sidecar's equivalent opens with `PLOT`, unprefixed, so the two sidecars announce themselves differently.


### The run's measurement report


*6 strings.*


**R9-364** · status

```text
$nm = $val
```


*Where:* The run's measurement report — one line per measurement row, produced by `ase::meas_report` (ASE-L core). ⚠ `ase::meas_report` HAS NO CALLER ANYWHERE IN THE TREE AT HEAD: `git show HEAD:src/*.tcl` finds it defined in `src/ase.tcl` and used nowhere, and `src/ase_window.tcl` contains no `meas_` reference at all. These five frames are therefore the shape of the run-log block and/or the Value column that Stage 8 task 2 (§8b) will build, ratified before the surface exists.


*For:* The ordinary case: names the measurement and gives the number the simulator reported, parsed out of the `<cell>_ase.meas` sidecar.


*Note:* `$val` is the simulator's printed text verbatim (e.g. `-4.500000e+01`), not reformatted — the commit measured that ngspice prints seven significant digits on apt 45.2 and honours `measureprec` only on the fork, so the digit count the user sees is binary-dependent and ASE-L does not normalise it.


**R9-365** · status

```text
$nm = $val -- $why
```


*Where:* The run's measurement report — one line per measurement row, produced by `ase::meas_report` (ASE-L core). ⚠ `ase::meas_report` HAS NO CALLER ANYWHERE IN THE TREE AT HEAD: `git show HEAD:src/*.tcl` finds it defined in `src/ase.tcl` and used nowhere, and `src/ase_window.tcl` contains no `meas_` reference at all. These five frames are therefore the shape of the run-log block and/or the Value column that Stage 8 task 2 (§8b) will build, ratified before the surface exists.


*For:* The same line with a caution appended: the number was produced, and something about it is uncertain. Today the only `$why` that can appear is the adaptive-step spectrum caution.


*Note:* ⚠ The separator is two ASCII hyphens with spaces, not an em dash, and `$why` begins lowercase, so the line renders `amp = 9.95420e-01 -- this spectrum is taken from …`. §A8 (punctuation drift) — check it against however the run log separates the same kind of aside elsewhere. Composed: ASE-L frame, **ngspice adapter** clause.


**R9-366** · status

```text
$nm: $why
```


*Where:* The run's measurement report — one line per measurement row, produced by `ase::meas_report` (ASE-L core). ⚠ `ase::meas_report` HAS NO CALLER ANYWHERE IN THE TREE AT HEAD: `git show HEAD:src/*.tcl` finds it defined in `src/ase.tcl` and used nowhere, and `src/ase_window.tcl` contains no `meas_` reference at all. These five frames are therefore the shape of the run-log block and/or the Value column that Stage 8 task 2 (§8b) will build, ratified before the surface exists.


*For:* The row emitted and the simulator reported nothing back for it — the frame that carries the `failed` explanation below.


*Note:* The only one of the five frames that uses a colon rather than a verb, so `f3db: the simulator did not report this measurement: …` renders with TWO colons in one line. §A8.


**R9-367** · status

```text
$nm was not measured: $why
```


*Where:* The run's measurement report — one line per measurement row, produced by `ase::meas_report` (ASE-L core). ⚠ `ase::meas_report` HAS NO CALLER ANYWHERE IN THE TREE AT HEAD: `git show HEAD:src/*.tcl` finds it defined in `src/ase.tcl` and used nowhere, and `src/ase_window.tcl` contains no `meas_` reference at all. These five frames are therefore the shape of the run-log block and/or the Value column that Stage 8 task 2 (§8b) will build, ratified before the surface exists.


*For:* The row was refused before the deck was written, so nothing was even attempted; `$why` is one of the twelve core refusals or six adapter refusals above.


*Note:* Composed: ASE-L frame plus a clause that is core's for twelve reasons and the **ngspice adapter's** for six. Several of those clauses open with `'$name'`, so the line renders as `pm was not measured: 'pm' needs a value for Signal` — the name twice in one sentence.


**R9-368** · status

```text
$nm cannot be measured: $why
```


*Where:* The run's measurement report — one line per measurement row, produced by `ase::meas_report` (ASE-L core). ⚠ `ase::meas_report` HAS NO CALLER ANYWHERE IN THE TREE AT HEAD: `git show HEAD:src/*.tcl` finds it defined in `src/ase.tcl` and used nowhere, and `src/ase_window.tcl` contains no `meas_` reference at all. These five frames are therefore the shape of the run-log block and/or the Value column that Stage 8 task 2 (§8b) will build, ratified before the surface exists.


*For:* The row's verdict was fatal. In practice the deck refusal above fires first, so this frame is reachable only by reporting on a state that was never rendered.


*Note:* Composed: ASE-L frame plus the **ngspice adapter's** fatal clause, which opens `on a real S-parameter run …` — so it renders `pm cannot be measured: on a real S-parameter run …`, reading as a stray preposition. The clause was written for the deck-refusal frame, not for this one, and the two cannot both read well without one of them changing.


**R9-369** · advice

```text
the simulator did not report this measurement: the condition it asks about may never occur in this run
```


*Where:* The `failed` explanation carried by `ase::meas_report`'s `$nm: $why` frame — ASE-L core's `ase::meas_results`. It is the answer to "the row was emitted, the run finished, and no number came back". Same delivery caveat: `ase::meas_report` has no caller at HEAD.


*For:* Tells the user that a measurement ran and found nothing — a threshold never crossed, an edge that never happened — rather than leaving an empty cell they would read as zero.


*Note:* Rendered: joined across one continuation. ⚠ Deliberately NOT said for a producer row: a `Resample` or `FFT spectrum` row yields a plot and never a number, so it is scored `produced` and the report prints nothing at all for it — that silence is a design decision a reviewer may want to see turned into a sentence. The row's own diagnostic from ngspice reaches the run log separately (stdout on apt 45.2, stderr on the fork) and is not quoted here.


### What lands on disk, and one raised error


*3 strings.*


**R9-370** · caution

```text
this spectrum is taken from adaptive-step transient data, which the transform assumes is evenly spaced. Add a Resample row before it, or read the amplitude as approximate
```


*Where:* A measurement row's caution — the only one in the commit. Produced by the **ngspice adapter's** `ase::backend::ngspice::meas_rule`. A caution EMITS: the row is written into the deck and the run still produces a number, and the sentence is what the run then says about it. Its only consumer at HEAD is `ase::meas_report`'s uncalled frame `$nm = $val -- $why`, so the user meets it as the tail of the value line rather than on its own.


*For:* Warns that an `FFT spectrum` or `Power spectral density` row with no `Resample onto a uniform time grid` row ahead of it on the same analysis will report a slightly wrong amplitude and frequency, because fft and psd never look at the time values. Shown after the run, beside the number it is about.


*Note:* Rendered: joined across two continuations. ⚠ *"Add a Resample row"* names the first word of the kind label `Resample onto a uniform time grid`, so the label and this sentence must move together. Two sentences joined by a full stop inside one clause, which the report frame then appends after ` -- `, giving `thd = 0.0999 -- this spectrum is taken from …` — a lowercase sentence mid-line. The commit's own measurement of the error is 9.95420e-01 at 999.57 Hz against 9.99885e-01 at 999.50 Hz, and the sentence deliberately does not quote a number because it is circuit-dependent.


**R9-371** · refusal

```text
ase: state design has no cell (meas_path)
```


*Where:* A Tcl error raised by `ase::meas_path` (ASE-L core) for a state whose design has no `cell`. It surfaces as an error string rather than as designed copy; every core caller wraps it in `catch`, so it should normally be unreachable from the GUI.


*For:* Refuses to compute the measurement sidecar's path for a state that does not name a design cell, and names the proc that could not do it.


*Note:* ⚠ This makes the family SEVEN, not six. R9-292's note lists `ckpt_path` (R9-291), `plotmap_path`, `effective_path` (R9-293), `cosim_file`, `log_file` and `raw_file` as six identically-worded raises and says that if one is changed all six should move together — `meas_path` is the seventh and must move with them. Same §A6 objection: the parenthesised proc name is developer vocabulary.


**R9-372** · other

```text
${cell}_ase.meas
```


*Where:* The run directory — the filename of the new measurement sidecar, written beside the netlist, the results file, the log, the plotmap, the checkpoint and the effective-settings sidecar. Composed by `ase::meas_path` (ASE-L core) as `[file join [ase::rundir $state] ${cell}_ase.meas]`. Deleted at the top of `ase::run_deck`, so it never serves the previous run's numbers.


*For:* Names the file the deck appends every measurement line to and that ASE-L parses the numbers back out of. The user meets it only as a file in the run directory.


*Note:* Direct twin of R9-290 `${cell}_ase.effective`; also a sibling of the `_ase.plotmap` and `_ase.raw` names. `.meas` is a recognised SPICE-adjacent extension, which may be a feature or a confusion since the file is NOT a `.meas` deck — ASE-L emits no `.meas` card anywhere.

---

## Issue 1447 — how a user names one analysis among several

*5 strings.*

⚖ **R6**'s schema half (commit pending at the time of writing) settles the one spelling by which
a measurement, and one day a calculator expression, says *which* analysis it reads. The words are
new and the scheme itself is a user-facing decision, so both are here.

**R9-377** · label

```text
ac1  dc1  dc2  tran1  op1
```

*Where:* The handle column in the Choose Analyses grid, the first column of `Analyses > List`,
and the value a measurement row stores in its `id` field. One proc mints it —
`ase::analysis_handles` — and every surface renders that answer.

*For:* Gives every analysis row a name a person can type. A row's handle is its own declared
`id` when it has one, and **`<type><n>`** otherwise, `n` counting from the top of the list among
rows of the same type.

*Note:* ⚠ **The case question the crew filed with this debt.** The handle is **lowercase**
(`dc1`) while the same row's type column in `Analyses > List` is **UPPERCASE** (`DC`) — chosen
that way because the handle is a thing you *type*, matched case-insensitively, and the type
column is UI text under your standing acronyms rule. So one line of the list reads
`dc1   DC   1 VIN 0 1.8 0.05`. §A2 and §A12 are the neighbouring questions. ⚠ Also worth knowing
what the scheme deliberately does **not** do: `n` counts every row of the type **including
disabled ones**, so unticking a row never renumbers the one below it — a reference that changed
meaning because somebody unticked a box is the silent-wrong-answer class this batch exists to
remove.

**R9-376** · other

```text
 (off)
```

*Where:* Appended to a row's line in `Analyses > List`.

*For:* Marks an analysis that is listed but switched off.

*Note:* ⚠ **A departure from issue 1444, and a deliberate one**: 1444 proposed listing only the
enabled analyses. Every row is listed instead, because a measurement bound to a switched-off row
**refuses**, and the reader's next question is *which one is off* — a list that omitted it could
not answer, and it would disagree with the grid beside it. Note the leading spaces: it is
appended after `string trimright`, so it renders two spaces clear of the last column.

**R9-373** · refusal

```text
no analysis called '$h' for '$name' to read
```

*Where:* A measurement row's refusal reason, from `ase::meas_verdict`. Same delivery as
R9-338 onward — the row is dropped from the deck and the sentence waits for the surface Stage 8
task 2 builds.

*For:* Refuses a measurement whose `id` names a handle no row answers to — a typo, or a row that
has since been deleted.

*Note:* Near-twin of R9-349 `no enabled $t analysis for '$name' to read`, which is the same
failure said about a *type* rather than a *handle*. §A8: the two should read as a pair.

**R9-374** · refusal

```text
'$name' names $t but reads '$h', which is [lindex $b 0]
```

*Where:* As R9-373.

*For:* Refuses a measurement whose stored analysis type and whose handle disagree — it says it
measures a `tran` but points at `ac1`.

*Note:* Both `$t` and `[lindex $b 0]` render the lowercase deck word (§A2), and the sentence
names the handle in quotes but the two types bare. ⚠ It is also the only refusal in the batch
that reports a disagreement between two things the user set, rather than one thing being wrong.

**R9-375** · refusal

```text
the analysis called '$h' is switched off, so '$name' has nothing to read
```

*Where:* As R9-373.

*For:* Refuses a measurement pointed at a real row that is not enabled — the case R9-376's
`(off)` marker exists to let the user find.

*Note:* The pair R9-375 and R9-376 must move together: one tells you a measurement cannot run,
the other is how you find the row it is complaining about.

---

## Issue 1448 — the handle made visible

*4 strings.*

⚖ R6's GUI half renders the scheme: a grid of analysis rows with a **Handle** column, and an
`Analyses > List` window. It **consumes R9-373 … R9-377 unchanged** — the handle spelling and
the `(off)` marker are not re-minted — and adds these four.

**R9-378** · label

```text
Handle
```

*Where:* The first column heading of the new analysis-row grid in the Choose Analyses dialog,
beside `Type`, `Enable` and `Arguments`.

*For:* Heads the column showing the name a user types to refer to that analysis — `ac1`,
`dc2`, or a row's own declared `id`.

*Note:* The word the whole scheme is called. If you would rather the column said `Name`, `Ref`
or `ID`, this is the one place that decides it — and it should then agree with whatever Stage 8
task 2's Measurements dropdown calls the same thing.

**R9-379** · label

```text
List
```

*Where:* The second entry of the `Analyses` menu cascade, beside `Choose…`.

*For:* Opens the read-only window that dumps one line per analysis row.

*Note:* One word, no ellipsis — unlike its neighbour `Choose…`, which has one because it opens
a dialog you act in. This one opens a window you only read, so the absence is deliberate.

**R9-380** · label

```text
Analyses — <design cell>
```

*Where:* The title bar of the `Analyses > List` window. Composed: `Analyses`, an **em dash**
(U+2014), and the design's cell name.

*For:* Says which bench the list belongs to, for a user with two windows open.

*Note:* The em dash matches the run-log sentences (R9-262, R9-264) and not the `--` separator
the measurement report uses (R9-365). §A8.

**R9-381** · status

```text
No analyses on this bench.
```

*Where:* The body of the `Analyses > List` window when the bench has no analysis rows.

*For:* Says the window is empty on purpose. Without it an empty window reads as a broken one.

*Note:* A complete sentence with a full stop, where most ASE-L status text has neither. §A8 —
and worth deciding once for every "nothing here yet" message the batch ends up with.

---

## Issue 1451 — the Measurements dialog, and the eight templates

*29 strings.*

The surface issue 1443's whole deck half was written for. Before it, nothing in the tree read a
kind's label, `ase::meas_report` had **no caller anywhere**, and a measurement could only be
created by hand-editing a `.state` file.

**R9-294 … R9-372 are consumed unchanged** — the eighteen kind labels, the field labels, the
refusals, the caution and the report frames are rendered verbatim, and `R9-369` (*"the simulator
did not report this measurement"*) lands **in the Value column**, because an empty cell reads as
zero. These 29 are what the surface itself had to add.

⚠ **Eight of them are template names** (R9-394 … R9-401) and they are **adapter** content, not
ASE-L's — a second simulator would name its own. The rest are ASE-L's own chrome.

**R9-382** · label

```text
Measurements
```

*Where:* the dialog's `wm title`, and the word the menu entry and the log heading are composed from

**R9-383** · label

```text
Measurements…
```

*Where:* `Outputs > Measurements…`, the menu entry. **Composed** — `[ase::ui::lbl_measurements]…`, the shape `Save All…` and `Choose…` already use

**R9-384** · label

```text
Kind
```

*Where:* the third column heading of the Measurements list, and its form label

**R9-385** · label

```text
Analysis
```

*Where:* the fourth column heading, its form label, and the template picker's analysis field

**R9-386** · label

```text
Measured on
```

*Where:* the form label on the producer binding

**R9-387** · label

```text
(the analysis)
```

*Where:* the `Measured on` value that means *the analysis's own plot* — the blank case, spelled so the picker is never empty

**R9-388** · label

```text
Up
```

*Where:* the button bar

**R9-389** · label

```text
Down
```

*Where:* the button bar

**R9-390** · label

```text
From Template…
```

*Where:* the button that opens the template picker

**R9-391** · label

```text
Measurement Template
```

*Where:* the template picker's `wm title`

**R9-392** · label

```text
Template
```

*Where:* its one picker's label

**R9-393** · label

```text
Measurements:
```

*Where:* the heading `ase::ui::run_finished` puts above the report in the run log. **Composed** from #1

**R9-394** · label

```text
DC gain
```

*Where:* template name (adapter)

**R9-395** · label

```text
-3 dB bandwidth
```

*Where:* template name (adapter). ⚠ ASCII hyphen-minus, not U+2212

**R9-396** · label

```text
Unity-gain frequency
```

*Where:* template name (adapter)

**R9-397** · label

```text
Phase margin
```

*Where:* template name (adapter)

**R9-398** · label

```text
Gain margin
```

*Where:* template name (adapter)

**R9-399** · label

```text
Slew rate
```

*Where:* template name (adapter)

**R9-400** · label

```text
Settling time
```

*Where:* template name (adapter)

**R9-401** · label

```text
THD
```

*Where:* template name (adapter). Acronym, uppercase, per the house rule

**R9-402** · label

```text
Output signal
```

*Where:* template field label — the signal every one of the eight reads

**R9-403** · label

```text
Passband gain
```

*Where:* `-3 dB bandwidth`'s third field

*Note:* (unit `dB`)

**R9-404** · label

```text
Start level
```

*Where:* `Slew rate`'s trigger level

*Note:* (unit `V`)

**R9-405** · label

```text
End level
```

*Where:* `Slew rate`'s target level

*Note:* (unit `V`)

**R9-406** · label

```text
Final value
```

*Where:* `Settling time`

*Note:* (unit `V`)

**R9-407** · label

```text
Tolerance
```

*Where:* `Settling time`

*Note:* (unit `V`)

**R9-408** · label

```text
Unwrapped phase
```

*Where:* the 19th kind's label (adapter)

**R9-409** · refusal

```text
this template needs a value for $lbl
```

*Where:* the template picker's one refusal

**R9-410** · refusal

```text
'$sim' has no measurement template called '$tpl'
```

*Where:* the other, unreachable from the GUI (the picker offers only what the catalogue declares) and reachable from a script

## Issue 1452 — `sp`, the deck half (stage 9 task 1)

*18 strings.* Two field labels, one composed precondition and its fix, and seven
sentences the **ngspice adapter** writes about the ports table. Every one was
verified by the driver against the working tree at collection; all but the two
labels are **rendered** — the code composes them from the registry's declared
`min` and `noun` and from the row's own numbers — so the text below is what the
widget shows for the stated case, not a single source literal.

⚠ **The sweep field labels this analysis shows are NOT new**: `Sweep type`,
`Points per decade` / `Points per octave` / `Number of points (2 gives ONE point)`,
`Start frequency`, `Stop frequency` and `lin_points`' caution and fix are all
consumed unchanged from stage 6. They are already handled above.


**R9-411** · label

```text
Noise figure (2 ports only)
```


*Where:* the `donoise` field's label on the `sp` form (adapter-declared).


*For:* Ticking it adds `NF`, `NFmin`, `Rn`, `SOpt` **and** the `Cy` correlation matrix to the run — and only when the table holds exactly two ports, which is why the restriction is in the label rather than only in a caution.


*Note:* §A5 — the parenthesised condition is doing a caution's job inside a label. ⚠ **AND IT IS NOW MEASURED WRONG, WHICH MAKES THIS THE ONE ENTRY IN THIS DOCUMENT WITH A DEFECT BEHIND IT (issue 1457, `owed.sh add rule 1457`).** This tick is what summons the **`Cy` correlation matrix, which the run produces at ANY port count, N×N** — only the four scalars `NF NFmin Rn SOpt` need exactly two ports. So on a three-port bench **the label tells the user not to tick the only control that would give them the nine `Cy` vectors.** It is issue 1457's own defect one layer up, in copy instead of code. The recommended wording is **`Noise figure and correlation matrix`**; four options are in the issue file and **nothing was implemented**, because the wording is the user's to choose.


**R9-412** · label

```text
Write Touchstone S2P
```


*Where:* the `s2p` field's label on the `sp` form (adapter-declared).


*For:* Ticking it runs `let Rbase = <port 1's Z0>` / `wrs2p <path>` / `unlet Rbase` after the analysis.


*Note:* §A12 — `S2P` is a file format, uppercase; `Touchstone` is a proper noun. The sibling field above it spells its condition out and this one does not.


**R9-413** · refusal

```text
this analysis needs at least 2 ports and names 1
```


*Where:* `ase::needs_eval`'s `two_ports` arm — ASE-L **core**, composed from the contract's declared `min` and `noun` through `ase::sim_plural`. Shown in the precondition banner, in the Ports dialog, and as the reason the row will not render.


*For:* A `fatal`: below the minimum `span.c:376-386` calls `controlled_exit(EXIT_BAD)`, so the process dies and takes every other analysis of the run with it, `op` included.


*Note:* Rendered — the two numbers and the singular/plural both vary. Reads `…at least 2 ports and names 0` on an empty table. ⚠ The noun is the registry's, so a simulator that calls them something else gets its own word with no change here.


**R9-414** · advice

```text
add 1 more port -- ports are assigned at run time, and nothing is written to your schematic
```


*Where:* the fix clause of R9-413, same site.


*For:* Says what to do, and pre-empts the question every user of this feature asks — whether S-parameter analysis will modify their schematic.


*Note:* ⚠ **THIS IS R9-431 IN A REFUSAL'S VOICE.** The Ports dialog's caption is the same promise as a statement: *"Ports are assigned at run time. Nothing is written to your schematic."* Two sites, two files, one sentence. **A ruling on either must move both.** Also §A5: `--` is the em-dash the tree writes as two hyphens.


**R9-415** · refusal

```text
port 2 names no source, so nothing promotes it and the run dies before it starts
```


*Where:* `ase::backend::ngspice::sp_row_check` — the **adapter**'s rules over the same table.


*For:* An entry with an empty first column promotes nothing, and the port count the simulator sees is then below the minimum.


*Note:* Rendered (the index varies). §A5 — *"the run dies before it starts"* is plain and accurate; it is the one place this batch says "dies".


**R9-416** · advice

```text
name the voltage source this port drives, or delete the row
```


*Where:* the fix clause of R9-415.


*For:* Both ways out of the state, in the order a user would try them.


**R9-417** · refusal

```text
port 'v1' has the number '0', and a port number must be a whole number of 1 or more
```


*Where:* `sp_row_check`.


*For:* `vsrc.c:31-37` reads `portnum` as an integer index; 0 and fractions do not address a port.


*Note:* Rendered — both quoted values vary. §A9 — the source name is quoted and so is the offending number.


**R9-418** · advice

```text
number the ports 1 upwards, in the order the matrix reports them
```


*Where:* the fix clause of R9-417.


*Note:* The trailing clause is the one that tells a user **why** the order matters — the matrix indices are the port numbers.


**R9-419** · refusal

```text
port 'v1' has Z0 '0'. A Z0 of 0 or less turns that source back into an ordinary source, and the simulator then blames a DIFFERENT port for 'incorrect port ordering'
```


*Where:* `sp_row_check`.


*For:* Measured behaviour: a non-positive `z0` silently demotes the source, and ngspice's own complaint then names an innocent port. Without this sentence the user debugs the wrong row.


*Note:* ⚠ **The longest refusal in the batch, and the only one with a shouted word inside it** (`DIFFERENT`) — §A1. It also quotes the simulator's own message in single quotes — §A6. Two full sentences where every other refusal is one clause.


**R9-420** · advice

```text
give every port a Z0 greater than 0, or leave Z0 empty for the 50 ohm default
```


*Where:* the fix clause of R9-419.


*Note:* ⚠ **Spells the unit as the word `ohm`**, which is why the Ports table's column heading is `Z0 (ohm)` and not `Z0 (Ω)` — see R9-448.


**R9-421** · refusal

```text
two ports share the number 1
```


*Where:* `sp_row_check`.


*Note:* Rendered (the number varies). The shortest refusal this stage writes.


**R9-422** · advice

```text
give every port a different number, 1 upwards with no gaps
```


*Where:* the fix clause of R9-421.


**R9-423** · refusal

```text
the port numbers are 1, 3 -- they have to run 1 to 2 with no gaps
```


*Where:* `sp_row_check`.


*For:* A gap in the numbering leaves an index the matrix has no row for.


*Note:* Rendered — the list and both bounds vary. §A5 — `--` again.


**R9-424** · advice

```text
renumber the ports 1 upwards, in the order the matrix reports them
```


*Where:* the fix clause of R9-423.


*Note:* ⚠ **R9-418 and R9-424 are the same advice with one word different** (`number` / `renumber`) — §A8, siblings that drifted. They may be one sentence.


**R9-425** · caution

```text
the noise figure is computed for exactly 2 ports and this analysis has 3, so NF, NFmin, Rn and SOpt will not be in the results
```


*Where:* `sp_row_check`, and a **caution** rather than a refusal because `span.c:74-178` simply does not compute them — the run still succeeds.


*Note:* Rendered (the count varies). ⚠ Names the four vectors in the simulator's own capitalisation, deliberately: they are names a user types into the calculator. ⚠ **An earlier version of this note said the sentence was incomplete because the `Cy` matrix is also absent at N ≠ 2. That was WRONG and is withdrawn** — the driver measured all four shapes on both binaries and `Cy` is **present** at N ≠ 2, N×N (issue **1457**). The sentence as written names only the four scalars, which is exactly correct, and it needs no second clause: a family that is present needs no warning.


**R9-426** · advice

```text
switch the noise figure off, or reduce the analysis to 2 ports
```


*Where:* the fix clause of R9-425.


**R9-427** · caution

```text
a Touchstone file holds exactly 2 ports and this analysis has 3, so only ports 1 and 2 will be written
```


*Where:* `sp_row_check`, a caution for the same reason — `rawfile.c:934-1022` prints its own note and writes the file anyway.


*Note:* Rendered (the count varies).


**R9-428** · advice

```text
reduce the analysis to 2 ports, or read the file as the 2-port it is
```


*Where:* the fix clause of R9-427.


*Note:* The second half tells the user the file is still usable, which is the part that saves a re-run.


## Issue 1454 — the Ports table and the matrix picker (stage 9 task 2)

*20 strings.* **Six are composed from the adapter's declared `noun`** so that they
read for any table a future contract declares, **four are the adapter's declared
column and family headings**, and the rest are fixed. Driver-verified verbatim in
`src/ase_window.tcl` and `src/ase.tcl` at collection.

⚠ **Every precondition sentence these dialogs show is issue 1452's**, reaching the
user through `ase::precheck_banner_text` — glyph and `Fix:` clause included. This
task mints **no** refusal frame of its own.


**R9-429** · button

```text
Ports…
```


*Where:* the per-type door on the Choose Analyses form, grid row 4 (composition: `"[Totitle <noun-plural>]…"`).


*Note:* A type whose contract declares no table gets **no button**, not a disabled one.


**R9-430** · label

```text
Analysis Ports (sp)
```


*Where:* the ports dialog's `wm title` (composition: `"Analysis [Totitle <noun-plural>] ($type)"`).


*Note:* The shape `Analysis Options ($type)` already in the tree. §A2 — the type renders as the lowercase deck word.


**R9-431** · label

```text
Ports are assigned at run time. Nothing is written to your schematic.
```


*Where:* the caption under the ports table. Ratified in `PLAN.md` §9a; composed from the declared noun.


*For:* The one question this feature raises. S-parameter analysis in most tools means editing the schematic to place port devices; ASE-L does it with `alter` at run time and the caption says so before the user looks for the damage.


*Note:* ⚠ **Same sentence as R9-414, in a promise's voice instead of a refusal's, in a different file. A ruling on either must move both.**


**R9-432** · label

```text
Add Ports from Schematic
```


*Where:* the scan picker's `wm title` (composition: `"Add [Totitle <noun-plural>] from Schematic"`).


*Note:* ⚠ Deliberately **not** the button's text with the noun bolted on the front — `Ports Add from Schematic…` reads as a fragment, and a window title ending in an ellipsis is a button wearing a title's clothes.


**R9-433** · status

```text
This schematic offers no more ports.
```


*Where:* the scan picker when the circuit has nothing left to offer (composition: `"This schematic offers no more <nouns>."`).


*For:* Distinguishes "nothing left" from "nothing found" — every eligible source is already in the table.


**R9-434** · refusal

```text
Every port needs a Source.
```


*Where:* `Add` pressed with the first column empty (composition: `"Every <noun> needs a <first column's label>."`).


*Note:* ⚠ The only refusal in this stage's GUI that is not issue 1452's, and the only sentence whose second half is a **column label** — so it changes if R9-445 does.


**R9-435** · button

```text
Add from Schematic…
```


*Where:* the ports dialog.


*Note:* ⚠ `PLAN.md` §9a writes it *"Add from schematic…"*. Title Case matches the two sibling buttons already in the tree (`From Design…`, `From Template…`); `Add` is kept because this one **adds** rows rather than replacing the dialog's source. §A8.


**R9-436** · button

```text
Matrix…
```


*Where:* the second per-type door on the Choose Analyses form.


**R9-437** · label

```text
Result Matrix (sp)
```


*Where:* the matrix picker's `wm title`.


*Note:* §A2 again — lowercase deck word in a Title Case frame.


**R9-438** · label

```text
Format
```


*Where:* the matrix picker's one control.


**R9-439** · label

```text
Magnitude (dB)
```


*Where:* a format value → RPN `db20()`.


**R9-440** · label

```text
Phase (deg)
```


*Where:* a format value → RPN `cph()`.


*Note:* ⚠ `cph()` is **continuous** phase. The label says `Phase (deg)` and not `Unwrapped phase`, which is the 19th measurement kind's label (R9-408) for the same idea — §A10, one idea wearing two names, now across two surfaces.


**R9-441** · label

```text
Real
```


*Where:* a format value → RPN `re()`.


**R9-442** · label

```text
Imaginary
```


*Where:* a format value → RPN `im()`.


*Note:* ⚠ `abs()` is **not** offered: its behaviour on a complex vector was never measured, and this batch does not offer what it has not measured.


**R9-443** · status

```text
This analysis reports no matrix yet.
```


*Where:* the matrix picker with nothing to offer and no precondition sentence to borrow.


*Note:* In practice the setup banner wins; this is the fallback.


**R9-444** · status

```text
The last run produced 12 of these.
```


*Where:* the matrix picker's note when a results file is on disk (composition: `"The last run produced <n> of these."`).


*For:* Tells the user the grid in front of them matches something that exists, rather than a prediction.


*Note:* Rendered — the count varies with the port count and the noise flag (12 / 20 / 27).


**R9-445** · label

```text
Source
```


*Where:* the ports table's first column — the **adapter**'s declared label.


*Note:* ⚠ Nothing in `ase_window.tcl` spells this word outside a comment; it arrives from the registry. Feeds R9-434's second half.


**R9-446** · label

```text
Port
```


*Where:* the ports table's second column — adapter-declared.


*Note:* ⚠ The **column** is the port's number while the **noun** for a whole row is also `port`, so the heading and the row noun are the same word at two scales.


**R9-447** · label

```text
Noise
```


*Where:* the matrix picker's heading over `NF`, `NFmin`, `Rn` and `SOpt`.


*For:* ngspice groups those four under no name of its own, so this heading is the adapter's word rather than the simulator's.


*Note:* ⚠ Capitalised to match its four siblings `S`, `Y`, `Z` and `Cy`, which are **ngspice's own spellings reproduced**, not minted. It is the only heading in that row that is an English word.


**R9-448** · unit

```text
Z0 (ohm)
```


*Where:* the ports table's third column — adapter-declared.


*Note:* ⚠ **Not `Z0 (Ω)`, which is what `PLAN.md` §9a's sketch draws.** The two sentences issue 1452 already ships write the unit as the word (*"leave Z0 empty for the 50 ohm default"*, *"a Z0 of 0 or less…"*), and one surface spelling it `Ω` while the refusal beside it spells it `ohm` would be two spellings of one unit. §A5, and exactly the kind of choice ⚖ R9 exists for.


⚠ **`Z0`, `NF`, `NFmin`, `Rn`, `SOpt`, `S`, `Y`, `Z` and `Cy` keep the simulator's
own capitalisation throughout both sections.** They are vector names a user will
type into the calculator and read in a rawfile, not English words, so the house
acronyms-uppercase rule does not reach them. This is stated once here rather than
repeated on nine entries.

## Issue 1453 — the registered "simulator" that is the editor

*1 string.* Added when issue 1453 was collected. Pinned byte-for-byte by row **XE4** of
`tests/headless/test_ase_simcaps_0948.tcl`, so a re-wording moves a suite.


**R9-449** · refusal

```text
/opt/x/xschem is xschem itself, not a simulator. It is registered as the simulator named ng-cm3. Starting it would open a second editor that overwrites your own recent files and window settings, so nothing was started. Point this entry at a simulator program such as ngspice.
```


*Where:* `ase::sim_why iseditor` — the fifth guard of `ase::sim_check`. One sentence serving five surfaces: registration, the Simulators dialog's Problem column, `sim_status`, the Detect door and the casemode readers.


*For:* The user's own registry entry points at the xschem binary. ASE-L's capability probe was `exec`ing it as `<prog> -b <deck>` — where **`-b` is xschem's `--detach`** — which started a **second editor** that rewrote their `recent_files` and `geometry` and never exited. This is the sentence that stops it and says why.


*Note:* ⚠ **Four sentences, which is the longest refusal in the batch** (R9-419 was the previous holder at two). Every clause is doing work: *what it is*, *how it got here*, **what would have happened to the user's own files**, and *what to do instead*. ⚠ It is the only string in this document that tells the user a tool would have damaged something of theirs — and the damage had already happened when it was written. §A11's question about naming internals reaches it too: `xschem` is a program name the user knows, not a source file.
