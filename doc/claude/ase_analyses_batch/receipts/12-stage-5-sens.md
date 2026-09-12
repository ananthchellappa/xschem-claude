# Stage 5 — `sens`, DC sensitivity

**One commit, issue 1428, and the last of Stage 5.** `tf` is issue **1426** (commit
`1e8e236e`); `pz` is issue **1427** (commit `326fe7b1`). Nothing here touches either.

**Floors:** `test_ase_core` 376 → **391** · `test_ase_simcaps_0948` 175 → **180** ·
`test_ase_preflight` 177 → **192** · `test_ase_dialogs` display 278 → **285** (headless 37
unmoved). **Forty-seven sabotage runs over forty-two distinct respellings.** Thirty-six reddened a
named row on the first attempt; **two killed a suite** and bought two hardenings (S12, S10);
**three survived** and bought three rows (S35, S37, S38); **one survived by contract** and is
not a hole (S39). Every one of the six exceptions was re-run against the row or hardening it
bought (S10r, S12b, S35r, S37b, S38b) and reddens.

---

## What the stage was for

`sens` was one of the seven entries Stage 2 registered so the four-state grid could show
that the analysis exists:

```tcl
sens [dict create label sens baseline 1 registered 1 emit {{role probe tmpl {sens}}}]
```

No `fields`, no `emitorder`, no `role analysis` card — so `ase::analysis_renderable`
answered 0, the cell read `blocked/unrenderable`, the Enable checkbutton was disabled and a
hand-enabled row was refused at the gate. The user could see that ngspice will tell them how
much an output moves when each device and model parameter is perturbed — the one analysis in
this stage that ADE-L lists and gives no computed picker for — and could not ask for it.

---

## What shipped

### `src/ase.tcl` — the registry entry (inside `ase::backend::ngspice::analysis_types`)

```tcl
sens [dict create \
  label sens  baseline 1  registered 1  emitorder 70 \
  needs  {sens_out sens_filters cider_klu} \
  fields {{name out     kind outvar required 1 label {Output}} \
          {name filters kind filter required 0 label {Parameters}}} \
  emit   {{role analysis tmpl {sens @out @filters? dc}}} \
  results {table {kind params}} \
  plots  {{select {Sensitivity Analysis} role table results table \
           label sens paramname ::ase::backend::ngspice::sens_param_kind}}]
```

(inside the `return [dict create …]` of `ase::backend::ngspice::analysis_types` — cite the
proc, the line is a hint: `src/ase.tcl:~15342`.)

**DC only.** The `ac` mode is Stage 6's, and that is a scope line rather than a convenience —
see *Neither of the plan's two rules ships* below.

### `src/ase.tcl` — one new adapter proc, **content** (D34–D37)

| proc | what it answers |
|---|---|
| `ase::backend::ngspice::sens_param_kind {name}` | `{model <instance> <parameter>}`, `{instance <name>}` or `{}` — for `r1:r`, for the rawfile's own `v(r1:r)`, for the hierarchical `r.x1.ra:r`, and case-insensitively |

Reached through the `paramname` key of the `plots` row, which is opaque to core. Like
`pz_root_kind` and unlike `out_decompose`, it is **not** registered as a
`register_backend` hook: it answers about one analysis's results, and nothing in core asks
that question yet.

### `src/ase.tcl` — two new predicates in `ase::needs_eval`

`sens_out` (fatal **or** blocked→caution ×2) and `sens_filters` (blocked→caution). Both are
ordinary Stage 4 machinery; no new mechanism was added. `sens_out` reaches ngspice's output
syntax through **`tf`'s own `out_decompose` hook**, reused rather than respelled — which is
what a registered hook is for.

### `tests/headless/test_ase_dialogs.tcl` — section **G2sens**, seven widget rows

The half `test_ase_core` cannot assert. `sens` is the **first form in this tree whose second
field is optional AND omitted from the line** when it is blank — `tf`'s two fields are both
required and `pz`'s optional four all carry defaults — so it is the first place a widget row
can say that an empty box produces a *shorter* deck line rather than a padded one. Display
arm only.

### Comment blocks

A `sens` block above `return [dict create …]` carrying the AC-scope argument with both
measured defects and their source reasons, the `{build}` decision, the eleven-line output
transcript, the filter transcript followed end to end through `render_deck`, the hierarchy
measurement, the `r1_temp` collision, the `viewrank` measurement and its two extra reasons,
the both-modes-one-Plotname trap, the no-capitals-to-fold measurement and the
casemode/filter refutation; headers on `sens_param_kind` and on both predicates. The
registry's "THE SIX ANALYSES … CANNOT YET DRIVE" header is corrected to **FOUR**, with a
note that a prose count beside a counted row is the count that goes stale — it read SIX
through `pz`'s commit while row EM7 correctly read five.

**`src/ase_window.tcl` is untouched.**

---

## Every measured fact this rests on, and where it was measured

All ngspice measurements **2026-09-12**, scratch decks under `/tmp/sensprobe`, never a bench
under `sky130A/`. Binary 3 is `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(`ngspice-46+`); binary 1 is `/usr/bin/ngspice` (`ngspice-45.2`). **Both were run for every
line below and the two agreed on every one.**

### 1. ngspice does not validate the output, and fills a ~90-row table anyway

With this tree's own `sim_status` guard wrapped round the analysis:

```
sens v(mid) dc        -> rc 0  r1 -1.38889e-04  r2 2.777775e-05
                               r3  2.777775e-05  v1 8.333333e-01   (right)
