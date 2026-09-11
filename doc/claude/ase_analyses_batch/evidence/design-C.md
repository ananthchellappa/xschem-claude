# Design C — the analysis surface as a compiler with a visible IR

Reader: the future Claude Code session that implements ASE-L's analysis surface.
Scope: ANALYSIS only. No design change is made by this document.

Trees, both read-only to this pass:
`/home/analog/dev/ngspice` @ `ver_50`, `ngspice-46-419-gccebdf2a2`;
binary `/home/analog/dev/ngspice/build-ver_50/src/ngspice`.
`/home/analog/dev/xschem-claude` @ `fluid-editing`, **dirty and moving** — every citation
below names a proc or a section, never a bare line number.

Evidence base: `workpad/dossiers/00-critique.md` first, then the seventeen siblings.
Facts **F1–F16** from the brief are cited by number and not restated.
`MEASURED-C` marks something I ran myself this session; the decks are in
`/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/probe-C/`.

---

## 0. The five things I measured myself, because the design turns on them

| # | claim | how | why the design needs it |
|---|---|---|---|
| M1 | `foreach p $plots / setplot $p / echo "$p\|$curplotname" >> idx / write raw all / end` captures **every** plot in one rawfile **and** writes a machine-readable plot→analysis index from inside the deck | `probe-C/v2.cir`, `c2.cir` — 5 plots (`const op1 ac1 noise1 noise2`), `idx.txt` = `const\|constants`, `ac1\|AC Analysis`, `tran1\|Transient Analysis` | F6 reconfirmed, and the sidecar index is new: it turns the raw into a labelled result set with no counter guessing |
| M2 | `setplot <op plot>` + `write <file> all` **does** capture device vectors requested by a `save` command — `@m1[gm]`, `i(@m1[id])`, `v(@m1[vdsat])` all present | `probe-C/v8.cir` | this is what makes decision C8 (terminal capture) possible at all. ⚠ It does **not** test the op-tier **bare-name** form; see risk RK1 |
| M3 | `$plots` is **oldest-first**, so the rawfile's plot order is creation order | `probe-C/v2.cir`, agrees with `orchestration.md` §2.3 | the sidecar index lines and the `Plotname:` records are in the same order — the reader can join them positionally |
| M4 | A **stale** deck-level `.save v(oldname)` + `disto` segfaults (rc 139); a **resolving** `.save v(out)` + `disto` is rc 0 | `probe-C/v6.cir` (rc 0) vs `v7.cir` (rc 139); `v3.cir`/`v5.cir` reconfirm F7 | narrows F7's rule. The trigger is not "a narrowed save", it is "a save that resolves to nothing". That makes `ase::netlist_map_resolve` a **crash guard**, not a nicety |
| M5 | `.param rl = 'var(ase_rload)'` + `set ase_rload=4700` in a run-directory `.spiceinit` yields `@r1[resistance] = 4.700000e+03` | `probe-C/v1.cir` | F15's injection channel works. **And** SOURCE-HERE `src/main.c:1264-1300`: the `.spiceinit` search is *netlist directory first*, then `$SPICE_USERINIT_DIR`, then cwd, then `$HOME` — **first hit wins and stops**. A generated `.spiceinit` beside the deck silently **shadows the user's entire `~/.spiceinit`** |

One more, measured end to end because it is the deliverable of §9:
a generated four-point parameter campaign (`probe-C/camp.cir`) ran `alterparam`+`reset`+`save`+`ac`+`meas`
per point, produced `bw3` = 3.183e5 / 1.592e5 / 7.958e4 / 3.979e4 (exactly `1/(2πRC)`), and the
terminal capture wrote all four `AC Analysis` plots plus the named collector into one rawfile.

---

## 1. Thesis

### 1.1 The claim

**ADE-L's Choosing Analyses dialog is a list of simulator verbs, and a designer does not think
in verbs.** They think "what is my phase margin", "does it start up at the slow corner",
"how much does mismatch cost me", "why won't it converge". Parity with that dialog is parity
with a 1993 abstraction; it is a bar worth clearing on the way past, not a target.

But the fashionable answer — a wizard that hides the verbs — is worse, and this codebase has
already proved why. ASE-L's `chana_options` collects settings that never reach the deck
(F3), and the tree's own comment on that class of bug is the right one: *"under-emission in
silence is the exact failure class this whole feature exists to delete"* (`ase.tcl`, the
op-tier block). **A layer that decides things the user cannot see is the same defect with a
nicer skin.**

So:

> **The analysis surface is a compiler. Intents are the front end, the `analyses` list is the
> intermediate representation, `render_deck` is the back end, and the IR is on screen at all
> times.** An intent never runs anything; it *writes rows*. Every row it writes is visible in
> the Analyses pane, editable in the Choose Analyses dialog, and stored in the `.state` file.
> Delete the intent and the rows remain and still run.

That single rule is what lets this design be ambitious without lying. It also makes the
ambitious layer *cheap*: an intent is a template over a registry that has to exist anyway.

### 1.2 The three layers

```
   ┌────────────────────────────────────────────────────────────────┐
   │ MEASUREMENTS pane  (new, optional, Stage 8)                    │  front end
   │   "Loop gain & phase margin"  "Noise & contributors"           │
   │   "Corners"  "Mismatch"  "Startup"  "Why won't it converge"    │
   └───────────────────────────┬────────────────────────────────────┘
                               │ expands to, once, visibly
   ┌───────────────────────────▼────────────────────────────────────┐
   │ THE IR — state keys `analyses` + `options` + `sweep` + outputs  │  IR
   │   rows shown in the Analyses pane, edited in Choose Analyses    │
   └───────────────────────────┬────────────────────────────────────┘
                               │ ase::analysis_types registry
   ┌───────────────────────────▼────────────────────────────────────┐
   │ render_deck / run_cmd / .spiceinit / -D      → ngspice          │  back end
   └────────────────────────────────────────────────────────────────┘
```

