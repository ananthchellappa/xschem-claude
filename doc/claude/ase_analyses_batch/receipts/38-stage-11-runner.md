# Issue 1462 — ngspice has no `.step` card, so a bench could only ever run once

**Stage 11, task 1 of two — the campaign RUNNER (§11a) and the SAMPLER (§11b).**
Files I own and touched, and nothing else: **`src/ase.tcl`**,
**`tests/headless/test_ase_campaign_1462.tcl`** (new),
**`tests/headless/test_ase_core.tcl`**, **`tests/headless/test_ase_persist.tcl`**,
**`tests/run_regression.tcl`**, plus `doc/claude/issues/1462-*.md`,
`doc/claude/issues/NUMBERING.md` and this receipt.

**`src/ase_window.tcl` was NOT opened for writing.** Its md5 is byte-identical to
the snapshot taken before I started — `c7a08663205b92593872d600518b615c` — verified
after every sabotage restore. The campaign editor, the progress readout and §11c's
result table are task 2's.

No commit, no `git add`, no stash, no restore, no clean, no push.
`tests/run_regression.tcl` **not run** (issue 0990 — the driver's, solo). **No
simulation on any bench under `sky130A/` or `ihp-sg13g2/`**: every simulator run
below is a hand-written deck or an ASE-L-rendered deck under `/tmp/stage11` or the
suite's own scratch dir, against an explicit binary path. Nothing under
`~/.xschem/` was opened for writing, and **no `.spiceinit` was written anywhere but
in a scratch shard directory**.

**Floors:** `test_ase_campaign_1462` **NEW, 133 both arms, identical rows** (124 at first hand-back; the T1 repair added nine);
`test_ase_core` **638 → 638**; `test_ase_persist` **49 → 49** — no row count moved
in either, one *expectation* moved in both. Each file's own `AND RAISED` paragraph
is in the same diff.

---

## ⚠ THE HEADLINE: §11a's FIRST-RANKED MECHANISM IS FATAL ON THE BINARY MOST USERS HAVE

`PLAN.md` §11a and `APPENDIX` §4.2 rank `.param rv='var(myres)'` + a per-shard
`set myres=4700` in `<rundir>/.spiceinit` **first**, because it is the one
mechanism that makes `campaign/deck.spice` byte-identical for every shard. The
brief repeats it in its Scope and in its *already measured* list. Measured here,
2026-09-13, on both binaries:

| binary | answer |
|---|---|
| fork `ngspice-46+` | `@r1[resistance] = 4.700000e+03` |
| **apt 45.2**, `/usr/bin/ngspice` | `Undefined parameter [var]` → ` Expression err: var(myres)` → ` Formula() error.` → **`ERROR: fatal error in ngspice, exit(1)`** |

Traced, not guessed: `var()` and `vec()` are ngspice commit **`aa1242ac7`**,
*"Add new functions for .param expressions"*, **2025-10-16**, Giles Atkinson.
`git describe --tags aa1242ac7` → **`ngspice-45.2-50-gaa1242ac7`**;
`git tag --contains aa1242ac7` → **`ngspice-46`**. The implementation is the
`XFU_VAR` arm of `xpressn.c` and it did not exist in 45.2.

**The current Ubuntu LTS ships 45.2** (the preflight's own three-binary table), so
the plan's first-ranked mechanism is unavailable to the users this batch exists to
reach, and it does not degrade — **it kills the run at parse, rc 1, nothing
written**. Nothing in ASE-L emits `var()`, so no capability probe was needed.

**The honest replacement, and it is arguably better than what was asked for.**
Every axis re-renders the shard's own deck, and `campaign/deck.spice` is the
**nominal** deck — so `diff campaign/deck.spice shard-0007/deck.spice` is exactly
what is different about point 7. The variation is *visible* instead of hidden in a
sidecar the reviewer has to know to look at.

## ⚠ AND A SECOND ONE: `setseed` IN `.spiceinit` IS THE SIXTH ACCEPTED-AND-INERT CASE

The brief's *already measured* list says `setseed 12345` works where
`set rndseed=12345` does not, and names the measurement as taken **in `.control`**.
Asked in the place a shard runner actually wants it — the shard's own
`.spiceinit`, which is per-process and therefore per-point — it does nothing:

| where | apt 45.2 run 1 / run 2 | fork run 1 / run 2 |
|---|---|---|
| `<rundir>/.spiceinit` | `-1.52995e+00` / `6.545672e-01` | `-2.46074e+00` / `7.316806e-01` |
| **`.control`** | `3.950885e-01` / `3.950885e-01` | `3.950885e-01` / `3.950885e-01` |
| nothing at all | `7.995930e-01` / `-1.17401e-01` | `-1.14963e+00` / `-5.03270e-01` |

rc 0, **nothing on either stream**, and the `.spiceinit` column is
indistinguishable from the no-seed column. The mechanism is in the source:
`main.c` reads the start-up file at **`:1266-1330`** and calls `initw()` —
`srand((unsigned int) getpid()); TausSeed();`, `wallace.c:76-86` — at **`:1371`**,
*after* it.

**Sixth member** of `LEDGER.md`'s *ACCEPTED IS NOT HONOURED* rule, after
`measureprec`, `set interp`, the three `optran` spellings, the third `.dc` sweep
and `set rndseed=`.

## ⚠ AND THE SEED THE PLAN FORBIDS IS THE RIGHT ONE FOR A SHARD RUNNER

`APPENDIX` §4.4's generator rule is *"never emit `.option seed=<n>` for a
statistical campaign"*, because Trap B is that `eval_opt()` runs on **every**
re-parse — so a `.control` loop that `reset`s re-seeds to the same value before
every draw and every run is the same sample, silently. **A shard runner never
`reset`s.** Each point is its own process with its own deck and its own seed, so
the trap's precondition is absent. Measured with seeds 7/8/9 on both binaries, one
deck carrying a **netlist-level** `agauss` *and* an **interpreter-level** `sgauss`:

| seed | `@r1[resistance]` | `sgauss(0)` | second run | other binary |
|---|---|---|---|---|
| 7 | `9.068280e+02` | `-9.31720e-01` | identical | identical |
| 8 | `1.056375e+03` | `5.637512e-01` | identical | identical |
| 9 | `1.005625e+03` | `5.625111e-02` | identical | identical |

And the negative control that settles which mechanism to use: with
`setseed 12345` in `.control`, the interpreter's draw is `3.950885e-01` every time
while the **netlist's** `agauss` answers `1053.4`, `853.9`, `995.4` on three
consecutive runs — because a netlist-level draw happens at **parse** time, before
the control block runs at all. **The user's own `tb_bandgap` bench is precisely
that case** (`agauss(1.8, 'ABSVAR', 1)` in its `variables`), so `setseed` would
have left the one bench ⚖ R8 was ruled about unseeded and silent.

`seed` is already row `seed` of the option catalogue, so the per-shard seed is an
override of the `options` state key and **no new emit site was added for it**.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| `var()` is fatal on apt 45.2 and works on the fork | **MEASURED HERE**, both binaries, full transcript above; **and on upstream47** (works), so it is "45.2 is old", not "the fork added it" |
| `var()` first shipped in ngspice-46, commit `aa1242ac7`, 2025-10-16 | **READ from the ngspice tree here** — `git log -1`, `git describe --tags`, `git tag --contains`. The *behaviour* is measured above |
| `setseed` in `<rundir>/.spiceinit` seeds nothing; in `.control` it does | **MEASURED HERE**, both binaries, two runs each, plus the no-seed control |
| `main.c:1266-1330` reads the init file and `:1371` calls `initw()` | **READ** from the ngspice tree; it explains the measurement rather than standing in for it |
| `.options seed=<n>` per shard is reproducible, distinct per shard, identical across binaries, and reaches the netlist-level draw | **MEASURED HERE**, three seeds × two runs × two binaries |
| `setseed` does NOT reach a netlist-level `agauss` | **MEASURED HERE**, three runs per binary |
| `alter <inst> <param>=<v>` works at the top of `.control` and answers `Error: no circuit loaded` in `.spiceinit` | **MEASURED HERE**, both binaries |
| `altermod @<model>[<p>]=<v>` works | **MEASURED HERE**, both binaries — `@d1[id]` `1.690583e-28` → `5.670347e-01` |
| `.temp <v>` re-rendered per shard really moves the answer | **MEASURED HERE**, both binaries, `i(v1)` `-1.00000e-03` → `-5.05051e-04` on a `tc1=0.01` resistor |
| ⚠ `@r1[resistance]` does **not** move with temperature | **MEASURED HERE**, both binaries — it reads `1.000000e+03` at 27 °C and at 125 °C, so the readback a first implementation reaches for is the wrong one |
| a `.lib` section cannot be `alter`ed, so corners always shard | **TRANSCRIBED** from `APPENDIX` §4.4 (`expand_section_references()`, `inpcom.c:4530`). Not re-measured; nothing in this task depends on it being false |
| a third `.dc` sweep level is accepted and discarded in silence | **TRANSCRIBED** from `evidence/sweep-nesting.md`. Row DK8 asserts the runner cannot create one |
| baselines: core 638, persist 49/153, meas 113, preflight 235 | **RE-MEASURED HERE** before I edited anything; all four matched the brief |
| 104 committed `.state` files | **COUNTED LIVE** (`git ls-files`) and round-tripped live, 104 of 104, with a non-vacuity control in the same loop |
| a measurement value's printed precision differs between the binaries | **MEASURED HERE** — the same `max` measurement comes back `1.000000e+00` on apt 45.2 and `1.00000e+00` on the fork. See the corrections |

---

## What shipped

**Core (schema) — not one simulator word.** One state key `sweep`, `{}` by
default, in `ase::schema_keys` and the **ninth** member of `ase::omit_if_empty`.
Forty-four procs: the key accessors (`campaign_get`/`_enabled`/`_axes`/`_seed`),
the sampler (`mc_seed_norm`, `mc_next`, `mc_unit`, `mc_dists`, `mc_digits`,
`mc_draw`), the axes and odometer (`campaign_axis_label`, `campaign_axis_values`,
`campaign_points`, `campaign_count`, `campaign_max_points`), the adapter seam
(`campaign_axis_kinds` + its memo, `campaign_kind_entry`, `campaign_kind_reparse`,
`campaign_seed_option`, `campaign_seed_notes`, `campaign_point_lines`), the mode
(`campaign_mode`), the paths (`campaign_dir`, `campaign_shard_id`,
`campaign_shard_dir`, `campaign_index_path`, `campaign_deck_path`), **the shard
state** (`campaign_shard_state`, `campaign_apply`, `campaign_set_option`), the
refusals and the notes (`campaign_refusals`, `campaign_notes`), `index.tsv`
(`campaign_index_header`/`_row`/`_cell`/`_text`/`_write`/`_read`), the runner
(`campaign_prepare`, `campaign_shard_timeout`, `campaign_woke`, `campaign_wait`,
`campaign_exit`, `campaign_step`, `campaign_run`) and the load-time validator
(`campaign_schema_errors`).

⚠ **`campaign_step` RUNS NOTHING ITSELF** — see the addendum. It builds the
shard's state, writes the netlist into the shard, and hands both to
**`ase::run_deck`**, the one body `ase::run`, `ase::run_existing` and a script
paste already share. An earlier revision of this receipt described a proc that
composed and `exec`ed the command here; row **S12** of `test_ase_simreg_0931`
caught it and the addendum is the repair.

**Adapter (content).** Five hooks on `ase::register_backend ngspice`:
`campaign_axis_kinds`, `campaign_control_lines`, `campaign_seed_option`,
`campaign_seed_notes`, `campaign_axis_refusals`.

**One wiring site in `render_deck`**, and its position is a decision:

| what | where | why |
|---|---|---|
| this point's `alter` / `altermod` lines | **inside `.control`, above every analysis and above `optran`** | they need a LIVE CIRCUIT (`Error: no circuit loaded` from `.spiceinit`, measured), a command in that block governs what FOLLOWS it, and they change the circuit the operating-point strategy is about to solve |

Everything else needed **no** new emit site: a design variable is a `variables`
row, a temperature is the `temperature` key, a corner is a `models` row's
`section`, and the seed is an `options` row. **A shard is a STATE** — that is the
whole design, and it is why this task added one emit site instead of five.

---

## Both arms, before and after, from the `RESULT:` line

| suite | headless BEFORE | headless AFTER | display BEFORE | display AFTER |
|---|---|---|---|---|
| `test_ase_campaign_1462` | — (new) | **ALL PASS (124)** | — (new) | **ALL PASS (124)** |
| `test_ase_core` | ALL PASS (638) | **ALL PASS (638)** | — | — |
| `test_ase_persist` | ALL PASS (49) | **ALL PASS (49)** | — | — |
| `test_ase_meas_1443` | ALL PASS (113) | ALL PASS (113) | — | — |
| `test_ase_preflight` | ALL PASS (235) | ALL PASS (235) | — | — |
| `test_ase_dialogs` | ALL PASS (37) | ALL PASS (37) | 1 FAILED (384) | **1 FAILED (384)** |

**Neighbourhood, headless, every one ALL PASS and every one with a `RESULT:`
line:** `test_ase_sp_1452` 58 · `test_ase_converge_1459` 76 ·
`test_ase_conv_gui_1460` 45 · `test_ase_options_1437` 75 ·
`test_ase_optsheet_1441` 62 · `test_ase_effective_1442` 92 ·
`test_ase_predeck_1439` 78 · `test_ase_simcaps_0948` 211 ·
`test_ase_optier_0963` 109 · `test_ase_window` 56.

The one display red is **`G2sens`**, issue **1436**, standing before I started,
value unchanged at `{1 1 0 1 0 Entry Entry normal}`. It is the only failure on
either arm of any suite above, and it is not mine — `src/ase_window.tcl` is
byte-identical to the snapshot.

⚠ **Section EE starts real simulators on BOTH binaries, and both ran** on both
arms. **Every run quoted in this receipt printed a `RESULT:` line**; there is no
run whose absence of output I am reading as a pass.

`diff` of the new suite's two ok-lists is **empty**, 124 rows each — which is why
it is registered in `hcases` only, with the reason written into
`run_regression.tcl` beside the entry.

**`.state` byte identity: 104 committed files, 0 mismatches**, measured live
through `ase::state_load` → `ase::state_serialize`. **With its non-vacuity control
in the same loop**: the first file given a non-empty `sweep` re-serializes
**differently**, so the loop is comparing rather than agreeing with itself.

---

## The six ways a row fails to fail

1. **Fixtures that never disagree.** Every extractor has a control that must
   answer the null: `AX1` (no sweep), `DK1`/`DK1b` (a configured campaign changes
   the bench's own deck **not at all**), `NT1` (a bench with no campaign says
   nothing), `RF1` (and is refused nothing), `SH5b` (no seed, no seed row),
   `IX1b` (a switched-off measurement gets no column), `IX6b` (an index that was
   never written reads empty), `PD1b` (no pre-deck option, no file), `RF8b` (one
   point under the ceiling), `NT3b` (the collapsibility sentence is **withheld**
   when it would be untrue), `KN9`'s second leg. ⚠ **And one control was itself
   vacuous and had to be measured**: `KN2b`'s and `KN9`'s fixture backends
   originally declared their hooks as `[list apply {…}]`, which is **not callable**
   as `$h …` — the `catch` every hook reader carries swallowed it and both rows
   went green on an empty answer. Fixed to real procs, with a positive control
   that really emits.
2. **Position asked where the mechanism is last-writer-wins.** Inverted
   deliberately: `DK3` (inside `.control`, above every analysis), `DK3b` (above
   `optran`, because the strategy is about the circuit the `alter` just changed),
   `DK9` (nothing escapes `.endc`). m22 and m24 are the mutations.
3. **An extractor that returns nothing.** Every reader is total and answers a
   comparable value — `NOPROC`, `RAISED:…`, `NONE`, `-`, `{}` — and every call
   goes through the one `c_ans` wrapper.
4. **A sabotage missing from the generator.** Mine was short by **three**, and
   all three were real: **m13** (the unmeasured re-parse class), **m16** (adding a
   variable destroying the bench's others) and **m24** (a `statekey` axis also
   delivered as a command). Each is now a row that did not exist when I started.
5. **Two halves tested in different suites.** Section **EE** is the answer: the
   deck ASE-L renders is RUN as a four-point campaign on **both** binaries and the
   measurement column is checked against **physics** — the two points whose RC
   product is equal must agree and the other two must not, so a campaign whose
   axes silently failed to reach the deck gives four identical numbers and fails.
6. ⚠ **A one-directional row.** `RN2` asks *"is every promised directory there?"*
   and would pass with an extra one, or with an index row for a shard nobody made.
   **`RN4` and `EE3` ask the other way**: the set of shard directories on disk,
   the set of shard ids in `index.tsv` and the odometer must be **one set**. And
   `IX2b` pins the count in both directions. That is the direction issue 1457 was
   blind in, and for a campaign it is the sharpest one there is — a run that
   wrote N rows proves nothing about the shard it silently skipped.

---

## THE SABOTAGE CAMPAIGN — 36 mutations, 36 killed by name, 0 survivors


One runner at a time, confirmed with `ps` before each launch; restore is `cp`
from a pristine snapshot with an **md5 compare printed every time** —
`restore: OK` on **36 of 36**, `MISMATCH` **0 of 36**, no `NORESULT` and no
`ANCHOR-MISS`, and `src/ase.tcl`'s md5 after the last one is the pristine
`120dd5de529a425934eee3efc4a36633`. `src/ase_window.tcl` is
`c7a08663205b92593872d600518b615c` throughout — the snapshot value.
The table is a name+status diff, never a count. `camp` is
`test_ase_campaign_1462`; **`test_ase_core` was ALL PASS (638) under every one
of the 36**, which is the "no collateral damage" column and is why it is not
repeated per row.

⚠ **Three mutations survived the first pass and are marked ↺ below.** Each one is
a hole the first list could not see, each got a new row, and each now dies by
name — that is the *"your first list will be short; it has been for eight crews"*
rule collecting its due for the ninth time.


| # | what I broke | camp | rows that reddened |
|---|---|---|---|
| **m1** | the sample stream is seeded from the clock, not from the campaign | 4 FAILED (117 passed) | `SA1` `SA3` `SA13` `AX8c` |
| **m2** | the generator is not warmed up after seeding | 2 FAILED (119 passed) | `SA3` `SA6` |
| **m3** | `bounded` returns a value BETWEEN nom-delta and nom+delta | 1 FAILED (120 passed) | `SA5` |
| **m4** | an unknown distribution silently draws a normal | 1 FAILED (120 passed) | `SA8` |
| **m5** | a missing distribution parameter defaults to 0 instead of refusing | 2 FAILED (119 passed) | `SA9` `RF7` |
| **m6** | a sample is printed with 17 significant digits | 2 FAILED (119 passed) | `SA3` `SA12` |
| **m7** | the generator multiplier changes (48271 instead of 16807) | 1 FAILED (120 passed) | `SA3` |
| **m8** | the odometer runs the FIRST axis fastest | 7 FAILED (114 passed) | `AX4` `SH2` `SH4` `SH6` `IX2` `IX6` `RN6` |
| **m9** | a `draw` beats a literal `values` list | 1 FAILED (120 passed) | `AX10` |
| **m10** | an axis with no values is skipped instead of emptying the campaign | 1 FAILED (120 passed) | `AX9` |
| **m11** | the derived label for an instance axis drops the parameter | 1 FAILED (120 passed) | `AX6` |
| **m12** | **D34 BROKEN** -- a backend with no hook falls back to ngspice content | 3 FAILED (118 passed) | `KN3` `KN4` `KN5` |
| **m13** ↺ | an unmeasured re-parse class answers "cheap" | ↺ **1 FAILED (123 passed)** | first pass **ALL PASS — SURVIVED**; with the new row **KN2b**
| **m14** | `register_backend` stops dropping the axis-kind memo | 1 FAILED (120 passed) | `KN5` |
| **m15** | `collapsible` ignores the re-parse classes entirely | 4 FAILED (117 passed) | `MD2` `NT3b` `NT4` `NT5` |
| **m16** ↺ | adding a design variable REPLACES the bench's variable list | ↺ **1 FAILED (123 passed)** | first pass **ALL PASS — SURVIVED**; with the new row **SH2c**
| **m17** | every shard gets the campaign seed instead of base+N | 2 FAILED (119 passed) | `SH5` `RN7` |
| **m18** | the seed option is appended rather than replacing the existing row | 1 FAILED (120 passed) | `SH5c` |
| **m19** | a corner axis rewrites the models row's FILE instead of its SECTION | 2 FAILED (119 passed) | `SH4` `DK6` |
| **m20** | an out-of-range point silently becomes point 0 | 1 FAILED (120 passed) | `SH7` |
| **m21** | shard ids are not zero-padded | 11 FAILED (110 passed) | `SH1` `SH8` `IX2` `IX6` `RN2` `RN6` `RN7` `RN8` `RN8b` `RN13` `PD3` |
| **m22** | **the whole `alter` emit site is removed from `render_deck`** | 5 FAILED (116 passed) | `DK2` `DK3` `DK3b` `EE2/apt` `EE2/fork` |
| **m23** | a state with no point is given one anyway | 1 FAILED (120 passed) | `DK1b` |
| **m24** ↺ | a `statekey` axis is ALSO handed to the control-line hook | ↺ **1 FAILED (123 passed)** | first pass **ALL PASS — SURVIVED**; with the new row **KN9**
| **m25** | the temperature axis loses its `statekey`, so it emits as a control line | 2 FAILED (119 passed) | `SH3` `DK5` |
| **m26** | the shared-rundir refusal is dropped | 1 FAILED (120 passed) | `RF2` |
| **m27** | the point ceiling stops refusing | 1 FAILED (120 passed) | `RF8` |
| **m28** | the adapter's per-axis refusals are never consulted | 3 FAILED (118 passed) | `RF9` `RF10` `RN9` |
| **m29** | two axes may share one column name | 1 FAILED (120 passed) | `RF5` |
| **m30** | a tab or newline in a value is written into the TSV | 1 FAILED (120 passed) | `IX4` |
| **m31** | `index.tsv` gains no measurement columns | 3 FAILED (118 passed) | `IX1` `IX5` `IX6` |
| **m32** | the index is written once at the end instead of after every shard | 9 FAILED (112 passed) | `RN6` `RN7` `RN8` `RN10` `RN13` `EE1/apt` `EE2/apt` `EE1/fork` `EE2/fork` |
| **m33** | a never-run shard is asked for its rawfile path (and the directory is made) | 1 FAILED (120 passed) | `RN8b` |
| **m34** | `ase::sim_apply_choice` is dropped from the runner | 3 FAILED (118 passed) | `RN12` `EE2/apt` `EE2/fork` |
| **m35** | a Stop verdict from the callback is ignored | 2 FAILED (119 passed) | `RN8` `RN8b` |
| **m36** | the runner stops re-checking the refusals | 1 FAILED (120 passed) | `RN9` |

---

## ⚖ R9 — every new user-facing sentence, verbatim

**None of these is implemented in a widget** — `src/ase_window.tcl` is untouched —
but core and the ngspice adapter mint them, so they are mine to file and the
user's to ratify. `owed.sh add rule 1462`.

### The five axis-kind labels, and their field labels

```
Design variable        field: Variable
Temperature
Corner                 field: Model row
Instance parameter     fields: Instance, Parameter
Model parameter        fields: Model, Parameter
```

### The run-log sentences — said once, before the first shard starts

```
campaign: <n> points over <m> axes (<labels>), one simulator process per point
campaign: every axis in this campaign avoids a re-parse, so one process could run all <n> points; ASE-L runs one process per point, which keeps every completed point when a campaign is stopped
campaign: this campaign has no seed, so anything the simulator draws for itself will differ the next time it is run
campaign: seeded from <n>; shard N is seeded <n>+N, so a single point can be re-run on its own and give the same answer
```

The singular/plural variant is real: one axis with one value reads
*"campaign: 1 point over 1 axis (temp), one simulator process per point"*.

### The two seed caveats — the ADAPTER's clauses, under ASE-L's frame

```
campaign: transient white and 1/f noise sources are not covered by it: their generator is seeded from the process id, so a `trnoise` source draws differently on every run whatever the seed says
campaign: it is set as a deck option, so re-running a single point by hand from its own directory reproduces that point exactly
```

### The refusal sentences, each with its fix

```
this simulator declares no campaign axes, so a campaign cannot be generated for it
   fix: choose a simulator that does
this bench names no run directory, so a campaign would build its shards in the directory every other cell shares
   fix: set a run directory for this bench first
no analysis is enabled, so every shard would run nothing
   fix: enable at least one analysis
'<kind>' is not a campaign axis this simulator can deliver
   fix: choose one of: <the declared kinds>
axis <n> has no name, so its column could not be labelled
   fix: give the axis a name
two axes are both called '<label>', so one column would hide the other
   fix: rename one of them
axis '<label>' cannot be sampled: <the sampler's own reason>
   fix: check the distribution's parameters
axis '<label>' has no values, so there is nothing to sweep
   fix: give it a list of values or a distribution
this campaign has <n> points, and ASE-L runs at most <max>
   fix: shorten an axis, or split the campaign
'temp' is not a parameter in this simulator, so sweeping it as a design variable would run every point at the same temperature and say nothing
   fix: use a Temperature axis instead
'<name>' cannot be used in a generated command: a space, a quote or an '=' splits it
   fix: use the name as the netlist spells it
```

### Two more, added by the T1 repair — both said by the runner, per shard

```
campaign <shard-0007> did not start: <the reason ase::run_deck raised with>
campaign <shard-0007> ran longer than <n> s and was stopped; the campaign continues with the next point
```

The first is measured by row RN15 (three points, three sentences, each naming the
shard) with RN15b as its control; the second by RN11. Both ride the `add rule
1462` debt already filed — the debt is a pointer to this issue, so listing them
here is how they reach the user.

### And the sampler's three raises, which a form will surface

```
ase: unknown distribution '<kind>'
ase: distribution '<kind>' needs '<key>'
ase: distribution '<kind>' needs a number for '<key>'
ase: a distribution needs a positive sample count
```

⚠ **Three words I want the user's eye on specifically.** `normal`, `uniform` and
`bounded` are the distribution names core offers. They are deliberately NOT
ngspice's `agauss` / `gauss` / `aunif` / `unif` / `limit` — D34 keeps a simulator's
spelling out of core, and all five map onto the three
(`agauss(n,a,k)` = `normal` σ = a/k; `gauss(n,r,k)` = `normal` σ = n·r/k;
`aunif`/`unif` = `uniform`; `limit` = `bounded`). Whether the FORM offers the
simulator's own five as a convenience is task 2's copy and the user's ruling.

---

## Corrections to this brief and to `PLAN.md`

| | |
|---|---|
| **C1** | ⚠ **`campaign/deck.spice` CANNOT be "written once and byte-identical for every shard".** §11a's shape and the brief's Scope both require it; the only mechanism that delivers it is `var()`, which is **fatal on apt 45.2** (measured, with the upstream commit and tag). What shipped is the **nominal** deck at that path plus a per-shard deck, so `diff` names the variation instead of hiding it. Every axis kind is affected, not only design variables: `alter` in `.spiceinit` answers `Error: no circuit loaded`, a corner cannot be `alter`ed at all, and a temperature is a deck card |
| **C2** | ⚠ **§11a's `shard-NNNN/.spiceinit` "carrying that point's `set` lines" has no `set` lines to carry.** With `var()` off the table the file's content is Stage 7's pre-deck options and nothing else — which is still worth having, is still written per shard under ⚖ R2's four conditions, and is still absent when the bench sets no pre-deck option. Rows PD1/PD1b/PD2/PD3 |
| **C3** | ⚠ **§11d rule 7 and APPENDIX §4.4 are wrong FOR A SHARD RUNNER.** *"`setseed <n>` once"* and *"never emit `.option seed=<n>`"* are both about a one-process `.control` loop. In one process per point there is no `reset`, so Trap B cannot fire — and `.options seed=<base+N>` is the only one of the two that reaches a NETLIST-level `agauss`, which is the shape the user's own bench is written in. Measured both ways, three seeds, two binaries |
| **C4** | ⚠ **`setseed` in `<rundir>/.spiceinit` is inert** — the sixth *accepted-and-inert* case, and a new one. The brief's measured list has `setseed` working; it works **in `.control`** and nowhere else |
| **C5** | **§11a's temperature mechanism is already in the tree under another spelling.** The plan says `.options temp=<v>` re-rendered per shard; ASE-L renders `.temp <v>` from the `temperature` state key, and `.temp` goes through the same `cp_vset("temp", …)`. Overriding the key is the plan's mechanism with no new syntax — measured to move the answer on both binaries |
| **C6** | ⚠ **`@r1[resistance]` does not move with temperature**, on either binary, while the branch current does. A first implementation reaching for the obvious readback measures nothing and passes |
| **C7** | **The third-`.dc`-level refusal is not the runner's to make.** The brief lists it under my Scope. Nothing the runner emits can create one — it shards its temperatures rather than collapsing them onto the `dc` card — and the only place a third level can be ASKED for is the `dc` analysis form, which is `ase_window.tcl`'s and therefore task 2's. Row **DK8** pins that the runner cannot produce one |
| **C8** | ⚠ **`ase::rundir` CREATES the directory it is asked about**, and every sidecar path resolves through it — so merely asking a never-run shard for its rawfile path made the shard directory. A campaign stopped after two of four points left four directories, two empty and indistinguishable from a run that produced nothing. Row **RN8b**, sabotage **m33** |
| **C9** | ⚠ **`ase::campaign_run` must call `ase::sim_apply_choice`**, exactly as `ase::run_deck` does for the 2026-09-08 ruling. Without it a campaign runs whichever entry was last *selected*, not the one the bench names, and writes the results into this bench's shards under this bench's coordinates. Row **RN12** |
| **C10** | **An eleventh measured binary difference**: the same `max` measurement comes back `1.000000e+00` from apt 45.2 and `1.00000e+00` from the fork — seven significant digits against six. A campaign golden may not pin a measurement's printed string; row EE2 compares numerically for that reason |
| **C11** | **PLAN.md's ≈ +700 for `src/ase.tcl` is +1191** (44 core procs, 5 adapter hooks, one emit site, and the comment blocks that carry the eight measurements). The suite is **1377** lines; `test_ase_core` +11/−3, `test_ase_persist` +9/−3, `run_regression.tcl` +20/−2 |
| **C12a** | ⚠ **A CAMPAIGN IS NOT A FOURTH RUN DOOR, AND `PLAN.md` §11a's table implies it is.** Its *"shard runner"* column reads as a thing that starts processes; what ships hands every shard to `ase::run_deck`, the body the three existing doors share. The table's claims (abort keeps completed shards, an interrupted run has a non-zero exit code, progress is `k/N`, the deck is one artifact) are all still true — they are just true *because* a shard is an ordinary run, not because the campaign re-implements one. See the addendum |
| **C12b** | ⚠ **A binary that never answers the capability probe pays `ase::cap_budget_ms` — 30 s — PER SHARD.** `ase::run_deck` asks `ase::cap_report` on every run and a timed-out probe is not cached. Measured: 31,296 ms for the probe, 64,420 ms for a two-point campaign with a ONE-second shard budget. Harmless for a working simulator (0.014 s cold) and worth knowing before someone runs 200 points against a broken one |
| **C12** | ⚠ **`sim_plural` exists and the plan's sentences did not use it.** Four of the run-log sentences carry a count; three needed the singular form. Not a correction to the plan's *content*, but the kind of thing a crew re-invents |

---

## What I did NOT ship, and why

* **No change to `src/ase_window.tcl`.** md5 verified identical after every
  sabotage restore. The campaign editor, the progress readout and §11c's
  histogram / mean / sigma / yield / scatter table are task 2's.
* **No collapse DELIVERY.** `ase::campaign_mode` computes and reports it; taking
  it means emitting `render_deck`'s `.control` body N times, and a second emitter
  for that body would be the **ninth** copy of "what a `dc` analysis is". The
  decision, its measured inputs and its sentence ship now so the day the body can
  repeat itself, the mode has a caller. Rows MD1–MD4, NT3, NT3b.
* **No §11c statistics.** Histogram, mean, sigma, min/max, yield and the
  two-column scatter are all computed from `index.tsv`, which now exists; they are
  a surface and belong with task 2.
* **No parallelism.** One shard at a time, sequential. `campaign_step` is a step
  function precisely so a later caller can drive it from an `after` or a pool.
* **`tests/run_regression.tcl` not run** — the driver's, solo (issue 0990).

---

## Ledger

Backed up before the write: `/tmp/stage11/owed_backup_224815` and
`/tmp/stage11/owed_backup_pre_add_*` (`cp -a` of `~/.claude/xschem_owed`).

| | rule | look | suite |
|---|---|---|---|
| **before** | 174 | 66 | 10 |
| **after** | **175** | 66 | 10 |

* `add rule 1462` — printed `recorded`. The five axis-kind labels and their field
  labels, the four run-log sentences, the two adapter seed caveats and the eleven
  refusal sentences with their fixes. **The user's to answer**; nothing is blocked
  on it.
* **No `look` filed, deliberately.** This task ships **no pixels**:
  `src/ase_window.tcl` is untouched and every new string is data a widget will
  later read. PLAN.md §11's own *"Re-measure on the dev display"* paragraph names
  **the histogram and the `k/N` progress readout** — both are task 2's, and the
  histogram is explicitly *"a new drawing in this tree"*. Task 2 owes those
  eyeballs.
* **No `suite` debt filed, deliberately.** `test_ase_campaign_1462` has no GUI
  leg: **124 checks and identical `ok:` lists on both arms** (`diff` empty). A
  `:0` debt is owed by a GUI feature's suite, and this is not one.

One added, **none destroyed**. No `clear` of any kind was issued.

## Hygiene, stated rather than assumed

* **One sabotage runner at a time**, confirmed with `ps` before each launch; 36 +
  3 mutations, 39 restores, 39 `restore: OK`, 0 `MISMATCH`.
* **No `git checkout` / `restore` / `stash` / `clean` / `add` / `commit` / `push`.**
* **Snapshots archived at hand-over** — see the last section.
* ⚠ **One observation I am reporting rather than glossing.**
  `~/.xschem/simulations/.ase_probe/` has a **mtime inside my session window**
  (23:04). Its contents are the two subdirectories `p3508210_1` and `p3533197_2`
  / `p3533449_1`, all dated **16:21 and 17:42 — before my session began at
  22:48** — and **no `campaign/` directory exists there**. What touched the parent
  is ASE-L's own `ase::cap_workdir`, which creates and then removes a probe
  workdir whenever a simulator is registered or selected without an explicit
  rundir; two of my throwaway probe scripts under `/tmp/stage11` registered a
  binary without setting a scratch `HOME`. **Nothing of the user's was destroyed**
  and every campaign in this task ran under an explicit `rundir`. The suite itself
  is hermetic (`test_scratch` + `test_sim_registry_isolate`). Saying it out loud
  because a directory under `~/.xschem/` with a fresh mtime is exactly the thing a
  later reader should not have to reconstruct.

## Debts this task leaves

1. ⚖ **The sentences above** — `owed.sh add rule 1462`. **Blocking nothing.**
2. 🔭 **M5 stays open and is sharper now.** See below.
3. ⚠ **The collapse mode has a decision and no delivery.** Named above; it needs
   `render_deck` to be able to emit its `.control` body more than once, which is a
   change to the deck renderer and belongs in its own commit.

### ⚠ M5 — the multi-raw family: what the runner produces, and what a viewer would need

The brief is explicit that this is **a conversation, not an experiment**, so
nothing was invented. What is now true, concretely:

**What the runner produces.** `<rundir>/campaign/index.tsv` plus, per point,
`shard-NNNN/<cell>_ase.raw` and `shard-NNNN/<cell>_ase.plotmap` — **one rawfile
per point**, each a complete ASE-L results file of exactly the shape a single run
produces today (one plot per enabled analysis, `set appendwrite`, the sidecar
naming which row wrote which plot). Nothing about an individual shard is new; what
is new is that there are N of them and that `index.tsv` is the thing that says
what each one *is*.

**What a viewer would need, stated as questions rather than as a design.**

1. **Who owns the family?** Today `ase::attach_dbs` attaches *a* results file to
   the waveform window. A campaign has N. Is the family one attachment with N
   datasets, N attachments, or a new object? `doc/claude/specs/calculator.md` says
   v1 handles only the **single-raw multi-dataset** case, so the answer is not
   already in the tree.
2. **What is a curve's label?** A family curve is `v(out)` *at point 7*, and point
   7's identity is a **row of `index.tsv`** — several columns, not a number. A
   legend that says `shard-0007` is useless; one that says `myres=2k temp=125` is
   what a person needs, and nothing in the viewer takes a label from a sidecar
   today.
3. **Which axis is the family over?** With two axes the natural picture is a
   family per axis value, i.e. a two-level grouping. The viewer has no concept of
   a grouped family.
4. **Where do the statistics live?** §11c computes them **in Tcl** from
   `index.tsv`, not from the rawfiles, so the histogram is a view over a table and
   not over a waveform. That may make it the *campaign result table's* job rather
   than the viewer's — which would leave the viewer needing only (1) and (2).
5. **What does "open the results" mean after a campaign?** A single run attaches
   one raw. A campaign could attach nothing, the first point, the nominal point,
   or the family. This is a user-facing decision, not an implementation one.

**M5 stays OPEN**, with those five questions as its content and with the runner's
output now a fact rather than a proposal.

---

## Snapshots, disarmed at hand-over

`CREW_BRIEF.md`'s *DISARM YOUR SABOTAGE SNAPSHOTS* section: ten-plus stale
pristine copies of `src/ase.tcl` were sitting in `/tmp` from this batch's earlier
crews, each still restorable by a stale waiter. Mine are moved out of reach of
their own restore scripts:

```
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/ase.tcl                 (pre-change)
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/ase_window.tcl          (pre-change, untouched)
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/pristine_post_ase.tcl   (sabotage baseline, pass 1)
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/pristine_v2_ase.tcl     (sabotage baseline, after the T1 repair)
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/sab.sh                  (the runners, so none can be re-fired)
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/sab2.sh
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/sab3.sh
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/sab4.sh
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/pristine_v3_ase.tcl     (sabotage baseline, final)
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/mutate.py
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/mutate2.py
/tmp/stage11/ARCHIVED_DO_NOT_RESTORE/mutate3.py
```

**The campaign logs are KEPT** and are the evidence this receipt points at, and
nothing reads them automatically:
`/tmp/stage11/sab_results.txt` (36 mutations), `/tmp/stage11/sab_results2.txt`
(the three re-runs), `/tmp/stage11/sab_results3.txt` and `/tmp/stage11/sab_results4.txt` (the T1
repair's own two passes),
`/tmp/stage11/probe/` and `/tmp/stage11/m*/` (the ngspice
measurements), `/tmp/stage11/ok_headless.txt` and `/tmp/stage11/ok_display.txt`
(the two arms' row lists), `/tmp/stage11/owed_backup_*` (the ledger backups).

⚠ **If this crew is ever woken after collection**: check `git status` and
`git log` before touching anything. The tree will have moved on, another crew is
probably live in it, and the single most damaging thing a finished crew can do is
tidy up.

---

# ADDENDUM — what T1 caught, and the route I took

**Reported by the coordinator after this task was handed back**, against a tree
holding my work uncommitted: `test_ase_simreg_0931` row **S12** red,
`{2 0}` against `{1 1}`.

```
FAIL: S12 STRUCTURAL the running session's choice is put in force once, in the one
body all three run doors share, below the gate that refuses without looking at a
simulator and above everything that resolves one -> {2 0} (exp {1 1}) : FAIL
```

**The correction was right about the defect and the fix broke the invariant that
states it.** A campaign really must not run whichever simulator happened to be
selected last — my row RN12 measures that — but `ase::campaign_run` bought it
with a **second** `ase::sim_apply_choice $state`, and S12 counts those lines and
asserts there is exactly **one**, in `ase::run_deck`, between the in-flight
refusal and the first resolver. `test_ase_simreg_0931` was not in the
neighbourhood list I ran, which is how it reached the coordinator instead of me.

## ⚠ WHAT I GOT WRONG, STATED PLAINLY

I treated "the campaign needs the bench's simulator applied" as a **requirement to
satisfy** and reached for the nearest call. The question I did not ask is the one
S12 is written in: **is a campaign a new run door, or is it a caller of the
existing one?** It is a caller. Every shard runs a deck; `ase::run_deck` is the
body `ase::run`, `ase::run_existing` and a script paste already share; a campaign
that composes and `exec`s its own command is a **fourth door with no gate on it**,
and every guard that body carries had to be either re-implemented or silently
skipped. I had re-implemented four of them and skipped seven without noticing.

## The route: **1 — every shard goes through `ase::run_deck`**

Not because the invariant said so, but because it made the code smaller and the
shard better. `ase::campaign_step` no longer composes a command, no longer
`exec`s, no longer writes a log, no longer deletes the five append-target
sidecars, no longer writes the ⚖ R2 pre-deck file and no longer applies the
session's choice. It builds the shard's state, writes the netlist into the shard,
and hands both to `run_deck`:

```tcl
set id [ase::run_deck $sst $nlpath [list ase::campaign_woke $tok]]
set rc [ase::campaign_wait $id $tok [expr {[ase::campaign_shard_timeout] * 1000}]]
```

**Everything a single run gets, a shard now gets**, by construction rather than
by my remembering: the in-flight lock, the pre-flight gate, the casemode
pre-check, the co-simulation build, the operating-point tier report, the
capability report, the five artifact deletions, the ⚖ R2 pre-deck file with its
four conditions, the run log with header and footer, the result probe, and the
stale-entry sentence. **A shard directory is now literally a run directory**,
holding `<cell>.spice`, `<cell>_ase.spice`, `<cell>_ase.log`, `<cell>_ase.raw` and
`<cell>_ase.plotmap` under the names a single run gives them — which is row
**RN3**, rewritten, and row **EE3b**, new, on both real binaries.

**Nothing blocked it.** The one thing routing through the shared body costs is
**per-shard chatter**: `run_deck` and `run_done` say four to eight sentences per
run, so a 200-point campaign says a thousand lines where my own runner said the
campaign's four once. That is honest — N runs are N runs — but it is a real
surface cost and it belongs to task 2's progress readout, which will want a way
to quiet it. **Recorded as a debt below rather than solved here.**

## And the second thing: the bare `catch` is gone, and the one that remains is measured

`catch {ase::sim_apply_choice $state}` does not exist any more — there is no call
to catch. The coordinator's point stands anyway and I have applied it to the
`catch` that **is** left, around `ase::run_deck` in `campaign_step`:

> *"If that is the reason, measure it: make a stale entry, show that `run_cmd`
> really does say it per shard, and pin that with a row."*

**Measured.** Row **RN15** registers an entry pointing at a path that does not
exist, runs a three-point campaign, and asserts **three** rows of `-1` in
`index.tsv` and **three** sentences, one per shard — captured by replacing
`::ase::echo` and counting, not by eyeballing a log. Row **RN15b** is its control:
the same campaign against a runnable stand-in says that sentence **zero** times.
The reason for the catch is now in the comment *and* in a row: a shard that cannot
start must be a row rather than the end of the campaign, because the alternative
is losing every point behind the first bad one.

## ⚠ THREE THINGS THE REPAIR MEASURED THAT NOTHING ELSE WOULD HAVE

1. **`ase::wait` is an unbounded `vwait`, and for a campaign that is not good
   enough.** A single run's wait is bounded by the user's own Stop button; a
   campaign's is not, and one wedged shard costs every point behind it. So
   `ase::campaign_wait` races the wait against an `after`, kills the overrunning
   process by the id this campaign started, and returns **124** — the code
   `timeout` and `run_suites.sh` already read as TIMEOUT. Row **RN11** drives it
   with a stand-in that sleeps thirty seconds against a **one-second** budget and
   measures the exits *and* the wall clock; **RN11b** asserts nothing was left
   running.
2. **A killed shard leaves its in-flight lock behind, and the next campaign over
   the same run directory is then refused by a run nobody is waiting for.**
   `ase::run_done` is what clears the lock and it fires on EOF, which a killed
   process does not always deliver promptly. Found the hard way: RN15b and PD1
   both went red for it. `campaign_wait` now clears the lock it abandoned.
3. ⚠ **A binary that never answers the capability probe pays
   `ase::cap_budget_ms` — 30 seconds — on EVERY shard.** `run_deck` asks
   `ase::cap_report` per run and a probe that times out is not cached. **Measured:
   31,296 ms for the probe and 64,420 ms for a two-point campaign whose shard
   budget was one second.** That is ASE-L's existing behaviour, not this timeout's,
   and it only bites a simulator that is already broken — but it is why RN11's
   stand-in answers the probe instantly and hangs only on a campaign deck, and it
   is worth a later look: **thirty seconds times N points** is a long time to
   spend finding out the same thing N times.

## ⚠ And one more way a row failed to fail, found in this pass

Row **RN5** read the shard decks with a bare `open` inside an `apply`. When the
deck's name changed from `deck.spice` to `<cell>_ase.spice`, the read **raised** —
and `--nogui --pipe` exits 0 on an uncaught mid-script Tcl error, so the suite
**died after RN4 and printed no `RESULT:` line at all**. Measured, in this pass,
on exactly the failure mode the brief names. RN5's reads now go through a total
`rn_slurp` that answers `NOFILE:<name>`, and the row asserts the file was found
before asserting anything about its contents.


## Verification after the repair, both arms, from the `RESULT:` line

| suite | headless | display |
|---|---|---|
| **`test_ase_simreg_0931`** — the suite that caught it | **ALL PASS (117)** | **ALL PASS (117)** |
| `test_ase_campaign_1462` | **ALL PASS (133)** | **ALL PASS (133)** |
| `test_ase_core` | ALL PASS (638) | ALL PASS (638) |
| `test_ase_persist` | ALL PASS (49) | ALL PASS (153) |

`diff` of the campaign suite's two ok-lists is **empty**. The suite went
**124 → 133**: RN3 rewritten for the run-directory layout, RN5 made total, plus
**RN0** (the shipped 1800 s budget, pinned before the section shortens it),
**RN11** (a shard that never finishes → 124, and the campaign carries on),
**RN11b** (nothing left running), **RN15** / **RN15b** (the unrunnable entry, per
shard, with its control), **RN16** (the shipped budget is back in force) and
**EE3b** (a real shard directory holds all five artifacts) — and then **RN9b**
(a campaign whose nominal deck cannot be rendered leaves no directory either) and
**RN11c** (a killed shard releases its lock), both added by the repair's own
sabotage.

⚠ **And the RN section now runs on a SHORTENED budget on purpose**, with the
shipped one asserted either side of it (RN0, RN16). Every stand-in finishes in
milliseconds, so ten seconds is generous — and it makes a broken wake-up a fast,
**named** failure instead of a suite that sits at the real budget until an
external `timeout` cuts it off. A `NORESULT` is not a result, and a sabotage that
can only produce one is a sabotage that tells you less than it should.

## Debts this repair adds

1. 🔭 **Per-shard chatter belongs to task 2.** `ase::run_deck` and
   `ase::run_done` say four to eight sentences per run — which program is
   starting, what a Stop would cost, the pre-deck file and what it shadows, the
   operating-point tier, the capability report, the measurement report, the
   completion line. For one run that is the feature; for a 200-point campaign it
   is a thousand lines in the CIW and the action log. **Nothing is wrong with any
   of them** — they are true, per run, and a campaign really is N runs — but the
   campaign's own four sentences are buried by them. Task 2's progress readout is
   where a quiet mode belongs, and it should be a *campaign* decision rather than
   a per-run one, because the run body must stay as loud as it is for a single
   run.
2. ⚠ **The capability probe is paid per shard when it cannot be answered.**
   Measured above: 31,296 ms for one probe and 64,420 ms for a two-point campaign
   whose shard budget was one second, because a timed-out probe is not cached.
   Harmless for a working simulator (0.014 s cold, and then free) and a real cost
   for a broken one. Not fixed here: it is `ase::sim_capabilities`' caching
   policy, not the campaign's, and changing what a failed probe caches would
   change behaviour for every run in the program.
## The repair's own sabotage — 11 mutations over two passes, 11 killed

Baselines: `pristine_v2_ase.tcl` (pass 3) and `pristine_v3_ase.tcl` (pass 4);
`restore: OK` on every one, `MISMATCH` **0**, `src/ase_window.tcl` untouched
throughout.

| # | what I broke | camp | rows that reddened |
|---|---|---|---|
| **n1** | a SECOND `ase::sim_apply_choice` comes back into `campaign_run` | ALL PASS (131) | **`S12` of `test_ase_simreg_0931`** — the invariant itself, and the only red |
| **n2** | the shard is launched without the wake-up callback | **NORESULT** (killed at the 900 s cap) + `RN6` `RN7` `RN8` `RN13` | every shard pays its full budget; the named rows red before the cap and the RUNTIME is the second tell |
| **n3** | the wait loses its deadline | 1 FAILED (130) | `RN11` |
| **n4** | a stall returns 0 instead of 124, so it looks like success | 1 FAILED (130) | `RN11` |
| **n5** ↺ | the overrunning process is not killed | ↺ **1 FAILED (132)** | first pass **SURVIVED**; with RN11b's identifier repaired, **`RN11b`** |
| **n6** ↺ | the abandoned run keeps its in-flight lock | ↺ **5 FAILED (128)** | first pass **SURVIVED**; with `RN11c` added, **`RN11c` `RN12` `RN13` `RN15b` `PD1`** — five rows, which is how load-bearing it turned out to be |
| **n7** | a shard that cannot start ends the whole campaign | 1 FAILED (130) | `RN15` |
| **n8** | the netlist is written outside the shard | 4 FAILED (127) | `RN2` `RN3` `EE3b/apt` `EE3b/fork` |
| **n9** | `campaign_prepare` makes the directory before it renders | 1 FAILED (132) | `RN9b` |

⚠ **n1 IS THE ROW THAT MATTERS MOST HERE.** It is the defect the coordinator
found, reproduced deliberately, and the only thing that notices is `S12` — which
is the whole argument for a structural invariant. A behavioural row cannot see
where a line sits.

### The two that survived, and what they taught

* **n5 survived because RN11b was VACUOUS.** It asked `ps -C sh` for a process
  that had `exec`ed away — `sh` is exactly what is not there — so it answered 0
  whether or not the kill happened. ⚠ **And repairing it exposed a second defect
  in the row**: a fixed `sleep 37` also matches a sleeper left by an *earlier run
  of this same suite* that the kernel has not reaped, so the row failed twice and
  passed once on identical code. The duration is now derived from the process id
  and the row waits up to two seconds for the reap. **Three consecutive runs, 133
  each.** A flaky row is worse than no row.
* **n6 survived because the fix I wrote had removed its own witness.** The lock
  is only stranded when the killed process leaves a grandchild holding the pipe —
  and I had changed the stand-in to `exec sleep`, which is precisely the shape
  that does *not*. `RN11c` adds the grandchild stand-in back as a second
  stand-in and asserts the three things that matter: the shard exits 124, the
  lock is released, and a **second campaign over the same directory is not
  refused by a run nobody is waiting for**.

Both are the same lesson from opposite ends: **a fix and the row that proves it
must not be written from the same assumption.**

### ⚠ And a third thing the repaired rows did wrong, found by looking

Making the sleeper's duration unique, I made it **long** — up to eighty minutes —
and RN11c's stand-in is the grandchild shape whose sleeper is deliberately *not*
killed. So every run of this suite left two processes lying about for the rest of
the hour, and a sabotage that removes the kill left four. **Measured: ten of them
were still running when this was noticed.** A *fractional* second
(`47.<pid mod 1000>`) buys the same uniqueness and is gone in under a minute.
Verified: three consecutive runs at 133, and `ps` clean afterwards. A suite that
litters the machine it runs on is a suite nobody will want to run.

### The neighbourhood, re-run after the repair

`test_ase_preflight` 235 · `test_ase_sp_1452` 58 · `test_ase_converge_1459` 76 ·
`test_ase_conv_gui_1460` 45 · `test_ase_dialogs` 37 · `test_ase_options_1437` 75 ·
`test_ase_optsheet_1441` 62 · `test_ase_effective_1442` 92 ·
`test_ase_predeck_1439` 78 · `test_ase_simcaps_0948` 211 ·
`test_ase_optier_0963` 109 · `test_ase_window` 56 · `test_ase_meas_1443` 113 —
**every one ALL PASS with a `RESULT:` line.** On the display arm
`test_ase_dialogs` is **1 FAILED (384)**, `G2sens`, issue **1436**, value
unchanged at `{1 1 0 1 0 Entry Entry normal}` — the standing red, and still not
mine.

⚠ **`test_ase_simreg_0931` is now in the list I run.** It was not, which is why
S12 reached the coordinator instead of me. The lesson is not "run more suites" —
it is that a change which adds a **call site** of anything can be caught by a
STRUCTURAL row in a suite whose subject looks unrelated, and `grep -rn` for the
proc you are about to call is cheaper than finding out afterwards.

**104 committed `.state` files still round-trip byte-identically**, 0 mismatches,
control disagreeing — re-measured after the repair.

## Hygiene for this pass

* **One sabotage runner at a time**, confirmed with `ps` before each launch.
  Passes 3 and 4: 11 mutations, 11 restores, **11 `restore: OK`, 0 `MISMATCH`**.
* ⚠ **One thing I did that I would not do again.** Sweeping leftover sleepers I
  reached for `pkill -f 'sleep 37'` — and `-f` matches the *whole command line*,
  so it matched **my own shell**, whose command line contained that string, and
  killed it (exit 144). Nothing of the user's was touched and nothing outside my
  own session could have been, but the lesson is the standing rule's: a pattern
  kill is not a kill of *your* process. The sweep that replaced it walks
  `ps -e -o pid=,args=` and kills only a process whose argv is exactly the
  sleeper.
* `tests/run_regression.tcl` **still not run** — the driver's, solo (issue 0990).
* **`src/ase_window.tcl` still byte-identical** to the snapshot:
  `c7a08663205b92593872d600518b615c`.
