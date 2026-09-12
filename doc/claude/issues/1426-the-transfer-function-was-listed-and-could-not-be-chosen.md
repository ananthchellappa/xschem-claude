# 1426 — the transfer function was listed and could not be chosen

**Status:** fixed
**Branch:** fluid-editing
**Stage:** the `tf` commit of **Stage 5** of `doc/claude/ase_analyses_batch/` (`pz` and `sens` are
separate commits).

## What it was

`tf` was one of the seven entries Stage 2 registered so the four-state grid could show that the
analysis exists:

```tcl
tf [dict create label tf baseline 1 registered 1 emit {{role probe tmpl {tf}}}]
```

No `fields`, no `emitorder`, no `role analysis` card — so `ase::analysis_renderable` answered 0,
the grid cell read `blocked/unrenderable`, and a hand-enabled row was refused at the gate. The user
could see that ngspice has a DC small-signal transfer function and could not ask for one.

It now carries a real entry: two fields, a rank, an emit template, a results destination and two
preconditions.

```tcl
tf [dict create \
  label tf  baseline 1  registered 1  emitorder 50 \
  needs  {tf_out tf_insrc cider_klu} \
  fields {{name out   kind outvar required 1 label {Output}} \
          {name insrc kind source required 1 label {Input source}}} \
  emit   {{role analysis tmpl {tf @out @insrc}}} \
  results {value {kind scalars}} \
  plots  {{select {Transfer Function} role scalars results value label tf \
           vectors ::ase::backend::ngspice::tf_vectors}}]
```

## The measurement that matters: ngspice checks the input and does not check the output

Measured 2026-09-12, one `-b` deck per line, on the fork (`build-ver_50`, `ngspice-46+`) and on
apt 45.2 alike:

```
tf v(mid) Rnope     -> rc 1, Warning: Transfer function source rnope not in circuit
tf v(mid) R1        -> rc 1, Warning: Transfer function source r1 not of proper type
tf v mid  V1        -> rc 1, Warning: Transfer function source  not in circuit   <- EMPTY
tf x(mid) V1        -> rc 1, Error: Syntax error: voltage or current expected.

tf v(nosuchnode) V1 -> rc 0, Transfer_function = 0.000000e+00
tf v(in,nosuch)  V1 -> rc 0, Transfer_function = 1.000000e+00
tf i(R1)         V1 -> rc 0, r1#Output_impedance = 1.000000e+20
tf i(nosuchsrc)  V1 -> rc 0, nosuchsrc#Output_impedance = 1.000000e+20
```

**Four of those eight are a run that succeeded**, with a vector named after the thing that does not
exist and three plausible numbers in it, and nothing on either stream. `tfanal.c:112-157` solves
against the already-factored Jacobian with a unit excitation, so an unmatched name excites nothing;
the `1e20` is the `|rhs| < 1e-20` clamp. **ASE-L is the only place this can be said at all**, which
is why the entry carries two `needs` ids rather than one and why `tf_out`'s sentence is the sharper
of the two.

⚠ **The missing parenthesis is the mistake a user makes, and ngspice blames it on the source.**
`tf v mid V1` fails with *"Transfer function source **·** not in circuit"* — the empty name —
because the `v` branch with no `(` consumes nothing and the `insrc` slot is then never filled. A
user reading that goes and looks at their source. `APPENDIX_ngspice_analyses.md` §2.7 records the
dot-card half of the same defect (`inp2dot.c:372-374` has an empty error arm).

## The static demotion is right for one finding in this predicate and wrong for another

Issue 1423 lowers every `blocked` verdict to `caution` on a static pass and appends *"(read from the
netlist text, which cannot see inside an `.include`)"*, because `ase::netlist_facts` answers
`exact 0` and a false refusal is worse than a missed one.

That is correct for a missing node or a missing source: an included stimulus file really can supply
them. **It is false about a syntax error.** No `.include` can make `v mid` a legal output; the
finding does not rest on the netlist at all, and a caveat about what the pass could not see is a lie
about why ASE-L is unsure.

So the malformed arm returns `fatal`, which is exempt from the demotion — and which is also the
honest severity. Measured 2026-09-12 with this tree's own `sim_status` guard wrapped around the
analysis:

```
tf x(mid) V1        -> rc 1, RUN-FAILED, the guard's `quit 1` fires and NOTHING
                             after it in .control runs
tf v(nosuchnode) V1 -> rc 0, REACHED-THE-END
```

which is issue 1424's definition of `fatal` word for word: not *"this run will be less useful"*, but
*"ngspice will not reach the end of `.control`"*.

⚠ **The severity tracks what the static pass can know, never how loudly the simulator complains.**
Both input-source findings stay `caution` even though ngspice's answer to both is a hard rc 1 abort.

## Four things PLAN.md Stage 5 said that the tree refuted

**1. `{build <proc>}` is not in this tree.** `PLAN.md` §1c specifies it as the escape an adapter
uses for a slot it has to *compose*, and Stage 5 spends it on
`{outkind outnode outref outsrc}` → `v(a,b)`. Stage 1 shipped `@x`, `@x?` and `@x!` and **no `build`
arm** — `ase::analysis_expand` treats a non-`@` token as a literal, so a `{build …}` token is
emitted as the literal words `build ase::backend::…`. The slot grammar joins tokens with a space and
cannot build `v(mid,out)` out of three of them. **Until that escape exists an emitted token is one
field**, so `tf` ships two fields (`out`, `insrc`) and not five. Not implemented here deliberately:
`sens` needs the same escape and is a separate crew's commit, and a shared grammar extension written
twice in one stage is a collision.

