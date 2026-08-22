# Spec — operating-point annotation on the schematic

*Put simulation results — node voltages and per-device operating-point
parameters — on the schematic, under three keys, with the displayed parameter
list editable by the user and portable across PDKs.*

> ⚠ **THERE IS STILL NO SAVE-CARD GENERATOR.** S3 failed three times (issues
> **0436**, **0442**, **0443** — ⚠ 0443 is a claimed number carried by
> `doc/claude/issues/0443-attempt-3-interrupted.patch` alone, with no issue
> `.md`; see issue **0487**) and S4 is deferred with it, so the feature
> cannot put real device numbers on a schematic without a hand-written deck:
> on a raw produced without hand-written `.save` cards, every `params` row and
> every `derived` row that depends on one renders **blank**. This is the single
> most important fact about the current state of this feature. Proven at file
> level: `src/op_annot.tcl` defines 17 procs and `op_annot::save_cards` is
> **absent** — the only occurrence of the name is the comment at
> `src/op_annot.tcl:61` telling a future author what to read before adding it.
>
> ⚠ **Not *every* row — corrected 2026-08-21 by S12b**, whose adversary refuted
> the earlier blanket wording here and in `waveform_subsystem_reference.md` §6.
> `pinexpr` rows are pin **voltages**, which the implicit save-everything already
> carries (§4.2: "quantities that need no save card at all"; `op_annot.tcl:696`),
> so they render on an ordinary raw with no cards written by anyone. Measured on
> a one-FET fixture with a node-voltages-only raw: **2 of 10 rows populated**
> (`vgs`, `vds`), eight blank. Overstating the blocker is the same class of
> error as understating it — and it hides the one thing that works today.

