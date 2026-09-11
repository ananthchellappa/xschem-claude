# Design A — One table, seven places collapse

**Every ngspice analysis reachable from ASE-L, as a data-entry problem.**

Reader: the Claude Code session that will implement analyses in ASE-L.
Author's angle: minimum-risk incrementalism. Nothing here asks for a rewrite.
Status: design of record for the analysis axis. **No code was written into either repository.**

| | |
|---|---|
| ngspice | `/home/analog/dev/ngspice`, branch `ver_50`, `ngspice-46-419-gccebdf2a2`; binary `build-ver_50/src/ngspice` |
| xschem fork | `/home/analog/dev/xschem-claude`, branch `fluid-editing`, HEAD `4ddc4900` at write time, **working tree dirty and moving** |
| evidence base | the 20 dossiers in `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/dossiers/`, headed by `00-critique.md` |
| my own scratch | `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/scratch/` (`np1.cir`, `np2.cir`, `np3.cir`, `d_ase.cir`, `dv.cir`, `dv2.cir`) |

**Anchoring rule.** `ase_window.tcl` grew ~350 lines between the dossier pass and this one, and
another agent is landing the UX batch into it right now. Every anchor below is a **proc name**.
Line numbers appear only as hints and were re-derived against HEAD `4ddc4900`; re-grep before
quoting one to anybody (`grep -n '^proc ase::ui::chana_show' src/ase_window.tcl`).

**Citation convention.** `[F<n>]` are the facts established in the brief. `[crit §x]` is
`00-critique.md`. `[ase-deck §x]`, `[ase-state §x]`, `[ase-ui §x]`, `[ase-conv §x]` are those
dossiers. `[M<n>]` is a measurement **I took in this session** — the six decks above are on disk
and re-runnable.

---

**Contents.** 0 Thesis · 1 What I measured this pass · 2 The descriptor (S2) · 3 Decisions P1-P30 ·
4 The twelve entries filled in · 5 The type list (S1) · 6 The form (S3) · 7 The options surface (S4) ·
8 The deck (S5) · 9 Results routing (S6) · 10 Beyond ADE (S7) · 11 Worked example: NOISE end to end ·
12 What the descriptor cannot express · 13 Stages (S8) · 14 Rulings · 15 Refusals · 16 Risks ·
17 Acceptance.

---

## 0. Thesis

ASE-L does not lack analysis features. It lacks **one place to say what an analysis is.**

Everything a 12-analysis GUI needs already exists in this tree and is battle-tested: a dialog that
swaps a per-type form in place (`ase::ui::choose_analyses` + `chana_show`), a variable-length
list-of-open-dicts state schema whose forward-compat promise is "unknown keys preserved"
(`ase::state_load`), a per-analysis deck epilogue that is already type-blind (guard,
`remzerovec`, `write`), a capability probe with a `known 0`/`known 1` discipline and a cache
keyed on program+args (`ase::sim_capabilities`), a results reader that picks its plot **by name**
out of a multi-plot raw, a click-to-pick-from-the-schematic mode (`select_on_design`, which
already takes a `mode` argument), a config-driven table engine (`listdlg`), and a rich form
template (`simdlg_editor`) with a live combobox, a Detect button, an in-dialog status label and
the file's one working entry validator.

What is missing is that **the answer to "what is a `dc` analysis" is written down seven times**
[F2, ase-ui §2.10] — in the state seed, in `anaargs`, in `chana_fields`, in the radio-row
literal, in `chana_show`'s hardcoded destroy list, in `anorder` + the `switch`, and in
`plot_sim_type` — with a *third* and *fourth* independent ordering beside them (the print anchor
`{dc ac tran op}` and the op-last reorder). Seven copies of a four-element list is survivable.
Seven copies of a twelve-element list, each of which fails **silently** when it drifts, is not:
the `ac.dec` field is already a lie the pane tells [ase-state §3.1], the Options… dialog already
reports settings that are not in force [F3], and a state carrying `{type noise enabled 1}` today
runs, exits 0, writes a raw and produces nothing [F2].

So the whole plan is one move, made in a specific order:

> **Collapse the seven places into one declarative per-analysis descriptor; prove the collapse by
> re-expressing today's four types in it with byte-identical output; then adding the remaining
> eight analyses is data entry, and every new capability (typed fields, pickers, options that
> actually emit, multi-plot capture, results routing, capability gating) becomes one new *column*
> of that table rather than one new hardcoded list.**

The corollary that makes this an *incrementalist* plan rather than an architecture plan: the
first ship is not the table. It is a five-line `default` arm that turns the silent drop into a
refusal [crit §9.3 / ase-conventions §9.3]. One rebuild, zero rulings, and it is the thing that
makes every later stage safe to land, because from then on a table that has drifted **says so**.

The two places where I part company with the obvious reading of the brief are stated up front:

* **The type list is a table, gated by the probe — not derived from the probe.** Nine of the
  twelve analyses are unconditionally compiled into every ngspice (`commands.c:312-362`,
  no `#ifdef`) [ase-deck §6.4]. Probing for them buys nothing and costs the user's Run gesture
  (issues 0953/0958/0959). Only `sp`, `pss` and CIDER are build-gated, and only they need the
  probe. See P4.
* **The descriptor's emit is a named proc, not a template string.** A template language that can
  express `tran`'s gap-filling `tstart`, `dc`'s all-or-nothing second triple, `sens`'s
  mode-dependent tail and `tf`'s compound output is a second place for bugs to hide. See P7 and
  §12/L3.

---

## 1. What I measured myself this pass

Four things, because the deck design turns on them and no dossier had settled them. Decks are on
disk in `workpad/scratch/`.

**[M1] `setplot previous` is a deterministic one-step walk back through creation order.**
`src/frontend/vectors.c:1392-1421` (`plot_setcur`): `previous` is literally
`plot_cur = plot_cur->pl_next`, and the plot list is newest-first. At the tail it prints
`Warning: No previous plot is available. Plot remains unchanged (const).` on stderr, leaves the
current plot alone, and the run continues at **rc 0**. There is no wrap-around and no error.

**[M2] Per-analysis capture of a multi-plot analysis works, with no counters and no string
comparison.** `np1.cir`: `noise v(mid) v1 dec 5 1k 100k` then `write` / `setplot previous` /
`remzerovec` / `write` put **both** `Noise Spectral Density Curves` and `Integrated Noise` into
one appended rawfile. `dv2.cir` did the same for `DISTORTION - 3rd harmonic` +
`DISTORTION - 2nd harmonic`. This closes `ase-deck §7.4`'s landmine and `§9`'s open question
without adopting the trailing `foreach $plots` recipe of [F6] — which would be correct but would
move every committed deck golden. See P12.

**[M3] A plot count is a predicate over the row, not a constant of the analysis.**
`np3.cir`: `noise v(mid) v1 lin 1 1k 1k` produces **one** plot (`plots = const noise1`), because
`Integrated Noise` is only opened when `NstartFreq != NstopFreq` (`noisean.c:511`); and
`option keepopinfo` (settable from inside `.control`, measured) prepends a
`NOISE Operating Point` plot, so the same `noise` row becomes **three** plots and the walk-back
is `Integrated Noise` → `Noise Spectral Density Curves` → `NOISE Operating Point`. `np2.cir`:
`disto` in IM mode (`f2overf1` given) produces **three** plots, not the two of harmonic mode.
A static `plots` list in the descriptor would silently re-write a previous analysis's plot.

**[M4] The `.disto` SIGSEGV [F7] is reachable through ASE-L's own deck shape, and `.save all`
prevents it.** Measured on the `.control`-command shape ASE-L actually emits:

| deck | rc |
|---|---|
| `.save v(c)` (resolves) + `op` + `disto` | 0 |
| **`.save v(nosuchnode)` (stale) + `op` + `disto`** | **139, SIGSEGV** |
| no `.save` at all + `op` + `disto` | 0 |
| `.save all` **and** `.save v(nosuchnode)` + `op` + `disto` | 0 |

So the rule is not "never emit a narrowed save with disto" — it is sharper and cheaper:
**a run containing `disto` must contain at least one save that resolves in the distortion plot,
and `.save all` is the construction that guarantees it.** (In the stale case ngspice also aborted
the `op`, which ASE-L's per-analysis guard would have caught first — but a bench whose only
outputs are device `@`-parameters resolves for `op` and starves `disto`, and that reaches the
crash with the guard green.)

---

## 2. The descriptor

### 2.1 Where it lives

`src/ase.tcl`, beside the backend registry, **Tk-free** (`ase.tcl:5-10` forbids Tk there, and
`--nogui` must drive every proc) [ase-state §9.1 constraint 5]. It is declared *by the backend*,
not by the core: spec decision D3 says "state schema + deck generation behind a per-simulator
table", and `ase::register_backend` already takes optional hooks beyond its five required ones
(`render_deck run_cmd log_file result_probe raw_file`) [decision K]. So the vocabulary of
analyses is a property of the simulator, exactly as the spec architecture says it should be, and
a future Xyce/Spectre backend brings its own without ASE-L hardcoding anyone's.

```tcl
# --- src/ase.tcl, in the backend section ------------------------------------
# ONE declarative description per analysis type. Read by BOTH files:
#   ase.tcl        — emit order, deck lines, plot capture, precheck, raw sim_type
#   ase_window.tcl — the radio row, the form, the Arguments column, validation
# Adding an analysis is ONE entry here plus ONE emit proc. Nothing else.
namespace eval ase::backend::ngspice {
    variable antypes [dict create]      ;# type -> spec dict
}

proc ase::backend::ngspice::an_declare {type spec} {
    variable antypes
    dict set antypes $type $spec
}

proc ase::backend::ngspice::analysis_types {} {      ;# the optional backend hook
    variable antypes
    return $antypes
}
```

registered alongside the existing five:

```tcl
ase::register_backend ngspice [dict create \
    render_deck   ase::backend::ngspice::render_deck \
    run_cmd       ase::backend::ngspice::run_cmd \
    log_file      ase::backend::ngspice::log_file \
    result_probe  ase::backend::ngspice::result_probe \
    raw_file      ase::backend::ngspice::raw_file \
    capabilities  ase::backend::ngspice::capabilities \
    analysis_types ase::backend::ngspice::analysis_types ]
```

### 2.2 The shape, key by key

```tcl
#   key        the state row's `type` value, the deck verb, and the widget-path leaf.
#              MUST be a bare lowercase word: it becomes $w.types.<key> and the
#              headless suites address widgets by path.
#   label      the radio text and the pane's display word. A USER-FACING STRING:
#              minted once in ase::ui::lbl_* and ratified (house rule).
#   order      emit position, ascending. op=0 dc=10 ac=20 tran=30 -> today's
#              {op dc ac tran} falls out unchanged. New types take 40+.
#   anchor     print-anchor priority (decision B). dc=10 ac=20 tran=30 op=40;
#              0 = NEVER the anchor. Only op/dc/ac/tran are non-zero, ever:
#              a spectrum has no scalar and must not move the Value column.
#   gate       {} = unconditionally compiled into ngspice, offer always.
#              Otherwise the capability key that must read 1 (P4).
#   verbhelp   the word `help <verb>` answers to, for the probe leg.
#   fields     ORDERED list of field descriptors — see 2.3. One list, three roles.
#   emit       (proc) {row opts} -> list of deck lines for this analysis, WITHOUT
#              the shared epilogue. The only place deck syntax is written.
#   plots      (proc) {row opts} -> list of {plotname simtype} pairs, NEWEST FIRST,
#              i.e. capture order. Length drives the setplot-previous walk [M2,M3].
#   precheck   (proc) {state row map opts} -> list of refusal sentences ({} = ok).
#              Netlist facts, run at preflight, not at OK (see §12/L4).
#   results    where each answer goes (§7). {waveform ...} {scalars ...} {table ...}
#   options    the per-analysis option names this type may carry (§6), by catalogue
#              key. Anything not listed is refused by the option editor.
#   multirow   1 if several rows of this type are meaningful (dc, ac, tran, noise);
#              0 for op. Consumed by the `id` work in stage 7, ignored before it.
#   notes      short strings shown as field/dialog hints; each one is a ruling.
```

### 2.3 A field descriptor

