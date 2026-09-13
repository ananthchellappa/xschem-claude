# Stage 7 task 1 — the options catalogue, and the one speller

**One commit, issue 1437, and the first of Stage 7's four tasks.** Scope was
`PLAN.md` **§7a + §7b** and nothing else; §7c, §7d, §7e, §7f and §7g are tasks
2–4 and are untouched here.

**Floor:** new suite `test_ase_options_1437` — **75 checks**, registered in
`tests/run_regression.tcl`'s `hcases`, so **T1 covers all 71**. No existing
suite's floor moved, because no existing row moved.

**`src/ase.tcl` 19019 → 19775 lines** (+756): 15 new `ase::` procs (the schema
half) and 2 new `ase::backend::ngspice` procs carrying a 247-row catalogue and a
spelling table (the content half). **`render_deck` is byte-unmoved.**

---

## ⚠ THE HEADLINE: THREE SILENT WRONG ANSWERS ARE LIVE IN THE SHIPPED TREE, AND ONE IS IN THE USER'S OWN BENCHES

The plan expected this stage to *prevent* option defects. It found three already
shipped, and the catalogue is what noticed.

### 1. Five committed benches ask for `wnflag` and none of them gets it

`git ls-files | grep '\.state$' | xargs grep -l wnflag` → **five** files carrying
`{name wnflag value 1}`. `wnflag` decides whether a MOS `W` is the total width or
the width per finger.

`render_deck` spells a stored value of `1` as a **bare card**, so the deck
carries `.options wnflag`. MEASURED on **both** binaries, reading the trailing
bare `set`:

```
.options wnflag      ->  + wnflag        <- a VALUELESS boolean variable
.options wnflag=1    ->    wnflag   1
```

and `wnflag` is read at `CP_NUM` (`inpcom.c:990`, `inpgmod.c:268`, `inp.c:2828`).
A `CP_BOOL` cannot answer a `CP_NUM` read — Trap 2, re-measured this pass on both
binaries with `warn`. **So the card ASE-L writes cannot deliver the value on
either binary, independent of any phase argument.** And one of the three read
sites is inside `inp_readall()`, which no `.options` card can reach at all.

The user asked for W per finger and has been getting W total, with nothing said
by anything.

### 2. A valued option stored as `1` is written as a bare card

MEASURED on both binaries, reading `option`'s own dump after a `tran`:

```
.options maxord=1    ->  MaxOrder = 1
.options maxord      ->  MaxOrder = 2     <- what render_deck writes for value 1
```

### 3. A valued option stored as `0` is dropped

MEASURED on both binaries:

```
.options gminsteps=0 ->  gminsteps = 0    <- gmin stepping disabled
(nothing emitted)    ->  gminsteps = 1    <- what render_deck writes for value 0
```

⚠ **`PLAN.md` §7b predicted defect 3 as "this batch's own defect inside its own
antidote".** It is older than the prediction, it is in the emitter, and the
prediction was about the speller that did not exist yet.

**None of the three is fixed here**, and that is deliberate — see *What I did not
ship*. Section **BR** of the new suite pins the exact blast radius by name so the
crew that rewires the emitter does not re-derive it.

---

## What shipped — the SCHEMA half (`src/ase.tcl`, `ase::`)

| proc | what it answers |
|---|---|
| `ase::sim_options {{sim {}}}` | the catalogue, through the optional `sim_options` hook; `{}` for a backend with none |
| `ase::sim_option_entry {sim name}` | one row, or `{}` |
| `ase::sim_option_names {{sim {}}}` | every name, sorted |
| `ase::sim_option_spell {{sim {}}}` | the adapter's (door × cptype) template table |
| `ase::opt_truthy {value}` | **one truth test**, shared with `ase::option_enabled` |
| `ase::opt_phase {sim name}` | `pre` / `deck` / `run` / `any` / `cmdline`, defaulting to `any` |
| `ase::opt_inert {sim name}` | the reason, or `{}` (D24) |
| `ase::opt_is_pre_deck {sim name}` | §7d's group, as a predicate |
| `ase::opt_door {sim name {where deck}}` | **computed, never typed**; raises on an impossible (phase, slot) pair |
| `ase::opt_template {sim name door cptype}` | the template, or `{}` — which is how a type error is *detected* |
| `ase::opt_line {sim name value {where deck}}` | **the one speller** (D23) |
| `ase::opt_default {sim name}` | the catalogue default |
| `ase::opt_restore_line {sim name {where control}}` | §7e's restore, as the speller applied to the default |
| `ase::option_schema_errors {{sim {}}}` | all 247 rows checked as a set |
| `ase::state_option_delivery {sim state}` | which stored options will not reach the simulator, and why |

**No memo, deliberately.** `ase::analysis_types` caches because its hook *builds*
a dict; this hook returns a namespace variable and Tcl's copy-on-write makes that
O(1). Issue 1406 is the scar on the other side: a memo whose invalidation rule is
*"nobody ever does that"*.

