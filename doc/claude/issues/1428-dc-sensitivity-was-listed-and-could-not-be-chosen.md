# 1428 — DC sensitivity was listed and could not be chosen

**Stage 5 of `doc/claude/ase_analyses_batch/`, third and last commit.** `tf` is issue
**1426**, `pz` is issue **1427**. Nothing here touches either.

## The defect

Stage 2 (issue 1410) registered eleven analysis types so the four-state grid could show
the user what ngspice can do. Seven of them were registered **probe-only**:

```tcl
sens [dict create label sens baseline 1 registered 1 emit {{role probe tmpl {sens}}}]
```

No `fields`, no `emitorder`, no `role analysis` card. `ase::analysis_renderable` answered
**0**, so the cell read `blocked/unrenderable`, the Enable checkbutton was disabled, the
form below it was empty, and a hand-enabled row was refused at `ase::preflight_gate`
before a deck was written.

So the user could see that ngspice will tell them **how much an output moves when each
device and model parameter is perturbed** — a capability Cadence ADE-L lists as a type
and gives no computed picker for — and could not ask for one.

## What this changes

`sens` gains a real registry entry in `ase::backend::ngspice::analysis_types`:
`emitorder 70`, two fields, a `role analysis` card, a `results`/`plots` pair and three
`needs` ids. The cell becomes `ok`, the form builds, OK commits, and the line reaches the
deck.

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

**DC only.** The `ac` mode is Stage 6's, and that is a scope line with two measured
AC-only defects behind it rather than a convenience — see *The AC mode is not deferred
work* below.

One new adapter proc, `ase::backend::ngspice::sens_param_kind` — **content** (D34–D37) —
reads one result vector name back into `{model <instance> <parameter>}` or
`{instance <name>}`. Two new predicates in `ase::needs_eval`: `sens_out` and
`sens_filters`. `src/ase_window.tcl` is **untouched**; the form is built from the registry
by `ase::ui::chana_field_row` and both fields fall to the existing default entry arm.

## The measurements this rests on

All 2026-09-12, scratch decks under `/tmp/sensprobe`, never a bench under `sky130A/`.
Binary 3 is `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`); binary 1
is `/usr/bin/ngspice` (`ngspice-45.2`). **Both were run for every line below and the two
agreed on every one.**

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

⚠ **`i()` is a voltage source and only a voltage source, and that is five device classes
rather than an argument.** The inductor and the current source are the two that
discriminate: `i(L1)` is a real branch current elsewhere in ngspice, so *"nothing else has
a branch current"* would have been a right answer resting on a wrong reason; and `I1`
**is** in `ase::netlist_facts`' `sources`, so a predicate asking *"is this an independent
source"* rather than *"is this a voltage source"* passes it in silence at rc 0.

⚠ **And this is where `sens` is BETTER than `tf`.** `tf v mid V1` blames the *source* with
an empty name (`Warning: Transfer function source  not in circuit`); `sens v mid dc` names
the output and the missing parenthesis. The verdict is still `fatal` — the guard's
`quit 1` fires and nothing after it in `.control` runs — but ASE-L's sentence is saying
the same thing earlier, not making up for a misleading message. Issue 1426's argument may
not be copied here.

### 2. A filter that matches nothing leaves the run with NO PLOT AT ALL

```
sens v(mid) r1 dc        -> $plots `const sens1`, one vector: r1
sens v(mid) r1 nosuch dc -> $plots `const sens1`, one vector: r1
                            -- the bad filter is DROPPED IN SILENCE
sens v(mid) nosuch dc    -> $plots `const`, $curplotname `constants`,
                            rc 0, REACHED-THE-END
sens v(mid) zzz* dc      -> the same
```

Followed through this tree's own renderer: `ase::backend::ngspice::render_deck` against a
scratch library with an explicit `rundir`, one enabled row
`{type sens enabled 1 out v(mid) filters nosuchdev}`, on **both** binaries →

```
rc 0, and the only record in <cell>_ase.raw is
  Title: Constant values / Plotname: constants / No. Variables: 12
ase::raw_content_verdict -> ok 0  constants 1  plotname constants
```

That is the artifact the whole of `tests/headless/test_ase_preflight.tcl` is about —
*"twelve mathematical constants where its waveforms should be"* — reached from a direction
nobody had walked. ⚠ **And defence (c) catches it and guesses the cause wrong**: its
sentence reads *"the analysis did not run (typically a `.save` of a node the circuit does
not have)"*. That is what makes defence (a) worth having here — `sens_filters` is the only
place the real cause can be said.

### 3. The vector namespace is hierarchical

`V1 / X1 / R9` at top level, `Ra` and `Rb` inside `.subckt divider`. The **complete**
bare-name set of the sensitivity plot, on both binaries:

```
r.x1.ra   r.x1.rb   r9   v1
```

A subcircuit device is `<letter>.<instance path>.<name>`; the subckt **call** `x1` produces
nothing at all. So a user filtering on the name they see inside their own subcircuit —
`ra` — matches nothing and is told nothing, and `sens_filters` is keyed on the **top
scope** for exactly that reason.