**2. `viewrank 0` would open the waveform window on nothing.** `PLAN.md` gives the entry
`viewrank 0`. The six remaining probe-only types have no viewrank because they cannot emit; `tf`
**can** emit and **does** produce data, so that argument does not reach it. The reason is one step
further on. `ase::plot_sim_type` answers a type **name**, and the waveform seam spends that name as
`xschem raw read <file> <type>`. Measured 2026-09-12 against a raw carrying an `Operating Point`
plot and a `Transfer Function` plot, through this tree's own binary:

```
xschem raw read both.raw tf                  -> raw_read(): no useful data found
                                                ... or no "tf" analysis      -> 0
xschem raw read both.raw op                  -> sim_type=op                  -> 1
xschem raw read both.raw {Transfer Function} -> sim_type=Transfer Function   -> 1
```

`src/save.c`'s `read_dataset()` maps `Plotname:` to a type with six named arms (transient / dc
transfer characteristic / noise spectral density / operating point / integrated noise /
ac|spectrum|sp) and then falls through to an exact `strcmp` against the plot name itself. `tf` is in
neither set. A `viewrank` would make `plot_sim_type` answer `tf`, `plot_sim_type_reason` answer `{}`
— *"there IS a mapping"* — and the viewer open on nothing, saying nothing. **The entry declares no
`viewrank`**, and Stage 6 revisits it when a surface learns to read a scalar plot.

**3. Only one of the three vector names is a constant.** `PLAN.md` writes them as three literals
(`Transfer_function v1#Input_impedance output_impedance_at_V(b)`). Measured 2026-09-12, `display`
after each command:

```
tf v(mid) V1     -> Transfer_function / v1#Input_impedance / output_impedance_at_V(mid)
tf v(mid,out) V1 -> output_impedance_at_V(mid,out)          [no space]
tf i(Vsense) V1  -> vsense#Output_impedance                 [the i() form REPLACES
                                                             the output-impedance name]
tf v(MID) v1     -> output_impedance_at_V(mid)              [the node is FOLDED, and
                                                             `..._at_V` keeps its capital]
```

The other two carry the row's own input source and output node, **folded to lower case even on the
case-preserving fork**. So the `plots` row's `vectors` key names a **proc** —
`ase::backend::ngspice::tf_vectors` — rather than three literals, because what the plan wrote as
literals is a template.

**4. The capitals are the fork's, and apt 45.2 folds them.** Measured 2026-09-12, the same deck
written by both binaries:

| | fork (`ngspice-46+`) | apt 45.2 |
|---|---|---|
| rawfile | `v(Transfer_function)` | `v(transfer_function)` |
| | `v(output_impedance_at_V(mid))` | `v(output_impedance_at_v(mid))` |
| | `v(v1#Input_impedance)` | `v(v1#input_impedance)` |

`display` shows the capitals on both; it is `print` and the **rawfile** that differ. So the literal
in the registry is the source spelling, and **a reader that matches it case-sensitively is wrong on
the binary a downloading user has.** Stage 6 folds. (Both rawfiles also wrap every name in `v(…)`,
because ngspice types all three as `voltage`.)

## What did NOT ship, and why

* **The five-field structured output picker** (`outkind`/`outnode`/`outref`/`outsrc`) — blocked on
  the `{build <proc>}` escape, above.
* **`ase::ui::resulttable` and the Value column showing the three numbers.** `plots` and `results`
  are **read by nothing in this tree** — grepped, no consumer — and Stage 6 is where the adapter
  gets the hook that resolves them. The registry now carries the measured content so that stage has
  it; the Value column is unchanged.
* **`seed_enabled`** — `tf` joins no fresh bench, so `ase::state_default` still seeds exactly four
  rows and the 104 committed `.state` files are untouched. Section CP of `test_ase_core.tcl` is the
  row that would notice; ⚖ **R4** is the ruling, shipping by construction.
* **`pz` and `sens`** — separate commits of the same stage.

## Rulings

⚖ **R9.** Two new field labels (`Output`, `Input source`) and six new precondition sentences. Filed
as an `owed.sh add rule 1426` debt; batched with Stage 5's other two types.

## Suites

| suite | before → after | section |
|---|---|---|
| `test_ase_core.tcl` | 348 → **360** | **TF** (new); `AG1`/`AG2` and `EM7`/`CP6` moved, expected |
| `test_ase_simcaps_0948.tcl` | 164 → **170** | **TV** (new) |
| `test_ase_preflight.tcl` | 152 → **164** | **PF227** (new) |
| `test_ase_dialogs.tcl` (`:99`) | 265 → **271** | **G2tf** (new); headless 37 unmoved |

`test_ase_persist` 44 / 148 and `test_ase_optier_0963` 103 headless — unmoved.

⚠ **`test_ase_optier_0963`'s DISPLAY arm did not finish, and it is a filed pre-existing stall.**
`CLAUDE.md` records it by name — *"86 of 103 rows, stops after row N3, no `ngspice` alive, no
verdict line"* — and `run_regression.tcl` runs that suite **headless only**, where it is ALL PASS
(103) before and after. Nothing here touches it. The run was bounded at 400 s and reported as a
`TIMEOUT`, not as silence.

⚠ **Two rows moved rather than being added, and both were expected.** `AG1`/`AG2` split the offered
list at five instead of four because `tf` earned an `emitorder`; `EM7`/`CP6` count six probe-only
types instead of seven. `CP1`–`CP4`, the committed-corpus rows, did not move at all.
