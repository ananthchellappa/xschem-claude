# Stage 5 — `pz`, the pole-zero analysis

**One commit, issue 1427.** `tf` is issue **1426** (commit `1e8e236e`); `sens` is a separate crew
and a separate commit of the same stage. Nothing here touches `sens`.

**Floors:** `test_ase_core` 360 → **376** · `test_ase_simcaps_0948` 170 → **175** ·
`test_ase_preflight` 164 → **177** · `test_ase_dialogs` display 271 → **278** (headless 37 unmoved).
**Forty-one sabotages.** Thirty-eight reddened a named row on the first attempt; **one survived** and
bought a row (S22); **two killed a suite** instead of reddening one and bought three hardenings
(S3, S33). Every one of the three was re-run against the row or hardening it bought, and reddens.

---

## What the stage was for

`pz` was one of the entries Stage 2 registered so the four-state grid could show that the analysis
exists:

```tcl
pz [dict create label pz baseline 1 registered 1 emit {{role probe tmpl {pz}}}]
```

No `fields`, no `emitorder`, no `role analysis` card — so `ase::analysis_renderable` answered 0, the
cell read `blocked/unrenderable`, and a hand-enabled row was refused at the gate. The user could see
that ngspice finds poles and zeros and could not ask it to.

---

## What shipped

### `src/ase.tcl` — the registry entry (inside `ase::backend::ngspice::analysis_types`)

```tcl
pz [dict create \
  label pz  baseline 1  registered 1  emitorder 60 \
  needs  {pz_shorted pz_nodes pz_devices pz_klu cider_klu} \
  fields {{name inp  kind node required 1 label {Input +}} \
          {name inn  kind node required 0 default 0 whenskipped 0 label {Input -}} \
          {name outp kind node required 1 label {Output +}} \
          {name outn kind node required 0 default 0 whenskipped 0 label {Output -}} \
          {name transfer kind mode required 0 default vol values {vol cur} label {Input type}} \
          {name mode kind mode required 0 default pz values {pz pol zer} label {Find}}} \
  emit   {{role analysis tmpl {pz @inp @inn? @outp @outn? @transfer? @mode?}}} \
  results {table {kind roots}} \
  plots  {{select {Pole-Zero Analysis} role table results table label pz \
           rootname ::ase::backend::ngspice::pz_root_kind} \
          {select {Distortion Operating Point} role opinfo results viewer \
           when {opt keepopinfo} label {pz operating point}}}]
```

(inside the `return [dict create …]` of `ase::backend::ngspice::analysis_types` — cite the proc, the
line is a hint: `src/ase.tcl:~14732`.)

### `src/ase.tcl` — one new adapter proc, **content** (D34–D37)

| proc | what it answers |
|---|---|
| `ase::backend::ngspice::pz_root_kind {name}` | `{pole <n>}`, `{zero <n>}` or `{}` — for `pole(1)`, for the rawfile's own `v(pole(1))`, and case-insensitively |

It is reached through the `rootname` key of the `plots` row, which is opaque to core. It is **not**
registered as a `register_backend` hook, because unlike `out_decompose` (any output variable) it
answers about one analysis's results and nothing in core asks that question yet.

### `src/ase.tcl` — one new core reader, **schema**

`ase::field_value {sim type row name}` — what a row will actually put in a slot: the stored value when
there is one, the field's **declared default** when there is not. It is `ase::field_emits`' answer for
a non-bool field, trimmed, so the precondition and the emitter agree by construction rather than by
hope. Row **PF228d** and sabotage **S23** are why it exists rather than four `ase::state_get`s.

### `src/ase.tcl` — four new predicates in `ase::needs_eval`

`pz_shorted` (fatal), `pz_nodes` (blocked → caution), `pz_devices` (fatal **or** caution), `pz_klu`
(fatal). All ordinary Stage 4 machinery; no new mechanism.

### `tests/headless/test_ase_dialogs.tcl` — section **G2pz**, seven widget rows

The half `test_ase_core` cannot assert. `pz` is the **first form in this tree that mixes three widget
classes** — four `kind node` entries and two `kind mode` comboboxes — so it is the first place a row
can say that a picker is a picker (`winfo class … TCombobox`, `cget -values`, a real `set` gesture).
Display arm only.

### Comment blocks

