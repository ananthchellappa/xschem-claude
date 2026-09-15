# Issue 1466 — Stage 13 task 1, transient noise and `trrandom`: the DECK half

**PLAN.md §13, task 1 of the driver's split** (LEDGER *Stage 13 — 📋 task split*). Files touched, and
nothing else: `src/ase.tcl`, `tests/headless/test_ase_trnoise_1466.tcl` (new),
`tests/run_regression.tcl` (`hcases`), `tests/headless/test_ase_sp_1452.tcl` (row SK1's fourth term,
see C12), `doc/claude/issues/1466-a-transient-could-not-carry-noise-without-editing-the-schematic.md`
(new), `doc/claude/issues/NUMBERING.md`, `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md`,
`doc/claude/ase_analyses_batch/PLAN.md` (a correction block at the head of §13 only) and this receipt.

**`src/ase_window.tcl` is untouched: md5 `008b95cc9c55ad9ee23e5f974e905175` before and after.**
**No commit, no `git add`, no stash/restore/clean/push. `tests/run_regression.tcl` NOT run** (issue
0990 — the driver's, solo). **No C** — `make -q -C src` was rc 0 at the start and nothing compiled
changed, so `src/xschem` (md5 `96fc4899…`) is the sources' binary and T1 needs no rebuild. No
simulation on any bench under `sky130A/`; every ngspice run is a hand-written deck or a deck ASE-L
rendered, in a scratch directory, against an explicit binary path, with `HOME` pointed at scratch.

---

## ⚠ THE HEADLINES

### 1. The noise reaches the deck, both routes, and it is verified by running it on both binaries

Section **EE** of the new suite renders one bench through `render_deck` — a `tran` row carrying
white noise on an altered supply, a `trrandom` current injected into a net, and an RTS source — then a
second `tran` row with no table, `.options seed=5`, and runs it; a **second ngspice process**
(`load` + `stddev`/`maximum`/`mean`) reads the results back without knowing anything about ASE-L.

| row | apt 45.2 | fork |
|---|---|---|
| EE1 rc 0, both transients in the plotmap, results read back | ✅ | ✅ |
| EE2 the noisy row: white σ > 0, injected random σ > 0, RTS reaches 5 mV | ✅ | ✅ |
| EE3 the next row is clean (|σ| < 1e-9 on all three) and has its card's points, not the noise's | ✅ | ✅ |
| EE4 the noisy row's point count is within 2× of `ase::stimuli_points` | ✅ | ✅ |
| EE5 two seeded runs: the random source and the RTS source repeat, white noise does not — **and `ase::stimuli_seed_report` says exactly that split** | ✅ | ✅ |
| EE6 with `notrnoise`: white gone, random and zero-timestep RTS survive — **as `ase::stimuli_kill_report` says** | ✅ | ✅ |

### 2. ⚠ A CONTRACT OF ITS OWN, BECAUSE THE WINDOW DRAWS EVERY `setup` CONTRACT

Stage 9's `setup` contract is the obvious home for a per-row table and **cannot be used here**:
`ase::ui::chana_show` grids a table button for any type whose `setup` declares `columns`, and
`ase::analysis_schema_errors` requires them. A `setup` contract on `tran` would have put a button on
the Tran form in the task that must draw nothing. It also has no leg for the netlist slot, and its
`check` leg gets the row alone. So a new **`stimuli`** contract — and **`ase::analysis_setup_key` now
answers either contract's key** (one per type; `twotables` refuses both), which is Stage 9's lesson 2
honoured: the `Options…` editor's reader and writer ask that proc, so they skip `noise` untouched.

### 3. ⚠ THE RESTORE IS MEASURED: A NETLIST-LEVEL SOURCE LEAKS INTO EVERY LATER TRANSIENT

Both binaries: `alter … trnoise = [ … ]`, `tran`, then a second `tran` with **no** restore → the second
is noisy (rms 0.84 V on a `dc 0` source; 4421 / 5004 points where its card asks for ~108). With
`alter … trnoise = [ 0 0 0 0 0 0 0 ]` between them: rms 0, 108 points — and the same zero vector
clears a `trrandom` source (`@v1[function]` = 7, no error). So PLAN §13's inject route, which writes
`trnoise(…)` on the carrier **card**, would have given every transient in the deck one row's noise.
Shipped: a **quiet carrier** in the netlist slot, altered above its own row's card, restored below the
guard. EE3 is the row.

### 4. ⚠ `trrandom` ON A CURRENT SOURCE FREEZES — AND NOW IT HAS A DETERMINISTIC TRIGGER

The claim came from finding F16 in the design documents with no deck behind it, and
`evidence/trnoise.md` T11 says *"do not let a plan claim ISRC is broken"*. Two first triggers did not
freeze (TD = 0; a breakpoint 20 ps before a multiple of TS). Reading `isrcacct.c` gave the real one:
the ISRC redraws — **and posts its next breakpoint** — only when `CKTtime - TD` is within 3 ulps of
`n*TS`, so a delay far larger than the hold time misses the first redraw and never posts another.
Measured on **both** binaries, `trrandom(2 1u 1m 1m 0)`:

| source | distinct values in [1 m, 1.5 m) | in [1.5 m, 2 m] |
|---|---|---|
| I | **1** | **1** |
| V | 501 | 502 |

So the inject route carries a random value on a **V source into a 1 S VCCS**, and the `alter` route
**refuses** `trrandom` on an existing I source. `trnoise` has no delay; its I carrier redraws (M3,
5004 points).

### 5. ⚠ `PLAN.md` §13's CARRIER `ase_inoise_1` IS AN XSPICE `a` CARD

SPICE reads a device from its first letter. **Fork only**: `MIF-ERROR - unable to find definition of
model 0`, `Simulation interrupted due to error!`, rc 1 — and `ase::netlist_facts` would have filed it
under `xspice` and started Stage 12's event probe. Shipped names begin with their letter:
`iase_noise_<row>_<k>`, `vase_noise_…` / `gase_noise_…`. Sabotage S02 is that name, and it reds NE3.

### 6. Two display-arm reds were already on the untouched tree, and neither moved

* `test_ase_dialogs` **G2sens**, issue **1436**, standing — **deterministic on `:99` today, 3 of 3 runs
  before any change** (`{1 1 0 1 0 Entry Entry normal}`), and the identical value after.
* `test_ase_optier_0963` display arm **stalls after row N3** — rc 124 at the 900 s cap, 91 rows,
  before any change; re-run on the finished tree under a 300 s cap: rc 124, 91 rows, last N3. This is
  the stall CLAUDE.md records; T1 runs that suite headless only (109, green).

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

All measurements 2026-09-15, scratch decks, `HOME` → scratch, every run under `timeout`. Decks and
outputs: `…/scratchpad/s13/meas/`.

| claim | evidence |
|---|---|
| `alter <src> trnoise = [ … ]` on V and I, SI suffixes inside the brackets, readback via `@src[trnoise]` | **MEASURED HERE**, both (m2, m2b, m3) |
| an `alter` after an `op` still reaches the `tran` | **MEASURED HERE**, both (m4) |
| no restore → the next transient is noisy; zero `trnoise` restores; it clears `trrandom` too | **MEASURED HERE**, both (m5a, m5b, m5c) |
| `alter` does not survive `reset` | **MEASURED HERE**, both (m8) |
| `trrandom` on I freezes with TD ≫ TS; does not with TD = 0 or a near-merged breakpoint | **MEASURED HERE**, both (td_i/td_v, m6a/m6b, trig_*) |
| V source + 1 S VCCS carries a random current | **MEASURED HERE**, both (m6c) |
| `notrnoise` split, inline and through `alter` | **MEASURED HERE**, both (m10, m10alt) — was fork-only in `evidence/trnoise.md` §5.4 |
| forced `optran` puts a draw into `op` and into the transient's first point; TD = 1n keeps it out | **MEASURED HERE**, both (m17, m17t, otd_*) |
| seeds by kind through the `alter` route, `.options seed=5` and `setseed 5` | **MEASURED HERE**, both (m7opt, m7set), and again in-suite (EE5) |
| a carrier on a net nothing else touches runs at rc 0 | **MEASURED HERE**, both (absent) |
| points at TS = 100u / 10u / 1u / 100n under `tran 1u 1m` | **MEASURED HERE**, both: 1039/1309/4415/44116 (45.2), 1039/1309/5008/50008 (fork) |
| 8 bytes a value in the `write` rawfile | **MEASURED HERE**, both (rawsz) |
| a control-only deck can `load` a raw and `stddev`/`maximum` it | **MEASURED HERE**, both (reader) |
| `ase_inoise_1` is an `a` card | **MEASURED HERE, fork only** (f1) — a deck ASE-L never emits |
| a negative TS through `alter` hangs | **MEASURED HERE, fork only** (f12, rc 124 under `timeout 10`) — ⚠ **never run on 45.2** |
| a current source on a digital node | **MEASURED HERE, fork only** (f11b) — refused, so 45.2 is never handed it |
| white noise irreproducible under every control; `trrandom` equal across binaries under a seed | **TRANSCRIBED** from `evidence/trnoise.md` §4 and `events-and-trnoise.md` Part 2; the split re-confirmed per binary (not across) |
| NALPHA = 2 silent zero, NALPHA = 0 discards NAMP, short forms are a heap read | **TRANSCRIBED** (`evidence/trnoise.md` T2–T4) |
| 1/f pre-allocation ≈ 40 bytes a sample | **TRANSCRIBED** (§2.2) |

---

## What shipped

`git diff --numstat` at hand-over: `src/ase.tcl` **+1234 / −5**, `tests/run_regression.tcl` **+10 / −1**,
`tests/headless/test_ase_sp_1452.tcl` **+11 / −1**, `doc/claude/ase_analyses_batch/PLAN.md` **+25**,
`R9_COPY_REVIEW.md` **+1011 / −1**, `NUMBERING.md` **+5 / −1**; new
`tests/headless/test_ase_trnoise_1466.tcl` **871 lines**, the issue file **109 lines**. (PLAN §13
budgeted `src/ase.tcl` ≈ +200 for both halves; roughly a third of the +1234 is the measurement-bearing
comments.)

### The state

A table on the `tran` row under the key **`noise`** — no top-level key, nothing in
`ase::omit_if_empty`, no `seed_enabled` anywhere. An entry is

```
{src <source> func trnoise na <v> ts <v> nalpha <v> namp <v> rtsam <v> rtscapt <v> rtsemt <v>}
{net <net>    func trrandom dist <1-4> ts <v> td <v> param1 <v> param2 <v>}
                                                    ... and `enabled 0` switches one entry off
```

### Schema — `src/ase.tcl`, namespace `ase::`

| proc | what |
|---|---|
| `ase::analysis_setup_key` | **generalised**: the `setup` key, else the `stimuli` key |
| `ase::analysis_schema_errors` | the `stimuli` block: `badstimuli twotables nostimulikey stimulikeyclash nostimuliselector nostimulilines badstimulilines badstimulihook nostimulitargets nostimulifunctions badstimulifunction badstimuliarg` |
| `ase::needs_eval` | new `stimuli_check` arm — worst finding of the adapter's `check` leg |
| `ase::netlist_facts` | a source's `wave` keyword; `globals` and `includes` beside `nodes` |
| `ase::analysis_stimuli`, `stimuli_get`, `stimuli_rows`, `stimuli_entry_on`, `stimuli_field` | the contract and the table, total readers |
| `ase::stimuli_function`, `stimuli_args`, `stimuli_arg_names`, `stimuli_arg_role` | functions, POSITIONAL descriptors, roles (`amplitude`, `interval`, `flicker`) |
| `ase::stimuli_values` | **every positional argument, padded with the contract's `pad`** |
| `ase::stimuli_target` | `{route field value}` for exactly one target |
| `ase::stimuli_emit`, `stimuli_netlist_lines` | the per-row legs (do not catch) and the netlist slot (enabled rows only) |
| `ase::stimuli_verdicts`, `stimuli_worst`, `stimuli_banner` | all findings per entry; the worst; the precheck-banner shape |
| `ase::stimuli_num` | a number through the adapter's `si_suffixes`, plain numbers only without it |
| `ase::noise_density`, `noise_flat_to`, `noise_points`, `noise_bytes` | the arithmetic |
| `ase::stimuli_min_interval`, `stimuli_points`, `stimuli_readout` | the row estimate and the per-entry readout dict |
| `ase::stimuli_kinds`, `stimuli_seeded`, `stimuli_seed_report`, `stimuli_kill_report` | seed and kill data |
| `ase::facts_net_status`, `facts_event_node` | a net through `netlist_map_resolve`; a MEASURED event node |
| `ase::backend::ngspice::render_deck` | three slots (netlist / above the card / below the guard) and the evtinv merge at its precheck tier |

### Content — `ase::backend::ngspice::`, reached through the registry's `tran` entry

`noise_contract` (the `stimuli` dict on `tran`, plus `stimuli_check` in `needs`), `noise_carrier_base`,
`noise_alter_target`, `noise_carrier_lines`, `noise_alter_lines`, `noise_restore_lines`, `noise_check`,
`noise_entry_check`, `noise_kinds`, `noise_quantity`, `noise_kind_phrase`, `noise_seed_sentences`,
`noise_reserved_hit`, `noise_num`, `noise_numz`. **No new `register_backend` hook**: every leg is a
proc name inside the registry entry, exactly as Stage 9's `setup` legs are, so **a backend whose
`analysis_types` declares no `stimuli` gets nothing** (rows NB1/NB2; sabotage S53).

### Where each line sits, and why each side

* **carrier** — right after the netlist, above `.include`/`.lib`/`.param`, outside `.control`
  (`evidence/trnoise.md` §10.4's slot);
* **`alter … = [ … ]`** — with Stage 9's setup lines: above the checkpoint arm and the verbatim hatch,
  so VB1/VB2's hatch-adjacent-to-card still holds (NE6) and a hatch can override the table;
* **zero restore** — the `post` leg's place: below the `$sim_status` guard (a failed transient has
  nothing to put back), above `remzerovec` and the `write`. **Stage 12's `eprvcd` line and every
  positional anchor above it are unmoved**: `test_ase_events_1465` 87 on both arms, `test_ase_optier_0963`
  109, `test_ase_core` 638.

---

## Suites — before → after, every arm, with rc

**Before** is the untouched tree, measured first (`…/s13/base/`). **After** is the finished tree
(`…/s13/after/`, then `…/s13/final/` for the new suite, the SP suite and the optier re-run). Headless
`./src/xschem --nogui --pipe -q --nolog --script`; display `tests/headless/devdisplay.sh exec ./src/xschem
--pipe -q --nolog --script`; each under `timeout`.

| suite | headless before | headless after | display before | display after |
|---|---|---|---|---|
| **`test_ase_trnoise_1466`** | — (new) | **ALL PASS (62), rc 0** | — | **ALL PASS (62), rc 0** |
| `test_ase_core` | 638, rc 0 | 638, rc 0 | 638, rc 0 | 638, rc 0 |
| `test_ase_persist` | 49 | 49 | 153 | 153 |
| `test_ase_preflight` | 235 | 235 | 235 | 235 |
| `test_ase_effective_1442` | 92 | 92 | 92 | 92 |
| `test_ase_options_1437` | 75 | 75 | 75 | 75 |
| `test_ase_converge_1459` (the `optran` rung) | 76 | 76 | 76 | 76 |
| `test_ase_campaign_1462` (seeds) | 133 | 133 | 133 | 133 |
| `test_ase_events_1465` (the transient block) | 87 | 87 | 87 | 87 |
| `test_ase_dialogs` | 37 | 37 | ⚠ **1 FAILED (384), rc 1** — G2sens, 1436 | ⚠ **1 FAILED (384), rc 1** — G2sens, value-identical |
| `test_ase_window` | 56 | 56 | 295 | 295 |
| `test_ase_sp_1452` | 58 | **58** (SK1 term moved, C12) | 58 | **58** |
| `test_ase_optsheet_1441` (the `notrnoise` row) | 62 | 62 | 87 | 87 |
| `test_ase_simreg_0931` (P6) | 117 | 117 | 117 | 117 |
| `test_ase_predeck_1439` (CM5/CM6) | 78 | 78 | 78 | 78 |
| `test_ase_meas_1443` | 113 | 113 | 113 | 113 |
| `test_ase_optier_0963` | 109, rc 0 | 109, rc 0 | ⚠ **TIMEOUT rc 124**, 91 rows, after N3 | ⚠ **TIMEOUT rc 124**, 91 rows, after N3 (300 s cap) |

Every row rc 0 except the two marked, both pre-existing and unmoved. `run_cmd`'s body is untouched, so
P6 and CM5/CM6 had nothing to red on.

### Per binary

Section **EE** runs on **`/usr/bin/ngspice` (45.2)** and on **`/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(the fork)** — six rows each, twelve green, **no `SKIPPED` line** in any final log. Every direct
measurement in this receipt was taken on both unless marked *fork only*, and the three fork-only
decks are decks ASE-L refuses or never emits.

### Reds met on the way, and whose they were

| red | whose | outcome |
|---|---|---|
| first run of the new suite, 9 FAILED: NR2, NK19, NX2, NX3, NS1, EE3/both, EE6/both | **mine, in the suite**: a dc row's first finding is `missing source`; an odd-length entry reads as unreadable; 5·1m/100n is 50000; line-continuation spaces in a literal; `stddev` of a constant 1.8 V prints `6.67741E-15` | repaired before the campaign — EE uses a 1e-9 tolerance, six orders under the 1e-3 noise it looks for |
| NK15 could not tell "first finding" from "worst" | **mine** — the fatal entry came first | entries reordered so a caution precedes the fatal; S35 reds it |
| no row covered `render_deck`'s evtinv merge | **mine** | NK21 added, seeding the inventory under the probe's key; S15 reds it |

---

## `.state` byte identity

Through **`tests/headless/state_roundtrip.tcl`** (`ase_state_roundtrip`), inside the new suite (row NC1,
which prints the numbers) on the finished tree:

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

No top-level state key; `ase::omit_if_empty` untouched. NC2: a bench carrying a three-entry noise table
saves, loads and saves again to the same bytes.

---

## THE SABOTAGE CAMPAIGN — 58 mutations, 58 killed by name, 0 restore mismatches

One runner (`sab.py`), started only after the after-change suites had finished, since mutations
rewrite `src/ase.tcl`. **The gate is a positive assertion and was fed the empty case first**:
`GATE CONTROLS empty=NORESULT noresult=NORESULT pass=SURVIVED fail=KILLED timeout=NORESULT`. Every
mutation: exact-anchor count of 1, apply, the suite headless under `timeout 300`, reds by row name,
restore by **plain copy** (Tcl only, nothing to build), md5 printed, pristine checked before the next.
Two mutations run the **fork only** (`ASE_NZ_NGSPICE`), because their decks are unmeasured on 45.2: S02
(an `a`-named carrier) and S54 (a `trrandom` zero restore, a hold time of 0 in the next transient).

| # | what I broke | rows that reddened |
|---|---|---|
| S01 | core does not pad a blank argument | NE1 NE2 NE3 NE4 NE8 EE4 EE5 EE6 (both) |
| S02 | the carrier loses its device letter — PLAN's `a` card [fork] | NE3 NE8 NK21 |
| S03 | a random current through a current source | NE4 EE2 EE6 (both) |
| S04 | nothing put back after the transient | NE5 NE8 EE3/apt EE3/fork |
| S05 | the `lines` and `post` legs trade places | NE1 NE5 NE6 NE8 EE2–EE6 (both) |
| S06 | the netlist slot emits nothing | NE3 NE4 NE8 EE2 EE6 (both) |
| S07 | the netlist slot serves disabled rows | NE7 |
| S08 | an entry's `enabled 0` ignored | NE7 |
| S09 | the noise between the hatch and the card | NE6 |
| S10 | `analysis_setup_key` answers `setup` only | 48 rows across NR/NE/NK/NX/NS/NC/EE **and `test_ase_sp_1452` SK1** |
| S11 | the schema forgets `twotables` | NR4 |
| S12 | the schema forgets a non-command `lines` | NR4 |
| S13 | `stimuli_check` answers nothing | NK1 NK15 NK21 |
| S14 | `tran` does not declare `stimuli_check` | NK1 NK15 NK21 |
| S15 | `render_deck` does not merge the measured inventory | NK21 |
| S16 | negative TS not refused | NK1 |
| S17 | TS = 0 under an amplitude not refused | NK2 |
| S18 | exponent exactly 2 accepted | NK3 |
| S19 | `netlist_facts` records no waveform | NK4 |
| S20 | `trrandom` on a current source not refused | NK5 |
| S21 | a missing source refused as fatal | NK6 |
| S22 | any device letter may carry noise | NK7 |
| S23 | noise into ground not refused | NK8 |
| S24 | an absent net refused despite includes | NK8 |
| S25 | no net is ever a measured event node | NK9 NK21 |
| S26 | distribution 5 accepted | NK10 |
| S27 | hold time 0 accepted | NK10 |
| S28 | an unreadable value not refused | NK11 |
| S29 | RTS times of 0 accepted | NK12 |
| S30 | the `optran` caution ignores the delay | NK5 NK13 |
| S31 | the `optran` caution ignores the rung switch | NK13 |
| S32 | an all-zero entry not cautioned | NK14 |
| S33 | a huge 1/f record only cautioned | NK14 |
| S34 | the check stops after the first entry with a finding | NK15 |
| S35 | the precondition takes the first finding, not the worst | NK15 |
| S36 | no target / two targets not refused | NK16 |
| S37 | reserved carrier names not checked | NK17 |
| S38 | a name that splits the command not refused | NK18 |
| S39 | an unreadable table silently dropped | NK19 |
| S40 | the row's point-count caution gone | NK20 |
| S41 | density drops the factor of 2 | NX1 |
| S42 | point estimate ignores points per interval | NX2 NX3 EE4 (both) |
| S43 | row estimate ignores its noise | NK20 NX2 NX3 EE4 (both) |
| S44 | the salvage estimator made noise-aware | NX2 |
| S45 | file size forgets bytes per value | NX3 |
| S46 | 1/f bytes forget the pad | NX4 |
| S47 | every amplitude in volts | NX5 |
| S48 | `notrnoise` kills RTS whatever the timestep | NS1 NS5 EE6 (both) |
| S49 | a seed said to repeat white noise | NS1 NS2 NS3 EE5 (both) |
| S50 | one sentence about noise in general | NS2 NS3 NS4 |
| S51 | an options seed row not counted as seeded | NS4 EE5 (both) |
| S52 | the kill switch never armed | NS5 |
| S53 | a backend with no contract borrows ngspice's | NB1 NB2 |
| S54 | the restore zeroes the entry's own function [fork] | EE1 EE3 EE5 EE6 |
| S55 | `netlist_facts` stops carrying globals/includes | NK8 |
| S56 | values in sorted, not positional, order | NE1 NE2 NE3 NE4 NE8 EE2–EE6 (both) |
| S57 | the schema forgets an argument with no label | NR4 |
| S58 | the RTS time descriptors swap positions | NR3 |
| **final** | **the restored tree** | **`test_ase_trnoise_1466` ALL PASS, `test_ase_sp_1452` ALL PASS** |

**Hygiene rows, not sabotaged, and they assert identities:** NR1 (the registry is self-consistent and
exactly `tran` declares the contract), NR4a (the fixture backend is really read — non-vacuity for NR4),
NC1 (the helper's four numbers), NC2 (a noise-carrying state round-trips). **What S10's reds say:** it
takes 48 rows down because every reader of the table goes through the key — which is also why the
Options editor could not have seen the table any other way.

Logs: `…/scratchpad/s13/sab/results.txt`, `…/sab/logs/<id>.<suite>.log`, `…/sab/runner.out`.

---

## Debts filed — queue before → after

Backed up first: `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/s13_1466/owed_backup_s13` (`cp -a
~/.claude/xschem_owed`).

| | rule | look | suite |
|---|---|---|---|
| **before** | 178 | 68 | 11 |
| **after** | **179** | **68** | **11** |

* **`add rule 1466`** — recorded. `R9_COPY_REVIEW.md` **R9-565 … R9-653**, header **564 strings from
  30 issues → 653 strings from 31 issues**. The generator refused to write unless every entry's fixed
  text was byte-present in the continuation-joined `src/ase.tcl`, and all 89 were. 32 refusals and
  cautions, 28 fixes, the split seed sentence (three templates and the kind names) and 25 labels. Two
  existing strings are reused, not re-filed: `cannot read '<v>' as a number for '<field>'` and
  `use the name as the netlist spells it`.
* **No `look`: task 1 draws nothing.** No widget, no pane, no badge. The Options sheet's `notrnoise`
  row text was deliberately left alone for that reason (C11). **Task 2 owes the decision** (see
  below).
* **No `suite` debt**: the new suite maps no window and runs headless in T1.

---

## Corrections — to PLAN.md, APPENDIX §5, `evidence/trnoise.md`, the brief, the CREW_BRIEF and the ledger

| | |
|---|---|
| **C1** | ⚠ **PLAN.md §13 / APPENDIX §5.5 / `evidence/trnoise.md` §10.2 and §10.4: `ase_inoise_1 0 out dc 0 trnoise(…)` is an XSPICE `a` card** (fork: MIF-ERROR, rc 1). Carriers must begin with their device letter |
| **C2** | ⚠ **PLAN.md §13: the injected card carrying `trnoise(…)` would serve every transient in the deck.** Measured leak on both binaries; shipped a quiet carrier + `alter` above the row + zero restore below the guard |
| **C3** | ⚠ **`evidence/trnoise.md` T11 ("do not let a plan claim ISRC is broken") is too wide, and PLAN's freeze claim had no deck.** ISRC `trrandom` with TD ≫ TS freezes on BOTH binaries (1 value vs 501); ISRC `trnoise` and TD = 0 `trrandom` redraw. Mechanism in `isrcacct.c`'s 3-ulps test on `CKTtime - TD` |
| **C4** | **PLAN.md §13 "non-positive TS" refusal is too wide for `trnoise`**: TS = 0 is the legal RTS-only idiom (`evidence/trnoise.md` §1.2's own asymmetry); refused only under a white or 1/f amplitude. Negative TS hangs (fork only); `trrandom` TS ≤ 0 refused |
| **C5** | ⚠ **PLAN.md §13 / APPENDIX §5.4: "not reproducible *in this build*"** — it is both binaries. The shipped sentence names the kinds, and says RTS noise and random sources DO repeat |
| **C6** | ⚠ **The task brief: "the seed is a campaign's (Stage 11), emitted once as `setseed` in `.control`".** Stage 11 shipped **`.options seed=<n>` per shard** (`campaign_seed_option` → `seed`; `setseed` misses netlist-level `agauss`). Measured here: both routes reproduce RTS and `trrandom` through `alter`, on both binaries, so the seed report treats a seeded campaign or an options `seed` row as seeded |
| **C7** | **PLAN.md §13 "the section warns when Stage 10's rung 4 is armed"** — the warning has a measured fix: any delay above 0 keeps the draw out of the first point (both binaries). It fires only for TD = 0 with the transient rung on (the default) |
| **C8** | **PLAN.md §13 / APPENDIX §5.2: "points ≈ `5*tstop/TS`"** is the fork's factor below the step; 45.2 gives ≈ 4.4 (4415 vs 5008; 44116 vs 50008). At TS = 10× the step both give 1309 against `max()`'s 1000. Worded as an estimate; no golden pins it |
| **C9** | **`evidence/trnoise.md` §10.3's "Kind: Voltage / Current — only for the inject route"**: a voltage source across a net shorts it; the inject route is a current. `trrandom` reaches it as a V source into a VCCS, an implementation detail the user never chooses |
| **C10** | **The brief's open question "does `alter` survive `reset` in a campaign shard"** — `alter` does NOT survive `reset` (both binaries, m8). No ASE-L emitter resets and a shard is its own process, so nothing is affected today; a future `.control` loop that resets must re-emit the `alter` lines |
| **C11** | **The brief's "the `notrnoise` catalogue row"**: the row has existed since Stage 7 and is correct as far as it goes; its `results_why` names only the white case. The Options sheet SHOWS `help` and `results_why` (`ase_window.tcl` option detail) and a `caveat` changes the row's badge, so the text is left for task 2; the kill split is shipped as data (`kill notrnoise` + `ase::stimuli_kill_report`) and verified against both binaries (EE6) |
| **C12** | **`test_ase_sp_1452` SK1's fourth term moves `{}` → `noise`**, with its own paragraph; count unchanged at 58. The row's point — `ports` refused on a `tran` row, no blanket list — holds |
| **C13** | **PLAN.md §13 *Files and procs*: "`src/ase.tcl` ≈ +200"** for both halves; task 1 alone is +1234 (a third comments carrying measurements). `src/ase_window.tcl` none, as split |
| **C14** | **LEDGER *Next* item 1: "the seed sentence's logic split by noise kind (… RTS and `trrandom` under `setseed` in `.control`)"** — also under `.options seed=`, the route ASE-L actually emits (C6) |
| **C15** | ⚠ **Numbering, at mint time**: `xschem-op-wcard`'s `NUMBERING.md` now matches 1466 because it carries this clone's HEAD and its pointer reads *"next free number is 1466"* — a pointer, not a reservation, and no issue file there. **Both clones' pointers read 1466; whichever commits a 1466 second collides.** This clone's is advanced to 1467 |

---

## What task 2 must build on

* **The table and its key.** Read and write the row key through `ase::analysis_setup_key ngspice tran`
  (it answers `noise`); **do not add a blanket list** — the Options editor's two sites already skip it
  (NR2, SK1). An entry is ON unless `enabled 0`.
* **The form's fields are data**: `ase::stimuli_get ngspice tran functions` (labels), `ase::stimuli_args
  ngspice tran <fn>` in **positional order** (each with `label`, `unit` — `s` or `source`, meaning V on a
  voltage source and A otherwise, see `stimuli_readout`'s `quantity` — `values`/`valuelabels` for the
  distribution, per-distribution `labels` for `param1`/`param2`), `targets` (Source / Net), `noun`.
  Show values in that order and nothing can reach the deck in another position.
* **Greying stimulus-bearing sources**: `ase::netlist_facts` records `wave` (and `trnoise`/`trrandom`) per
  source, with `scope {}` for top level. Offer top-level V/I sources carrying none. **Net candidates**:
  facts `nodes {} nodes`, excluding ground and `ase::facts_event_node`. Use the facts a dialog already
  has (`ase::netlist_facts_cached`) — never netlist because a dialog opened.
* **Verdicts per entry**: `ase::stimuli_verdicts ngspice $row $facts $state` → `{entry verdict sentence
  fix}` for ALL entries (0 = the table), and `ase::stimuli_banner` in `ase::precheck_banner_text`'s
  shape. The precheck already carries the worst through `stimuli_check`.
* **Readouts**: `ase::stimuli_readout ngspice $state $row <k> [nvec]` → `density flat_to points bytes
  flicker_bytes quantity estimate`. **`bytes` needs `nvec`** (for example the last run's
  `No. Variables`); without it the proc answers `{}` rather than guess. Every number is an estimate and
  must be worded as one (C8).
* **The seed sentence**: `ase::stimuli_seed_report` → `sentences` (0, 1 or 2, verbatim), `seeded`,
  `repeat`, `norepeat`. **The kill switch**: `ase::stimuli_kill_report` → `armed`, `killed`, `survive`.
* **Destroy the section on a type switch**: `evidence/trnoise.md` §10.1's warning about
  `chana_show`'s destroy list is live for this form.
* **The Arguments column** renders a row with a table as `noise={…}` today (`ase::ui::arg_summary`'s
  generic arm; `ports={…}` gets the same).
* **The `look` decision** by measurement (Stage 12's C5), and the `notrnoise` row's text (C11).
* **R9 labels** are R9-629 … R9-653, the kind names R9-628, the seed templates R9-625 … R9-627.

## What this task learned that binds later stages

1. **A `setup` contract is drawn by the window.** A headless task that needs a per-row table cannot add
   one; the `stimuli` contract plus the generalised `ase::analysis_setup_key` (one table per type,
   `twotables`) is the shape.
2. **A netlist-level card serves every analysis in the deck.** Anything scoped to one row must be given
   above that row and taken back below it — measured, not assumed.
3. **An ngspice current source's accept code can miss a breakpoint** (ISRC's 3-ulps test). A generated
   time-varying source that must redraw belongs on a V source.
4. **A generated card's name must begin with its device letter** — `ase_…` is an XSPICE card.
5. **`alter` does not survive `reset`.**
6. **`stddev()` of a constant is not 0** (6.7e-15): an absence row needs a tolerance, chosen orders
   below the presence it guards.
7. **A sentence that makes a claim about the simulator needs a both-binary row that checks the claim**
   (EE5, EE6) — the data is only as good as that row.

## Declared limits (also in the issue file)

* **`tran_points` does not know the noise timestep** — it decides checkpointing, and a checkpointed noisy
  transient (`stop after`/`resume` across `trnoise` breakpoints) is unmeasured, so it is unchanged
  (pinned by NX2's fourth term; S44 reds it). A noisy transient whose card alone is under the
  100,000-point floor is not checkpointed. **Named open for the driver.**
* A source inside an `.include` or a subcircuit: a caution. The digital-node refusal needs a measured
  inventory. Route 3 (a series V source) is not offered. A table-altered source ends the run as a zero
  `trnoise` (it outputs its `dc`).

## Hygiene

* **One runner at a time** (baseline → after → sabotage → final, each confirmed finished with a deadline
  waiter); no `pkill`, no `pgrep -f` kill; every suite command under `timeout`; the three risky decks on
  the fork only, under `timeout`.
* **Nothing under `~/.xschem/`** was written by anything this task added: ngspice runs had `HOME`
  pointed at scratch; the suite calls `test_sim_registry_isolate`. No `untitled~.sch` in the repo root.
* **Snapshots disarmed**: the pre-change copies, the work copy, the sabotage pristine copy, `sab.py`, the
  R9 generator and the owed backup are under
  `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/s13_1466/`. Logs kept in `…/scratchpad/s13/` (`meas/`, `base/`,
  `after/`, `final/`, `dev/`, `sab/`).
* **No background process of this crew is running.** The dev display (`:99`) is left up; the runners
  called its idempotent `start`.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**

`…/scratchpad` is `/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
