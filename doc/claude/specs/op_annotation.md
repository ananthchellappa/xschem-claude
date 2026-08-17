# Spec — operating-point annotation on the schematic

*Put simulation results — node voltages and per-device operating-point
parameters — on the schematic, under three keys, with the displayed parameter
list editable by the user and portable across PDKs.*

Status: **S1 landed; S2–S12 not implemented.** Branch `annotate`.
Plan of atomic steps: `doc/claude/suggestions/next_session_prompt_op_annotation.md`.

**S1** (2026-08-16) delivered `src/op_annot.tcl` — the namespace, `register` /
`descriptor` / `type` / `devpath` / `vector`, sourced from `src/xschem.tcl` —
plus `tests/headless/test_op_annot.tcl` (32 checks). Implementing it corrected
four things this spec asserted: the `devpath` templates in §4.2 (issue 0422),
the save-card side of **I1** (rule **R4** and §5 below), **I5**'s claim about
user rcs, and §8's cross-PDK test. Each correction is marked *measured* where it
appears.

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

**The single value accessor**, and the one this spec builds on:

```tcl
xschem raw value <vector-name> -1     ;# value at the current annotation point
```

(`scheduler.c:10312` — with point `-1` it falls through to `cursor_b_val[idx]`,
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
`set_text_flags()` `actions.c:1121`). The test is copy-pasted at **nine** sites:
`draw.c:868, 1131, 10266, 10556`, `svgdraw.c:923, 1290`, `psprint.c:1205, 1664`,
`select.c:709`, `actions.c:4422`.

It is all-or-nothing and it hides unrelated things too. It also behaves
differently per PDK: **sky130's OP texts do not set `hide=true`**, so once data
is loaded they are on screen permanently; gf180's do.

> `doc/claude/code_analysis/waveform_subsystem_reference.md` §6 says "Op text is
> layer-15 (hidden unless `show_hidden_texts=1`)". That is wrong — hiding comes
> from the attribute, not the layer — and should be corrected when this lands.

---

## 3. The measured constraint: ngspice saves nothing by default