sens v(nosuchnode) dc -> rc 0  EVERY vector -0.000000e+00
sens v(in,nosuch) dc  -> rc 0  v1 1.000000e+00 and the rest 0 -- the missing
                               REFERENCE is silently ground
sens i(Vsense) dc     -> rc 0  r1 -2.77778e-08 … v1 1.666667e-04   (right)
sens i(R1) dc         -> rc 0  every vector 0.000000e+00
sens i(C1) dc         -> rc 0  every vector 0.000000e+00
sens i(L1) dc         -> rc 0  every vector 0.000000e+00
sens i(I1) dc         -> rc 0  every vector 0.000000e+00
sens i(nosuchsrc) dc  -> rc 0  every vector 0.000000e+00
sens x(mid) dc        -> rc 1  Error: Syntax error: voltage or current expected.
sens v mid dc         -> rc 1  Error: Syntax error: '(' expected after 'v'
```

Six of the eleven are a run that **succeeded** with a table of zeros. That is worse than
`tf`'s three numbers, because a table reads as a result.

⚠ **`sens` is BETTER than `tf` on the last line, and the argument may not be copied.**
`tf v mid V1` blames the *source* with an empty name; `sens v mid dc` names the output and
the missing parenthesis. The verdict is still `fatal` — the guard's `quit 1` fires and
nothing after it in `.control` runs — but ASE-L's sentence is saying the same thing earlier,
not making up for a misleading message.

### 2. A filter that matches nothing leaves the run with NO PLOT AT ALL

```
sens v(mid) r1 dc        -> $plots `const sens1`, one vector: r1
sens v(mid) r1 nosuch dc -> $plots `const sens1`, one vector: r1
                            -- the bad filter is DROPPED IN SILENCE
sens v(mid) nosuch dc    -> $plots `const`, $curplotname `constants`, rc 0
sens v(mid) zzz* dc      -> the same
```

Followed through this tree's own renderer — `render_deck` against a scratch library with an
explicit `rundir` (`/tmp/sensprobe/e2e2`), one enabled row
`{type sens enabled 1 out v(mid) filters nosuchdev}`, on **both** binaries:

```
rc 0, and the only record in <cell>_ase.raw is
  Title: Constant values / Plotname: constants / No. Variables: 12
ase::raw_content_verdict -> ok 0  constants 1  plotname constants
```

That is the artifact the whole of `tests/headless/test_ase_preflight.tcl` is about, reached
from a direction nobody had walked. ⚠ **And defence (c) catches it and guesses the cause
wrong**: its sentence reads *"the analysis did not run (typically a `.save` of a node the
circuit does not have)"*. That is what makes defence (a) worth having here.

### 3. The vector namespace is hierarchical

`V1 / X1 / R9` at top level, `Ra` and `Rb` inside `.subckt divider`. The **complete**
bare-name set of the sens plot, on both binaries:

```
r.x1.ra   r.x1.rb   r9   v1
```

A subcircuit device is `<letter>.<instance path>.<name>`; the subckt **call** `x1` produces
nothing at all.

### 4. The underscore form collides in ngspice itself

One deck carrying `R1` and `R1_temp`; `display` after `sens v(mid) dc`:

```
r1_temp             : voltage, real, 1 long
r1_temp             : voltage, real, 1 long
```

Once as `R1`'s instance `temp` parameter, once as `R1_temp`'s own principal resistance. Two
different quantities, one name, one plot.

### 5. `xschem raw read` cannot find a `sens` plot

Against a raw carrying an `Operating Point` plot and a `Sensitivity Analysis` plot, through
`./src/xschem --nogui --pipe -q --nolog`:

```
xschem raw read both.raw sens                   -> raw_read(): no useful data found
                                                   ... or no "sens" analysis     -> 0
xschem raw read both.raw op                     -> sim_type=op                   -> 1
xschem raw read both.raw {Sensitivity Analysis} -> sim_type=Sensitivity Analysis -> 1
```

### 6. There are no capitals to fold

The same op+sens deck written by both binaries: the `Variables:` blocks are
**byte-identical** — `v(r1)`, `v(r2)` — and the only difference anywhere in either header is
the `Command:` version line.

### 7. The AC mode's two defects, and that neither reaches DC

```
sens v(mid) r1 ac lin 5 1k 5k -> 1.000000e+03  8.000000e+05  6.400000e+08
                                 5.120000e+11  4.096000e+14        (each x800)
.options klu + sens v(mid) ac dec 1 1k 10k -> rc 139, SIGSEGV
.options klu + sens v(mid) dc              -> rc 0, and the numbers are
                                 BYTE-FOR-BYTE the sparse ones
