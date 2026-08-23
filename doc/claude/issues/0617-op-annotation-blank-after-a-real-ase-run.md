# 0617 — a successful OP run annotates nothing, and the tool does not say why

STATUS: **DISPLAY HALF STILL OPEN — an attempt was made 2026-08-23, REFUTED on the
committed sky130 bench, and REVERTED.** The emit half stays closed (S3+S4, below).
Nothing of the attempt is in the tree; what it *measured* is below and is binding on
the retry.

## ⚠ THE RETRY'S ONE HARD CONSTRAINT — `.options savecurrents` defeats an ANY-test

The attempt built the three-cause taxonomy the brief asked for — (a) no raw, (b) raw
loaded but no device-parameter vectors, (c) raw loaded but this instance absent — and
decided (b) vs (c) with a membership test: *is ANY of this instance's descriptor
`params` vectors in the loaded raw?* That test is **wrong on the user's own bench**,
and the crew's adversary caught it end to end with a real `/usr/local/bin/ngspice`
run on `sky130A/xschem_libs/sky130_tests/test_nfet_final` with its **committed**
state (`save_op_params 0`, `options {{name savecurrents value 1}}`). Re-measured
independently by the write-up agent before reverting:

```
== A savecurrents ON (the COMMITTED state)  exit=0
   raw list = i(v1) | i(@m.xm1.msky130_fd_pr__nfet_01v8[id])
   text M1  = |id  = 409.7u / gm  = / gds = / vgs = / vth = / vds = / |
   in_raw   = 1
   CAUSE    = ||
   MSG      = OP annotation ON (device OP info) -- raw already loaded
== B savecurrents OFF (same deck otherwise)  exit=0
   raw list = i(v1) | i(all)
   text M1  = |id  = / gm  = / gds = / vgs = / vth = / vds = / |
   in_raw   = 0
   CAUSE    = |nodevvec|
   MSG      = ... -- this raw has NO device parameter vectors: the deck saved no
              per-device `.save` cards, so re-netlist with Outputs > Save All ...
```

**Five of six rows blank, and the tool emits the byte-identical shipped sentence.**
That is this issue's exact symptom, surviving the fix, on a shipped bench. Leg B
nails causation: `.options savecurrents` hands the raw **one free device vector per
device** (`i(@dev[id])`), the ANY-test sees it, declares the sheet healthy, and the
channel goes silent. Recorded in the spec as **R7** (§3.3).