Measured with the installed `ngspice` on throwaway decks (`.op` on a
subckt-wrapped MOS, mirroring the PDK device shape):

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
  must not assume the user did.)

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
    params  {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2}
             {cgg cgg 1} {cgso cgso 1} {cgdo cgdo 1}}   ;# ⚠ cgso/cgdo: issue 0429
    derived {{ft    {$gm/(2*3.141592654*($cgg + $cgdo + $cgso))}}
             {gm/id {$gm/$id}}}
    pinexpr {{vgs {expr(@#1:spice_get_voltage - @#2:spice_get_voltage)}}
             {vds {expr(@#0:spice_get_voltage - @#2:spice_get_voltage)}}}
  }
}

# --- gf180mcu -------------------------------------------------------------
# Inner device measured uniform `m0` across all 19 nfet*/pfet* symbols.
foreach t {nmos pmos} {
  op_annot::register $t {
    devpath {\@m.@path@spiceprefix@name\.m0}
    match   {*gf180mcu_pr/*}
    params  {{id id 0} {gm gm 1} {gds gds 1} {vth vth 2} {vdsat vdsat 2}}
    derived {{gm/id {$gm/$id}}}
    pinexpr {{vgs {expr(@#1:spice_get_voltage - @#2:spice_get_voltage)}}
             {vds {expr(@#0:spice_get_voltage - @#2:spice_get_voltage)}}}
  }
}

# --- IHP sg13g2 (psp103 via OSDI: element letter `n`, inner device n<model>) --
foreach t {nmos pmos} {
  op_annot::register $t {
    devpath {\@n.@path@spiceprefix@name\.n@model}
    match   {*sg13g2_pr/*}
    params  {{ids ids 0} {gm gm 1} {gds gds 1} {vth vth 2} {vgs vgs 2}
             {vdss vdss 2} {vds vds 2} {cgg cgg 1} {cgsol cgsol 1} {cgdol cgdol 1}}
    derived {{cgg_tot {$cgg + $cgsol + $cgdol}}
             {ft      {$gm/(2*3.141592654*($cgg + $cgsol + $cgdol))}}
             {gm/id   {$gm/$ids}}}
  }
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

### 4.3 The two consumers

**`op_annot::save_cards {}`** — walk the hierarchy (the `sg13g2_sch_expand`
recursion, generalized and de-prefixed: `no_draw 1` / `no_undo 1` /
`keep_symbols 1` around it, `xschem descend` / `go_back`, `nolist_libs`
respected). For each instance whose symbol `type` has a registration, emit one
`save <vector>` per `params` entry, skipping `pinexpr` and `derived` (nothing to
save for those). Returns the block as text. **Always prepend `save all`** (rule
R2).

**`op_annot::text <instname>`** — look up the registration for the instance's
symbol type; read each `params` vector with `xschem raw value <v> -1`; compute
`pinexpr` from pin voltages and `derived` from the read values; format
`label = <engineering>` per line, blank (not `NaN`, not `0`) for anything
missing. Returns the block. This is `sg13g2_display_fet_params` with the
parameter list lifted out into data.

### 4.4 Getting the block onto the screen — two carriers

**Carrier 1: the annotator symbol.** A PDK-neutral
`xschem_library/devices/annotate_params.sym`, modelled exactly on IHP's:

```
K {type=annotator template="name=annot1 ref=M1"}
T {tcleval([op_annot::text @ref])} … {layer=15 font=Monospace hide=op}
T {@ref} … {layer=4}
```

Placed next to a device (menu item / key pre-fills `ref` from the selection).
**Needs no C change and no PDK symbol edit** — it is the phase-1 deliverable and
it works on every PDK the moment its descriptor is registered.

**Carrier 2: the draw-time overlay.** For every instance whose symbol type is
registered, and only while the annotation mask says so, `draw()` renders
`op_annot::text` next to the symbol bounding box. No symbol placed, no schematic
modified, nothing saved to the `.sch`. This is what makes `6` behave like
Cadence: press it and *every* transistor lights up.

Consequences of carrier 2 that the plan must handle:

* it must be replicated in `svgdraw.c` and `psprint.c` or exports lose the
  annotation (2 further sites);
* it **duplicates** what a PDK symbol already prints. sky130's `id=`/`gm=` texts
  have no `hide=true`, so they are always on. Removing the duplication is a
  one-time scripted edit per PDK (mark those texts `hide=op`), tracked as its own
  step, not a prerequisite;
* placement must be deterministic and collision-tolerant — anchor to the symbol
  bbox corner, with a per-instance `annot_dx`/`annot_dy` override attribute.

### 4.5 Visibility: annotation classes

Replace the single boolean with a mask.

* Text attribute gains classes: `hide=op`, `hide=voltage`, alongside the existing
  `hide=true` / `hide=instance`. New flag bits next to `HIDE_TEXT`
  (`xschem.h:387`), set in `set_text_flags()` (`actions.c:1121`).
* New `xctx->annot_show` bitmask (`bit0 = device OP info`, `bit1 = node
  voltages`), mirrored in Tcl as `annot_show`, per the `MIRRORED IN TCL`
  convention.
* The nine copy-pasted visibility tests collapse into one helper
  `text_hidden(flags)`. **That refactor is the substance of the change**; the
  class logic is a few lines inside it.
* `hide=true` keeps its exact present meaning under `show_hidden_texts`. Nothing
  existing changes behaviour.

### 4.6 The keys

In `src/cadence_style_rc` (and the per-PDK copies), following the `Ctrl-4`
precedent in that file:

```tcl
bind .drw <Control-Key-6> {cadence::annot_mode none;   break}
bind .drw <Key-6>         {cadence::annot_mode op;     break}
bind .drw <Alt-Key-6>     {cadence::annot_mode opvolt; break}
```

Verified free / safely overridable in this tree:

* plain `6` reaches `callback.c:7272` and is a **no-op** unless Control is held;
* `Ctrl-6` is "select drawing layer 6" — overridden with a trailing `break`,
  exactly as `Ctrl-4` already overrides "select layer 4" for
  `ase::direct_plot_for_current`;
* `Alt-6` (keysym 54) appears in **no** row of `src/keybindings.csv`; the only
  alt+digit row is `key,50,alt,canvas,view.toggle_view_type` (Alt-2);
* no Shift is involved, so the shifted-keysym trap documented in that file for
  `Ctrl-Shift-2` / `Ctrl-Shift-4` does not apply.

`cadence::annot_mode <mode>` must:

1. set `annot_show` (`none` → 0, `op` → 1, `opvolt` → 3);
2. if no raw is loaded and the mode is not `none`, load one for the current cell —
   `ase::last_rawfile` / `ase::session_for_current` when an ASE session exists,
   else `$netlist_dir/<cell>.raw` — via `xschem annotate_op`;
3. `xschem update_all_sym_bboxes; xschem redraw` (the pair the existing
   "Show hidden texts" checkbutton uses; bboxes change when texts appear);
4. **say what happened on the status line.** A key that finds no raw file must
   report that, not fail silently. Same for "no descriptor registered for this
   PDK" — that is the single most likely first-run confusion.

---

## 5. Contracts and invariants

| id | invariant |
|---|---|
| **I1** | Save cards and display share one name builder, `op_annot::devpath`. The save card is bare `devpath+[param]`; the display name is `op_annot::vector`, i.e. `devpath` plus the descriptor's `kind` wrapper. Never two independent builders. *(Restated by S1 — R4; the original wording named `vector` on both sides and is measurably impossible.)* **⚠ AMENDED BY S3 — "one builder" was under-specified and it reverted a complete implementation. One builder, but it must take a BASIS.** `devpath`'s hierarchy prefix comes from `sim_sch_path`, which is **relative to the level where the raw was loaded** — the right basis for *reading* a vector out of a loaded raw, and the wrong one for *writing* a save card, which needs a **deck-absolute** name. They coincide only when no raw is loaded or the raw is at the top, which is why 85 green checks missed it. The fix is a basis argument on the one builder (`op_annot::devpath <inst> ?basis?`, `absolute` for save cards), **not** path arithmetic in the walk — that would be the second builder this invariant forbids, and is exactly what the prototypes' `startpath` was. Issue **0436**, mechanism confirmed in the C at `save.c:1260`, `draw.c:2831-2838`, `scheduler.c:5150`. |
| **I2** | A generated save block always carries **`.save all`** — the DOT-card (rule R2; the bare `save all` writes no raw at all — see R2). Honoured as *"any **non-empty** block carries `.save all` as its first line"*: an empty walk returns `{}`, because a file whose entire content is `.save all` says nothing while reporting success. **⚠ This is in direct tension with S2's acceptance criterion and S3 must resolve it, not inherit it.** The prototypes (`sg13g2_save_params`, `sky130_save_fet_params`) emit a comment plus bare `.save` cards and **no `save all`** — so a block that reproduces them byte for byte violates I2, and a block that satisfies I2 is by construction *not* byte-equal to them. S2's byte-diff was the right acceptance for a **name builder**; it is the wrong acceptance for a **block emitter**. S3 asserts I2 on the block and keeps the byte-diff on the card names only. |
| **I2b** | **A generated save block names only devices that are in the netlist.** Added by S3. An instance carrying `spice_ignore=true` is absent from `xschem netlist` but is still visited by a hierarchy walk, and per **R5** one card for a non-existent device suppresses the entire raw under the bench idiom. So *one* such device anywhere in a design is enough to make a generated `.save` file kill the simulation it was generated for. Issue **0437**. **⚠ THE FILTER IS SEVEN CLASSES, NOT ONE — AND GETTING THREE OF THEM REFUTED S3b.** Measured (issue **0442**): `spice_ignore` (true/`open`/`short`, instance **or** symbol), `only_toplevel` below the walk entry, `lvs_ignore` gated on `::lvs_ignore` — *and four symbol-level classes S3b missed entirely*: empty/absent `format` (`spice_netlist.c:639`, the instance vanishes from the deck completely), `default_schematic=ignore` (`:643`), `spice_sym_def` (`:665`, body replaced by attribute text), `spice_stop=true` (`:635`+`:695`, `.subckt` emitted **empty**). The last two drop the **subtree** while the instance call survives — so "may I emit a card for this?" and "may I descend into this?" genuinely diverge and cannot be aliases. **Any implementation of this invariant must be acceptance-tested against `xschem netlist` on a HIERARCHICAL fixture carrying all seven**; S3b's cross-check row was correct but its fixture was flat, which is exactly why 96 green checks and 8 sabotage variants missed the gap. Strongly consider deriving the device set from `xschem netlist` output, or exposing `skip_instance()` (netlist.c:1245) to Tcl, rather than re-implementing the netlister's filter in Tcl a class at a time — that reimplementation has now drifted twice, and `skip_instance()` also branches on `xctx->netlist_type`, which no Tcl copy has ever consulted. |
| **I3** | A missing vector renders **blank**, never `0`, never a fabricated number. Same discipline as the digital-database refusal in `save.c` (RULING D5-1): a plausible wrong number on a schematic is worse than no number. |
| **I4** | The overlay never modifies the schematic. No instances placed, no `set_modify`, nothing written to the `.sch`. |
| **I5** | A user's `op_annot::register` overrides the PDK's, and takes effect on redraw — no restart, no rebuild. **⚠ "their own rc" is measurably wrong for `~/.xschem/xschemrc`**: xschemrc is sourced at `xinit.c:3234-3292`, *before* `xschem.tcl` at `:3401`, so `op_annot::register` there dies with `invalid command name`. The override must go in a file sourced after startup — a `--script` rc such as the PDK workareas' `cadence_style_rc`, or the console. S1 corrected the claim rather than the ordering; making xschemrc work would mean defining the namespace before the rc pass, which is a C change nobody has needed yet. |
| **I6** | The hierarchy walk restores `no_draw`, `no_undo`, `keep_symbols` and the original `sch_path` on every exit path, including error paths. The IHP prototype's `go_back 2` pairing is the reference for the **descend/ascend shape only — ⚠ it does NOT satisfy this invariant.** Measured: `sky130_save_fet_params` on `sky130_tests/test_generators` raises `Symbol not found` and leaves `no_draw=1 keep_symbols=1` set, because the restore is on the normal path and there is no `catch`/`finally`. S3 must wrap the walk body in `catch`, restore unconditionally, then re-raise — and must force a raise in its test rather than asserting only on the happy path. Issue **0431**. **S3 addenda, all measured:** the unwind is bounded by the **entry** level, not by 0 (`src/xschem.tcl:3857`'s `while {[xschem get currsch]} …` would ascend past a caller that was already descended); the restore must also pop the `log_action -suppress` scope it pushed, since an unpopped one silences the user's action log for the rest of the session; and **`no_undo` cannot be restored to its entry value because `xschem get no_undo` does not exist** (setter only, `scheduler.c:11958`; returns `{}` whether the flag is 0 or 1). 0 is the only restorable value, so a caller who wraps the walk in its own `no_undo 1` scope has it **silently disarmed** — measured `{3 2 2}` before, `{3 2 3}` after. Issue **0432**. |
| **I7** | `hide=true` semantics are unchanged for every existing symbol in every library. |

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

---

## 7. Out of scope (named, so it is not accidentally assumed)

* Voltages on **unlabelled** nets. Today a voltage needs a label/pin/probe
  symbol on the net (D1). A per-net overlay is a separate feature.
* Xyce and Vacask device-parameter naming. The descriptor can express them, but
  no descriptor is written here and none is tested.
* Implementing the dead `@spice_get_modelparam_<p>(<dev>)` /
  `@spice_get_modelvoltage_<p>(<dev>)` token branch (`token.c:5023`). File it;
  this design does not need it.
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
* **Pixels**: the overlay is a look-at-it deliverable and no green suite can
  clear it. `tests/headless/owed.sh add look "op annotation on tb_bandgap"`.