```

Confirmed in source as well as by measurement: `count_steps`' `SENS_DC` arm
(`cktsens.c:872`) returns n=0 and s=0 and `sens_sens` sets `freq = 0.0` for the single
point, so the value `inc_freq` computes is never used; and `cktsens.c:97-105`'s commented-out
guard would have refused **all** sensitivity under KLU, DC included.

### 8. End to end, on both binaries

`render_deck` against a scratch library with an explicit `rundir` (`/tmp/sensprobe/e2e`), a
state carrying `{type op enabled 1}` and
`{type sens enabled 1 out v(mid) filters {r1 r2 r3}}`. The deck emits

```
op … remzerovec … write …/senscell_ase.raw
sens v(mid) r1 r2 r3 dc … remzerovec … write …/senscell_ase.raw
```

**rc 0 on the fork and rc 0 on apt 45.2**, two `Plotname:` records in one raw, byte-identical
headers. Read back through ASE-L's own readers, identically from both:

```
ase::cap_raw_plots       -> {{Operating Point} 1 {v(in) v(mid) v(out) v(sns) i(v1) i(vsense)}}
                            {{Sensitivity Analysis} 1 {v(r3) v(r1) v(r2)}}
ase::raw_content_verdict -> ok 1 constants 0 appended 0 plotname {Operating Point} …
ase::plot_sim_type       -> op   (sens has no viewrank, so op still wins)
```

---

## The `{build <proc>}` decision, and its justification

**Decision (a): ship without composition, as `tf` and `pz` did. `ase::analysis_expand` is
unmodified and every existing slot row is untouched.**

The `tf` crew found (C43) that `PLAN.md` §1c specifies `{build <proc>}` as the escape an
adapter uses for a slot it must compose, that **Stage 1 shipped `@x`, `@x?` and `@x!` and no
`build` arm at all**, and that `sens` is the type that wants it — and left the decision here.
It is not built, for three reasons in order of weight:

1. **A measurement, not the cost.** The escape's only gain is a **structured** output picker
   (`{outkind outnode outref outsrc}` → `v(a,b)`). But
   `ase::backend::ngspice::out_decompose` — registered as a hook, shipped by issue 1426,
   pinned by section TV of `test_ase_simcaps_0948.tcl` — **already takes `v(a)`, `v(a,b)` and
   `i(src)` apart again**, exactly and case-insensitively. The structured data is therefore
   recoverable from the one verbatim token whenever a surface wants it. Composition buys
   nothing a reader does not already give, and `sens_out` is written on that reader.
2. **It would be a Stage 1 grammar change with one consumer, for a surface that does not
   exist.** `ase::ui::resulttable` and the `.sens` picker are Stage 5b's; adding a grammar arm
   in the last commit of Stage 5 to reach them would be shipped mechanism with nothing pulling
   on it — which is the shape `CREW_BRIEF.md` warns about in the adapter-manifest paragraph.
3. **The blast radius is the whole registry.** Every shipped `emit` template and every slot
   row in `test_ase_core` section EM would have to be re-verified, plus its own sabotages,
   to buy a field split in one entry.

**And `@modeargs` is the other half of the answer.** The brief asked me to note that
`@modeargs` being a free slot is what forces the plan's `lin` restriction to be a `rule`
rather than a field constraint — and it is, exactly: a free slot has no declared value set
for a constraint to attach to. **This entry has no `@modeargs` at all.** The DC case is the
**literal** token `dc` in the template, so there is nothing free to constrain; and when Stage
6 adds the mode it can declare the sweep field `values {dec oct}` and have the restriction be
a **field constraint the form cannot offer** rather than a rule the form offers and then
refuses. That is a better answer than the plan's, and it is available only because the mode
is modelled rather than free. So **neither of `PLAN.md`'s two `rules` ships**, and that is the
shape changing rather than work being postponed.

---

## What PLAN.md and the APPENDIX said that the tree refuted

This is Stage 5's fourteenth through seventeenth corrections (`tf` took C43–C47, `pz` C48–C51).

### C52 — `{build <proc>}` is not built, and the reason is a measurement

Above.

### C53 — `sens_params` is not a condition this tree can reach

`PLAN.md` lists a `sens_params` precondition, *"≥1 eligible perturbable parameter"*,
`caution`. Measured, an unfiltered `sens` on a deck with any device at all produces vectors:
a deck whose only devices are a `V` source and a `B` source still yields
`b1_dtemp b1_m b1_tc1 b1_tc2 b1_temp v1 v1_freq v1_phase v1_pwr v1_z0`. The **only** way
measured to produce an empty sensitivity plot is a filter that matches nothing — which is
`sens_filters`, a sharper statement of the same worry with a fixture that reproduces it and a
sentence that names the filter.

### C54 — APPENDIX §2.10's three-row naming table is a FLAT-deck measurement

The table gives `<instance>`, `<instance>:<param>`, `<instance>_<param>`. Measurement 3: a
subcircuit device's vector is `<letter>.<instance path>.<name>`, and every xschem bench has
subcircuits. This is not a correction to the table's rows, which are right about a flat deck —
it is the missing row, and it is the one that decides whether the filter predicate is keyed on
the top scope or on every scope. Sabotage **S23** is the difference.

### C55 — APPENDIX §2.10's "write filters lowercase" is backwards under the one casemode that makes case matter

§2.10 says the glob is *"case-sensitive against already-folded names — so write filters
lowercase"*. Measured under the **default** casemode on both binaries, `sens v(mid) R1 dc`,
`R*` and `RL` **all match**, because the command reader folds the filter too. Measured on the
fork under `-D casemode=preserve`, against a netlist spelling the device `R1`:

```
sens v(mid) R1 dc -> $plots `const sens1`   (the plot exists)
sens v(mid) r1 dc -> $plots `const`         (NO PLOT AT ALL)
```

— exactly backwards from the advice. The honest rule is *"the filter is compared against the
instance name as ngspice stored it"*. Nothing ships for it (see *What I did NOT ship*); the
measurement is in the registry comment so Stage 7, which owns the pre-deck casemode class,
inherits it.

### And the static demotion's three cases, chosen per finding (Stage 4, issue 1427's finding)

The brief required this to be chosen per finding and said which:

| finding | verdict | which of the three rules, and why |
|---|---|---|
| the output is not readable as `v(…)`/`i(…)` | **`fatal`**, no caveat | *keep it when no include can make the text legal* — no `.include` makes `v mid` an output. `fatal` is exempt from the demotion and is independently honest: the guard's `quit 1` fires |
| the output names a node the circuit has not got | `blocked` → **`caution`** with the caveat | *lower it when an `.include` could supply what is missing* — an included file really can define that node |
| the output names no voltage source to read a current through | `blocked` → **`caution`** with the caveat | the same |
| a filter names nothing in this netlist | `blocked` → **`caution`** with the caveat | the same: an `.include` can add a top-level device with that name |

⚠ **The third rule — "skip the caveat when the finding is that the deck CONTAINS something" —
is deliberately NOT used here, and its absence is the interesting part.** `sens_filters`
reads like a positive finding and is not one: it says *"this netlist does not contain X"*,
which is exactly what a static pass cannot prove. `pz_devices`' `caution` arm says *"this deck
contains a `Y` card"*, which it can. The dividing line is the direction of the claim, not the
verdict. ⚠ **And the severity still tracks what the static pass can KNOW, never how bad the
outcome is** — `sens_filters` stays `caution` even though being right about it means a run
with nothing in it at all. Row **PF229i** is that sentence as an assertion.

### `viewrank` — measured for the third time, with two reasons of its own

Measurement 5 is `tf`'s and `pz`'s argument. `sens` adds two: a DC sens plot is `Flags: real`,
one data row, **no scale vector** — a table, not a sweep (that half is `pz`'s); and
**`Sensitivity Analysis` is the plot name of BOTH modes**, so even a working mapping could not
tell a DC row's results from an AC row's (APPENDIX §2.10, trap `[R-M11]`). Row **SE5** pins the
absence and **SE5b** is its non-vacuity.

---

## Suites moved, before → after, per arm

| suite | headless | display (`:99`) |
|---|---|---|
| `test_ase_core` | 376 → **391** | 376 → **391** |
| `test_ase_simcaps_0948` | 175 → **180** | 175 → **180** |
| `test_ase_preflight` | 177 → **192** | 177 → **192** |
| `test_ase_dialogs` | 37 → 37 | 278 → **285** |
| `test_ase_persist` | 44 → 44 | 148 → 148 |
| `test_ase_optier_0963` | 103 → 103 | see *For the driver* |

New sections: **SE** in `test_ase_core.tcl`, **SV** in `test_ase_simcaps_0948.tcl`, **PF229**
in `test_ase_preflight.tcl`, **G2sens** in `test_ase_dialogs.tcl`. All four floor paragraphs
raised in the same commit.

**Five existing `test_ase_core` rows moved rather than being added**, every one expected and
every one named in that file's floor paragraph:

| row | before | after | why |
|---|---|---|---|
| `AG1` | `{op dc ac tran tf pz noise sens …}` | `{op dc ac tran tf pz sens noise …}` | `sens` earned `emitorder 70` — and **overtook `noise`**, which is ahead of it in declaration order and has no rank |
| `AG2` | split at six, five rank-less | split at **seven**, four rank-less | same |
| `EM7` | five types with no `fields` | four | `sens` has fields |
| `CP6` | `5` probe-only | `4`, and `sens` asserted to HAVE fields | same |
| `GR8` | nine declared kinds | ten — **`filter` added deliberately** | a sens row's second field is a list of globs over ngspice's parameter namespace, and PLAN.md §5a's computed picker needs to find it without guessing which text box it is |

⚠ **`TF3b` and `D7e3` were flagged to move and did NOT.** The brief named both as rows that
move each time a type stops being probe-only. `pz`'s commit had already moved both off `pz` —
to `noise`, and to `noise`+`pss` — and neither names `sens`, so both are untouched here.
**A row picked for distance stops moving; that is what picking it for distance was for**, and
`D7e3`'s own comment (reach for a *fixture backend* when `pss` runs out) is still the standing
instruction for whoever makes `pss` renderable.

⚠ **`R1`, `AG3`, `CP1`–`CP4` did not move.** `sens` declares no `seed_enabled`, so
`ase::state_default` still seeds exactly four rows and the **104 committed `.state` files are
untouched** — three Stage 5 commits in a row, which is ⚖ R4's recommended answer shipping by
construction rather than by anybody remembering.

⚠ **`test_ase_preflight` rows PF222a-e / PF222h-j are green**, as the brief required. They
rest on `noise` being unrenderable and `noise` is untouched.

---

## The sabotage table

Thirty-nine sabotages, all against `src/ase.tcl`, each a plausible respelling rather than a
break. Restore was `cp` from `/tmp/sensprobe/pristine/` with an md5 compare after **every**
one; the final tree matches pristine on all five touched files. S1–S30 and S35–S39 are
headless; S31–S34 are the display arm on `:99`.

| # | the respelling | rows reddened |
|---|---|---|
| S1 | `emitorder 70` → `15` ("put sens just after dc") | core **AG1 AG2 TF1 PZ1 SE1 SE4b** |
| S2 | template swaps `out` and `filters` | core **SE2 SE2b SE4** |
| S3 | the literal `dc` dropped from the template | core **SE2 SE2b SE2c SE4 SE4b** |
| S4 | `filters` gains `whenskipped 0` | core **SE2 SE2c SE4b** |
| S5 | `out` loses `required 1` | core **SE3** |
| S6 | `kind filter` → `kind text` | core **GR8** |
| S7 | `kind filter` → `kind real` (a glob number-checked) | core **GR8 SE3** |
| S8 | **add `viewrank 0`** — PLAN.md's own shape for this stage | core **SE5** |
| S9 | add `seed_enabled 0` | core **R1 AG3 AG4 TF6 PZ6 SE6** |
| S10 | `role analysis` → `role probe` | core **SE1 SE2 SE2b SE2c SE3 SE3b** — then **KILLED THE SUITE** *(see below)* |
| S10r | the same, re-run against the hardened reader | core **SE1 SE2 SE2b SE2c SE3 SE3b SE4 SE4b**, `RESULT: 8 FAILED (383 passed)` |
| S11 | `select {Sensitivity Analysis}` → `{Sensitivity analysis}` | core **SE8** + simcaps **SV5** |
| S12 | `paramname` renamed to `vectors` (one key, two meanings) | core **SE8** · simcaps **KILLED THE SUITE** *(see below)* |
| S12b | the same, re-run against the hardened row | simcaps **SV5** |
| S13 | `sens_param_kind` stops stripping the rawfile `v()` wrapper | simcaps **SV3 SV4 SV5** |
| S14 | `sens_param_kind` splits the underscore too | simcaps **SV1 SV2** |
| S15 | the `v()` strip becomes case-sensitive — **landed on `pz_root_kind`, the first match in the file** | simcaps **PV2** *(a real non-vacuity result for `pz`'s row, and SV3 correctly stayed green)* |
| S15b | the same, on `sens_param_kind`'s own line | simcaps **SV3** |
| S16 | `sens_param_kind` splits on the LAST colon | simcaps **SV4** |
| S17 | `needs` drops `sens_out` | preflight **PF229b c d e f g** |
| S18 | `needs` drops `sens_filters` | preflight **PF229h i j l** |
| S19 | the malformed output is `blocked`, not `fatal` | preflight **PF229d PF229e** |
| S20 | the `i()` arm accepts any independent source | preflight **PF229f** |
| S21 | the voltage arm checks only the first node | preflight **PF229g** |
| S22 | `sens_out` reports on every deck (refuses everything) | preflight **PF229a h j k l m** |
| S23 | `sens_filters` searches EVERY scope, not the top one | preflight **PF229j** |
| S24 | `sens_filters` compares only the bare name | preflight **PF229l** |
| S25 | `sens_filters` stops skipping globs | preflight **PF229k** |
| S26 | `sens_filters` stops skipping dotted names | preflight **PF229j PF229k** |
| S27 | `sens_filters` compares case-sensitively | preflight **PF229l** |
| S28 | `sens_filters` reports on every deck | preflight **PF229a j k l** |
| S29 | `sens_filters` drops the `catch` round `llength` | preflight **PF229m** |
| S30 | the malformed-output remedy loses its parentheses clause | preflight **PF229d** |
| S31 | `out` loses `required 1` (the OK that COMMITS and CLOSES) | dialogs `:99` **G2sens** (the refusal row) |
| S32 | `filters` declared `kind mode` (a combobox, not a text box) | dialogs `:99` **G2sens** × 2 |
| S33 | the `Parameters` label respelt | dialogs `:99` **G2sens** (the labels row) |
| S34 | `filters` gains a default of `r*` | dialogs `:99` **G2sens** (the round-trip row) |
| S35 | `results {table {kind params}}` → `{viewer {kind sweep}}` | **NOTHING** *(see below — survivor 1)* |
| S35r | S35 re-run against the row it bought | core **SE9** |
| S35b | the same key respelt on **`tf`** instead of `sens` | core **SE9** |
| S36 | `baseline 1` → `0` (sens claimed build-gated) | core **AG5 SE3b** |
| S37 | the radio label `sens` → `sensitivity` | **NOTHING** *(see below — survivor 2)* |
| S37b | the same, re-run against the row it bought | core **SE1** |
| S38 | `needs` drops `cider_klu` | **NOTHING** *(see below — survivor 3)* |
| S38b | the same, re-run against the row it bought | preflight **PF229n** |
| S39 | an unimplemented id added to `needs` | **NOTHING — and correctly so** *(see below)* |
| S40 | `sens_out`'s node walk stops folding | preflight **PF229o** |

### The two that KILLED a suite, and the two hardenings they bought

**S10 reddened six rows and then killed `test_ase_core` outright** — six named `FAIL:` lines
and then **no `RESULT:` line and no `OVERALL:` line at all**. This file's outer `catch` closes
at the end of section SI, thousands of lines above section SE, so a raise in SE aborts the
file; and a raise is exactly what `role analysis` → `role probe` produces, because
`render_deck` refuses an **enabled** row of an unrenderable type with `-code error` (row D7e4
asserts that) and `sens_lines` called it bare.

The three deck readers — **`tf_lines`, `pz_lines` and `sens_lines`** — now call the render
inside a `catch` and return `RAISED:<msg>` as an ordinary value. Measured, same sabotage:

```
unhardened -> six FAILs, then nothing:  no RESULT:, no OVERALL:
hardened   -> eight FAILs (SE4 and SE4b join), RESULT: 8 FAILED (383 passed), OVERALL: notok
```

⚠ **The `catch` went on all three rather than on mine alone, and that is deliberate.**
`tf_lines` and `pz_lines` had the identical exposure with no measurement behind it — the `tf`
crew's own S18 and the `pz` crew's S18-equivalent would have died the same way and been
recorded as a short list of reds. It is a one-line addition that never fires in a green tree
and turns a dead file into a named row in a red one, so unlike the `ase::netlist_has_node`
refactor I declined (below) it changes no behaviour and carries no regression risk.

**S12's first attempt did not redden a row in `test_ase_simcaps_0948` — it killed the file
with NO `RESULT:` LINE AT ALL**, which in a sabotage log reads as *"nothing went red"*. Row
SV5 read the `plots` row with a bare `dict get $SV_PL paramname`, which is only legal while
the key is there — and the key's **renaming** is the exact change the row exists to catch.

SV5 now reads every key through an `svkey` helper that answers `ABSENT`. S12 re-run reddens
**SV5** alone and the file survives at 179 passed. The reason is written beside it, because
the next person to touch the row will otherwise take the helper for defensive padding. This is
the third time in Stage 5 the same lesson has been paid for — `pz`'s `pzkey` (S3) and
`g2pz_cget` (S33) are the other two — and `test_ase_core`'s SE8 had it from the start because
of them, which is why **core reddened while simcaps died on the same sabotage**.

### The two that SURVIVED, and the two rows written because of them

**S35 — rewriting `sens`'s `results {table {kind params}}` to `results {viewer {kind sweep}}`
left `test_ase_core`, `test_ase_simcaps_0948` AND `test_ase_preflight` all green.** The
`results` key is read by nothing in this tree yet, so nothing noticed the claim Stage 6 will
spend when it decides where a run's answers go. ⚠ **And `tf`'s and `pz`'s carry the same
unasserted key for the same reason**, so the row covers all three rather than `sens` alone:
row **SE9** asserts the destination each of the three was *measured* to produce — three
scalars in one plot, a root table with no scale vector, a one-row table of one number per
perturbable parameter. S35 and S35b both redden it.

**S37 — rewriting the radio label `sens` to `sensitivity` left `test_ase_core` and
`test_ase_dialogs` green.** `label` is today's radio text and the registry says in as many
words that promoting it to a human noun is **⚖ R9's to ratify, not a stage's to do in
passing** — and nothing was watching. Row **SE1** now asserts it. ⚠ **The other ten entries'
labels are still unasserted**; this closes the hole for `sens` only, and whoever does the
label-promotion stage inherits the rest *and* the measurement that nothing would have noticed.

**S38 — deleting `cider_klu` from `sens`'s `needs` left `test_ase_core` and
`test_ase_preflight` green.** PF224f/PF224g pin the **predicate**; nothing pinned which types
**subscribe** to it. That matters more than it looks: `cider_klu` is `fatal` because a CIDER
device under KLU makes ngspice `exit(1)` rather than return an error, so a `sens` row that did
not declare it would let the user start a run in which every analysis after the CIDER one
silently does not happen. Row **PF229n** asserts the subscription and both halves of the pair;
S38 re-run reddens it alone.

### The one that survived BY CONTRACT, and is not a hole

**S39 — adding an unimplemented id (`zz_unimplemented`) to `needs` changed nothing, and that
is the documented safe direction.** `ase::needs_eval`'s own header says an id it does not know
returns `{}` — satisfied — because a registry naming a precondition nobody has written yet
must not block a run; row **PF224h** is that contract as an assertion. Recorded here rather
than quietly dropped, because a reader scanning this table for survivors should not have to
re-derive why this one is correct.

### The rows that exist because a sabotage demanded them

* **SE9** — S35. Without it the three Stage 5 entries' `results` destinations are unasserted.
* **SE1's label leg** — S37.
* **PF229n** — S38.
* **PF229o** — not a sabotage but the same discipline applied to a **duplication**: there are
  now THREE copies of the "does this circuit have this node" walk (`tf_out`, `pz_nodes`,
  `sens_out`), written one stage-commit apart, and all three must agree that the comparison
  FOLDS. Nothing would have noticed a drift. The row asks all three the same two questions;
  S40 reddens it.
* **PF229a** — the *"refuses everything"* discriminator (S22, S28), inherited from PF227a and
  PF228a rather than re-learned.
* **PF229m's `pcall` leg** — S29 would otherwise abort the file inside its outer `catch` and
  print `FATAL:`.
* **SV5's `svkey`** — S12.
* **The `catch` in `tf_lines` / `pz_lines` / `sens_lines`** — S10.

---

## What Stage 5's `sens` commit learned that binds later stages

**A key that is read by nothing is asserted by nothing, and a whole stage can ship three of
them without noticing.** `tf`'s `results`, `pz`'s `results` and `sens`'s were all written as
the *measured* destination for a Stage 6 consumer — and all three could be rewritten to
anything at all with every suite green. The tell is not "is this key correct" but **"what
would fail if it were wrong"**, and for a forward-declared key the answer is nothing until
somebody writes the row. Sabotage found it; reading the registry would not have.

**The same is true of a key a PREVIOUS stage wrote.** `label` is Stage 2's, unchanged by this
commit and unasserted by anything — and it is *user-facing copy under a standing ruling*. A
crew that only sabotages what it changed will never find that class. **Sabotage the entry, not
the diff.**

**A predicate's fixture set has to contain the thing the predicate is about, and "the thing"
is sometimes a shape rather than a value.** `sens_filters`' whole correctness rests on the
netlist being **hierarchical** — a flat fixture makes the top-scope key and the all-scopes key
indistinguishable, and S23 would have survived. The `pz` crew learned the value version of this
(a fixture set that all looks the same makes a guard invisible); this is the structural one.

**"Silently ignored" and "no answer at all" are different failure modes, and the second is the
one a GUI can uniquely say.** `pz` taught that a silent wrong answer is worse than a refusal.
`sens` adds the case below it: a run that produces **nothing**, reports success, and hands the
downstream checker an artifact whose own diagnosis names the wrong cause. The preflight was the
only place the real cause could be said, and the measurement that proved it was following the
deck all the way through `render_deck` rather than stopping at the ngspice transcript.

**A severity is not a measure of how bad the outcome is.** `sens_filters` guarantees a run with
nothing in it and is still `caution`, because an `.include` can add the device. That is the
third time this stage has had to say it, and it is the one rule most likely to be "improved" by
somebody reading only the consequence.

**A plan's three-row table can be right and incomplete, and the missing row is the one that
decides the implementation.** APPENDIX §2.10's naming table is correct about a flat deck; every
xschem bench is hierarchical, and the missing `<letter>.<path>.<name>` row is precisely what
chooses between a predicate that works and one that is silent on every real bench.

**A test file's outer `catch` has an END, and every section below it is unprotected.**
`test_ase_core`'s closes at the end of section SI — thousands of lines above where Stage 5's
three sections live — so the natural reading *"this suite is abort-proofed"* is false for the
part of it this stage wrote. The tell is not visible while the tree is green; it is visible
only when a sabotage that SHOULD have reddened rows produces a short list and then silence.
**Check where the catch closes before trusting it**, and put the `catch` on the helper rather
than on the rows.

**A prose count beside a counted row is the count that goes stale.** The registry header said
"THE SIX ANALYSES … CANNOT YET DRIVE" for two commits while row EM7, which *counts* them, read
five. The row was right both times and nobody looked at the prose. It is corrected, and it now
says which of the two to believe.

---

## What I did NOT ship, and why

* **AC sensitivity** — Stage 6, for the measured reasons above. Neither of `PLAN.md`'s two
  `rules` ships, and the `lin` restriction should arrive there as a **field constraint**
  (`values {dec oct}`), not as a rule.
* **The `{build <proc>}` escape** — decision (a), justified above. `ase::analysis_expand` is
  unmodified.
* **`sens_params`** — correction C53; it is not a condition this tree can reach.
* **The `.sens` parameter picker** (`PLAN.md` §5a) and **`ase::ui::resulttable`** (§5b).
  `src/ase_window.tcl` is **untouched**. `kind filter` exists so the picker can find this field
  without guessing which text box it is.
* **The Value column / result table showing the sensitivities** (the plan's headline #4).
  `plots` and `results` are read by nothing in this tree; Stage 6 is where the adapter gets the
  hook that resolves them. The registry carries the measured content so Stage 6 inherits it.
* **A normalised column.** A sens row answers d(out) per unit of the parameter, so
  `r1 = -1.38889e-04` is volts per ohm and is not comparable with `v1 = 8.333333e-01`, volts
  per volt. That is the surface's job; `sens_param_kind`'s header says so in capitals.
* **Anything about the casemode/filter interaction (C55).** ASE-L would have to know the bench's
  casemode, which is a pre-deck variable and Stage 7's, and the finding would be a caution about
  the *user's own spelling* rather than about the circuit. `sens_filters` compares
  case-insensitively, which is the permissive direction.
* **A generic `resultname` key** collapsing `tf`'s `vectors`, `pz`'s `rootname` and `sens`'s
  `paramname`. Three opaque keys in one stage is a smell and it is named as one in SE8's
  comment — but nothing reads any of the three, so collapsing them now would be a schema
  decision taken with **zero consumers**. Stage 6 is where a consumer arrives and where the
  generalisation belongs.
* **`viewrank`**, **`seed_enabled`**, and any change to `ase::analysis_emit_check`. A bad output
  is caught by a precondition, not by a new kind-validation arm; the commit door's job is *"can
  this be emitted"*, not *"is this what the user meant"*.
* **A fix to the other ten entries' unasserted `label` keys** — found by S37, closed for `sens`,
  named for whoever does the label-promotion stage.
* **A shared `ase::netlist_has_node` reader.** There are now three copies of the node-existence
  walk and collapsing them is the right change — but `tf_out` and `pz_nodes` belong to issues
  1426 and 1427, and refactoring two shipped predicates in the last commit of a stage buys
  tidiness at the price of a regression nobody asked for. The `pz` crew introduced
  `ase::field_value` on a MEASURED failure (its sabotage S23); I have no measured failure here,
  only a smell. Row **PF229o** makes the drift visible instead, and its comment says plainly
  that it is not a refactor and does not pretend to be one.

---

## Rulings

⚖ **R9.** Two field labels — `Output`, `Parameters` — and **four precondition sentences with
their four remedies** (ten new user-facing strings in all). Recorded as
`owed.sh add rule 1428` at the moment it was incurred; **the ledger was backed up first** to
`/tmp/sensprobe/owed_backup_20260912_113406`, per `CLAUDE.md`'s one-ledger-every-clone
paragraph, and the entry is stamped to this clone. Batch with 1426's and 1427's — **all three
of Stage 5 are now waiting on one batched ratification.**

**No `look` debt.** `src/ase_window.tcl` is untouched; the form is built by
`ase::ui::chana_field_row` from the registry and both fields fall to the existing default entry
arm, which is the same arm `tf`'s two and `pz`'s four nodes take. Nothing new is drawn. The
first pixel deliverable of Stage 5 is `ase::ui::resulttable` and the `.sens` picker, which are
Stage 5b's to file.

**No `suite` debt beyond the display-arm runs recorded above**, which were taken on `:99`.

---

## For the driver

* T1 was **not** run by this crew (issue 0990 — the driver runs it solo).
* Nothing was committed, added, stashed or restored. `git status` shows **six modified** —
  `src/ase.tcl`, `tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_simcaps_0948.tcl`,
  `tests/headless/test_ase_preflight.tcl`, `tests/headless/test_ase_dialogs.tcl`,
  `doc/claude/issues/NUMBERING.md` — and **two new**,
  `doc/claude/issues/1428-dc-sensitivity-was-listed-and-could-not-be-chosen.md` and this
  receipt. `src/ase_window.tcl` is **untouched**. **`LEDGER.md` is NOT touched** — it is outside
  the files this crew may modify, so its Stage 5 table still shows T3 as *not started* and its
  T2 row as *pending*; both are the driver's to close.
* `NUMBERING.md`'s pointer was advanced **1428 → 1429** in the same edit as the entry, and the
  two checks were run at mint time: the reserved-band scan over this clone's head table
  (silent) and `ls ~/dev/*/doc/claude/issues/1428-*` plus `/usr/bin/grep -lw 1428` across every
  clone's `NUMBERING.md` (only this clone's own pointer line).
* The whole ASE family (29 suites) was re-run on **both arms** through `run_suites.sh`, every
  arm `timeout`-bounded (`SUITE_TIMEOUT=400`):
  * **headless** (`--nogui`): **27/27 passed, 2 skipped** (`test_ase_dirty`,
    `test_ase_log_seam_0207` — both self-skip for want of an X connection).
    `test_ase_optier_0963` headless is **ALL PASS (103)**, which is the arm
    `run_regression.tcl` actually runs it on.
  * **display `:99`**: see the two named non-passes below.
* ⚠ **Two named outcomes on the display arm, neither a regression, both reported as outcomes
  rather than as silence:**
  * `test_ase_log_seam_0207` — **my invocation, not a regression.** It asserts on the action
    log, which exists only under `--logdir`; its own first row is literally
    `PS0 action log open (needs --logdir)`, and `full_audit.sh:85` has it on `logdir_tests` for
    exactly this reason. The `tf` and `pz` crews hit the same thing. I did **not** re-run it
    with `--logdir`, because this crew's brief forbids `--logdir` outright; the `pz` receipt
    records `run_suites.sh --logdir test_ase_log_seam_0207` → **ALL PASS (49)**, and I verified
    the mechanism that makes that safe rather than taking it on trust —
    `run_suites.sh:122` is `tmpd=$(mktemp -d)`, so the user's own `/tmp/Xschem.log.N` is never
    the target and issue 1359's scar does not apply. **The driver may want that one run.**
  * `test_ase_optier_0963` — **`TIMEOUT | test_ase_optier_0963 run 15/29 (after 400s)`**, a
    named outcome rather than silence. This is the filed pre-existing display-arm stall
    `CLAUDE.md` records by name (*"86 of 103 rows, stops after row N3"*), which both earlier
    Stage 5 crews hit in the same place. Nothing in this commit touches `optier`,
    `render_deck`'s op-tier legs, or anything that suite drives, and its **headless** arm — the
    one `run_regression.tcl` runs it on — is **ALL PASS (103)** before and after. **Bounded by
    `run_suites.sh`'s own per-arm `timeout`**, so there is no orphan and no hand-placed prefix
    (`pgrep -fa src/xschem` after the run is clean).
* ⚠ **`~/.xschem/` was not touched by any probe of mine** — every ngspice run used a scratch
  deck or a scratch library with an explicit `rundir` under `/tmp/sensprobe`, and no bench
  under `sky130A/` was run. The suites themselves do write there (`geometry`,
  `~/.xschem/simulations` gets a temp netlist written and removed), which is pre-existing suite
  behaviour on the arm `CREW_BRIEF.md` prescribes; checked afterwards, **the user's 69,642,552-byte
  `~/.xschem/simulations/tb_bandgap_ase.raw` is intact at its original 2026-09-09 21:54
  timestamp**, along with its `.log`, `.opinfo` and `.spice`.
* Suggested commit subject:
  `feat(1428): DC sensitivity was listed and could not be chosen`