A `pz` block above `return [dict create …]` carrying the `{build}` refutation for this entry, the
positional-back-fill argument, the `viewrank` measurement, the `Distortion Operating Point`
transcript, the "the capitals are the fork's" **exception**, and why `plots` names a reader rather
than a vector list; a header on `pz_root_kind`; a header on `ase::field_value`; and one on each of
the four predicates.

**`src/ase_window.tcl` is untouched.**

---

## Every measured fact this rests on, and where it was measured

All ngspice measurements **2026-09-12**, scratch decks under `/tmp/pzprobe`, never a bench under
`sky130A/`. Binary 3 is `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`); binary 1
is `/usr/bin/ngspice` (`ngspice-45.2`). **Both were run for every line below, and the two binaries
agreed on every one.**

### 1. The syntax grid, with this tree's own `sim_status` guard wrapped round the analysis

```
pz in 0      out 0    vol pz  -> rc 0, REACHED-THE-END, pole(1) pole(2)
pz in 0      out 0    vol pol -> rc 0, REACHED-THE-END, pole(1) pole(2)
pz in 0      out 0    vol zer -> rc 0, REACHED-THE-END, NO VECTORS AT ALL
pz in 0      out 0    cur pz  -> rc 0, REACHED-THE-END, two poles, two zeros
pz in 0      in  0    cur pz  -> rc 0, REACHED-THE-END, four roots
pz nosuch 0  out 0    vol pz  -> rc 1, doAnalyses: The input signal is shorted on
                                       the way to the output
pz in 0      nosuch 0 vol pz  -> rc 1, the SAME sentence
pz in in     out 0    vol pz  -> rc 1, doAnalyses: Input is shorted
pz 0  0      out 0    vol pz  -> rc 1, doAnalyses: Input is shorted
pz IN 0      in  0    vol pz  -> rc 1, doAnalyses: Transfer function is unity
pz in 0      out out  vol pz  -> rc 1, doAnalyses: Output is shorted
pz in 0      in  0    vol pz  -> rc 1, doAnalyses: Transfer function is unity
pz 0  in     in  0    vol pz  -> rc 1, doAnalyses: Transfer function is -1
pz in 0      out 0    vol     -> rc 1, Error: no such parameter on this device or
                                       parameter is missing
pz in 0      out 0    pz      -> rc 1, the SAME sentence
pz in 0      out 0            -> rc 1, the SAME sentence, TWICE
pz in 0      out 0    vol bogus -> rc 1, the SAME sentence
.options klu + pz …           -> rc 1, Error: Pole/zero analysis is not (yet)
                                       supported with 'option KLU'. /
                                       Use 'option sparse' instead.
```

Four things came out of that grid and each of them is a design decision:

* **A missing node is not a floating node.** ngspice invents it and the root finder reports
  `The input signal is shorted on the way to the output` (`cktpzstr.c:213`), naming neither the node
  nor the fact that one was invented.
* **The in-is-out refusals are `vol`-only.** `pzan.c:117-125` guards both unity arms with
  `PZinput_type == PZ_IN_VOL`, and `pz in 0 in 0 cur pz` reaches the end at rc 0 with four roots.
  Refusing the current-input case would refuse the input admittance of a node, which is the reason
  `cur` exists.
* **An omitted picker is an abort, not a default.** `PZwhich = 0` makes `PZan` do *neither* search;
  `PZinput_type = 0` is treated as the current case. Both words must always be emitted — hence `@x?`
  slots with declared defaults rather than optional ones.
* **`IN` and `in` are the same node to `pz`.** Which is why both comparisons in `pz_shorted` fold
  (sabotages S31, S32).

### 2. A device `pz` cannot model is left out, silently

`cktpzld.c:29` calls `DEVpzLoad` **only when it is not NULL**, and nine families declare it NULL
(`cpl isrc jfet2 ltra mos6 soi3 tra txl urc`). Same two-pole RC, a line hung off a node, against the
same deck with the line deleted:

```
no line at all   -> pole(1) -2.61803e+06   pole(2) -3.81966e+05
+ Y1 (TransLine) -> pole(1) -2.61803e+06   pole(2) -3.81966e+05    rc 0
+ P1 (CplLines)  -> pole(1) -2.61803e+06   pole(2) -3.81966e+05    rc 0
+ T1 (Tranline)  -> rc 1  doAnalyses: Transmission lines not supported
+ O1 (LTRA)      -> rc 1  doAnalyses: The input signal is shorted on the way to
                          the output
+ U1 (URC)       -> rc 1  doAnalyses: device already exists, existing one being used
```

