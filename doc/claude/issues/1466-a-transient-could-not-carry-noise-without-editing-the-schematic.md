# 1466 — A transient could not carry noise without editing the schematic

**Status:** the DECK half is implemented — Stage 13 task 1 of `doc/claude/ase_analyses_batch/`.
The Tran form's section (task 2) is not yet built, so today the table is reachable only by the
core procs and a `.state` file.
**Suite:** `tests/headless/test_ase_trnoise_1466.tcl` (T1 `hcases`, headless only).
**Receipt:** `doc/claude/ase_analyses_batch/receipts/41-stage-13-deck.md`.
**Ruling:** ⚖ R9 — every sentence and label below is recommended copy, recorded with
`owed.sh add rule 1466` and in `R9_COPY_REVIEW.md`.

## What the user met

ngspice can make any independent source emit **transient noise** — white, 1/f and random
telegraph (`trnoise`) — or a **random value held for a time** (`trrandom`). It is the noise
`.NOISE` cannot show: jitter on a clock edge, a comparator flipping, a burst. ASE-L had no way to
ask for either. The only door was typing positional arguments onto a source on the schematic,
which ASE-L's founding doctrine forbids and which two shipped ngspice examples get wrong
(`simple-noise.cir`'s "1/f noise" is white noise plus a permanent offset).

## What was measured before a line was written (2026-09-15, apt 45.2 AND the ngspice-46+ fork)

Scratch decks, `HOME` pointed at an empty directory, every run under `timeout`.

| fact | 45.2 | fork |
|---|---|---|
| `alter v1 trnoise = [ 1m 1u 0 0 0 0 0 ]` on a DC-only V source, then `tran` | `@v1[function]` = 7, rms 0.85 mV | identical shape, rms 0.83 mV |
| the same with `1e-3 1e-6` — SI suffixes inside the brackets | same readback | same readback |
| the same on an I source (`i1 0 n dc 0`) | noisy | noisy |
| `op`, then `alter`, then `tran` | noise reaches the tran | same |
| two transients, **no** restore between | the second is noisy too (rms 0.84 V, 4421 points where the card asks for ~108) | same (5004 points) |
| two transients, `alter … trnoise = [ 0 0 0 0 0 0 0 ]` between | second clean: rms 0, 108 points | same |
| the zero `trnoise` vector after a `trrandom` source | `@v1[function]` = 7, second tran clean, no error | same |
| `alter …`, `reset`, `tran` | **clean** — `alter` does not survive `reset` | same |
| `trrandom(2 1u 1m 1m 0)` on an **I** source (TD ≫ TS) | **1** distinct value after TD, held to the end | same |
| the same on a **V** source | 501 / 502 values per half-window | same |
| `trrandom(2 10u 0 1m 0)` on an I source, TD = 0 | redraws throughout | same |
| forced `optran 0 0 0 100n 10u 0` + `trrandom` TD = 0, `op` | `v(qq)` = 8.33e-02 (a draw) | -1.40e-01 |
| the same, `tran`: first point | 8.29e-02 | 5.93e-02 |
| the same with TD = 1n | first point 0, later values random | same |
| `notrnoise`: white / 1/f / RTS-only / white+RTS / trrandom | 0 / 0 / **survives** / 0 / **survives** | same, inline and through `alter` |
| `.options seed=5` or `setseed 5`, two runs, through `alter` | RTS mean and trrandom mean identical, white mean differs | same |
| a carrier on a net nothing else touches | rc 0, nothing said | rc 0 |
| points for `tran 1u 1m`, TS = 100u / 10u / 1u / 100n | 1039 / 1309 / 4415 / 44116 | 1039 / 1309 / 5008 / 50008 |
| bytes per value in the `write` rawfile | 8 | 8 |
| `ase_inoise_1 0 out dc 0 trnoise(...)` (PLAN §13's name) | not run | XSPICE `a` card: `MIF-ERROR - unable to find definition of model 0`, rc 1 |
| `alter v1 trnoise = [ 1m -1u 0 0 0 0 0 ]` | **not run — it hangs** | **hangs**, rc 124 under `timeout 10` |
| a current source on a digital node | not run | `singular matrix: check node dig`, optran rescues, rc 0 |

## What shipped

**The state.** A table on the `tran` row under the key `noise`. An entry is
`{src <source> | net <net>, func trnoise|trrandom, <arguments…>, [enabled 0]}` — `na ts nalpha
namp rtsam rtscapt rtsemt` for `trnoise`, `dist ts td param1 param2` for `trrandom`. No top-level
key, nothing in `ase::omit_if_empty`, no `seed_enabled`; all 104 committed `.state` files
round-trip byte-identically.

**Schema (core, `src/ase.tcl`).** A `stimuli` contract on a registry entry, validated by
`ase::analysis_schema_errors` (`badstimuli`, `twotables`, `nostimulikey`, `stimulikeyclash`,
`nostimuliselector`, `nostimulilines`, `badstimulilines`, `badstimulihook`, `nostimulitargets`,
`nostimulifunctions`, `badstimulifunction`, `badstimuliarg`). `ase::analysis_setup_key` now
answers the `stimuli` key too, so the `Options…` editor's two sites skip it. Readers:
`ase::analysis_stimuli`, `stimuli_get`, `stimuli_rows`, `stimuli_entry_on`, `stimuli_field`,
`stimuli_function`, `stimuli_args`, `stimuli_arg_names`, `stimuli_arg_role`, `stimuli_values`
(every positional argument, padded), `stimuli_target`, `stimuli_emit`, `stimuli_netlist_lines`,
`stimuli_verdicts`, `stimuli_worst`, `stimuli_banner`, `stimuli_num`. Readouts: `noise_density`,
`noise_flat_to`, `noise_points`, `noise_bytes`, `stimuli_min_interval`, `stimuli_points`,
`stimuli_readout`. Seed and kill data: `stimuli_kinds`, `stimuli_seeded`, `stimuli_seed_report`,
`stimuli_kill_report`. Facts: `ase::facts_net_status`, `ase::facts_event_node`;
`ase::netlist_facts` records a source's `wave` and carries `globals` and `includes`. A new
`stimuli_check` precondition on `tran`.

**Content (`ase::backend::ngspice::`).** `noise_contract`, `noise_carrier_base`,
`noise_alter_target`, `noise_carrier_lines` (the netlist leg), `noise_alter_lines`,
`noise_restore_lines`, `noise_check` / `noise_entry_check`, `noise_kinds`, `noise_quantity`,
`noise_kind_phrase`, `noise_seed_sentences`, `noise_reserved_hit`, `noise_num`, `noise_numz`.

**The deck.** Three slots in `render_deck`, each empty for every bench without a table:
1. **right after the netlist** — a quiet carrier per injected entry: `iase_noise_<row>_<k> 0 <net>
   dc 0` for `trnoise`; `vase_noise_<row>_<k> ase_noise_<row>_<k> 0 dc 0` plus
   `gase_noise_<row>_<k> 0 <net> ase_noise_<row>_<k> 0 1` for `trrandom`;
2. **above the row's card**, with the setup lines — `alter <source|carrier> <fn> = [ … ]`, every
   argument, positionally, padded with 0;
3. **below the guard, above `remzerovec`** — `alter <source|carrier> trnoise = [ 0 0 0 0 0 0 0 ]`.

And `render_deck`'s precheck tier now merges the measured event inventory, as the gate already did.

## Declared limits

* **The salvage estimator (`tran_points`) does not know the noise timestep.** It decides
  checkpointing, and a checkpointed noisy transient is unmeasured, so it was left alone and
  `ase::stimuli_points` raises its answer for the readout only. A noisy transient whose card alone
  is below the 100,000-point floor is therefore not checkpointed.
* **The `notrnoise` catalogue row's text is unchanged.** Its `results_why` names only the white
  case; rewriting it moves text the Options sheet shows, which is task 2's pixel half.
* **A source inside an `.include` or a subcircuit** is a caution, never a refusal.
* **The digital-node refusal needs a measured inventory**; an unmeasured mixed circuit is refused
  by nothing (a refusal is never a guess).
* **Route 3 (a series voltage source)** is not offered: it renames a net.
* **The Analyses pane's Arguments column** shows a row carrying a table as `noise={…}` — the same
  generic rendering `ports={…}` already gets. Task 2's.
* **A table-altered source ends the run as a zero `trnoise`** rather than a DC-only source; it
  outputs its `dc` value, which is what the restore measured for the next transient.

## The sentences

32 new refusal and caution sentences, 28 new fixes, the split seed sentence (three templates and
the kind names) and 25 labels the task 2 form will show — `R9_COPY_REVIEW.md`, section *Issue
1466*. The unreadable-value refusal reuses the existing `cannot read '<v>' as a number for
'<field>'`, and the name refusal's fix reuses `use the name as the netlist spells it`.
