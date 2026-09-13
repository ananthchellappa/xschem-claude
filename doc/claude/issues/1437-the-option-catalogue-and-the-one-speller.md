# 1437 — the option catalogue, and the one speller that makes its columns type errors

**Stage 7 of the ASE-L analyses batch, task 1 of 4 (`PLAN.md` §7a + §7b).** Batch:
`doc/claude/ase_analyses_batch/`; receipt
`doc/claude/ase_analyses_batch/receipts/19-stage-7-catalogue.md`.

## The defect

**There is no error channel for a misspelled or misdelivered option on ASE-L's
route.** Measured on both preflight binaries: a deck carrying `.options
bogusdot=1` above the block and `option bogusopt=3` inside it prints **nothing on
either stream**, and a trailing bare `set` lists both names — silently invented as
variables. The `Error: unknown option %s - ignored` branch exists
(`inpdoopt.c:69-78`) and **neither route ASE-L takes reaches it**.

So the only defence is knowing what class a name belongs to **before** the line is
written. ASE-L knew nothing: `render_deck`'s option loop spelled every stored row
by one rule — bare card for `1`, `name=value` otherwise, skip on `0` — and three
silent wrong answers are live in the shipped tree because of it.

### 1. Five committed benches ask for `wnflag` and none of them gets it

`wnflag` decides whether a MOS `W` is the total width or the width per finger. It
is read inside `inp_readall()` (`inpcom.c:990`), **before any `.options` card
exists**, and it is a `CP_NUM`, which a bare `set` cannot answer. `.options
wnflag` — the line ASE-L writes for `{name wnflag value 1}` — is the wrong door
**twice over**. `git ls-files | grep '\.state$'` finds **five** such benches.

### 2. A valued option stored as `1` is written as a bare card

MEASURED on both binaries: `.options maxord=1` gives `MaxOrder = 1`; `.options
maxord` leaves it at **2**. The user typed 1 and got 2.

### 3. A valued option stored as `0` is dropped

MEASURED on both binaries: `.options gminsteps=0` gives `gminsteps = 0` and
disables gmin stepping; writing nothing leaves it at **1** (`cktntask.c:121`).
`PLAN.md` §7b predicted exactly this defect *"inside its own antidote"*; it is
older than the prediction and it is in the emitter.

## The fix

**A 247-row catalogue declared as the ngspice adapter's CONTENT, and one speller
in ASE-L's SCHEMA whose refusals are the traps** (D23, D24, D33's amendment,
D34–D37).

### The content half — `ase::backend::ngspice`

`variable sim_options`, reached **only** through the new optional `sim_options`
hook, plus an `option_spell` hook carrying the (door × cptype) template table.
Core never names the variable and a backend with no hook gets `{}` — never a
literal fallback.

Generated once from the ngspice C source and hand-maintained after; every row
carries the `site` it was read from:

| block | rows | what |
|---|---|---|
| A | **57** | settable `OPTtbl` keywords, `cptype` from the row's own `IF_` bit, `help` ngspice's own description verbatim |
| B | **163** | `cp_getvar` variables, `cptype` from the `CP_` constant at the call site |
| C | **13** | `cp_usrset` hook variables (`options.c`), **not in the plan's floor** — `units` is one of them |
| D | **6** | card-text pseudo-options (`savecurrents*`, `seed`, `seedinfo`) |
| E | **1** | the one argv-delivered option, `--soa-log=` |
| F | **1** | `nosavecurrents`, a tombstone |
| G | **6** | the front-end print flags, inert on the `.control` route |

A ∩ B is **empty**, re-measured: 98 + 163 = 261 distinct names.

### The schema half — `ase::`

`ase::sim_options`, `ase::sim_option_entry`, `ase::sim_option_names`,
`ase::sim_option_spell`, `ase::opt_truthy`, `ase::opt_phase`, `ase::opt_inert`,
`ase::opt_is_pre_deck`, `ase::opt_door`, `ase::opt_template`, `ase::opt_line`,
`ase::opt_default`, `ase::opt_restore_line`, `ase::option_schema_errors`,
`ase::state_option_delivery`.

**The door is computed, never typed**, from `phase` and `cptype`. ⚠ `PLAN.md`'s
own catalogue excerpt **states a door on every row**, three paragraphs above the
sentence forbidding it, and it spells `phase L1` — an ngspice word in a column
core computes from. ASE-L's phase vocabulary is `pre` / `deck` / `run` / `any` /
`cmdline`; the adapter keeps `L1`/`L2`/`L3`/`task` in `ngphase`, which core never
reads.