Byte-identical roots at rc 0 for the first two: **the analysis answered for a circuit the user does
not have.** `isrc`'s NULL is correct (an independent current source is an open in small signal);
`urc` fails for a different reason — it expands into internal R/C elements at setup and `pz` runs
`CKTpzSetup` **twice**, so the second pass collides; measured, the same deck under `op` works.

### 3. `PZinit`'s transmission-line check cannot fire for an LTRA

`pzan.c:96-106` looks up `"transmission line"`, then `"Tranline"`, then `"LTRA"`, and **stops at the
first name that is a compiled-in device type** rather than the first with instances. On any build
with `tra` compiled in, `i` is `tra`'s index and `CKThead[tra]` is NULL, so no error and no fall
through. **Measured:** an O-card deck does not print `Transmission lines not supported`; a deck with a
T card *and* an O card does, because the T card is what the one check that runs can see.

### 4. `xschem raw read` cannot find a `pz` plot

Against a raw carrying an `Operating Point` plot and a `Pole-Zero Analysis` plot, through
`./src/xschem --nogui --pipe -q --nolog`:

```
xschem raw read both.raw pz                   -> raw_read(): no useful data found
                                                 ... or no "pz" analysis        -> 0
xschem raw read both.raw op                   -> sim_type=op                    -> 1
xschem raw read both.raw {Pole-Zero Analysis} -> sim_type=Pole-Zero Analysis    -> 1
xschem raw read both.raw {Operating Point}    -> no useful data found           -> 0
```

`src/save.c`'s `read_dataset()` maps six named `Plotname:` records to a type and then falls through
to an exact `strcmp` against the plot name itself. `pz` is in neither set.

### 5. `keepopinfo` really does write `Distortion Operating Point`

`.options keepopinfo`, then `setplot`, on **both** binaries:

```
Current pz1   * keepopinfo pz plots (Pole-Zero Analysis)
        op1   * keepopinfo pz plots (Distortion Operating Point)
        const Constant values (constants)
```

### 6. There are no capitals to fold — the one place `tf`'s C46 does not reach

Same deck written by both binaries. `Variables:` carries `v(pole(1))` and `v(pole(2))` on **both**,
byte-identical; the only difference anywhere in either header is `Command: ngspice-46+` vs
`Command: ngspice-45.2`. `pzan.c:151`/`:155` build the names with `sprintf(name, "pole(%-u)", i+1)`.

### 7. `mos6` shares the silent defect, and is deliberately not covered

Same topology, `.model nm6 nmos level=6` vs `level=1`: level 6 aborts (`The input signal is shorted
on the way to the output`), level 1 answers `pole(1) = -1.00000e+06`. `mos6init.c:51` is
`.DEVpzLoad = NULL`. Not shipped — see *What I did NOT ship*.

### 8. End to end, on both binaries

`ase::backend::ngspice::render_deck` against a scratch library with an explicit `rundir`
(`/tmp/pzprobe/e2e`), a state carrying `{type op enabled 1}` and `{type pz enabled 1 inp in outp
out}`. The deck emits

```
op … remzerovec … write …/pzcell_ase.raw
pz in 0 out 0 vol pz … remzerovec … write …/pzcell_ase.raw
```

**rc 0 on the fork and rc 0 on apt 45.2**, two `Plotname:` records in one raw. Read back through
ASE-L's own readers, identically from both binaries' files:

```
ase::cap_raw_plots       -> {{Operating Point} 1 {v(in) v(mid) v(out) i(v1)}}
                            {{Pole-Zero Analysis} 1 {v(pole(1)) v(pole(2))}}
ase::raw_content_verdict -> ok 1 constants 0 appended 0 plotname {Operating Point} …
ase::plot_sim_type       -> op   (pz has no viewrank, so op still wins)
```

---

## What PLAN.md Stage 5 said that the tree refuted

This is the batch's tenth through thirteenth corrections (`tf` took C43–C47).

### C48 — `{build <proc>}` buys `pz` nothing, so its absence costs `pz` nothing