```tcl
#   label      user-facing, ruling-bearing. "Points per decade", never "Points".
#   kind       node | nodepair | source | vsource | device | param | enum | flag
#              | real | int | freq | time | volt | amp | text | compound
#              -> chooses the widget AND the validator AND the unit parser.
#   unit       Hz | s | V | A | {}  — appended to the label, parsed on input.
#   role       any of {form summary emit}. A field can be summary-only: that is
#              exactly what `ac.dec` is today, and writing it down that way is
#              how the existing drift becomes visible instead of mysterious.
#   required   1 = must be non-empty when the row is ENABLED (today's D6 rule).
#   default    value used when the key is absent; {} = no key, omit from emit.
#   min/max/min_exclusive/max_exclusive  numeric bounds, refused at OK.
#   values     enum members, in menu order.
#   relabel    {targetfield {enumvalue newlabel ...}} — the ADE sweep-type
#              behaviour. dialog_row names the label $w.l<name>, so the relabel
#              is one `configure -text`.
#   pick       select_on_design flavour to fill this field from a schematic click
#              ({} = typed only).
#   depends    {field value ...} — grid the row only when another field matches.
#   deprecated a sentence. The field is rendered greyed with the sentence as its
#              tip and is NEVER emitted. `ac.dec` starts life here.
```

### 2.4 One complete entry — NOISE

The hard case, chosen because it exercises every column: two pickers, a sweep-type selector that
relabels its neighbour, an optional trailing argument, a **conditional** plot count [M3], a
scalar result that must not go in the Value column, a precondition that lives in the netlist and
not in the row, and a global `set` variable (`sqrnoise`) that changes the *units of the answer*.

```tcl
ase::backend::ngspice::an_declare noise {
  label     {Noise}
  order     40
  anchor    0
  gate      {}
  verbhelp  noise
  multirow  1
  fields {
    output {
      label {Output node} kind node unit {} role {form summary emit} required 1
      pick  {node} }
    outref {
      label {Output reference} kind node unit {} role {form summary emit} required 0
      default {} pick {node}
      notes {noise-outref} }                  ;# "blank = ground"
    source {
      label {Input source} kind vsource unit {} role {form summary emit} required 1
      pick  {source}
      notes {noise-input-ac} }                ;# "must carry an AC value"
    sweep {
      label {Sweep type} kind enum values {dec oct lin} default dec
      role {form summary emit} required 1
      relabel {points {dec {Points per decade}
                       oct {Points per octave}
                       lin {Number of points}}} }
    points {
      label {Points per decade} kind int min 1 role {form summary emit} required 1 }
    start {
      label {Start frequency} kind freq unit Hz min_exclusive 0
      role {form summary emit} required 1 }
    stop {
      label {Stop frequency} kind freq unit Hz min_exclusive 0
      role {form summary emit} required 1 }
    ptssum {
      label {Points per summary} kind int min 0 default {}
      role {form summary emit} required 0
      notes {noise-ptssum} }                  ;# "1 = per-device breakdown, no decimation"
  }
  emit      ase::backend::ngspice::an_emit_noise
  plots     ase::backend::ngspice::an_plots_noise
  precheck  ase::backend::ngspice::an_pre_noise
  results {
    waveform {{Noise Spectral Density Curves} noise}
    scalars  {onoise_total inoise_total}
    table    {per-generator {onoise_* inoise_* onoise.* inoise.*}}
  }
  options   {keepopinfo sqrnoise noisyxspice enable_noisy_r}
  notes     {noise-vs-trnoise}
}
```

and its three procs — the only hand-written code an analysis needs:

```tcl
# noise v(OUT[,REF]) SRC {dec|oct|lin} PTS FSTART FSTOP [PTSPERSUM]
#   inp2dot.c:18-121 (dot_noise) / nsetparm.c:82-93.  The first token must be a
#   bare `v`; ptspersum is present only if a non-blank token remains (:98-110).
proc ase::backend::ngspice::an_emit_noise {row opts} {
    set out [ase::state_get $row output]
    set ref [ase::state_get $row outref]
    set probe [expr {$ref eq {} ? "v($out)" : "v($out,$ref)"}]
    set line "noise $probe [ase::state_get $row source]\
 [ase::state_get $row sweep dec] [ase::state_get $row points]\
 [ase::state_get $row start] [ase::state_get $row stop]"
    set pps [ase::state_get $row ptssum]
    if {$pps ne {}} { append line " $pps" }
    return [list $line]
}

# NEWEST FIRST — this list IS the setplot-previous walk [M1,M2].
# Its LENGTH is a predicate, not a constant [M3]:
#   * `Integrated Noise` exists only when fstart != fstop   (noisean.c:511)
#   * `keepopinfo` prepends `NOISE Operating Point`         (noisean.c:225-229)
proc ase::backend::ngspice::an_plots_noise {row opts} {
    set sq [ase::opt_on $opts sqrnoise]
    set dens [expr {$sq ? {Noise Spectral Density Curves - (V^2 or A^2)/Hz}
                        : {Noise Spectral Density Curves}}]
    set intg [expr {$sq ? {Integrated Noise - V^2 or A^2} : {Integrated Noise}}]
    set pl {}
    if {![ase::num_eq [ase::state_get $row start] [ase::state_get $row stop]]} {
        lappend pl [list $intg noise]
    }
    lappend pl [list $dens noise]
    if {[ase::opt_on $opts keepopinfo]} {
        lappend pl [list {NOISE Operating Point} op]
    }
    return $pl
}

# Netlist facts. Returns SENTENCES, not booleans — they are shown verbatim.
proc ase::backend::ngspice::an_pre_noise {state row map opts} {
    set bad {}
    set src [ase::state_get $row source]
    if {![ase::netlist_map_resolve $map instance $src [ase::sim_casemode_now]]} {
        lappend bad [ase::ui::lbl_an_no_such_source noise $src]
    } elseif {![ase::netlist_src_has_ac $map $src]} {
        lappend bad [ase::ui::lbl_an_source_no_ac noise $src]   ;# E_NOACINPUT
    }
    if {[ase::opt_value $opts solver] eq {klu}} {
        lappend bad [ase::ui::lbl_an_klu_refused noise]         ;# noisean.c:73-78
    }
    return $bad
}
```

Three things to notice about that entry, because they are the whole argument of this document:

1. **No widget appears in it.** The radio row, the form, the labels, the validation and the
   Arguments column are all *derived*. `ase_window.tcl` reads `fields` and never learns the word
   "noise".
2. **No deck syntax appears in the data.** It is in one proc, 9 lines, next to its `inp2dot.c`
   citation, and it is unit-testable headlessly with no simulator.
3. **The parts that could not be data are visibly not data** — `plots` and `precheck` are procs
   because the honest answer is conditional (§12).

### 2.5 The accessors both files call

```tcl
proc ase::an_spec   {sim type}        ;# the dict, or {} for an unknown type
proc ase::an_known  {sim type}        ;# 0/1 — the loud-default predicate (P1)
proc ase::an_types  {sim}             ;# every declared type, ascending `order`
proc ase::an_fields {sim type role}   ;# ordered field NAMES carrying that role
proc ase::an_field  {sim type f}      ;# one field descriptor
proc ase::an_label  {sim type}
proc ase::an_emit   {sim type row opts}
proc ase::an_plots  {sim type row opts}
proc ase::an_pre    {sim state row map opts}
proc ase::an_simtype {sim type row opts}   ;# the FIRST plot's raw sim_type word
proc ase::an_all_field_names {sim}    ;# union over every type — kills the destroy list
```

`ase::an_*` resolve the backend hook and degrade cleanly: a backend that declares no
`analysis_types` hook answers `{}` for `an_types`, and `an_known` is 0 for everything, so the
loud default of P1 fires rather than a silent drop. That is the whole compatibility story for a
second backend.

### 2.6 The seven places, collapsed

| # | today | after | risk |
|---|---|---|---|
| 1 | `ase::state_default`'s four-row `analyses` seed (`ase.tcl:502`) | **unchanged**, deliberately — a seed is a decision, not a derivation [ase-state §6.4]. It gains a load-time *check* against the table (P2). | none |
| 2 | `variable anaargs` (`ase_window.tcl:83`) | `[ase::an_fields $sim $type summary]` | `ac`'s `dec` must stay in the summary list, `deprecated`, or the Arguments column changes (it changes for no committed state — none carries `dec` [ase-state §4]) |
| 3 | `ase::ui::chana_fields` | `[ase::an_fields $sim $type form]` | must return `{}` for `op` and for an unknown type, as today |
| 4 | `foreach t {op dc ac tran}` in `choose_analyses` | `[ase::ui::chana_offered $key]` (§4.1) | `test_ase_dialogs.tcl` drives `$top.chana.types.tran` **by path** — the four paths must still exist. Adding siblings is safe; renaming is not. |
| 5 | `foreach f {source start stop step points}` — the hardcoded destroy list in `chana_show` | `foreach f [ase::an_all_field_names $sim]` | **this is the collapse that pays for the whole exercise.** [ase-ui §2.5] calls the drift "the single sharpest trap in the analysis code"; a union over the table cannot drift. |
| 6 | `set anorder {op dc ac tran}` + the four-arm `switch` + the `{dc ac tran op}` reorder | sort by `order`, dispatch to `emit`, keep the op-last reorder as an explicit named rule (P11) | the reorder's reason is measured and specific to `op` [decision A, issue 0964]; it does **not** generalise and must stay a special case |
| 7 | `ase::plot_sim_type`'s `foreach type {op dc ac tran}` | max `anchor`… **no** — a separate field, `simtype`, off the first plot (P16) | `plot_sim_type` and the print anchor are *different* orderings for *different* reasons [ase-state §7.1]; keeping them separate is required, not optional |
| +1 | the print anchor `foreach type {dc ac tran op}` | highest `anchor` among enabled rows, ties to the last row in state order | reproduces today exactly with `dc=10 ac=20 tran=30 op=40`; **every new type is `anchor 0`** so the Value column can never move by accident |

---

## 3. Decisions

Each is numbered, has one reason, and names the evidence. They are the contract; §4–§9 are the
mechanism. Where a decision needs the user, it says so and points at the ruling in §13.

### The spine

**P1. The emit loop gets a loud `default` arm before anything else changes, and it refuses the
run.** Reason: today an analysis type the renderer does not know is counted, warned about,
displayed as enabled, and then never emitted — rc 0, a raw is written, nothing happened
[F2, ase-state §7.3]. This is the worst failure mode in the area, it needs no ruling, no new
string beyond one sentence, and it makes every later stage safe: from then on a drifted table
*says so*. It ships alone. [crit §9.3]

**P2. `ase::state_load` gains an idempotent, `catch`ed check that every `analyses` row's `type` is
declared, and reports the ones that are not.** Reason: the only migration this tree has ever done
in the loader is exactly this shape (`expand_bus_outputs`, issue 0159), and its comment says why
it is `catch`ed — "opening a session must never FAIL because a cosmetic migration tripped over an
odd stored row" [ase-state §5.2]. It reports; it never deletes a row and never rewrites the file.

**P3. The descriptor table is the vocabulary. `version` stays 1, `schema_keys` does not change,
and no new top-level state key is added.** Reason: 105 committed `.state` files round-trip
byte-identically and five test rows (F3/G3/R4/V4/R2) assert it; `omit_if_empty` exists solely to
protect that [F13, ase-conv §6]. New per-analysis data goes *inside* the row, where the merge
already preserves it — the precedent is `viewer`'s nested growth, whose own comment ends "No
version bump" [ase-state §5.4].

### The type list (S1)