### 4. The underscore form collides in ngspice itself

One deck carrying `R1` and `R1_temp`. `display` after `sens v(mid) dc` lists

```
r1_temp             : voltage, real, 1 long
r1_temp             : voltage, real, 1 long
```

— once as `R1`'s instance `temp` parameter and once as `R1_temp`'s own principal
resistance. Two different quantities, one name, one plot. `sens_param_kind` therefore
splits the **colon** and refuses to split the underscore.

### 5. `xschem raw read` cannot find a `sens` plot

Against a raw carrying an `Operating Point` plot and a `Sensitivity Analysis` plot,
through this tree's own binary:

```
xschem raw read both.raw sens                   -> no useful data found ... or
                                                   no "sens" analysis      -> 0
xschem raw read both.raw op                     -> sim_type=op             -> 1
xschem raw read both.raw {Sensitivity Analysis} -> sim_type=Sensitivity …  -> 1
```

So the entry declares **no `viewrank`**, for the third time in this stage and with two
further reasons of its own: a DC sens plot is `Flags: real`, one data row, **no scale
vector** — a table, not a sweep — and `Sensitivity Analysis` is the plot name of **both**
modes, so even a working mapping could not tell a DC row's results from an AC row's.

### 6. There are no capitals to fold

The same op+sens deck written by both binaries: the `Variables:` blocks are
**byte-identical** — `v(r1)`, `v(r2)`, ngspice's own `v(…)` wrapper round a name it types
as a voltage — and the only difference anywhere in either header is the `Command:` version
line. Issue 1426's C46 warning does not reach this entry, for `pz`'s reason (there are no
capitals) rather than by inheritance.

### 7. End to end, on both binaries

`render_deck` against a scratch library with an explicit `rundir` (`/tmp/sensprobe/e2e`),
a state carrying `{type op enabled 1}` and
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

## The AC mode is not deferred work — the shape changes

Both AC-only defects were re-measured on both binaries:

```
sens v(mid) r1 ac lin 5 1k 5k -> 1.000000e+03  8.000000e+05  6.400000e+08
                                 5.120000e+11  4.096000e+14        (each x800)
.options klu + sens v(mid) ac dec 1 1k 10k -> rc 139, SIGSEGV
.options klu + sens v(mid) dc              -> rc 0, and the numbers are
                                 BYTE-FOR-BYTE the sparse ones
```

Neither reaches DC. The sweep defect is `inc_freq` (`cktsens.c:829-837`) testing against
the `#define LINEAR 3` pulled in from `noisedef.h` instead of `SENS_LINEAR`, so the test is
always true; `count_steps`' `SENS_DC` arm (`cktsens.c:872`) returns n=0 and s=0 and
`sens_sens` sets `freq = 0.0` for the single point, so the value `inc_freq` computes is
never used. The KLU crash is the guard at `cktsens.c:97-105` being **commented out** — and
note what the commented guard would have refused: **all** sensitivity under KLU, DC
included, which is measured safe and identical here.

So **neither of `PLAN.md`'s two `rules` ships**, and that is the shape changing rather than
work being postponed. The plan has to express *"do not offer `lin` for SENS AC"* as a
`rule` **because `@modeargs` is a free slot** — a free slot has no declared value set for a
field constraint to attach to. This entry has no `@modeargs` at all: the DC case is the
**literal** token `dc` in the template. When Stage 6 adds the mode it can declare the sweep
field `values {dec oct}` and have the restriction be a **field constraint the form cannot
offer**, rather than a rule the form offers and then refuses.

## What `PLAN.md` said that the tree refutes

**C52 — `{build <proc>}` is not built, and for `sens` the reason is a measurement rather
than the cost.** Issue 1426 found that `PLAN.md` §1c specifies `{build <proc>}` as the
escape an adapter uses for a slot it must compose, and that Stage 1 shipped `@x`, `@x?` and
`@x!` and **no `build` arm at all**. `PLAN.md` Stage 5 spends the escape here too —
`{sens {build ase::backend::ngspice::an_sens_out} @filters? @modeargs}` — and the `tf` crew
explicitly left the decision to this commit, because `sens` is the last entry in the stage
that wants it.

It is **not** built. The escape's only gain would be a **structured** output picker, and
`ase::backend::ngspice::out_decompose` — registered as a hook and shipped by issue 1426 —
already takes `v(a)`, `v(a,b)` and `i(src)` **apart** again, exactly and
case-insensitively. The structured data is therefore recoverable from the one verbatim
token whenever a surface wants it, so composition buys nothing a reader does not already
give. Building a Stage 1 grammar arm with one consumer, in the last commit of Stage 5, to
reach a surface Stage 5b has not built, is a change with no measurement behind it. **Stage
1's grammar is unmodified and every existing slot row is untouched.**

**C53 — `sens_params` is not a condition this tree can reach, and the filter check is what
it was reaching for.** `PLAN.md` lists a `sens_params` precondition — *"≥1 eligible
perturbable parameter"*, `caution`. Measured, an unfiltered `sens` on a deck with any
device at all produces vectors: a deck whose only devices are a `V` source and a `B` source
still yields `b1_dtemp b1_m b1_tc1 b1_tc2 b1_temp v1 v1_freq v1_phase v1_pwr v1_z0`. The
**only** way measured to produce an empty sensitivity plot is a filter that matches
nothing, which is `sens_filters` — a sharper statement of the same worry, with a fixture
that reproduces it and a sentence that names the filter.