Status: **S1, S2, S5, S6b, S7, S8, S9b, S10b and S11 landed; S3 refuted and
reverted three times (S9 once), S4 deferred with it; S12 attempted 2026-08-21
and NOT completed, S12b (2026-08-21) completed its remaining deliverable** —
S12's implement agent produced no change at all and only its write-up survived
(issues **0484**/**0485** filed, plan numbering reconciled, this block); S12b
rewrote `waveform_subsystem_reference.md` §6 and corrected this spec. Branch `annotate`. *(This line was stale through S9b
and S10b; corrected by the S11 write-up, then by the S12 write-up. "S6b" is the
commit's own spelling — `1f1b8125` — and is now used throughout in preference
to the earlier "S6".)*
Plan of atomic steps: `doc/claude/suggestions/next_session_prompt_op_annotation.md`.

**S1** (2026-08-16) delivered `src/op_annot.tcl` — the namespace, `register` /
`descriptor` / `type` / `devpath` / `vector`, sourced from `src/xschem.tcl` —
plus `tests/headless/test_op_annot.tcl` (32 checks). Implementing it corrected
four things this spec asserted: the `devpath` templates in §4.2 (issue 0422),
the save-card side of **I1** (rule **R4** and §5 below), **I5**'s claim about
user rcs, and §8's cross-PDK test. Each correction is marked *measured* where it
appears.

**S6** (2026-08-19) delivered the first user-visible piece: `annotate_params.sym`
in **both** device library trees, `op_annot::place_annotator`, and one
`Simulation > Graphs > Add device OP annotator` item. It corrected §4.4's
symbol text (the missing space before `]` — every earlier revision of this spec
shipped a spelling that renders `?` on every row) and added §4.4's two-tree
requirement. It landed with issues **0446** and **0447** explicitly ACCEPTED, not
closed — see §5 I3 and both issue files; the step's status is **E** for those two
questions and for the pixel deliverable.

**S8** (2026-08-19) delivered the three keys — `6` / `Ctrl-6` / `Alt-6` bound in
`src/cadence_style_rc`, body in the new `utils/annot_mode.tcl` — plus the repair
of both shipped **Annotate Operating Point** menu items, which S7 had left
producing a loaded raw and a dark annotator. It corrected §4.6's claim that the
per-PDK rcs are copies (they delegate; one bind block covers all three PDKs) and
added §4.6's guard, message-matrix and `-hold` requirements, all measured. Status
**E** for the `annot_show` default (issue **0457**) and the pixel deliverable.
Filed and not fixed: **0460** (the descriptor clause names decorations),
**0461** (a specific load-failure reason is discarded), **0462** (a guard covered
only by wording rows). Fixed within the step: **0459**.

**S11** (2026-08-20) made the annotation **time-scrubbable without a graph**:
`xschem set cursor2_x <t>` now resolves cursor B directly against `xctx->raw`
when no rect on GRIDLAYER carries `flags & 1` — three C files, ~12 lines of
executable code, **zero Tcl**, because every consumer already reads
`xschem raw value <v> -1`. See §2.1 and the new §4.7. It corrected this plan's
long-standing anchor for the cursor arm (`scheduler.c:11847`, not `:11802`), and
refuted the idea that a `memset`-0 `Graph_ctx` is a neutral one — landmine 13.
Status **E** for issue **0479** (an out-of-range cursor holds the endpoint
silently, on both paths, deliberately). Filed and not fixed: **0477**, **0478**,
**0480** (three defects of the *graph* path, each pinned by a row asserting the
current wrong behaviour), **0481** (three sabotage variants reddened nothing),
**0482**, **0483**.

Related:
`doc/claude/code_analysis/waveform_subsystem_reference.md` §6 (the existing
back-annotation write-up), `doc/claude/specs/cadence_bindkey_plan.md` (the key
profile this adds to), `doc/claude/specs/ase_l.md` (the deck renderer that must
carry the generated save cards), `ihp-sg13g2/sg13g2_procs.tcl` (the working
single-PDK prototype this generalizes).

---

## 1. The problem

Four things a user wants on the schematic after a run:

| # | want | today |
|---|---|---|
| A | DC operating-point node voltages | works, on labelled nets only |
| B | node voltages at a chosen transient timepoint | works, needs a graph object on the canvas |
| C | per-device OP info (vgs, id, gm, gds, vdsat, …) from a DC OP | display machinery exists; **the data is not in the raw file** |
| D | the same at a transient timepoint | as C |

and three interaction requirements:

| # | want |
|---|---|
| E | `Ctrl-6` default info, `6` device OP info, `Alt-6` also node voltages |
| F | the user edits *which* parameters are shown, without editing symbols |
| G | it works on sky130, gf180 and IHP sg13g2, not just one of them |

C is the blocker, F is the design problem, G is what decides the shape of the
design.

---

## 2. What exists, precisely

### 2.1 The annotation value pipeline (C)

`xschem annotate_op [rawfile] [level] [sim_type]` (`scheduler.c` ~2329) loads a
raw via `extra_rawfile()` — trying `op`, then `dc` (Xyce writes OP as a one-point
DC sweep), then `tran` (point 0) — forces `live_cursor2_backannotate=1`, and
calls `update_op()`.

`update_op()` (`save.c:1988`) copies point 0 of every vector into
`xctx->raw->cursor_b_val[]` **and** publishes every vector into the Tcl array
`ngspice::ngspice_data`.

`backannotate_at_cursor_b_pos()` (`callback.c:1531`) does the same at an
arbitrary sweep position when graph cursor B moves, so every annotated number
follows the cursor live.

**⚠ AMENDED BY S11 (2026-08-20) — "when graph cursor B moves" *was* the whole
problem, and a graph is no longer required.** `xschem set cursor2_x <t>`
(`scheduler.c:11847`, **not** the `:11802` this plan quoted for months — that is
the `cadgrid` self-log) used to reach that function only through three
independent gates: a rect on GRIDLAYER, `rect[GRIDLAYER][`**`0`**`].flags & 1`,
and `graph_flags & 4`. With any one false it moved a global nobody read, so a
schematic with a transient raw loaded and **nothing plotted** — the ordinary
state after pressing `6` — was frozen at `update_op()`'s point 0 forever.
S11 added `backannotate_at_cursor_b_nograph()` (`callback.c`, §4.7): when no
rect on GRIDLAYER carries `flags & 1`, the cursor is resolved **directly against
`xctx->raw`**. The two unrepaired gates are issues **0477** and **0478**.

**The single value accessor**, and the one this spec builds on:

```tcl
xschem raw value <vector-name> -1     ;# value at the current annotation point
```

(**`scheduler.c:10344`** — ⚠ *re-measured by S12b on HEAD `479be885`; this line
asserted `:10312` through S11, which is an `extra_rawfile(3, …)` call in the
`raw loaded` neighbourhood, not the value accessor* — with point `-1` it falls
through to `cursor_b_val[idx]`,
i.e. the OP point or the cursor-B point, whichever is current.) `get_raw_index()`
already tries the name as-is, uppercased, lowercased, and `v(...)`-wrapped.

### 2.2 The display mechanisms (4 of them, all symbol-text based)

| # | form | where the name comes from | used by |
|---|---|---|---|
| D1 | `@spice_get_voltage` on a 1-pin symbol | the attached net | `lab_pin`, `lab_wire`, `ipin`, `opin`, `vdd`, `ngspice_probe` |
| D2 | `@spice_get_diff_voltage` on a 2-pin symbol | its two nets | `spice_probe_vdiff` |
| D3 | `@spice_get_node <literal raw name>` | typed into the symbol text | sky130 FET symbols (`id`, `gm`) |
| D4 | `tcleval([<proc> …])` | a Tcl proc | gf180 FET symbols, `device_param_probe`, `ngspice_get_value`, all IHP annotators |

Plus the bare tokens `@spice_get_current_<p>` / `@spice_get_modelparam_<p>` /
`@spice_get_modelvoltage_<p>` (`token.c:5163`, name built by `get_fqdevice()`
`token.c:4514`), which **do not work for any of the three PDKs**: those symbols
netlist as `X<name>` subcircuit wrappers, so the element prefix seen is `x` and
the generic branch emits `i(@x…[i])`. That is exactly why every PDK spells the
name out by hand.

> The parenthesised forms `@spice_get_modelparam_<p>(<dev>)` and
> `@spice_get_modelvoltage_<p>(<dev>)` are matched by the regex at `token.c:4646`
> and then silently produce nothing — only the `@spice_get_current` variants are
> implemented in that branch. Reserved-but-dead; see issue list.

### 2.3 The IHP prototype — the thing to generalize

`ihp-sg13g2/sg13g2_procs.tcl` already implements, for sg13g2 only, most of what
this spec asks for:

| piece | proc | what it does |
|---|---|---|
| hierarchy walk | `sg13g2_sch_expand` / `sg13g2_hier_sch_expand` (:345, :366) | descends the whole design with `no_draw`/`no_undo` set, visiting every instance |
| save-card emitter | `sg13g2_write_save_lines` (:304) | per FET, appends 10 `.save @n.<path><X><name>.n<model>[<p>]` lines; per NPN, 13 |
| deliverable | `sg13g2_save_params` (:425) + IHP menu (:604) | writes `<netlist_dir>/<cell>.save`, opens it in a text window; user `.include`s it by hand |
| display | `sg13g2_display_fet_params` (:449) | reads each vector with `xschem raw value <p> -1`, formats a block, adds derived `ft` and `gm/id` |
| carrier symbol | `sg13g2_pr/annotate_fet_params.sym` | `K {type=annotator template="name=annot1 ref=M1"}` + one text `tcleval([sg13g2_display_fet_params @ref])` |
| placement | IHP menu "Add FET param annotator" (:640) | places the annotator pre-filled with the selected instance's name |

What it does **not** do, and this spec must:

1. the parameter lists are hardcoded inside two Tcl procs — not user-editable;
2. every name is sg13g2-specific (`@n.` prefix, `n<model>` inner device, the
   `_5t` model-suffix strip) and the procs are `sg13g2_`-prefixed by design, so
   nothing is reusable by sky130 or gf180;
3. the annotator is a symbol the user places **one per device, by hand**;
4. the save cards land in a file the user must remember to `.include`;
5. no keys, no toggle, no interaction with `show_hidden_texts`.

### 2.4 The visibility switch

One global boolean: `show_hidden_texts` (`xctx->show_hidden_texts`, mirrored in
Tcl), gating texts whose attribute is `hide=true` (`HIDE_TEXT`, set in
`set_text_flags()` `actions.c:1121`).

> **⚠ CORRECTED BY S7 — THIS SECTION SAID "NINE" AND THEN LISTED TEN, AND THE
> TEN ARE NOT TEN COPIES OF ONE TEST.** Every downstream count in this spec and
> in the plan inherited the wrong number. Measured: `grep -n HIDE_TEXT src/*.c`
> returns exactly **ten** tests, and they split cleanly in two.
>
> * **Six** iterate a *symbol's* `symptr->text[j]` and mask
>   `(HIDE_TEXT | HIDE_TEXT_INSTANTIATED)` — `draw.c:868`, `draw.c:1131`,
>   `draw.c:10266`, `svgdraw.c:923`, `psprint.c:1205`, `select.c:709`.
> * **Four** iterate the *schematic's own* `xctx->text[i]` and mask `HIDE_TEXT`
>   alone — `draw.c:10616`, `svgdraw.c:1326`, `psprint.c:1698`, `actions.c:4796`
>   *(re-measured on HEAD `479be885` by S12b; the numbers this line carried
>   through S11 — 10556 / 1290 / 1664 / 4422 — have all drifted).*
>   The last carries `/* | HIDE_TEXT_INSTANTIATED */` commented out **in place**,
>   so the difference is deliberate and someone already thought about it.
>
> **That split *is* the meaning of `hide=instance`** — "hidden when this symbol
> is instantiated, visible while you are editing the symbol itself". Measured end
> to end through the real export path at `show_hidden_texts 0`: symbol texts
> visible `{none, op, voltage}` but top-level texts visible
> `{none, op, voltage, INSTANCE}`, identically in SVG and in PS. A helper with
> one fixed mask — the literal reading of §4.5's original wording — silently
> flips `hide=instance` for **630 occurrences across 244 tracked files** and
> breaches I7 on the first line written. See §4.5 for the signature that shipped.

It is all-or-nothing and it hides unrelated things too. It also behaved
differently per PDK: **sky130's OP texts did not set `hide=true`**, so once data
was loaded they were on screen permanently; gf180's did. **⚠ CLOSED BY S10b**
(issue 0475): sky130's 119 annotation records now carry `hide=true` too, so the
two PDKs behave alike. See the ruling in §4.5's I7 row — the token is `hide=true`,
not the `hide=op` this spec assumed below, because `hide=op` renders *iff* bit0
and the overlay is gated on the same bit, so it does not deduplicate.

> `doc/claude/code_analysis/waveform_subsystem_reference.md` §6 said "Op text is
> layer-15 (hidden unless `show_hidden_texts=1`)". That was wrong — hiding comes
> from the attribute, not the layer — and **S7 corrected it in place** (that file
> §6), as this section asked. S12b then rewrote that whole section against
> HEAD `479be885`; it now carries the layer census, the `annot_show` bits, the
> overlay and the no-save-card-generator blocker. Cite it by **section**, never by
> line.

---

## 3. The measured constraint: ngspice saves nothing by default

Measured with the installed `ngspice` on throwaway decks (`.op` on a
subckt-wrapped MOS, mirroring the PDK device shape). **Re-measured 2026-08-21 by
S12b with `ngspice-46+` — R1 and R2 both hold** (`.save all` on a `.op` deck gave
exactly `v(d) v(g) i(vd) i(vg)` and no `@m1[gm]`; `.save all @m1[gm]` gave all
five; `.save v(d)` alone reduced the raw to two vectors, `v(g)`/`i(vd)`/`i(vg)`
gone):

| deck | vectors in the raw |
|---|---|
| `.op`, nothing saved | `v(d) v(g) i(vd) i(vg)` |
| `.op` + `save all` | **identical** |
| `.options savecurrents` alone | `i(@m.xm1.m0[id]) [ib] [ig] [is]` — **and the node voltages are gone** |
| `save all @m.xm1.m0[gm] [id] [vdsat] [vth]` | node voltages *and* `@m.xm1.m0[gm]`, `i(@m.xm1.m0[id])`, `v(@m.xm1.m0[vdsat])`, `v(@m.xm1.m0[vth])` |
| the same list with `tran 0.1n 20n` | the same device vectors at every timestep (220 points) |

Three rules follow, and they are load-bearing for everything below:

* **R1.** `gm`, `gds`, `vth`, `vdsat`, `cgg`, … exist in the raw **only** if the
  deck explicitly saved them, one card per device per parameter.
* **R2.** Any explicit `save` **cancels the implicit save-everything**. A deck
  that adds device saves must also carry `.save all`, or the node voltages
  disappear. (The shipped sky130 examples already pair them; a generated block
  must not assume the user did.) ⚠ **S12b sharpened the stake on this**: the node
  voltages R2 is about are exactly what the `pinexpr` rows read, and those rows
  are the only ones that render today. So a generated block that omits `.save
  all` does not merely fail to add the `params` rows — it **deletes the two rows
  that already work**. S3 must be tested against that regression, not only
  against the rows it adds.

  **⚠ The spelling is the DOT-card `.save all`.** Corrected by S3 after three
  independent measurements on **both** binaries now on this box
  (`/usr/bin/ngspice` = 42, `/usr/local/bin/ngspice` = 46+, which now *shadows*
  42 on `PATH`). A bare deck-level `save all` line is **not** a no-op and not a
  cosmetic difference: ngspice parses it as an `s`-prefixed **switch instance**
  and dies with `Error on line N … Unable to find definition of model`, writing
  **no raw file at all**. That is strictly worse than omitting it — it removes
  the whole raw rather than only the node voltages this rule is about. Earlier
  revisions of this spec and of the S3 plan cell said "prepend `save all`"; taken
  literally that instruction produces a deck that cannot simulate.

* **R5. One bad card costs the whole raw — and which failure you get depends on
  how ngspice was invoked.** Added by S3. This resolves an apparent contradiction
  between landmine 9 and issue 0429: both are correct, for different idioms.

  | invocation | one bogus `.save` card |
  |---|---|
  | `ngspice -b -r out.raw deck` | `Warning: unrecognized variable`, raw written, **fabricated `0.0` column** (landmine 9) |
  | `.control … write out.raw … .endc` — **what every shipped PDK bench uses** | `Warning from checkvalid`, and **NO RAW FILE AT ALL** |

  ngspice-46+ adds `Error during 'write': no writable vector found.` So under the
  benches a wrong descriptor is not a plausible wrong number, it is *no data* —
  and one rejected parameter anywhere in a generated block suppresses the entire
  run. Issue **0434**.

  **⚠ AMENDED BY S3d — THE SECOND ROW IS TRUE ONLY WHEN *EVERY* DEVICE CARD IS
  BOGUS, AND THE DIAGNOSIS CHANNEL IT NAMES DOES NOT EXIST.** Re-measured on
  both installed binaries (`/usr/local/bin/ngspice` 46+ and `/usr/bin/ngspice`)
  under the same `.control … write … .endc` idiom, with the block at deck level:

  | block, under `.control … write … .endc` | rc | raw | stderr |
  |---|---|---|---|
  | `.save all` + N good cards | 0 | written | empty |
  | `.save all` + N good cards + **one** bogus card | 0 | **written**, plus a column under exactly the requested name holding zeros and marked **`dims=0`** | **literally empty** |
  | `.save all` + **every** device card bogus | 0 | **none** | `checkvalid` + `no writable vector found` |

  Two consequences, and both change how this feature must be tested:

  * **A stderr check is blind in the realistic case.** It fires only for the
    all-bogus block. The S3 step brief prescribed exactly that detector; it does
    not work.
  * **A raw-header *name* diff is blind too** — the name is present, holding
    zeros.

  The detector that works is **`dims=0` in the raw header**: present on every
  bogus vector, absent on every genuinely-produced one, and it additionally
  catches a right-device / wrong-*parameter* card (a level-1 MOS's `[vth]` came
  back `dims=0` on a REAL device). Issue **0489**. The rows that guarded it (X3
  with its own non-vacuity control, X4 asserting values non-zero and finite — a
  full column of `0.0` is a FAIL) were written for S3 attempt 4 and **reverted
  with it**; they are preserved in `doc/claude/issues/0494-attempt-4-reverted.patch`
  and must return with attempt 5.

  The *harm* model is unchanged and is why S3 must suppress rather than guess: a
  guard of the `_prefix_ok` kind (issue **0488**) is needed because a mis-spelled
  hierarchy prefix makes **every** card in a subtree bogus at once, which is
  precisely the third row.
* **R3.** The vector names follow a fixed shape —
  `i(<dev>[<p>])` for currents, bare `<dev>[<p>]` for conductances,
  `v(<dev>[<p>])` for voltages — which is exactly `get_fqdevice()`'s
  `modelparam` 0/1/2 convention, and exactly what the IHP prototype writes by
  hand. Transient saves are sampled at every timestep, so D (OP info at a
  timepoint) is free once C works.
* **R4. The name you *save* is not the name you *read* — you always save the
  bare one.** Added by S1; measured on `ngspice-42`, one card per throwaway deck
  so no card could mask another. This is implicit in the fourth row of the table
  above (bare cards in, wrapped names out) but was never stated, and getting it
  backwards is the whole of the S3 risk:

  | save card written | vector that appears in the raw |
  |---|---|
  | `.save @m.xm1.m1[id]` | `i(@m.xm1.m1[id])` |
  | `.save i(@m.xm1.m1[id])` | **nothing at all — silently dropped, no diagnostic** |
  | `.save @m.xm1.m1[vdsat]` | `v(@m.xm1.m1[vdsat])` |
  | `.save v(@m.xm1.m1[vdsat])` | `v(@m.xm1.m1[vdsat])` |
  | `.save @m.xm1.m1[gm]` | `@m.xm1.m1[gm]` |

  **ngspice applies the wrapper itself, from the parameter's own type** —
  current → `i(…)`, voltage → `v(…)`, admittance → bare. The bare card is the
  only form that works for all three kinds; the `i(…)` card works for none.

  Two consequences, both binding:
  1. A save-card emitter must write `devpath` + `[param]` and **never**
     `op_annot::vector`. See the restatement of **I1** in §5.
  2. The descriptor's `kind` is therefore not a free label — it is a *claim
     about the parameter's ngspice type*, and it is only ever used on the read
     side. A wrong `kind` makes the save succeed and the read silently miss.

---

## 4. Design

### 4.1 Shape

```
              ┌─────────────────────────────┐
              │  PDK descriptor (Tcl)       │   <- the ONLY thing a PDK author
              │  op_annot::register <type>  │      or a user writes
              │    devpath / params /       │
              │    derived                  │
              └──────────────┬──────────────┘
                             │
                 ┌───────────┴────────────┐
                 │  op_annot::vector      │   ONE name builder
                 │  (type, inst, param)   │   -> "@m.x1.xm1.msky…[gm]"
                 └───────────┬────────────┘
                             │
              ┌──────────────┴───────────────┐
              │                              │
   ┌──────────▼──────────┐        ┌──────────▼───────────┐
   │ op_annot::save_cards│        │ op_annot::text <inst>│
   │  walk hierarchy,    │        │  read each vector via│
   │  emit `save …`      │        │  `xschem raw value`  │
   │  into the deck      │        │  format a block      │
   └─────────────────────┘        └──────────┬───────────┘
                                             │
                                  ┌──────────┴───────────┐
                                  │ carrier: annotator   │
                                  │ symbol (phase 1) or  │
                                  │ draw-time overlay    │
                                  │ (phase 2)            │
                                  └──────────────────────┘
```

**The central invariant (I1):** the save-card generator and the display derive
their names from the same builder. If they ever build names independently they
will disagree, and the failure is silent — you save vectors nobody shows, and
show `-` for vectors you saved. One builder, two consumers, always.

> **⚠ Corrected by S1, measured — the shared builder is `op_annot::devpath`, not
> `op_annot::vector`.** The first revision of this spec said both consumers call
> `op_annot::vector`. They cannot: rule **R4** shows `.save i(<dev>[id])`
> produces no vector at all, so a save card built from `vector`'s kind-0 output
> is silently discarded by ngspice. The correct split is
>
> | side | name | who wraps |
> |---|---|---|
> | **write** (save cards, S3/S4) | `[op_annot::devpath $inst][param]`, always bare | ngspice, from the parameter's type |
> | **read** (display, S5/S9) | `op_annot::vector $inst $param` | us, from the descriptor's `kind` |
>
> I1 is unchanged in substance and if anything sharper: `devpath` is the single
> builder both sides share, and `vector` is the *read shape* layered on top of
> it. The place the two sides can still drift is the `kind` field — and that
> drift is exactly what §8's raw-header diff has to catch.

### 4.2 The PDK descriptor

A PDK contributes one registration per device class it wants annotated, in its
own rc / procs file. Nothing else about a PDK is touched.

```tcl
op_annot::register <symbol-type> <dict>
```

where `<symbol-type>` is the symbol `K`-record `type=` token (`nmos`, `pmos`,
`vertical_npn`, `res`, …), and the dict carries:

| key | meaning |
|---|---|
| `devpath` | template for the raw-file device path, **including the element-letter prefix**. Expanded with `xschem translate <inst> …` (so `@name`, `@model`, `@spiceprefix`, `@path` all work) plus `$path` for the hierarchy prefix. |
| `devproc` | *alternative to* `devpath`: name of a Tcl proc called as `<proc> <instname> <model> <path> <spiceprefix>` returning the device path. The escape hatch for PDKs that mangle the model name. |
| `params` | ordered list of `{label param kind}`. `kind` is `0` = wrap in `i(…)`, `1` = bare, `2` = wrap in `v(…)` — the R3 shape, and `get_fqdevice()`'s convention. |
| `derived` | ordered list of `{label expr}`, evaluated after `params` are read, with each `label` from `params` available as a Tcl variable. Non-numeric inputs yield a blank, never a fabricated number. |
| `pinexpr` | ordered list of `{label expr-over-pin-voltages}` for quantities that need no save card at all. **The spelling is the shipped one**, `expr(@#1:spice_get_voltage - @#2:spice_get_voltage)` — see the pinexpr note below. |
| `match` | **optional** list of globs tested (`string match -nocase`) against the instance's cell name, `getprop instance <n> cell::name` → `sky130_fd_pr/nfet_01v8.sym`. A descriptor that matches nothing builds **no devpath**. Absent or empty = permissive, i.e. the behaviour before the key existed. Added by S2 as the ruling on issue **0425** — see below. |

**⚠ THE `devpath` TEMPLATE MUST BE ESCAPED.** Measured on branch `annotate`;
the first revision of this section got it wrong and issue
`doc/claude/issues/0422-op-annot-spec-devpath-templates-do-not-survive-translate.md`
records the measurement. `xschem translate` tokenises on `SPACE(c)` =
`{\n, space, \t, \0, ;}` only (`token.c:24`), so **`.` does not terminate an
`@`-token**, and a token that misses `get_tok_value()` appends **nothing**
(`token.c:5351-5366`). The natural-looking

```
@m.$path@spiceprefix@name.msky130_fd_pr__@model
```

therefore expands to `Xnfet_01v8` — no error, no warning, a plausible-looking
wrong string, i.e. exactly the silent drift **I1** exists to prevent. Escape the
leading `@` and the `.` that must end a token, the way the shipped sky130 symbol
already does (`sky130A/…/nfet_01v8.sym:63-64`):

```
\@m.@path@spiceprefix@name\.msky130_fd_pr__@model
```

Two further rules that fall out of the same measurement:

* `@path` (translate-native, `token.c:4719`) and `$path` (substituted by
  `op_annot::devpath` with `string map`) are both accepted and give the same
  string. **`@path` is canonical** — C resolves it for free. The Tcl pass is
  `string map` and never `subst`: a template is user data, and `subst` would
  execute any `[...]` in it. (Consequence: `string map` also rewrites a literal
  `$pathological`.)
* `translate` runs a trailing `expr(…)` / `expr_eng(…)` / `tcleval(…)` pass
  (`token.c:5424-5432`; measured: `translate M1 {expr(1+1)}` → `2`), so a
  `devpath` template is restricted to plain `@`-token text.

**What S1 settled about the registry** (implemented in `src/op_annot.tcl`;
recorded here because S2 writes the descriptors and S5 reads them):

* **`register` replaces, it does not merge.** A dict-merge reads better for the
  "user edits one line in their own rc" story, but it lets one PDK's
  `pinexpr`/`derived` leak into another PDK's later-registered `nmos` in the
  same interpreter. To tweak one key, round-trip:
  `set d [op_annot::descriptor nmos]; dict set d params …; op_annot::register nmos $d`.
* **⚠ The key is not unique — SETTLED BY S2 with the `match` key.** `type=nmos`
  is carried by sky130, gf180, IHP *and* `xschem_library/devices/nmos*.sym`, so a
  generic device sitting next to PDK devices picked up the PDK's descriptor
  (`devpath M2` → `@m.m2.msky130_fd_pr__cmosn`), and a second PDK's registration
  silently overwrote the first (`devpath M1` → `@n.xm1.nnfet_01v8` on a *sky130*
  device). Both are now blank. Grounding is **I3 via landmine 9**, re-measured
  rather than trusted: a raw asked for a nonexistent device name yields
  `@m.xm1.msky130_fd_pr__nfet_01v8[gm] admittance dims=0` with **no stderr
  warning**, and `xschem raw value` returns `0` — a wrong descriptor is
  indistinguishable from a real zero, so blank is the only compliant outcome.
  Rejected: qualified keys (`sky130:nmos`) plus an "active PDK" concept, and
  "document it and move on". **Accepted residual: the overwrite itself is not
  fixed** — two PDKs in one interpreter still lose the first registration; it now
  degrades to blank rather than to a confidently wrong name, so §8's *one
  interpreter per PDK* still stands. Full ruling, transcript and residuals in
  issue **0425**.
* **⚠ CONSUMER CONTRACT CHANGE, from the same ruling: a non-empty `descriptor` no
  longer implies a non-empty `devpath`.** S3's walk and S5's formatter must skip
  on a blank **devpath**, never on a blank descriptor.
* **The error discipline: data conditions are blank, caller bugs are loud.**
  `descriptor`, `devpath` and `vector` return `{}` for *every* data condition —
  no descriptor, unknown instance, unknown symbol, `translate` failure, a
  `devproc` that raises — because S6/S9 call them from inside a draw/`tcleval`
  path where a raise breaks rendering (I3). `register` with a malformed dict, and
  `vector` with a kind omitted for a param that is not in `params`, both **raise**:
  an rc typo must be caught at registration rather than becoming a blank at draw
  time, which is indistinguishable from "this PDK is not supported".
* **`kind` may be omitted at the call site** — `op_annot::vector M1 gm` reads it
  from `params`. Prefer that: the kind is descriptor data, and a consumer that
  retypes `0` at its call site has quietly become a second builder of the same
  decision. Note the lookup matches the **param** field, not the label, so
  `{Ids ids 0}` is resolved by `ids`.
* **Not validated yet**: a `params` row with a missing or non-numeric `kind`
  silently falls into the `v(…)` branch (mirroring `token.c`), and a
  whitespace-only `devpath` survives as a device name. Issue **0426** — worth
  closing before S6 puts this surface in front of users (requirement F).

**What S2 actually shipped**, in `sky130A/sky130_procs.tcl`,
`gf180mcuD/gf180_procs.tcl` and `ihp-sg13g2/sg13g2_procs.tcl`. This block
**replaces** an earlier, hand-written one that was wrong in four ways; the
divergences are called out because each was measured and each binds a later step.

```tcl
# --- sky130 ---------------------------------------------------------------
# ⚠ A DEVPROC, NOT A TEMPLATE. See "the sky130 four-way switch" below.
proc sky130_op_devpath {instname model path spiceprefix} {
  set m msky130_fd_pr__$model
  if {[regexp {g5v0d16} $model]} {
    set m xsky130_fd_pr__$model.msky130_fd_pr__${model}_base
  } elseif {[regexp {20v0_(iso|nvt)} $model]} {
    set m msky130_fd_pr__${model}_base
  } elseif {[regexp {20v0} $model]} {
    set m m1
  }
  return "@m.$path$spiceprefix$instname.$m"
}
foreach t {nmos pmos} {
  op_annot::register $t {
    devproc sky130_op_devpath
    match   {*sky130_fd_pr/*}
    params  {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
  }                                        ;# THE DEFAULT SIX — ruling D9, §4.2a
}

# --- gf180mcu -------------------------------------------------------------
# Inner device measured uniform `m0` across all 19 nfet*/pfet* symbols.
foreach t {nmos pmos} {
  op_annot::register $t {
    devpath {\@m.@path@spiceprefix@name\.m0}
    match   {*gf180mcu_pr/*}
    params  {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
  }                                        ;# THE DEFAULT SIX — ruling D9, §4.2a
}

# --- IHP sg13g2 (psp103 via OSDI: element letter `n`, inner device n<model>) --
foreach t {nmos pmos} {
  op_annot::register $t {
    devpath {\@n.@path@spiceprefix@name\.n@model}
    match   {*sg13g2_pr/*}
    params  {{id ids 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
  }             ;# THE DEFAULT SIX — ruling D9. IHP spells the current `ids`; the
                ;# LABEL is `id` so one display vocabulary covers all three PDKs.
}
op_annot::register vertical_npn {
  devproc sg13g2_op_npn_devpath   ;# strips `_5t`, then @q.<path><X><name>.q<model>
  match   {*sg13g2_pr/*}
  params  {{gm gm 1} {go go 1} {gmu gmu 1} {gpi gpi 1} {gx gx 1}
           {vbe vbe 2} {vbc vbc 2} {ib ib 0} {ic ic 0}
           {cbe cbe 1} {cbc cbc 1} {cbep cbep 1} {cbcp cbcp 1}}
  derived {{rin {1.0/$gx + 1.0/($gmu + $gpi)}}
           {vce {$vbe - $vbc}}
           {ft  {$gm/(2*3.141592654*($cbe + $cbc + $cbep + $cbcp))}}}
}
```

Registrations go at the **end** of each procs file, guarded by
`[info commands ::op_annot::register] ne {}` with a one-line stderr note when
absent. Measured: a raise inside a PDK procs file prints
`Tcl_AppInit() error: can not execute <rc>`, **abandons the rest of the workarea
rc** (the PDK menu, `user_startup_commands`, the library-manager autostart) and
still exits 0 — and issue 0424 makes `invalid command name` a live possibility in
an installed tree. `register`'s own malformed-dict raise is deliberately **not**
caught: that is an rc typo and must stay loud.

**Five things the earlier hand-written block got wrong. All measured.**

1. **The sky130 four-way switch.** `sky130_write_save_lines:76-78` has FOUR
   inner-device spellings and `xschem translate` cannot express a switch, so
   sky130 needs a `devproc`. Measured on the shipped `sky130_tests/test_nmos`:
   the single template mismatches **35 of 119** prototype cards — the
   `g5v0d16v0` and `20v0` families, e.g. proto
   `@m.xm6.xsky130_fd_pr__nfet_g5v0d16v0.msky130_fd_pr__nfet_g5v0d16v0_base[gm]`
   vs template `@m.xm6.msky130_fd_pr__nfet_g5v0d16v0[gm]`. Corroborated
   independently: `grep -rho 'gm=@spice_get_node …' sky130A/…/*fet*/symbol/*.sym
   | sort -u` returns exactly those four spellings. Per landmine 9 the wrong
   names would not blank — they would show fabricated zeros on three families.
2. **`pmos` must be registered too.** The prototypes branch on
   `regexp {[pn]mos}`; `op_annot`'s key is an *exact array index*. Registering
   only `nmos` would have left 17 sky130, 9 gf180 and 4 IHP PMOS symbols
   unannotated with no diagnostic. **Six FET registrations, not three.**
3. **`vertical_npn` has THIRTEEN parameters, not six.** The earlier list
   (`ic ib gm go vbe vbc`) silently dropped `gmu gpi gx cbe cbc cbep cbcp`, and
   with them the prototype's `rin` and `ft`. Order and kinds come from
   `sg13g2_write_save_lines:331-339` and `sg13g2_display_bip_params:524-536` —
   the only authority for `kind` in the tree.
4. **`pinexpr` uses the shipped spelling.** `{@#1 - @#2}` has **no evaluator
   anywhere in the tree**; `nfet_01v8.sym:65-66` spells it
   `expr(@#1:spice_get_voltage - @#2:spice_get_voltage)`, which is
   measured-working through `translate`'s trailing `expr()` pass. `register`
   stores verbatim, so whatever is written here is what S5 inherits — leaving the
   shorthand would have forced S5 to invent a second expansion convention, which
   is the I1 drift shape exactly. Pin order confirmed D=0 G=1 S=2 B=3 on both
   sky130 and IHP B-records. **⚠ Trap for S5: with no raw loaded this expression
   translates to the literal `" - "`, so S5 must test `string is double -strict`
   and blank (I3).**
5. **`derived` rows are self-contained.** Each `ft` inlines its own capacitance
   sum instead of referencing the derived label `cgg_tot`, and no derived label
   shadows a `params` label. That removes any evaluation-order contract S5 would
   otherwise have to discover. **Deferred user-visible consequence, and it is
   S5/S6's question:** an IHP FET block will show `cgg` (the raw parameter) *and*
   a new `cgg_tot` line, where `sg13g2_display_fet_params` today shows a single
   `cgg` holding the sum.

**⚠ The sky130 `params` list carries two parameter names ngspice-42 rejects.**
`cgso` and `cgdo` are not valid vectors for the sky130 models
(`cgs`/`cgd` are), and **one rejected `.save` card makes ngspice write no raw
file at all** under the `.control … write <cell>.raw … .endc` idiom every shipped
bench uses — exit 0, one `checkvalid` warning, no file. They are here because the
step's acceptance was byte-for-byte equality with `sky130_write_save_lines`,
which has emitted them for years. Issue **0429**; this is the open question that
put S2 at status E, and S4 owns the ngspice-side check that would have caught it.

Every sg13g2 number in the existing prototype is expressible; the `_5t` strip is
the reason `devproc` exists. **Acceptance measured**: bare
`.save [op_annot::devpath $i][param]` cards reproduce `sg13g2_save_params` byte
for byte on **all 49 loadable `sg13g2_tests` cells** (26 with cards, 0
mismatches, including `IHP_testcases` at 405 cards and the three `_5t` HBT cells
at 26 each), and `sky130_save_fet_params` on `test_nmos` 119/119. **⚠ Not
tree-wide for sky130**, though: 3 of 45 shipped sky130 cells differ, because the
prototype reads the prefix with `getprop instance … spiceprefix` (empty when the
token lives only in the symbol `template=`) while `op_annot` uses `translate`.
The generic answer is the correct one — those cells netlist as `XM1` — so this is
a fix, not a regression. Issue **0430**.

**What the user edits** is the `params` list — one line in their own rc, which
overrides the PDK's registration. No symbol is touched, no C is rebuilt, and the
change takes effect on the next redraw.

### 4.2a The default display set — RULING D9 (the user, 2026-08-22)

**A MOS device shows six rows, in this order:**

```
id  gm  gds  vgs  vth  vds
```

Nothing else, on any PDK. The reason is stated as plainly as it was given:
**too many parameters displayed is just clutter.** An annotation block sits on
top of the schematic the designer is reading; every row that is not being looked
at costs screen and costs attention.

This **supersedes the E-question in issue 0429** rather than answering it. That
question was "keep `cgso`/`cgdo`, or drop them and lose two display rows" — under
D9 neither capacitance is in the default set at all, so there is nothing to
ratify. `cgs`/`cgd` are not substituted for anything (the refuted sketch in 0429),
and the two rows are reachable the same way any other non-default row is: by
overriding the descriptor.

**What leaves the default, and it must be said out loud rather than discovered:**

| leaves | was on | note |
|---|---|---|
| `vdsat` | sky130, gf180 | |
| `cgg`, `cgso`, `cgdo` | sky130 | |
| `cgg`, `cgsol`, `cgdol`, `vdss` | IHP | |
| `ft` | sky130, IHP | falls out with `cgg`; **no simulator computes it** (below) |
| `gm/id` | all three | |
| `cgg_tot` | IHP | |

The IHP `vertical_npn` descriptor is **untouched** — D9's six are MOS quantities
and an HBT has no `vgs`. Whether a bipolar default set wants the same treatment
is open, and deliberately not decided here.

#### Why this is not a loss of simulator data

Measured, `show m.xm1.msky130_fd_pr__nfet_01v8 : all` on ngspice-46+ with real
sky130 `tt` models. **ngspice exposes no `ft` and no `gm/id`** — not for BSIM4,
not for psp103. Both were arithmetic performed in Tcl by each PDK's own
`*_procs.tcl`, independently, with two different formulas
(`gm/2/pi/(cgg+cgdo+cgso)` on sky130, `gm/(2*pi*(cgg+cgsol+cgdol))` on IHP).
Dropping them removes a computation the tool was doing, not a measurement the
simulator was providing. The `derived` key stays in the grammar for the user who
wants it back.

#### All six are measured savable — on both ngspice generations, on all three PDKs

This is the check issue 0429 said was **owed and missing** — assert against
ngspice, not against our own strings. One card per parameter, real models, the
`.control … write … .endc` idiom every shipped bench uses:

```
sky130 nfet_01v8   /usr/bin/ngspice (42)    id gm gds vgs vth vds -> RAW, checkvalid=0
                   /usr/local/bin (46+)     id gm gds vgs vth vds -> RAW, checkvalid=0
gf180  nfet_03v3   both binaries            id gm gds vgs vth vds -> RAW, checkvalid=0
IHP    sg13_lv_nmos  46+ only               id gm gds vgs vth vds -> RAW, checkvalid=0
```

**⚠ IHP needs ngspice-46+, and that is the only asterisk.** An earlier revision of
this spec said IHP "cannot be simulated on this box"; that was measured against
`/usr/bin/ngspice` (42), which supports OSDI v0.3 while the vendored
`psp103.osdi` targets v0.4, and then over-generalised. `/usr/local/bin/ngspice`
(46+) loads it and runs the bench. Measured 2026-08-22 on
`sg13g2_tests/dc_lv_nmos`, annotated live:

```
id  = 259.1u   gm  = 464u      gds = 17.78u
vgs = 1.2      vth = 0.2966    vds = 1.5
```

so all three PDKs' defaults rest on a real raw rather than on inference.

and the vector shapes come back exactly on the `kind` convention already in the
descriptor — `i(@m.…[id])` = 0, bare `@m.…[gm]` / `[gds]` = 1,
`v(@m.…[vgs])` / `[vth]` / `[vds]` = 2:

```
0  v(d)                        4  v(@m.xm1.m0[vds])     voltage
1  @m.xm1.m0[gds]  admittance  5  v(@m.xm1.m0[vgs])     voltage
2  @m.xm1.m0[gm]   admittance  6  v(@m.xm1.m0[vth])     voltage
3  i(@m.xm1.m0[id])   current  7  v(g)
```

**So no default row can suppress a raw file on any supported ngspice** — which is
the whole of what 0429 was about.

#### The consequence nobody asked for and everybody wants: `pinexpr` leaves the default path

`vgs` and `vds` are **real BSIM4 instance parameters** (`vgs 0.896512`,
`vds 1.79302` in the `show` dump above), savable on both binaries. sky130 and
gf180 were computing them from pin voltages with a `pinexpr` because the
prototypes did. Under D9 they are ordinary `params` rows, read from the raw like
every other number, and **no shipped descriptor carries a `pinexpr` any more.**

Two open defects therefore leave the shipped path, without either being fixed:

* **0446** — the pin expression that fabricates `vgs = 0` / `vds = 0` when the
  source is on GND and the other net is absent from the raw. The C defect
  (`token.c:4364`, `token.c:5441`) is untouched and still reachable by any
  user-written `pinexpr`; its guardian must move to a **test-local** descriptor
  so the pin on the wrong behaviour survives.
* **0444** — the load-bearing space before `)`. Same status: the tokenisation is
  unchanged, the trap is real for anyone writing a `pinexpr`, and it no longer
  sits between a stock user and their numbers.

`pinexpr` stays in the grammar, keeps its landmine notes, and is now what it
should always have been: the escape hatch for a quantity the simulator does not
save, rather than the mechanism for two that it does.

#### What is owed, and is NOT part of D9

1. **A means for the user to choose her own set. TBD, and named as TBD** — the
   default is six because six is the right default, not because six is all
   anyone may have. Today the only route is `op_annot::register` in a `--script`
   rc (invariant **I5**), which is three lines of Tcl and is not a user
   interface. Whatever ships must be reachable without editing a PDK file.
2. **A mismatch warning — approved in principle by the same ruling.** When the
   descriptor asks for a parameter and the raw does not deliver it, the row
   still renders **blank** (invariant **I3** is unchanged), and the tool
   **additionally reports it once** — in the CIW and in the logfile — instead of
   saying nothing. See invariant **I8**.

### 4.2b The six-row cap — RULING D9b (the user, 2026-08-22)

> *"For ANY PDK, ANY device, only display max of six parameters UNLESS there is a
> setting to do otherwise. We can't have BJT (NPN, PNP) causing clutter."*

§4.2a decided **which** six a MOS shows. This decides that **six is a ceiling for
everything**, and it is enforced in the formatter rather than by editing
descriptors one at a time:

```tcl
op_annot::text      # builds params, then pinexpr, then derived, then TRUNCATES
op_annot::max_rows  # -> the effective cap: 6 by default, 0 = no limit
op_annot::dropped   # -> rows the last text() call dropped, the I8 seam
```

**Why in the formatter and not in the descriptors.** A descriptor is data that a
PDK, or a user, writes. There will always be one more PDK than there are
descriptor files anyone has edited, and a rule that only holds for the three in
this tree is not the rule that was asked for. The cap holds for a PDK shipped
next year by somebody who never read this document.

**The setting, which exists today.** `::op_annot_max_rows` — an ordinary Tcl
variable, settable from any `--script` rc or the console, live on the next redraw
(invariant **I5**):

```tcl
set ::op_annot_max_rows 0     ;# no limit — show everything a descriptor carries
set ::op_annot_max_rows 10    ;# or any other ceiling
```

`0`, a negative number, or anything that is not an integer all mean **no limit** —
a typo must not silently hide rows. Issue **0603** is the friendlier means; this
is the mechanism that means will drive.

**Three properties of where the truncation sits**, each measured by a test row:

* **After all three row classes are built**, so the kept rows are the first N in
  the descriptor's own declared order — `params`, then `pinexpr`, then `derived`.
  A PDK author controls what survives by ordering the list.
* **Before the width pass**, so the label column pads to the longest label
  *actually shown*. A dropped 7-character label must not leave six rows padded
  to 7.
* **Recorded, not silent.** `op_annot::dropped` reports how many rows the last
  call dropped. Without it, "the cap works" and "the formatter returned nothing"
  are the same observation — and a silent truncation is precisely the class of
  thing invariant **I8** exists to make audible. The reporter of **0604** reads
  this seam.

#### A cap chooses how many; a descriptor still has to choose which

IHP's `vertical_npn` shipped **sixteen** rows — thirteen `params` and three
`derived` — and is the case that prompted the ruling. Left untrimmed it would not
have painted sixteen; it would have painted the first six in declared order,
`gm go gmu gpi gx vbe`: five internal small-signal conductances and no current at
all. So it was reordered and trimmed, to mirror the MOS six as closely as a
bipolar allows:

```
MOS   id   —    gm  gds  vgs  vds
BJT   ic   ib   gm  go   vbe  vbc
```

**`vce` is absent, and that is a consequence of the cap rather than an
oversight.** psp103 publishes `vbe` and `vbc`, not `vce`; the prototype showed
`vce` as a *derived* row over both. A derived row may only reference labels that
are themselves displayed rows, so `vce` costs three rows to show one number —
seven in total, one over the cap, and the cap would then drop `vce` itself as the
last row. `vbe` and `vbc` carry the same information (`vce = vbe - vbc`) inside
the budget. Getting the derived row back is two lines and a raised cap, recorded
in `sg13g2_procs.tcl`.

### 4.3 The two consumers

**`op_annot::save_cards {}`** — walk the hierarchy (the `sg13g2_sch_expand`
recursion, generalized and de-prefixed: `no_draw 1` / `no_undo 1` /
`keep_symbols 1` around it, `xschem descend` / `go_back`, `nolist_libs`
respected). For each instance whose symbol `type` has a registration, emit one
`save <vector>` per `params` entry, skipping `pinexpr` and `derived` (nothing to
save for those). Returns the block as text. **Always prepend `save all`** (rule
R2).

**⚠ FOUR ATTEMPTS, FOUR REVERTS — S3a/0436, S3b/0442, S3c/0443, S3d/0494.**
`save_cards` is **not on the tree**. Read `doc/claude/issues/0494-...md` before
starting a fifth; the preserved patch `0494-attempt-4-reverted.patch` applies
clean (`rc=0`) at `d56283ec` and is the right starting point. What attempt 4
**settled, and what a fifth should carry forward rather than re-derive**:

* **THE NETLISTER IS THE ORACLE — RUN IT AND READ IT, NEVER MIRROR IT.** This is
  the one decision that survived every attack, and it is what the paragraph above
  gets wrong: "for each instance whose symbol `type` has a registration" is not a
  sufficient filter, because seven independent netlister rules drop instances or
  whole subtrees (`spice_ignore`, `spice_ignore=short`, `only_toplevel`,
  `lvs_ignore`, empty/absent symbol `format`, `default_schematic=ignore`,
  `spice_sym_def`, `spice_stop`). Attempt 2 hand-implemented three of seven and
  was reverted for it (0442). Measured cost of the oracle:
  `xschem netlist -keep_symbols -noalert <abs path>` is 12–116 ms on ordinary
  designs, writes to `$USER_CONF_DIR/op_annot` so `$netlist_dir` and the user's
  files are untouched, restores `netlist_dir` itself, leaves `xschem get modified`
  at 0, and answers correctly from a descended entry.
* **`_netlisted` AND `_descendable` ARE DIFFERENT QUESTIONS** on the same
  instance: `spice_stop`, `spice_sym_def` and `default_schematic=ignore` keep the
  instance's call in the deck while dropping its subtree. In the deck, "key
  absent" and "key present but empty" are those two different answers.
* **THE BASIS IS ENTRY-RELATIVE, NOT LEVEL-0 ABSOLUTE**, and not raw-relative.
  A netlist invoked from a descended cell makes *that* cell the deck top, so
  entry-relative is the only basis naming devices the generated deck contains.
  `op_annot::devpath` grew `?basis? ?root?` for this, with `read` as the default
  so no display consumer moves. Both raw-relative sources must be neutralised —
  the Tcl `sim_sch_path` **and** `@path`, which carries its own copy of the
  stripping loop in C (`token.c:4719`) and must be `string map`ped away (never
  `subst`ed — a template is user data) before `xschem translate` sees it.
* **THE CARD IS BARE** — `[devpath][param]`, never `op_annot::vector`'s read
  shape. `.save i(@m.xm1.m1[id])` yields no vector and no diagnostic.
* **WHAT IS STILL UNSOLVED**, and killed attempt 4: the deck index keyed on
  `** sch_path:` cannot see **parameter-specialised** subcircuits — the netlister
  writes `.subckt passgate` and `.subckt passgate_1` under the *same* key, and
  `get_sch_from_sym` answers the synthesised name, so 12 of 39 deck FETs on
  `tb_bandgap_opamp` got no card while the user was told it was "normal"
  (**0496**, **0497**). And the walk dirties the user's schematic via `go_back`
  (**0495**).

**`op_annot::text <instname>`** — look up the registration for the instance's
symbol type; read each `params` vector with `xschem raw value <v> -1`; compute
`pinexpr` from pin voltages and `derived` from the read values; format
`label = <engineering>` per line, blank (not `NaN`, not `0`) for anything
missing. Returns the block. This is `sg13g2_display_fet_params` with the
parameter list lifted out into data.

**⚠ IMPLEMENTED BY S5 — the following is now measured behaviour, not intent.**
`op_annot::text`, `op_annot::raw_or_blank` and `op_annot::eng_or_blank` ship in
`src/op_annot.tcl`; `eng_or_blank` is `sg13g2_to_eng_safe` with its `return
"NaN"` replaced by `return {}` (I3), and `raw_or_blank` is `sg13g2_raw_or_double`
verbatim apart from the name. What S5 settled that this section did not specify:

* **THREE OUTCOMES, NOT TWO.** A row with nothing after the `=` means "this
  parameter exists and could not be read"; `{}` — no block at all — means "this
  device is not annotated" (unknown instance, unknown type, no descriptor, a
  `match` miss, or a descriptor with no rows). Collapsing them either way is
  user-visible: blanks painted on an unrelated symbol, or a silently missing
  parameter list on a real device. Skip on a blank **devpath**, never on a blank
  descriptor.
* **A WHOLE-BLOCK GATE, COPIED FROM THE C RATHER THAN INVENTED.** Nothing is read
  unless `token.c:4318`/`:4339`'s own three terms hold: `live_cursor2_backannotate`
  && `xschem raw loaded` >= 0 && `annot_p` >= 0 from `xschem raw annot`, each
  catch-wrapped (`raw annot` itself raises with no raw). Without it, a raw that
  was READ but never PUBLISHED — `xschem raw read <f> op` never calls
  `update_op()` — returns a **fabricated 0** from the calloc-zeroed
  `cursor_b_val[]` while point 0 holds the true value. That is the one I3 hole
  the plan said S5 could not close, and one call closes it. The gate deliberately
  omits the C's `!raw_is_digital` term: `annotate_op` refuses digital files
  outright and a digital raw carries no device vectors.
* **A FINITENESS TEST, NOT JUST A `catch`.** `expr {1.0/0.0}` yields `Inf` with
  **no raise**, `string is double -strict Inf` is 1, and `to_eng Inf` renders
  `infT`. Every shipped `derived` row (`ft`, `gm/id`, `rin`) is a division. The
  guard is `[string is double -strict $v]` then `catch {expr {$v*0.0 == 0.0}}`,
  which raises for both `Inf` and `NaN`, so no such literal enters the source.
* **A MEASURED `0.0` STILL PRINTS `0`.** I3 forbids fabricating a number for a
  *missing* vector; it does not forbid showing a real zero, and blanking every
  zero would hide a genuinely cut-off device.
* **ROW ORDER IS A CONTRACT**: `params`, then `pinexpr`, then `derived` — because
  a `derived` expression sees every `params` **label** and every `pinexpr`
  **label** as a Tcl variable. §4.2 says *label*, while `op_annot::_kind` matches
  the *param*, so the two are genuinely different fields. Values are bound only
  when finite, so a missing input leaves the variable UNSET and the row raises
  inside the catch and blanks — which generalizes the prototype's per-denominator
  guards without knowing which variable is a denominator. Evaluated in a
  proc-LOCAL scope, never `uplevel #0`.
* **THE LABEL COLUMN PADS TO THE LONGEST LABEL IN THAT BLOCK.** The prototypes
  hardcode `gm    = `, which cannot fit `gm/id` or IHP's `cgg_tot`. Every row ends
  in exactly one newline.
* **`devpath` ONCE, `_wrap` PER ROW** — not `vector` per row. Both of `vector`'s
  shared primitives are still the ones called and the kind still comes from the
  descriptor's own triple, so I1 holds in substance; per-row `vector` would be 26
  nested `xschem translate` calls on IHP's 13-param NPN while the outer
  `translate`'s `static char *result` (`token.c:4604`) is live. Guarded by a row
  asserting `[_wrap [devpath …] $p $kind] eq [vector … $p]` for every params row.

### 4.4 Getting the block onto the screen — two carriers

**Carrier 1: the annotator symbol.** A PDK-neutral `annotate_params.sym`,
modelled exactly on IHP's. LANDED in S6, and its `type=annotator` is what keeps
it out of the registry so it never annotates itself:

```
K {type=annotator
template="name=annot1 ref=M1"}
T {tcleval([op_annot::text @ref ])} 5 5 0 0 0.2 0.2 {layer=15
font=Monospace
hide=op}
T {@ref} 0 0 2 1 0.2 0.2 {layer=4}
```

⚠ **THE SPACE BEFORE THE `]` IS LOAD-BEARING, and every earlier revision of
this section omitted it.** `SPACE(c)` (`token.c:24`) is `{\n, space, \t, \0, ;}`
and does not contain `]`, so without it the token is `@ref]`, misses
`get_tok_value()` and appends nothing; the `tcleval` body is left unbalanced,
`tclpropeval2`'s catch turns it into `?`, and EVERY ROW of the block becomes a
question mark. Measured side by side in one process:

    tcleval([op_annot::text @ref ])   ->  the ten-row block
    tcleval([op_annot::text @ref])    ->  `?`

Same mechanism as issue 0444, applied to `]` instead of `)`. All three shipped
PDK prototypes already carry that space. Pinned by rows K3 and K11 of
`tests/headless/test_op_annot.tcl` — K11 derives the broken spelling from the
shipped file's own bytes, so the two cannot drift apart.

⚠ **THE SYMBOL IS WRITTEN TO BOTH DEVICE LIBRARIES** —
`xschem_library/devices/annotate_params.sym` AND
`xschem_libs_newsym/devices/annotate_params/symbol/annotate_params.sym`,
byte-identical. The flat copy is the one `xschem_library/Makefile` installs; the
nested one is the only copy the three PDK workareas can see, because each
`cadence_style_rc` sets `XSCHEM_LIBRARY_PATH {}` with
`library_registry_defs_only 1` and each `library.defs` resolves
`DEFINE devices ../../xschem_libs_newsym/devices`. A flat-only write is invisible
in exactly the three workareas the acceptance names. The fork itself is issue
0450; row K1 guards this one cell.

Placed next to a device — Simulation > Graphs > **Add device OP annotator**,
which calls `op_annot::place_annotator` and pre-fills `ref` from the selection.
The symbol is named library-qualified, `devices/annotate_params`, and NOT via
`find_file_first` (issue 0449). **Needs no C change and no PDK symbol edit** —
it is the phase-1 deliverable and it works on every PDK the moment its
descriptor is registered.

~~⚠ `hide=op` IS INERT UNTIL S7 and the carrier therefore ships ALWAYS-ON, with
no user off switch.~~ **✅ RESOLVED BY S7 (2026-08-19).** The measurement that
stood here — three scratch symbols differing only in the hide token giving
byte-identical instance bbox widths at both `show_hidden_texts` states
(`hide=none` 186/186, `hide=op` 186/186, `hide=true` 16/186), because
`strboolcmp` (`util.c:72`) classifies `op` as `s=-1` and falls through to
`strcmp` so no bit is set — no longer holds. `set_text_flags` now tests exact
`op` and `voltage` **before** the `strboolcmp` fallback, and the carrier's
numeric block appears **iff `annot_show` bit0**, at both `show_hidden_texts`
states. Its `T {@ref}` label and corner strokes still render at every setting,
so a placed annotator is never invisible — only its numbers are gated.

⚠ **THE CARRIER'S RESTING STATE FLIPPED, AND NOBODY HAS RATIFIED IT.**
`annot_show` defaults to **0**, so the annotator S6 shipped always-on one day
earlier now renders dark until `xschem set annot_show 1` or S8's `6` key.
Decision D2, ladder rung **L3** — see the S7 block in the plan for the open
question and the `~/.xschem/xschemrc` off-ramp.

**Carrier 2: the draw-time overlay.** ✅ **LANDED AT S9b (2026-08-20).**
(⚠ Attempted in full at S9 (2026-08-19), refuted and reverted — issue 0466; S9b
re-landed that implementation's src/ half unchanged and replaced its
invalidation. Full record in issue 0466 § S9b.) For every instance whose
**`op_annot::text` block is non-blank** — *not* "whose symbol type is
registered": §4.2's `match` ruling and §4.3's consumer contract both say skip on
a blank **devpath**, and measured, `devices/nmos.sym` answers descriptor?=1 with
devpath `{}` under a sky130-only registration, so the registered-type gate paints
blocks on 13 generic symbols — and only while the annotation mask says so,
`draw()` renders `op_annot::text` next to the symbol bounding box. No symbol placed, no schematic
modified, nothing saved to the `.sch`. This is what makes `6` behave like
Cadence: press it and *every* transistor lights up.

Consequences of carrier 2 that the plan must handle:

* it must be replicated in `svgdraw.c` and `psprint.c` or exports lose the
  annotation (2 further sites);
* it **duplicates** what a PDK symbol already prints. sky130's `id=`/`gm=` texts
  had no `hide=true`, so they were always on. Removing the duplication is a
  one-time scripted edit per PDK, tracked as its own step, not a prerequisite.
  **⚠ DONE BY S10b, AND THE TOKEN IS `hide=true`, NOT `hide=op`.** Measured on all
  40 shipped sky130 files: `text_hidden()` renders a `hide=op` text *iff*
  `annot_show` bit0, and `get_annot_overlay()` (decision D2) gates the whole
  overlay on the *same* bit, so `hide=op` makes the symbol text visible exactly
  when its replacement is — the double-printing survives at mask 1 and mask 3 and
  vanishes only at the mask where nothing is drawn. `hide=true` deduplicates at
  both, matches what gf180's 19 symbols already ship, and leaves the legacy
  numbers reachable through View > Show hidden texts for the user whose rc never
  sources the PDK procs. Full table and ruling: issue **0475** §3;
* placement must be deterministic and collision-tolerant — anchor to the symbol
  bbox corner, with a per-instance `annot_dx`/`annot_dy` override attribute.
  **S9 measured the shape that works**: upright (rot 0 / flip 0) at the *text-free*
  bbox corner `inst.xx2 / inst.yy1`, `annot_dx`/`annot_dy` **relative** with
  defaults +5 / 0, size 0.2, layer 15, font Monospace — the last three lifted
  verbatim from the shipped carrier so the two carriers match side by side.
  Rotating with the instance was rejected (a 90° FET prints a vertical wall of
  monospace rows); absolute offsets were rejected (they break when the instance
  moves);
* ⚠ **the per-instance cache must be invalidated by enumerating the FORMATTER'S
  INPUTS, not by listing the obvious user actions.** This is what reverted attempt
  1: thirteen epoch fields — path hash, `modify_seq`, four raw terms, the mask, a
  data counter, a descriptor generation — and **not one moves on `xschem reload`**,
  so the overlay painted the previous file's numbers, breaching **I3** (issue
  **0466**). ⚠ **And the one-line fix that issue proposed was necessary but not
  sufficient, and its anchor was wrong**: `load_schematic()` is at **`save.c:4311`**
  (not `:4319`, which this spec asserted and which is mid-prologue) and has an early
  `return 0` at `:4391` reached *after* `xctx->sch[currsch]` is rewritten. What
  S9b landed instead, each hook one line:

      HOOK A  actions.c clear_drawing()   — every file re-read: load, reload,
              `load -keep_symbols`, descend, ascend, undo, redo, `clear`, teardown
      HOOK B  actions.c set_modify(), INSIDE its existing
              `if(mod == 1 || mod == -2 || mod == -1)` floater-cache block — the
              codebase's own per-object-render-cache channel; the only cover for
              `editprop.c:1263`'s `set_modify(-2); draw();` (a full frame BEFORE
              its caller's `set_modify(1)` at :1289) and for readonly buffers
              (`ro_suppress`, actions.c:189, kills `modify_seq`)
      HOOK C  actions.c remove_symbols() — the ONLY cover for `xschem reload_symbols`,
              which is `remove_symbols(); link_symbols_to_instances(-1);` and nothing
              else. A `.sym` whose `type=` changed on disk otherwise keeps the old
              descriptor's block forever
      HOOK D  save.c raw_add_vector / raw_renamevar / raw_deletevar + the
              `xschem raw set` arm — in-place raw mutation moves NO epoch field
      TERM 14 `live_cursor2_backannotate`, a shipped menu checkbutton
              (`xschem.tcl:15360`) that is `op_annot::_annotated`'s FIRST gate

  The covering rows must re-load the **same path** with changed content (a
  different path moves the hash and flushes anyway, which is why 192 checks missed
  it), and each hook needs its **own** row — S9b's sabotage matrix reds exactly one
  row per hook;