**P4. Offered = declared, minus what the build is known to lack. The probe gates only the three
build-gated features; it is never in front of the dialog.** Reason: `op tf tran ac dc pz sens
disto noise` are unconditional in `commands.c:312-362`; only `sp` (RFSPICE), `pss` (WITH_PSS) and
CIDER's devices are `#ifdef`-ed [ase-deck §6.4]. Probing for the nine buys nothing and would
inherit issues 0953 (the probe is paid inside the user's Run gesture), 0958 (on every press) and
0959 (the bound evaporates without `timeout(1)`) [ase-conv §9.1]. So: a `gate` of `{}` means
"offer always"; a non-empty `gate` names a capability key, and the row is offered **only** on a
`known 1` measurement — never on `known 0`, because a missing key means "not measured", never
"no" [decision J].

**P5. The capability probe gains exactly one new leg, in one deck, publishing two new keys.**
`help all > probe_d.txt` + `devhelp > probe_e.txt` in a single `cap_run`, parsed `^(\S+)\s` into
`analyses_available` and `devices_available`, with derived `has_sp` / `has_pss` / `has_cider`
[ase-deck §6.4, its seven rules]. Reason: it is additive, file-based (never log-based, never
exit-code-based — the probe's own doctrine), and costs about one `op`. **Caveat carried in the
code:** `help all` truncates at the first NULL `co_func` and is wrong as a general command
inventory [crit §3.2] — it is used here *only* for analysis verbs, which all sit before that
block, and the comment must say so or someone will reuse it.

**P6. Three refusal classes are distinguished, and they read differently.**
(a) *Not in this build* — `pss` with `known 1` and the key absent: the radio is present and
disabled, with the reason as its tooltip. Never hidden: a hidden control is indistinguishable
from a GUI that never heard of the feature.
(b) *Dangerous in this build* — `disto` with a narrowing save [M4], `sens` in AC mode under
`option klu` [F8/D3]: offered, and refused **at preflight** with the exact remedy.
(c) *Needs the netlist to be different* — `sp` without two ports, `ac`/`noise` without an AC
source, `sens` without eligible parameters: offered, and refused at preflight naming the missing
thing. Reason: (a) is about the program, (b) about the deck we would generate, (c) about the
user's circuit; a GUI that renders all three the same way teaches the user nothing.

### The form (S3)

**P7. The form is derived from `fields`; the deck line is written by `emit`.** Reason: a template
mini-language would have to express `tran`'s "tmax without tstart substitutes tstart 0, not shift
a slot", `dc`'s all-or-nothing second triple, `sens`'s `ac …|dc` tail, `tf`'s `v(a,b)` vs
`i(vsrc)` compound and `pz`'s two bare enum words. That is a language, and a language is a second
place for bugs [§12/L3]. Nine lines of Tcl per analysis, next to its `inp2dot.c` citation, is
cheaper and testable without a simulator.

**P8. Field widgets keep their existing paths `$w.<field>`; `Options…`, the status line and the
button bar move to computed rows with today's values as the floor.** Reason: `test_ase_dialogs`
G1/G2/GE4/GE5 drive `$top.chana.types.tran` and `$top.chana.step` **by path** [ase-ui §5.4], and
"adding a widget path is additive and safe; moving one reds". Computed rows
`status = max(7, nfields+2)`, `opts = status+1`, `buttons = status+2` reproduce today's 7/8/9
exactly for ≤4 fields and stop the collision that a 7-field type would otherwise cause
[ase-ui §5.3].

**P9. Refusals appear on the form, at a fixed row, and *also* go to the CIW.** `ase::ui::dialog_status`
generalised from `rsel_status` — which keeps its sentence in `dlg($key,…)` whether or not a widget
exists, so it stays assertable headlessly [ase-ui §3.6]. Reason: today `chana_ok`'s refusal goes
to a different window and the dialog just sits there [F3, FINDINGS `refusals-appear-in-a-different-window`].
The `ase::echo` line stays, because headless callers and the action log read it.

**P10. Pick-from-the-design is a fourth `select_on_design` mode, not a new mechanism.** The proc
already takes `mode` (`outputs` | `plot`); a `field` mode fills a named dialog entry from a
canvas click, reusing hierarchy qualification (`sod_qualify`) and the bus-bit dialog. Reason:
this is the cheapest genuine ADE-beater in the list — ADE-L makes you type the sweep source name
too [ase-ui §6 row 13] — and the click pipeline is already built and case-mode aware.

### The deck (S5)

**P11. Analyses stay `.control` commands, one at a time, and `op` stays last in the reorder.**
Reason: the command route avoids the `analInfo[]` re-ordering (a bare `run` dispatches every card
in registry order, not deck order [crit §5.5]), the `-r` death [I7], the two-`.sens`-cards
SIGABRT [D5], the `.op`-scopes-the-save-list starvation that reaches the DISTO crash [D1/M4] and
the batch double-run. The op-last rule is kept as a named special case because its reason —
ngspice's save list is sticky forward-only, measured at 74.9 MB — is about `op` and does not
generalise [decision A, issue 0964].

**P12. Multi-plot analyses capture with `write` / `setplot previous` / `remzerovec` / `write`,
driven by the descriptor's `plots` length.** Reason: measured end to end on `noise` and `disto`
[M1, M2]; it needs no plot counter, no string comparison in the deck (which silently takes the
false branch [crit §5.2]), and — decisively for this plan — it leaves the single-plot emission
**byte-identical**, so the committed deck goldens D1/E12 stay green while `noise` arrives.
The `foreach p $plots` recipe of [F6] is correct and is the fallback if `setplot previous` ever
changes; it is not adopted now because it would move every golden and would lose partial results
when a guard `quit 1`s.

**P13. `remzerovec` is emitted before **every** write, including the extra ones after a
`setplot previous`.** Reason: it is per-plot ("one call at the end would only ever have cleaned
the last analysis's") [decision E]; the setplot walk creates exactly the same hazard one plot
further back.

**P14. When `disto` is enabled the deck emits `.save all`.** Reason: [M4] — a narrowing save that
does not resolve in the distortion plot is a SIGSEGV at rc 139 with one stderr line, and `.save
all` alongside the narrow save is measured safe. This is one line in `render_deck` and it is the
difference between "the GUI crashed the simulator" and "it worked". It also composes with the
existing G-LEADER rule, which already says the `.save all` leader stays at deck level [I1].

**P15. Every save expression is resolved against the netlist map before the deck is written.**
`ase::netlist_map_resolve` exists and is currently unused for this [ase-state §3.4]; it is the
second line of defence behind P14 and the first line for `.disto`'s cousin failure — a stale
Outputs row after a schematic edit.

**P16. `plot_sim_type` reads the descriptor's first plot, and the word it returns is a
per-*plot* fact.** Reason: `src/save.c`'s `read_dataset` maps `Plotname:` to `sim_type` with
explicit arms for tran/dc/noise/op/ac and a **catch-all that uses the raw `Plotname:` literal,
compared with `strcmp`** (`save.c:994-1004`, re-read this session). So `noise` attaches both of
its plots with one `raw read … noise` (the `integrated noise` arm sets `noise` too), `sp` attaches
as **`ac`** (`sp analysis` is in the ac arm), and `pz` needs the literal string
`Pole-Zero Analysis`, capitals, hyphen and space included. A per-analysis `simtype` word would be
wrong for `disto`, whose two plots carry two different literals (§12/L8).

### The options surface (S4)

**P17. The Options… dialog stops storing anything it cannot emit.** Reason: it is a correctness
defect, not a feature gap — the window reports simulation settings that are not in force
[F3, measured: typed `uic 1 tstart 5u tmax 1n`, pane rendered them, deck said `tran 10n 200u`].
Until the catalogue exists, the honest interim is to refuse the key at OK with a sentence. Never
"store and hope".

**P18. There is one option catalogue with a `route` column, covering both catalogues of options.**
Every entry carries `{name cptype route category default inert_when analyses help}` where
`route ∈ {deck control set argv spiceinit}`. Reason: there are genuinely two disjoint
surfaces — `OPTtbl`'s ~86 keywords and 163 `cp_getvar` variables [F15] — but from the GUI's side
the only question that matters is *where do I write it*, and that is one column. It also encodes
the traps: `oldlimit` is `route deck` only because `TSKfixLimit` is never copied on the `.control`
route [F8/D6]; `numdgt`/`rawfileprec`/`measureprec` are `route set`; `casemode`/`ngbehavior`/
`soacheck`/`no_auto_gnd` are `route argv` or `spiceinit`.

**P19. A CP_BOOL is never emitted as `name=1`, a CP_NUM is never emitted as a bare `set`, and
`-D name=value` is only ever used for CP_STRING.** Reason: all four are silent no-ops, measured
[F15 §1.5]: `-D sqrnoise` works and `-D sqrnoise=1` is inert; `-D warn=1` is inert because `warn`
is read as CP_NUM. The `cptype` column plus one emitter proc (`ase::backend::ngspice::opt_emit`)
makes the wrong form unwritable.

**P20. An option that is inert in this build is not offered, and the catalogue says why.**
`itl1/itl2/itl4` are floored at 100 in `niiter.c:37-39`, so the shipped 50/10 are dead numbers
[F8/C1] — the spinner clamps to ≥100 and the hint says so. `ramptime` is an XSPICE code-model
knob behind a `#ifdef XSPICE_EXP` that is defined nowhere [C2] — not offered. `newtrunc` and the
`lte*` family need `PREDICTOR` — not offered. `defas`, `klu_memgrow_factor` — known broken, not
offered. `nosavecurrents` does not exist in this tree [crit §1.2] — not offered, and the
catalogue carries a tombstone so nobody re-adds it from the manual.

**P21. Per-analysis options are emitted immediately before their analysis and restored
immediately after, from the catalogue's `default` column; an option with no known default is
global-only.** Reason: **ngspice has no per-analysis option scope.** `option keepopinfo` inside
`.control` sets the task option and it stays set for every later analysis (measured this session
in `np3.cir`). Offering a per-analysis option without a restore would make analysis 4 silently
inherit analysis 3's settings. Where no restore is possible the GUI must say the option is global
— that is honest, and it is more than ADE-L tells you.

**P22. Convergence is a guided remedy, not a field wall, and `optran` is its fourth rung.**
One model of the four rungs, emitting **either** `.options noopiter/gminsteps/srcsteps` **or**
one `optran <opiter> <gmin> <src> <step> <stop> 0` line, never both — because `optran`'s first
three arguments override those options on the same task [convergence §7.7]. `optran` is **on by
default** in this tree with `1 1 1 100n 10u 0` injected by `cp_init`, and it silently sets the
accuracy of every fallback operating point (0.9999550 instead of 1.0 on a 1 µs RC) [F11]. The
panel is the first time any user has seen this knob.

### Results (S6)

**P23. Three destinations, and each analysis names one per answer.** Waveform viewer for anything
with a sweep; the **Results Display Window** for per-analysis scalars, root lists, S-matrices and
sensitivity tables; the Outputs pane's Value column for per-*output* scalars only, unchanged.
Reason: decisions B and C — the Value column is a scalar column and `result_probe` accepts
`<expr> = <number>` and nothing else; inventing a scalar for a spectrum is the defect 0967 was
filed about [F13].

**P24. Per-analysis scalars (`onoise_total`, the TF triple, PZ roots, `.four`'s THD) do not go in
the Outputs pane.** They are properties of the *analysis*, not of an output row, and the pane has
no column that means that. Reason: adding a column to the Analyses pane reds `W1p`, which asserts
the three column lists verbatim [ase-ui §5.4]; and the RDW already exists and is under active
work. Interim before the RDW section lands: the run log carries them and the log window shows it.

**P25. A plot is labelled to the user by its literal `Plotname:` string, from the descriptor.**
Reason: three name spaces exist for every analysis — registry name (`NOISE`), plot name
(`Noise Spectral Density Curves`), typename (`noise2`) — and only the plot name is stable and
user-meaningful [outputs §3.2]. `$curplotname` after `setplot` yields it at run time if the GUI
ever needs to confirm [F6].

### Beyond ADE (S7)

**P26. Sweeps, corners and Monte Carlo are a generated `.control` layer driven by
`.param x = "var(name)"` + a written `.spiceinit`, and they are a dialog, not a fourth pane.**
Reason: ngspice has no `.step` and no corner construct; `.dc` nests exactly two levels and sweeps
only R / V / I / `temp` [F10]. `var(name)` is read at netlist-read time as CP_REAL and is
therefore reachable **only** from `spinit`/`.spiceinit` — not `-D`, not `.options`, not
`.control` [F15 §3.2]. And `W1p` asserts exactly three panes, so a fourth pane is a suite move
for no functional gain.

**P27. ⚠ A generated `.spiceinit` collides with the simulator registry's "no .spiceinit"
checkbox.** The simulator entry can carry `--no-spiceinit` (`dlg($key,simns)` in `simdlg_editor`),
and a `.spiceinit` written into the run directory is then ignored — silently. Any feature that
depends on P26's delivery route must detect that combination and refuse with a sentence naming
the checkbox. This is a new finding of this design pass; nothing in the tree knows about it.

**P28. Five of [F14]'s seventeen are designed in; twelve are named and deferred.** Reason: a plan
that lists all seventeen has chosen nothing. The five are chosen because each one is *unreachable
in ADE-L* and needs no new ngspice feature: the `CKTncDump` starred-node highlight, the
convergence ladder + `optran` panel, `wrnodev` save/restore of a DC solution, the `.sens` glob
filter + offline parameter picker, and the transient-noise panel [F16]. §9 argues each.

### Migration (S8)

**P29. The default seed stays four rows until the user rules otherwise.** Reason: `dict merge` is
per top-level key, so a fifth seeded row would reach *new* sessions only and never the 105
committed benches [ase-state §6.4] — an asymmetry that must be a decision, not an accident. And
`test_ase_core.tcl:287-288` and `W1p` assert the four rows, so changing it is a suite move and a
new-session behaviour change at once.

**P30. Row identity (`id`) is introduced only when the dialog learns to address rows by index —
not before.** Reason: `chana_row` returns *the first row of the type* and `pane_dblclick`
computes the row index and throws it away [ase-ui §2.9], so a second `dc` row is emittable,
displayable and deletable but not editable. Adding `id` without fixing the addressing would put
a key in the state file that nothing can reach.

---

## 4. The twelve entries, filled in

This is the payoff of the thesis: once §2 exists, this table *is* the feature. Grammars are from
the parser, not the manual (`inp2dot.c` is the authority; the built-in help disagrees in three
places [an-smallsig §7.2, an-rf-pss §7]).

| type | order | anchor | gate | form fields (in order) | emitted line | plots, newest first | simtype |
|---|---|---|---|---|---|---|---|
| `op` | 0 | 40 | — | *(none)* | `op` | `Operating Point` | `op` |
| `dc` | 10 | 10 | — | `source start stop step` + optional `source2 start2 stop2 step2` | `dc <src> <a> <b> <s> [<src2> <a2> <b2> <s2>]` | `DC transfer characteristic` | `dc` |
| `ac` | 20 | 20 | — | `sweep points start stop` (+`dec` deprecated) | `ac <sweep> <n> <fa> <fb>` | `AC Analysis` (+`AC Operating Point` under `keepopinfo`) | `ac` |
| `tran` | 30 | 30 | — | `step stop tstart tmax uic` + the transient-noise section (§9.5) | `tran <step> <stop> [<tstart> [<tmax>]] [uic]` | `Transient Analysis` | `tran` |
| `noise` | 40 | 0 | — | `output outref source sweep points start stop ptssum` | `noise v(o[,r]) <src> <sweep> <n> <fa> <fb> [<pps>]` | `Integrated Noise`†, `Noise Spectral Density Curves` (+op under `keepopinfo`) | `noise` |
| `tf` | 50 | 0 | — | `outkind outnode outref outsrc insrc` | `tf v(n[,r])\|i(vsrc) <insrc>` | `Transfer Function` | *literal* |
| `pz` | 60 | 0 | — | `in1 in2 out1 out2 transfer mode` | `pz <n1> <n2> <n3> <n4> {vol\|cur} {pol\|zer\|pz}` | `Pole-Zero Analysis` | *literal* |
| `disto` | 70 | 0 | — | `sweep points start stop f2overf1` | `disto <sweep> <n> <fa> <fb> [<r>]` | 2 harmonic plots, or **3** IM plots when `f2overf1` is given | *literal, per plot* |
| `sens` | 80 | 0 | — | `outkind outnode outref outsrc filters mode sweep points start stop` | `sens <out> [<filters>] {ac <sweep> <n> <fa> <fb> \| dc}` | `Sensitivity Analysis` | *literal* |
| `sp` | 90 | 0 | `has_sp` | `sweep points start stop donoise` | `sp <sweep> <n> <fa> <fb> [<donoise>]` | `SP Analysis` (+`AC Operating Point` under `keepopinfo`) | `ac` |
| `pss` | 100 | 0 | `has_pss` | `fguess stabtime oscnode† steady_coeff points harmonics sciter uic` | `pss <7 positional> [uic]` | `Time Domain …` + `Frequency Domain Periodic Steady State Analysis` | *literal, per plot* |
| *(`options`)* | — | — | — | **not an analysis** — the ~86-keyword task settings sheet, which is the option catalogue of §6 | — | — | — |

† `Integrated Noise` exists only when `start != stop` [M3]. `oscnode` is assigned once and never
read — the argument is inert (`dcpss.c:126`) [an-rf-pss §3.4], so the field exists to keep the
positional grammar and its hint says so.

*literal* means `simtype` is the exact `Plotname:` string, `strcmp`-compared by
`save.c:994-1004` — `Pole-Zero Analysis`, `Transfer Function`, `Sensitivity Analysis`,
`DISTORTION - 2nd harmonic`, and so on. **`SEN2` and `HB` are not in this table and never will
be**: they are `extern`-declared and defined nowhere [F1].

**Per-type precheck rules**, i.e. the netlist facts that make an offered analysis refusable:

| type | refuse when | source |
|---|---|---|
| `ac`, `noise`, `disto`, `tf`, `sp` | the named input source is absent, is not a V/I source, or has no AC value (`E_NOACINPUT`) | `noisean.c:110-142`; `an-smallsig §2.4` |
| `noise`, `pz` | `option klu` is in force (both refuse with a clean `E_UNSUPP`) | `noisean.c:73-78`, `pzan.c:29-35` |
| `sens` | `option klu` **and** mode `ac` — this one **SIGSEGVs**, it does not refuse | [F8/D3], guard commented out at `cktsens.c:97-105` |
| `pz` | any transmission line in the circuit; input shorted; output shorted; in == out with `vol` | `pzan.c:92-128` |
| `sp` | fewer than two ports, or non-contiguous `portnum` — **`controlled_exit`, the process dies** | `span.c:376-386` |
| `dc` | `sgn(stop-start) != sgn(step)` (zero points, no error at all) or `step == 0` | `dctrcurv.c:213-264`, `inp2dot.c:320-322` |
| `ac`, `sp`, `noise`, `disto` | `lin` with `points == 2` → **one point, silently** | [F8/D2], `acan.c:103-114` |
| any | the type's `gate` is set and the capability is not `known 1` | P4 |
| the deck | `disto` enabled without a resolving save → **SIGSEGV** | [M4], P14 |

---

## 5. The type list, concretely (S1)

```tcl
# ase_window.tcl — the radio row, derived. Replaces `foreach t {op dc ac tran}`.
proc ase::ui::chana_offered {key} {
    set st  [ase::session_state $key]
    set sim [ase::state_get $st simulator]
    set out {}
    foreach t [ase::an_types $sim] {
        set gate [ase::an_gate $sim $t]
        if {$gate eq {}} { lappend out [list $t enabled {}] ; continue }
        # A capability KEY that is absent means "not measured", never "no"
        # (ase.tcl:2827-2831). Only the free peek is consulted here: no probe
        # is EVER started from a dialog opening (issues 0953/0958).
        set caps [ase::sim_caps_have_path $sim]
        if {[dict exists $caps $gate] && [dict get $caps $gate]} {
            lappend out [list $t enabled {}]
        } elseif {[dict exists $caps known] && [dict get $caps known]} {
            lappend out [list $t disabled [ase::ui::lbl_an_not_in_build $t]]
        } else {
            lappend out [list $t disabled [ase::ui::lbl_an_unmeasured $t]]
        }
    }
    return $out
}
```

Layout: the row becomes a **wrapping grid**, not `pack -side left`, because twelve radios run off
the right edge past about eight [ase-ui §6 row 1]. Four per row, `grid`, paths unchanged
(`$w.types.<type>` — the suites' `$top.chana.types.tran` still resolves). A disabled radio keeps
its path and carries the reason as a `::balloon` tip; that is what makes "your ngspice was built
without PSS" a fact the user can read instead of a control that is not there.

Beside the row, one **Detect** button (the `simdlg_editor` precedent), which is the *only* door
that starts a probe. That single decision retires the whole of issue 0958's complaint for this
surface: the dialog never pays for a measurement the user did not ask for.

### 5.1 The three refusal classes rendered

* **Not in this build.** Radio disabled, tip = `ase::ui::lbl_an_not_in_build`. For `pss` a second
  sentence is owed: nobody has ever run it — `WITH_PSS` is off in `build-ver_50`, both trees are
  read-only, and the dossier's own recommendation is that a PSS panel is unshippable until
  someone builds it and records the two `Plotname:` literals and whether the recursive
  `DCpss(ckt,1)` re-entry terminates [crit §5.7 item 1]. **PSS ships as a declared entry with
  `gate has_pss` and no form fields wired, so the table is complete and the feature is honestly
  absent.**
* **Dangerous.** Offered, refused at preflight, remedy named. Two live cases: `sens`+`ac`+`klu`
  (SIGSEGV) and `disto` without a resolving save (SIGSEGV). Both are *deck* facts, so the refusal
  belongs in `ase::preflight_gate`, which already runs before any artefact is read, deleted or
  written [I6(a)].
* **Needs the netlist.** Offered, refused at preflight, missing thing named. `sp` is the sharp
  one: zero or one port is `controlled_exit(EXIT_BAD)` — the process dies at rc 1 and the
  `.control` block never resumes, so `sim_status` cannot save it [an-rf-pss §2.6/§2.12]. A Run
  button that can kill the simulator on a configuration mistake is not shippable; the port count
  is checked in Tcl, before the deck is written.

---

## 6. The form (S3)

### 6.1 Field kind → widget → validator

| kind | widget | validation | precedent |
|---|---|---|---|
| `real int freq time volt amp` | `entry` + `-validate key` | SPICE-suffix parse (`ase::parse_eng`, the inverse of `ase::format_value`), bounds from the field, refused at OK with the reason on the form | `simdlg_path_validate` is the file's one working validator; note it must defer with `after idle` because a validate command runs *before* the entry changes [ase-ui §3.5] |
| `enum` | readonly `ttk::combobox` `-style Ase.TCombobox` | membership | `simdlg_case_show` rebuilds `-values` live |
| `flag` | `checkbutton` | — | everywhere |
| `node nodepair source vsource device param` | `entry` + **Pick** button at grid column 2 | resolved against `ase::netlist_map` at OK (a warning) and at preflight (a refusal) | `simdlg_editor`'s `Browse…`/`Detect` at column 2; `select_on_design` for the click |
| `compound` | two or three widgets in one row, one state key | the composing proc owns it | `tf`'s `v(a,b)` vs `i(vsrc)` |
| `text` | `entry` | none — and it is only used for `sens`'s glob filters | — |

**The unit-suffix parser is new and is the single most-used new piece.** Nothing in ASE-L parses
`10n` today: `ase::format_value` renders a number for *display only* and has no inverse
[ase-ui §5.3]. It must accept ngspice's own set (`f p n u m k meg g t`, case-insensitive, with
trailing junk allowed — `1meghz` is 1e6 in ngspice) and it must **never rewrite the stored
value**: the state file keeps what the user typed, exactly as decision N requires for numeric
fields.

### 6.2 The sweep-type selector, which is the ADE behaviour people actually miss

```tcl
# In chana_show, after the row is built:
if {[dict exists $fspec relabel]} {
    trace add variable ::ase::ui::dlg($key,f_$fname) write \
        [list ase::ui::chana_relabel $key $fname]
}
# and the handler is one line per target:
proc ase::ui::chana_relabel {key fname args} {
    ...
    foreach {target map} $relabel {
        if {[dict exists $map $val]} {
            $w.l$target configure -text "[dict get $map $val]:"
        }
    }
}
```

`dialog_row` names the label `$w.l<ename>` — that is why the relabel is one `configure`
[ase-ui §3.1]. The behaviour it buys: choosing `lin` makes the neighbour say **Number of
points**, `dec` makes it say **Points per decade**. This is not cosmetic. `numsteps` means
*total* for `lin` and *per decade* for `dec`/`oct`, and getting it wrong is the classic ngspice
AC mistake [an-rf-pss §6 item 10]; the same field also has the `lin 2 → one point` trap [F8/D2],
which the validator refuses with "a linear sweep needs 1 point or 3 or more".

### 6.3 The fifteen ADE-L Choosing-Analyses behaviours, answered

| # | ADE-L behaviour | this design |
|---|---|---|
| 1 | every analysis the simulator declares, as a wrapped radio grid | **adopt** — table-driven, `grid`-wrapped, gated (P4) |
| 2 | per-analysis form swaps in place | **already have it**, and the destroy list stops being a trap (§2.6 row 5) |
| 3 | Enable checkbox on the form | already have it |
| 4 | Enabled column in the list | **improve** — keyboard-reachable, and a confirm on the destructive path; today a stray click in a 63 px column silently edits the deck with no undo [ase-ui §1.3] |
| 5 | sweep triple with a mode selector that relabels | **adopt** (§6.2) |
| 6 | Options… of typed simulator options | **adopt and fix** — this is a correctness defect today (P17) |
| 7 | Apply (commit without closing) | **adopt**, stage 5; it moves the button bar, which `GE4` reads |
| 8 | per-type form memory across type switches | **ruling R-4** — it reverses recorded decision D4 |
| 9 | several analyses of the same type | **adopt, late** (P30) — needs `id` *and* the dialog's addressing fixed |
| 10 | list starts empty | **refuse for now** (P29) — ruling R-6 if the user wants it |
| 11 | field-level rejection shown next to the field | **adopt** (P9) |
| 12 | typed, unit-bearing fields | **adopt** (§6.1) — and it is what makes 6 safe |
| 13 | pick the sweep source from the design | **adopt** (P10) — ADE-L makes you type it, so this is ahead |
| 14 | analyses run in list order | **refuse** — the order is table data, but `op`-last is measured and pinned (P11); a user-visible reorder control would invite exactly the 74.9 MB regression 0964 fixed |
| 15 | the setup travels with the cellview | **already better** — `.state` views, multiple per cell, Load/Save browsers |

---

## 7. The options surface (S4)

Two catalogues, one table, five routes.

```tcl
# ase.tcl — one row per option. ~120 rows to start (the ones a GUI should offer),
# not 250: the catalogue's job is to be a CURATED surface over two raw ones.
ase::opt_declare gmin {
  cptype  real          ;# CP_BOOL|CP_NUM|CP_REAL|CP_STRING|CP_LIST|task
  route   deck          ;# deck | control | set | argv | spiceinit
  scope   global        ;# global | analysis
  cat     convergence   ;# tolerance|iteration|timestep|convergence|device|temp|
                        ;#  solver|output|diagnostic|netlist|experimental
  default 1e-12
  analyses {}           ;# {} = every analysis; else the types it is meaningful for
  help    {Minimum conductance added across every pn junction}
}
ase::opt_declare keepopinfo {
  cptype task  route control  scope analysis  cat output  default 0
  analyses {ac noise pz tf disto sp}
  effect  {adds one extra Operating Point plot before the analysis}   ;# P21/M3
}
ase::opt_declare sqrnoise {
  cptype bool  route set  scope analysis  cat output  default 0
  analyses {noise sp}
  effect  {reports V^2/Hz instead of V/sqrt(Hz) and renames both noise plots}
}
ase::opt_declare oldlimit {
  cptype task  route deck  scope global  cat convergence  default 0
  warn    {reaches the simulator only as a .options CARD — TSKfixLimit is not
           copied on the .control route (cktntask.c:68)}
}
ase::opt_declare itl4 {
  cptype task  route deck  scope analysis  analyses {tran}  default 10
  floor   100
  inert_below 100
  warn    {values below 100 do nothing: niiter.c:37-39 raises maxIter to 100}
}
ase::opt_declare ramptime { retired {an XSPICE code-model knob behind XSPICE_EXP,
                                     which is defined nowhere in this tree} }
ase::opt_declare nosavecurrents { retired {documented by the manual; absent from
                                           this source tree entirely} }
```

### 7.1 Finding one option among two hundred

One dialog, four elements, and no wall of fields:

1. a **filter entry** (`combo_filter`'s prefix-match idiom, already in the file),
2. a **category list** on the left (the eleven `cat` values — they come straight from
   options.md §7 and hidden-vars §7, which are already grouped this way),
3. the **rows that differ from default, pinned at the top**, with everything else behind
   "Show all". This is the single most useful view and it is free: the catalogue carries
   `default`, so "what have I changed" is a filter, not a feature;
4. a **live preview pane** showing the exact lines that will be emitted and *where* —
   `.options gmin=1e-10` above `.control`, `set sqrnoise` inside it, `-D casemode=preserve` on
   the command line, `set wnflag=1` into a generated `.spiceinit`. **ADE-L shows you a form.
   Showing the deck text is strictly more informative and it is what stops the F3 class of
   defect from ever coming back** — a setting that has no line in the preview is not in force,
   visibly.

### 7.2 Emission

```tcl
# The ONE place an option turns into text. Returns {where line}, and the caller
# is the only thing that knows how to deliver each `where`.
proc ase::backend::ngspice::opt_emit {name value} {
    set o [ase::opt_spec $name]
    switch -- [dict get $o route] {
      deck    { return [list deck    ".options [ase::opt_kv $name $value]"] }
      control { return [list control "option [ase::opt_kv $name $value]"] }
      set     { return [list control "set [ase::opt_kv $name $value]"] }
      argv    { # ⚠ -D is CP_STRING or CP_BOOL only, and `-D name=1` KILLS a
                # CP_BOOL (measured, hidden-vars §1.5).
                if {[dict get $o cptype] eq {bool}} { return [list argv "-D $name"] }
                if {[dict get $o cptype] eq {string}} { return [list argv "-D $name=$value"] }
                return -code error "ase: $name cannot be delivered on the command line" }
      spiceinit { return [list spiceinit "set [ase::opt_kv $name $value]"] }
    }
}
```

Four traps, encoded so the wrong form is unwritable [F15]: `opt_kv` emits a bare name for
`cptype bool` and `name=value` otherwise; `argv` refuses anything but bool/string; `spiceinit` is
the only route for a CP_NUM/CP_REAL/CP_LIST pre-deck variable; and `savecurrents` + `ac` keeps
the existing `remzerovec` (already emitted per analysis, decision E) plus a warning, because the
manual's documented workaround does not exist here [crit §1.2, hidden-vars §4].

### 7.3 Where each route is delivered

| route | delivered by | pinned by | note |
|---|---|---|---|
| `deck` | `render_deck`, above `.control` | deck goldens D1/E12 | already exists (`.options` emission, step 6) |
| `control` | `render_deck`, inside `.control`, per P21 before/after its analysis | deck goldens | new |
| `set` | same, as `set name[=v]` | deck goldens | new |
| `argv` | `run_cmd` | **`test_ase_simreg_0931` row D4 pins the command word-for-word** | adding args moves that golden — a deliberate, single-stage change |
| `spiceinit` | `run_deck`, written into the run directory before launch | new | **⚠ P27: silently ignored when the simulator entry carries `--no-spiceinit`, and it also interacts with the casemode machinery, where a stray `.spiceinit` is a known defeat path** |

### 7.4 The convergence remedy panel

Not a field wall (P22). One panel, four rungs, matching `cktop.c`'s actual ladder:

```
Operating point strategy
  [x] 1. Newton from the initial guess                      -> optran arg 1
  [x] 2. gmin stepping        steps [ 10 ]                  -> optran arg 2
  [x] 3. source stepping      steps [ 10 ]                  -> optran arg 3
  [x] 4. transient operating point   step [ 100n ] to [ 10u ]  -> optran args 4,5
        (on by default in this ngspice — you have been using it)
      [ Pick a stop time ]  = 100 x tstep before a transient, 0.1/fstart before ac/noise
  emits:  optran 1 10 10 100n 10u 0
```

with a **live ladder readout** during the run, parsed off the merged output stream for the fixed
strings `Starting dynamic gmin stepping` / `Starting true gmin stepping` /
`Starting source stepping` / `Transient op started` and their `completed`/`failed` verdicts
[convergence §4.3]. Two parsing hazards that must be in the code as comments: the `ngdebug`
per-step lines (`Trying gmin = …`, `Supplies reduced to …%`) end **without a newline**, and the
ladder is on stderr while `CKTncDump` and the initial-transient table are on stdout — ASE-L
captures `2>@1`, so the two streams interleave unpredictably and the parser must be
order-independent.

---

## 8. The deck (S5)

### 8.1 The loop, after the collapse

```tcl
# render_deck, replacing `set anorder {...}` + the four-arm switch.
# Everything else in render_deck is untouched: it is already schema-driven
# and already scales (ase-deck §7.1).
set anorder [ase::an_emit_order $sim $state $optier_live]     ;# P11
foreach type $anorder {
  set ai -1
  foreach a [ase::state_get $state analyses] {
    incr ai
    if {[ase::state_get $a type] ne $type} { continue }
    if {[ase::state_get $a enabled 0] ne {1}} { continue }

    # (1) 0964: device requests immediately before the ONE analysis that can use them
    if {$type eq {op}} { foreach opsl $optier_ctl { lappend lines $opsl } }

    # (2) per-analysis options, set before / restored after (P21)
    foreach l [ase::an_opt_lines $sim $a set] { lappend lines $l }

    # (3) THE ANALYSIS. One dispatch. No switch, no default case that can drift:
    #     an_known is false -> we never got here, preflight refused (P1).
    foreach l [ase::an_emit $sim $type $a $opts] { lappend lines $l }
    if {$type eq {op}} { foreach opsl $optier_post { lappend lines $opsl } }

    # (4) the epilogue, unchanged and still type-blind (decisions D, E)
    foreach g [::ase::backend::ngspice::sim_status_guard] { lappend lines $g }
    lappend lines "remzerovec"
    if {$type eq {op} && [llength $optier_write]} {
      lappend lines "write [raw_file $state] all [join $optier_write { }]"
    } else {
      lappend lines "write [raw_file $state]"
    }

    # (5) NEW: the extra plots of a multi-plot analysis [M1,M2,M3]. For every
    #     analysis in the tree today this list has length 1 and emits NOTHING,
    #     so every committed deck golden stays byte-identical.
    set pl [ase::an_plots $sim $type $a $opts]
    for {set p 1} {$p < [llength $pl]} {incr p} {
      lappend lines "setplot previous"
      lappend lines "remzerovec"                       ;# per-PLOT (P13)
      lappend lines "write [raw_file $state]"
    }

    # (6) per-analysis options restored (P21)
    foreach l [ase::an_opt_lines $sim $a restore] { lappend lines $l }

    if {[list $type $ai] eq $printanchor} { foreach pl2 $printlines { lappend lines $pl2 } ; set printsdone 1 }
  }
}
```

```tcl
proc ase::an_emit_order {sim state optier_live} {
    set types {}
    foreach t [ase::an_types $sim] {           ;# ascending `order`
        if {[ase::an_enabled_rows $state $t] ne {}} { lappend types $t }
    }
    # Decision A / issue 0964. NOT reorderable by taste: ngspice's save list is
    # sticky FORWARD ONLY (`unsave` does not exist, a later `save all` does not
    # reset it — both measured), so with in-.control device requests every
    # analysis after `op` re-records the device numbers: +74.9 MB, +4.08 s on
    # the user's tb_bandgap.
    if {$optier_live && [lsearch -exact $types op] >= 0} {
        set types [lsearch -inline -all -not -exact $types op]
        lappend types op
    }
    return $types
}
```

Note what did *not* change: `set appendwrite`, the deletion of the raw before the run, the
guard-before-write ordering, the `.save all` leader at deck level, the op-only device write, the
print anchor. Those are invariants I1–I9 and decisions A–F, and every one of them survives the
collapse because the collapse only touches *which line names the analysis*.

### 8.2 Dot cards vs `.control` commands — agreeing with the critique, with one addition

Commands, one at a time [P11]. The critique's four reasons stand [crit §5.5]; I add a fifth from
this session: **`.disto` reaches its SIGSEGV through the save-scope starvation that dot cards
create** — `.op` installs `com_save2(&all,"OP")`, which scopes the save list to OP and starves
every later analysis [crit §D1], and my [M4] shows the same crash arriving through a stale `.save`
on the command route. The command route plus P14 plus P15 closes both doors.

The one place a **dot card** is still required is the layer *around* the analyses — `.four`,
`.meas`, `.probe`, and any `.options` with `route deck`. Those go above `.control` [I2], into
the emission slot that is today op_annot's private territory (step 11 of [ase-deck §1.1]). Two
consequences to carry: `.meas` cards are refused under `-r` (irrelevant here, `-r` is already dead
[I7]) and **two `.sens` cards abort the process** [F8/D5] — which is one more reason the analysis
layer never emits cards.

### 8.3 Where the pre-deck options go

Outside the deck by definition [F15 §3]. Three delivery points, and the design uses all three:

| what | where | why not elsewhere |
|---|---|---|
| `casemode`, `ngbehavior`, `soacheck`, `no_auto_gnd`, `no_auto_braces`, `rawfile` | `-D name[=string]` appended in `run_cmd` | read inside `inp_readall()`, before `ci_vars` exists; `.options` and `.control` are silently too late |
| `wnflag`, the ten `ps_*` variables, **and every `var(<name>)` used by `.param x = "var(name)"`** | a generated `.spiceinit` in the run directory | CP_NUM/CP_REAL cannot travel on `-D` at all — `-D` is always a string |
| `warn`, `maxwarns` | `.options` in the deck | they are the first reads on the *safe* side of the boundary; the `--soa-log=FILE` flag that pairs with them is `argv`. One feature, two doors [F15 §3.3] |

**⚠ P27 again, because it will bite:** a `.spiceinit` in the run directory is ignored when the
simulator registry entry carries `--no-spiceinit`, and it is a known defeat path for the casemode
flag. Any stage that starts writing one must (a) read `sim_entry`'s argument list first, (b)
refuse with a sentence naming the checkbox, and (c) never write a `.spiceinit` that carries
anything the user did not ask for.

### 8.4 The decks the GUI must refuse to generate

This is the list a future session should turn into `ase::preflight_gate` rows. Each is a
*construction* rule, not a warning.

1. **`disto` enabled and no save that resolves in the distortion plot.** Emit `.save all`
   (P14); if the user has explicitly turned the blanket off, refuse the run. [M4] rc 139.
2. **`sens` in `ac` mode with the solver set to `klu`.** Refuse; offer to switch to `sparse`.
   [F8/D3] rc 139.
3. **Any `lin` sweep with `points == 2`** in `ac`, `sp`, `noise`, `disto`. Refuse at the field.
   [F8/D2] — silently one point.
4. **`dc` whose step sign disagrees with the span, or whose step is 0.** Refuse at the field.
   Zero rows, `$sim_status` 0, four zero-length vectors, no message.
5. **`sp` with fewer than two ports, or non-contiguous `portnum`.** Refuse before writing the
   deck: the simulator *dies* (`controlled_exit`), so no in-deck guard can help.
6. **`noise`/`ac`/`disto`/`tf`/`sp` whose input source has no AC value.** Refuse; the deck would
   run and report `ac input not found`.
7. **`pz` with a transmission line present, shorted input or output, or in == out under `vol`.**
   Refuse; each is a hard `E_*` and one of them is a plot with zero vectors.
8. **Any analysis type not declared in the table.** Refuse loudly — this is P1, and it is the
   only refusal that ships in stage 1.
9. **Two rows of the same type that differ only in a field the emitter ignores.** Refuse at OK;
   otherwise the deck runs the same analysis twice and appends two identically-named plots.
10. **A save expression that does not resolve against the netlist map** (P15) — always a warning,
    and a refusal when `disto` is enabled.

---

## 9. Results routing (S6)

Decision B says the Value column is a scalar column and nothing else; decision C says do not
invent a scalar for a waveform [F13]. So every analysis needs a named destination, and three
exist.

| analysis | answer | destination | new surface? |
|---|---|---|---|
| `op` | node voltages, device operating point | Value column (the anchor) + the existing op annotation | no |
| `dc` | one sweep | waveform viewer | no — **except** a *nested* `dc`, see below |
| `ac` | complex sweep | waveform viewer | no |
| `tran` | waveform | waveform viewer; scalars via `.meas` into the Value column | no |
| `noise` | spectrum (`onoise_spectrum`, `inoise_spectrum`) | waveform viewer, `sim_type noise` — **both** noise plots attach with one `raw read` (`save.c:967-983`) | no |
| `noise` | `onoise_total`, `inoise_total` | **per-analysis scalars** → RDW section (P24); the log carries them until that lands | yes, small |
| `noise` | per-generator breakdown (`onoise_r1_thermal`, `onoise.m1.1overf`, …) | RDW table, gated on `ptssum >= 1`, with the warning that `ptssum` also decimates the spectrum — `ptssum = 1` is the setting that gives the breakdown with no decimation | yes |
| `tf` | three scalars (gain, input impedance, output impedance at node) | per-analysis scalars → RDW | no new |
| `pz` | a root list, `pole(1) zero(1) …`, complex, 1 point | RDW **table**, plus an optional root plot in the viewer. The Calculator explicitly does not model pz output (`calculator.md:585`) — do not route it there | yes, small |
| `disto` | 2 or 3 complex spectra | waveform viewer, **one attach per plot** — each plot carries a different `Plotname:` literal and therefore a different `sim_type` (§12/L8) | viewer change |
| `sens` | up to ~90 real (or complex, in ac mode) vectors | RDW **table** with the glob filter and the offline parameter picker (§10.4) | yes |
| `sp` | S/Y/Z matrices vs frequency, plus `NF NFmin Rn SOpt` for 2 ports | waveform viewer as `sim_type ac`; Touchstone via `wrs2p` **with the `.csparam Rbase=50` workaround** (`wrs2p` fails with `Error: No Rbase vector given` otherwise); Smith chart is a viewer feature, deferred and named | viewer change |
| `pss` | two plots, time then frequency | viewer, one attach per plot; **no phase and no `meas` support** — `com_measure2.c:1660-1666` rejects pss plots, so the results UI must not offer either | blocked on a build |
| `.four` | THD + harmonic table (`fourierMN`, `thdMN`) | RDW table + a harmonic bar chart | yes |
| `.meas` | scalars | Value column via the existing `result_probe` path — the `meas` **command** inside `.control`, redirected with `> file` for full precision (the vector is truncated to 7 significant digits at `measure.c:138`) | no |
| transient noise [F16] | a waveform, an rms scalar, optionally a spectrum | viewer + Value column (via `meas … RMS`, **not** `stddev()`, which measured 5 % high) + a `linearize`+`fft` plot | no |

**Nested `dc` is the one case where ngspice loses information the GUI must rebuild.** A two-level
sweep comes back **flattened into one 1-D vector with no `Dimensions:` header** [F10,
outputs §4.3]. ADE gives a family of curves for free; here the GUI must slice the vector itself
using the point count it computed when it wrote the sweep. That is a viewer feature with a real
cost, and the design's position is: **offer the second sweep level, and slice in the GUI** —
because the alternative (not offering it) throws away the one nesting ngspice does support.

### 9.1 How a multi-plot analysis is labelled

By its literal `Plotname:` string, which the descriptor carries and `$curplotname` confirms at run
time (P25). In the viewer's dataset list and in the RDW the user sees
`Noise — Spectral Density` / `Noise — Integrated`, minted from the descriptor's `results` entry,
never a typename like `noise2` and never an index. The typename counter is per-abbreviation and
shared (`keepopinfo`'s noise operating point comes back as **`op1`** [M3]), so it is unusable as
an identity.

---

## 10. Beyond ADE (S7)

### 10.1 Sweeps, corners and Monte Carlo — one generated `.control` layer

There is no `.step`, no corner construct, and `.dc` nests two levels and sweeps only R / V / I /
`temp` [F10]. So the GUI generates. The model, from [orchestration §11], with F15's mechanism as
the delivery route:

* An **axis** is `{kind name values}`.
  * *design variable* → `.param <n> = "var(<n>)"` in the deck **plus** `set <n>=<v>` in the
    generated `.spiceinit`, or `alterparam <n>=<v>` + `reset` per point. The first form is the
    one that honours the founding doctrine — **the schematic carries only the circuit**
    [F13] — because the value never touches a symbol.
  * *instance parameter* → `alter <flat> <param> = <v>` (no re-parse).
  * *model parameter* → `altermod @<model>[<param>] = <v>`.
  * *temperature* → `set temp = <v>`, collapsing to `dc temp a b s` when it is the only axis.
  * *corner* → one generated top-level deck per corner, `source`d in a loop (route B).
  * *statistical* → run count + seed, `setseed <n>` once, `reset` per run.
* **Values** are expanded by the GUI, never by ngspice.
* **Per-run outputs** are `meas` statements; each gets a column in a collector plot, and the axis
  coordinates are stored as columns too — that is the only thing that makes the result table
  joinable.
* **Reproducibility is shown, not assumed**: the seed, whether the deck carries `.option seed`
  (warn loudly), and the fact that the campaign starts with a `reset`.

It is a **dialog**, not a fourth pane (P26), with a one-line summary of the campaign in the
status bar so a bench that is sweeping never looks like a bench that is not.

### 10.2 The five picks from [F14], and why these five

1. **`CKTncDump`'s starred nodes, highlighted on the schematic.** After a failed operating point
   ngspice prints a `Last Node Voltages` table with a trailing ` *` on every node that still
   fails the convergence test (`cktncdump.c:11-43`). xschem already has net highlighting and
   `ase::netlist_map` already maps deck names back to nets. **This is the biggest single win
   available and it needs no new ngspice feature.** ADE hands you an opaque `sim.log`.
2. **The convergence ladder + `optran` as a live pane and a guided remedy** (§7.4). Chosen
   because `optran` is *on by default* in this tree, silently sets the accuracy of every fallback
   operating point, supersedes three `.options` a user might set, and no user has ever seen it
   [F11]. A GUI that shows which rung solved your circuit is telling the user something Cadence
   does not.
3. **`wrnodev` — save and restore a DC solution.** `com_wr_ic.c:25-66` writes the current node
   voltages as a ready-to-`.include` `.ic` file; it is "the closest thing ngspice has to Cadence's
   save/restore DC solution" [convergence §1.6]. One button ("Save this operating point"), one
   checkbox ("start from the saved one"), and a class of unconvergeable benches becomes routine.
4. **`.sens` glob filters + the offline parameter picker.** `sens v(out) r*:r m*:vth0 ac …` plus
   the `devhelp -csv -type -flags` predicate — `Dir == inout && Type == real && flags contain
   neither X nor R` — lets the GUI show a checkbox tree of perturbable parameters *computed
   without running anything* [crit §5.6]. It turns an unusable 90-vector dump into a design tool,
   **and ADE-L has no sensitivity analysis at all.**
5. **The transient-noise panel** [F16]. `trnoise`/`trrandom` are instance parameters on both
   `vsrc` and `isrc`, documented nowhere in-tree, reachable with `alter` on an existing DC-only
   source or one generated parallel current-source line — so it needs **no schematic change**.
   ADE-L has no transient-noise feature at all; this is a category where ngspice is ahead and the
   GUI can show it. Non-negotiable honesty in that panel: white and 1/f noise are **not
   reproducible** in this build (the Wallace pool is seeded from `getpid()`), only RTS and
   `trrandom` respond to `setseed`, and the label must say so — one sentence that prevents a bug
   report.

### 10.3 The twelve not chosen, one line each

`speedcheck`/`deltacheck` (needs `ngdebug`; a diagnostics-pane item, not an analysis one) ·
`rusage devtimes` (same pane, later) · `stop when`/`resume`/`step` (needs interactive or `-p`
mode; ASE-L runs `-b` [F9] — it is a transport change, not an analysis change) · `iplot`
(refused in batch, same reason) · `diff` (a regression feature that belongs with the RDW's
run-to-run comparison) · `.probe` power (a nice Outputs-pane column; belongs to the outputs axis,
not this one) · `set topo_reduce` (goes into the convergence remedy list as one more rung, no
panel of its own) · `.four`'s bar chart (routed in §9, but the chart itself is viewer work) ·
`group_delay`/`cph`/`mtimeavg`/`deriv`/`integ` (a Calculator menu — the Calculator has its own
spec) · `--soa-log` (a diagnostics pane, and it needs the two-door `warn`+flag handling of §8.3) ·
`snsave`/`snload` (untested, and the snapshot format is undocumented) · a Smith chart (a viewer
feature with its own geometry work).

---

## 11. Worked example — NOISE, from the form to the plot and back

The user has a bandgap testbench open, an operating point enabled, and wants input-referred noise
at `VBG` from 1 Hz to 1 MHz.

### 11.1 The form

`Analyses > Choose…` → the radio grid shows twelve entries, four per row. `pss` is present and
greyed with the tip *"this ngspice was built without PSS"*; everything else is live because
`gate` is `{}` (P4) and no probe ran. The user clicks **Noise**.

`chana_show` destroys **every** field widget the table can produce
(`ase::an_all_field_names` — the union, so nothing from the previous type survives; this is the
trap of [ase-ui §2.5] closed by construction), then builds rows 2.. from
`[ase::an_fields ngspice noise form]`:

```
Choose Analyses                                        (.aseN.chana)
 ( ) op   ( ) dc   ( ) ac   ( ) tran
 ( ) noise•  ( ) tf   ( ) pz   ( ) disto
 ( ) sens ( ) sp   ( ) pss‡
 [x] Enable
 Output node:        [ VBG                    ]  [Pick]
 Output reference:   [                        ]  [Pick]     blank = ground
 Input source:       [ V1                     ]  [Pick]     must carry an AC value
 Sweep type:         [ dec              v]
 Points per decade:  [ 10                     ]            <- relabelled by Sweep type
 Start frequency:    [ 1                  ] Hz
 Stop frequency:     [ 1meg               ] Hz
 Points per summary: [                        ]            1 = per-device breakdown
 <status line, row 7>
 [Options…]                                       row 8
 [OK]                                    [Cancel] row 9
```

`Pick` puts `select_on_design` into `field` mode (P10); a click on the schematic's `VBG` net
fills the entry with the hierarchy-qualified, case-mode-correct name. Choosing `lin` in the
combobox rewrites the neighbour's label to **Number of points** and arms the `points == 2`
refusal (§6.2). Typing `banana` into *Stop frequency* is refused **on the form** at row 7 (P9),
not in the CIW — and the dialog stays up, as it does today, but now it says why.

### 11.2 The state row

```tcl
analyses {{type op enabled 1}
          {type dc enabled 0}
          {type ac enabled 0}
          {type tran enabled 1 stop 200u step 10n}
          {type noise enabled 1 output VBG source V1 sweep dec points 10 start 1 stop 1meg}}
```

No new top-level key, no `schema_keys` change, `version` still 1 (P3). `outref` and `ptssum` were
empty, so `chana_ok`'s existing empty-deletes-the-key rule keeps them out of the file — the row
is exactly as long as the settings it carries. The other 105 committed states are untouched and
still round-trip byte-identically.

### 11.3 The deck

`render_deck` emits (only the `.control` block shown; everything above it is unchanged):

```
.save all
.save v(VBG)
.control
set appendwrite
op
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write /run/tb_bandgap_ase.raw
print v(VBG)
tran 10n 200u
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write /run/tb_bandgap_ase.raw
noise v(VBG) V1 dec 10 1 1meg
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write /run/tb_bandgap_ase.raw
setplot previous
remzerovec
write /run/tb_bandgap_ase.raw
.endc
.end
```

Read the five things that are load-bearing:

1. **Order.** `op` first, then `tran`, then `noise` — `order` 0, 30, 40 (P11). If the bench had
   device-parameter requests the order would become `tran noise op`, and `noise`'s `order 40`
   keeps it before `op` in that case too, which is exactly what decision A requires.
2. **The guard is per analysis, above the write** [decisions D, I5]. A `noise` that fails after a
   good `tran` still ends the run at rc 1 with `RUN-FAILED`, and the bad plot never enters the
   raw.
3. **`remzerovec` twice for one analysis** — once before each write, because it is per-plot
   (P13).
4. **`setplot previous` + a second `write`** is the whole multi-plot fix, and it is three lines
   [M1, M2]. Had the user typed `start = stop`, `an_plots_noise` would have returned one plot and
   these three lines would not be there [M3] — a static list would have re-written the
   transient's plot into the raw under the wrong name.
5. **The print anchor did not move.** `noise` is `anchor 0`, so `print v(VBG)` still rides the
   operating point (P24, decision B) and the Outputs Value column still shows an op number, as
   ruled in issue 1243.

### 11.4 The run and the raw

```
Plotname: Operating Point
Plotname: Transient Analysis
Plotname: Integrated Noise
Plotname: Noise Spectral Density Curves
```

Four plots, one file, `set appendwrite` [I3], with the raw deleted before the run because append
means the file must not pre-exist.

### 11.5 Back into the GUI

* `ase::plot_sim_type` returns the *transient* (its own preference order is deliberately not the
  emit order [ase-state §7.1]) so the viewer opens where it did before. The noise datasets are in
  the same file and are attached by name.
* One `xschem raw read <file> noise` picks up **both** noise plots: `save.c:967-983` maps
  `noise spectral density curves` → `noise` and `integrated noise` → `noise`. **This is why noise
  is the easy multi-plot case and `disto` is the hard one** (§12/L8).
* The two integrated scalars go to the per-analysis results section (P24), labelled
  *Noise — Integrated*, never into the Outputs Value column.
* The Analyses pane's Arguments column reads
  `output=VBG source=V1 sweep=dec points=10 start=1 stop=1meg` today, and — after the stage-6
  ruling — reads the deck line itself, `noise v(VBG) V1 dec 10 1 1meg`, which is the strongest
  possible statement that the window and the simulator agree.

### 11.6 What the user is told that ADE-L would not tell them

* That `ptssum` buys a per-device noise breakdown **and** decimates the spectrum by the same
  factor, so `1` is the setting they want (`resnoise.c:68` gates every per-device vector on
  `NStpsSm != 0`).
* That the numbers are V/√Hz unless `sqrnoise` is set, in which case both plot *names* change
  too — and that the built-in help says the opposite and is stale [an-smallsig §3.8].
* That `mos6`, B-sources, VCVS/VCCS/CCCS/CCVS and transmission lines contribute **no noise at
  all**, so a behavioural block built from B-sources is silently noiseless.
* That `.NOISE` and transient noise are two different features, and where the other one is
  [F16].

---

## 12. What the descriptor cannot express

The most valuable section of this document. Every item below is a place where a table is the
wrong shape, and where a future session will be tempted to force it.

**L1 — ngspice has no per-analysis option scope.** `option keepopinfo` inside `.control` sets the
task option and it stays set (measured this session). P21's set-before/restore-after is a *GUI
fiction* built out of the catalogue's `default` column; it is correct only for options whose
default is known, and it is impossible for `.options oldlimit`, which is silently dropped on the
`.control` route entirely because `TSKfixLimit` is never copied (`cktntask.c:68`) [F8/D6]. The
catalogue must therefore carry `route deck` for that one option, and a per-analysis `oldlimit` is
simply not offerable.

**L2 — a plot count is a predicate, not a constant** [M3]. `noise` is 1 plot at a single
frequency and 2 otherwise; `disto` is 2 in harmonic mode and 3 in IM mode; `keepopinfo` adds one
to every small-signal analysis. Hence `plots` is a proc. A static list would either lose a plot
or re-write a previous analysis's plot under the wrong name — silently, at rc 0.

**L3 — field interdependence beyond one hop.** `tran`'s `tmax` requires `tstart` (and a missing
`tstart` must be *substituted as 0*, not shifted out of its slot); `dc`'s second sweep is an
all-or-nothing group of four; `sens`'s tail is `ac <4 args> | dc`; `tf`'s output is `v(a[,b])`
**or** `i(vsrc)` from one field pair; `pz` takes two bare enum words that the parser does not
validate at all. This is why `emit` is a proc (P7). The `fields` list can *describe* the widgets;
it cannot describe the grammar.

**L4 — preconditions are netlist facts, not row facts.** Whether `V1` has an AC value, whether
two ports exist, whether a transmission line is present, whether any parameter is sensitivity-
eligible: none of it is in the analysis row. It needs `ase::netlist_map` and therefore runs at
preflight. **Consequence the design must own: the dialog can be green and the run still refused.**
Both surfaces must say the same sentence, minted once.

**L5 — some failures cannot be guarded from inside the deck.** `sp` with fewer than two ports is
`controlled_exit(EXIT_BAD)`: the process dies at rc 1, the `.control` block never resumes, and
`$sim_status` never gets a chance. Only the GUI can prevent it. The same is true of the `.disto`
SIGSEGV [M4] and of `sens`+`ac`+`klu` [F8]. The in-deck guard is defence (b); this class needs
defence (a) [I6].

**L6 — the `op`-last rule is not a property of `op`.** It is a property of the *device-parameter
save tier*: ngspice's save list is sticky forward-only, so if device numbers are requested they
must be requested last. Encoding it as `order 999 for op` would be wrong — in the ordinary case
`op` runs **first** and the goldens say so. It stays an explicit named rule in `an_emit_order`.

**L7 — the table does not give a row an identity.** `chana_row` addresses *the first row of the
type* and `pane_dblclick` computes the index and discards it [ase-ui §2.9]. Two `dc` sweeps are
emittable and deletable but not editable. The descriptor's `multirow` flag records the intent;
making it true is a change to the dialog's addressing, not to the table (P30).

**L8 — `sim_type` is a per-PLOT fact, and the C reader compares the raw `Plotname:` literal with
`strcmp`.** `save.c:994-1004`. So `noise`'s two plots share `sim_type noise` (an explicit arm),
`sp` attaches as `ac`, and **`disto`'s plots carry two or three *different* literals** — one
`raw read` cannot attach them all. Multi-plot analyses whose plots differ in name need either one
attach per plot or a viewer change. The descriptor can *say* this (its `plots` list is
`{plotname simtype}` pairs); it cannot fix it.

**L9 — nested `dc` loses its dimensions.** ngspice flattens a two-level sweep into one 1-D vector
with no `Dimensions:` header [F10]. The GUI must slice it using the point count it computed
itself. No descriptor column can describe that; it is viewer work.

**L10 — the pre-deck options are outside the deck by construction.** `emit` cannot deliver them:
they belong to `run_cmd` (`-D`) or to a written `.spiceinit`, and `run_cmd`'s word order is
pinned byte-for-byte by a command golden [I8]. A "simulator option" and a "pre-deck variable"
look identical to the user and are two different mechanisms underneath; only the catalogue's
`route` column keeps them apart.

**L11 — a capability probe measures the command's existence, not the analysis's success**
[ase-deck §6.4]. `sp` exists in this build and still fails on a portless circuit. The GUI must
never turn `analyses_available` into a promise.

**L12 — the table cannot be filled in without the user.** Every `label` and every `notes` string
is a new user-facing sentence, and this tree's house rule is that those are the user's to ratify
(`tests/headless/owed.sh add rule`). Data entry is not free; it is one ruling per batch of
labels. §13's stages batch them deliberately.

**L13 — XSPICE/event results are a separate channel.** Event-driven nodes come back through
`eprint`/`eprvcd`/`edisplay` and a `digital` plot, not through the analysis's own plot
[xspice dossier]. A mixed-signal `tran` therefore has two result streams and the descriptor
models one. Also unresolved upstream: the DC-sweep + auto-bridge failure has a reproducer and no
root cause [crit §5.7 item 4], so `dc` on a mixed-signal deck cannot be offered honestly yet.

---

## 13. Stages (S8)

Each stage is one rebuild, ships on its own, and ends green. The order is chosen so that the
*riskiest* thing (a new analysis reaching the deck) happens only after the machinery that makes
it safe is already in the tree and proven byte-identical.

### Stage 1 — The silent drop dies

**Ships:** a refusal for any analysis type the renderer cannot emit, in two places: a
`ase::preflight_gate` row (defence (a), which runs before any artefact is read, deleted or
written [I6]) and a `-code error` backstop in `render_deck`'s dispatch for CIW/script callers.
**RED first:** a state whose only analysis is `{type noise enabled 1 …}` renders a `.control`
block with no analysis and reports nothing — assert that, watch it fail, then make it refuse.
**Proves:** [F2] is closed. **Suites:** none move; one new row. **Rulings:** none blocking; one
sentence, recorded with `owed.sh add rule`. **Cost:** ~20 lines.

### Stage 2 — The table, with today's four types, byte-identical

**Ships:** §2's descriptor, the `analysis_types` optional hook, the `ase::an_*` accessors, and
the seven call sites of §2.6 rewritten to read them. `op dc ac tran` are re-expressed as data +
four four-line emit procs.
**Proves the thesis.** The acceptance criterion is *nothing changes*: the committed deck goldens
(`test_ase_core` D1, `test_ase_final`, `test_ase_final_gf180`, row E12's byte-identity guard) are
unchanged; `W1p`'s four seeded rows and three column lists are unchanged; `G1/G2/GE4/GE5` still
drive `$top.chana.types.tran` and `$top.chana.step` by path; the 105 `.state` files still
round-trip byte-identically; `plot_sim_type` and the print anchor still answer exactly what they
answered. **Rulings:** none. **Cost:** ~250 lines net, most of it data and comments.
**This stage is the whole bet: if it cannot be made byte-identical, the descriptor's shape is
wrong and the plan should stop here rather than proceed.**

### Stage 3 — The Options… dialog stops lying, and `tran`/`ac`/`dc` grow their real fields

**Ships:** (a) the extras editor refuses at OK any key that is not a declared field, with the
reason on the form (P17) — the F3 correctness defect dies; (b) `tran` gains `tstart`, `tmax`,
`uic`; `ac` gains `sweep` (`dec|oct|lin`) and `dec` becomes `deprecated`; `dc` gains its second
sweep triple, all-or-nothing; (c) the emit procs learn the optional-tail rules, including
"`tmax` without `tstart` substitutes `tstart 0`, it does not shift a slot".
**Byte-identity holds** for every state that does not use a new field, which is all 105 of them —
measured: not one committed state carries an extra analysis key [ase-ui §2.7].
**Suites:** `G2`'s Arguments display string if `dec` leaves the summary; a new deck golden per
new field. **Rulings:** R1, R2.

### Stage 4 — Capability gating

**Ships:** the `help all` + `devhelp` probe leg publishing `analyses_available` /
`devices_available` (P5), `gate` honoured in the radio row, the three refusal classes rendered
(P6), and a **Detect** button as the only door that starts a probe.
**Suites:** `test_ase_simcaps_0948` gains rows; nothing moves. **Rulings:** R3.

### Stage 5 — The form becomes a real form

**Ships:** typed fields and the SPICE-suffix parser; `ase::ui::dialog_status` and refusals on the
form; `Pick` buttons via `select_on_design`'s new `field` mode; the sweep-type relabel; computed
grid rows (P8); `Apply`; a keyboard-reachable Enable toggle and a confirm on delete.
**Suites:** `GE4` reads the button bar; `W1p`'s "no inline add/del buttons" claim must stay true.
**Rulings:** R2 (labels), R4 (form memory / D4), R5 (relabel copy).

### Stage 6 — The first three new analyses: `noise`, `tf`, `pz`

**Ships:** three table entries, three emit procs, three plot procs, three prechecks; the
multi-plot capture of P12/P13; `simtype` wired into `plot_sim_type`; per-analysis scalars routed
(P24). Chosen because all three are unconditional in every ngspice build, none of them can crash
the simulator, and between them they exercise every new mechanism: two plots, a compound output
field, two bare enum words, and a scalar that must not enter the Value column.
**Suites:** one deck golden per analysis; a `plot_sim_type` row per analysis. **Rulings:** R6, R7,
and R8 if the Arguments column becomes the deck line here.

### Stage 7 — The options surface proper

**Ships:** the catalogue of §7 with its `route`/`cptype`/`default`/`inert_when` columns; the
filter + category + "differs from default" + **live deck preview** dialog; the five delivery
routes including the generated `.spiceinit` (P27's conflict detected and refused); the
convergence remedy panel with `optran` as its fourth rung and the live ladder readout.
**Suites:** the `run_cmd` command golden moves the first time an `argv` option is emitted.
**Rulings:** R9.

### Stage 8 — The dangerous three: `disto`, `sens`, `sp` (and `pss` declared, not wired)

**Ships:** `disto` with P14's `.save all` construction rule and P15's save resolution; `sens`
with the glob filter, the offline parameter picker and the `klu`+`ac` refusal; `sp` with a port
check that runs *before* the deck is written, and Touchstone export carrying the
`.csparam Rbase=50` workaround; `pss` present in the table, gated, with no form.
**Rulings:** R11, R12.

### Stage 9 — Beyond ADE

**Ships:** the sweep/corner/Monte-Carlo dialog (P26) and the five picks of §10.2, in the order
`CKTncDump` highlight → `optran`/ladder pane (already in stage 7) → transient noise → `wrnodev` →
sensitivity picker (already in stage 8). **Rulings:** R10 and the label batches.

### What I would put off, and say so

* **`libngspice`.** It has never been built on this machine [crit §5.7 item 2], and it gates the
  abort story and the whole progress story. Deciding it inside the analysis axis would be a
  transport decision wearing an analysis hat.
* **Graceful abort.** In batch mode ngspice installs no signal handlers, so SIGINT is immediately
  fatal — rc 130, nothing written [F9]. ASE-L's SIGKILL Stop is therefore no worse than SIGINT,
  and "stop and keep what you have" cannot be promised until the transport changes.
* **CIDER.** Never built here; five device rows and a 16-card sub-language are source-only.
* **A Smith chart and the nested-`dc` family slicer.** Both are viewer work with their own specs.

---

## 14. The ruling ledger

House rule, from the pinned memory: **ask these one at a time, discuss each, and let the answer
to one reframe the next.** Do not hand the user this list. It is ordered by when it blocks.

| # | blocks | the question | my recommendation |
|---|---|---|---|
| **R1** | stage 3 | When a user types an option the deck cannot carry, does the dialog **refuse** it or **store it and mark it inert**? | **Refuse.** Storing it is what created F3; a state file that carries settings that do not run is a lie with a long half-life. |
| **R2** | stage 3/5 | The field labels. `Points` → `Points per decade`; `Step`/`Stop` → `Time step`/`Stop time`; the new `tstart`/`tmax`/`uic` captions; and whether `dec` disappears from the Arguments column. | Adopt the unit-bearing labels; drop `dec` (no committed state carries it). ~14 strings, one batch. |
| **R3** | stage 4 | The two capability sentences: "built without PSS" and "not measured — press Detect". | Mint both; they are the whole of P6(a). |
| **R4** | stage 5 | Reverse recorded decision **D4** — should switching the analysis type keep what you typed? | **Yes**, cached in `dlg($key,anform,<type>)` for the dialog's lifetime only. D4's reason (no hidden multi-type writes) is preserved because nothing is written until OK. |
| **R5** | stage 5 | The relabel copy for the sweep-type selector. | `Points per decade` / `Points per octave` / `Number of points`. |
| **R6** | stage 6 | The twelve analysis labels as they appear in the radio row and the pane. | Lowercase deck words in the radio (they *are* the deck verbs, and the user will type them elsewhere); title-case in the pane. |
| **R7** | stage 6 | Where a per-analysis scalar (`onoise_total`, the TF triple) appears before the RDW section exists. | The run log plus a one-line summary in the status bar. Explicitly **not** the Outputs Value column (decisions B/C). |
| **R8** | stage 6 | Does the Arguments column become the **emitted deck line** instead of `key=value` pairs? | **Yes.** It is the strongest possible statement that the window and the simulator agree, and it makes an unemitted key impossible to miss. It moves two display strings (P4/G2). |
| **R9** | stage 7 | May ASE-L write a `.spiceinit` into the run directory at all? | Yes, but only when the simulator entry does **not** carry `--no-spiceinit`, only with keys the user set, and with the file shown in the preview pane. P27 is a silent-defeat path and this ruling is what stops it. |
| **R10** | stage 9 | Does `state_default` gain new seeded analysis rows, and do existing benches get them? | **No** to both, at first. `dict merge` is per key, so a new seed would reach new sessions only [ase-state §6.4]; Cadence does not add analyses to your bench either. |
| **R11** | stage 8 | Offer `pss` at all, given nobody has ever run it and the build here lacks it? | Declare it, gate it, ship no form. Revisit after someone builds `--enable-pss` and records the two `Plotname:` literals. |
| **R12** | stage 8 | Offer the second `dc` sweep level before the viewer can slice families? | Yes — the flattened vector is still correct data, and the alternative is throwing away the one nesting ngspice has. Say in the form that the second sweep comes back flattened. |

---

## 15. Refusals

What this design will not do, with the reason. A future session that wants one of these should
argue against the reason, not rediscover it.

1. **No fourth pane.** `W1p` asserts exactly three panes and their column lists verbatim
   [ase-ui §5.4]. Sweeps/corners/MC is a dialog (P26).
2. **No modal dialog anywhere.** A `grab set` + `tkwait` would hang the headless suites; the file
   has exactly three modal points and they are all pre-existing [ase-ui §3.2].
3. **No `ttk::notebook`.** It appears nowhere in the entire xschem tree except a comment
   explaining why it was not used; it would need a new theming arm and would break deterministic
   widget paths.
4. **No scrollable form.** No idiom for one exists in `ase_window.tcl`; the computed-row scheme of
   P8 plus a collapsible section is enough for the longest form (`pss`, 8 fields).
5. **No emit-template mini-language.** §12/L3.
6. **No capability probe at startup, and none in front of the dialog.** Nine of twelve analyses
   are unconditional; probing them would inherit issues 0953/0958/0959 for no information (P4).
7. **No state schema version bump, no new top-level key, no rewrite of any committed `.state`
   file.** P3.
8. **No user-facing control over analysis order.** The table carries `order`; `op`-last is
   measured and pinned; a reorder control would invite exactly the regression 0964 fixed
   (P11, §12/L6).
9. **No round-tripping analysis settings through ngspice.** OP has zero parameters and nothing
   about a DC or OP job can be read back [F12]; the GUI is the sole authoritative store and
   re-emits. Any "read the settings back from the simulator" feature is refused.
10. **No dot-card analyses, and no `-r`.** P11, [I7], and the two-`.sens`-cards SIGABRT.
11. **No offering of dead knobs.** `sens2` and `hb` do not exist [F1]; `ramptime` is not a supply
    ramp [C2]; `nosavecurrents` does not exist in this tree [crit §1.2]; `newtrunc`/`lte*` need
    `PREDICTOR`; `defas` and `klu_memgrow_factor` are broken; `itl1/itl2/itl4` below 100 are inert
    [C1]. Each gets a tombstone in the catalogue so it is not re-added from the manual.
12. **No PSS form until someone builds and runs it.** R11.
13. **No claim that transient noise is reproducible.** White and 1/f are seeded from `getpid()`
    and respond to no seed control [F16]; the panel says so in one sentence.
14. **No scalar invented for a waveform.** Decision C. Transient-only stays blank in the Value
    column until the user rules otherwise, as it is today.
15. **No analysis capability delivered by putting anything on the schematic.** The founding
    doctrine [F13]. The two places this bites are transient noise (solved with `alter` or a
    generated parallel source) and `sp` ports (which must be an ASE-L-owned assignment emitted
    into the SP netlist variant, never symbol properties on the user's schematic).
16. **No promise of "stop and keep what you have".** [F9].
17. **No `libngspice` in this axis.** §13.

---

## 16. Risks

1. **The target file is moving.** `ase_window.tcl` gained ~350 lines between the dossier pass and
   this one and the UX batch is landing into it now. Every stage must re-derive anchors by proc
   name and re-read `doc/claude/ase_l_ux_batch/PLAN.md` + `LEDGER.md` first; stage 5 overlaps that
   batch's Stage F4 directly and should be merged with it rather than raced.
2. **`ase::run_existing` bypasses every refusal in this design.** It runs `<rundir>/<cell>.spice`
   as it stands and never calls `render_deck` [ase-deck §5.1]. So P14's `.save all`, P15's save
   resolution and every precheck are absent on that path — including the two that prevent a
   SIGSEGV. Either the preflight rows must also run against the existing deck text, or the Run
   button must say which protections do not apply. **This is the sharpest hole in the design and
   it is not hypothetical.**
3. **The plot-count predicate can be wrong, and it fails quietly.** An over-count writes a
   previous analysis's plot into the raw a second time under its own name; an under-count loses a
   plot. Mitigation: after a run, compare the raw's `Plotname:` list against the union of the
   descriptors' expectations and warn on a mismatch — the reader that does this already exists
   (`ase::cap_raw_plots`, the probe's own header parser).
4. **`setplot previous` is load-bearing and undocumented.** It is four lines of `vectors.c` [M1].
   If it changes upstream, the fallback is [F6]'s trailing `foreach p $plots` recipe, which is
   analysis-blind and already measured — but adopting it moves every deck golden, so the switch
   is a stage of its own, not a hotfix.
5. **Options and plots are coupled.** `keepopinfo` adds a plot, `sqrnoise` renames two, `ptssum`
   decimates one. So the options surface can silently invalidate the descriptor's plot list. The
   `plots` proc takes `opts` for exactly this reason, and every option that changes a plot set
   must carry `effect` in the catalogue.
6. **The `argv` route moves a pinned golden.** `test_ase_simreg_0931` row D4 pins the command
   word for word, and the probe's own command shape must keep mirroring it [I8].
7. **Stored analysis keys become live input.** The moment stage 3's emitter learns optional
   fields, a key stored in someone's bench starts changing what runs. Measured safe for the 105
   committed states (none carries an extra key) but **not** for user benches elsewhere on disk;
   P2's load-time report is the mitigation and it must name the row and the key.
8. **`help all` truncates.** It matched the `#ifdef` set exactly on this build, but the loop stops
   at the first NULL `co_func` [crit §3.2]. Used only for analysis verbs, with the caveat in the
   comment; a build with a relocated help database could answer differently, and the secondary
   signal (`devhelp` for RFSPICE's `portnum`) is what the code should cross-check `sp` against.
9. **Twelve analyses means twelve label batches.** §12/L12. If the rulings are not batched per
   stage the user is asked a dozen times, which is exactly what the standing preference forbids.

---

## 17. Acceptance, per stage

Whatever else changes, these are the checks that say the collapse worked:

* `tests/headless/test_ase_core.tcl` D1 and `test_ase_final*.tcl` deck goldens **byte-identical**
  through stage 2, and after that changed only by lines a new field or a new analysis put there.
* Row **E12** (renders byte-identically with no in-`.control` device requests) green at every
  stage.
* `W1p` (three panes, the three column lists, four seeded rows numbered 1-4) green until R10 says
  otherwise.
* `G1/G2/GE4/GE5` green: the dialog still opens from menu, strip and double-click, and
  `$top.chana.types.tran` and `$top.chana.step` still resolve **by path**.
* The five load→save byte-identity rows (F3/G3/R4/V4/R2) green, and `test_ase_core.tcl:191`'s
  `lsort` of `schema_keys` untouched.
* A state carrying an undeclared analysis type **refuses**, at both doors, with the type named.
* A `noise` row produces **two** `Plotname:` entries in the raw, and a `noise` row whose start
  equals its stop produces **one**.
* `T1` at zero counted failures — a standing red is a defect, not furniture (xschem `CLAUDE.md`).

---

*Written 2026-09-09 against ngspice `ngspice-46-419-gccebdf2a2` and xschem-claude `4ddc4900`.
Six measurement decks in `workpad/scratch/`. No file in either repository was modified.*