The middle layer already exists and is nearly the right shape (`ase-state.md` §9.2: *"Keep
`analyses` exactly where it is"*). The work is (a) making the back end registry-driven and
honest, (b) making the IR expressive enough to hold all twelve analyses and a campaign, and
only then (c) adding the front end.

### 1.3 The argument against the two safer designs

**Safer design A — "just add the eight missing types to the four hardcoded lists."**
It is the smallest change and it is what the FINDINGS entry `no-noise-analysis-and-silent-drop`
literally proposes. I reject it as the *shape*, though I keep it as Stage 0's content, because
seven hand-maintained tables that fail silently when they disagree (`ase-ui.md` §2.10) have
*already* drifted once: `anaargs` advertises `ac.dec` and the emitter hardwires `dec`
(`ase-state.md` §3.1). Twelve types × seven sites is eighty-four opportunities for the same
drift, and every one of them fails without a message.

**Safer design B — "make the dialog perfect, stop there."**
This is real ADE-L parity and it leaves the biggest wins on the floor. ngspice's genuinely
distinctive material is not in the analysis cards at all: it is `CKTncDump`'s starred
non-converging nodes (F14 #1), the four-rung ladder with `optran` armed by default and
invisible (F11), `.sens` with glob filters (ADE-L has no sensitivity analysis at all), and
transient noise (F16 — ADE-L has no such feature). A dialog-only design cannot reach any of
them, and it still leaves F10's hole: ngspice has no `.step` and no corners, so **the GUI is
already obliged to be a code generator**. Being a good one is not scope creep; it is the job.

**What my ambition costs, stated up front:** one changed deck invariant (I3, decision C8), one
new file in the run directory with a shadowing hazard (C12), a new results surface, and ten
rulings. Section 12 lists them; section 13 lists what I refuse in exchange.

---

## 2. Decisions

Numbered so a suite row, a commit message and a receipt can cite them. Each is one line of
decision and one of reason. None contradicts decisions **A–N** of `ase-conventions.md` §5.6.

| # | decision | reason |
|---|---|---|
| **C1** | **Analyses rows are the only thing that runs.** Any higher-level surface (intent, campaign, remedy) expands into rows, options and a `sweep` spec *before* the run, and the expansion is visible in the pane. | F3's defect is the window reporting settings that are not in force. A hidden layer reintroduces it at a larger scale. |
| **C2** | **One declarative registry, `ase::analysis_types`, in `ase.tcl`.** The radio row, the form, `anaargs`, the Arguments column, the emit arm, `plot_sim_type`, the capability gate and the validation all *read* it. | `ase-ui.md` §2.10's seven sites, each failing silently. `ase.tcl` must stay Tk-free (`ase-state.md` §9.1 #5), so the registry lives there and only its rendering in `ase_window.tcl`. |
| **C3** | **The silent drop dies first, alone.** A `default` arm in the emit loop that refuses by name, shipped before the vocabulary grows. | F2. One rebuild, zero rulings, converts the worst failure mode in the area (a run that completes and produces nothing while the pane shows the analysis enabled) into a refusal. `ase-conventions.md` §9.3 reaches the same conclusion independently. |
| **C4** | **The offered set = registry ∩ capability, and an unavailable analysis is SHOWN DISABLED WITH A REASON, never hidden.** | Hiding makes ASE-L look like it lacks the feature; the user then cannot tell "ngspice can't" from "ASE-L can't". F4's contract already says a missing key means *not measured*, never *no*. |
| **C5** | **The analysis-availability probe is one more redirect in the EXISTING capabilities deck — no new run** — and the type list reads the free peek `ase::sim_caps_have`. A `Detect` button is the only door to a cold measurement. | Issues 0953/0958/0959: the probe is already paid inside the user's Run gesture, on every press, and its bound evaporates without `timeout(1)`. Adding a startup probe inherits all three. `ase-deck.md` §6.4 rule 5 says the same: do not add a fourth `cap_run` if one deck can carry both redirects. |
| **C6** | **One producer for the deck line and the Arguments column** — the `analysis_line` hook of `ase_l_ux_batch/PLAN.md` Stage F1, fed by the registry. | The `ac.dec` lie exists precisely because there are two producers. If the column and the deck cannot disagree, the window cannot lie. |
| **C7** | **Analyses are `.control` commands, one at a time.** Dot cards only for things with no command form (`.ic`, `.nodeset`, `.probe`, `.lib`, `.param`, `.options`, `.temp`, `.save`). | Agreed with the critique §5.5, and there are five independent reasons, not one: a bare `run` dispatches the whole `analInfo[]` table in registry order not deck order (critique §5.5), `.op`/`.tf` cards starve later analyses' save scope (F7's table), `-b` double-runs, **two `.sens` CARDS abort with rc 134 while two `sens` COMMANDS are fine** (F8/D5), and the DISTO SIGSEGV is reachable from the card route with no `.save` at all (M4, `probe-C/v5.cir`). |
| **C8** | **Capture becomes one terminal `foreach $plots` sweep plus a deck-written sidecar index; the per-analysis `write` is retired.** | I3's invariant assumes one analysis ⇒ one plot and that is false for NOISE and DISTO (`ase-deck.md` §7.4) and for every `keepopinfo` extra. M1 proves the loop is analysis-blind; M2 proves the op plot's device vectors survive it; M3 makes the index joinable. ⚠ This is the one invariant this design changes — see RK1 and ruling R5. |
| **C9** | **The `sim_status` guard and `remzerovec` stay after EVERY analysis, and `op` stays last.** | Decisions **A**, **D**, **E**. Measured: one guard at the end gave rc=0 and a 2198-byte raw with the failure completely masked. The op-last rule is worth 74.9 MB. Neither generalises; both are kept as explicit special cases in the registry, not folded into a sort key. |
| **C10** | **A list of decks the GUI must REFUSE to generate**, enforced in `render_deck` and pre-flighted in the dialog. §7.4. | F7, F8 and M4 are simulator crashes and silent wrong answers. The GUI is the only validator in the system (F15). |
| **C11** | **One option catalogue with a `class` (CP type) and a `door`, and ONE emitter** `ase::opt_emit` that turns (row, value) into text. | F15's four silent-failure traps are *type* errors. Encode them in a function, not in documentation: a `CP_BOOL` physically cannot acquire an `=1` if the only code path that can emit it is `class`-driven. |
| **C12** | **Pre-deck options are delivered by `-D name` / `-D name=string` for `CP_BOOL`/`CP_STRING`, and by a generated `.spiceinit` in the run directory for `CP_NUM`/`CP_REAL`/`CP_LIST` — and that generated file must chain the user's.** | F15 §3.3. M5: the search order makes the generated file shadow `~/.spiceinit` completely. |
| **C13** | **Convergence is a remedy panel with ONE model of the four rungs; it emits `optran` OR `.options`, never both.** | F11 + `convergence.md` §7.7: `optran`'s first three arguments *override* `.options noopiter/gminsteps/srcsteps` on the same task. Two models means the panel lies about which one won. |
| **C14** | **Non-scalar answers never enter the Outputs "Value" column.** Every registry entry names a `result` destination. | Decisions **B** and **C**. `result_probe` accepts `<expr> = <number>` and nothing else. |
| **C15** | **Sweeps, corners and Monte Carlo are a generated `.control` campaign, held in a new `sweep` state key. The primitive is `alterparam <name> = <v>` + `reset` over ASE-L's OWN `.param` variables.** `var()` + `.spiceinit` (F15) is the fallback for values ASE-L did not render — a number baked into a subcircuit or a `.lib`. | F10 leaves no choice about generating. But ASE-L *already* renders `.param <name>=<value>` from its `variables` state key, so the cheap, in-deck, no-extra-file mechanism covers the common case. Reserve F15's new channel for the case only it solves. |
| **C16** | **An analysis row may carry an optional `id`.** Absent ⇒ today's first-of-type addressing, unchanged. | `chana_row` returns *the FIRST state row of type*, so a second `dc` sweep is emittable but not editable (`ase-state.md` §3.3). `id` is additive, absent on all 105 committed files, and costs no schema key. |
| **C17** | **No top-level schema key is added except `sweep`, which joins `ase::omit_if_empty`; `version` stays 1.** | F13: 105 committed `.state` files, five byte-identity test rows, and `dict merge` is per top-level key. An `omit_if_empty` key changes no existing file's bytes. |

---

## 3. S1 — where the type list comes from

### 3.1 Both, with a precedence

The registry is the **vocabulary** (what an analysis is called, what fields it has, how it
emits). The probe is the **availability filter** (what this binary has). Neither can substitute
for the other: the probe cannot tell you PSS's parameter list, and the registry cannot tell
you that this build was configured `--disable-sp`.

```
offered(type) = registry(type) AND cap_verdict(type)

cap_verdict:
  caps known 0                       -> UNVERIFIED : offer, badge "not checked"
  known 1, type in analyses_available -> AVAILABLE : offer
  known 1, type absent                -> ABSENT    : show, DISABLED, with the reason sentence
```

The three states are the point. `known 0` is not `no` — F4's standing contract, stated three
times in `ase.tcl`. Today's dialogs already ask the free peek first and put a **Detect** button
in front of the expensive case (`ase::sim_caps_have`, and `simdlg_case_show`'s live combobox is
the rendering precedent).

### 3.2 The probe leg — one redirect, no new run

`ase-deck.md` §6.4 already drafted `analyses_available` / `devices_available` from
`help all > probe_d.txt` + `devhelp > probe_e.txt` in one deck. **Change one thing:** F5 and
critique §3.2 establish that `help all` truncates at the first NULL `co_func` — it stops at the
control-flow keywords and omits everything from `cdump` onward. It happens to list every
analysis verb because they sit before the NULL block, but the reasoning is wrong and a future
ngspice reorder breaks it silently.

Use the per-verb loop instead, which walks the whole table (`com_help.c:84`):

```
* capability deck A, existing circuit, two extra redirects
.control
  op
  ...existing probe A body...
  help ac    > probe_an.txt
  help dc    >> probe_an.txt
  help op    >> probe_an.txt
  help tran  >> probe_an.txt
  help noise >> probe_an.txt
  help tf    >> probe_an.txt
  help pz    >> probe_an.txt
  help sens  >> probe_an.txt
  help disto >> probe_an.txt
  help sp    >> probe_an.txt
  help pss   >> probe_an.txt
  devhelp    > probe_dev.txt
.endc
```

`Sorry, no help for pss.` is the absence signal (F5, measured). Twelve lines, one existing run,
file-based verdicts — which is the doctrine (`ase-deck.md` §6.2: *"NOT ONE VERDICT COMES FROM
THE EXIT CODE OR THE LOG"*). The verdict proc is its own proc so a suite can drive it without a
simulator (`ase::cap_altshow_verdict` is the precedent).

Published keys, following the missing-key-means-unmeasured contract:

```tcl
analyses_available  {ac dc disto noise op pz sens sp tf tran}   ; from probe_an.txt
devices_available   {... d_cosim adc_bridge numd nbjt ...}      ; from probe_dev.txt
rfports             0|1                                          ; devhelp vsource | grep portnum
```

`rfports` is the second, independent RFSPICE signal (F5) and is worth the extra grep because
`sp`'s absence and `sp`'s uselessness look identical to a user.

### 3.3 The three awkward cases the brief names

**(a) An analysis the binary lacks — PSS.** Shown, disabled, with a sentence that names the
cause and the cure: *"This ngspice was built without PSS support (configure `--enable-pss`)."*
Not hidden (C4). And **no form ships for it in this pass** — see refusal X1: nobody has ever
run PSS (critique §5.7 item 1) and a form for an analysis nobody has executed is a guess
wearing a uniform.

**(b) An analysis that exists but is dangerous — DISTO, SENS+KLU.** Offered normally. The
danger is not in the analysis, it is in the *deck shape*, and it is prevented by construction
(§7.4) plus one pre-flight sentence on the form. Concretely:

- DISTO: the form carries a live note *"Distortion needs at least one saved output that exists
  in this netlist"*, and the emitter refuses a deck where any `save`/`.save` name fails
  `ase::netlist_map_resolve` **while `disto` is enabled** (M4).
- SENS in AC mode: the option catalogue marks `klu` as **incompatible with AC sensitivity**; if
  both are set the run is refused at pre-flight with the reason. DC sensitivity under KLU is
  safe and stays offered (F8/D3, measured both ways).

**(c) An analysis with netlist preconditions — SP, AC, NOISE, SENS.** These are computable
offline from the netlist ASE-L already has, and `ase::preflight_scan` already walks the state
— it just only looks at `outputs` today (`ase-state.md` §3.4). Extend it:

| type | precondition | how it is checked, offline | severity |
|---|---|---|---|
| `sp` | at least one `portnum`-carrying source | scan the netlist for a V source with `portnum=` | **refuse** — measured `Error: No RF Port is present` |
| `ac`, `noise`, `disto`, `sp` | at least one source with an AC value | scan for `ac ` on a V/I line | **refuse** for `noise` (measured `E_NOACINPUT`), **warn** for `ac` (a run with no AC source is legal and returns zeros) |
| `noise` | `input` names a V or I source that has an AC value | netlist map + the same scan | **refuse** (measured) |
| `noise`, `pz`, `tf`, `disto`, `sens` | `output` node exists | `ase::netlist_map_resolve` | **refuse** |
| `sens` | at least one eligible parameter | `devhelp -csv -type -flags` predicate, §5.4 | **warn** — an empty sensitivity is legal and useless |
| `dc` | `source` is a V source, an I source, a resistor, or the literal `temp` | netlist map + type | **refuse** — F10, and `dctrcurv.c:89-151` accepts exactly those four |

"Refuse" means: the Run gesture stops before any artifact is touched, through the existing
`ase::preflight_gate` (defence (a) of decision **I6**), with a sentence naming the analysis, the
field and the fix.

---

## 4. S2 — the registry

### 4.1 Shape

One dict, `ase::analysis_types`, keyed by type. Every value is a dict of exactly these keys.
Missing optional keys mean their documented default, never a guess.

```tcl
# ---------------------------------------------------------------------------
# ase::analysis_types  --  the ONE description of an analysis.
#
# WHY THIS EXISTS. Adding `noise` today means editing seven places, each of
# which fails SILENTLY if missed (state_default's seed, anaargs, chana_fields,
# the radio foreach, chana_show's hardcoded destroy list, anorder + the switch
# arm, plot_sim_type). Seven hand-kept tables have already drifted once: anaargs
# advertises `ac.dec` and render_deck hardwires the literal `dec`. This dict is
# the single source; every one of those sites becomes a reader.
#
# KEYS, all required unless marked optional:
#   label       display noun. A user-facing string -> ratify before minting.
#   verb        the .control command word. NOT the plot name and NOT the
#               registry name -- ngspice has three namespaces for one analysis
#               (outputs.md §3.2): verb `noise`, registry `NOISE`, plot
#               `Noise Spectral Density Curves`.
#   fields      ordered list of field descriptors (§4.2). Order = form order
#               = Arguments-column order. One list, not two.
#   emit        the emit program (§4.3): a token list, or `proc <name>` when
#               the card cannot be expressed positionally.
#   plots       list of {name <Plotname literal> when <predicate>} -- what the
#               run will produce. Drives labelling and the results router.
#   result      where the answer goes (§8). One of: viewer | value | table |
#               annot | none, plus a sub-key.
#   caps        capability token required, or {} for always-present.
#   pre         list of precondition predicates (§3.3).
#   refuse      list of deck-shape refusals this type triggers (§7.4).
#   order       emit-order weight. `op` is pinned last by an explicit rule, NOT
#               by this number -- decision A's reason is about op and does not
#               generalise.
#   sim_type    the string handed to `xschem raw read <file> <type>`, or {}.
# ---------------------------------------------------------------------------
```

### 4.2 A field descriptor

```tcl
# {key <k> label <l> widget <w> unit <u> default <d> required 0|1
#  validate <proc> depends {<key> <value>} help <one line>}
#
#  widget ::= num | si | enum | node | source | device | param | expr | bool
#             | sweepmode
#  si     : a number that may carry an ngspice engineering suffix (1k, 1meg,
#           100n). The GUI PARSES it to validate and to compute readouts, and
#           EMITS IT VERBATIM -- ngspice's own parser is the authority and a
#           round trip through a Tcl double would change 1meg into 1000000.0.
#  depends: this field is shown/emitted only when <key> currently holds <value>.
#           This is what makes `ptspersum` appear only when the contributor
#           table is asked for, and what relabels a sweep-mode neighbour.
```

### 4.3 The emit program

Positional token assembly with **slot dependencies honoured**, because ngspice cards are
positional and a missing optional argument must be *substituted*, never *skipped*
(`ase_l_ux_batch/PLAN.md` Stage F4: "`tmax` without `tstart` must substitute `tstart 0`, not
shift a slot").

```tcl
# emit ::= list of tokens, each one of
#   {lit  <word>}                     a literal
#   {fld  <key>}                      the field's value, verbatim
#   {opt  <key> <substitute>}         the field if present, else <substitute>,
#                                     but ONLY if a later token is present too
#   {tail <key>}                      emit if present, and everything after it
#                                     is suppressed when it is absent
#   {call <proc>}                     escape hatch: proc {row} -> list of words
#
# ONE consumer builds both the deck line and the Arguments summary from this,
# so the column and the deck can never disagree (decision C6).
```

`tran` is the case that needs `opt`: `tran tstep tstop [tstart [tmax]] [uic]`.
`noise` and `sens` need `call`, because `v(out,ref)` is a composition and `sens`'s parameter
filter is a variable-length list.

### 4.4 The hard case, filled in completely: NOISE

Every value below is sourced from `an-smallsig.md` §3 (which is itself sourced from
`nsetparm.c`, `inp2dot.c:18-121` and `noisean.c`) or measured.

```tcl
noise {
  label     {Noise}
  verb      noise
  order     40
  caps      {analysis:noise}
  sim_type  noise

  fields {
    { key output   label {Output node}        widget node   required 1
      help {The node whose noise you want. Pick it on the schematic.}
      validate ase::validate_node }

    { key outputref label {Output ref}        widget node   required 0
      default {} help {Reference node; empty means ground.}
      validate ase::validate_node }

    { key input    label {Input source}       widget source required 1
      help {A V or I source that carries an AC value. Noise is referred to it.}
      validate ase::validate_ac_source }

    { key sweep    label {Sweep type}         widget sweepmode required 1
      default dec  enum {dec {Decade} oct {Octave} lin {Linear}}
      relabels points }

    { key points   label {Points per decade}  widget num    required 1
      default 10   validate ase::validate_pos_int
      help {DEC/OCT: points per decade/octave. LIN: TOTAL points.} }

    { key start    label {Start frequency}    widget si     unit Hz required 1
      validate ase::validate_freq_gt0
      help {Must be > 0. Zero is refused by ngspice with E_PARMVAL.} }

    { key stop     label {Stop frequency}     widget si     unit Hz required 1
      validate ase::validate_freq_gt0 }

    { key contributors label {Per-device contributor table} widget bool
      default 0 required 0
      help {Adds every device's noise vectors. Costs nothing but decimation --
            see `every` below.} }

    { key ptspersum label {Report every N points} widget num default 1
      required 0 depends {contributors 1}
      validate ase::validate_pos_int
      help {ngspice couples the contributor table to spectrum decimation.
            1 = full spectrum AND the table. Larger values throw spectrum rows
            away. Measured: ptspersum=4 over 21 points leaves 6 rows.} }
  }

  emit { {lit noise} {call ase::backend::ngspice::an_noise_probe}
         {fld sweep} {fld points} {fld start} {fld stop}
         {tail ptspersum} }

  plots {
    { name {Noise Spectral Density Curves}        when {always}
      alt  {Noise Spectral Density Curves - (V^2 or A^2)/Hz} when {opt sqrnoise} }
    { name {Integrated Noise}                     when {expr {start ne stop}}
      alt  {Integrated Noise - V^2 or A^2}        when {opt sqrnoise} }
    { name {NOISE Operating Point}                when {opt keepopinfo} }
  }

  result {
    viewer  {plot {Noise Spectral Density Curves} traces {onoise_spectrum inoise_spectrum}}
    value   {plot {Integrated Noise} vectors {onoise_total inoise_total}}
    table   {plot {Integrated Noise} kind contributors when {field contributors 1}}
  }

  pre {
    {ac_source_exists      refuse}
    {node_exists output    refuse}
    {node_exists outputref refuse}
    {source_has_ac input   refuse}
  }

  refuse {
    {lin_two_points sweep points}     ;# see §7.4 R3 -- lin 2 silently gives 1 point
    {unresolvable_save}               ;# shared with disto; cheap insurance
  }
}
```

Two things in that entry are the whole argument for the registry:

* **`ptspersum` is `depends`-gated on a checkbox named for the thing the user wants.** The raw
  parameter is a decimation factor whose side effect is the contributor table
  (`an-smallsig.md` §3.9: every device registers its vectors only when `NStpsSm != 0`). Nobody
  should have to know that. The field the user sees is "Per-device contributor table"; the
  number is secondary and defaults to the only value that costs nothing.
* **`plots` is a list with predicates.** NOISE produces one, two or three plots depending on
  `sqrnoise`, on whether `start == stop`, and on `keepopinfo` — measured, `an-smallsig.md` §3.7:
  *"Verified with a single-frequency noise run: only the spectral plot exists"*. A GUI that
  hard-codes "noise makes two plots" mislabels a spot-noise run.

### 4.5 The second hard case, sketched: SP

```tcl
sp {
  label {S-parameters}  verb sp  order 45  caps {analysis:sp rfports}
  sim_type ac                                   ;# xschem's raw reader maps
                                                ;# `sp analysis` -> ac already
                                                ;# (ase-state.md §7.5)
  fields {
    { key sweep  widget sweepmode default dec enum {dec oct lin} relabels points }
    { key points widget num  required 1 default 10 }
    { key start  widget si unit Hz required 1 validate ase::validate_freq_gt0 }
    { key stop   widget si unit Hz required 1 }
    { key donoise label {Noise parameters (NF, NFmin, Rn, Sopt)} widget bool default 0 }
  }
  emit   { {lit sp} {fld sweep} {fld points} {fld start} {fld stop} {tail donoise} }
  plots  { { name {SP Analysis} when always }
           { name {AC Operating Point} when {opt keepopinfo} } }
  result { viewer {plot {SP Analysis} mode smith traces {S_1_1 S_2_1}}
           table  {plot {SP Analysis} kind smatrix} }
  pre    { {rf_port_exists refuse} }
  refuse { {lin_two_points sweep points} }   ;# span.c has AC's numsteps<=2 bug too
}
```

Note `caps {analysis:sp rfports}` — **two** tokens. The `sp` command existing does not mean the
build has RF ports; both are measured separately (F5) and both are required.

### 4.6 What the seven sites become

| old site | becomes |
|---|---|
| `ase::state_default`'s four-row seed | unchanged. It is a *seed*, not a derivation (ruling R1). |
| `ase::ui::anaargs` | `[dict keys [dict get $reg $type fields]]` |
| `ase::ui::chana_fields` | the same list filtered by `depends` |
| the radio `foreach t {op dc ac tran}` | `[ase::analysis_offered $state]`, grid-wrapped |
| `chana_show`'s **hardcoded five-name destroy list** | destroy every child created by the previous `fields` list — the registry knows the names. This is `ase-ui.md` §2.5's *"single sharpest trap in the analysis code"* and the registry deletes it structurally. |
| `anorder` + the `switch` | sort by `order`, with `op`-last as an explicit named exception, and `[dict get $entry emit]` dispatch with a loud `default` |
| `ase::plot_sim_type` | reads `sim_type`; a type with `{}` yields `{}` as today |

---

## 5. S3 — the form

### 5.1 Field types, and what each one buys

| widget | behaviour | precedent in the tree |
|---|---|---|
| `si` | accepts `1k`, `100n`, `1meg`, `1.5e3`; parses to validate and to compute a live readout; **emits the user's text verbatim** | `ase::format_value` / decision **N** is display-only for the same reason |
| `num` | integer, with the registry's `validate` | `-validate key` idiom exists in `simdlg_editor` |
| `enum` | readonly `ttk::combobox` | `simdlg_case_show`'s live `-values` |
| `sweepmode` | an enum that **relabels its neighbour** via `$w.l<ename> configure -text` | `dialog_row` returns `$w.$ename` and creates `$w.l$ename`, so the relabel is a one-liner |
| `node` | entry + a **Pick** button that arms `select_on_design` | already hierarchy-aware (`sod_qualify`) and bus-aware (`bus_dialog`) — built for Outputs, pointed at a form field |
| `source` | combobox filled from the netlist's V/I sources, + Pick | same click machinery; ADE-L makes you type this |
| `device` | combobox from the netlist instance map | |
| `param` | the offline parameter picker of §5.4 | new |
| `expr` | free text, but validated against the netlist before OK | `ase::netlist_map_resolve`, currently unused |
| `bool` | checkbutton | |

**The `si` rule is load-bearing.** ngspice's own parser understands `1meg`; Tcl's does not, and
`1meg` is not `1e6` to a `.state` file that must round-trip byte-stable. So: parse for the human,
emit for the machine, store what the human typed.

### 5.2 Sweep-mode relabelling, concretely

```
AC / NOISE / SP:   Sweep type [Decade ▾]  ->  neighbour label "Points per decade"
                                Octave    ->                  "Points per octave"
                                Linear    ->                  "Total number of points"
                                          and a live readout: "= 61 points, 1 Hz … 1 MHz"

DC:                Sweep type [Linear ▾]  (ngspice has no log .dc)
                   Step size [10m]        + readout "= 181 points"
                   or Number of steps     (GUI computes step; ngspice is told step)

AC / SP range:     [Start–Stop ▾] / [Centre–Span]   -- Centre–Span is computed in
                   the GUI; ngspice only ever sees start and stop.
```

The "Total number of points" label for `lin` is not cosmetic: it is the only place a user can
learn that `points` means something different in each mode, and it is where the **`lin 2` trap**
(F8/D2 — `ac lin 2 f1 f2` silently yields ONE point) is caught, by refusing 2 with the sentence
*"ngspice produces a single point for a linear sweep of 2; use 3 or more."*

### 5.3 Where a refusal appears

Today it goes to the CIW while the dialog sits there with no visible change
(`chana_ok`, and FINDINGS `refusals-appear-in-a-different-window`). Fix, in three parts:

1. `ase::ui::dialog_status $w <msg>` — a status line at a **fixed high grid row**. The dialog
   already reserves rows 8 and 9 for exactly this reason, and `rsel_status` is the pattern to
   generalise.
2. The offending **field** is marked (background + focus), because with twelve types and up to
   nine fields "some field is empty" is not a diagnosis.
3. `ase::echo … error` is still called, unchanged, for the action log and for headless callers.

No new sentences are minted for the existing refusals — they exist. New sentences (the
precondition refusals of §3.3, the `lin 2` refusal, the option-class refusals) are on the
ratification list (ruling R6).

### 5.4 The parameter picker — computed offline, no run

`.sens` on a three-device deck yields ~90 vectors (`an-smallsig.md` §7.4). The picker predicts
that list without running anything, using the critique §5.6 predicate:

```
devhelp -csv -type -flags <device>   ->  id#, Name, Dir, Type, Flags, Description
eligible  :=  Dir == inout  AND  Type == real
              AND flags contain neither X (IF_NONSENSE) nor R (IF_REDUNDANT)
              AND (mode == ac  OR  flags contain neither A nor AA)
```

Rendered as a checkbox tree grouped by instance, whose selection compiles to `.sens`'s **glob
filter** (`sens v(out) r*:r m*:vth0 ac dec 10 1k 1meg`). This is a strict ADE-L beater: ADE-L
has no sensitivity analysis at all.

⚠ The picker's own trap: two `.sens` **cards** abort with rc 134 (F8/D5). We emit commands
(C7), so this is dodged — and the registry records it in `refuse` so a future dot-card path
cannot reintroduce it.

### 5.5 ADE-L's fifteen behaviours — adopt / improve / refuse

Numbered as in `ase-ui.md` §6.

| # | verdict | note |
|---|---|---|
| 1 type row | **improve** | grid-wrapped so twelve types fit; **the widget paths `$top.chana.types.<t>` are preserved** because `test_ase_dialogs.tcl` G1/G2/GE4 drive them by path and adding siblings is safe |
| 2 form swaps in place | **adopt**, fixed | the hardcoded destroy list dies with the registry (§4.6) |
| 3 Enable on the form | adopt | unchanged |
| 4 Enabled column | **improve** | today a text glyph: no keyboard reach, no undo, and a stray click in a 63 px column silently edits the deck |
| 5 sweep mode + relabel | **improve** | §5.2, plus a live point-count readout ADE-L does not have |
| 6 Options… | **improve, and this is the correctness item** | §6 |
| 7 Apply | adopt | third button; moves `dialog_buttons`' geometry, GE4 reads the bar |
| 8 form memory across type switches | **adopt, needs ruling R2** | reverses recorded decision D4. With four types the discard rule is defensible; with twelve it is a trap |
| 9 several analyses of one type | **adopt via `id`** (C16) | "a DC sweep of VIN and one of temperature" is a real bench and is unsayable today |
| 10 list starts empty | **refuse** | ruling R1: 105 committed files and `test_ase_core.tcl` R1 pin the four-row seed. The gain is cosmetic; the cost is every golden |
| 11 field-level refusal | **adopt** | §5.3 |
| 12 typed fields | **adopt** | §5.1 — and it is what makes #6 safe |
| 13 pick from the design | **adopt** | the cheapest genuine beater; the machinery is built |
| 14 run in list order | **refuse** | decision **A**'s op-last rule is worth 74.9 MB and is not reorderable by taste. Instead: **show** the computed order, with the reason, in the pane |
| 15 setup travels with the cellview | already better | `.state` views, multiple states per cell |

---

## 6. S4 — the options surface

### 6.1 First, stop lying

`chana_options` collects free-text name/value pairs that never reach the deck (F3). Across 105
committed states and 420 analysis rows, not one carries an extra key — so **nothing breaks if
we fix it, and everything breaks the first time someone uses it.** Two honest outcomes, and the
choice is a ruling (R7-adjacent, folded into R3):

* **Recommended:** the extra-key editor becomes the *optional-field* editor. Its universe is
  `[registry fields] − [quick fields]` for this type, typed and validated, and it emits.
  Anything the emitter cannot place is **refused at OK**, not stored — Stage F4's rule.
* Fallback if that is too much for one stage: the dialog is retitled and carries one sentence
  saying the keys are recorded but not emitted. Worse, but not a lie.

⚠ The migration hazard, stated because it is easy to miss: the moment the emitter learns to
emit tail keys, any key already stored in those 105 files becomes **live simulator input**
(`ase_l_ux_batch/PLAN.md` R-16). Mitigation: emit only keys the registry knows; carry the rest
forward untouched and show them in the Arguments column marked as inert.

### 6.2 Two catalogues, one model

| | OPTtbl | `cp_getvar` |
|---|---|---|
| count | ~86 keywords | **163 variables, disjoint** (F15) |
| door | `.options <name>[=<v>]` | `set` / `.options` / `-D` / `.spiceinit`, per variable |
| scoping | per task | global, and `set` **shadows** `.options` |
| 26 of them | — | **unreachable from `.options` entirely** |

One catalogue row covers both:

```tcl
# ase::opt_catalogue -- one row per option, both catalogues.
#
#   name      the spelling ngspice reads
#   family    tolerance | iteration | timestep | convergence | device
#             | temperature | solver | output | diagnostic | netlist | inert
#   class     opt      -- an OPTtbl keyword, emitted as `.options name[=v]`
#             bool     -- CP_BOOL   : bare `set name`. `=1` KILLS IT.
#             num      -- CP_NUM    : `set name=<int>`. Bare KILLS IT.
#             real     -- CP_REAL   : `set name=<real>`
#             string   -- CP_STRING : `set name=<word>`
#             list     -- CP_LIST   : `set name=( a b c )`
#   door      deck     -- `.options` above .control
#             ctl      -- `set` inside .control
#             predeck  -- MUST be emitted before the deck is read (F15 §3.2)
#   scope     global | per-analysis
#   results   0|1      -- does it change numbers? (drives the "results-affecting"
#                         badge and the run-report line)
#   inert     {}       -- or the reason it does nothing in THIS build
#   default   the value when absent
#   blurb     one line, the user's
#
# THE POINT OF `class`: it is the only defence against F15's four silent
# failures, and they are all TYPE errors --
#   `set sqrnoise=1`  is SILENTLY OFF   (CP_BOOL cannot answer a =value)
#   `set warn`        is SILENTLY OFF   (CP_BOOL cannot answer a CP_NUM read)
#   `-D warn=1`       is SILENTLY OFF   (-D is ALWAYS a string)
#   `set x=0x10`      is SILENTLY 0
# so ONE emitter, ase::opt_emit {row value}, owns every spelling and no caller
# ever builds an option string by hand.
```

```tcl
proc ase::opt_emit {row value} {
  set n [dict get $row name]
  switch -- [dict get $row class] {
    opt    { if {$value eq {} || $value eq {1}} { return ".options $n" }
             if {$value eq {0}} { return {} }
             return ".options $n=$value" }
    bool   { if {[string is false -strict $value]} { return {} }
             return "set $n" }                    ;# never, ever `set $n=1`
    num    { if {![string is entier -strict $value]} {
               return -code error "ase: option '$n' takes an integer" }
             return "set $n=$value" }
    real   { return "set $n=$value" }
    string { return "set $n=$value" }
    list   { return "set $n=( [join $value { }] )" }
  }
}
```

That proc is testable without a simulator, which is how the four traps become five suite rows.

### 6.3 Finding one option among 250 without a wall of fields

The dialog is **search-first and difference-first**:

```
 ┌ Simulator options ─────────────────────────────────────────────────────┐
 │ Search [ gmin▏                    ]   ☑ Only show what I changed        │
 │ Family  [All ▾]  Scope [All ▾]                                          │
 │ ────────────────────────────────────────────────────────────────────── │
 │  name        value        default   scope    what it changes            │
 │  gmin        1e-10        1e-12     global   ⚠ conductance added to     │
 │                                              every node                 │
 │  gminsteps   10           10        global     rung 2 of the OP ladder  │
 │  ────────────────────────────────────────────────────────────────────  │
 │  ⚠ 3 options differ from ngspice defaults.  [Reset all]                 │
 └────────────────────────────────────────────────────────────────────────┘
```

Rules:

1. **Difference-first is the default view.** With 250 options, "what have I changed" is the
   only question a user actually asks, and it is the one ADE-L answers badly.
2. **⚠ marks `results 1`.** A user must be able to see, in one glance, which of their settings
   can change a number. 21 of the 163 do (F15 group R) and 11 decide whether output appears at
   all (group G).
3. **Family is the coarse filter**, not an accordion of every option — `tolerance`,
   `iteration`, `timestep`, `convergence`, `device`, `temperature`, `solver`, `output`,
   `diagnostic`, `netlist`.
4. **`inert` options are not in the list at all**, except by explicit search, where they appear
   greyed with their reason. The do-not-offer list is F15 §7.11 plus F8: `itl1/itl2/itl4` below
   100 (floored in `niiter.c:37-39` — the *shipped defaults 50 and 10 are inert*), `itl3`/`itl5`
   (empty `case` arms), `ramptime` (live code behind `XSPICE_EXP`, defined nowhere),
   `oldlimit` on the `.control` route (`TSKfixLimit` never copied, `cktntask.c:68`),
   `klu_memgrow_factor`, `newtrunc` (needs `PREDICTOR`), `scalm`, `debug`, `x11lineararcs`, and
   `nosavecurrents` **which does not exist in this tree at all** despite the manual.
5. **`itl1/itl2/itl4` are clamped, with the reason shown.** Typing 50 gets you
   *"ngspice raises any iteration limit below 100 to 100 (`niiter.c:37`). Using 100."*
6. **Global vs per-analysis.** `.options` is per-task, so in principle per-analysis; but ASE-L
   emits one `.control` block and the options sit above it, so in *practice* every `.options`
   line applies to every analysis. Say so: the Scope column reads `global` for everything
   emitted above `.control`, and `per-analysis` only for the handful the registry emits inside
   the loop (today: none; after §7.3: `sqrnoise` and `keepopinfo`, both of which are `set`
   variables and therefore genuinely per-position). **Do not offer a per-analysis control that
   is physically global** — that is F3's defect in a new costume.

### 6.4 Pre-deck options — the delivery a GUI cannot fake

26 variables are read before `inp_dodeck` builds `ci_vars` (`inp.c:1376`), so `.options x` and
a `.control set x` both do **nothing, silently** (F15 §3). Delivery, by class:

| class | door | mechanism |
|---|---|---|
| `bool` | `-D name` | appended to `run_cmd`, **after** the registry args and **before** the deck path, preserving I8's word order |
| `string` | `-D name=value` | same |
| `num`, `real`, `list` | **generated `.spiceinit` in the run directory** | the only route short of `-p` pipe mode |

Which options actually need the file? From F15 §3.2: `wnflag`, the ten `ps_*`, `sourcepath`,
`scale`, and **any name used as `var(<name>)`**. For an analog user that is essentially *only*
`var()` injection — i.e. the file exists for the campaign generator of §9 and almost nothing else.
That is a good reason to make it conditional: **no campaign, no file.**

⚠ **The shadowing hazard, and it is the sharpest new finding of this design.** M5:
`src/main.c:1264-1300` searches for `.spiceinit` in *the netlist's own directory first*, then
`$SPICE_USERINIT_DIR`, then cwd, then `$HOME` — **first hit wins and the search stops**. ASE-L
writes its deck into the run directory and runs from there, so a generated `.spiceinit`
silently replaces the user's `~/.spiceinit` in its entirety — including any `codemodel` or
`osdi` lines, `ngbehavior`, `sourcepath`, everything. Mitigation, and it needs ruling R4:

```
* ASE-L generated -- do not edit; regenerated on every run
* Chained from the file this one shadows (main.c searches the deck directory FIRST):
source /home/user/.spiceinit
set ase_rload=4700
set ase_cload=1e-12
```

plus a pre-flight notice the first time a user's `~/.spiceinit` is detected and chained.

### 6.5 The convergence surface — a remedy, not a field wall

This is where F11 and F14 #1/#2 pay off, and it is the single most user-visible thing in the
design. Three parts, all driven by parseable output ngspice already emits.

**(a) The strategy panel — one model of four rungs.**

```
 ┌ Operating point strategy ──────────────────────────────────────────────┐
 │ ☑ 1. Direct Newton solve                                               │
 │ ☑ 2. gmin stepping           steps [10 ]                               │
 │ ☑ 3. Source stepping         steps [10 ]                               │
 │ ☑ 4. Transient operating point   step [100n]  settle to [10u]          │
 │      ⓘ On by default in this ngspice, and nobody has ever seen it.     │
 │        The OP it returns is the transient state at 10 µs, not a DC      │
 │        solution: measured 0.9999550 instead of 1.0 on a 1 µs RC.        │
 │                                          [Pick a settle time for me]    │
 │ Emits: optran 1 10 10 100n 10u 0                                        │
 └────────────────────────────────────────────────────────────────────────┘
```

* One line, `optran <opiter> <gminsteps> <srcsteps> <step> <stop> 0`, and **never**
  `.options noopiter/gminsteps/srcsteps` alongside it: `optran`'s first three arguments
  *override* those on the same task (`convergence.md` §7.7). C13.
* **Argument 6 (`opramptime`) is never emitted as anything but 0.** `convergence.md` §7.6 #2:
  the ramp factor `0.5*(1-cos(π·t/ramptime))` has no clamp, so past `ramptime` it keeps
  oscillating and returns to 0 at `2·ramptime`. `README.optran` itself says ramping is "not yet
  established". Refusal X6.
* **"Pick a settle time for me"** implements what `README.optran` *wanted* and `optran.c` has
  `#if 0`-ed out: `100 × tstep` before a transient, `0.1 / fstart` before an AC or noise run.
  Since ngspice does not do it, the GUI does — and says so.
* Emitting `optran` is a **`.control` command**, so it belongs at the head of the block beside
  `pre_commands` and before the first analysis.

**(b) The live ladder pane.** `cktop.c` emits a fixed, parseable state machine on **stderr**
(`convergence.md` §4.3). Render it as four lamps that light in order:

```
   ①  Newton            ✗ failed
   ②  gmin stepping     ⟳  Trying gmin = 1.0000E-03
   ③  source stepping   ·
   ④  transient OP      ·
```

Two parser rules that must be in the implementation from day one, both measured:
`Trying gmin = …` and `Supplies reduced to …%` end **without a newline**, so the next line is
appended to the same physical line; and the ladder is on stderr while `DC solution failed -`,
`CKTncDump` and SOA warnings are on stdout — **two independently buffered streams that arrive
out of order in a `2>&1` capture.** ASE-L merges with `2>@1` today (I8), so either the panel
tolerates interleaving or the run pipeline learns to keep the streams apart. Tolerating is
cheaper and is what I recommend: match on line content, never on order.

**(c) The failing nodes, on the canvas.** After every failed OP, `CKTncDump`
(`cktncdump.c:10-43`) prints a `Last Node Voltages` table to stdout with a trailing ` *` on each
node that still fails the convergence test. `convergence.md` §4.4 calls it *"the single most
useful diagnostic in ngspice"* and nobody has ever proposed a UI for it.

**Parse it, map the names through `ase::netlist_map`, and highlight those nets on the schematic.**
ADE gives you an opaque `sim.log`. This needs no ngspice change, no new probe, and no ruling
beyond the sentence. It is the biggest single win available and it is item 1 of §9.3.

**(d) The remedy ladder.** When the OP fails, the panel offers, in order, with the reason:

| symptom in the log | offered remedy | emits |
|---|---|---|
| `Dynamic gmin stepping failed` and nodes starred | raise `gmin`, or `.nodeset` the starred nodes | `.options gmin=1e-10` / `.nodeset v(n)=…` |
| `Timestep too small` in a transient, with a dangling passive named | `set topo_reduce` — *its console message names the offending element* | pre-deck `set topo_reduce` |
| everything failed | rung 4 with a longer settle time | `optran 1 10 10 <step> <stop> 0` |
| a converged OP you want to keep | **`wrnodev <file>`** then `.include` it as `.ic` | `convergence.md` §1.6: "the closest thing ngspice has to Cadence's save/restore DC solution" |

---

## 7. S5 — the deck

### 7.1 Commands, not cards — and the exception

C7. `.control` commands for every analysis. Cards survive only for what has no command:
`.ic`, `.nodeset`, `.probe`, and everything ASE-L already emits above `.control`
(`.include`, `.lib`, `.param`, `.options`, `.temp`, `.save`). Invariant **I2** governs the
boundary: a dot card inside `.control` is `save: no such command available` at rc 0, and a bare
`save` above it is not a card — both fail silently.

**`-r` stays dead** (I7), re-measured: with a `.control` block and no explicit `write`, `-r`
produces no rawfile at all.

### 7.2 The shape

```
<netlist minus .end>
<injected transient-noise sources>          <- new slot, §9.2
.include / .lib / .param / .options / .temp / .save / op-tier cards   [unchanged]
.control
  <pre_commands>                                                       [unchanged]
  <cosim auto-bridges>                                                 [unchanged]
  <set/setseed option lines, class-emitted>                            <- §6.2
  <optran line, if the convergence panel is non-default>               <- §6.5
  set appendwrite
  setplot new aselres "ASE-L results" aseldata        <- only when a campaign or
                                                        cross-run scalars exist
  <ANALYSIS BLOCK>                                                     <- §7.3
  foreach p $plots                                                     <- §7.5
    setplot $p
    echo "$p|$curplotname" >> <cell>_ase.index
    write <cell>_ase.raw all
  end
  <print lines at the anchor>                                          [unchanged]
.endc
.end
```

### 7.3 One analysis, emitted

Per enabled row, in registry order with `op` pinned last:

```
  <op-tier save commands, only immediately before op>      [decision A, unchanged]
  <the analysis line, from the registry emit program>
  if $?sim_status = 0
    echo NO-SIM-STATUS
  end
  if $sim_status ne 0
    echo RUN-FAILED
    quit 1
  end
  remzerovec
```

and **that is all** — no `write`. Decisions **D** and **E** are preserved exactly: the guard
after every analysis (measured: one guard at the end masks a failure completely and ships a
2198-byte raw at rc 0), and `remzerovec` after every analysis (it is per-plot, so one call at
the end only ever cleans the last).

The guard must still **precede** whatever ships results. Under C8 that is the terminal loop, so
the guard's `quit 1` happens before any `write` — strictly stronger than today, because a
failure now suppresses *every* plot rather than only the failing analysis's.

Per-analysis `set` options (`sqrnoise`, `keepopinfo`) are emitted immediately before their
analysis line and unset immediately after, so a noise row's squared-output choice cannot leak
into a later disto run. **`sqrnoise` is genuinely global while set**, so if two noise rows
disagree the GUI refuses at commit rather than emitting a lie (ruling R7).

### 7.4 Decks the GUI must refuse to generate

Each is a measured crash or a silent wrong answer. Each becomes a `refuse` token in the
registry and a suite row.

| id | refusal | evidence | where enforced |
|---|---|---|---|
| **R1** | **`disto` enabled AND any `save`/`.save` name does not resolve in the netlist** | F7 + **M4**: stale `.save v(oldname)` + disto = rc 139 SIGSEGV; the same deck with `v(out)` = rc 0. `distoan.c` discards `OUTpBeginPlot`'s return at all five plots and dereferences NULL | pre-flight (`netlist_map_resolve`) **and** `render_deck` |
| **R2** | **`disto` enabled AND zero saved outputs** (the naive "op + disto" two-checkbox deck) | M4/`probe-C/v5.cir`, rc 139 | pre-flight: require ≥1 resolving output, or emit `save all` |
| **R3** | **any `lin` sweep with `points == 2`** (AC, NOISE, SP) | F8/D2, `acan.c:103-114`: `numsteps-1 > 1` is false for 2, so it falls into the one-point arm. `span.c:417-427` has the same shape | field validation, with the sentence |
| **R4** | **`sens` in AC mode AND `option klu`** | F8/D3 measured: klu+dc is identical to sparse and safe; klu+ac is SIGSEGV. The guard in `cktsens.c:97-105` is commented out | option cross-check at pre-flight |
| **R5** | **two `.sens` CARDS in one deck** | F8/D5, rc 134 SIGABRT. We emit commands so this cannot occur — recorded so a future dot-card path cannot reintroduce it | `render_deck` assertion |
| **R6** | **`savecurrents` (or `save_all_i`) AND an `ac` analysis** | F15 §4: `savecurrents` + AC destroys the whole write, and `nosavecurrents` — the manual's documented workaround — **does not exist in this tree**. The real remedy is `remzerovec`, which C9 already emits | warn at commit; `remzerovec` is already emitted per analysis |
| **R7** | **a `.dc` with three nest triples** | F10: the third is silently dropped | field validation |
| **R8** | **a `.dc` whose sweep source is not a V source, an I source, a resistor, or `temp`** | F10, `dctrcurv.c:89-151` | source picker offers exactly those four kinds |
| **R9** | **an `optran` line together with `.options noopiter/gminsteps/srcsteps`** | C13 | the convergence panel has one model |
| **R10** | **an option emitted through the wrong door for its class** | F15's four traps | structurally impossible: `ase::opt_emit` is the only producer |

### 7.5 Capture — the one invariant this design changes

**Today:** `set appendwrite` + one `write` per analysis (I3, issue 0929). That was the right fix
for "a single trailing write stored only the last analysis". It assumes one analysis ⇒ one plot,
and NOISE and DISTO each produce two or more; today ASE-L **silently loses one of each**
(`ase-deck.md` §7.4).

**Proposed:** keep `set appendwrite`, keep the delete-before-run (append means the file must not
pre-exist), and replace the N per-analysis writes with one terminal loop:

```
  foreach p $plots
    setplot $p
    echo "$p|$curplotname" >> <cell>_ase.index
    write <cell>_ase.raw all
  end
```

**Why it is strictly better:** it is analysis-blind (M1), so NOISE's two plots, DISTO's two or
five, every `keepopinfo` extra, every `linearize`/`fft` derivative and every campaign iteration
come along for free; and the `echo` line writes a **plot→analysis index from inside the deck**
(M1), in the same order as the `Plotname:` records (M3), which is what makes a family of four
identically-named `AC Analysis` plots labellable at all.

**What it costs, honestly:**

* The committed byte-exact deck goldens move (`test_ase_core.tcl` D1, `test_ase_final*`), and
  row E12's "renders byte-identically" guard is *about* this block.
* Decision **F** — device `@dev` names ride the op write and no other — currently rides on the
  literal `write <raw> all <bare device names>` of op-tier `b`. **M2 shows `setplot <op plot>` +
  `write <file> all` does capture device vectors requested by a `save` command**, which is the
  mechanism, but M2 used explicit `save @m1[id]` names, **not** the tier-`b` bare-name form.
  This must be re-proven before the change lands: rows E5/M1 exist precisely to stop this line
  being moved. See RK1 and ruling R5.
* The `const` plot is captured too. The reader already has to filter `Plotname: constants`
  (`doc/codex/issues/0059`), and now the index file makes the filter trivial.

**Fallback if R5 is refused:** keep the per-analysis write for single-plot analyses and add the
terminal loop *only* for multi-plot ones, accepting duplicate plots in the raw and resolving
them by index position rather than by name. Uglier, and I do not recommend it.

### 7.6 Where the pre-deck options go

They are outside the deck by definition (F15 §3). `-D` flags join `run_cmd` between the
registry args and the deck path (I8's word order is pinned by command goldens `test_ase_simreg_0931`
D4, so the insertion point matters). The generated `.spiceinit` is a new run-directory artifact,
written by `ase::run_deck` beside the deck, deleted and rewritten per run like the raw, and
**chaining the user's** (§6.4, ruling R4).

---

## 8. S6 — results routing

### 8.1 The rule

Decisions **B**/**C**: the Outputs "Value" column is a scalar column — `result_probe` accepts
`<expr> = <number>` and nothing else, and `print` on a multi-point plot emits a paged
`Index time vbg` table from which it extracts exactly nothing (measured: 20,514 rows per output,
108,275 log lines for five). So every registry entry names a destination, and **nothing invents a
scalar**.

### 8.2 The destination per analysis

| analysis | answer | destination | new surface? |
|---|---|---|---|
| `op` | node voltages, branch currents, device operating point | **Value column** (the only genuinely scalar analysis) + `op_annot` on the canvas | no |
| `dc` | a sweep | viewer, scale `v-sweep`/`i-sweep`/`temp-sweep`/`res-sweep` | no |
| `dc` **nested** | a *flattened* 1-D vector with **no `Dimensions:` header** | viewer, **re-split by the GUI** using the point count it computed itself (F10) | no — but the splitter is new code |
| `tran` | waveforms | viewer; scalars only via `meas` | no |
| `ac` | a complex sweep | viewer; derived scalars (DC gain, f3dB, UGF, PM, GM) via generated `meas` → Value column | no |
| `noise` | spectral density **plus** an integrated summary **plus** optional per-device contributors | viewer (`onoise_spectrum`, `inoise_spectrum`); Value column for `onoise_total`/`inoise_total`; **Table** for contributors | **Table** |
| `tf` | three numbers: the transfer function, `Input_impedance`, `output_impedance_at_<node>` | **Value column ×3** — a perfect fit, and the only new analysis that needs no new surface | no |
| `pz` | a root list, `pole(1)…zero(n)`, complex | **Table**: Re, Im, f = abs(p)/2π, Q = abs(p)/2·Re(p). `specs/calculator.md:585` records that ngspice `pz` output is *not modelled* today | **Table** |
| `disto` | 2 plots (single-freq) or 5 (`f2overf1`), complex vs frequency | viewer, labelled by their `Plotname:` literals (`DISTORTION - 2nd harmonic`, `- 3rd harmonic`, `- IM: f1+f2`, `- IM: f1-f2`, `- IM: 2f1-f2`) | no |
| `sens` | one plot, N vectors, 1 point (DC) or complex vs frequency (AC) | **Table**, sortable by magnitude — this is what turns a 90-vector dump into a design tool | **Table** |
| `sp` | S/Y/Z matrices + optionally NF, NFmin, Rn, SOpt | viewer in **Smith/polar** mode + **Table** for the matrix at a frequency; `wrs2p` export with the `Rbase` caveat | **Smith mode** |
| `pss` | two plots (time domain, then frequency domain) | viewer — **not shipped this pass** (X1) | — |
| `.four` / `fft` | `fourierMN` 2-D vectors + `thdMN` | **Table** (harmonic, magnitude, phase, % of fundamental) + a bar chart; THD as a Value-column scalar | Table |
| `meas` | a scalar per statement | **Value column** — this is its natural and only home | no |
| transient noise | a waveform realisation | viewer; `meas … RMS` → Value column; optional `linearize`+`fft` spectrum → viewer; N-run spread → Table + histogram | no |
| **campaign** (sweep/corner/MC) | one row per run | **Table**: axis coordinates as columns, `meas` scalars as columns; plus a family-of-curves overlay in the viewer | Table |

**One new surface serves six needs.** That is the selective pick: a **Result Table** — a
sortable, exportable grid with a scalar-per-cell contract, fed from a named plot's vectors or
from the campaign collector. It is the same widget for PZ roots, sensitivity, noise
contributors, S-matrix, harmonics and campaign runs. Building six bespoke panes would be the
mistake; building one and pointing six `result` declarations at it is the design.

The second new surface, **Smith/polar mode in the viewer**, is a genuine addition and is scoped
smaller: `examples/sp/sp2.cir` and `Tschebyschef-LP.cir` already demonstrate `smithgrid`, so the
transform is known.

### 8.3 Labelling multi-plot results to the user

The deck writes `<cell>_ase.index` (§7.5), one line per plot, in file order:

```
const|constants
op1|Operating Point
noise1|Noise Spectral Density Curves
noise2|Integrated Noise
disto1|DISTORTION - 2nd harmonic
disto2|DISTORTION - 3rd harmonic
```

The GUI joins it positionally to the rawfile's `Plotname:` records (M3: `$plots` is oldest-first,
and the loop writes in that order) and to the analysis rows it generated, producing the label the
user sees: *"Noise — spectral density"*, *"Noise — integrated"*, *"Distortion — 2nd harmonic"*.

For a campaign, the generator appends the coordinates itself:

```
ac1|AC Analysis|run=0|rload=500
ac2|AC Analysis|run=1|rload=1000
```

which is how four identically-named `AC Analysis` plots (measured, `probe-C/camp.cir`) become a
labelled family. **This is the piece ADE gives you for free and ngspice does not**, and it is
solved with one `echo` line rather than a counter heuristic.

---

## 9. S7 — beyond ADE

### 9.1 The campaign generator

ngspice has no `.step`, no corners, no MC construct (F10). Everything must be generated. The
state grows exactly one key.

```tcl
sweep {                                   ;# omit_if_empty, absent on all 105 files
  mode      parametric | corners | montecarlo
  axes {
    { kind param  name rload  values {500 1000 2000 4000} }
    { kind param  name cload  from 1p to 10p steps 5 spacing log }
    { kind temp              values {-40 27 125} }
    { kind instance name r1 param temp values {…} }
    { kind model    name nch  param vth0 values {…} }
    { kind corner   lib {…} sections {tt ss ff} }
  }
  runs      40                            ;# montecarlo only
  seed      4242                          ;# {} = unseeded, and say so
  collect   { {name bw3   meas {ac bw3 when vdb(out)=-3.0103 fall=1}}
              {name gain  meas {ac gain max vdb(out)}} }
}
```

**The primitive is `alterparam` + `reset` over ASE-L's OWN `.param` variables** (C15). ASE-L
already renders `.param <name>=<value>` from its `variables` state key, so a design variable is
already in the deck and already sweepable with no extra file. `var()` + `.spiceinit` is the
fallback for a value ASE-L did not render — a number inside a subcircuit or a `.lib`.

The generated block, exactly as measured (`probe-C/camp.cir`, rc 0):

```
.control
  set filetype=ascii
  set appendwrite
  set ase_vals = ( 500 1000 2000 4000 )
  setplot new aselres "ASE-L results" aseldata
  set ase_coll = $curplot
  let f3db = vector(4)
  let rv   = vector(4)
  let ase_i = 0
  foreach ase_v $ase_vals
    alterparam rload = $ase_v
    reset
    save v(out)                    $ <- MANDATORY: reset drops the save list
    ac dec 20 1k 10meg
    if $sim_status ne 0
      echo RUN-FAILED
      quit 1
    end
    remzerovec
    meas ac bw3 when vdb(out)=-3.0103 fall=1
    set ase_dt = $curplot
    setplot $ase_coll
    set ase_ix = "$&ase_i"
    let f3db[$ase_ix] = {$ase_dt}.bw3
    let rv[$ase_ix]   = $ase_v
    let ase_i = ase_i + 1
  end
  setplot $ase_coll
  foreach p $plots
    setplot $p
    echo "$p|$curplotname" >> <cell>_ase.index
    write <cell>_ase.raw all
  end
.endc
```

Measured output: `bw3` = 3.18314e5 / 1.59156e5 / 7.95778e4 / 3.97887e4 — exactly `1/(2πRC)` at
500/1k/2k/4k, so the `.param` change really took effect; and the rawfile carries all four AC
plots plus the named collector.

Generator rules, each with its measured reason:

| rule | reason |
|---|---|
| **re-emit `save` after every `reset`** | `orchestration.md` §5.6: the save list does not survive a re-parse; the shipped examples get this wrong |
| **name the collector**: `setplot new aselres "ASE-L results" aseldata` | a bare `setplot new` gives `unknown1`/`Anonymous` (measured, `probe-C/camp.cir` first draft) |
| **never compare strings in `.control`** | `if "$p" ne "const"` silently takes the false branch (critique §5.2); filter on the reader side |
| **never use `.` `-` `(` `[` in a generated variable name** | `$` substitution swallows them (`orchestration.md` §1.4) |
| **`set x = "$&vec"`** to move a vector value into a shell variable | `$&vec` alone loses precision by default (§1.5) |
| **statistics in Tcl, not in the deck** | there is no `sort`, no median, no percentile, no histogram in ngspice (`orchestration.md` §6.7) |
| **`setseed <n>` once, and say what it does and does not reproduce** | F16: white and 1/f transient noise are seeded from `getpid()` and are irreproducible under *every* seed control. RTS and `trrandom` are reproducible |
| **filter `Reset re-loads circuit <title>` from stdout** | printed on every `reset` (`inp.c:551`) |

Corners use **route B** — one generated top-level deck per corner, `source`d in a loop
(`orchestration.md` §5.3) — because `.lib` section selection happens at parse time and cannot be
changed by `alterparam`. Monte Carlo uses **route 2** — `define` the five distribution helpers,
`setseed`, then `alter`/`altermod` per draw, no re-parse — which the dossier measured at ~10×
cheaper per run and bit-identical across two invocations.

**Progress and abort.** F9 is unforgiving: in `-b` batch mode ngspice installs no signal handlers,
so SIGINT is immediately fatal — rc 130, nothing written. ASE-L's Stop is SIGKILL and is
therefore no worse. But a 400-run campaign that dies with nothing is intolerable, so the
generator adds a **cooperative abort**: `Stop` writes a flag file, and the loop checks it.

```
    if $ase_i > 0
      ... run ...
    end
```
plus, at the top of each iteration, an `fopen`-based check of `<rundir>/ase.stop`
(the `vlnggen` script in ngspice's own tree uses `fopen` for exactly this kind of probe). Each
completed run's plots are already in memory and the terminal loop writes them, so an aborted
campaign yields a **partial, well-formed, labelled result set** — which is more than ADE-L's
own batch mode gives you.

### 9.2 Transient noise (F16) — a category ADE-L does not have

`trnoise`/`trrandom` are `IF_REALVEC` instance parameters on **both** `vsrc` and `isrc`
(the manual's "isrc not yet available" is wrong here, measured), documented nowhere in-tree.
They belong on the **Tran form**, as a collapsible section — they are a simulation setting, not
a source property, and F13's founding doctrine forbids putting them on the schematic.

Two injection routes, neither of which touches the schematic:

1. `alter <src> trnoise = [ 10m 1u 0 0 ]` on an existing DC-only source — the GUI knows which
   sources it drives and greys out the ones carrying stimulus.
2. a parallel current source added by `render_deck` in a new slot right after the netlist:
   `ase_inoise_1 0 out dc 0 trnoise(1m 1u 1 0.1m 5m 18u 30u)` — validated against
   `netlist_map_resolve` first.

**Emit all seven `trnoise` args and all five `trrandom` args, always, padded with 0.** Short
forms are a heap read (T2) and a silent zero (T4), and two shipped ngspice examples get them
wrong. The form's fields, validations and live readouts are specified in `trnoise.md` §10.3 and
I adopt them wholesale; the one sentence that must be on screen is the honest one:
*"White and 1/f noise are not reproducible in this ngspice build (seeded from the process id)."*

### 9.3 The four F14 picks, and why these four

Seventeen items were catalogued. **Choosing all seventeen is choosing nothing**, so:

**Pick 1 — `CKTncDump`'s starred nodes, highlighted on the canvas.** (F14 #1)
Biggest win per line of code in the entire document. The data already exists after every failed
OP; the net-name mapping already exists; the canvas highlight already exists. ADE gives you a
log file. *Chosen because it converts the single most common, most opaque failure in analog
simulation into a picture.*

**Pick 2 — the four-rung ladder pane with `optran` visible.** (F14 #2, #3, F11)
`optran` is **on by default** in this tree, returns the transient state at `opfinaltime` as the
operating point (measured 0.9999550 instead of 1.0 on a 1 µs RC), supersedes
`noopiter`/`gminsteps`/`srcsteps`, and **no user has ever seen this knob.** A GUI that does not
show it is misreporting how the operating point was obtained. *Chosen because it is a
correctness item disguised as a feature.*

**Pick 3 — `.sens` glob filters + the offline `devhelp -flags` parameter picker.** (F14 #7)
ADE-L has **no sensitivity analysis at all**. This is the clearest "plainly better" item, and
§5.4 shows the whole picker is computable with no simulator run. *Chosen because it is
capability ADE lacks, not capability ADE has.*

**Pick 4 — the Run Report.** (F14 #4, #5, folded into one item)
After every run, one collapsible panel: wall clock, `rusage tranpoints accept rejected`
(*"the single best convergence-health metric"*), `rusage devtimes` (per-device-type load time —
a free "what is slow" table), and, when `set ngdebug` is on, the `speedcheck`/`deltacheck`
vectors plotted as "where was the simulator struggling". *Chosen because three catalogued items
collapse into one panel with one parser, and because "your run took 4 minutes" is a question
every user asks and no tool answers.*

**Plus one that is not optional:** `wrnodev` as save/restore of a DC solution (F14 #6), because
it is the remedy the convergence panel needs and Cadence users expect it.

Considered and **not** chosen this pass, with reasons in §13: `iplot`, `stop`/`step`/`resume`,
`diff`, `--soa-log`, `.probe` power, the calculator vocabulary, `topo_reduce` as a standalone
feature (it appears only as a remedy), `.four` as a first-class analysis (it appears only as a
result surface).

---

## 10. Worked end to end — NOISE, form to plot and back

The hard case, followed all the way through. Everything below is either measured or cited.

### 10.1 What the user does

Analyses ▸ Choose… ▸ **Noise**. The form (built from §4.4's `fields`, in that order):

```
 ┌ Choose Analyses ───────────────────────────────────────────────────────┐
 │  ○ op  ○ dc  ○ ac  ○ tran  ● noise  ○ tf  ○ pz  ○ sens  ○ disto  ○ sp  │
 │  ○ pss (this ngspice was built without PSS support)                    │
 │  ☑ Enable                                                               │
 │  Output node    [ v(out)          ] [Pick…]                            │
 │  Output ref     [                 ] [Pick…]   empty = ground           │
 │  Input source   [ V1          ▾   ]           must carry an AC value    │
 │  Sweep type     [ Decade      ▾   ]                                     │
 │  Points per decade [ 10 ]                     = 61 points, 1 Hz … 1 MHz │
 │  Start frequency [ 1        ] Hz                                        │
 │  Stop frequency  [ 1meg     ] Hz                                        │
 │  ☑ Per-device contributor table                                        │
 │     Report every [ 1 ] points   ⓘ 1 keeps the full spectrum            │
 │                                                     [Options…]          │
 │  ⓘ                                                  [OK] [Apply] [Cancel]│
 └────────────────────────────────────────────────────────────────────────┘
```

`[Pick…]` arms `select_on_design`; a click on the schematic writes `v(out)`, hierarchy-qualified.
The input-source combobox lists only V/I sources that carry an `ac` value — the precondition of
§3.3 becomes a *filter*, so the refusal never has to fire. If the user types a source with no AC
value anyway, OK refuses **on the form** (§5.3) with
*"V2 has no AC value; ngspice would refuse this run with 'ac input not found'."*

### 10.2 What lands in the state file

```
analyses {{type op enabled 1}
          {type dc enabled 0}
          {type ac enabled 0}
          {type tran enabled 1 step 10n stop 200u}
          {type noise enabled 1 output v(out) input V1 sweep dec points 10
           start 1 stop 1meg contributors 1 ptspersum 1}}
```

Note what did **not** happen: no new top-level key, no `version` bump, no migration. A fifth row
in a list that was always variable-length (`delete_selection` and `chana_ok`'s append prove it in
production today), and `ase::state_load` merges the file over the defaults so an old file with
four rows still loads unchanged. The 105 committed files round-trip byte-identically because none
of them gains a key.

### 10.3 What is emitted

```spice
* ...netlist...
.lib /models/sky130.lib.spice tt
.param Vgs=1.8
.temp 27
.save v(out)
.control
set appendwrite
tran 10n 200u
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
noise v(out) V1 dec 10 1 1meg 1
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
op
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
foreach p $plots
  setplot $p
  echo "$p|$curplotname" >> /run/tb_noise_ase.index
  write /run/tb_noise_ase.raw all
end
print v(out)
.endc
.end
```

Read it against the decisions: `op` is **last** (A); a guard **and** `remzerovec` follow **every**
analysis (D, E); the analysis lines are `.control` commands (C7); nothing is written until every
analysis has passed its guard (C8/C9); the emit order is `tran noise op` because the registry
weights `tran` 30, `noise` 40, and `op` is pinned last by the explicit exception.

### 10.4 What comes back

Measured shape (`probe-C/v2.cir` is this deck's skeleton):

```
/run/tb_noise_ase.index          /run/tb_noise_ase.raw
  const|constants                  Plotname: constants
  tran1|Transient Analysis         Plotname: Transient Analysis
  noise1|Noise Spectral Density…   Plotname: Noise Spectral Density Curves
  noise2|Integrated Noise          Plotname: Integrated Noise
  op1|Operating Point              Plotname: Operating Point
```

Both files list plots in creation order (M3), so the join is positional and needs no matching
heuristic. Note that **both** noise plots arrived — today one of them is silently lost
(`ase-deck.md` §7.4).

### 10.5 Where each piece of the answer goes

| vector | plot | destination | why |
|---|---|---|---|
| `onoise_spectrum`, `inoise_spectrum` | Noise Spectral Density Curves | **viewer**, log-x, labelled *"Noise — spectral density"* | a spectrum is not a scalar (decision B) |
| `onoise_total`, `inoise_total` | Integrated Noise | **Value column**, via a `print` emitted after `setplot` on that plot | genuinely scalar; 1 point, no reference vector |
| `onoise_total_r1_thermal`, `onoise.m1.1overf`, … | Integrated Noise | **Result Table**, sorted descending by contribution, grouped by instance | the answer to "where does it come from" |

Two naming facts the table code must carry, both from `an-smallsig.md` §3.9: **two incompatible
conventions coexist** — most devices use `onoise_total_<inst>_<mech>` with underscores, while the
BSIM3/BSIM4/BSIMSOI/HiSIM family uses `onoise.<inst>.<mech>` with dots; and the **empty-suffix
entry is the device total**, so `onoise_total_q1` is Q1's total and `onoise_total_q1_ic` is one
mechanism of it. A table that sums the wrong rows double-counts.

Also: OSDI's integrated total is `onoise_total_<inst>` **with a trailing space**
(`osdinoise.c:111-113`) — a naming bug the table must tolerate rather than trip over.

### 10.6 Back into the GUI

* `ase::plot_sim_type` returns `noise` from the registry's `sim_type`; `xschem raw read` already
  maps `noise spectral density curves` → `noise` and `integrated noise` → `op`/`noise`
  (`save.c:957-1005`), and has a **catch-all arm** for any other `Plotname:`. So **adding NOISE
  needs no C change at all** (`ase-state.md` §7.5).
* The Analyses pane's Arguments column renders from the same emit program as the deck line (C6),
  so it reads `output=v(out) input=V1 dec 10 1 1meg 1` and cannot drift.
* The Value column shows `onoise_total` and `inoise_total` — and **only** those, because the
  print anchor is unchanged and the noise scalars are fetched by their own targeted `print`.

### 10.7 The one thing the user must be told

If they tick "Per-device contributor table" and then set "Report every" to 8 to make the run
faster, the spectrum silently loses seven eighths of its rows — ngspice couples the two
(`an-smallsig.md` §3.9, measured: `ptspersum=4` over 21 points leaves 6). The form says so, and
the default is 1, which costs nothing.

---

## 11. S8 — stages

Each stage is shippable on its own, in this order. "Rulings" names the ones that gate it.

| # | stage | content | rulings | suites that move |
|---|---|---|---|---|
| **0** | **The silent drop dies** | a `default` arm in the emit loop that refuses by name and stops the run. RED test: today a `{type noise enabled 1 …}` state renders a deck with no analysis, rc 0, empty raw, pane ticked | **none** | one new row |
| **1** | **The registry, byte-identical** | extract `ase::analysis_types` with exactly the four existing types; every one of the seven sites becomes a reader; `analysis_line` is the one producer. The D1 golden and E12 are the proof | **none** | goldens must NOT move |
| **2** | **Honest availability** | the `help <verb>` probe leg on the existing capability deck; the type list = registry ∩ caps; unavailable types shown disabled with a reason; preconditions in `preflight_scan` | R8 | simcaps suite grows |
| **3** | **The form stops lying** | typed fields with units; `ac` gains `lin`/`oct` and the `dec` lie dies; `tran` gains `tstart`/`tmax`/`uic` with slot substitution; sweep-mode relabelling; `dialog_status` refusals; the extra-key editor becomes typed-and-emitted-or-refused; Apply | R2, R3, R6, R7 | dialogs G1/G2/GE4/GE5, window P4 |
| **4** | **Capture becomes plot-complete** | terminal `foreach $plots` + the sidecar index; multi-plot labelling; the campaign-ready collector naming | **R5** | every deck golden; E5/M1 must be re-proven |
| **5** | **The analyses, one per commit** | `noise`, `tf`, `pz`, `sens`, `disto`, `sp` — each with a registry entry, a deck golden, a raw-attach row and its `refuse` tokens | R6 per label set | new rows per type |
| **6** | **The Result Table** | one sortable scalar grid serving PZ roots, sensitivity, noise contributors, the S-matrix, harmonics and campaign runs | R6 | new suite |
| **7** | **Options, both catalogues** | `ase::opt_catalogue` + `ase::opt_emit`; the search-first difference-first dialog; inert options refused; `-D` delivery for pre-deck bool/string | R6 | new suite for `opt_emit`'s five trap rows |
| **8** | **Convergence as a remedy** | the four-rung panel with `optran` visible; the live ladder pane; **`CKTncDump` starred nodes highlighted on the canvas**; `wrnodev` save/restore; the Run Report | R6 | new suite |
| **9** | **The campaign** | the `sweep` state key; the generated parametric / corner / Monte-Carlo block; the generated `.spiceinit` for `var()` injection; the cooperative abort; the campaign Result Table | **R4**, R6 | new suite; state schema gains one `omit_if_empty` key |
| **10** | **Intents** | the Measurements pane: each intent expands, visibly, into rows + options + a campaign. Ships last **because it is a front end over everything above and adds no capability of its own** | R10, R6 | new suite |
| **11** | **Transient noise** | the Tran form's noise section; the two injection routes; the honest reproducibility sentence; the N-run histogram | R6 | new suite |

**What ships first is Stage 0, alone**, and the reason is the tree's own habit: one rebuild, zero
rulings, zero suites moved, and it converts the worst failure mode available into a refusal.
`ase-conventions.md` §9.3 reaches the same conclusion from a different direction.

**What I would put off:** PSS (X1), the `-p` pipe transport (X3), `iplot`/`stop`/`step` (X4),
CIDER and XSPICE event analyses (X5), and the Smith-chart viewer mode, which I would fold into
Stage 5's `sp` commit only if it is cheap and otherwise defer.

**Migration.** Nothing in Stages 0–8 touches the state schema. Stage 9 adds `sweep` and it joins
`ase::omit_if_empty`, so no committed `.state` file changes a byte and the five byte-identity
rows stay green. `version` stays 1 throughout — adding a type and adding optional row keys is
exactly *"a new optional key"*, not *"a change an old loader could MISREAD"*
(`ase.tcl`'s own migration doctrine). The one asymmetry to state and test: if the seed ever gains
a fifth row (ruling R1 — I recommend it does not), newly created states get five rows while all
105 existing ones keep four, because `dict merge` is per top-level key.

---

## 12. Rulings the user must give

Per the standing preference, these are **not** to be put as a list. Raise the most consequential
one, give the evidence and the recommendation, and hold a conversation about it before moving on.
Ordered by how much they gate.

| # | question | recommendation | what it costs to get wrong |
|---|---|---|---|
| **R5** | Retire the per-analysis `write` for a terminal `foreach $plots` capture? | **Yes.** It is the only way NOISE and DISTO stop losing a plot, and M1/M2/M3 measured the mechanism. | It moves every committed deck golden and it re-opens decision **F** (device names ride the op write). Must not land without re-proving rows E5/M1. |
| **R4** | May ASE-L write a `.spiceinit` into the run directory, chaining the user's? | **Yes, chained, with a pre-flight notice.** It is the only door for `CP_NUM`/`CP_REAL`/`var()` and therefore the only door for the campaign. | Without chaining it silently deletes the user's entire ngspice configuration for that run (M5). |
| **R2** | Reverse recorded decision D4 — remember in-form edits across a type switch? | **Yes**, cached per dialog lifetime. | With four types the discard rule is defensible; with twelve it silently eats work. Reversing a recorded decision needs the ruling. |
| **R3** | Row identity (`id`) and N-rows-of-a-type, editable? | **Yes**, additive and absent on every existing file. | "A DC sweep of VIN and one of temperature" is a real bench and is unsayable today. |
| **R7** | Is `sqrnoise` offered per-noise-row or once, globally? | **Once, globally**, labelled as global. | It is a `set` variable; two noise rows cannot disagree. Offering it per row would be F3's defect in a new costume. |
| **R8** | Unavailable analyses: shown-disabled with a reason, or hidden? | **Shown.** | Hidden makes ASE-L look like it lacks the feature and gives the user no way to tell "ngspice can't" from "ASE-L can't". |
| **R1** | Does `state_default`'s four-row seed change? | **No.** | 105 files and `test_ase_core.tcl` R1 pin it; the gain is cosmetic and the cost is every golden. |
| **R6** | Every new user-facing label and sentence. | Batch by stage and ratify per stage, not per string. | The tree's standing rule: *every new user-facing sentence is the user's to ratify*, recorded with `owed.sh add rule`. |
| **R9** | Ship a PSS form for an analysis nobody has ever executed? | **No.** Build `--enable-pss`, run the two shipped examples, record the plot literals, *then* design it. | Critique §5.7 item 1. A form for an unrun analysis is a guess wearing a uniform. |
| **R10** | Does the intent layer ship at all, or is the verb layer the deliverable? | **Ship it, last (Stage 10).** | It adds no capability; it adds reach. If the answer is no, Stages 0–9 still stand entirely on their own — which is the design's insurance policy. |

---

## 13. What this design refuses, and why

| # | refused | reason |
|---|---|---|
| **X1** | **A PSS form.** | `WITH_PSS` is off here and nobody has ever run PSS. The plot literals, the numbering, the success signal and whether the recursive `DCpss(ckt,1)` re-entry terminates are all unmeasured (critique §5.7 #1). Shown-disabled with the configure flag; nothing more. |
| **X2** | **`.sens2` and `.hb`.** | `SEN2info` and `HBinfo` are declared `extern` and **defined nowhere** (F1). They do not exist. |
| **X3** | **The `-p` pipe transport, this pass.** | It would buy graceful abort (F9), live `iplot`, the `stop`/`step` debugger and pre-deck `CP_NUM` delivery without a file — a genuinely attractive bundle. It also rewrites `run_cmd` (whose word order is pinned by command goldens), the log framing (decision **G**), the exit-status contract (**I6**) and every completion path. Too much for a pass whose first job is to stop losing plots. **Put it on the roadmap as the thing that unlocks four features at once.** |
| **X4** | **`iplot`, `stop when`, `step`, `resume`.** | All require interactive or `-p` mode (F9/D4), so they are downstream of X3. |
| **X5** | **CIDER and the XSPICE event-analysis surface.** | Neither has been built or measured here (critique §5.7 #3, #4); the DC-sweep + auto-bridge failure has a reproducer and no root cause. |
| **X6** | **`optran`'s ramp-time argument as a working feature.** | `optran.c:670-671` has no `optime > opramptime` clamp, so the factor keeps oscillating and returns to 0 at `2·ramptime`; `README.optran` says ramping is "not yet established". Always emitted as `0`. |
| **X7** | **`ramptime` as "supply ramping".** | The live code is inside `#ifdef XSPICE_EXP`, **defined nowhere in the tree** (F8, and this corrects `convergence.md` §10.4). |
| **X8** | **Any inert option, offered as if live.** | `itl1/2/4` under 100, `itl3`/`itl5`, `oldlimit` on the `.control` route, `klu_memgrow_factor`, `newtrunc`, `scalm`, `debug`, `x11lineararcs`, and `nosavecurrents` **which the manual documents and this tree does not contain**. |
| **X9** | **Reading any analysis setting back out of ngspice.** | F12: OP has zero parameters and nothing about a DC or OP job is askable. The GUI is the sole authoritative store and re-emits; a round trip would invent facts. |
| **X10** | **`help all` as a command inventory.** | It stops at the first NULL `co_func` and omits everything from `cdump` onward (F5, critique §3.2). It happens to list the analysis verbs; the reasoning is wrong and would break silently. |
| **X11** | **Dot-card analyses, and `-r`.** | C7's five reasons; and `-r` produces no rawfile at all once a `.control` block exists (I7, re-measured). |
| **X12** | **Anything written back onto the schematic.** | F13's founding doctrine: the schematic carries only the circuit. This is why transient noise lives on the Tran form and not on a source symbol. |
| **X13** | **Promising "stop and keep what you have" for a batch run.** | F9: `-b` installs no handlers, SIGINT is rc 130 with nothing written. The campaign's cooperative flag file is the honest partial-result story, and it only works inside a generated loop. |
| **X14** | **Statistics in the deck.** | ngspice has no sort, no median, no percentile, no histogram (`orchestration.md` §6.7). Read the sample out and do it in Tcl. |
| **X15** | **Three-deep `.dc` nesting, and sweeping anything but a V source, an I source, a resistor or `temp`.** | F10: the third triple is silently dropped and the other four are all `dctrcurv.c` accepts. |
| **X16** | **A per-analysis control over a variable that is physically global.** | `sqrnoise`, `interp`, `filetype` and friends are `set` variables. Offering them per row would report a setting that is not in force — F3 again. |
| **X17** | **Twelve bespoke result panes.** | One Result Table serves six of them (§8.2). Six panes would be six half-finished panes. |

---

## 14. Risks

| # | risk | mitigation |
|---|---|---|
| **RK1** | **The capture change (C8) is the largest regression surface in the document.** It moves every deck golden and re-opens decision **F**, whose rows E5/M1 exist specifically to stop that line moving. M2 measured the mechanism but not the tier-`b` bare-name form. | Land Stage 4 with a dedicated golden that runs the op tier's own fixture and asserts every `@dev` vector survives the terminal write, **before** the per-analysis write is deleted. Keep the fallback of §7.5 in the plan. |
| **RK2** | **The generated `.spiceinit` shadows the user's completely** (M5). | R4: chain it, and pre-flight a notice. Never write it when no campaign is configured. |
| **RK3** | **105 committed `.state` files with a byte-stable round trip asserted by five test rows.** | No top-level key until Stage 9, and that one joins `omit_if_empty`. `test_ase_core.tcl:191` reddens deliberately on any schema-key change — treat it as a tripwire, not an accident. |
| **RK4** | **The probe's standing costs are inherited**: paid inside the user's Run gesture (0953), on every press (0958), unbounded without `timeout(1)` (0959). | C5: no new run, free peek by default, Detect as the only door to a cold measurement. Do not put a probe in front of the dialog opening. |
| **RK5** | **`test_ase_dialogs.tcl` G1/G2/GE4 drive `$top.chana.types.tran` by path.** | Grid-wrap the radio row; add siblings, never rename or move. |
| **RK6** | **`chana_show`'s hardcoded five-name destroy list** breaks the moment a sixth field name exists — *"the single sharpest trap in the analysis code"*. | The registry deletes it structurally in Stage 1; do not add a field before Stage 1 lands. |
| **RK7** | **Emitting stored unknown keys turns dormant keys in 105 files into live simulator input** (Stage F4 R-16). | Emit only registry-known keys; carry the rest forward and mark them inert in the Arguments column. |
| **RK8** | **The intent layer becomes a second source of truth** if C1 is ever relaxed "just for this one case". | The rule is testable: a suite row that expands every shipped intent and asserts the rendered deck is identical to the deck rendered from the resulting rows alone. |
| **RK9** | **The DISTO SIGSEGV is upstream and our refusals are the only defence.** It is not known whether it exists in `pre-master-47` (critique §7 #2). | Ship refusals R1/R2 with `disto`, never after. The one-line upstream fix (capture `OUTpBeginPlot`'s return at all five sites, mirroring `acan.c:169-175`) is worth filing separately. |
| **RK10** | **`ase_window.tcl` is dirty and moving** — it gained 115 lines during one dossier read. | Cite procs, not lines. Re-derive every anchor before quoting it to anyone. |
| **RK11** | **Two independently buffered output streams** (ladder on stderr, `CKTncDump` on stdout) arrive out of order under `2>@1`. | The ladder pane matches on content, never on order. Do not build a state machine that assumes arrival sequence. |

---

## 15. Corrections and additions to the evidence base

Kept visible rather than folded in, per house style.

1. **F7 is narrower than stated, and therefore more dangerous.** The DISTO trigger is not "a
   narrowed `save`" but "a save list that resolves to nothing". **M4**: a *valid* deck-level
   `.save v(out)` + `disto` is rc 0; a *stale* `.save v(oldname)` + `disto` is rc 139. The
   realistic user story is not an exotic deck — it is renaming a net on the schematic and
   re-running. `ase::netlist_map_resolve`, which `ase-state.md` §3.4 notes is unused, is a crash
   guard.
2. **The terminal capture is viable for the op plot too.** **M2**: `setplot <op plot>` +
   `write <file> all` captures `@m1[gm]`, `i(@m1[id])` and `v(@m1[vdsat])`. Not previously
   measured by any dossier (`ase-deck.md` §9 lists it as untested). ⚠ The op-tier **bare-name**
   form remains untested — RK1.
3. **`$plots` is oldest-first**, so the rawfile's plot order is creation order (**M3**,
   agreeing with `orchestration.md` §2.3 and contradicting nothing, but stated here because the
   sidecar index's positional join depends on it).
4. **`echo "…" >> file` works inside `.control`** and is the sidecar-index mechanism (**M1**).
   No dossier proposed writing a machine-readable index from inside the deck.
5. **The `.spiceinit` search order is netlist-directory-first and stops at the first hit**
   (`src/main.c:1264-1300`). F15 §3.3 names `.spiceinit` as a delivery route without noting that
   it *replaces* the user's. This is a new hazard.
6. **For ASE-L's own design variables, `alterparam` + `reset` beats `var()` + `.spiceinit`.**
   F15's new channel is real and I use it — but only for values ASE-L did not render a `.param`
   for. ASE-L already renders `.param` from its `variables` key, so the common sweep needs no
   extra file at all. Measured end to end in `probe-C/camp.cir`.
7. **`reset` drops the save list**, so a campaign must re-emit `save` inside the loop
   (`orchestration.md` §5.6). My measured campaign honours it; the shipped ngspice examples do not.
8. **`optran`'s argument 6 must always be 0** — `convergence.md` §7.7 suggests offering the four
   rungs "plus two numbers" and does not say loudly enough that the sixth argument is broken
   (§7.6 #2 does). X6 states it as a rule.

---

### Appendix — anchors this design leans on

**ngspice** (`/home/analog/dev/ngspice`, `ver_50`): `analysis.c:8-59` (the twelve),
`niiter.c:37-39` (the iteration floor), `acan.c:103-114` (`lin 2`),
`distoan.c:516,540,563,584,606` (the unchecked `OUTpBeginPlot`), `cktsens.c:97-105` (the
commented-out KLU guard), `main.c:1217-1220` (no batch signal handlers),
`main.c:1264-1300` (the `.spiceinit` search), `inp.c:1376` (the pre-deck boundary),
`init.c:77-94` (optran armed by default), `optran.c:670-671` (the unclamped ramp),
`cktncdump.c:10-43` (the starred nodes), `cktop.c` (the ladder messages),
`nsetparm.c:82-93` + `noisean.c` + `cktnoise.c` (NOISE), `com_help.c:56` vs `:84`
(the truncating vs the complete help loop), `variable.c:759-858` (the coercion table).

**xschem-claude** (`fluid-editing`, dirty — procs, not lines): `ase::state_default`,
`ase::state_load`, `ase::schema_keys`, `ase::omit_if_empty`, `ase::register_backend`,
`ase::backend::ngspice::render_deck`, `ase::backend::ngspice::sim_status_guard`,
`ase::backend::ngspice::capabilities`, `ase::sim_capabilities`, `ase::sim_caps_have`,
`ase::cap_run`, `ase::plot_sim_type`, `ase::preflight_gate`, `ase::preflight_scan`,
`ase::netlist_map_resolve`, `ase::n_enabled_analyses`, `ase::ui::choose_analyses`,
`ase::ui::chana_show`, `ase::ui::chana_ok`, `ase::ui::chana_options`, `ase::ui::chana_row`,
`ase::ui::arg_summary`, `ase::ui::dialog_row`, `ase::ui::select_on_design`,
`ase::ui::simdlg_case_show`, `ase::ui::rsel_status`.

**Prior decisions this design must not contradict:** `ase-conventions.md` §5.6 **A–N**;
issues 0929 (appendwrite), 0964 (op last), 0967 + 1243 (the print anchor), 0963 (the op tiers),
0950/0953/0958/0959 (the probe), 0159 (bus bits), 0434 (the `-r` idiom).