**This is not a corner case.** `grep -rl savecurrents --include=*.state` counts
**35 of the 104 committed state files**, and the list includes
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap_opamp/ngspice_state1/tb_bandgap_opamp.state`
— *the very bench the user reported this issue from*.

### What the retry must therefore do

* **A fourth cause, `partial`, is mandatory**, and it is the common one: *this raw
  carries only N of the M parameters these devices want*. Neither (b) nor (c) is a
  true sentence for it — (b)'s "re-netlist" happens to be the right advice, but the
  reason it gives is false, and a false reason in a diagnostic is how the next
  session's crew gets sent to the wrong file.
* **`_annot_in_raw` must not be an ANY test**, and `_annot_cause` must not exit at
  the first instance found in the raw — one incidental `[id]` silenced a whole sheet.
* **Cost is now a live concern**: an ALL-test over every instance × every param is
  `instances × params` linear `get_raw_index` lookups on the failing path. The
  attempt's ANY/exit-early shape was fast precisely because it was wrong. Measure it
  on a 500-device sheet before shipping.
* The **whole `.state` corpus is the test fixture** the attempt lacked: every new
  fixture raw it wrote was all-or-nothing, which is why 341 checks passed over a
  defect visible on the first real bench. **At least one row must run a real deck
  with `savecurrents` on.**

### Two more things the attempt measured, both kept

* **Collateral, and it is why the revert was whole-file**: to fit the new sentence
  under the 255-char `statusmsg_text` seam the attempt budgeted the *path*, so on a
  realistic testbench sheet the pinned case-(a) line changed from
  `NO RAW FILE: /home/analog/.../tb_bandgap_ase.raw` (full path, type list clipped by
  C at 255) to `NO RAW FILE: tb_bandgap_ase.raw` (basename, full type list). The
  brief said case (a) must be **unchanged**; it was not. Which of path or type list
  should be sacrificed is a user-visible choice nobody has ratified — see **0639**.
* **The mutual-exclusion guards written for decision D3 had ZERO test coverage.** The
  crew's sabotage agent deleted *both* of them and all 341 checks stayed green;
  deleting a third guard too still left the target row green. Exclusion was in fact
  being enforced by the length-budget fallback, not by either guard written for it.
  A retry that re-introduces those guards must red a check when they are removed.

**Kept out of the tree, for the retry to read**:
`/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_0617+0618/REVERTED_annot_mode.tcl`
and `REVERTED_test_op_annot.tcl` (scratch, not committed — the design is described
above, and the ANY-test is the part that must not be copied).

---

STATUS: **EMIT HALF CLOSED 2026-08-23 — S4 landed.** `ase::netlist` now captures
`op_annot::save_cards` and `ase::render_deck` carries the block VERBATIM into the
deck, immediately above `.control`, when the new `save_op_params` gate is on
(*Outputs → Save All → Save device OP parameters*). Proved end to end on a real
`/usr/local/bin/ngspice` run in `tests/headless/test_ase_final.tcl` rows
F10a–F20: the raw's device-parameter vector set is EXACTLY `op_annot::vector` of
the emitted cards, the node voltages survive in the same raw (invariant I2), and
`op_annot::text M1` renders six real numbers — against the pinned before-state
(F18) where the same cell with the gate off has zero device vectors and
`gm/gds/vgs/vth/vds` all blank.

**What is still open in this issue:**
* **The gate defaults OFF**, so the user's exact sequence needs the checkbox
  ticked once. The emit-side *report-what-was-not-delivered* channel fires for
  that (row F19: one `ase::echo` line naming *Outputs > Save All > Save device OP
  parameters*, only when an `op` analysis is enabled). `op_annot::last_warnings`
  now reach the ASE pane too — previously only `write_save_file` consumed them.
* **The DISPLAY half (invariant I8) is untouched.** Pressing `6` on a blank row
  still says nothing about *why* it is blank. That is a display-path change,
  outside S4's Files cell, and this issue stays OPEN for it.
* **With unsaved edits on the sheet, ASE emits no cards at all** and says so —
  a PROVISIONAL choice pending the 0628/0632 ruling, filed as **0633**.
* **Three defects IN THIS CHANNEL, measured by the S4 adversary and not fixed:**
  **0635** — every *refusal* path reports two sentences and the second
  contradicts the first; **0636** — the gate-off nudge fires on every `op`
  netlist for every user with no opt-out; **0637** — a truthy-but-not-`1` gate
  value is silently off, and the reported card count assumes an `@` prefix. A
  report channel that gives contradictory advice is only marginally better than
  one that says nothing, which is what this issue was filed about.


STATUS: **HALF CLOSED 2026-08-22 — S3 landed, S4 has not.** **Addressed by S3 (attempt 5), landed 2026-08-22** — see the *S3 LANDED* section of `doc/claude/suggestions/next_session_prompt_op_annotation.md`. `op_annot::save_cards` on the user's own `sky130_tests_ase/tb_bandgap` now emits **469 lines (1 × `.save all` + 468 cards)** in 244 ms, of which **468 of 468 materialise as real vectors** in an ngspice 46+ raw, and all 78 cards of the hand-written demo golden are a byte-exact subset. **The user's six blank rows are still blank until S4 carries the block into `ase::render_deck`** (or the user runs the new *Simulation → Graphs → Create device OP .save file* menu item and `.include`s the result). The **I8** half of this issue — the tool saying *why* a row is blank — is untouched and still open.

Original filing follows.

STATUS: **OPEN — reported by the user 2026-08-22**, second eyes-on session.
The *cause* is that plan steps **S3 and S4 were never implemented**; this issue
is the user-visible half that stands even after they land. Rider on
[0604](0604-op-annot-must-report-requested-but-undelivered-vectors.md) (invariant **I8**:
report requested-but-undelivered). Related: 0607, 0608.

---

## What the user did, and saw

```
src/xschem --script sky130A/cadence_style_rc --logdir /tmp
open ngspice_state1 of tb_bandgap  (sky130_tests_ase)
enable ONLY the OP analysis, Netlist and Run   -> succeeds
descend x1 > x1, press 6
```

> "Nothing - I get only `param = <blank>`. And node voltages are already
> displayed without asking for them."

## Why. It is not a mystery, and it is not the raw's fault

Measured simulator rule **R1** (spec §3): `gm`, `gds`, `vth`, `vdsat`, `cgg`
**exist in a raw only if the deck saved them explicitly, one card per device per
parameter.** `save all` does not include them — it covers node voltages and
source branch currents, which is exactly why the user's node voltages *were*
there and every device row was blank. The raw is correct; the deck never asked.

`ase::render_deck` (`src/ase.tcl:3159-3166`) emits `.save all` plus one `.save`
per **user-configured output row**. Nothing in the shipped tree emits the
per-device operating-point cards, because:

- **S3 (`op_annot::save_cards` + the hierarchy walk) is NOT IMPLEMENTED.**
  `src/op_annot.tcl` has `vector`, `devpath`, `text`, `descriptor` … and **no
  save-card emitter** at all (`grep -n '^proc' src/op_annot.tcl`).
- **S4 (ASE carries the cards into the deck) is NOT IMPLEMENTED.**

So the display half of the feature (S5/S6/S7/S8/S9/S11) shipped and the supply
half did not. Every demo to date got its cards from a **hand-written scratch
generator** outside the tree — `~/op_annot_demo/gen.tcl`, 78 cards, documented in
`~/op_annot_demo/REPRO_bandgap.md` step 2. That is the entire difference between
the sessions that annotated and the user's session that did not.

## The two halves of the fix

**Half 1 — supply the cards.** Implement S3 and S4 as the plan already specifies
them (`doc/claude/suggestions/next_session_prompt_op_annotation.md:610` and
`:742`, including landmines 1/2/7/14 and rule R4: **a save card is BARE, never
`op_annot::vector`'s wrapped form**). Dispatched as its own work; not this issue.

**Half 2 — this issue. Say it out loud.** Even with S3/S4 landed, a user can run
a deck that predates them, a hand-edited deck, or `Run` on an existing netlist
artifact (`ase::run_existing`). Today that path is **silent**: six rows of
`<blank>` and no statement of why. Invariant **I3** says a missing vector renders
blank — correct, keep it — but **I8** says the tool must report what it was asked
for and did not deliver.

Required: when annotation resolves and **every** device parameter vector is
missing while the raw is otherwise loaded and healthy, the status line must say
so once, held, naming the actual cause and the actual remedy. Something with the
information content of:

> `OP annotate: raw has no device parameter vectors (deck emitted no per-device
> .save cards). Re-netlist with OP annotation enabled.`

**Not** a generic "no data". The user must be able to act on it without reading
this file.

## Landmines

- **Distinguish the three blank causes** — they need different sentences:
  (a) no raw loaded at all; (b) raw loaded but *no device vectors saved* (this
  issue); (c) raw loaded, cards present, but this **instance** is absent from it
  (the `x1 > x2` case — measured 2026-08-22 as a *bench* artefact, the demo raw
  genuinely only held `@m.x1.x1.*`, and the blank was I3 behaving correctly).
  Reporting (b) when it is really (c) sends the user to re-netlist for nothing.
- **Say it once, held — not per instance.** 13 FETs must not produce 13 status
  messages or 78 of them. The S8 chords already use the held status line.
- **Do not break I3.** The rows still render blank. This adds a channel, it does
  not add a fake number or an error dialog.
- `ase::run_existing` deliberately does not re-netlist, so its remedy sentence
  differs — it must tell the user to re-netlist, not merely to re-run.

## Acceptance

- Raw with `save all` only + press `6`: blank rows **and** a held status line
  naming the missing-save-cards cause.
- Raw with cards present + press `6`: numbers, and **no** message (no crying wolf).
- Raw absent + press `6`: the existing "no raw file" message, unchanged.
- Cards present but the instance is not in the raw: the (c) sentence, not the (b) one.
