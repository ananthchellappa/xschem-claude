# 0965 — two devices on the bandgap bench get a name ngspice cannot resolve

**FIXED 2026-08-30** (the S4a repair pass), together with the silence that made
it invisible. Filed by the 0963 tier work, which shipped over it.

## The symptom, as the user met it

On `sky130_tests_ase/tb_bandgap`, 12 of the 468 annotation numbers were simply
blank — six rows on each of two transistors — and **nothing anywhere said so**.
`op_annot::last_warnings` was empty. `op_annot::last_counts` read
`dropped_by_rule 0 not_found 0 name_failed 0`, i.e. the walk believed it had
named all 78 devices correctly. The 561-line run log had no occurrence of
"no such", "x5.xm2" or "x6.xm2". The only count the user was ever shown was how
many requests went **in**.

Of the 78 device names the tree emitted, two were not in the deck:

    @m.x1.x5.xm2.msky130_fd_pr__pfet_01v8_lvt
    @m.x1.x6.xm2.msky130_fd_pr__pfet_01v8_lvt

## The cause is NOT the one the item guessed, and the guess is worth recording

The backlog item said the clue was the W/L difference — x5 and x6 are the
passgates at `W_P=0.6 / L_P=0.35` while the siblings that resolve are at
`W_P=0.5 / L_P=0.15` — and that the PDK subcircuit "probably takes a different
internal branch". **Measured, and false.**
`sky130A/models/libs.tech/combined/continuous/models_fet/sky130_fd_pr__pfet_01v8_lvt.spice`
holds ONE `.subckt`, ONE device line (line 34), 42 binned `.model` cards and
**zero** `.if`/`.else` cards. There is no W/L-dependent branch to take. The
W/L correlation is a coincidence: x5 and x6 happen to be the only two passgates
that also carry `modelp=pfet_01v8_lvt` on their schematic line.

## The cause: two readers of "which model is this device", filled differently

Both the netlister and a live descend resolve a `@token` through
`xctx->hier_attr[currsch-1]` (`lcc[...]` in `xschem globals`), and the two fill
it differently:

| filled by | `prop_ptr` | `templ` |
|---|---|---|
| `src/actions.c:4780-4783` (live descend) | the parent **instance**'s property string | its symbol template |
| `src/spice_netlist.c:492-496` (netlisting) | `sym.parent_prop_ptr` — **NULL** unless the instance carried `schematic=` | the same symbol template |

`src/token.c:5443-5457` looks the token up in `prop_ptr` first and falls back to
`templ`. So:

* `sky130_tests/passgate/symbol/passgate.sym:19`'s `format=` string never
  mentions `@modelp`, so the netlister writes **ONE** `.subckt passgate` body
  for all five passgates, built from the SYMBOL TEMPLATE default
  `modelp=pfet_01v8`. Measured on the generated deck: `.subckt passgate` count
  1, `modelp` occurrences 0, body line `XM2 ... sky130_fd_pr__pfet_01v8 ...`.
* `op_annot::devpath` asked `xschem translate <inst> @model`, which on a live
  descend is answered from x5's own `modelp=pfet_01v8_lvt`.

The annotation followed the **schematic**; the deck followed the **symbol
template**; they disagreed for exactly the instances that override a model
attribute the netlister does not pass down.

This generalises: any per-instance override of an attribute that feeds a device
name diverges the same way, on any PDK whose descriptor interpolates `@model`.
Today that is sky130 only — gf180's template hardcodes `m0`.

## The fix

`op_annot::_model_netlist` (`src/op_annot.tcl`) answers the way the **netlister**
answers, and both arms of `op_annot::devpath` — the devproc arm and the
devpath-template arm — go through it. That is invariant I1's whole point: the
save card and the on-screen row are spelled by one builder, so fixing only the
card path (which would have written correctly-named numbers into the results
file and then looked them up under a name nothing wrote) was never an option.

Three things a reader would otherwise get wrong, all guarded and all commented:

* **GA** — the enclosing cell's SYMBOL TEMPLATE is the step a live descend never
  reaches, and it is where the answer comes from. Row NM2/NM6.