* ⚠ **it is deliberately NOT folded into `symbol_bbox()`**, so zoom-full and the
  auto-viewport print form clip the rightmost blocks (issue **0463**). Folding it
  in was rejected: `symbol_bbox()` is reached from netlist/save paths and run over
  every instance by `update_all_sym_bboxes`, making a per-instance Tcl call there
  a re-entrancy hazard against `translate()`'s single static result buffer;
* ⚠ **it multiplies the existing tcleval-in-a-draw-path hazard by every device on
  the sheet.** A devproc that re-enters xschem segfaults (`signal 11`) —
  **pre-existing**, reproduced identically through the S6 carrier with the overlay
  never running, but carrier 2 makes every registered device an entry point;
* ⚠ **`draw()`'s whole body is inside `if(has_x)`**, so no headless check can see
  the screen back end. Measured **twice**: stubbing the screen renderer leaves the
  suite at `ALL PASS` (192 checks at S9, 209 at S9b) while reddening four rows on
  a display. A monotonic `xschem get annot_overlay_count` seam plus a DISPLAY leg
  is the only coverage that path can have — and `xschem get drawcount` is not a
  substitute, because `draw_count++` sits *above* the `has_x` guard
  (`draw.c:10393`). ⚠ Run the display leg **without `--nogui`**, or the
  display-only rows self-skip (209 instead of 214);