**C54 — APPENDIX §2.10's three-row naming table is a FLAT-deck measurement.** The table
gives `<instance>`, `<instance>:<param>` and `<instance>_<param>`. Measurement 3 above:
a subcircuit device's vector is `<letter>.<instance path>.<name>`, and every xschem bench
has subcircuits. This is not a correction to the table's rows, which are right about a flat
deck — it is the missing row, and it is the one that decides whether a filter predicate is
keyed on the top scope or on every scope.

**C55 — APPENDIX §2.10's "write filters lowercase" is wrong under the one casemode that
makes case matter, and harmless under every other.** §2.10 says the filter glob is
*"case-sensitive against already-folded names — so write filters lowercase"*. Measured on
both binaries under the default casemode, `sens v(mid) R1 dc`, `R*` and `RL` **all match**,
because the command reader folds the filter too. Measured on the fork under
`-D casemode=preserve`, against a netlist spelling the device `R1`:

```
sens v(mid) R1 dc -> $plots `const sens1`   (the plot exists)
sens v(mid) r1 dc -> $plots `const`         (NO PLOT AT ALL)
```

— exactly backwards from the advice. The honest rule is *"the filter is compared against
the instance name as ngspice stored it"*, which under a folding casemode makes the filter's
own case irrelevant and under a preserving one makes the **netlist's** spelling the one to
match. Nothing is shipped for it (see below); the measurement is in the registry comment so
Stage 7, which owns the pre-deck casemode class, inherits it.

## Where the three severities come from

`sens_out`'s syntax arm is **`fatal`** for one reason only: the run does not reach the end
of `.control`. Its two silent arms are **`blocked`**, which `ase::analysis_needs` demotes to
**`caution`** with the `.include` caveat, because an included file really can define the
node or the source. `sens_filters` is **`blocked`**→`caution` for the same reason, **even
though the consequence of being right is a run with nothing in it**: the severity tracks
what the static pass can *know*, never how bad the outcome is. That is issue 1423's rule
and issue 1426's C47 arriving for the third time.

## Suites

| suite | headless | display `:99` |
|---|---|---|
| `test_ase_core` | 376 → **391** (section SE) | 376 → **391** |
| `test_ase_simcaps_0948` | 175 → **180** (section SV) | 175 → **180** |
| `test_ase_preflight` | 177 → **192** (section PF229) | 177 → **192** |
| `test_ase_dialogs` | 37 → 37 | 278 → **285** (section G2sens) |

Five existing `test_ase_core` rows moved rather than being added: `AG1`/`AG2` (the offered
list splits at seven; `sens` overtook `noise`, which is ahead of it in declaration order and
has no rank), `EM7`/`CP6` (four probe-only types now, not five) and `GR8` (a new declared
kind, `filter`). **`TF3b` and `D7e3` were expected to move and did not** — `pz`'s commit had
already moved both off `pz`, to `noise` and to `noise`+`pss`, and neither names `sens`. A row
picked for distance stops moving; that is what picking it for distance was for.

`R1`, `AG3` and `CP1`–`CP4` do not move: `sens` declares no `seed_enabled`, so
`ase::state_default` still seeds exactly four rows and the 104 committed `.state` files are
untouched. Three Stage 5 commits in a row, which is ⚖ R4's recommended answer shipping by
construction.

## What this does NOT do

* **AC sensitivity** — Stage 6, for the measured reasons above.
* **The `.sens` parameter picker** (`PLAN.md` §5a) and **`ase::ui::resulttable`** (§5b).
  `src/ase_window.tcl` is untouched. `kind filter` exists so the picker can find this field
  without guessing which text box it is.
* **The Value column / result table showing the sensitivities.** `plots` and `results` are
  read by nothing in this tree yet; the keys carry the measured destination so Stage 6
  inherits it.
* **A normalised column.** A sens row answers d(out) per unit of the parameter, so
  `r1 = -1.38889e-04` is volts per ohm and is not comparable with `v1 = 8.333333e-01`,
  volts per volt. That is the surface's job and the surface does not exist;
  `sens_param_kind`'s header says so.
* **Anything about the casemode/filter interaction (C55).** ASE-L would have to know the
  bench's casemode, which is a pre-deck variable and Stage 7's; and the finding would be a
  caution about the *user's own spelling*, not about the circuit.
* **`viewrank`**, **`seed_enabled`**, and any change to `ase::analysis_emit_check`. A bad
  output is caught by a precondition, not by a new kind-validation arm; the commit door's
  job is *"can this be emitted"*, not *"is this what the user meant"*.

## Rulings

⚖ **R9.** Two field labels — `Output`, `Parameters` — and **four precondition sentences with
their four remedies** (ten new user-facing strings in all). Recorded as `owed.sh add rule 1428`.
Batch with 1426's and 1427's.
