# Stage 5 — `tf`, the DC small-signal transfer function

**One commit, issue 1426.** `pz` and `sens` are separate crews and separate commits of the same
stage; nothing here touches them.

**Floors:** `test_ase_core` 348 → **360** · `test_ase_simcaps_0948` 164 → **170** ·
`test_ase_preflight` 152 → **164** · `test_ase_dialogs` display 265 → **271** (headless 37
unmoved). **Twenty-one sabotages**, every one reddening a named row, none killing a suite. One
sabotage passed against the row as first written and the row was strengthened; it is S9 below.

---

## What the stage was for

`tf` was one of the seven entries Stage 2 registered so the four-state grid could show that the
analysis exists:

```tcl
tf [dict create label tf baseline 1 registered 1 emit {{role probe tmpl {tf}}}]
```

No `fields`, no `emitorder`, no `role analysis` card — so `ase::analysis_renderable` answered 0, the
cell read `blocked/unrenderable`, and a hand-enabled row was refused at the gate. The user could see
that ngspice has a DC small-signal transfer function and could not ask for one.

---

## What shipped

### `src/ase.tcl` — the registry entry (inside `ase::backend::ngspice::analysis_types`)

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

(`src/ase.tcl:~14494`, inside the `return [dict create …]` — cite the proc, the line is a hint.)

### `src/ase.tcl` — two new adapter procs, both **content** (D34–D37)

| proc | what it answers |
|---|---|
| `ase::backend::ngspice::out_decompose {text}` | `{voltage n}`, `{voltage n ref}`, `{current name}` or the single word `malformed` |
| `ase::backend::ngspice::tf_vectors {row}` | the three vector names a `tf` row will produce |

`out_decompose` is registered as the `out_decompose` hook on `ase::register_backend ngspice`,
alongside `dc_swkind`. `tf_vectors` is reached through the `plots` row's `vectors` key, which is
opaque to core.

### `src/ase.tcl` — two new predicates in `ase::needs_eval`

`tf_insrc` and `tf_out`. Both are ordinary Stage 4 machinery; no new mechanism was added for them.

### `tests/headless/test_ase_dialogs.tcl` — section **G2tf**, six widget rows

The half `test_ase_core` cannot assert: that the two fields are **built**, that the previous type's
widgets are **gone** from the same `$w.form` frame, that **Enable is live**, that the labels are the
declared ones, that OK **commits** and the Arguments column shows `tf v(D) V1`, and that a
half-filled row is still **refused**. Display arm only, like every widget row in that file.

### Comment blocks

A `tf` block above `return [dict create …]` carrying the eight-line measured transcript, the
`viewrank` refutation with its three `xschem raw read` lines, the `{build}` refutation and the
fork-vs-45.2 case table; and the "seven probe-only types" paragraph corrected to six with the
exception named rather than dropped.

---

## Every measured fact this rests on, and where it was measured

All ngspice measurements 2026-09-12, scratch decks under `/tmp/tfprobe`, never a bench under
`sky130A/`. Binary 3 is `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`); binary
1 is `/usr/bin/ngspice` (`ngspice-45.2`). **Both were run**, per the brief's three-binary rule.

### 1. The three vector names, and which of them are constants

```
tf v(mid) V1      -> Transfer_function / v1#Input_impedance / output_impedance_at_V(mid)
tf v(mid,out) V1  -> output_impedance_at_V(mid,out)     [no space after the comma]
tf i(Vsense) V1   -> vsense#Output_impedance            [REPLACES the ..._at_V name]
tf v(MID) v1      -> output_impedance_at_V(mid)         [the node is FOLDED; the
                                                         literal keeps its capital V]
```

`display` after each command, fork. **Only `Transfer_function` is a constant.** The other two carry
the row's own input source and output node, folded to lower case even on the case-preserving fork —
the UID prefix is the device's own UID, which ngspice stores folded.

### 2. ngspice checks the input source and does not check the output

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

Same verdicts on both binaries (the `R1` case was re-run on apt 45.2 verbatim). **Four of the eight
are a run that succeeded**, with a vector named after the thing that does not exist. This is the
whole reason the entry carries two `needs` ids.

### 3. `i()` is a voltage source and only a voltage source — measured across four device classes