* ⚠ **a cache needs a SECOND seam, `xschem get annot_overlay_flushes`** — a
  monotonic count of wholesale flushes, incremented **inside the sync at the moment
  of the flush**, never on invalidation *requests* (several hooks legitimately fire
  for one user action). Without it every staleness row is satisfiable by deleting
  the cache, i.e. flushing every frame — measured invisible to all 31 staleness
  rows, and worth ~1.16 ms/frame on a 13-device sheet;
* ⚠ **a renderer resets your caches behind your back.**
  `prepare_netlist_structs()` calls `set_modify(-2)` (`netlist.c:1798`), and
  `svg_draw()` (`svgdraw.c:1282`) and `create_ps()` (`psprint.c:1653`) both call it
  **after** their instance loop — so one export tears down the caches it just
  filled. S9b brackets that single line with a depth-counted
  `annot_invalidate_hold()`; the hold **drops** rather than defers, so it is safe
  only at that one site. The floater half is untouched — issue **0473**;
* ⚠ **the overlay resolves a device by NAME and it should not.**
  `get_annot_overlay(n, …)` holds the index, discards it, and passes
  `inst[n].instname` into `op_annot::text`, which re-resolves through
  `get_instance()` (`scheduler.c:187`) whose first branch reads an all-digit name
  as an **index**. Measured: an instance renamed `1`, or two instances sharing a
  name, render **another device's numbers** in all three back ends with no warning
  — I3's forbidden case. Pre-existing (the S6 carrier's `ref=` has it) but carrier
  2 widens it to every registered device. Issue **0469**; **do not default the mask
  on until it is closed**.