**`ase::opt_line` is the one speller**, and it switches on **(door, cptype)**, not
on `cptype` alone. The plan's sketch switches on `cptype` and therefore spells
every `bool` as `set <name>`; `sqrnoise` is a bool and ASE-L emits `.options
sqrnoise` today, measured to work on both binaries. The door is the half the
sketch dropped.

## Why this is a type error and not a guard

A template with **no `@value` slot** cannot produce `set sqrnoise=1`, so T3 is
unreachable rather than defended against. The `predeck` door declares **no**
`num`/`real`/`list` template, so T5 dies twice (`opt_door` never routes one there
either). The `options` door declares **no** `list` template, because a list on a
`.options` card does not get ignored — `inp.c:1407-1411` reaches
`controlled_exit(EXIT_FAILURE)`.

And four **(phase, slot)** pairs are impossible, each measured on both binaries:

| pair | what happens today |
|---|---|
| `pre` + in-block | `.options casemode=preserve` and `set casemode` in the block are both ignored, silently (T8) |
| `deck` + in-block | `.options warn=1` arms the SOA check; `set warn=1` inside `.control` does **nothing** — the block runs after the circuit is loaded |
| `run` + above-block | `set units=degrees` gives `-44.99` deg; `.options units=degrees` leaves the phase in **RADIANS** |
| `list` + above-block | the run **aborts**, rc 1 |

⚠ **The middle two are classes `PLAN.md`'s door table does not have.** Its table
says `options` and `control` reach "the same set"; measured, they do not.

## Two counts the dossiers got wrong

**The pre-deck class is 34, not 26.** `hidden-vars.md` §3.2 headlines *"26
variables, in three phases"* and then tabulates **35** — its count omits the ten
`ps_*` U-device knobs, which are read from `initialize_udevice()`
(`udevices.c:932`) via `u_instances()` (`inpcompat.c:478`), inside the netlist
read. `PLAN.md` §7d and the crew brief's trap table both quote the 26.

**And the 35th, `scale`, is measured NOT pre-deck.** `.options scale=0.5` halves
a MOS `W` on both binaries (`@m1[w]` 2.0e-06 → 1.0e-06); `set scale=0.5` inside
`.control` does nothing. Three committed schematics — the shipped `rom8k`
example — carry `.options SCALE=0.10`. Its row is `deck` with a `caveat` naming
the two read sites (`subckt.c:592`, `inp.c:2689`) that no `.options` card
reaches, so a deck with subcircuits is scaled only in part.

**APPENDIX §3.2 names the wrong 163rd `cp_getvar` variable.** A literal grep
finds 162; the 163rd is **`casemodewrite`**, read through `cp_getvar_policy()`
(`variable.c:753`, seven call sites, one name), not the computed `auto_bridge_*`
family — which is a 164th thing, in neither count. `hidden-vars.md`'s own §6.2
`CP_BOOL` list already contains it, so the inventory was right and the
reconciliation paragraph was not.

**`rsdiode` does not exist.** APPENDIX §3.2 lists it beside `diode_cj0` and
`diode_rser`; measured, it has zero `cp_getvar` sites in this tree.

**Three catalogue-B variables are libngspice-only.** `addescape`,
`nosighandling` and `no_spiceinit` are read **only** in `src/sharedspice.c`. The
`ngspice` executable ASE-L runs never reads any of them; all three now carry
`inert` and the speller refuses them.

**And the six front-end print flags do nothing on ASE-L's route.** MEASURED on
both binaries and both routes: a dot-card deck with `.options acct list` adds ten
lines of accounting and element summary; the identical deck with its analysis
inside `.control` adds none. One committed `.state` carries `{name acct value 1}
{name list value 1}`. Same shape as `oldlimit`.

## What did NOT change

**`render_deck` is untouched.** No deck golden moved, no `.state` file moved, no
new state key, no `seed_enabled`, `ase::state_default` still seeds exactly four
rows, and the 104 committed `.state` files are byte-identical. Rewiring the
emitter is §7c/§7d/§7e's, and section BR of the suite pins the exact blast radius
by name so that crew does not re-derive it.

One behaviour did change, deliberately: **`ase::option_enabled` now calls
`ase::opt_truthy`**, so an option row stored with an **empty** value reads OFF
rather than ON. It read ON before, while the speller writes no line for one — two
predicates disagreeing about whether a switch is on. No committed `.state` file
and no fixture stores an empty value; what the old arm bought for one was
`.options <name>=`, a card with no value on it.

## Suite

New: `tests/headless/test_ase_options_1437.tcl`, **75 checks**, sections CA / CB /
DO / SP / IN / HK / BR / DL / RS / PR, registered in `tests/run_regression.tcl`'s
`hcases`, so **T1 covers all 75**. Identical on both arms — there is no widget
here.