```
tf i(Vsense) V1  -> Transfer_function = 3.333333e-04   <- correct, 1/3k A/V
tf i(L1)     V1  -> Transfer_function = 0.000000e+00   <- WRONG, rc 0
tf i(I1)     V1  -> Transfer_function = 0.000000e+00   <- WRONG, rc 0
tf i(R1)     V1  -> Transfer_function = 0.000000e+00   <- WRONG, rc 0
```

⚠ **This one nearly went in as a false refusal by reasoning.** `i(L1)` **is** a real branch current
elsewhere in ngspice — `op` then `print i(L1)` answers `5.000000e-04`, while `print i(R1)` answers
`Error: no such function as i, or i(r1) is not available.` So "an inductor has no branch current" is
false, and had the predicate been written on that argument it would have been right by accident and
wrong about the reason. The measurement is what justifies the rule.

⚠ **The current source is the row that matters.** `I1` **is** in `facts sources`, so a predicate
asking *"is this an independent source"* rather than *"is this a voltage source"* passes it,
silently, at rc 0. That is sabotage **S10** and row **PF227g**.

### 4. `sim_status` after each of the two failure shapes

With this tree's own guard (`ase::backend::ngspice::sim_status_guard`) wrapped around the analysis:

```
tf x(mid) V1        -> rc 1, RUN-FAILED, the guard's `quit 1` fires and NOTHING
                             after it in .control runs
tf v(nosuchnode) V1 -> rc 0, REACHED-THE-END
```

This is what makes the malformed arm `fatal` (issue 1424's definition, word for word) and the
missing-node arm `blocked`.

### 5. `xschem raw read` cannot find a `tf` plot

Against a raw carrying an `Operating Point` plot and a `Transfer Function` plot, through
`./src/xschem --nogui --pipe -q --nolog`:

```
xschem raw read both.raw tf                  -> raw_read(): no useful data found
                                                extra_rawfile() ... or no "tf" analysis   -> 0
xschem raw read both.raw op                  -> sim_type=op                               -> 1
xschem raw read both.raw {Transfer Function} -> sim_type=Transfer Function                -> 1
```

`src/save.c`'s `read_dataset()` maps `Plotname:` to a type with six named arms (transient / dc
transfer characteristic / noise spectral density / operating point / integrated noise /
ac|spectrum|sp) and then falls through to an **exact `strcmp`** against the plot name itself. `tf` is
in neither set.

### 6. The capitals are the fork's; apt 45.2 folds them

Same deck, written by both binaries:

| | fork (`ngspice-46+`) | apt 45.2 |
|---|---|---|
| rawfile | `v(Transfer_function)` | `v(transfer_function)` |
| | `v(output_impedance_at_V(mid))` | `v(output_impedance_at_v(mid))` |
| | `v(v1#Input_impedance)` | `v(v1#input_impedance)` |

`display` shows the capitals on both; it is **`print` and the rawfile** that differ. Both wrap every
name in `v(…)` because ngspice types all three as `voltage`.

### 7. End to end, on both binaries

`ase::backend::ngspice::render_deck` against a scratch library with an explicit `rundir`
(`/tmp/tfprobe/e2e`), a state carrying `{type op enabled 1}` and
`{type tf enabled 1 out v(mid) insrc V1}`. The deck emits

```
op … remzerovec … write …_ase.raw
tf v(mid) V1 … remzerovec … write …_ase.raw
```

**rc 0 on the fork and rc 0 on apt 45.2**, two `Plotname:` records in one raw. Read back through
ASE-L's own readers:

```
ase::cap_raw_plots    -> {{Operating Point} 1 {v(in) v(mid) i(v1)}}
                         {{Transfer Function} 1 {v(transfer_function) …}}
ase::raw_content_verdict -> ok 1 constants 0 appended 0 plotname {Operating Point} …
ase::plot_sim_type       -> op            (tf has no viewrank, so op still wins)
```

---

## What PLAN.md Stage 5 said that the tree refuted

This is the batch's fifth stage and its sixth through ninth corrections.

### C43 — `{build <proc>}` is not in this tree, so an emitted token is one field

`PLAN.md` §1c specifies `{build <proc>}` as *"the escape hatch"* an adapter uses for a slot it has to
**compose**, and Stage 5 spends it on `{outkind outnode outref outsrc}` → `v(a,b)`. **Stage 1 shipped
`@x`, `@x?` and `@x!` and no `build` arm.** `ase::analysis_expand`'s first line is
`if {[string index $tok 0] ne {@}} { lappend res [list 1 $tok {}] ; continue }` — a `{build …}` token
is a literal, and would be emitted as the literal words `build ase::backend::…`. The slot grammar
joins tokens with a space and cannot build `v(mid,out)` out of three of them.