### 4.5 Visibility: annotation classes ✅ LANDED (S7, 2026-08-19)

Replace the single boolean with a mask.

* Text attribute gains classes: `hide=op`, `hide=voltage`, alongside the existing
  `hide=true` / `hide=instance`. New flag bits next to `HIDE_TEXT`
  (`xschem.h:387`), set in `set_text_flags()` (`actions.c:1121`).
* New `xctx->annot_show` bitmask (`bit0 = device OP info`, `bit1 = node
  voltages`), mirrored in Tcl as `annot_show`, per the `MIRRORED IN TCL`
  convention.
* ~~The nine copy-pasted visibility tests collapse into one helper
  `text_hidden(flags)`.~~ **That refactor is the substance of the change**; the
  class logic is a few lines inside it.
* `hide=true` keeps its exact present meaning under `show_hidden_texts`. Nothing
  existing changes behaviour.

**AS BUILT — three things this section got wrong, all measured before the fix.**

1. **It is TEN sites, not nine, and the helper takes a CONTEXT.** See the
   correction box in §2.4. The signature that shipped is
   `int text_hidden(int flags, int ctx)` with `TEXT_CTX_INSTANCE` /
   `TEXT_CTX_SCHEMATIC`; the six symbol-text sites pass the former, the four
   `xctx->text` sites the latter, so the mask difference that used to be
   invisible in a copy-pasted expression is now an argument you can read at the
   call site. *(Decision D1, ladder rung **L1**, invariant **I7**. Rejected: one
   fixed mask, which flips `hide=instance` for 630 occurrences in 244 files;
   also rejected, two thin wrappers `sym_text_hidden`/`sch_text_hidden`, which
   re-create the two-tests problem at the name level.)* The predicate:

   ```c
   int text_hidden(int flags, int ctx)
   {
     if(flags & HIDE_TEXT_OP)      return (xctx->annot_show & ANNOT_SHOW_OP)      ? 0 : 1;
     if(flags & HIDE_TEXT_VOLTAGE) return (xctx->annot_show & ANNOT_SHOW_VOLTAGE) ? 0 : 1;
     if(xctx->show_hidden_texts) return 0;
     if(flags & HIDE_TEXT) return 1;
     if(ctx == TEXT_CTX_INSTANCE && (flags & HIDE_TEXT_INSTANTIATED)) return 1;
     return 0;
   }
   ```

   `set_text_flags` zeroes `flags` and its `hide=` branch is an if/else chain,
   so the four bits are mutually exclusive; with neither class bit set this
   reduces **provably** to the six-plus-four split it replaced. Bits 64 and 128
   were free, and `flags` is a plain `int` that is never serialised (always
   recomputed by `set_text_flags`), so adding bits needs no file-format change.

2. **The classes ignore `show_hidden_texts` entirely** — they are gated *solely*
   by `annot_show`, per this spec's own acceptance wording "a `hide=op` text
   appears iff bit0". *(Decision D3, ladder rung **L2**. Rejected: making
   `show_hidden_texts` a master override for the new classes, which reads
   naturally since `hide=op` is spelled as a hide token, but would make S8's
   `Ctrl-6 → none` a silent no-op whenever the shipped **Annotate Operating
   Point** menu items have already done `set show_hidden_texts 1` — which is the
   exact flow a user reaches this feature through.)* **The cost, measured and
   accepted:** a `hide=op` text cannot be revealed by View > Show hidden texts,
   *including while editing the symbol that carries it*.

3. **The mirror must NOT copy `show_hidden_texts`' shape.** `show_hidden_texts`
   is a *pull* cache refreshed at only three places while `symbol_bbox()`,
   `svg_draw()` and `create_ps()` all read it and none refresh it — so the first
   export after any Tcl-side change renders with the **old** value, both
   directions, both formats (three SVG in a row give `0 1 1`; reversed `1 0`),
   and `update_all_sym_bboxes; redraw` is one toggle behind (`0/0/0/161`). That
   is **issue 0453**, filed and deliberately left alone (decision D5 — fixing it
   changes when `hide=true` texts appear in exports for every existing library
   symbol, the behaviour change this commit was forbidden to carry). `annot_show`
   instead follows the **P6 `pin_names_sync_cache` precedent**:
   `annot_show_sync_cache()` is called at all six bulk-evaluation entry points
   (`draw`, `calc_drawing_bbox`, `xschem print`, `xschem update_all_sym_bboxes`,
   startup, CLI batch print) and `xschem set annot_show N` writes **both**
   `xctx->annot_show` and the Tcl var so no later pull can undo the setter
   *(decision D4)*. Rows L17/L18 assert the annotation mask is not stale.

**⚠ `annot_show` IS AN INTEGER, NOT A BOOLEAN.** `annot_show_sync_cache` uses
`tclgetintvar` (→ `atoi`), unlike its neighbour `show_hidden_texts` which uses
`tclgetboolvar`. Measured: `set annot_show true|on|yes` all give C `0`, i.e.
**silently off**; only `1`/`2`/`3` work. Anything setting this variable — S8's
`cadence::annot_mode` above all — must write a number.

### 4.6 The keys ✅ LANDED (S8, 2026-08-19)

Bound in **`src/cadence_style_rc` only**, following the `Ctrl-4` precedent in
that file, with the body in `utils/annot_mode.tcl`:

```tcl
bind .drw <Key-6>         {cadence::annot_mode op;     break}
bind .drw <Control-Key-6> {cadence::annot_mode none;   break}
bind .drw <Alt-Key-6>     {cadence::annot_mode opvolt; break}
```

**⚠ CORRECTED BY S8 — "and the per-PDK copies" was wrong.** There are no
copies. `sky130A/cadence_style_rc:17`, `gf180mcuD/:18` and `ihp-sg13g2/:17` each
`source [file join $_ws .. src cadence_style_rc]`, so **one** block reaches all
three PDKs; editing three files would have created the silent-drift shape this
spec forbids elsewhere. (The plan's Files cell also omitted gf180mcuD, one of the
three acceptance PDKs, entirely.) Verified by firing real `event generate`
chords under all four profiles: `6` → mask 1, `Ctrl-6` → 0, `Alt-6` → 3,
`rectcolor` unchanged at 4 throughout.

**⚠ ALL THREE CHORDS MUST BE SPELLED OUT.** Tk matches a pattern whose modifiers
are a **subset** of the event's, so with only `<Key-6>` bound both `Ctrl-6` and
`Alt-6` fire it — the OFF key silently means ON. Measured, and reproduced live by
sabotage SB8. `Ctrl+Alt+6` falls into the Alt form; `Shift-6` matches nothing
(keysym `asciicircum`). `Ctrl-6` joins `Ctrl-2` and `Ctrl-4` as a displaced
*select drawing layer N*; the verb survives on the Layers menu and as
`xschem set rectcolor 6` (`cadence_bindkey_plan.md` §10).

Verified free / safely overridable in this tree, all four confirmed by
measurement:

* plain `6` reaches `callback.c:7272` and is a **no-op** unless Control is held;
* `Ctrl-6` is "select drawing layer 6" — overridden with a trailing `break`,
  exactly as `Ctrl-4` already overrides "select layer 4" for
  `ase::direct_plot_for_current`;
* `Alt-6` (keysym 54) appears in **no** row of `src/keybindings.csv`; the only
  alt+digit row is `key,50,alt,canvas,view.toggle_view_type` (Alt-2);
* no Shift is involved, so the shifted-keysym trap documented in that file for
  `Ctrl-Shift-2` / `Ctrl-Shift-4` does not apply.

`cadence::annot_mode <mode>` does, in this order:

1. set `annot_show` **through `xschem set annot_show N`** (`none` → 0, `op` → 1,
   `opvolt` → 3). Never a bare `set ::annot_show`: the C field reads stale until
   the next sync, and the variable is an **integer**, so `true`/`on`/`yes` all
   `atoi` to 0 — silently *off*;