## What shipped — the CONTENT half (`ase::backend::ngspice`)

`variable sim_options` (247 rows) + `proc sim_options` + `proc option_spell`,
registered as two new optional hooks. **Core never names the variable**, and
section **HK3** asserts it lexically: not one of the fifteen schema procs' bodies
contains `reltol`, `gminsteps`, `keepopinfo`, `casemode`, `sqrnoise`, `wnflag`,
`savecurrents`, `.options`, `.control`, `CP_BOOL`, `CP_NUM` or `ngspice`.

| block | rows | source | evidence |
|---|---|---|---|
| **A** | **57** | settable `OPTtbl` keywords | **measured** — `cptype` from the row's own `IF_FLAG`/`IF_INTEGER`/`IF_REAL`/`IF_STRING` bit, `help` ngspice's own description string verbatim, `site` the `cktsopt.c` line |
| **B** | **163** | `cp_getvar` variables | **measured** — `cptype` from the `CP_` constant at the call site |
| **C** | **13** | `cp_usrset` hook variables (`options.c`) | **measured** that the names exist; `units` is one |
| **D** | **6** | card-text pseudo-options | **measured** — `savecurrents*`, `seed`, `seedinfo` |
| **E** | **1** | the one argv-delivered option | `--soa-log=`, `main.c:970` |
| **F** | **1** | tombstone | `nosavecurrents` |
| **G** | **6** | front-end print flags | **measured inert on ASE-L's route** |

Blocks **A + B are the plan's 220-row floor**. Blocks C–G are 27 further rows,
each because a *measurement* found a delivery class the floor has no member of.

---

## ⚠ HOW MANY ROWS WERE VERIFIED, AND HOW MANY TRANSCRIBED

The brief asked for this plainly, so here it is column by column. **A transcribed
column and a measured column are different kinds of evidence.**

| column | rows | evidence |
|---|---|---|
| `cptype` | **247 / 247** | **VERIFIED against the C source**, mechanically, for every row. Blocks A and B were extracted by script from `cktsopt.c`'s `OPTtbl` and from every `cp_getvar`/`cp_getvar_policy` call site in `src/`; blocks C–G by hand from the named file |
| `site` | **247 / 247** | **VERIFIED** — the file:line each row was read from |
| `help` (block A) | **57 / 57** | **VERIFIED** — ngspice's own description string, copied out of the same table row |
| `default` (block A) | **54 / 57** | **VERIFIED** from `CKTnewTask()` (`cktntask.c:92-145`); the other three (`minbreak`, `maxopalter`, `maxevtiter`) have no application default there and carry none |
| `inert` | **16 / 16** | **VERIFIED** — every reason re-read in the fork source this pass, and the two route-dependent ones (`acct`/`list` and the other four print flags) measured on both binaries and on both routes |
| `phase` | **59 of 247 carry a phase other than `any`** | **every one of the five CLASSES was measured on both binaries with a named member** — `warn`/`maxwarns` for `deck`, `units` for `run`, `savecurrents` and `seed` for the card-text `deck` rows, `casemode` for `pre`, `soa_log` for `cmdline`. The 34 individual pre-deck rows are the dossier's own table, each corroborated against its read sites, with **one refuted** (`scale`, moved to `deck` by measurement). The remaining 188 rows are `any`, which is the default and what the dossier's own phase column says |
| `group` | **0 / 247 verified** | **TRANSCRIBED** from `evidence/options.md` §3.1 and `evidence/hidden-vars.md` §2. It is a GUI grouping, not a simulator fact |
| `scope` | **0 / 247 verified** | **TRANSCRIBED** from `evidence/options.md` §10.2 |
| `results` | **0 / 21 verified** | **TRANSCRIBED** — the Group R list from APPENDIX §3.2 |

**So: every row's type and provenance is measured; the three GUI columns are
transcribed and are labelled as such in the code.** The count that matters for
§7c's ⚠ badge — *"the 21 `results 1` rows"* — is a transcription, and a crew that
wants to stand behind that badge should re-take it.