So `tf` ships **two** fields, `out` and `insrc`, and `out` carries the output expression verbatim.

⚠ **Not implemented here deliberately.** `sens` needs the same escape (`sens <outvar> …`) and is a
separate crew's commit in the same stage; `pz` needs it for nothing at all — `pz n1 n2 n3 n4
cur|vol pol|zer|pz` is six separate tokens, so the plan's `{build ase::backend::ngspice::an_pz_nodes}`
buys `pz` nothing. A shared grammar extension written twice in one stage is a collision, and the
driver's brief says *"the grammar you must use (shipped this session, do not re-invent)"*.

### C44 — `viewrank 0` would open the waveform window on nothing

`PLAN.md` gives the entry `viewrank 0`. The six remaining probe-only types have no viewrank because
they cannot emit; `tf` **can** emit and **does** produce data, so the registry's existing argument
does not reach it. The reason is one step further on, and it is measurement 5 above:
`ase::plot_sim_type` answers a type **name**, the waveform seam spends it as `xschem raw read <file>
<type>`, and `tf` matches nothing. A `viewrank` would make `plot_sim_type` answer `tf`,
`plot_sim_type_reason` answer `{}` — *"there IS a mapping"* — and the viewer open on nothing, saying
nothing.

**The entry declares no `viewrank`.** Row TF5 pins it and row TF5b is its non-vacuity: the same bench
against a fixture backend whose `tf` **does** carry a viewrank answers `tf` and reports a mapping
that does not exist.

### C45 — only one of the three vector names is a constant

`PLAN.md` writes them as three literals, `Transfer_function v1#Input_impedance
output_impedance_at_V(b)`. Measurement 1 says the other two are **templates** carrying the row's own
source and node. So `plots`' `vectors` key names a **proc** rather than a list.

### C46 — the literals are the fork's spelling, and a case-sensitive reader is wrong on apt 45.2

Measurement 6. The brief's own "facts that are MEASURED and authoritative" block carries the capital
spellings, and they are right — **on the fork**. On the binary a downloading user has, the same run
writes `v(transfer_function)`. The registry carries the source spelling; the comment says in capitals
that Stage 6's reader must fold.

### C47 (smaller) — the static demotion is right for one finding in a predicate and wrong for another

Not a plan claim, but a Stage 4 mechanism meeting its first counter-example. Issue 1423 lowers every
`blocked` to `caution` on a static pass and appends *"(read from the netlist text, which cannot see
inside an `.include`)"*. That is correct for a missing node or source. **It is false about a syntax
error** — no include can make `v mid` legal, the finding does not rest on the netlist at all, and the
caveat is a lie about why ASE-L is unsure. The malformed arm returns `fatal`, which is exempt from the
demotion and is independently the honest severity (measurement 4).

⚠ **And the severity tracks what the static pass can know, never how loudly the simulator
complains.** Both input-source findings stay `caution` even though ngspice's answer to both is a hard
rc 1 abort, because an `.include`d stimulus file really can supply `V1`. Row PF227i is that sentence
as an assertion.

---

## Suites moved, before → after, per arm

| suite | headless | display (`:99`) |
|---|---|---|
| `test_ase_core` | 348 → **360** | 348 → **360** |
| `test_ase_simcaps_0948` | 164 → **170** | 164 → **170** |
| `test_ase_preflight` | 152 → **164** | 152 → **164** |
| `test_ase_dialogs` | 37 → 37 | 265 → **271** |
| `test_ase_persist` | 44 → 44 | 148 → 148 |
| `test_ase_optier_0963` | 103 → 103 | see below |

New sections: **TF** in `test_ase_core.tcl`, **TV** in `test_ase_simcaps_0948.tcl`, **PF227** in
`test_ase_preflight.tcl`, **G2tf** in `test_ase_dialogs.tcl`. All four floor paragraphs raised in
the same commit.

⚠ **`test_ase_optier_0963`'s DISPLAY arm did not finish, and it is a filed pre-existing stall, not
this change.** `CLAUDE.md` records it by name: *"a stall in `test_ase_optier_0963`'s **display** arm
— 86 of 103 rows, stops after row N3, no `ngspice` alive, no verdict line"*, which cost a session
eight hours because the waiter around it had no deadline. The same suite's **headless** arm — the
one `run_regression.tcl` actually runs, since its case list runs this suite headless only — is
**ALL PASS (103)**, before and after. Nothing in this commit touches `optier`, `render_deck`'s
op-tier legs, or anything that suite drives. **My run was bounded** (`timeout 400`) and reported as
a named outcome rather than as silence, per `CLAUDE.md`'s rule.

⚠ **And note the timeout was placed wrongly, and it is recorded rather than quietly corrected**: `timeout 400
devdisplay.sh exec …` signals the *shell*, not xschem, which is exactly the orphan trap
`CLAUDE.md` documents for `run_regression.tcl`'s display arm (the prefix belongs **inside**
`cmd_exec`). The straggler was reaped by hand; nothing was left on `:99`.

**Four existing rows moved, all expected and all named in their own comments:**

| row | before | after | why |
|---|---|---|---|
| `AG1` | the offered list split 4/7 | 5/6, `tf` fifth | `tf` earned an `emitorder` |
| `AG2` | `{op dc ac tran}` / `{noise tf pz …}` | `{op dc ac tran tf}` / `{noise pz …}` | same |
| `EM7` | seven types with no `fields` | six | `tf` has fields |
| `CP6` | `7` probe-only | `6`, and `tf` asserted to HAVE fields | same |

⚠ **`R1`, `AG3`, `CP1`–`CP4` did not move.** `tf` declares no `seed_enabled`, so
`ase::state_default` still seeds exactly four rows and the **104 committed `.state` files are
untouched** — ⚖ R4's recommended answer continuing to ship by construction. `CP6` was rewritten to
name `tf` on **both** sides rather than dropping it from the walk: deleting it would make the row read
the same before and after, and a census that cannot see its own subject is not a census.

---

## The sabotage table

Twenty-one sabotages, all against `src/ase.tcl`, each a plausible respelling rather than a break.
Restore was `cp` from `/tmp/tfprobe/pristine/` with an md5 compare after every one; the final tree
matches pristine on every touched file. **One of the twenty-one made a suite die rather than redden
a row — S21 — and the row it should have reddened was rewritten because of it**; the other twenty
each produced a named `FAIL` row and a `RESULT:` line. S1–S19 are headless; S20–S21 are the
display arm.

| # | the respelling | rows reddened |
|---|---|---|
| S1 | `emitorder 50` → `15` ("put tf just after dc") | core **AG1 AG2 TF1 TF4b** |
| S2 | `tmpl {tf @out @insrc}` → `{tf @insrc @out}` | core **TF2 TF2b TF4 TF4b** |
| S3 | `out` `required 1` → `0` | core **TF3** |
| S4 | `plots`' `vectors` → `…::tf_vector_names` (a rename) | simcaps **TV6** |
| S5 | `tf_vectors` keeps the source's own case | simcaps **TV4 TV5 TV6** |
| S6 | `output_impedance_at_V(` → `…_at_v(` — *the apt 45.2 spelling* | simcaps **TV4 TV5 TV6** |
| S7 | the malformed output is `blocked`, not `fatal` | preflight **PF227d PF227e** |
| S8 | `foreach n [lrange $d 1 end]` → `[lrange $d 1 1]` | preflight **PF227j** |
| S9 | one sentence for both input-source failures | preflight **PF227h** *(see below)* |
| S10 | an `i()` output accepts any independent source | preflight **PF227g** |
| S11 | **add `viewrank 0`** — PLAN.md Stage 5's own text | core **TF5** |
| S12 | add `seed_enabled 0` | core **R1 AG3 AG4 TF6** |
| S13 | `kind outvar` → `kind text` | core **GR8** |
| S14 | drop `tf_out` from `needs` | preflight **PF227b c d e g j** |
| S15 | `out_decompose` stops refusing `i(a,b)` | simcaps **TV2** |
| S16 | the `v`/`i` prefix matched case-sensitively | simcaps **TV1** |
| S17 | `out_decompose` never registered as a hook | simcaps **TV3** + preflight **PF227b c d e g j** |
| S18 | `role analysis` → `role probe` | core **TF1 TF2 TF2b TF3 TF3b** |
| S19 | every voltage output reported (refuses *everything*) | preflight **PF227a PF227h PF227j** |
| S20 | `role analysis` → `role probe` (run against the widgets) | dialogs `:99` **G2tf** × 4 |
| S21 | `insrc` `required 1` → `0` | dialogs `:99` **G2tf** (the refusal row) |

S11 was re-run after `tfvr`'s five required hooks were changed to borrow ngspice's (`ag_five`) instead of pointing at an unrelated proc, and still reddens **TF5** alone.

### The one that KILLED a suite, and the row rewritten because of it

**S21's first attempt did not redden a row — it killed the file at 65 of 271.** With `insrc` no
longer required, OK **commits and closes** the dialog, so the row's
`[$top.chana.status cget -text]` raised `invalid command name ".ase5.chana.status"` and the suite
printed `UNEXPECTED ERROR` and `OVERALL: notok`.

That is the weaker result the brief warns about, and the Stage 3 receipt already prescribes the fix:
*"where it is cheap, call the proc inside the **row's own** `catch` and assert the return code."* The
row now reads the status line inside its own `catch`, records `winfo exists` as an ordinary value,
and its cleanup `catch`es the cancel for the same reason. Re-run: **1 FAILED (270 passed)**, the row
named. The reason is written beside it, because the next person to touch that row will otherwise
take the `catch` for defensive padding and remove it.

### The one that survived, and the row written because of it

**S9 passed against PF227h as first written.** The row's last element asserted only
`[tfs $TFPN 0] ne [tfs $TFPT 0]` — that the two sentences differ. Both sentences carry the name the
user typed (`'Vnope'`, `'R1'`), so a predicate answering **one** sentence for both conditions still
produces two different strings, and the row was satisfied by it.

Rewritten to compare **clause by clause**: each distinguishing clause asserted present in its own
sentence and **absent from the other** (`not an independent source` in one and not the other, `this
circuit has no` in one and not the other). S9 re-run against the strengthened row reddens it:
`got 'tf_insrc 1 tf_insrc 1 0 0 1 1' want 'tf_insrc 1 tf_insrc 1 1 0 1 0'`.

This is the Stage 3 lesson arriving again: *a test that asserts a refusal is satisfied by a door that
refuses everything*, and its mirror — **a test that asserts two answers differ is satisfied by two
answers that differ for a reason the row does not care about.**

### The three rows that exist because a sabotage demanded them

* **TF5b** — S11 (the plan's `viewrank 0`) reddens TF5, but TF5's first three answers are also what a
  registry with **no `tf` entry at all** would give. TF5b registers a fixture backend whose `tf`
  carries a viewrank and shows the answer changing, so TF5 measures the key and not the absence.
* **PF227a** — S19 is the *"refuses everything"* discriminator. Without a row asserting that a
  runnable `tf` row says **nothing**, every PF227 row is satisfied by a predicate that reports on
  every deck.
* **PF227g**'s `I1` half — S10. `R1` alone does not discriminate, because a resistor is not in
  `facts sources` at all; only a current source, which **is**, can tell *"is this a voltage source"*
  from *"is this an independent source"*.

---

## What Stage 5 learned that binds later stages

**A general mechanism a plan assumes is not a mechanism until someone greps for it.** `{build
<proc>}` reads like shipped infrastructure in `PLAN.md` — it is in the grammar block of §1c, beside
three sigils that ARE shipped, and three of Stage 5's own entries spend it. It does not exist.
Stage 1's receipt does not mention dropping it, so nothing anywhere records the gap; the only way to
find it is to open `ase::analysis_expand` and look. **Before building on a plan's mechanism, grep for
its implementation** — and when a stage silently drops one, say so in that stage's receipt.

**A key whose meaning is "a surface prefers this" has to be checked against the surface, not against
the registry.** `viewrank 0` is defensible from inside the registry: `tf` emits, `tf` produces data,
so the type list's stated reason for withholding it does not apply. It is refuted one layer out, by
what `ase::plot_sim_type`'s answer is **spent on** — a `strcmp` in `src/save.c` against six literal
plot names. **A registry key is only as true as the consumer at the far end of it**, and the
registry's own comment is not that consumer.

**What a plan writes as a literal is sometimes a template, and the tell is that it names a node.**
Two of TF's three vector names contain the user's own circuit in them. The plan's three literals came
from one transcript of one deck, which is how a template gets written down as a constant — and a
Value-column probe built on them would have found one vector of three.

**A severity has to track what the checker can KNOW, not what the simulator does.** Issue 1423's
static demotion is a blanket rule, and this stage is the first predicate where it is right about one
finding and false about another in the same `switch` arm. The dividing line is not severity and not
how loudly ngspice complains — both input-source failures are a hard rc 1 abort and stay `caution`
— it is **whether an `.include` could change the answer.** A syntax error is the class where it
cannot, and `fatal`'s exemption from the demotion is what lets that be said.

**Measure the device classes before writing a rule about device classes.** `tf`'s `i()` form works
only for a voltage source, and the obvious reason — "nothing else has a branch current" — is
**false**: `i(L1)` is a perfectly good branch current everywhere else in ngspice. Writing the rule
from the argument would have produced a correct predicate resting on a wrong reason, which the next
person extends in the wrong direction. And a current source is the discriminating fixture, because a
current source **is** an independent source: the near-miss predicate passes it silently at rc 0.

**A GUI row that reads a dialog widget after pressing OK must guard the read.** The one change the
row exists to catch is the one that makes OK *succeed*, and a succeeded OK destroys the toplevel the
row is about to interrogate. So the sabotage that should have reddened the row killed the file. The
`catch` is not defensive padding; it is the difference between a named row and a line number.

---

## What I did NOT ship, and why

* **The five-field structured output picker** (`outkind`/`outnode`/`outref`/`outsrc`) — blocked on
  `{build <proc>}`, which Stage 1 did not ship. Correction C43. Implementing the escape here would
  collide with the `sens` crew, which needs the same one in the same stage.
* **`ase::ui::resulttable`, the s-plane scatter and the `.sens` picker** — `pz`'s and `sens`'s, not
  `tf`'s. `src/ase_window.tcl` is **untouched** by this commit.
* **The Value column showing the three numbers** (the plan's headline #2). `plots` and `results` are
  **read by nothing in this tree** — grepped both files for every spelling, no consumer — and Stage 6
  is where the adapter gets the hook that resolves them. The registry now carries the measured
  content, including `tf_vectors`, so Stage 6 inherits it rather than re-deriving it; the Value
  column is unchanged.
* **`viewrank`** — correction C44.
* **`seed_enabled`** — would add a fifth row to every fresh bench. ⚖ R4.
* **Any change to `analysis_emit_check`.** A malformed `out` is caught by the `tf_out` precondition,
  not by a new kind-validation arm in the schema. `values` (on `ac`'s `sweep`) is already not
  enforced there, so adding enforcement for one new kind would have been a schema change with one
  implementation — and the commit door's job is *"can this be emitted"*, not *"is this what the user
  meant"*.
* **`pz` and `sens`** — separate crews, separate commits.

---

## Rulings

⚖ **R9.** Two field labels — `Output`, `Input source` — and six precondition sentences. Recorded as
`owed.sh add rule 1426` at the moment it was incurred; the ledger was backed up first, per
`CLAUDE.md`. Batch with `pz`'s and `sens`'s.

**No `look` debt.** `src/ase_window.tcl` is untouched; the form is built by
`ase::ui::chana_field_row` from the registry, and both fields fall to the existing `default` entry
arm. Nothing new is drawn. (The *first* pixel deliverable of Stage 5 is `ase::ui::resulttable`, which
is `pz`'s and `sens`'s to file.)

**No `suite` debt beyond the display-arm run recorded above**, which was taken.

---

## For the driver

* T1 was **not** run by this crew (issue 0990 — the driver runs it solo).
* Nothing was committed, added, stashed or restored. `git status` shows **six modified** —
  `src/ase.tcl`, `tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_simcaps_0948.tcl`,
  `tests/headless/test_ase_preflight.tcl`, `tests/headless/test_ase_dialogs.tcl`,
  `doc/claude/issues/NUMBERING.md` — and **two new**,
  `doc/claude/issues/1426-the-transfer-function-was-listed-and-could-not-be-chosen.md` and this
  receipt. `src/ase_window.tcl` is **untouched**.
* The ledger was backed up to `/tmp/tfprobe/owed_backup_*` before the `owed.sh add rule 1426`,
  per `CLAUDE.md`'s one-ledger-every-clone paragraph. The entry is stamped to this clone.
* ⚠ **The one outstanding item is `test_ase_optier_0963` on `:99`**, a filed pre-existing stall
  that `CLAUDE.md` names, in a suite this commit does not touch and that `run_regression.tcl` runs
  headless only (ALL PASS, 103). Reported as a bounded `TIMEOUT`, not as silence.
* `NUMBERING.md`'s pointer was advanced **1426 → 1427** in the same edit as the entry.
* Suggested commit subject:
  `feat(1426): the transfer function was listed and could not be chosen`