2. if nothing is annotated **and** no raw is loaded and the mode is not `none`,
   load one for the current cell — `ase::session_for_current` /
   `ase::last_rawfile` when an ASE session exists (**its level travels with the
   path**, or landmine 4's device-path collapse follows), else
   `$netlist_dir/<cell>.raw` — via `xschem annotate_op`, **only after
   `file exists`**, with success **re-asked from `xschem raw loaded`**;
3. `xschem update_all_sym_bboxes; xschem redraw` (the pair the existing
   "Show hidden texts" checkbutton uses; bboxes change when texts appear, and
   S7's sync rides inside the first, so no extra sync call);
4. **say what happened on the status line, `-hold`.** A key that finds no raw
   file must report that, not fail silently. Same for "no descriptor registered
   for this PDK". **⚠ `-hold` IS NOT OPTIONAL** — measured, one `<Motion>` event
   reverts a plain `statusmsg` to `mouse = … selected: 0 path: .`, and a key
   press is always followed by pointer motion, while a headless check that never
   generates motion still passes (issue 0248).

**⚠ THE GUARD IN STEP 2 IS LOAD-BEARING, NOT AN OPTIMISATION.** `annotate_op`
deletes the previously loaded OP and unsets `ngspice::ngspice_data` **before** it
tries to open the new file (`scheduler.c:2409`) and returns rc=0 either way — so
an unguarded reload silently destroys a good annotation. Three guards:
`op_annot::_annotated`, then `raw loaded >= 0`, then `file exists`.

**⚠ AND `op_annot::_annotated` COLLAPSES TWO CAUSES — ASK WHICH ONE.** It is
false when *either* `live_cursor2_backannotate` is 0 *or* the raw published no OP
point (`raw annot` `p == -1`). The shipped `Waves > Op` route
(`xschem raw_read`) reaches the **second** with the flag still at 1, and
`scheduler.c:2404` *forces that flag on*, so the first is almost never the
reason. S8 shipped a status line that named the flag unconditionally — a
plausible wrong **reason**, which is ruling **D5-1**'s plausible wrong *number*
in different clothes — and repaired it before commit (issue **0459**, row N10b).

The message matrix, as built:

| state | line |
|---|---|
| `none` | `OP annotation OFF` |
| `op` / `opvolt` | `OP annotation ON (device OP info)` / `… (device OP info + node voltages)` |
| already live | `-- raw already loaded` |
| loaded now | `-- loaded <path>` |
| exists, won't parse | `-- COULD NOT LOAD <path>` |
| candidate absent | `-- NO RAW FILE: <path>` |
| no candidate buildable | `-- NO RAW FILE for this cell` |
| loaded, flag off | `-- a raw is loaded but backannotation is off (live_cursor2_backannotate 0)` |
| loaded, no OP point | `-- a raw is loaded but it published no operating point: use Waves > Op Annotate, or ``xschem raw_clear`` then press again` |
| nothing annotatable | `-- no OP descriptor for symbol type(s): <t…>` appended to any of the above |

Both first-run confusions land in the **same** line: fixing the raw only to meet
the descriptor problem on the next press is the shape this rejects.

**S8 also repaired the two shipped `Annotate Operating Point` menu items**
(`src/xschem.tcl`), which set `show_hidden_texts` and — since S7 made the class
bits ignore that variable entirely — produced a loaded raw and a **dark**
annotator (measured: carrier bbox 29×22, unchanged). They now set
`annot_show 1` and run the bbox/redraw pair. That is the only route to this
feature for a non-cadence user; whether the mask deserves a first-class stock
control is the open question in issue **0457**.

**Not yet done here:** the "nothing annotatable" scan names decorations and
relabels unresolvable symbols (`logo`, `missing`, `vsource` …) — issue **0460**,
best fixed with S10's type inventory; and `annotate_op`'s own minted refusal
sentence is discarded in favour of the generic `COULD NOT LOAD` — issue **0461**.

---

### 4.7 Timepoint annotation with no graph ✅ LANDED (S11, 2026-08-20)

**The seam:** `xschem set cursor2_x <t>` on a schematic with **no graph object**
now moves `raw->annot_p / annot_x / annot_sweep_idx / cursor_b_val[]`, so every
consumer of `xschem raw value <v> -1` follows the timepoint — `op_annot`'s device
rows, the S9b overlay, every `@spice_get_voltage` symbol text and floater
(`token.c`), every `pinexpr` row, and the IHP prototype's own
`sg13g2_raw_or_double`. **No Tcl changed**: they were all already reading the
array the new arm writes.

```c
/* scheduler.c -- the gate is a SCAN for a graph OBJECT, not a rect count */
for(i = 0; i < xctx->rects[GRIDLAYER]; ++i)
  if(xctx->rect[GRIDLAYER][i].flags & 1) { has_graph = 1; break; }
if(has_graph)      { ...the shipped block, byte-identical... }
else if(backannotate_at_cursor_b_nograph()) { if(floaters) set_modify(-2); }

/* callback.c -- 12 lines, and it reimplements NOTHING */
int backannotate_at_cursor_b_nograph(void)
{
  xRect r; Graph_ctx gr;
  if(!xctx || sch_waves_loaded() < 0) return 0;
  memset(&r, 0, sizeof(r));
  memset(&gr, 0, sizeof(gr));
  gr.gx1 = -HUGE_VAL; gr.gx2 = HUGE_VAL;
  backannotate_at_cursor_b_pos(&r, &gr);
  return 1;
}
```

Four things about that helper are load-bearing, and each has a rejected
alternative that was measured rather than argued:

1. **The public entry, never the static inner one.** Only
   `backannotate_at_cursor_b_pos()` bumps `annot_data_changed()`; a
   **within-segment** cursor move touches no other field of the 14-field
   `Annot_epoch`, so calling `backannotate_cursor_b_in_db()` directly would leave
   the S9b overlay showing the previous timepoint's numbers while
   `xschem raw value -1` reports the new ones — the I3 breach that reverted S9
   attempt 1 (issue 0466). ⚠ **No test row currently reds this** — issue **0481**.
2. **A stack-local `Graph_ctx`, never `&xctx->graph_struct`.** `save.c`'s
   `raw_read()` carries the same idiom and the reason: the shared struct is live
   inside `draw_graph()`, which calls `raw_read()`.
3. **An explicit whole-sweep window, NOT a `memset`-0 one.** A zeroed ctx is the
   degenerate window `[0,0]`; every transient raw has a sample at exactly t = 0,
   it passes the scan's window filter, so `first` is 0 rather than −1, RULING
   **D4-7**'s `rescan_no_window` never fires, and `interpolate_yval()` returns
   **point 1's value for every t past the second sample**. Built and measured
   (S11 SAB-2): 12 red rows, `v(d) = 1` where the truth is 3. See landmine 13
   and issue **0480**, which is the same defect left *unfixed* on the graph path.
4. **The `sch_waves_loaded()` gate ahead of the call**, because the public entry
   fires `annot_data_changed()` and `catch {eval $cursor_2_hook}` *before* its
   own test — so without it every `set cursor2_x` on a data-less sheet would fire
   a user hook that has been graph-only since it was written.

**A zeroed `xRect` is a correct one**, verified in the callees:
`backannotate_cursor_b_in_db()` reads only the `sweep` token (and
`get_tok_value()` answers `""` for a NULL `prop_ptr`, so `sweep_idx` falls back
to 0 = the time column) and `flags & 4` (private cursor, clear); and
`graph_cursor_dbs()` (`draw.c`) has an explicit non-graph arm that yields the
current database and nothing else — no `%` parse, no `extra_rawfile()` switch.

**Out of range holds the endpoint, identically on both paths** (RULING **D4-4**),
because the direct path reaches the same clamp. That satisfies I1 and is
*deliberately* not what S11's brief asked for; the open question is issue
**0479**. A vector **missing** from the raw still renders blank (I3): the two
cases are different and only the second is a fabrication.

**Not done, deliberately (decision D8):** the `cursor1_x` twin stays `#if 0`'d,
and `utils/annot_mode.tcl` is untouched — so the `6` / `Ctrl-6` / `Alt-6` keys
still land on point 0 until something moves cursor B. The mechanism exists; the
key path does not use it, and wiring it is a new user interaction that needs its
own step (and runs into issue 0478).

---

## 5. Contracts and invariants

| id | invariant |
|---|---|
| **I1** | Save cards and display share one name builder, `op_annot::devpath`. The save card is bare `devpath+[param]`; the display name is `op_annot::vector`, i.e. `devpath` plus the descriptor's `kind` wrapper. Never two independent builders. *(Restated by S1 — R4; the original wording named `vector` on both sides and is measurably impossible.)* **⚠ AMENDED BY S3 — "one builder" was under-specified and it reverted a complete implementation. One builder, but it must take a BASIS.** `devpath`'s hierarchy prefix comes from `sim_sch_path`, which is **relative to the level where the raw was loaded** — the right basis for *reading* a vector out of a loaded raw, and the wrong one for *writing* a save card, which needs a **deck-absolute** name. They coincide only when no raw is loaded or the raw is at the top, which is why 85 green checks missed it. The fix is a basis argument on the one builder (`op_annot::devpath <inst> ?basis?`, `absolute` for save cards), **not** path arithmetic in the walk — that would be the second builder this invariant forbids, and is exactly what the prototypes' `startpath` was. Issue **0436**, mechanism confirmed in the C at `save.c:1260`, `draw.c:2831-2838`, `scheduler.c:5150`. **HELD AT S11 ACROSS A NEW VALUE SOURCE, and this is the invariant that decided the step.** The graphless cursor arm reaches the *same* `interpolate_yval` / `rescan_no_window` / per-database fan-out as the graph arm rather than owning a copy, so an out-of-range t **holds the endpoint on both paths** (measured identical `{annot_p, v(d), gm}` triples at −5 ns, 2.5 ns and 99 ns; row **T18**). S11's brief asked for the new arm to blank instead; that was **rejected** as the exact silent drift this invariant exists to prevent — and, decisively, *no row compares the two paths*, so the divergence would have reddened nothing. Question owed to a human: issue **0479**. ⚠ Note the limit of row T18: it can only red when the two paths **diverge**, so it is not a test of the shared arithmetic (deleting RULING D4-4's clamp leaves it green — issue 0481). |
| **I2** | A generated save block always carries **`.save all`** — the DOT-card (rule R2; the bare `save all` writes no raw at all — see R2). Honoured as *"any **non-empty** block carries `.save all` as its first line"*: an empty walk returns `{}`, because a file whose entire content is `.save all` says nothing while reporting success. **⚠ This is in direct tension with S2's acceptance criterion and S3 must resolve it, not inherit it.** The prototypes (`sg13g2_save_params`, `sky130_save_fet_params`) emit a comment plus bare `.save` cards and **no `save all`** — so a block that reproduces them byte for byte violates I2, and a block that satisfies I2 is by construction *not* byte-equal to them. S2's byte-diff was the right acceptance for a **name builder**; it is the wrong acceptance for a **block emitter**. S3 asserts I2 on the block and keeps the byte-diff on the card names only. |
| **I2b** | **A generated save block names only devices that are in the netlist.** Added by S3. An instance carrying `spice_ignore=true` is absent from `xschem netlist` but is still visited by a hierarchy walk, and per **R5** one card for a non-existent device suppresses the entire raw under the bench idiom. So *one* such device anywhere in a design is enough to make a generated `.save` file kill the simulation it was generated for. Issue **0437**. **⚠ THE FILTER IS SEVEN CLASSES, NOT ONE — AND GETTING THREE OF THEM REFUTED S3b.** Measured (issue **0442**): `spice_ignore` (true/`open`/`short`, instance **or** symbol), `only_toplevel` below the walk entry, `lvs_ignore` gated on `::lvs_ignore` — *and four symbol-level classes S3b missed entirely*: empty/absent `format` (`spice_netlist.c:639`, the instance vanishes from the deck completely), `default_schematic=ignore` (`:643`), `spice_sym_def` (`:665`, body replaced by attribute text), `spice_stop=true` (`:635`+`:695`, `.subckt` emitted **empty**). The last two drop the **subtree** while the instance call survives — so "may I emit a card for this?" and "may I descend into this?" genuinely diverge and cannot be aliases. **Any implementation of this invariant must be acceptance-tested against `xschem netlist` on a HIERARCHICAL fixture carrying all seven**; S3b's cross-check row was correct but its fixture was flat, which is exactly why 96 green checks and 8 sabotage variants missed the gap. Strongly consider deriving the device set from `xschem netlist` output, or exposing `skip_instance()` (netlist.c:1245) to Tcl, rather than re-implementing the netlister's filter in Tcl a class at a time — that reimplementation has now drifted twice, and `skip_instance()` also branches on `xctx->netlist_type`, which no Tcl copy has ever consulted. |
| **I3** | A missing vector renders **blank**, never `0`, never a fabricated number, **and never the previous run's — or the previous FILE's — number. ⚠ AMENDED BY S9, which it reverted (issue 0466): a cross-frame render cache makes 'the previous file's number' reachable in one click.** `xschem reload` re-reads the `.sch` at the same path and moves none of the state a cache can observe — `set_modify(0)` bumps `modify_seq` only for mod 1|3 (`actions.c:200`), the path hash is unchanged, the raw is untouched — so a device renamed on disk keeps rendering its predecessor's value on every later frame and export until an unrelated flush. **✅ CLOSED BY S9b (2026-08-20), and the amendment is sharper than the revert made it look.** Invalidating on `load_schematic()` — whose real anchor is **`save.c:4311`**, not the `:4319` this line asserted (that is mid-prologue), and which has an early `return 0` at `:4391` reached *after* `sch[currsch]` is rewritten — is **necessary but NOT sufficient**. Four further inputs move with no epoch field behind them: `xschem reload_symbols` (`remove_symbols(); link_symbols_to_instances(-1);` and nothing else — no `set_modify`, no `clear_drawing`) changes the symbol `type=` the descriptor is keyed on; `editprop.c:1263`'s `set_modify(-2); draw();` paints a full frame *before* its caller's `set_modify(1)` at `:1289`; in-place raw mutation (`raw rename`, `raw set`) keeps the same pointer, nvars, level and `annot_p`; and `live_cursor2_backannotate` — a shipped menu checkbutton — is the formatter's FIRST gate with no C mirror. **The generalisable rule S9b settled: enumerate by INPUT OF THE FORMATTER, not by obvious user action**, give each input its own hook and its own test row (S9b's sabotage matrix reds exactly one row per hook), and add a second seam (`xschem get annot_overlay_flushes`, counting wholesale flushes inside the sync) so that "invalidate correctly" cannot be satisfied by "delete the cache". ⚠ **A DIFFERENT I3 FABRICATION IS STILL OPEN — issue 0469**: the overlay looks a device up by NAME, and `get_instance()` (`scheduler.c:187`) reads an all-digit name as an index, so a device renamed `1` — or a sheet with duplicate instance names — renders **another device's numbers** in all three back ends with no warning. Any implementation that caches across frames must be tested by re-loading the **same path** with changed content. Same discipline as the digital-database refusal in `save.c` (RULING D5-1): a plausible wrong number on a schematic is worse than no number. **⚠ HELD FOR EVERY `params` AND `derived` ROW AT S5, AND MEASURABLY VIOLATED BY `pinexpr` — issue 0446, confirmed twice.** `token.c:4364` hardcodes a GND net to `0.0` whether or not any raw is loaded, while a net absent from the raw expands to the literal `-`; `translate`'s trailing `eval_expr()` pass (`token.c:5441`) then reads `expr(- - 0.0 )` as unary minus and returns a strict-double **`0`**. So a FET with its source on GND — the ordinary topology — renders `vgs = 0` / `vds = 0` while all eight other rows correctly blank. **This needs no hierarchy and no exotic state: a flat schematic and the wrong `.raw` is enough**, which makes it the first thing a user will do wrong, not a corner case (0446 was re-scoped after its original filing described only the level-shift path). Fabrication requires exactly one operand to be a hardcoded GND; with both nets absent the expression stays non-numeric and is correctly rejected. The fix is in C — make the missing-net marker something `eval_expr` cannot absorb, or refuse the `expr()` pass over an expansion that contained it — so it is not a rider on any Tcl step. **S6 ACCEPTED IT RATHER THAN CLOSING IT (2026-08-19, ladder rung L3, decision D5)** — the carrier ships, the fabrication is reproduced through the real draw path, and it is pinned by a green check (`test_op_annot.tcl` row **K16**) that asserts the WRONG behaviour on purpose, so the C fix reds a named line instead of silently changing what a schematic shows. Only the two descriptors carrying `pinexpr` can reach it (sky130, gf180); IHP cannot. The unanswered ledger question is in 0446 under §S6 ACCEPTANCE. **HELD AT S11 for the new value source**: `gds` is deliberately absent from section T's fixture raw and renders **blank** at 1 ns, 3 ns and 99 ns alike, on a path that fabricates nothing (row **T7**). The narrow reading S11 settled, and it is binding: an **endpoint hold** is a real measured sample of a *present* vector, not a fabricated number for a *missing* one — I3 governs the second, RULING D4-4 governs the first. ⚠ **The third clause — 'never the previous run's number' — is measurably open at the raw layer**: `xschem annotate_op <same path>` does **not** re-read a resident raw, so a re-simulated design annotates the previous run's values and S11 now lets the user scrub time through them (issue **0482**, reproduced twice). |
| **I4** | The overlay never modifies the schematic. No instances placed, no `set_modify`, nothing written to the `.sch`. **HELD AT S8** — row **N16** cycles `none`→`op`→`opvolt`→`none` through the real proc, including an auto-load, and asserts `xschem get modified` is 0 with the instance count unchanged. The mask is view state, so a key press is not an edit. **HELD AT S9b ON SHIPPED DATA**: `xschem get modified` = 0 on `sky130_tests_ase/bandgap_opamp` with `annot_show 1` and 13 blocks rendered, read **before** any save; `git diff -- sky130A` = 0 bytes; row **O17** asserts the same inside the suite (13 devices, all rows blank, nothing modified). **HELD AT S9 TOO, measured four ways on the full overlay** — `xschem get modified` 0 after five mask changes and five exports; a byte-identical `.sch` across a save (7618 → 7618); `git diff` over four shipped sky130 cells after the acceptance run = **0 bytes**; and a deliberate `set_modify(1)` sabotage inside the reader was caught. ⚠ **But the row that names itself the I4 row was VACUOUS**: it read `xschem get modified` *after* its own `xschem save` (1 before, 0 after), and its file-bytes element is order-dependent — on a display `xschem load` itself redraws, so the row's first save normalises the fixture and the trailing save writes identical bytes. On `:99` the breach was caught only by two *other* rows. Read `modified` **before** the save. **HELD AT S11**: five graphless cursor moves plus a redraw leave `xschem get modified` at 0 with the instance count unchanged, read **before** any save (row **T11**). `set_modify(-2)` refreshes derived/floater caches without dirtying the sheet — mod −2 bumps `modify_seq` only for mod 1|3. ⚠ The row that exercises the *floater* half (**T22**) does not actually reach `if(floaters) set_modify(-2)`: `xschem get texts` is 0 on its fixture, so `there_are_floaters()` returns 0 and the guarded call never runs — issue **0481** §3. **⚠ AMENDED BY S3d — THE WALK CANNOT HOLD THIS TODAY, AND IT WAS ASSERTED ANYWAY.** A hierarchy walk ascends with `xschem go_back`, and **`go_back` dirties the parent**. Measured on a shipped bench (`sky130_tests_ase/bandgap_opamp`, 73 instances): `modified BEFORE=0 AFTER=1`, isolated to `DIRTY inst=x1 ... afterdescend=0 aftergoback=1` — `descend` leaves the flag alone, `go_back` sets it. Worse, descending **clears** a genuinely-dirty flag on the way down (`before=1 afterdescend=0`), so a walk over a modified sheet also destroys real state. The shipped sky130 prototype does the same. Attempt 4 repeated this invariant verbatim in `save_cards`'s own header while violating it, and its guardian (row W19) could not fail because its fixture was a synthetic file_version 1.2 `.sch` the test itself wrote. **Until `go_back` is fixed or the flag is snapshotted and restored, I4 must NOT be claimed in a walk's source comments, and any guardian for it must run on a SHIPPED schematic.** Issues **0495**, **0499**. |
| **I5** | A user's `op_annot::register` overrides the PDK's, and takes effect on redraw — no restart, no rebuild. **⚠ "their own rc" is measurably wrong for `~/.xschem/xschemrc`**: xschemrc is sourced at `xinit.c:3234-3292`, *before* `xschem.tcl` at `:3401`, so `op_annot::register` there dies with `invalid command name`. The override must go in a file sourced after startup — a `--script` rc such as the PDK workareas' `cadence_style_rc`, or the console. S1 corrected the claim rather than the ordering; making xschemrc work would mean defining the namespace before the rc pass, which is a C change nobody has needed yet. |
| **I6** | The hierarchy walk restores `no_draw`, `no_undo`, `keep_symbols` and the original `sch_path` on every exit path, including error paths. The IHP prototype's `go_back 2` pairing is the reference for the **descend/ascend shape only — ⚠ it does NOT satisfy this invariant.** Measured: `sky130_save_fet_params` on `sky130_tests/test_generators` raises `Symbol not found` and leaves `no_draw=1 keep_symbols=1` set, because the restore is on the normal path and there is no `catch`/`finally`. S3 must wrap the walk body in `catch`, restore unconditionally, then re-raise — and must force a raise in its test rather than asserting only on the happy path. Issue **0431**. **S3 addenda, all measured:** the unwind is bounded by the **entry** level, not by 0 (`src/xschem.tcl:3857`'s `while {[xschem get currsch]} …` would ascend past a caller that was already descended); the restore must also pop the `log_action -suppress` scope it pushed, since an unpopped one silences the user's action log for the rest of the session; and **`no_undo` cannot be restored to its entry value because `xschem get no_undo` does not exist** (setter only, `scheduler.c:12030`; returns `{}` whether the flag is 0 or 1). 0 is the only restorable value, so a caller who wraps the walk in its own `no_undo 1` scope has it **silently disarmed** — measured `{3 2 2}` before, `{3 2 3}` after. Issue **0432**. **⚠ AMENDED BY S3d — I6 IS A MEMORY-SAFETY BOUNDARY, NOT A TIDINESS RULE.** A sabotage variant that deleted the restore crashed xschem deterministically, 3 legs of 3: `propagate_hilights(): .ptr<0, unbound symbol: inst 0, name=MP1 sch=w_bare.sch` → `FATAL: signal 11`. Issue **0498**. **⚠ CORRECTED AND LARGELY CLOSED BY X0498 (2026-08-22) — read this before writing a walk.** Two things this cell asserted are **measured false**. (a) It is **not** “carried across a schematic load”: three consecutive `xschem load` calls with the flags leaked survive cleanly, because `scheduler.c:7611`'s `keep_symbols` is the local **`-keep_symbols` argument**, not the Tcl global. The carrier is **`xschem netlist`**. (b) **`keep_symbols` alone is harmless**; `keep_symbols=1` and `no_undo=1` are **jointly** necessary — measured matrix: `1/0`→SURVIVED, `0/1`→SURVIVED (symbol table silently emptied), `1/1`→SIGSEGV. The real mechanism is that every C hierarchy walk (the five `global_*_netlist` drivers and `hier_psprint`) restores the user's document by **exactly one mechanism** — its own `push_undo`/`pop_undo` pair — and `no_undo` silently no-ops **both halves**, so the walk descends and never comes back. X0498 fixed that in the C: `undo_shield_push()`/`undo_shield_pop()` (`src/netlist.c`) park `no_undo` at 0 across each walk's own pair and restore the caller's value on **every** exit path including the `fopen` error return, and `INST_UNBOUND()` (`src/xschem.h`) guards the four unbound-instance dereferences that faulted (`hilight.c`, and the three guard-after-deref sites `draw.c`/`psprint.c`/`svgdraw.c`). **Consequence for S3 and for every later walk: a leaked `no_undo` can no longer corrupt or crash the netlisters.** I6 remains binding — a leak still leaves `no_draw=1` (a dead screen), still leaves the hierarchy where it stopped, and still silences an unpopped `log_action -suppress` scope — but an I6 slip now presents as a **diagnosable wrong answer, not a segfault**, which is exactly what the four reverted S3 attempts needed. **Anchor correction, applied above:** `xschem get no_undo` still does not exist and the setter is at **`scheduler.c:12030`** — every revision of this cell before 2026-08-22 said `11958`, which had drifted. Probe `no_undo` **by effect**, never by a getter. **Class narrowed, not eliminated:** `xctx->sym[xctx->inst[i].ptr]` is still dereferenced unguarded in `move.c` (12 sites), `editprop.c` (6), `save.c:4328`, `netlist.c` and `select.c:1507`, and `go_back` has its own `pop_undo`-shaped restore that X0498 did **not** shield. |
| **I7** | `hide=true` **and `hide=instance`** semantics are unchanged for every existing symbol in every library. **⚠ RESTATED BY S7 — the original wording named only `hide=true`, and `hide=instance` is the one that was actually at risk.** Counted across all tracked `.sym`/`.sch`: `hide=instance` **630 occurrences / 244 files**, `hide=true` **166 / 62** (47 / 22 before S10b, plus the 119 sky130 records in 40 files that S10b added — issue 0475; gf180's 38 are unchanged **by design**, and row L22 is the tree's only non-vacuous fixture for this half of I7), `hide=op` **2** (the twin `annotate_params.sym`), `hide=voltage` **0** — no other `hide=` value exists anywhere, so the acceptance sweep is a bounded, nameable list rather than a spot check. The threat was never the class bits; it was collapsing ten visibility tests that mask **two different things** into one fixed mask (§2.4). **HELD AT S7**, verified three independent ways: rows L11–L14 and L19–L22 of `test_op_annot.tcl`; the adversary's own fixtures (all 57 `xschem_library/devices/*.sym` carrying `hide=instance`, and the 19 gf180mcu FETs carrying `hide=true`, exported to SVG at `annot_show` 0 vs 3 at both `show_hidden_texts` states — byte-identical, and **non-vacuous** because the same corpus does differ between `show_hidden_texts` 0 and 1); and a re-run of the pre-S7 before-state script, whose `hide=true` (0 at `sht=0`, 158 at `sht=1`) and `hide=instance` (0 on a symbol, visible at top level) numbers came back byte-for-byte. ⚠ **PS byte-comparison is unsound** until issue **0454** is fixed — `xschem print ps` ends every page with an uninitialised RGB triple that changes between exports of identical content; L20/L22 compare a normalised copy (`opa_l_normps`) and L21 keeps that normalisation non-vacuous. |

| **I8** | **A parameter the descriptor asked for and the raw did not deliver is REPORTED, not merely blank.** Added by ruling **D9** (2026-08-22). I3 governs what the *schematic* shows and is unchanged — the row stays blank, and no number is ever fabricated. I8 governs what the *tool* says: the mismatch between what was requested and what arrived goes to the **CIW and to the logfile**, once per (device, parameter) per annotate pass, never per redraw. The motivating measurement is issue **0429**: ngspice-42 rejects a `.save` card by exiting **0** with no raw file at all, and the only trace is a single `Warning from checkvalid:` line in a log the user is not reading. A blank row cannot distinguish *"this device is off"* from *"your simulator does not know that parameter"* from *"your raw file was never written"*, and the user needs the second and third said out loud. **Not yet implemented** — the requirement is ratified, the mechanism (where CIW output goes, how the once-per-pass dedup is keyed, what a wholly-absent raw reports as distinct from a single absent vector) is the owed step. |

### 5.1 Shipped and unratified — the questions this run owes a human

Collected here, in one place, so they can be answered in one sitting. **NINE
rows, one per issue file** — 0424 was **closed** and 0429 **superseded** on 2026-08-22, and their rows are kept, struck, rather than deleted, so the count still checks — a reader can check the list is complete by that
count. Every file named below was verified to exist on disk by the S12 write-up
agent (2026-08-21).

The heading is deliberately **not** "open questions". Three of these are not
questions at all in their own headers: 0429 and 0444 are marked **FIXED/RULED**
and still owe a ratification, and 0424 is an **owed action** (a `./configure`
run) rather than a decision. The honest framing is *shipped, and nobody with
authority has signed it off*.

| # | kind | the question |
|---|---|---|
| **0424** | ~~owed action~~ **CLOSED 2026-08-22** | `make install` shipped an `xschem.tcl` sourcing an **uninstalled** `op_annot.tcl`; the installed binary SEGFAULTed at startup. `./configure` + rebuild ran with the user's authority: install lines 0 -> 2, staged `make install DESTDIR=` launches at EXIT=0, and the negative control (helper hidden) still gives 139. Encoded as crew rule 2b and a `CLAUDE.md` bullet. **0423 stays open** — a missing sourced helper should print and exit, not segfault. |
| **0429** | ~~ratification~~ **SUPERSEDED 2026-08-22** | ruling **D9** cuts the MOS default to `id gm gds vgs vth vds`, so neither capacitance is in the default set and there is nothing left to ratify. `cgs`/`cgd` are not substituted for anything. All six defaults are measured savable on ngspice-42 **and** 46+, on sky130 **and** gf180 — the ngspice-side check 0429 said was owed. See §4.2a. |
| **0444** | ratification, **narrowed by D9** | a registered `pinexpr` whose @-token abuts `)` can never produce a number. The C tokenisation is unchanged — but under D9 **no shipped descriptor carries a `pinexpr`**, so this is now a trap for a user writing her own, not something between a stock user and her numbers. *(Note: this is the **swallowed closing paren** — the "stray space" is the symptom in §4.4's symbol text, not the defect.)* |
| **0446** | ratification, **off the shipped path by D9** | a pin expression fabricates **`0`** when one terminal is GND and the other net is absent from the raw — an I3 fabrication reachable from a flat schematic and the wrong `.raw`. Accepted in writing by S6b (decision D5) and pinned by row **K16**, which asserts the wrong behaviour on purpose. |
| **0447** | ratification | `op_annot::text` **raises** on a malformed descriptor list while its own header says it never does. Accepted alongside 0446 by S6b (decision D6). |
| **0457** | ratification | `annot_show` has no stock, non-`cadence_style_rc` control — a user not on that profile has no shipped way to reach the mask. S8's E question. |
| **0475** | ratification | the 40 shipped sky130 FET symbols' annotation texts are gated behind **`hide=true`** rather than `hide=op`. S10b measured `hide=op` and **refuted** it (both `hide=op` and the overlay answer to `annot_show` bit 0, so a `hide=op` text becomes visible exactly when its replacement does), then shipped `hide=true`. S10b's E question. |
| **0476** | ratification | annotation texts **outside** sky130 that answer to no visibility knob at all — including the `annotate_params.sym` carrier's IHP ancestor. |
| **0479** | ratification | a cursor placed **outside** the data holds the endpoint and says nothing. S11 deliberately kept the graphless path identical to the graph path (invariant I1) rather than blanking, because no row compares the two. S11's E question. |

**Why these accumulated rather than blocking.** Every one of them was found by a
step that had already shipped its behaviour, under decision-ladder rung **L3**:
implement the least-surprising option, then hand the user the exact question.
Nine such questions in one feature is itself a signal — this feature changes
what a schematic *shows*, so almost every choice is user-visible.

*(Collected by the S12 write-up agent. The S12 implement agent produced no
change; see the S12 block of the plan for what else that step still owes.)*

---

## 6. Landmines

1. **R2 — an explicit save cancels save-all.** Measured. A generated block
   without `save all` silently deletes every node voltage from the raw, so the
   feature that was supposed to *add* information removes some.
2. **The element-letter prefix is PDK-specific and is not `m`.** sky130 and
   gf180 use `@m.`; IHP uses `@n.` (psp103 through OSDI) and `@q.` for HBTs.
   Anything that hardcodes `m` works on two PDKs out of three.
3. **The inner device name is PDK-specific**: `msky130_fd_pr__<model>` vs `m0`
   vs `n<model>` (with `_5t` stripped for some IHP bipolars). This is why the
   descriptor takes a template and a proc escape hatch, not a fixed rule.
4. **`sch_waves_loaded()` ties the data to `raw->schname` / `level`.** Descending,
   ascending or opening another schematic makes the same data silently invisible
   (returns −1) without freeing it — easy to misread as data loss. Set
   `raw_level` when a top-level raw must annotate a sub-schematic.

   **⚠ THIS IS THE LANDMINE THAT REVERTED S3, and it is sharper than the
   paragraph above suggests.** It does not only hide data; it silently *rewrites
   the names a hierarchy walk emits*. The chain, all confirmed in the C:
   `save.c:1260/1410/2153` bind `raw->schname` to `xctx->sch[xctx->currsch]` —
   **whatever cell the user happened to be standing in when the raw was loaded**;
   `draw.c:2831-2838` then re-matches that filename against every level *as the
   walk descends*, so the match point moves during the walk; and
   `scheduler.c:5150` `sim_sch_path` **strips every path component above the
   matched level**. Consequence: with a raw loaded one level down, two different
   instances of the same subcircuit **collapse to the same device path**.
   Measured on a 3-level fixture: 8 cards, only **5 unique**, and no warning
   anywhere. Reachable in two clicks, because "Annotate Operating Point into
   schematic" loads a raw at the current level. So `sim_sch_path` is a **read**
   primitive; anything that *writes* a name for a deck must ask for an absolute
   basis. Issue **0436**.

   **✅ SETTLED BY S3b, ruling D2 — and the answer has a second half the issue
   did not record.** The write basis is `xschem get sch_path` (which no loaded
   raw can perturb) minus the walk's **entry** path — i.e. **ENTRY-RELATIVE, not
   level-0-absolute**. Settled by measurement, not preference: `xschem netlist`
   invoked from a descended cell writes **that** cell as the deck top, so
   entry-relative is the only basis naming devices the generated deck actually
   contains; it is also what both PDK prototypes' `startpath` arithmetic
   produces, and it makes `<cell>.save` agree with its own body. The two bases
   coincide only when the walk starts at `currsch 0` — which is why a test suite
   that never enters descended and never loads a raw cannot tell them apart.

   **⚠ `@path` IS A SECOND RAW-RELATIVE SOURCE, AND IT LIVES IN THE C.**
   `token.c:4719` is a byte-for-byte copy of `sim_sch_path`'s stripping loop, so
   a fix that only swaps the Tcl `sim_sch_path` call passes every sky130 test
   (sky130 goes through a `devproc`) while leaving gf180's and IHP's `@path`
   **templates** silently raw-relative. The write basis must `string map` `@path`
   away *before* `xschem translate` sees it — never `subst`, since a template is
   user data and `subst` would execute embedded `[...]`. Any test for this must
   cover the template arm **and** the devproc arm; each is caught only by its own
   row. S3b implemented all of this, the adversary could not break it along six
   attack lines, and the code is preserved in
   `doc/claude/issues/0442-attempt-2-reverted.patch`.
5. **The hierarchy walk is destructive if it leaks.** It descends the real
   design with undo and drawing disabled. Any early return that skips the
   restore leaves the editor in a state where edits are not undoable and the
   canvas does not repaint.
6. **`show_hidden_texts` is not a per-PDK-consistent switch today** — sky130's OP
   texts ignore it. Anything that reasons "the OP text is hidden unless the user
   asked" is wrong on sky130.
7. **Instance names are case-mixed.** `get_raw_index()` retries as-is, upper,
   lower and `v(…)`-wrapped, which covers it — but a new name builder that
   bypasses `get_raw_index` will not be covered.
8. **A one-point OP raw and a multi-point tran raw are the same code path.**
   `xschem raw value <v> -1` returns the OP value in the first case and the
   cursor-B value in the second, which is exactly what makes C and D one feature.
9. **⚠ A save card for a device that does not exist produces a column of
   `0.0`, not a missing vector — under `-b -r`. Under the bench idiom it
   produces NO RAW AT ALL.** Added by S1, measured on `ngspice-42`; the idiom
   split was added by S3 — see **R5**, and read it before trusting the paragraph
   below, which describes `ngspice -b -r out.raw` only. Under the
   `.control … write … .endc` form every shipped PDK bench uses, the same bogus
   card gives `Warning from checkvalid` and no raw file (issue 0429/0434). Both
   are threats to **I3**; the first fabricates a number, the second destroys the
   whole run. A deck carrying
   `.save @m.xnope.m1[id]` for a device that is not in the netlist emits one
   line — `Warning: unrecognized variable - @m.xnope.m1[id]` — on stderr and
   then writes a **full column named exactly what was asked for**, holding
   `0.0`. Confirmed for all three kinds (`[id]` → `i(…)`, `[vdsat]` → `v(…)`,
   `[gm]` → bare); the value was decoded out of the binary raw and is `0.0`, not
   a NaN and not an absent point.

   So a wrong descriptor — wrong element letter, wrong inner-device name, wrong
   hierarchy prefix — does **not** render blank. It renders `0`, which the
   display cannot distinguish from a real `gm` of zero. That is precisely the
   "plausible wrong number" I3 and `save.c` RULING D5-1 exist to forbid, and it
   arrives from the simulator rather than from our code, so no amount of care in
   `op_annot` prevents it. The two things that *do* detect it are: capturing
   ngspice's `unrecognized variable` warnings and saying so on the status line
   (§4's requirement 4), and noticing that a device's parameters are *all*
   exactly zero. Neither is implemented.
10. **A new `.tcl` helper is not installed until `./configure` is re-run.**
   `src/Makefile` is generated from `Makefile.in`, gitignored, and has no
   regeneration rule, so adding a file to `install_shares` leaves `make install`
   stale — and a `source` line for a file that is not installed is a **startup
   SIGSEGV**, not a missing feature (issues 0424 and 0423). Invisible in-tree,
   because `XSCHEM_SHAREDIR` resolves to `src/` there.
11. **⚠ A CORRECT ORACLE ASKED THE WRONG FIXTURE PROVES NOTHING — this is how
   BOTH S3 attempts shipped a refuted deliverable past a green suite.** Attempt 1
   passed 85 checks and 11 sabotage variants while missing two defects, because
   no row loaded a raw or placed a non-netlisted instance. Attempt 2 passed 96
   checks and 8 sabotage variants while missing four netlister drop classes,
   because its `xschem netlist` cross-check row — the right idea, and the very
   acceptance issue 0437 asked for — ran on a **flat** fixture whose only
   variants were the classes already handled. Verify-B caught the tell both
   times and it is worth naming: a sabotage variant whose predicted red **does
   not appear** means the fixture cannot reach that code path. In attempt 2,
   `filter_skips_cards_but_still_descends` was predicted to red the cross-check
   row and did not, which was the visible edge of the whole gap. **Treat a
   missing predicted red as a fixture defect to be fixed before the step
   lands — not as a lucky pass and not as a prediction error to be footnoted.**

10. **⚠ `op_annot::register` VALIDATES ALMOST NOTHING, AND THE COST LANDS AT DRAW
    TIME.** Measured at S5 (issue **0447**): `register` checks only `dict size`,
    so a descriptor whose `params`, `pinexpr` or `derived` value is not a
    well-formed Tcl **list** is accepted at rc=0 and stored; `op_annot::text`
    then raises `unmatched open brace in list` from its `foreach row [dict get
    $d …]`, at draw time, on all three keys independently. Reachable through
    **I5** — a user's own `register` in an rc — from a single unbalanced brace.
    The same file already treats exactly this class as a *data* condition for
    the `match` glob list (`op_annot::_matches` catches, `devpath` returns `{}`),
    so the discipline exists and was simply not carried across. Validate at
    registration, where the failure lands next to the typo, rather than
    catching at read, where it is silent. **Whoever fixes it should also close
    the coverage hole found in the same pass**: `op_annot::text`'s three early
    returns (type, descriptor, devpath) are mutually redundant, and deleting any
    ONE of them reds nothing at all — 97/97 stays green — so no single-point
    failure in any of them is currently detectable.

11. **⚠ A GREEN SUITE CAN BE MEASURING A FILE YOU ARE NOT SHIPPING.** At S5 the
    Red agent's reference implementation lived in `/tmp` and scored 97/97
    through a source-shimming wrapper, and the planned edits were separately
    found already on disk from an interrupted earlier attempt. Identical green,
    two different files. The only thing that distinguished them was applying
    every sabotage variant to the **production** file and confirming the
    predicted rows red there. Do that before believing a pass, and record the
    `md5sum` of each shipping file in the report — the S5 crew did, and it is
    what let a later agent verify the tree had not drifted under it.

12. **⚠ TWO AGENTS SABOTAGING ONE CHECKOUT CONCURRENTLY IS A CREW HAZARD.**
    Across the S5 verification passes the same suite was observed at 97, 95, 96
    and 85 checks within minutes, because sabotage was being applied and
    reverted on the shared working tree while another agent measured. The red
    sets matched other agents' sabotage predictions exactly. **Anyone reading a
    red `test_op_annot.tcl` from this run's logs must check `md5sum
    src/op_annot.tcl` before believing it.** Serialize sabotage passes, or give
    each one its own worktree.

13. **⚠ A ZEROED `Graph_ctx` IS A DEGENERATE WINDOW, NOT A NEUTRAL ONE.** Added
    by S11, after the design it recommends was built and refuted. RULING D4-7's
    `rescan_no_window` (`callback.c`) makes "no window" safe — but a
    `memset`-0 ctx is the window `[0,0]`, and **every transient raw has a sample
    at exactly t = 0**, which *passes* the filter. So `first` becomes 0 rather
    than −1, the rescan never fires, and `interpolate_yval()` clamps `frac` to 1
    and walks one segment forward: **point 1's value for every t past the second
    sample**, silently. Measured `v(d) = 1` where point 3 holds 3.0. Anyone
    standing a `Graph_ctx` up outside `draw_graph()` must set an explicit window
    (`±HUGE_VAL` for the whole sweep). The same defect is live and *unfixed* on
    the graph path, which borrows the shared `xctx->graph_struct` — issue 0480.

14. **⚠ A ROW CAN BE GREEN FOR A REASON THAT HAS NOTHING TO DO WITH THE
    MECHANISM IT NAMES.** Added by S11, whose sabotage matrix caught 5 of 8
    exactly and **missed three**. A cursor move **across** a segment boundary
    changes `raw_annot_p`, which flushes the overlay on its own, so three rows
    written to prove "the invalidation goes through the public entry" stayed
    green with the public entry bypassed — only a **within-segment** move can
    see that field. Likewise "past the end it holds the last sample" is enforced
    by an `(p + 1 < ofs_end)` early return, not by the clamp the row names, so
    deleting the clamp reds nothing above the lower bound; and the floater row
    never reaches the line it was written for because its fixture has no floaters
    (`xschem get texts` is 0). **When a row asserts a contract, sabotage the
    contract — not the feature — and check the row is what goes red.** Issue 0481.

---

## 7. Out of scope (named, so it is not accidentally assumed)

* Voltages on **unlabelled** nets. Today a voltage needs a label/pin/probe
  symbol on the net (D1). A per-net overlay is a separate feature.
* Xyce and Vacask device-parameter naming. The descriptor can express them, but
  no descriptor is written here and none is tested.
* Implementing the dead `@spice_get_modelparam_<p>(<dev>)` /
  `@spice_get_modelvoltage_<p>(<dev>)` token branch. **Filed as issue 0484**
  by S12 (and its element-letter twin as **0485**); this design does not need
  either. ⚠ The anchor this bullet used to carry, `token.c:5023`, was stale —
  the branch that consumes all three token families is **`token.c:4996`**,
  guarded by the regex at `token.c:4646`.
* Removing the PDK symbols' own OP texts. A one-time scripted edit per PDK,
  sequenced after the overlay, not a prerequisite for it.
* Annotation of AC / noise / sweep results.

---

## 8. Verification

* **Headless gold**: a one-MOSFET cell → `op_annot::save_cards` output golded as
  text → run ngspice → `annotate_op` → `op_annot::text` output golded as text.
  `tests/headless/` has the gold infrastructure; `create_save` / `open_close` /
  `netlisting` have no baseline and can only report `NOGOLD`.
* **Hierarchy walk**: a 3-level design, gold the card list, and assert
  `no_draw` / `no_undo` / `keep_symbols` / `sch_path` are restored (I6).
* **Cross-PDK**: the same test cell shape under each registered descriptor,
  asserting the built vector names match what ngspice actually wrote — read the
  raw header back and diff the two name sets. This is the direct test of I1.
  Two corrections from S1, both measured:
  * **One interpreter per PDK.** All three PDKs (and the generic
    `xschem_library/devices/nmos.sym`) use the symbol type `nmos`, which is the
    descriptor key, so the second `op_annot::register nmos` destroys the first.
    Issue 0425.
  * **The name diff is necessary but NOT sufficient.** Landmine 9: ngspice
    fabricates a `0.0` column under exactly the name you asked for, so a
    completely wrong descriptor still passes a name-set diff. The diff proves
    the two *sides* agree; it does not prove the name is *real*. Pair it with an
    assertion that the values are not all zero, and with a check of ngspice's
    stderr for `unrecognized variable`.
* **The name builder itself**: `tests/headless/test_op_annot.tcl` (S1, 32
  checks) — golden device path and all three wrapper kinds against a sky130
  `nfet_01v8` at `sim_sch_path` `x1.`, descriptor storage/replacement, the
  blank-vs-raise error discipline, live (uncached) `sim_sch_path`, and a check
  that building a name modifies nothing (I4). Run it as
  `./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_annot.tcl`.
* **The carrier** (S6, `test_op_annot.tcl` section K, 17 rows): both copies of
  the symbol exist and are byte-identical (K1 — the only guard on issue 0450);
  the `tcleval` text extracted **from the shipped file** renders the same block
  as a direct `op_annot::text` call, blank without a raw and the S5 golden with
  one (K8/K10); the no-space spelling derived from the same file's bytes renders
  `?` (K11, the 0444 control); `place_annotator` pre-fills `ref` from the
  selection, falls back to the template with nothing selected, and does not
  disturb `modified` (K12–K14). **Known gaps, both real:**
  * every committed row runs under ONE PDK (sky130). The step's own acceptance
    — "place next to a FET on each of the three PDKs" — is verified by no
    committed check; S6 verified it by hand under xvfb (IHP `@n.xm1.nsg13_lv_nmos`
    with element letter **n**, gf180 `@m.xm1.m0`, sky130
    `@m.xm1.msky130_fd_pr__nfet_01v8`, all populated). Issue 0425 (one
    interpreter per PDK) is why it is not one suite.
  * the menu item itself is covered only by a **source grep** (K15), because the
    Graphs cascade is built under `if {[info exists has_x]}` and `--nogui` never
    enters it. All the logic that can fail lives in `op_annot::place_annotator`,
    which K12–K14 do drive for real.
* **The annotation classes** (S7, `test_op_annot.tcl` sections L and M, 32
  rows — 115 → **147** checks headless, **149** under a display). The mask's
  surface (L1–L4: default 0, the Tcl mirror, the setter reaching C *and*
  pushing back to Tcl); the gate itself (L5–L10: `hide=op` iff bit0, `hide=voltage`
  iff bit1, and both ignoring `show_hidden_texts` in **both** directions);
  I7 (L11–L14 the four hide values × both switches, L19–L22 the shipped
  corpora with L21 as the non-vacuity partner); the two export paths the plan
  called "the ones nobody looks at" (L15/L16, SVG **and** PS, symbol **and**
  top-level); the anti-staleness rows 0453 would otherwise have inflicted
  (L17 first-export-is-correct, L18 one `update_all_sym_bboxes` suffices);
  the end-to-end carrier (L23–L25); and three structural rows (L26 the token
  now has teeth, L27 `HIDE_TEXT` survives in `src/*.c` only inside
  `set_text_flags` and `text_hidden`, L28 the two Tcl mirror lines). **L29 is
  the control that makes L3 mean anything**: `xschem set zzz_garbage 1` still
  errors while `xschem set annot_show 1` does not — without it, L3 could be
  satisfied by the `argv[2][0] < 'n'` silent fall-through that swallowed
  `xschem set annot_show 1` before this step.
  * **Two things `--nogui` cannot reach.** `calc_drawing_bbox`'s text loop is
    inside `if(has_x && selected != 2)` (`actions.c:4416`), so the tenth site is
    reachable only under a display — rows M1/M2, which self-skip headless.
    And `tests/property_form/wrap.tcl` **silently aborts** under `--nogui` at
    `slickprop::init_fonts` after ~36 checks, never reaching the `hide`-token
    rows; run it as `cd src && DISPLAY=:99 GUI_GATE=0 ./xschem -q --nolog
    --script ../tests/property_form/wrap.tcl` (284 → **288**, the +4 being
    PF-S7a..d, which pin issue 0452's *current wrong* behaviour on purpose).
  * **`xschem print svg|ps` IS a headless oracle** in its explicit-viewport
    form, `xschem print svg <file> <w> <h> <x1> <y1> <x2> <y2>`
    (`scheduler.c:9829`). An earlier comment in `test_op_annot.tcl` claiming
    otherwise was true only of the no-viewport form, and it would have pushed
    four of the ten sites behind xvfb for no reason.
* **The draw-time overlay** (S9b, `test_op_annot.tcl` section **O**, 38 rows —
  172 → **209** checks headless, **214** under a display). Two halves, and the
  second is the one the retry exists for:
  * **the overlay itself** (O1–O20): the SVG site, the PS site, the screen seam,
    the D1 non-blank-block gate, `annot_dx`/`annot_dy`, I4 read **before** the
    save, and O17's honest acceptance — 13 devices annotate on
    `sky130_tests_ase/bandgap_opamp`, **all rows blank** (S3/S4 deferred, no
    save-card generator, so a real PDK raw carries no device vectors and I3
    requires blank), nothing modified.
  * **the invalidation** (O21–O38): a device renamed on disk and re-read by
    `xschem reload` (O21, issue 0466's literal repro) and by
    `load -keep_symbols` (O22, the clean HOOK-A isolator, where
    `remove_symbols()` never runs); `model=` rewritten under an unchanged name
    (O23, which reds any implementation whose only guard is
    `strcmp(cached_name, instname)`); a no-change reload leaving two exports
    **byte-identical** (O24, the anti-fabrication control — "invalidate more"
    must not become "render non-deterministically"); sibling descend (O25, but
    see issue **0471** — it guards the wrong mechanism); undo/redo (O26); the
    same raw path rewritten and re-annotated (O27); `setprop … name` (O28,
    honestly already covered by `set_modify(1)`); `live_cursor2_backannotate`
    (O29, the only row that reds if epoch term 14 is missing); `raw rename`
    blanking **only its own row** while siblings keep their values (O30, the
    discriminator between correct invalidation and blanking everything);
    `reload_symbols` after a `type=` change (O31, the only row that reds if
    HOOK C is missing); the four **flush-seam** rows (O32–O35, without which
    every staleness row above is satisfiable by deleting the cache); a
    window/tab switch (O36); `raw switch` under a static schematic (O37); and
    two consecutive redraws flushing **zero** times (O38, the screen-path proof
    that a cache still exists).
  * ⚠ **Run it on a display as well as headless, and WITHOUT `--nogui`**:
    `GUI_GATE=0 xvfb-run -a -s "-screen 0 1920x1080x24" ./src/xschem --pipe -q
    --nolog --script tests/headless/test_op_annot.tcl`. O14, O36 and O38
    self-skip headless, and the `draw_site_stub` sabotage variant (screen
    renderer replaced by an empty static) prints `ALL PASS (209 checks)`
    headless while reddening O13/O14/O17/O38 on the display.
  * ⚠ **The suite is in NO tier runner** (issue **0465**): `grep -c op_annot` is
    0 in both `tests/run_regression.tcl` and `tests/headless/run.sh`. T1 and T2
    cannot see this feature in either direction.
* **Timepoint annotation with no graph** (S11, `test_op_annot.tcl` section
  **T**, 23 rows — 218 → **241** headless, 223 → **246** on a display; the same
  +23 on both legs, no row is display-only). Three groups, and the middle one
  matters most:
  * **the new path** (T0–T11, T16–T22): `annot` `{0 0 -1}` → `{2 3e-09 0}`,
    node **and** device vectors moving together, interpolation between samples,
    the I3 blank rider on a vector absent from the raw, I4 read before any save,
    the flush-seam pair, and T21 — a plain non-graph rect on GRIDLAYER with no
    graph anywhere still annotates (the row that discriminates decision D1 from
    the rejected `rects == 0` trigger).
  * **the graph-present regression** (T12–T15), which the step brief weights
    *above* the new path. All four graph states are pinned including the two
    **wrong** ones — T13 the undrawn degenerate window (0480), T14 the rect-zero
    hard-code (0477), T15 the `graph_flags & 4` gate (0478) — so a later repair
    reds a named line instead of passing unnoticed. The external half of this
    oracle is the four shipped cursor suites at exactly 93 / 81 / 57 / 56; **do
    not add rows to them**, their integers are the baseline.
  * ⚠ **three rows do not discriminate what they name** — issue **0481**. Read it
    before trusting section T as protection for decision D4 or D7.
  * ⚠ The mandatory ordering trap in every graph row: `xschem cursor 2 1`
    **resets** `graph_cursor2_x` to 0, so it must precede `set cursor2_x`
    (issue 0478).
* **Pixels**: the overlay is a look-at-it deliverable and no green suite can
  clear it. `tests/headless/owed.sh add look "op annotation on tb_bandgap"`.
  ⚠ S9b's acceptance was met **programmatically** (13 devices, `modified` 0,
  `git diff` 0 bytes, perf table re-measured); the `6` / `Ctrl-6` **keystroke**
  leg and a human eyeball on the pixels are recorded as a `look` debt, not
  discharged. A green suite never clears a look debt.