**Behaviour measured on both binaries this pass** (the fork `ngspice-46+` at
`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, and `/usr/bin/ngspice`
`ngspice-45.2`), **fourteen probe families**, every value identical on the two:
`sqrnoise` ×5 spellings · `warn` ×7 · `maxwarns` ×3 · `keepopinfo` ×5 ·
`units` ×4 · `savecurrents` ×4 · `scale` ×3 · `wnflag` ×2 · `maxord`/`gminsteps`
×4 · `ticlist` on a `.options` card · `seed` · the six print flags on both routes
· `-D` ×6 · `casemode` ×3 (fork only, because `$curcasemode` is the fork's).

---

## The five doors, and the four impossible pairs

`door` is computed from `phase` and `cptype`. Five values, each with at least one
catalogue member (row **CA9**):

| door | spelled | when |
|---|---|---|
| `options` | `.options name` / `.options name=v` | phase `deck`, or phase `any` in the deck slot |
| `control` | `option name=v` (OPTtbl) / `set name=v` (variables) | phase `run`, or phase `any` in the block slot, or any `list` |
| `predeck` | `-D name` / `-D name=v` | phase `pre` and cptype `bool`/`string` |
| `predeck-file` | a `set` line for `<rundir>/.spiceinit` | phase `pre` and cptype `num`/`real`/`list` |
| `cmdline` | the row's own flag | phase `cmdline` |

and four pairs **raise**, each measured on both binaries:

| pair | what ngspice does today | row |
|---|---|---|
| `pre` + in-block | MEASURED on the fork (`$curcasemode` is fork-only): `.options casemode=preserve` → `fold`, and `set casemode=preserve` inside `.control` → `fold`. **Both doors ignored, in silence** (T8). `-D casemode=preserve` → `preserve` | DO4 |
| `deck` + in-block | `.options warn=1` prints the SOA violation; `set warn=1` inside `.control` prints **nothing** | DO5 |
| `run` + above-block | `set units=degrees` gives `-44.99` deg; `.options units=degrees` leaves the phase in **RADIANS** | DO6 |
| `list` + above-block | the run **ABORTS** — `ERROR: wrong format in option ticlist!  Aborting...`, rc 1 | DO7 |

---

## What the plan and the dossiers said that this refuted

Corrections **C100–C113**, continuing the C series (C92–C99 were issue 1435).

### C100 — `PLAN.md` §7a states a `door` on every row of its own catalogue excerpt, three paragraphs above the sentence forbidding it

*"`door` is computed, never typed. A row that states its door is a row that can
disagree with itself."* — and every row of the `variable sim_options` sketch
above it carries `door options`, `door options|control`, `door predeck`,
`door control`. ⚠ **Same shape as C92**: a section self-contradictory in one
screen, where a crew reading either half alone would be confident and half of
them wrong.

### C101 — and the sketch spells `phase L1`, which is an ngspice word in a column core computes from

If `ase::opt_door` reads `L1`/`L2`/`L3`, core has learned ngspice's phase
vocabulary — the exact D34 violation §7a's own paragraph is written to prevent,
sitting in the schema half. ASE-L's vocabulary is `pre`/`deck`/`run`/`any`/
`cmdline`; the adapter keeps `L1`/`L2`/`task`/`cardtext`/`frontend`/`argv` in
`ngphase`, which core never reads.

### C102 — §7b's speller switches on `cptype` alone, and that spelling moves a shipped deck

The sketch's `bool` arm returns `set $name`. `sqrnoise` is a `CP_BOOL` and what
ASE-L emits today is `.options sqrnoise`, **measured to work on both binaries**
(`onoise_total` 3.859e-07 → 1.489e-13). The spelling is a function of the
**door and the cptype together**; the door is the half the sketch dropped.

### C103 — the door table has two whole delivery classes missing, and both are silent

`PLAN.md`'s table says `options` and `control` reach *"the same set"*. Measured,
on both binaries, they do not:

* **the `deck` class** — `warn`, `maxwarns`, `probe_is_given`, `brief`, the four
  `cp_getvar` reads inside `inp_dodeck()` after the `ci_vars` boundary
  (`inp.c:1433`, `:1447`, `:1452`, `:1533`). `.options warn=1` arms the SOA check
  and prints the violation; `set warn=1` inside `.control` prints nothing,
  because the block runs *after* the circuit is loaded. `maxwarns` behaves
  identically (5 violations → 2 with `.options maxwarns=2`, still 5 with `set
  maxwarns=2`).
* **the `run` class** — the `cp_usrset` hook names (`options.c`). `set
  units=degrees` gives `-44.99`; `.options units=degrees` leaves `-0.785`
  **radians**.

⚠ **The second is the 57.2958× phase error the crew brief calls out as the trap
"no design caught"** — and the plan's own catalogue would have offered a door for
it that does not work.

### C104 — `units` is not one of the 220 at all

It is not a `cp_getvar` variable. It is intercepted in `cp_usrset`
(`options.c:419`, `eqc(var->va_name, "units") && va_type == CP_STRING`). The
plan's catalogue excerpt lists it as a row of a floor that does not contain it.
⚠ **The single most consequential option in this batch is outside the measured
floor**, which is why block C exists.

### C105 — APPENDIX §3.2 names the wrong 163rd variable

It reconciles *"a literal-string re-grep found 162 names; the 163rd is the
computed family `auto_bridge_<family>_<type>_<dir>`"*. Measured: a literal grep
over `cp_getvar` finds **162**, and adding `cp_getvar_policy()` — the fork's
policy-aware reader, `variable.c:753`, **seven call sites, one name** — brings it
to **163**. The 163rd is **`casemodewrite`**, and `hidden-vars.md`'s own §6.2
`CP_BOOL` list contains it, so the inventory was right and the reconciliation
paragraph was not. The computed `auto_bridge_*` family is a **164th** thing, in
neither count.

### C106 — the pre-deck class is 34, not 26, and `hidden-vars.md`'s own table says so

§3.2 headlines *"**26** variables, in three phases"* and then tabulates **35**:
13 L1 names, the ten `ps_*` U-device knobs, 10 L2 names, and 2 pre-L1. 35 − 26 =
the ten `ps_*`, which the count omits. They are genuinely pre-deck — read from
`initialize_udevice()` (`udevices.c:932`) via `u_instances()`
(`inpcompat.c:478`), reached from `pspice_compat()` at `inpcom.c:1475`/`:2039`,
inside the netlist read. ⚠ **`PLAN.md` §7d and the crew brief's trap table both
quote the 26**, so the GUI group §7d is asked to build is a third larger than the
plan says.

### C107 — and one of the 35, `scale`, is measured NOT pre-deck

MEASURED on both binaries: `.options scale=0.5` halves a MOS `W` — `@m1[w]`
2.0e-06 → 1.0e-06 — while `set scale=0.5` inside `.control` does nothing.
**Three committed schematics carry `.options SCALE=0.10`** — the shipped
`rom8k` example, in `xschem_library/`, `xschem_libraries_oa/` and
`xschem_libs_newsym/` — and it reaches **nine** generated netlists under
`tests/netlisting/results/`. Classifying `scale` pre-deck would have condemned a
spelling that demonstrably works and that this repo ships. The row is
`deck` with a `caveat` naming the two read sites (`subckt.c:592`, `inp.c:2689`)
that no `.options` card reaches, so a deck with subcircuits is scaled only in
part. ⚠ **This one was caught by measuring a row I had already transcribed and
was about to ship** — the *measure the exception before the rule* discipline
paying for itself inside one task.

### C108 — `rsdiode` does not exist

APPENDIX §3.2 adds *"plus `rsdiode` [crit §1.3]"* to the two diode overrides.
Measured: zero `cp_getvar` sites in the tree. `diode_cj0` and `diode_rser` are
real (`diosetup.c:89`, `:241`, `:259`); `rsdiode` is not.

### C109 — three catalogue-B variables are libngspice-only, and inert for the binary ASE-L runs

Exhaustive grep over `src/`: **`addescape`, `nosighandling` and `no_spiceinit`
are read ONLY in `src/sharedspice.c`.** The `ngspice` executable never reads any
of them. `no_spiceinit` is listed in `hidden-vars.md` §3.2's pre-deck table as a
delivery route; `nosighandling` sits in Group X as if a run could be told not to
handle signals. All three now carry `inert` with that reason, and the speller
refuses them.

### C110 — the six front-end print flags do nothing on ASE-L's route, and a committed bench sets two of them

MEASURED on both binaries, both routes. A dot-card deck with `.options acct
list` adds **10** lines of accounting and element summary; the identical deck
with its analysis inside `.control` adds **none**. `opts` adds 22 lines on a
dot-card deck and 0 in `.control`; `nomod` removes 56 and 0. `node` and `nopage`
change nothing on either route here. One committed `.state` carries
`{name acct value 1} {name list value 1}`. ⚠ **Same shape as `oldlimit`** — an
option that works from a dot card and is dropped on the `.control` route ASE-L
uses — and nothing in any dossier had noticed the other five.

### C111 — `hidden-vars.md` §6.1's Trap-2 table reads as if `set warn=1` fires inside `.control`

Its rows are `set warn` → 0 warnings, `set warn=1` → 1 warning. MEASURED on both
binaries: **inside `.control`, `set warn=1` gives 0**, and so do `set warn`,
`set warn=1.0` and `set warn="1"`. The trap is real — a `CP_NUM` needs
`=<number>` — but it is only observable through the `.options` door, and §3.1 of
the same file says so. Two sections of one dossier, and the reader who takes the
trap table literally builds the wrong door.

### C112 — the shipped emitter's two spellings, above

Defects 2 and 3 of the headline. `render_deck`'s rule — bare card for `1`,
`name=value` otherwise, skip on `0` — is right for a flag and wrong for every
valued option a user sets to `1` or to `0`.

### C113 — `ase::option_enabled` and the speller disagreed about an empty value

`option_enabled`'s arm was `$v eq {0} ? 0 : 1`, which answers **ON** for a row
stored with an empty value, while `ase::opt_line` writes no line for one. Two
predicates disagreeing about whether a switch is on is exactly the eight-copies
defect this batch exists to delete. They are now one body, `ase::opt_truthy`. No
committed `.state` and no fixture stores an empty value; what the old arm bought
for one was `.options <name>=`, a card with no value on it.

---

## The sabotage campaign

**Thirty-six respellings**, each a plausible rewrite rather than a break — the
tidy-up somebody would actually make, and **ten of them reproduce a claim
`PLAN.md` or a dossier actually makes** — S02 and S03 (the door table's *"same
set"*), S06 (§7b's `cptype`-only switch), S07 (§7b's `{1 true yes on}`), S22
(`gminsteps` 10), S25 (the appendix's 163rd name), S26 (`units` as a catalogue
row), S28, S31 and S35 (the dossier's pre-deck table). Restore was `cp` from `/tmp/s7t1/sab/good_ase.tcl`
with an **md5 compare after every application**, the campaign aborts on a restore
mismatch rather than continuing, and anchor uniqueness was checked against the
pristine file **before** the campaign started: 36/36 unique. Every application ran
**two** suites — the new one and `test_ase_core`, which is the file the shared
`ase::opt_truthy` reaches.

**Forty applications in all (36 + 4 re-runs), 40/40 restored, ZERO KILLS, and
after the re-runs ZERO SURVIVORS.** The working tree was owned by the campaign
while it ran and no source file was edited during it.

| # | the respelling | rows reddened |
|---|---|---|
| S01 | opt_door: a pre-deck option quietly takes -D in the block too | DO4 |
| S02 | opt_door: a deck-load option is allowed in the block (both doors work) | DO5 |
| S03 | opt_door: a run-phase option is allowed above the block | DO6 |
| S04 | opt_door: a list takes whatever slot was asked for | BR5 CA6 DO7 |
| S05 | opt_door: every pre-deck option goes through the run-directory file | DO2 SP6 |
| S06 | opt_line: the plan's sketch -- switch on cptype alone | BR5 SP6 |
| S07 | opt_line: the plan's truthy list, {1 true yes on} — **survived pass 1**; reddens after the row below was written | **SP13c** |
| S08 | opt_line: an empty value writes the bare card | SP4 |
| S09 | opt_line: zero means off for a valued option too | BR4 SP5 |
| S10 | opt_line: the inert refusal is dropped (the GUI disables the field anyway) | CA6 IN2 IN3 IN4 |
| S11 | opt_line: an unknown name falls back to the .options spelling | HK3 SP12 |
| S12 | opt_template: the argv flag moves into the shared table | SP11 |
| S13 | opt_truthy: an empty value counts as on | SP13 SP14 |
| S14 | option_enabled goes back to its own equality test | SP14 |
| S15 | opt_restore_line: a flag restores by writing its default | RS1 RS2 RS5 |
| S16 | opt_restore_line builds its own line instead of calling the speller | HK3 RS1 RS5 |
| S17 | option_schema_errors stops complaining about a row with no cptype | CA7 |
| S18 | state_option_delivery reports only names it does not know | DL1 DL5 |
| S19 | state_option_delivery refuses an unknown name instead of reporting it | DL2 |
| S20 | opt_phase: a row that says nothing is assumed pre-deck — **survived pass 1**; reddens after the row below was written | **CB6b** |
| S21 | opt_is_pre_deck also counts the deck-load class | CB6 DO10 |
| S22 | catalogue: gminsteps defaults to 10, as the manual reads | CB1 RS1 |
| S23 | catalogue: the defas defect note is dropped | CB2 |
| S24 | catalogue: the itl4 widget minimum is dropped | CB3 |
| S25 | catalogue: casemodewrite is dropped (a cp_getvar grep does not find it) | CB4 |
| S26 | catalogue: units is dropped (it is not one of the 220) | CB5 DO6 |
| S27 | catalogue: wnflag is an ordinary option after all | CB6 DL1 DL5 DO2 SP7 |
| S28 | option_spell: a bool takes a value, like everything else — **survived pass 1**; reddens after the row below was written | **SP3b** |
| S29 | option_spell: -D learns to carry a number | SP8 |
| S30 | option_spell: .options learns a list form | SP10 SP9 |
| S31 | option_spell: an OPTtbl keyword in the block is spelled with set — **survived pass 1**; reddens after the row below was written | **SP1b** |
| S32 | catalogue: acct is a live option after all -- it is in a committed bench | DL3 DL5 IN1 IN5 |
| S33 | catalogue: the nosavecurrents tombstone is removed | IN1 IN4 |
| S34 | catalogue: soa_log loses its argv spelling | CA6 SP11 |
| S35 | catalogue: scale is pre-deck after all, as the dossier's table lists it | CB6 CB7 |
| S36 | catalogue: the scale partial-coverage caveat is dropped | CB7 |

### ⚠ FOUR SURVIVED PASS 1, AND ALL FOUR ARE THE SAME DEFECT IN THE SUITE

*A row whose fixtures never disagree cannot fail* — the **eleventh**, twelfth,
thirteenth and fourteenth times in this batch. Each was a **line whose failure
mode needed a state no fixture built**, and the honest fix is the one the brief
names: build the state, never delete the line.

| survivor | why nothing moved | the row written for it |
|---|---|---|
| **S07** — `ase::opt_line` uses the plan's `{1 true yes on}` membership test instead of `ase::opt_truthy` | no row typed a value *outside* that list into the speller. A user who types `2` gets no card while `ase::option_enabled` and `render_deck` both read `2` as ON | **SP13c** — the speller writes a flag for exactly the values `option_enabled` calls on, over ten values |
| **S20** — `ase::opt_phase` defaults to `pre` instead of `any` | **all 247 ngspice rows declare a phase**, so the default is unreachable through this simulator. It is not decoration: it is what a second adapter's descriptor gets when it omits the key, which is what D37's paper validation does | **CB6b** — a stand-in backend whose one row declares only a `cptype` |
| **S28** — the `options` door's `bool` template gains `=@value` | every bool row tested either an `optflag` or the **control** door. Nothing spelled a `CP_BOOL` through the `.options` door — **the line ASE-L emits for `sqrnoise` today** | **SP3b** — `.options sqrnoise` with no value, in both doors, and no value produces an `=` |
| **S31** — an `OPTtbl` flag in the block is spelled `set` instead of `option` | ⚠ **and ngspice's own behaviour would not have caught it either.** MEASURED on both binaries, `$plots` after an `ac`: `option keepopinfo` → `const op1 ac1`, and **`set keepopinfo` → `const op1 ac1` as well**, because `cp_vset` forwards an `OPTtbl` name to `if_option`. `option` is the documented command and the one a second simulator can be asked for; `set` is ngspice's coincidence | **SP1b** — an `OPTtbl` flag inside the block is written with the `option` command |

⚠ **S31 is the one to remember.** Three of the four survivors were fixtures that
never exercised a line. The fourth was a respelling the **simulator accepts**, so
no amount of running ngspice would have revealed it — only a row that states
which mechanism ASE-L means. **A test that only asks "does the simulator do the
right thing" cannot see a portability defect.**

### C114 — and the suite found four of its own rows unfalsifiable, one of them because ngspice is forgiving

The four pass-1 survivors above. ⚠ **S31 is the new shape**: three of them were
fixtures that never exercised a line, and the fourth was a respelling **the
simulator accepts** — `set keepopinfo` reaches a task option on both binaries
because `cp_vset` forwards `OPTtbl` names to `if_option`. **A test that only asks
"does the simulator do the right thing" cannot see a portability defect**, and no
amount of running ngspice would have revealed this one.

---

## Suites moved, before → after

| suite | headless | display (`:99`) | in T1? |
|---|---|---|---|
| **`test_ase_options_1437`** (new) | — → **75** | — → **75** | **yes** — added to `tests/run_regression.tcl`'s `hcases` in this change |
| every other ASE suite | unmoved | unmoved | unchanged |

**NO EXISTING ROW IN ANY SUITE MOVED.** The whole ASE family (31 suites) was run
headless through `tests/headless/run_suites.sh` **twice — once before the
`option_enabled` unification and once after every edit — with identical
results**: **28 PASS, 2 self-skips**
(`test_ase_dirty`, `test_ase_log_seam_0207` — each says in its own first line it
needs an X connection) and **1 known red**, `test_cosim_golden_e2e` 45 passed /
1 failed, row **GE24**, issue **1431**, the one-timestep VCD boundary — unchanged,
and not in T1. `test_ase_core` **598**, `test_ase_preflight` **235**,
`test_ase_persist` **44**, `test_ase_dialogs` headless **37**,
`test_ase_simreg_0931` **111**, `test_ase_simcaps_0948` **199**,
`test_ase_optier_0963` **108** (it did not flap — issue 1402), all unmoved.

**NO DECK GOLDEN MOVED AND NO `.state` FILE MOVED.** `render_deck` is byte
unmoved, no state key was added, `ase::state_default` still seeds exactly four
rows, no `seed_enabled` anywhere, and section **CP** of `test_ase_core.tcl` — the
row that would notice a byte in the 104 committed `.state` files — is green.

---

## What I did NOT ship, and why

* **Any change to `render_deck`.** The three live defects above are *emitter*
  defects and the emitter's option block belongs to §7c/§7d/§7e, which own the
  surface that decides what a user is allowed to type. Fixing `wnflag` needs
  `<rundir>/.spiceinit`, which is **task 2's** whole subject (⚖ R2's four
  conditions); fixing the bare-card and dropped-zero spellings moves decks for a
  GUI that does not exist yet. **Section BR pins the blast radius by name
  instead**, and row **BR6** asserts the emitter is still spelling the bare card,
  so the day it changes, this file says so.
* **§7c's surface** — no search box, no changed-only view, no ⚠ badge, no deck
  preview pane. Task 3. **Nothing here draws a pixel**, so this task incurs **no
  `look` debt**; task 3 is where the plan's *"largest new pane"* debt is owed.
* **§7d's pre-deck delivery** — no `.spiceinit` writer, no `-D` arm in `run_cmd`,
  no `-n` refusal, no shared-rundir refusal. Task 2. ⚠ **So the six
  `test_ase_simreg_0931` rows that move "the first time `-D` is emitted" have NOT
  moved**, and re-baselining them is still task 2's to budget.
* **§7e's emit-then-restore** — `ase::opt_restore_line` exists because it is the
  speller applied to the default and it is what makes the `default` column
  load-bearing; **where it is called is task 4's.**
* **§7f's `option`/`set` read-back** and **§7g's four `caps`-reading rules.**
  Task 4.
* **`help` text for the 190 rows outside block A.** Every one would be a new
  user-facing sentence and therefore the user's to ratify (⚖ R9); minting 190 of
  them unasked would be the largest unratified copy drop in the batch. Block A's
  57 carry ngspice's *own* description strings verbatim, which are not ASE-L copy.
* **`acct`, `list`, `nomod`, `nopage`, `node`, `opts` as live options.** They are
  in the catalogue as inert rows with the measured reason, which is D24's third
  shape and the same treatment `oldlimit` gets.

---

## What this task learned that binds later stages

**A COLUMN THE PLAN CALLS SCHEMA CAN BE CONTENT WEARING A SCHEMA NAME.** `door`
is ASE-L's column and `phase` is ASE-L's column — and the plan's sketch fills
`phase` with `L1`, an ngspice word, and then has core compute `door` from it.
The naming rule the batch already has (`ase::` is schema, `ase::backend::<sim>::`
is content) is **lexical about procs and silent about dict keys**. ⚠ **When a
core proc computes from a column, that column's VOCABULARY is core's too** — and
the check is to read the values, not the key name.

**A TABLE WITH ONE MEMBER PER KEY IS NOT A TABLE.** The `cmdline` door reads the
row, not the shared spelling table, because `--soa-log=<file>` is not an instance
of any pattern. D43's *"a table with no key"* has a mirror image: a key with no
table. The tell is the same — you find yourself writing one entry per row.

**MEASURE THE ROW YOU TRANSCRIBED CONFIDENTLY.** `scale` was in the dossier's own
pre-deck table, with a caveat that said the opposite two lines later, and I had
already shipped it as pre-deck. One three-line probe on both binaries refuted it,
and the shipped `rom8k` example would have been reported as broken by a checker
that was itself wrong. ⚠ **The row that a document annotates with "but…" is the
row to measure**, because the annotation is the author telling you they were not
sure either.

**AND THE CLASS YOU CANNOT SEE IS THE ONE WITH NO MEMBER IN YOUR CATALOGUE.**
The `run`-only class exists because `units` exists, and `units` is not one of the
220 — so a crew that built exactly the plan's floor would have had a door table
with no member for that door, no row to test it with, and no reason to discover
it. ⚠ **Before trusting a taxonomy, look for the class with zero members and ask
whether the members are missing or the class is.**

---

## Rulings

⚖ **R9 — new user-facing copy, filed as `owed.sh add rule 1437`** at the moment
it was incurred, pointing at `doc/claude/issues/1437-*.md`:

1. the speller's **seven refusals** — unknown option; inert option (which quotes
   the row's reason); the three impossible (phase, slot) pairs; no template for a
   cptype through a door; a slot that is neither `deck` nor `control`;
2. `ase::state_option_delivery`'s **three report reasons**;
3. the catalogue's **sixteen inert reasons**, which §7d will show beside a
   disabled row, and the **`defas` DRAIN-area sentence**;
4. **five help lines ASE-L wrote** — `savecurrents`, `seed`, `seedinfo`,
   `soa_log`, `units`. Block A's 57 are ngspice's own text.

**Batch with 1426, 1427, 1428, 1429, 1430, 1432, 1433, 1434 and 1435, which are
all still waiting.**

**NO `look` DEBT.** Nothing in this task draws a pixel: it is a catalogue, a
speller and a suite. §7c owns the pane and owns that debt.

⚖ R2 is **answered** (yes, four conditions) and its machinery is task 2's. ⚖ R3
is **answered** (Option C). ⚖ R4 is **open** and nothing here is gated on it —
nothing was seeded and no `seed_enabled` was added.

⚠ **THE LEDGER WAS BACKED UP FIRST**, per `CLAUDE.md`'s one-ledger-every-clone
paragraph, to `/tmp/s7t1/owed_backup/xschem_owed` (**155 rule / 57 look / 9
suite** at the time); after the add it reads **156 / 57 / 9**. Measured
immediately before the add: `/usr/bin/grep -L '^repo:'` over the three
directories prints the **same four unstamped entries** issues 1430–1435 have each
reported (`rule/1357`, `rule/1357@xschem-claude`,
`look/hier_pdf_nav_1357_H6.1789071932.2875683`,
`suite/test_hier_pdf_links_1333`), and the stamp split is **204 this clone / 13
op-wcard**. ⚠ The op-wcard count has now been **13 across six receipts** while
this clone's has moved 197 → 199 → 200 → 202 → 204 → 205.

---

## For the driver

* **T1 was NOT run by this crew** (issue 0990 — the driver runs it solo). ⚠ **T1's
  membership changed in this commit**: `tests/run_regression.tcl`'s `hcases`
  gains `headless/test_ase_options_1437`, so T1 now runs **75 more checks** than
  it did at `08774b2b`. Nothing else in that file moved.
* **Nothing was committed, added, stashed, restored, cleaned or pushed.** No
  `git checkout --`, no `git restore`, no `git stash`, no `git clean`, no
  `git commit`, no `git push`, no PR. The working tree is the one handed over
  plus **three modified files** (`src/ase.tcl`, `tests/run_regression.tcl`,
  `doc/claude/issues/NUMBERING.md`) and **three new ones**
  (`tests/headless/test_ase_options_1437.tcl`, the issue file, this receipt).
  The four untracked paths inherited at `08774b2b` — `.xschem/`,
  `doc/claude/rdw_lists_batch/`, `doc/claude/rdw_sim_batch/`,
  `sky130A/.../debug_st1/` — are untouched.
* **`NUMBERING.md`'s pointer was advanced 1437 → 1438** in the same change as the
  entry. **Both mint checks were run at the moment of minting**: the
  reserved-band scan over this clone's head table (**silent** for 1437) and
  `ls ~/dev/*/doc/claude/issues/1437-*` plus `/usr/bin/grep -lw 1437` across
  **every** clone's `NUMBERING.md` — only this clone's own pointer line came
  back. `1438` was checked clean at the same time.
* ✅ **THE NEW SUITE IS IN T1 AND ITS TWO ARMS AGREE**: **75 headless, 75 on
  `:99`**, taken through `tests/headless/run_suites.sh`, which reported *"display
  arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0"* —
  `devdisplay.sh status` before and after: alive, **openbox (Openbox 3.6.1)**,
  `1920x1080x24`. There is no widget in this file, so the arms are expected to
  agree and the row count says they do.
* ⚠ **NO SIMULATOR IS STARTED BY THE FEATURE, BUT THIRTY-ONE PROBES WERE RUN TO
  BUILD IT, ON BOTH BINARIES.** The catalogue is data and the speller is string
  substitution; neither starts a program. The crew brief's both-binaries rule was
  therefore discharged by **measuring every ngspice claim the catalogue rests on
  against both** — `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
  (`ngspice-46+`) and `/usr/bin/ngspice` (`ngspice-45.2`) — and **every value was
  identical on the two**, including the four silent failures the doors are built
  from. Where a claim is about the C source rather than behaviour, the row and
  this receipt name the file and line.
* **Machine rules honoured throughout**: every xschem invocation was given a path
  (`./src/xschem`) and `--nolog`, never `--logdir`, never a bare `xschem`; **no
  bench under `sky130A/` was run** and no simulation touched `~/.xschem/` —
  every ngspice probe ran on a scratch deck under `/tmp/s7t1/probe` with that
  directory as its own cwd; every bespoke command carried a `timeout` and every
  waiting loop a deadline; `tests/run_regression.tcl` was not run.
* ⚠ **`~/.xschem/geometry` WILL HAVE BEEN WRITTEN AGAIN** by the display arm —
  issue **1397**, already on the user's queue and already reported by the 1430,
  1432, 1433, 1434 and 1435 crews. Every headless invocation here carried
  `--nogui`; the write comes from `run_suites.sh`'s display arm opening a real
  window that saves its size on exit. **Nothing else under `~/.xschem/` was
  touched**, and the repo's own `.xschem/op_param_lists.conf` is unmodified.
* **No file was created in the repo root**, and `git status` carries no stray.
* ⚠ **THE SIX `test_ase_simreg_0931` ROWS HAVE NOT MOVED**, and the plan expects
  them to move *"the first time `-D` is emitted for an option"*. Nothing emits
  `-D` yet — `ase::opt_line` can spell it, and `run_cmd` does not call it. That
  re-baseline is **task 2's** to budget, exactly as `PLAN.md` §7 says, and
  `test_ase_simreg_0931` is **ALL PASS (111)** here.
* **The next task is 2 of 4 — `PLAN.md` §7d**, the pre-deck class and the inert
  list. It inherits from here: the 34-row pre-deck group is already a predicate
  (`ase::opt_is_pre_deck`), the two doors it needs are already computed
  (`predeck` → `-D`, `predeck-file` → the run-directory file) and already spelled
  (`ase::opt_line`), the sixteen inert rows already carry their reasons, and
  `ase::state_option_delivery` already names every stored option that cannot
  reach the simulator. What it has to build is the **delivery**: `spiceinit_write`,
  `run_cmd`'s `-D` arm, ⚖ R2's four conditions, and the two refusals.