`PLAN.md` spells this entry `{pz {build ase::backend::ngspice::an_pz_nodes} @transfer @mode}`. Issue
1426 found that Stage 1 shipped `@x` / `@x?` / `@x!` and **no `build` arm at all**. The `tf` receipt
already predicted this half — *"`pz` needs it for nothing at all"* — and the implementation confirms
it: `pz NODE1 NODE2 NODE3 NODE4 {cur|vol} {pol|zer|pz}` is six space-separated words and the slot
grammar joins tokens with a space, so **four node fields are the four node tokens**. The missing
mechanism is still missing; this entry does not want it. **`sens` still does.**

### C49 — `pzan.c:92-128` is cited for a guarantee it does not give

`PLAN.md`'s `pz_devices` is *"no family lacking `DEVpzLoad`, and no transmission line
(`pzan.c:92-128`)"*, a single `blocked`. Measurements 2 and 3 split it in two:

| family | ngspice's behaviour | ASE-L |
|---|---|---|
| `T` (Tranline) | refused by `PZinit`, rc 1 | `fatal` |
| `O` (LTRA) | **not** refused by `PZinit`; aborts later with a message about the input being shorted | `fatal` |
| `U` (URC) | aborts, `device already exists` | `fatal` |
| `Y` (TransLine), `P` (CplLines) | **rc 0, silently absent from the matrix** | `caution` |

Neither `blocked` nor one verdict. The plan's single sentence would have been wrong about two of the
five families in the direction that matters most: it would have called a silent wrong answer a
refusal.

### C50 — `plots`' vector key names a READER here, not a predictor

`tf`'s `plots` row names a proc that computes its three vector names from the row (C45). A `pz` row
cannot know any of its names: `n` is whatever the root finder converged on, and **measured, the same
row that gives two poles gives zero zeros at rc 0**. Declaring a `vectors` key would give one key two
meanings across two entries of the same registry, so the entry declares **none** and ships
`pz_root_kind` under a `rootname` key. Row **PZ8** asserts the absence; rows **PV1–PV4** pin the
reader.

### C51 — `tf`'s capital-folding warning does not reach `pz`

C46 records that the fork writes `v(Transfer_function)` where apt 45.2 writes
`v(transfer_function)`, so a case-sensitive reader is wrong on the binary a downloading user has.
Measurement 6: `pz`'s names have no capitals at all and the two rawfiles are byte-identical.
`pz_root_kind` is still case-insensitive, because that costs nothing and the measurement is about two
binaries rather than about all of them — but the **reason** is different, and writing C46's reason
here would have been a copied argument rather than a measured one.

### And the third case of the static demotion (not a plan claim — a Stage 4 mechanism meeting a new counter-example)

Issue 1423 lowers every `blocked` to `caution` on a static pass and appends *"(read from the netlist
text, which cannot see inside an `.include`)"*. C47 found that right for one finding in `tf_out` and
false for another. `pz` adds a third case neither had a name for:

| finding | verdict | why |
|---|---|---|
| a node is not in the circuit | `blocked` → `caution` **with** the caveat | an `.include`d file really could define it |
| the row's own two node boxes hold the same word | `fatal`, no caveat | no include can change what the user typed |
| **this deck CONTAINS a `Y` card** | `caution`, no caveat | **the static pass PROVED it** — an `.include` can only ADD devices, never remove the card just read |

A **positive** finding is not weakened by what the pass could not see, so the caveat would be wrong
about it in the opposite direction from the second row. Row **PF228h** is that sentence as an
assertion. **And the severity still tracks what the static pass can KNOW, never how loudly ngspice
complains** — every failure in measurement 1 is a hard rc 1 abort and the node check is still not
`fatal`.

---

## Suites moved, before → after, per arm

| suite | headless | display (`:99`) |
|---|---|---|
| `test_ase_core` | 360 → **376** | 360 → **376** |
| `test_ase_simcaps_0948` | 170 → **175** | 170 → **175** |
| `test_ase_preflight` | 164 → **177** | 164 → **177** |
| `test_ase_dialogs` | 37 → 37 | 271 → **278** |
| `test_ase_persist` | 44 → 44 | 148 → 148 |
| `test_ase_optier_0963` | 103 → 103 | `TIMEOUT` (pre-existing, see *For the driver*) |

New sections: **PZ** in `test_ase_core.tcl`, **PV** in `test_ase_simcaps_0948.tcl`, **PF228** in
`test_ase_preflight.tcl`, **G2pz** in `test_ase_dialogs.tcl`. All four floor paragraphs raised in the
same commit.

**Seven existing `test_ase_core` rows moved rather than being added**, every one expected and every
one named in that file's floor paragraph:

| row | before | after | why |
|---|---|---|---|
| `AG1` | `{op dc ac tran tf noise pz …}` | `{op dc ac tran tf pz noise …}` | `pz` earned `emitorder 60` |
| `AG2` | split at five, six rank-less | split at **six**, five rank-less | same |
| `EM7` | six types with no `fields` | five | `pz` has fields |
| `CP6` | `6` probe-only | `5`, and `pz` asserted to HAVE fields | same |
| `GR8` | eight declared kinds | nine — **`node` added deliberately** | a pz row names four bare nodes and `0` is ground, not the integer zero |
| `TF3b` | used `pz` as its unrenderable control | uses `noise` | `pz` is renderable now |
| `D7e3` | used `pz` as its second unrenderable type | uses `pss` | same; `pss` is the furthest away (`baseline 0` **and** `#ifdef`-gated) |

⚠ **`R1`, `AG3`, `CP1`–`CP4` did not move.** `pz` declares no `seed_enabled`, so `ase::state_default`
still seeds exactly four rows and the **104 committed `.state` files are untouched** — ⚖ R4's
recommended answer continuing to ship by construction.

⚠ **`test_ase_preflight` rows PF222a-e / PF222h-j are green**, as the brief required. They rest on
`noise` being unrenderable and `noise` is untouched — which is also why `TF3b`'s new control is
`noise` rather than a type that will move again: the day it changes, those rows move too and this one
is not the only warning.

---

## The sabotage table

Forty-one sabotages, every one a plausible respelling of `src/ase.tcl` rather than a break. Restore
was `cp` from `/tmp/pzprobe/pristine2/` with an md5 compare after **every** one; the final tree
matches pristine on every touched file (`66d2f1ec…` for `src/ase.tcl`). S1–S32 are headless;
S33–S37 are the display arm on `:99`.

| # | the respelling | rows reddened |
|---|---|---|
| S1 | `emitorder 60` → `15` ("put pz just after dc") | core **AG1 AG2 PZ1 PZ4b TF1** |
| S2 | template swaps `inn` and `outp` | core **PZ2 PZ2b PZ4 PZ4b** |
| S3 | `inn` loses `whenskipped 0` (keeps its default) | core **PZ2c** *(see below — first attempt KILLED the suite)* |
| S3b | `inn` loses **both** `default 0` and `whenskipped 0` — the silent positional shift | core **PZ2 PZ2b PZ2c PZ4 PZ4b** |
| S4 | `inn` loses `default 0` (keeps `whenskipped`) | core **PZ2c** |
| S5 | `mode` default `pz` → `pol` | core **PZ2 PZ2b PZ2e PZ4 PZ4b** |
| S6 | `transfer` default `vol` → `cur` | core **PZ2 PZ2b PZ2e PZ4 PZ4b** |
| S7 | `outp` loses `required 1` | core **PZ3** |
| S8 | `pz_root_kind` stops stripping the rawfile `v()` wrapper | simcaps **PV2 PV4** |
| S9 | `pz_root_kind` accepts any `name(digits)` | simcaps **PV3** |
| S10 | `pz_root_kind` matches case-sensitively | simcaps **PV1 PV2** |
| S11 | `select {Pole-Zero Analysis}` → `{Pole Zero Analysis}` | core **PZ8** |
| S11b | the same, measured against simcaps | simcaps **PV4** |
| S12 | the upstream mislabel "fixed" to `Pole-Zero Operating Point` | core **PZ8** |
| S12b | the same, measured against simcaps | simcaps **PV5** |
| S13 | **add `viewrank 5`** | core **PZ5** |
| S14 | add `seed_enabled 0` | core **R1 AG3 AG4 PZ6 TF6** |
| S15 | `kind node` → `kind real` on `inp` alone | core **PZ2e PZ3** |
| S15b | `kind node` → `kind real` on **all four** | core **GR8 PZ2e PZ3** |
| S16 | the `plots` row's `rootname` renamed | simcaps **PV4** |
| S17 | `needs` drops `pz_nodes` | preflight **PF228b PF228c** |
| S18 | `needs` drops `pz_shorted` | preflight **PF228d PF228e PF228f PF228j** |
| S19 | `needs` drops `pz_devices` | preflight **PF228g** |
| S20 | `needs` drops `pz_klu` | preflight **PF228i** |
| S21 | `pz_nodes` checks only the input node | preflight **PF228b** |
| S22 | `pz_nodes` stops skipping ground | **NOTHING** *(see below — the survivor)* |
| S23 | `pz_shorted` reads the ROW instead of the declared default | preflight **PF228d** |
| S24 | `pz_shorted`'s unity arms lose the `vol` guard | preflight **PF228f** |
| S25 | `pz_shorted` is `blocked`, not `fatal` | preflight **PF228d PF228e PF228j** |
| S26 | `pz_devices` calls the silent families `fatal` too | preflight **PF228g** |
| S27 | `pz_devices` trusts `PZinit` and only checks the `T` card | preflight **PF228g** |
| S28 | `pz_klu` fires whatever the option's value | preflight **PF228i** |
| S29 | `pz_nodes` reports on every deck (refuses everything) | preflight **PF228a d f g h i l m** |
| S30 | `pz_devices` reports on every deck (refuses everything) | preflight **PF228a d f g i l m** |
| S31 | `pz_shorted` compares case-sensitively | preflight **PF228e** |
| S32 | `pz_shorted`'s unity arms compare case-sensitively | preflight **PF228e** |
| S33 | the `Find` picker declared `kind node` (a text box) | dialogs `:99` **G2pz** × 3 *(twice KILLED the suite first)* |
| S34 | `outp` loses `required 1` (the OK that COMMITS and CLOSES) | dialogs `:99` **G2pz** (the refusal row) |
| S35 | the four node labels lose their `+` and `-` | dialogs `:99` **G2pz** |
| S36 | `mode`'s values reordered to `{pol zer pz}` | dialogs `:99` **G2pz** |
| S37 | `outn` dropped from the field table entirely | dialogs `:99` **G2pz** × 3 |

