# 1467 — The transient noise table had a deck and no form

**Status:** implemented — Stage 13 task 2 of `doc/claude/ase_analyses_batch/` (the GUI half of
issue 1466).
**Suite:** `tests/headless/test_ase_trnoise_gui_1467.tcl` (T1 `hcases` **and** `dcases`).
**Receipt:** `doc/claude/ase_analyses_batch/receipts/42-stage-13-gui.md`.
**Ruling:** ⚖ R9 — every new sentence and label below is recommended copy, recorded with
`owed.sh add rule 1467` and in `R9_COPY_REVIEW.md`.

## What the user met

Issue 1466 made a transient able to carry transient noise and random sources with no schematic
edit — a `noise` table on the `tran` row, every argument emitted positionally and padded, put back
after its own transient — and **drew nothing**. The only way to put a table on a bench was to
close ASE-L and hand-edit the `.state` file. The density a white-noise amplitude buys, the number
of points a noise timestep costs, the sentence saying which kinds of noise a seed repeats, and
thirty-two refusals all existed as data and reached no screen.

## What shipped

**A noise section on the Tran form** (`ase::ui::nz_build` and its helpers in
`src/ase_window.tcl`), gridded into the Choose Analyses dialog's free row 5 and built or removed by
`ase::ui::chana_show` on **every** rebuild — destroyed before the type is looked at, so no other
analysis form can inherit it (`evidence/trnoise.md` §10.1's destroy-list trap).

| part | what it shows | where the words come from |
|---|---|---|
| header | `▸ Noise sources (N)`, folded shut until opened; remembered for the window, like `▸ Advanced` | the contract's `noun` |
| table | one line per entry: On, Target, Kind, **Values** — the values the deck writes, positionally and padded (`ase::stimuli_values`) — and the worst verdict's glyph | `targets`, `functions` labels |
| Add row | a function, and a scrolling list of **only the targets the adapter's target check accepts for that function** | `ase::stimuli_candidates` → the adapter's new `candidates` leg |
| editor | target kind and name, function, Enable, and one field per argument **in positional order**, each labelled with its unit (`source` → V on a voltage source, A otherwise); a distribution is chosen by name and relabels its parameters | `ase::stimuli_args`, `ase::stimuli_quantity` |
| estimates | `Estimates: density ≈ … V/√Hz, flat to ≈ … kHz · ≈ N points · results file ≈ … kB` — **every number marked**; the file size only once a run has given a vector count | `ase::stimuli_readout`, `ase::stimuli_nvec` |
| verdicts | the selected entry's findings and the table's own, in `ase::precheck_banner_text`'s shape | `ase::stimuli_verdicts` |
| footer | the seed sentences and, when the kill switch is armed, the kill sentences — **verbatim** | `ase::stimuli_seed_report`, `ase::stimuli_kill_report` (new `sentences` key) |

**The editor is bound to an entry, never a draft.** Add creates the entry first; every field
writes it as it is typed. There is no half-filled row for OK to drop, which is what *nothing the
window shows may fail to reach the deck* means for a form with a table in it.

**OK** (`ase::ui::chana_ok`) writes the table **only when it changed** — the working copy is taken
from the stored row verbatim, so an untouched section writes the same bytes — and **refuses a
changed table the run would refuse**, with the verdict in the dialog, by the adapter's own check
(`setup_ok`'s rule for the Ports table). The table is dialog memory keyed by the edit cache's key,
so a type switch keeps it (⚖ R5), two transient rows keep two (issue 1448), and Cancel drops it.

**The Arguments column** reads `tran 1u 2m  + 2 noise sources` for a row whose table has two
entries switched on; a row with no table reads exactly as before.

**The `notrnoise` Options-sheet row** gains a `help` sentence and its `results_why` keeps the
2026-09-13 measurement and adds issue 1466's per-kind one (white and 1/f always, RTS only with a
noise timestep above 0, `trrandom` never).

## ⚠ What a measurement changed

**`facts nodes` is not a net list.** Issue 1466's hand-over said to offer nets from
`facts nodes {} nodes`. `ase::netlist_map` files **every token after a device's name** there.
Measured on `vdd vdd 0 dc 1.8 / vsig in 0 dc 0 sin(0 1 1k) / r1 vdd out 1k / m1 out in 0 0 nch
W=1u / xinv out y inv`: the top scope held `0 1 1.8 1k 1k) bias dc in nch out rts sin(0 vdd y`,
and `ase::facts_net_status` answered `present` for `dc`, `1k`, `sin(0` and `nch`. Harmless for a
refusal (which must not false-refuse), wrong for an offer — the Add row would have listed `dc` as a
net. So the adapter reads nets from the netlist **text** (`ase::facts_netlist_text`, a peek of the
file the facts came from) by the node positions of the device letters it is sure of
(`noise_net_tokens`), skipping subcircuit bodies and `.control` blocks.

**Retyping a value passes through an empty field.** An emptied argument loses its key (core pads
it), so the first cut, asked to delete and re-enter the same `10u`, moved `ts` to the end of a
hand-written entry and changed the bench's bytes for a value that had not changed. The editor now
remembers the entry's key order when it loads it and writes it back in that order
(`ase::ui::nz_reorder`, row GB6).

**The offer and the refusal are one body.** The target rules were split out of
`noise_entry_check` into `noise_target_check` (the value rules into `noise_value_check`, same
finding order), and `noise_candidates` offers exactly what `noise_target_check` accepts. Rows NQ2
and NQ3 check both directions through the reader the run uses.

## New schema and content

* **Core** (`src/ase.tcl`): `ase::stimuli_noun`, `ase::stimuli_quantity`, `ase::facts_netlist_text`,
  `ase::stimuli_candidates`, `ase::stimuli_nvec`; `ase::stimuli_kill_report` gains `sentences`; the
  schema validates two more optional legs.
* **Adapter** (`ase::backend::ngspice::`): the `candidates` and `kill_sentences` legs —
  `noise_candidates`, `noise_net_tokens`, `noise_target_fatal`, `noise_kill_sentences` and its
  helpers — and the `notrnoise` catalogue row's text.
* **Window**: no simulator word. Row NZ1 lints `src/ase_window.tcl` for `trnoise`, `trrandom` and
  `notrnoise` outside comments (zero) with `src/ase.tcl` as the positive control.

## Opening it starts nothing

The facts, the netlist text and the last run's vector count are peeks taken once per build. Row
GO1 stubs seven doors (`ase::netlist`, `ase::netlist_in_place`, `ase::run_deck`,
`ase::event_nodes`, `ase::event_probe`, `ase::analysis_detect`, `ase::sim_capabilities`), opens the
section, adds, types and switches types, and requires zero calls — with a direct call as its
control.

## Verified end to end, on both binaries

Section EE types a white-noise entry on `vdd` and a Gaussian random current into `bias` into the
real widgets, presses OK, renders the deck, runs it on `/usr/bin/ngspice` (45.2) and on the fork,
and reads the results back with a second ngspice: the supply is noisy (σ 0.85 mV / 0.84 mV), the
net carries the random current, and the run's point count (1210 / 1349) is within a factor of two
of the form's estimate (1000). It then reopens the form, which now estimates the results file from
that run's own vector count (88 kB) — checked against the files the runs wrote (106,899 /
119,130 bytes).

## Declared limits

* **A cold bench offers no targets.** Without warm facts nothing can say which source carries a
  waveform. Add still makes an entry, whose verdict says it names nothing, and the name can be
  typed.
* **The net reader knows the node positions of `r c l v i d b e f g h j m x` cards only.** A net
  reached only through another card kind is not offered (it can be typed; the check judges it).
* **The estimates follow the form's step and stop on a key release.** A value pasted into those
  fields without a key moves the estimate at the next edit in the section.
* **The results-file size needs a previous run** of that same row (a plotmap record naming it).
* The Options sheet's rendering of the new text is `test_ase_optsheet_1441`'s generic detail row;
  this suite checks the text as data.