* **GB** — the netlister's own exception: an instance carrying `schematic=`
  makes `get_additional_symbols` build a separate block whose
  `parent_prop_ptr` IS that instance's property string, so there the override
  really does reach the deck and must be kept. Row NM4 is this guard's only
  witness.
* **one level, not a chain** — every `.subckt` body is netlisted with
  `currsch == 1`, so a `@token` in a device's `model=` can only reach the
  immediately enclosing cell. A multi-level walk here would resolve names the
  deck cannot spell.

Everything else — a literal model, an expression, any non-`@token` form — is
returned exactly as `translate` resolves it. That is 76 of the 78 names on this
bench and every name on every other PDK.

## Ruling D5-1: the numbers now appear, and the disagreement is reported

Guard **GC** in `op_annot::_walk` counts the disagreement and says it once per
instance, through the channel `ase::op_cards_capture` already echoes:

> the schematic line for M2 asks for model "pfet_01v8_lvt", but the cell it sits
> in does not pass that setting into the netlist, so the simulator was given
> "sky130_fd_pr__pfet_01v8" for it instead. …

`op_annot::last_counts` gained `netlist_model_differs` alongside the three 0497
counters. Rejected alternatives, recorded so the next crew does not re-derive
them: show nothing (restores the 12 blank rows this exists to delete); show
silently (ruling D5-1); fix `passgate.sym` (netlister/symbol scope, and it
changes what the user's bench simulates — filed as **0970**).

**On the user's ruling queue** (`owed.sh add rule 0965`): the disagreement fires
on every netlist of tb_bandgap, twice, at error level. Is that the right level
for a disagreement that changes no number?

## A name that came back with nothing is never silent again

Measured first-hand on ngspice-46+, and the asymmetry is sharper than "ngspice
says nothing":

| shape | what a name the deck does not contain costs |
|---|---|
| deck-level `.save` | **totally silent**: exit 0, normal results file, the bad name lands as a zero-length entry that `remzerovec` strips |
| in-`.control` `save` | the same silence |
| `write <raw> all @dev…` | prints three lines naming the device, and writes **NO RESULTS FILE AT ALL**, still at exit 0 |

`ase::op_report_missing` (`src/ase.tcl`), called from `ase::run_done`, now
compares what the deck asked for with what the Operating Point plot came back
holding, and says so in plain English — both counts and the names, capped at
five plus "and N more". Its two sentences are minted in `ase::sim_why`
(ruling D5-4). The captured block travels to the completion hook in the run's
`meta` dict, because `run_done` fires from `execute_fileevent` and is never
handed the netlist text.

⚠ **A missing `Operating Point` plot is "none of them came back", not an error
to swallow.** Measured on the bench with the short form and one unmatchable
name: on an operating-point-only deck no file is written at all, but with a
transient in the same run the file EXISTS, holds the transient, and simply has
no operating point in it. A report that only asked "did a file appear" would say
nothing in the shape the user actually runs.

## Guard G4 STAYS, and here is what it now stands on

Measured on `sky130_tests_ase/tb_bandgap` with the transient shortened to
`tran 1u 2u` (a state edit; every row is about deck shape and vector spelling,
neither of which depends on transient length). Rows X1–X3 and X5.

| | form c (per device) | form b (one write line) |
|---|---|---|
| deck | 35,255 bytes / 329 lines | 17,641 bytes / 328 lines |
| wall clock | 3,296 ms | 3,420–7,100 ms |
| results file | 284,283 bytes | 710,738–2,213,395 bytes |
| requests asked / back | 468 / 468 | 468 / 468 |
| per-device per-parameter value diff | — | **zero differences over all 468 values** |

So with 0965 fixed, the short form is correct and its values are identical. It
is still **not** auto-selected, for three measured reasons:

1. **The failure mode is total, not partial.** One unresolvable name on the
   write line writes no results file at all at exit 0 (row X3, measured on this
   bench with a name made unmatchable on purpose). The same name costs form c
   six numbers on one device and keeps the other 462.
2. **0965 closed one source of bad names, not the class.** The inner device
   spelling is DESCRIPTOR knowledge (`sky130_op_devpath` branches on
   `g5v0d16` / `20v0_(iso|nvt)` / `20v0`), and the deck cannot verify it: PDK
   model subcircuits are `.include`d, never netlisted, so nothing in the deck
   names `msky130_fd_pr__pfet_01v8` at all. A deck cross-check can prove the
   hierarchy path and the callee; it cannot prove the leaf.
3. Its results file is **2.5×–7.8× larger** here, because a bare device name on
   a write line dumps every parameter that device has (~75 for a level-1 MOS,
   89 for BSIM4) rather than the six the annotation reads.

Row X5 measures that G4 fires on the real bench with the real ngspice and no
priming at all: `c unsafe`.

## Rows

`tests/headless/test_op_annot.tcl` section **NM** (NM1–NM6, unit scale, on a
two-level fixture built to be the bench in miniature);
`tests/headless/test_ase_optier_0963.tcl` sections **N** (N1–N5, the whole
78-name finding from committed files with no simulator, in about two seconds),
**Q** (Q1–Q6, the report) and **X** (X1–X6, the bench, with a real run).

## Considered and deferred, so nobody re-derives it

`utils/annot_mode.tcl`'s `cadence::_annot_cause` names three reasons a row can
come back blank. A fourth — "the deck does not contain a device by that name" —
was considered and **not** added. With the name builder fixed, 0965's blank rows
are gone at the source, and a residual unresolvable name is now reported by
`ase::op_report_missing` at the end of the run, where it names the devices. A
per-row cause would be a second, smaller job on a different surface (the `6`
chord's own diagnostic) and belongs with whoever next touches that file.

---

## Addendum, 2026-08-30 — the guards this fix added, and who watches them

The sabotage pass on the fix above found that four of its guards had **no row
anywhere that could see them**. Each now has a witness, and one of the four was
also half broken (issue **0972**).

| guard | what it stops | witness |
|---|---|---|
| `op_annot::_subst_model`'s token boundary | a plain `string map` rewrites the front of `@modelname` / `@modelp` too, producing a device path no deck contains, silently | `test_op_annot.tcl` **NM7** (unit), **NM8** (end to end) |
| `op_annot::_lcc_attr` reads a MULTI-LINE template | a reader stopping at the first newline drops the half that carries `modelp` — which is the half it exists to read | `test_op_annot.tcl` **NM2**, **NM6**, **NM8**, now that the fixture's symbol wraps its `template=` the way the shipped `passgate.sym` does |
| the whole-name presence test in `ase::op_report_missing` | a substring test lets a longer-named device answer for a shorter-named one, which is the exact silence this issue is about | `test_ase_optier_0963.tcl` **Q7** |
| "I could not work out where the file would be is not 'there is no file'" | telling the user their run produced no results when nothing was ever opened | `test_ase_optier_0963.tcl` **Q9** (both halves) |
| the nonzero-exit early return | burying a real error under a second sentence counting devices | `test_ase_optier_0963.tcl` **Q10** |

The `@dev[param]` split itself was wrong for any bussed instance — see issue
**0972**, fixed in the same pass, rows **Q8** and **Q11**.

---

## Addendum 2, 2026-08-30 — what this fix left behind, measured by the write-up

Three things about the fix above were measured from the shipped code before it
was committed and **deliberately not touched**, because a change to a
user-facing sentence with no row watching it is the defect this item's own
sabotage pass already failed it for once.

| number | what it is | why not fixed here |
|---|---|---|
| **0974** | the disagreement warning above leads with `M2` on a sheet where five passgates each contain an `M2`, names the placed instance (`x5`) only inside the trailing device path, and never says what the user can do | wording plus two new rows; row N3 is blind to it because it finds `x5` inside the device path |
| **0975** | the "did not come back" sentence asserts one cause ("the deck spells a device differently") even when NOTHING came back, where the likelier reason is a non-converging operating point; and says "of 1 devices" | needs a third sentence and a row driving file-present-and-zero-back, a shape no row drives |
| **0976** | this issue's own defect is still live at five sites in the shipped PDK helpers, two of them user-reachable (`sky130_display_fet_params`, `sky130_hier_sch_expand`) | row NM5's "one place" is scoped to `src/op_annot.tcl`; the PDK helpers look the model up themselves and have no suite |

**Rule debt 0965 asks the user to ratify the show-plus-warn decision and the
level of that line.** It is the *decision* that is theirs — the wording they
will be reading while they decide is already filed as defective, and the look
debt says so.