### The one that SURVIVED, and the row written because of it

**S22 — deleting the `$n eq {0}` ground skip from `pz_nodes` — left `test_ase_preflight` at ALL PASS
(176).** Every deck PF228a–PF228l uses writes node `0` on a card, so `ase::netlist_map` has it and the
lookup succeeds. The skip was doing nothing those rows could see.

It is still load-bearing, and the row proves it. **Measured:** `ase::netlist_facts` on
`V1 in gnd dc 1 / R1 in out 1k / R2 out gnd 1k` answers a node set with **no `0` in it**. Both
reference fields *default* to `0`, so without the skip the commonest pole-zero row there is —
`inp in outp out`, both references implicit — would be reported as naming a node the circuit has not
got. Row **PF228m** is that deck; S22 re-run reddens it alone.

This is the mirror of the tf crew's S9 lesson: *a predicate's guard is only tested by a fixture that
needs it*, and a fixture set that all looks the same makes a guard invisible.

### The two that KILLED a suite, and the three hardenings they bought

**S3's first attempt killed `test_ase_core` at 366 of 376** with `key "whenskipped" not known in
dictionary`. Row PZ2c read the field descriptor with a bare `dict get`, which is only legal while the
key is there — and the key's deletion is the exact change the row exists to catch. PZ2c, PZ2e and PZ8
now read through a `pzkey` helper that answers `ABSENT`; S3 re-run reddens **PZ2c** alone.

**S33 killed `test_ase_dialogs` twice.** First at 67 of 278 on `cget -values` (`unknown option` —
`-values` exists only on a combobox), which bought `g2pz_cget`. Then at 69 of 278 on
`$top.chana.form.mode set pol` (`bad option "set"` — an Entry has no `set`), which bought recording
the two picker gestures' **return codes** as ordinary values. S33 re-run reddens **three G2pz rows**
and the file survives at 275 passed.

Both are the weaker result the brief warns about, and both are the Stage 3 lesson arriving again:
*where it is cheap, call the thing inside the row's own `catch` and assert the return code.* The
comments beside all three say so, because the next person to touch them will otherwise read the
`catch` as defensive padding and remove it.

### Two rows that exist because a sabotage demanded them

* **PF228a** — S29/S30 are the *"refuses everything"* discriminators. Without a row asserting that a
  runnable `pz` row says **nothing**, every PF228 row is satisfied by a predicate that reports on
  every deck. (Inherited from PF227a rather than re-learned.)
* **PF228e**'s two mixed-case legs — S31/S32. Measured first: `pz IN 0 in 0 vol pz` is
  `doAnalyses: Transfer function is unity`, rc 1, on both binaries. Without those legs a
  case-sensitive comparison is green.

---

## What Stage 5's `pz` commit learned that binds later stages

**A plan's citation can be right about the file and wrong about the guarantee.** `pzan.c:92-128`
really does contain a transmission-line check, and `PLAN.md` rests a precondition on it. The check
cannot fire for an LTRA on any build with `tra` compiled in, and never looks at `txl`, `cpl` or `urc`
at all. **Read the lookup, not the label** — `CKTtypelook` answers about the device *table*, not about
the *circuit*, and the difference is five families.

**"Silently ignored" is a different verdict from "refused", and the plan collapsed them.** Two of
`pz`'s five offending families give rc 0 and byte-identical roots to a deck that does not contain the
device. A single `blocked` for all five would have called that a refusal — which is the one thing the
user would never find out was wrong, because the run *worked*.

**The static demotion has three cases, not two, and the third is the cheap one.** A finding of the
form *"this deck contains X"* is **proved** by a pass that cannot see everything, because an
`.include` can only add. Neither issue 1423 nor issue 1426 had a name for it; the rule as written
only reaches `blocked`, so nothing was wrong — but nothing said so either, and the next predicate
that writes a positive finding as `blocked` will get a caveat that is false in a new direction.

**When a second entry reaches the same conclusion as the first, check whether it reaches it for the
same reason.** `pz` has no `viewrank` and `tf` has no `viewrank`, and copying `tf`'s paragraph would
have been defensible and incomplete: `pz` has a **second** reason — its plot is a root list with no
scale vector, so even a working mapping would open the waveform viewer on something that is not a
sweep. Conversely `tf`'s capital-folding warning reads like a general fact about the two binaries and
is not: `pz`'s names have no capitals, and an inherited warning would have been a copied argument.

**A key's meaning must survive its second entry.** `tf`'s `plots` row names a proc that *predicts*
three vector names. Using the same `vectors` key for `pz` — whose names the run decides — would have
made one key mean "the names" in one entry and "some names, maybe" in the other. Two keys is cheaper
than one key with two meanings, and the measurement that forced it is one line: the same row that
gives two poles gives **zero** zeros at rc 0.

**A form value and a form default are two different questions, and a precondition wants the second.**
`ase::state_get $row inn` answers the empty string for the commonest pz row there is, because the
default is what gets emitted and nothing is stored. A shorted-input check built on the row reads `in`
against `{}`, never fires, and lets ngspice answer with a message that names no field. `ase::field_value`
exists so the predicate and the emitter cannot disagree.

---

## What I did NOT ship, and why

* **`ase::ui::resulttable`, the s-plane scatter and the `.sens` picker** — Stage 5b. `src/ase_window.tcl`
  is **untouched**. The registry carries the measured destination (`results table`, `role table`) so
  the surface can be built against it rather than re-deriving it.
* **The Value column / result table showing the roots** (`PLAN.md`'s headline #3). `plots` and
  `results` are **read by nothing in this tree** — grepped both files for every spelling, no consumer
  — and Stage 6 is where the adapter gets the hook that resolves them.
* **`viewrank`** — correction C51's neighbour; measured twice over.
* **`seed_enabled`** — would add a fifth row to every fresh bench. ⚖ R4.
* **The Hz conversion.** A root's value is an s-plane **radian frequency**: `-2.61803e+06` is
  416.7 kHz. Dividing by 2π and labelling it is the *surface's* job and the surface does not exist;
  `pz_root_kind`'s header says so in capitals so Stage 6 cannot miss it.
* **The model-level families (`mos6`, `jfet2`, `soi3`).** They share the silent-omission defect —
  measured, `level=6` aborts where `level=1` answers. They are selected by a `level=` number and
  ngspice's level-to-device map is a per-build decision (levels 8 and 49 split between `bsim3` and
  `bsim3v32` by a `version=` parameter), so a rule keyed on a level would be a claim about **one**
  binary's mapping that ASE-L cannot verify. The device **letter** is a claim about the netlist. The
  measurement and the reason are in `pz_devices`' comment so the next crew inherits them.
* **A fix to `ase::netlist_facts`' letter table.** It labels `p` as `port`; ngspice's `P` card is
  `CplLines` (`inp2p.c:46` LITERRs *"Device type CplLines not supported by this binary"*) and
  ngspice's RF port is a **voltage source with `portnum=`**, which is why the same proc reads
  `portnum` off `v` cards. The label is read by other predicates and is not this stage's to change;
  `pz_devices` names the **device** rather than the family key, and its comment records the mislabel.
* **Any change to `analysis_emit_check`.** A shorted or missing node is caught by a precondition, not
  by a new kind-validation arm. The commit door's job is *"can this be emitted"*, not *"is this what
  the user meant"*.
* **`sens`** — a separate crew, a separate commit. ⚠ **It will have to move `EM7`, `CP6`, `AG1`/`AG2`
  and `D7e3` again**, and `D7e3`'s comment now says what to do when `pss` runs out: a fixture backend,
  not a fourth shipped type.

---

## Rulings

⚖ **R9.** Six field labels — `Input +`, `Input -`, `Output +`, `Output -`, `Input type`, `Find` — the
two pickers' value sets (ngspice's own words, shown verbatim), the **ground default** on the two
reference nodes, and **eight precondition sentences with their eight remedies** (sixteen new
user-facing strings in all). Recorded as `owed.sh add rule 1427` at the moment
it was incurred; **the ledger was backed up first** to `/tmp/pzprobe/owed_backup_20260912_102925`, per
`CLAUDE.md`'s one-ledger-every-clone paragraph, and the entry is stamped
`repo:/home/analog/dev/xschem-claude`. Batch with 1426's and `sens`'s.

**No `look` debt.** `src/ase_window.tcl` is untouched; the form is built by
`ase::ui::chana_field_row` from the registry — the four nodes fall to the existing default entry arm
and the two pickers to the existing `kind mode` combobox arm. Nothing new is drawn. The first pixel
deliverable of Stage 5 is `ase::ui::resulttable`, which is Stage 5b's to file.

**No `suite` debt beyond the display-arm runs recorded above**, which were taken on `:99`.

---

## For the driver

* T1 was **not** run by this crew (issue 0990 — the driver runs it solo).
* Nothing was committed, added, stashed or restored. `git status` shows **six modified** —
  `src/ase.tcl`, `tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_simcaps_0948.tcl`,
  `tests/headless/test_ase_preflight.tcl`, `tests/headless/test_ase_dialogs.tcl`,
  `doc/claude/issues/NUMBERING.md` — and **two new**,
  `doc/claude/issues/1427-the-pole-zero-analysis-was-listed-and-could-not-be-chosen.md` and this
  receipt. `src/ase_window.tcl` is **untouched**.
* The whole ASE family (29 suites) was re-run on **both arms** through `run_suites.sh`, every arm
  `timeout`-bounded:
  * **headless** (`--nogui`, `SUITE_TIMEOUT=400`): **27/27 passed, 2 self-skipped**
    (`test_ase_dirty`, `test_ase_log_seam_0207` — both need an X connection).
    `test_ase_optier_0963` headless is **ALL PASS (103)**.
  * **display `:99`** (`SUITE_TIMEOUT=300`): **27/29 passed**, and both non-passes are named:
    * `test_ase_log_seam_0207` — **my invocation, not a regression.** It asserts on the action log,
      which exists only under `--logdir`; its own first row is literally
      `PS0 action log open (needs --logdir)`, and `full_audit.sh:85` has it on `logdir_tests` for
      exactly this reason. Re-run as `run_suites.sh --logdir test_ase_log_seam_0207` →
      **ALL PASS (49 checks)**. (`run_suites.sh --logdir` writes to a `mktemp -d`, so the user's own
      `/tmp/Xschem.log.N` is untouched — issue 1359's scar does not apply.)
    * `test_ase_optier_0963` — **`TIMEOUT` after 300 s, reported as a named outcome rather than as
      silence.** This is the filed pre-existing stall `CLAUDE.md` records by name (*"86 of 103 rows,
      stops after row N3"*), which the `tf` crew hit in the same place. Nothing in this commit touches
      `optier`, `render_deck`'s op-tier legs, or anything that suite drives, and its **headless** arm —
      the one `run_regression.tcl` actually runs, since its case list runs this suite headless only —
      is **ALL PASS (103)** before and after. ⚠ Unlike the `tf` run, the bound came from
      `run_suites.sh`'s own per-arm `timeout` rather than a hand-placed prefix, so there was no
      orphan: `pgrep -fa src/xschem` after the run is empty.
* `NUMBERING.md`'s pointer was advanced **1427 → 1428** in the same edit as the entry.
* Suggested commit subject:
  `feat(1427): the pole-zero analysis was listed and could not be chosen`
