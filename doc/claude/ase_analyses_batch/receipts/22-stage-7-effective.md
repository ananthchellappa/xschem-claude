# Stage 7 task 4 — a scope the simulator does not have, a channel that was half broken, and the four rules

**One commit, issue 1442, and the LAST of Stage 7's four tasks.** Scope was
`PLAN.md` **§7e + §7f + §7g** and nothing else; §7a+§7b landed as task 1
(`d2f4437a`, issue 1437), §7d as task 2 (`98beb2b5`, 1439), §7c as task 3
(`f91c36ae`, 1441).

**Floor:** new suite `test_ase_effective_1442` — **92 checks, identical on both
arms** — registered in `tests/run_regression.tcl`'s **`hcases` only**, and
deliberately not in `dcases` (its UI rows drive two *pure* procs and create no
widget, so the display arm would be a weaker measurement of the same thing
rather than a bigger one — the half of issue 1405's distinction that argues for
leaving a suite out).

**`src/ase.tcl` 20614 → 21792** (+1178); **`src/ase_window.tcl` 9273 → 9328**
(+55). Four new optional adapter hooks, thirty new `ase::` procs, two new
`analysis_needs` preconditions, one rewritten one.

---

## ⚠ THE HEADLINE: HALF OF §7f's RECIPE WRITES NOTHING, AND THE MISSING HALF ALWAYS DIFFS CLEAN

The brief named this as the load-bearing claim and told me to re-measure it. I
did, and the measurement went further than the brief expected: the *reason* for
the leg is confirmed, and the plan's *mechanism* for it is refuted.

`PLAN.md` §7f writes the channel as

```
option   > <cell>_ase.effective
set     >> <cell>_ase.effective
```

**MEASURED 2026-09-13 on BOTH binaries, in ONE deck, with `echo … > f` and
`print … > f` beside them as positive controls** — because a null result here is
exactly the answer that looks the same whether you measured or not (C133):

| command | bytes |
|---|---|
| `echo POSITIVE-CONTROL-ECHO > f` | **22** |
| `print v(mid) > f` | **22** |
| `set >> f` | **440 / 450** |
| **`option > f`** | **0** |

`com_option.c` writes its entire dump with bare `printf` — stdout — while
ngspice's `>` rebinds `cp_out`, which is what `out_printf` uses and what makes
`set`'s redirection work. So `option > file` cannot capture anything **by
construction**, on every ngspice that has this file.

⚠ **A deck built to the plan's recipe would have produced a plausible,
half-empty sidecar, and the half that was missing is the one that reports the
TASK** — `reltol (current) = 0.05`, `itl4 (transient iterations) = 7`,
`Integration Method = GEAR`. A diff over a half that was never written is clean,
always. That is C133's vacuity defect living inside the feature written to cure
it.

**What shipped instead**, each half through the door measured to work:

```
echo ASE-EFFECTIVE-BEGIN      ->  the run log (stdout), which ASE-L already captures whole
option
echo ASE-EFFECTIVE-END
set >> <cell>_ase.effective   ->  the sidecar, which redirection reaches
```

---

## ⚠ WHAT I VERIFIED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| `option >` writes zero bytes; `set >>` works | **MEASURED on both binaries**, one deck, with `echo >` and `print >` as positive controls in the same deck. Source-confirmed: `com_option.c` uses bare `printf`, `cp_vprint` uses `out_printf` |
| there is no error channel for a misspelled option | **RE-MEASURED on both binaries** with `.options reltol=0.05` → `reltol (current) = 0.05` as the positive control. `.options bogusdot=1` + `option bogusopt=3`, and `.options frobnicate` + `.op`, print **not one word**. The branch is at `inpdoopt.c:75` (the plan says 74-78; it is :75 for the message and **:77 for an `fprintf(stderr,…)` the plan does not mention**) and neither route reaches it |
| a flag CAN be restored, so §7e's mechanism is real | **MEASURED on both binaries** with §7e's own example: `option keepopinfo` then `ac` gains `op1 ac2`; `option keepopinfo=0` then `ac` gains only `ac3`. **Source-generalised**: every `IF_FLAG` arm in `cktsopt.c` is `(val->iValue != 0)` |
| `OPT_SPARSE` is inverted | **SOURCE-READ**, `cktsopt.c:181` — `task->TSKkluMODE = (val->iValue == 0)`. Not separately measured; recorded on the row as a warning |
| the KLU suppression works and costs nothing | **MEASURED on both binaries** on the deck shape ASE-L writes: unsuppressed **rc 139 SIGSEGV**, suppressed **rc 0** with the solver reading KLU / sparse / KLU across three jobs, and the `sens` output **byte-identical** (diff of 216 lines → zero, once the deck title comment is excluded) to a deck that never asked for KLU |
| `option` reports the LAST JOB's solver, not the request | **MEASURED on both binaries** — `option klu` then `option` still says `Sparse 1.3`; after one job it says `KLU`. Source: `cktdojob.c:113` copies `TSKkluMODE` into `CKTkluMODE` at job start |
| **`option` prints the temperature in KELVIN** | **MEASURED on both binaries** — `.options temp=40` reads back `313.150000`. ⚠ **The catalogue's own comment says the opposite** ("read back in CELSIUS … the number the user types and the number `option` prints back"). Refuted; see C137 |
| `ac lin 2` yields one point | **MEASURED on both binaries** with `lin 3` → 3 and `dec 2` → 3 as positive controls. `lin 1` → 1, which is honest and is why the rule fires on 2 alone |
| D4 does not reach ASE-L's deck | **SOURCE-READ AND VERIFIED**: `outitf.c:1011`/`:1190` is the `-r` writer with the 8-character field; `rawfile.c:209` is the `write` command with none. Verified on both binaries — a 1008-point `write` gives `No. Points: 1008`, unpadded |
| the `set` dump's prefix is the door | **SOURCE-READ** (`variable.c:1221-1240`, `cp_vprint`) **AND MEASURED** — `.options bogusdot=1` → `+ bogusdot 1`, `option bogusopt=3` → `  bogusopt 3`, one deck |
| 12 of 13 catalogue-unknown dumped names are ngspice's own | **MEASURED** on the end-to-end deck's real artifacts |
| **60** of 247 rows carry a `default` | **COUNTED** live, two independent routes agreeing (`ase::opt_default` non-empty, and `dict exists … default`), with `reltol`→`1e-3` and `wnflag`→`{}` as positive and negative controls |
| `filetype` is the only CIDER `cp_getvar` variable | **VERIFIED BY GREP** over the whole of `src/ciderlib`, and `src/ciderlib` is built only under `--enable-cider` (`configure.ac:1215`, `src/Makefile.am:15`) |
| §7g rule 2 is already shipped | **CONFIRMED, not re-implemented** — row RU5 asserts `vecsaves` is still the `caution` issue 1434 shipped |
| `group` is still 0/247 verified; `scope` cannot be measured | **INHERITED from task 3 and not re-derived.** Nothing in this task depends on either: §7e reads `scope` only to decide which rows a per-analysis surface lists, and the global surface still offers every row |

---

## What shipped — the SCHEMA half (`src/ase.tcl`, `ase::`)

**§7e — per-analysis scope**

| proc | what it answers |
|---|---|
| `opt_restore_spell` / `opt_restore_template` | the adapter's REVERSE spelling table, or `{}` |
| `opt_restore_line` | **repaired** — a flag now restores with an explicit zero |
| `opt_restorable` | `yes`, or `{no nodefault|nospelling|inert|owned|unknown}` |
| `opt_row_analysis` | a stored row's analysis scope, or `{}` for a global row |
| `opt_scope_plan` | per analysis: `scoped` / `leaks` / `refused`, with both lines |
| `opt_scope_lines` | the `pre` and `post` blocks, `post` in reverse order |
| `opt_analysis_verdict` | what the surface says: `scoped` / `{leaks why}` / `global` |
| `opt_scoped_names`, `opt_leak_why`, `preview_analysis_types` | the surface's readers |

**§7f — requested versus effective**

`effective_path`, `effective_marker`, `effective_region`, `effective_parse_vars`,
`effective_parse_task`, `effective_read`, `effective_lookup`, `effective_same`,
`effective_diff`, `effective_coverage`, `effective_report`, `effective_armed`,
`opt_door_reported`.

**§7g** — `opt_gate_state`, `opt_gate_why`, `opt_door_phrase`,
`analysis_suppress`, `analysis_suppresses`, `analysis_suppress_lines`,
`analysis_point_estimate`, plus the `lin_points` and `points_max` preconditions
and a rewritten `sens_klu`.

## What shipped — the CONTENT half (`ase::backend::ngspice`)

Four new **optional** hooks — `option_restore_spell`, `effective_emit`,
`effective_lookup`, `analysis_suppress` — plus the `effective_labels` variable
and `requires_cider`. **A backend with no hook gets no content** (D34): row RS5
proves a backend with no reverse table restores nothing, **RS5b** is its
non-vacuity half, and section **HK** asserts lexically that none of the thirty
new core procs contains an ngspice spelling, with **HK2** running **HK1's own
token list** over the adapter and finding them.

## What shipped — the SURFACE (`src/ase_window.tcl`)

The per-analysis sheet now **stamps the analysis onto a new row**
(`optsheet_stamp`, reached through a new optional `stamp` key on the shared
list-dialog config — the same shape as the existing `fill` key). The `Written`
column says `<TYPE> BLOCK` for a scoped row. The detail line carries the scope
verdict (`SCOPED:` / `GLOBAL:` / `LEAKS: <why>`) and the capability gate
(`GATED: …`). The deck preview's `control` slot — which issue 1441's row **PV7**
asserted was empty **as a fact, so that filling it would move a named row** —
now carries the per-analysis lines and the suppression.

---

## ⚠ THE DECISION THE BRIEF ASKED FOR: §7g RULE 1

The brief set out three options: (a) keep the refusal, (b) suppress `klu` for the
whole run and say so, (c) something I could argue for. **I chose (c), and it is
neither of the plan's two shapes.**

**The suppression is scoped to the ANALYSIS, not to the run** — which is §7e's own
mechanism, applied to the one option pair whose restore is measured in both
directions, and it needs **no new spelling at all**.

Why not (a): Stage 6's 6g-1 settled the principle — *a refusal where the emitter
can make the run correct is a false refusal* — and the emitter demonstrably can.

Why not (b): the brief's objection to it is real and I accept it. What gets
suppressed is **the user's own `klu` setting**, not a save list ASE-L wrote, and
(b) drops KLU for **every** analysis in the deck. KLU is chosen for speed on
exactly the circuits that have several analyses, so (b) is a larger unasked-for
change than 1434's save-list widening. (c) removes that objection entirely: the
only thing that changes is the solver used by the one analysis that would
otherwise crash.

**MEASURED on both binaries, on the deck shape ASE-L actually writes** — a
`.options klu` card, a `tran`, the AC `sens`, a second `tran`:

| deck | rc | solver per job |
|---|---|---|
| no suppression | **139, SIGSEGV** | — |
| `option klu=0` before the `sens`, `option klu` after | **0** | KLU / sparse / **KLU** |

and the `sens` numbers are **byte-identical** to the same analysis on a deck that
never asked for KLU. `option sparse` was measured to do the same thing; the
restore line is used because it is the mechanism §7e already has and a second
spelling would be a second answer.

⚠ **AND THE USER CAN NEVER GET A SIGSEGV, because the refusal is DEMOTED rather
than DELETED.** `ase::analysis_suppresses` requires **both** that the adapter
names the option **and** that the speller can actually write the off-line; a
backend failing either still gets the `fatal`, because the alternative there is
the crash. Row **RU2** builds that world by removing the hook from the live
registry and asserts the `fatal` comes back.

---

## Corrections, C134 onwards

Continuing the C series — **C100–C133 were issues 1437, 1439 and 1441.**

### C134 — the `default` column answers for **60** of 247 rows, not 65, and 65 is the `help` count

Issue 1441's receipt states *"65 of 247 rows carry a `default`; 64 carry `help`"*
and its C127 repeats the 65. **Counted live over the shipped catalogue, two
independent routes agreeing: 60 carry `default`, 65 carry `help`.** Counted
textually over the previous commit's catalogue: **60 and 64**. So `default` was
never 65 — the two columns were transposed, and the `help` count moved 64 → 65
when 1441 added the `units` sentence. ⚠ **The same shape as 1441's own C123 and
C130:** a number that was right about one column attached to another.

### C135 — §7e's escape hatch would REMOVE 17 rows from a surface issue 1441 had already shipped

§7e: *"an option with no known default is labelled **global** and offered only on
the global surface."* Measured: **32** catalogue rows declare an `{analysis …}`
scope and only **15** of those are restorable, so the hatch would take **17 rows
off the per-analysis sheet** that 1441's `Simulator Options…` button already
offers. The plan anticipated the *case*; it did not anticipate that a shipped
surface would shrink.

**What ships instead:** every analysis-scoped row stays offered and each one
**says which it is** — `scoped` (set before, put back after) or
`leaks <why>` (set where you asked, and it outlives the analysis). A shortcut
that disappears is worse than a shortcut that tells you its scope, and the leak
is then *reported* rather than either silently happening or silently costing the
user their setting. Rows **SP7** and **SP8**.

### C136 — `ase::opt_restore_line` could not restore a flag, and that is the mechanism §7e rests on

The shipped proc returned `{}` for the whole flag class under *"a valueless
option restores by ABSENCE, and absence has no line"*. True of the **forward**
spelling; false of the **reverse** one. MEASURED on both binaries with §7e's own
example — `option keepopinfo=0` really does turn it back off — and
source-generalised: every `IF_FLAG` arm in `cktsopt.c` is
`task->TSKxxx = (val->iValue != 0)`.

⚠ **THE OLD BEHAVIOUR WAS NOT MERELY PEDANTIC — IT PINNED §7e SHUT.** With no
reverse spelling for the flag class, a per-analysis scope could promise nothing
for any flag, and §7g rule 1 would have had no way to turn KLU off for one
analysis and put it back. `test_ase_options_1437`'s row **RS2** asserted the old
claim by name and is re-baselined with the transcript.

### C137 — `option` prints the temperature in KELVIN, and the catalogue says the opposite

The shipped catalogue's own comment reads *"`temp` AND `tnom` ARE STORED IN
KELVIN AND READ BACK IN CELSIUS … The default here is 27, the number the user
types and **the number `option` prints back**."* MEASURED on both binaries:
`.options temp=40` reads back **`temp = 313.150000`**.

⚠ **Without the conversion this would be a false alarm on every bench that sets
a temperature** — *"you asked for temp 40, ngspice is using 313.15"* — and a
verification channel that cries wolf on an ordinary setting is one the user
switches off. `effective_lookup` converts, in the adapter, because the unit is an
ngspice fact. Row **EF6**.

### C138 — `option` does not print the option's own name for several settings

Measured: `method` → `Integration Method`, `maxord` → `MaxOrder`, and the solver
appears as a bare `Sparse 1.3` / `KLU` line with no `=` at all. §7f therefore
needs an adapter-supplied **label map**, which the plan does not mention. Rows
**EF3** and **EF7**; a backend with no hook reads the name verbatim (**EF8**).

### C139 — the `set` dump's first character says WHICH DOOR a value came through, and it is what keeps §7f from raising twelve false alarms a run

`cp_vprint` (`variable.c:1221-1240`) tags each row: `' '` a shell variable, `'+'`
a **circuit** variable, `'*'` an environment one. Measured in one deck:
`.options bogusdot=1` → `+ bogusdot 1`, `option bogusopt=3` → `  bogusopt 3`.

⚠ **This is load-bearing, not a curiosity.** Measured on the end-to-end deck's
real artifacts: **13 of the 24 dumped names are outside the catalogue and TWELVE
of them are ngspice's own shell variables** — `batchmode`, `history`,
`inputdir`, `program`, `prompt`, `plots`, `curplot*`, `oscompiled`,
`xspice_enabled`. Every one carries `control` or `env`; the one real stray
carries `deck`. An `invented` verdict without the origin tag would fire twelve
times on every run of every bench. Rows **DF3** and **DF4**.

⚠ **AND THE HYPOTHESIS IT REPLACED WAS WRONG.** I first supposed that a
RECOGNISED `.options` name goes into the task and does *not* become a circuit
variable, which would have made the `+` prefix a direct misspelling detector.
Measured: `reltol`, `klu`, `itl4` and `temp` **all** carry `+`, exactly as
`bogusopt` does. The prefix says which door, never whether the name was
understood.

### C140 — a scoped row must not be compared against the end-of-run state, or §7e makes §7f lie

Measured end to end: `itl4` scoped to `tran` with value 200 reads back as
`itl4 (transient iterations) = 10` — the restore working exactly as designed.
Compared naively that is a `differs`, on every scoped row, on every run. The
verdict `scoped` exists for it. Row **DF6**, with **DF6b** as its non-vacuity
half: the same pair *without* the scope **is** a difference.

### C141 — §7g rule 4's stated reason does not apply to the deck ASE-L writes

D4 is `No. Points:` overflowing an 8-character field. Source-read: `outitf.c:1011`
reserves it (`fprintf(run->fp, "0       \n")`) and `:1190` back-fills with `%d`
and no width. **That is the `-r` streaming writer.** ASE-L's deck writes with the
`write` command — `rawfile.c:209`, `fprintf(fp, "No. Points: %d\n", length)`, no
reservation, nothing to overflow — verified on both binaries with a 1008-point
write giving the unpadded header `No. Points: 1008`.

The rule still ships, because a run of that size is hours and gigabytes, but
**with the reason that is true**. Shipping the plan's reason would have put an
unmeasured claim on the user's screen, which is the defect this batch exists to
delete. The `-r` half is in the source comment for whoever adds `-r` to
`run_cmd`.

### C142 — a lexical assertion over a proc body must strip comments, and this issue hit it THREE times

In this tree the comments quote the very strings a lexical scan looks for,
because that is what makes them evidence.

1. **HK1** reddened on `ase::effective_diff` for `.options`, `ngspice` and
   `CP_BOOL` — all inside comments recording measurements.
2. **HK1 reddened again on the ENGLISH WORD.** `option ` appears in
   *"this simulator's catalogue"*-class sentences because `option` is **ASE-L's
   own vocabulary too** — the sheet is called Options and every reader is
   `ase::opt_*`. The list now holds **templates and literals** (`option @`,
   `set @name`, `"option `, `"set `) rather than the word, which is sharper: it
   catches a spelling and ignores prose.
3. **EF12** reported a correctly-placed deletion as *"below the launch"* because
   `run_deck`'s own header comment contains the phrase *"just before `eval
   execute`"* — the paragraph explaining why the deletions are at the top.

### C143 — `wnflag`'s shipped door is `options`, not the pre-deck door §7d's story implies

Measured over the shipped catalogue while choosing a fixture for **DF8**:
`ase::opt_door ngspice wnflag` answers **`options`**, so the read-back channel
*can* speak for it and `missing` is its correct verdict. The pre-deck rows are a
different 32 (`addcontrol`, `casemode`, `ngbehavior`, …), and `addcontrol` is
what DF8 uses. Not a defect — issue 1439 settled `wnflag` — but it is the sort of
inherited assumption that would have made a row assert the wrong verdict.

### C144 — four extractors in `test_ase_core` matched `option` when they meant `op`

`^(op|dc |ac |tran …)` has no word boundary on its first alternative, so the bare
`option` command §7f writes matched it and four rows reported a line that is not
an analysis. ⚠ **Repaired, not re-baselined**: the claims are unchanged and what
was wrong was the word the extractor thought it was looking for.
`test_ase_optier_0963` already spells it `(op|dc|ac|tran)(\s|$)`, and so does
`test_ase_core`'s own line 8485 — so three of the tree's eight extractors were
already right and four were not.

---

## THE SABOTAGE CAMPAIGN

**Forty-one respellings**, each a plausible rewrite rather than a break — the tidy-up
somebody would actually make — and **fifteen of them reproduce a claim
`PLAN.md`, a dossier, this tree's own shipped code, or an earlier draft of this
very change actually makes**: S01 (the shipped `opt_restore_line`), S08 and S09
(§7e's own escape-hatch sentence), S10 (`PLAN.md` §7f's literal two-line recipe),
S14 and S15 (the identity label map and no unit conversion — the design before
C137 and C138), S17 (comparing a scoped row, the design before C140), S18 (the
`invented` arm before C139), S21 (fusing `unreported` into `missing`), S22 (the
unconditional arming this change started with), S24 (the deletion site the plan
asked for and 1430 refuted), S25 (the shipped `fatal`), S31 and S33 (refusing
where D47 says warn), S37 (the read-back below the marker — the placement this
change's own first cut had).

Restore was `cp` from `/tmp/s7t4/sab/good2_ase.tcl` and `good2_win.tcl` with an
**md5 compare after every application**, the campaign **aborts on a restore
mismatch** rather than continuing, **anchor uniqueness was checked against the
pristine files before each campaign started (40/40 unique, both times)**, and
**no source file was edited while a campaign was live**. Every application ran
**six** suites: `test_ase_effective_1442`, `test_ase_options_1437`,
`test_ase_predeck_1439`, `test_ase_optsheet_1441`, `test_ase_core` and
`test_ase_preflight` — the last two because `render_deck`, the D1 golden and the
`sens_klu` precondition are all in the blast radius.

**Eighty-two applications in all** — 40 on the first tree, 40 again on the final
tree, and S24 twice on its own (see below) — **82/82 restored, ZERO KILLS**, and
on the final tree **41/41 redden at least one NAMED row with ZERO SURVIVORS**.

⚠ **S24 WAS MISSING FROM THE FIRST CAMPAIGN ENTIRELY, AND IT IS THE ONE THE BRIEF
ASKED FOR BY NAME.** The generator skipped it and nothing noticed until the
results file was read row by row — *"establish exactly where the delete may go
without moving any of those anchors, **and assert it**"* was the brief's
instruction, and the assertion had no sabotage behind it. Run afterwards, it
**SURVIVED**: row EF12 only asked that the delete sit above `eval execute`, which
is precisely the placement `PLAN.md` asks for and issue 1430 refuted. EF12's
bound is now the **pre-deck block** — the first line in `run_deck` that may
create a file — and S24 reddens it. ⚠ **A sabotage that is never run is
indistinguishable from one that passes**, and the only thing that caught it was
counting the rows.

| # | the respelling | rows reddened |
|---|---|---|
| S01 | opt_restore_line: a flag restores by ABSENCE, as the shipped code had it | RS1 RS2 RS5b DK7 DK10 DK10b RU1 RU2c RS2 PF230f (got 'sens_klu fatal 1 0' want 'sens_klu caution 1 0') |
| S02 | opt_restore_line: core spells the reverse line itself, saving a hook nobody else needs | RS5 |
| S03 | opt_restorable: a row with no default is restorable anyway -- the speller will sort it out | RS7 SP7 |
| S04 | opt_scope_plan: a row that cannot be put back is dropped rather than emitted | SP3 |
| S05 | opt_scope_plan: match the stored analysis name exactly, as it was typed | SP8b  — **survived pass 1**; reddens after the row it needed was written |
| S06 | opt_scope_lines: the restores come off in the same order as the sets | SP6 |
| S07 | opt_deck_plan: a scoped row gets its deck card too, belt and braces | SP5 |
| S08 | opt_analysis_verdict: an unrestorable row is `global`, exactly as PLAN.md §7e says | SP7 |
| S09 | opt_scoped_names: the per-analysis surface offers only what it can truly scope (§7e's hatch) | SP8 |
| S10 | effective_emit: redirect the task dump too, exactly as PLAN.md §7f writes it | DK3 DK4 DK5 DK9 DK10 D1 C4 C5 |
| S11 | effective_parse_vars: the prefix is decoration -- every row is the same kind | EF1 |
| S12 | effective_parse_task: keep the lines without `=` too, a heading is information | EF3 |
| S13 | effective_region: the FIRST bracket wins | EF4 |
| S14 | effective_lookup: the label map is the identity -- ngspice prints the option's own name | EF7 |
| S15 | effective_lookup: no unit conversion, a number is a number | EF6 |
| S16 | effective_same: string equality only, a value is a value | EF9 |
| S17 | effective_diff: a scoped row is compared like any other stored row | DF6 |
| S18 | effective_diff: any catalogue-unknown variable is invented, wherever it came from | DF4  — **survived pass 1**; reddens after the row it needed was written |
| S19 | effective_diff: a flag reported with no value differs from the 1 that was asked for | DF7 |
| S20 | effective_diff: an unknown name that left no trace is `ok` -- nothing said, nothing wrong | DF4 DF5 DF11 |
| S21 | effective_diff: `unreported` folded into `missing` | DF8 |
| S22 | effective_armed: arm it on every deck, because verification is mandatory | DK6 EF11 |
| S23 | effective_path: no raise for a state with no cell, just use a bare name | EF10 |
| S24 | run_deck: delete the sidecar just before `eval execute`, where the plan asked for it | EF12  — **survived pass 1**; reddens after the row it needed was written |
| S25 | sens_klu: keep the refusal -- a crash is not something to work around | DK7 DK10 RU1 PF230f (got 'sens_klu fatal 1 0' want 'sens_klu caution 1 0') |
| S26 | analysis_suppresses: trust the rule; if the adapter names it, suppress it | RU2b  — **survived pass 1**; reddens after the row it needed was written |
| S27 | analysis_suppress_lines: put the default back rather than the user's own value | DK7 |
| S28 | opt_gate_state: evaluate every row's gate, for uniformity | GT5 |
| S29 | opt_gate_state: a gated row that names no predicate is simply `ok` | GT5 |
| S30 | requires_cider: answer a boolean -- `unknown` is just a polite no | GT8 GT8b  — **survived pass 1**; reddens after the row it needed was written |
| S31 | lin_points: refuse rather than warn | RU6 RU6b |
| S32 | lin_points: fire on `lin 1` too, which also yields one point | RU7 |
| S33 | points_max: refuse -- a gigabyte file is not something to warn about | RU9 |
| S34 | analysis_point_estimate: estimate it here rather than through the adapter's hook | RU11 |
| S35 | render_deck: drop the per-analysis option lines entirely | DK1 DK2 DK7 |
| S36 | render_deck: the option lines go below the verbatim hatch, next to the analysis | DK1 DK2 DK7 |
| S37 | render_deck: the read-back goes below the completion marker | CK17 |
| S38 | opt_preview: the suppression is ASE-L's choice, not the user's, so it is not shown | DK10 |
| S39 | listdlg_stamp_pairs: stamp every row, new or edited | UI2b  — **survived pass 1**; reddens after the row it needed was written |
| S40 | optsheet_where: the catalogue door is the answer -- the store does not move a line | UI3 |
| S41 | optsheet_stamp: the global sheet stamps a scope too | UI2 |

### ⚠ FIVE SURVIVED PASS 1, AND ALL FIVE ARE ONE FAMILY

*A row whose fixtures never disagree cannot fail* — the **twenty-first** through
twenty-fifth times in this batch. None was fixed by deleting a line, and none of
the five was a wrong behaviour: in every case the CODE was right and the ROW was
asking a coarser question than the code answers.

| survivor | why nothing moved | the row written for it |
|---|---|---|
| **S05** — `opt_scope_plan` matches the stored analysis name case-sensitively | **every fixture in the file spells `tran` in lower case.** ⚠ And the hole is not cosmetic: a hand-edited `.state` carrying `analysis TRAN` is skipped by `opt_scope_plan` (the case differs) **and** by `opt_deck_plan` (the `analysis` key is non-empty), so the option is stored, shown in the sheet as scoped, and **emitted nowhere at all** | **SP8b** over three spellings, with **SP8c** as its non-vacuity half — a scope naming a *different* analysis still does not match |
| **S18** — any catalogue-unknown variable is `invented`, whatever door it came through | **the row asked over an EMPTY bench.** `effective_diff` walks the bench's *stored* options, so a state with none produces no rows and *"no row said invented"* was true of a diff that said nothing — the vacuity defect inside the row written to prevent it | **DF4** rebuilt: the fixture now STORES `batchmode` (a name ngspice owns, which the catalogue does not describe and the dump reports as a shell variable) beside the real stray, so the row turns on the origin tag |
| **S26** — `analysis_suppresses` trusts the rule instead of checking the speller | ⚠ **a guard no fixture could reach.** RU2 builds the first failure (no hook at all); nothing built the second — an adapter that NAMES an option the speller cannot take back. **It is the clause that guarantees the user never gets a SIGSEGV**: without it a `caution` is returned on the strength of a suppression that never reaches the deck | **RU2b** on a synthetic backend whose `klu` row carries no `default` (the shape 60-of-247 of the real catalogue has), with **RU2c** as its non-vacuity half |
| **S30** — `requires_cider` answers `absent` where it should answer `unknown` | **the row compared `state` and threw away `reason`**, and `absent/notpresent` and `absent/unmeasured` have the same state. The two are opposite answers to the user — *"this build does not have it"* against *"ASE-L has not found out"* — and `opt_gate_why` really does say two different sentences | **GT8** now compares the full `{state reason}`, with **GT8b** asserting the two sentences differ |
| **S39** — the stamp is applied to an edited row as well as a new one | ⚠ **the same shape as S26.** `listdlg_ok` runs off a live dialog's entry widgets, so no headless row can drive it and the new-row guard was unreachable. The hole: editing a GLOBAL row while the tran sheet happens to be open would silently re-scope it | **the API moved** — `ase::ui::listdlg_stamp_pairs` takes the index, so **UI2b** can ask it directly; **UI2c** covers a dialog whose config declares no stamp |

⚠ **THE PATTERN IS WORTH MORE THAN THE FIVE FIXES.** Four of the five rows were
*true statements about the shipped code* that would have stayed true after the
behaviour changed — a row over an empty bench, a row over one spelling, a row
over one field of a two-field answer, a row over a proc rather than its caller.
**The fifth (S26) is the one to remember**, and it is task 3's S26 again: a guard
whose only caller cannot produce the input that trips it. The fix is never to
delete it and never to fake it — **let the caller pass the input**, which is what
moved `listdlg_stamp_pairs` out of `listdlg_ok` too.

---

## Suites moved, before → after

| suite | headless | display (`:99`) | in T1? |
|---|---|---|---|
| **`test_ase_effective_1442`** (new) | — → **92** | — → **92** | **yes, `hcases` only** — added in this change. Not `dcases`, and the file says why |
| `test_ase_core` | 598 → **598**, **D1's inline golden deck re-baselined** and four extractors repaired | 598 → **598** | yes |
| `test_ase_options_1437` | 75 → **75**, one row re-baselined (**RS2**) | 75 → **75** | yes |
| `test_ase_preflight` | 235 → **235**, one row re-baselined (**PF230f**) | 235 → **235** | yes |
| `test_ase_predeck_1439` | 78 → **78** | 78 → **78** | yes |
| `test_ase_optsheet_1441` | 62 → **62** | 87 → **87** | yes, BOTH arms |
| `test_ase_dialogs` | 37 → **37** | 299 passed / **1 FAILED** — issue **1436**, unchanged | yes (headless arm only) |
| `test_ase_simreg_0931` | 117 → **117** | 117 → **117** | yes |
| `test_ase_simdlg_0937` | 5 → **5** | 55 → **55** | yes |
| `test_ase_persist` | 44 → **44** | 148 → **148** | yes |
| `test_ase_simcaps_0948` | 199 → **199** | 199 → **199** | yes |
| `test_ase_optier_0963` | 108 → **108** | **TIMEOUT at 200 s** — issue **1440**, pre-existing, and T1 runs this file headless only | yes (headless arm only) |
| `test_cosim_golden_e2e` | 45 passed / **1 FAILED** — issue **1431**, unchanged | — | **no** |
| every other ASE suite | unmoved | — | — |

**The three re-baselined rows, with the reason that moved each:**

| row | before → after | why |
|---|---|---|
| `test_ase_options_1437` **RS2** | *"a flag has no restore line"*, `{} {}` → `{option keepopinfo=0} {option klu=0}` | **the claim is measured FALSE on both binaries** (C136), and the old form pinned §7e's whole mechanism shut |
| `test_ase_preflight` **PF230f** | `sens_klu fatal` → `sens_klu caution` | the decision the brief asked me to return, §7g rule 1. The `fatal` is still reachable and row **RU2** holds it there |
| `test_ase_core` **D1** | the inline golden deck gains four lines before `.endc` | §7f's read-back, **armed because that bench stores an option**. A bench that stores none gets a byte-identical deck |

### ⚠ The three results that are NOT this change

* **`test_ase_dialogs` G2sens**, display arm. Issue **1436**, filed by the 1435
  crew and not fixed. The actual value — `{1 1 0 1 0 Entry Entry normal}` against
  `{1 1 0 0 0 Entry Entry normal}` — is **byte-identical to 1436's transcript**
  and to the one every crew since has reported. T1 runs this file's **headless**
  arm only, where it is ALL PASS (37). ⚠ **And 299 of 300 passing is the
  measurement that says this change's `listdlg_ok` refactor moved no gesture** —
  every dialog leg that drives the shared list-dialog engine is in that 299.
* **`test_ase_optier_0963` display arm.** Issue **1440**, rc 124 at the 200 s
  suite timeout, stops after row N3. ⚠ **This crew did NOT investigate it** — it
  is the known exception the brief names. Its **headless** arm, which is the one
  T1 runs, is **ALL PASS (108)** here.
* **`test_cosim_golden_e2e` GE24, headless.** Issue **1431**, the one-timestep
  VCD boundary, 45 passed / 1 failed, unchanged and **not in T1**.

⚠ **EVERYTHING ELSE IS GREEN ON BOTH ARMS** — the twelve-suite headless run is
11/12 (the twelfth being 1431) and the eleven-suite display run is 10/11 (the
eleventh being 1436).

⚠ **NO COMMITTED DECK GOLDEN FILE MOVED AND NO `.state` FILE MOVED.**
`tests/headless/gold/cmos_example.spice` does carry a `.control` block, but it is
a **netlister** golden from a schematic's own `code_shown` instance, not an
ASE-L rendered deck — checked, and it is unaffected. No state key was added,
`ase::state_default` still seeds exactly four rows (`op dc ac tran`), there is no
`seed_enabled` anywhere in this diff, `op` is still last in emit order, and the
print anchor (1243), the plotmap record (1430), the checkpoint block (1433), the
`.save all` leader (1434), 1439's door consultation and 1441's
`ase::opt_deck_plan` are all where they were. `test_ase_core`'s section **CP** —
the row that would notice a byte in the 104 committed `.state` files — is green.

---

## What I did NOT ship, and why

* **A per-analysis option CONTAINER.** `options` stays **one list**; the scope is
  a key on the stored row. A second container would have been a new state shape
  for the 104 committed `.state` files to round-trip, and it buys nothing: no
  committed state carries an `analysis` key on an option row, so byte identity
  holds by construction rather than by `omit_if_empty`.
* **A `hazard_table`.** §7g says it in as many words — *"a table with no key (D43)
  pretending to be data"*. Rule 1 is one predicate in the adapter and one
  precondition in core; the mitigation has no registry.
* **A second gated catalogue row.** `filetype` is the only `cp_getvar` variable in
  the whole of `src/ciderlib` (verified by grep), and it is therefore the only
  row in the catalogue whose **existence** is a build option. The XSPICE-scoped
  rows (`noisyxspice`, `xtrtol`, `auto_bridge`, `no_auto_bridge_family`) are
  *device*-conditional rather than build-conditional and `devhelp` lists no XSPICE
  families to gate them on — so they stay ungated and the schema is proved in all
  five directions on a synthetic backend instead (section GT).
* **`sp lin 2`.** §7g names it beside `ac lin 2`. `sp` is still a bare probe stub
  with **no fields at all**, so it cannot carry a sweep to warn about. The rule is
  written over the *fields* rather than over a type list, so it covers `sp` the
  day `sp` gets one — and says nothing today rather than pretending to.
* **Any measurement of `group` or `scope`.** Task 3 settled both; nothing here
  depends on either.
* **`help` text for the 182 rows that have none.** ⚖ R9, as tasks 1 and 3 left it.

---

## What this task learned that binds later stages

**A DOCUMENTED MECHANISM CAN BE HALF BROKEN, AND THE BROKEN HALF IS THE ONE THAT
LOOKS FINE.** `option > f` and `set >> f` are one line apart in the plan and one
writes 450 bytes while the other writes zero. ⚠ **When a recipe has two limbs,
measure each limb separately and give each one its own positive control** — the
deck that proved `set` worked would have "proved" the whole recipe worked.

**A LEXICAL ASSERTION OVER A PROC BODY MUST STRIP COMMENTS, BECAUSE IN THIS TREE
THE COMMENTS QUOTE THE STRINGS THE ASSERTION HUNTS.** Three times in one issue
(C142). And the sharper half: **a word can belong to both vocabularies.**
`option` is ngspice's command *and* ASE-L's own noun, so the guard must look for
the **spelling** — a template slot or a quoted literal — and not for the word.

**A VERIFICATION CHANNEL'S REAL ENEMY IS THE FALSE ALARM.** Three separate
verdicts exist only to prevent one: `scoped` (C140), the origin tag on `invented`
(C139), and `unreported` as distinct from `missing`. Any one of them collapsed
would put a confident complaint on the screen for an ordinary bench, and a
channel that cries wolf on the ordinary case stops being read before it ever
catches the real one. ⚠ **Budget as much design for what a checker must NOT say
as for what it must.**

**AND A "NOT SHIPPED" DECISION CAN ITSELF BE A REFUTATION.** §7e's escape hatch,
read literally, would have shrunk a surface that shipped three commits earlier
(C135). ⚠ **When a plan clause was written before the surface it constrains,
check what it would REMOVE, not only what it would add.**

---

## Rulings

⚖ **R9 — new user-facing copy, filed as `owed.sh add rule 1442`** at the moment
it was incurred, pointing at `doc/claude/issues/1442-*.md`:

1. the **five §7f report sentences** — *"you asked for X; <sim> reports Y"*,
   *"X did not reach <sim> — it reports no such setting"*, the `invented`
   sentence, the `unverifiable` sentence, and the coverage warning *"⚠ neither
   read-back channel reported any stored option on this run, so nothing below
   rests on a comparison"*. ⚠ **The `unverifiable` one needs the ruling most**:
   it tells the user that nothing can confirm their setting, which is honest and
   is a sentence nobody has had to read in this GUI;
2. **§7g rule 1's caution and its fix line** — the sentence that says KLU was
   turned off for one analysis and put back;
3. **§7g rule 3's and rule 4's caution and fix lines**;
4. **§7g rule 5's three gate sentences** and the **four door phrases**
   (*above the analysis block*, *inside the analysis block*, *on the command
   line*, *in the run-directory start-up file*, plus *through no door this
   simulator offers*);
5. the **detail-line words** — `SCOPED:`, `GLOBAL:`, `LEAKS: <why>`, `GATED:` —
   and the five leak reasons;
6. the **`Written` column's `<TYPE> BLOCK`** value;
7. the **two preview notes** — the suppression note and the leak note.

**Batch with 1426, 1427, 1428, 1429, 1430, 1432, 1433, 1434, 1435, 1437, 1439
and 1441, which are all still waiting.**

⚠ **AND A `look` DEBT IS FILED — `owed.sh add look ase_effective_1442`.** The
suites are green on both arms and the deliverable is **not** done: it is *"suites
green, please look"*, and it clears only when the user says so. Three things the
eyes are for: whether the preview's **in-block slot** reads as a different place
from the deck slot now that it has lines in it; whether the detail line stays
readable with a scope verdict **and** a gate sentence **and** a badge on one
line; and whether the post-run *"what the simulator actually used"* lines are
legible in the CIW among the other run output.

⚠ **THE LEDGER WAS BACKED UP FIRST**, per `CLAUDE.md`'s one-ledger-every-clone
paragraph, to `/tmp/s7t4/owed_backup/xschem_owed` (**159 rule / 58 look / 10
suite** at the time); after the two adds it reads **160 / 59 / 10**. Measured
immediately before the adds: `/usr/bin/grep -L '^repo:'` over the three
directories prints the **same four unstamped entries** issues 1430–1441 have each
reported, and the stamp split is **210 this clone / 13 op-wcard** before the adds.
⚠ The op-wcard count has now been **13 across nine receipts**.

⚖ R2 is **answered** (yes, four conditions) and ⚖ R3 is **answered** (Option C).
⚖ **R4 is open and nothing here is gated on it** — nothing was seeded, no state
key was added to `ase::state_default`, and there is no `seed_enabled` anywhere.

---

## ⚠ IS STAGE 7 COMPLETE?

**Yes for §7a–§7g as `PLAN.md` specifies them, with four things named as open.**

| section | task | state |
|---|---|---|
| §7a one catalogue, five columns | 1 (1437) | shipped — 247 rows |
| §7b one speller | 1 (1437) | shipped — T3/T4/T5 are type errors |
| §7c finding one option among 247 | 3 (1441) | shipped — finder, groups, badge, preview |
| §7d the pre-deck class and the inert list | 2 (1439) | shipped — ⚖ R2's four conditions all met |
| §7e per-analysis scope | **4 (1442)** | shipped, with C135's honest limit on the surface |
| §7f requested versus effective | **4 (1442)** | shipped, through the channel that works |
| §7g the four rules | **4 (1442)** | five rules: 2 was already shipped, 1 changed, 3/4/5 new |

**What is still open, so the driver does not have to reconstruct it:**

1. **⚖ R9 — thirteen issues' worth of unratified user-facing copy**, 1442
   included. This is the batch's largest standing debt and it is the user's.
2. **The `look` debts** — 1441's options sheet and 1442's additions to it.
   Neither clears on a green suite.
3. **`group` is 0/247 verified and `scope` cannot be measured** (task 3's C125 /
   C129). Both are mitigated by design rather than verified, and both are stated
   on the record.
4. **Ten `results` rows remain `unverified`** (task 3) and say so on the surface.

None of the four blocks a later stage. Stage 8 is next.

---

## For the driver

* **T1 was NOT run by this crew** (issue 0990 — the driver runs it solo).
  ⚠ **T1's membership changed in this commit**: `tests/run_regression.tcl`'s
  **`hcases`** gains `headless/test_ase_effective_1442` (**+92** — see the driver
  footnote below).  **`dcases` does
  NOT change**, and the file carries the measurement that says why — 83 checks on
  both arms at the time that comment was written, so the display arm would be a
  weaker measurement of the same thing. Nothing else in that file moved.
* **Nothing was committed, added, stashed, restored, cleaned or pushed.** No
  `git checkout --`, no `git restore`, no `git stash`, no `git clean`, no
  `git commit`, no `git push`, no PR. The working tree is the one handed over
  plus **seven modified files** (`src/ase.tcl`, `src/ase_window.tcl`,
  `tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_options_1437.tcl`,
  `tests/headless/test_ase_preflight.tcl`, `tests/run_regression.tcl`,
  `doc/claude/issues/NUMBERING.md`) and **three new ones**
  (`tests/headless/test_ase_effective_1442.tcl`, the issue file, this receipt).
  The four untracked paths inherited at `40eb33d6` are untouched.
* **`NUMBERING.md`'s pointer was advanced 1442 → 1443** in the same change as the
  entry. **Both mint checks were run at the moment of minting**: the reserved-band
  scan over this clone's head table (**silent** for 1442) and
  `ls ~/dev/*/doc/claude/issues/1442-*` plus `/usr/bin/grep -lw 1442` across
  **every** clone's `NUMBERING.md` (the glob verified non-empty, two clones) —
  only this clone's own pointer line came back.
* ⚠ **THE THREE RE-BASELINED ROWS ARE DECISIONS, AND HERE IS THE ONE-LINE CASE
  FOR EACH**, so the driver can check them without re-deriving:
  * `test_ase_options_1437` **RS2** — *"a flag has no restore line"* is measured
    false on both binaries, and the old claim pinned §7e shut.
  * `test_ase_preflight` **PF230f** — `sens_klu` `fatal` → `caution`, which is
    the decision the brief asked me to return. The `fatal` is still reachable and
    row **RU2** holds it there.
  * `test_ase_core` **D1**'s inline golden deck — the §7f read-back, armed
    because that bench stores an option. **No committed golden FILE moved**;
    `tests/headless/gold/cmos_example.spice` carries a `.control` block but it is
    a netlister golden from a schematic, not an ASE-L rendered deck.
* ⚠ **NO SIMULATOR IS STARTED BY THE FEATURE, BUT ~45 PROBE RUNS WERE MADE TO
  BUILD IT, ON BOTH BINARIES.** Every probe ran on a scratch deck under
  `/tmp/s7t4/probe/ng` with that directory as its own cwd. **No bench under
  `sky130A/` was run** and no simulation touched `~/.xschem/`.
* ⚠ **TWO DELIBERATE SIGSEGVs WERE TAKEN, ONE OF THEM ON `/usr/bin/ngspice`**,
  reproducing the AC-`sens`-under-KLU crash so that the mitigation had a positive
  control. **The crash-report environment was checked first**: `core_pattern` is
  `core`, `systemd-coredump` is not installed and `ulimit -c` is 0, so nothing
  was written and nothing was reported — the same conditions under which the 1435
  crew took the original measurement.
* ⚠⚠ **`$HOME/.spiceinit` WAS NEVER WRITTEN, MOVED, BACKED UP OR READ**, and no
  start-up file was created anywhere in this task.
* **Machine rules honoured throughout**: every xschem invocation was given a path
  (`./src/xschem` or through `run_suites.sh`) and `--nolog`, never `--logdir`,
  never a bare `xschem`; every bespoke command carried a `timeout` and every
  waiting loop a deadline; **a stall was a named outcome** (the campaign runner
  reports `TIMEOUT/<suite>` and `NORESULT/<suite>` as verdicts);
  `tests/run_regression.tcl` was not run; nothing was `pkill`ed.
* ⚠ **`~/.xschem/geometry` WILL HAVE BEEN WRITTEN AGAIN** by the display arm —
  issue **1397**, already on the user's queue and reported by every crew since
  1430. Every headless invocation carried `--nogui`.
* ⚠ **ONE PATH UNDER `~/.xschem/` IS NAMED IN A GOLDEN, AND NOTHING WAS WRITTEN
  THERE.** `test_ase_core`'s D1 golden resolves `ase::rundir` to
  `~/.xschem/simulations/nfet_clean_ase.effective` as a **path string** — the
  suite renders a deck and compares text, and no simulator is started with that
  state. **Verified after the fact**: `find ~/.xschem -name '*.effective'`
  returns nothing at all.
* **The next task is Stage 8.**


---

> ⚠ **DRIVER FOOTNOTE 2026-09-13.** The *For the driver* line above read **`+85`**, which
> disagrees with this receipt's own floor paragraph (*"92 checks, identical on both arms"*),
> with the comment this commit added to `tests/run_regression.tcl` (*"92 checks headless and
> 92 on the dev display"*), and with the driver's own run (`RESULT: ALL PASS (92 checks)`).
> **It is 92.** Corrected in the line itself because it is a bare number with no argument
> attached; everything else in this receipt is left as written.
>
> ⚠ **This is the SECOND receipt in a row whose prose miscounted its own suite** — issue
> 1441's said *"T1 covers all 82"* for a suite that prints 62 and 87. The suites themselves
> have been right every time and the driver's re-runs have matched them exactly; it is the
> **sentences about** the counts that drift. Anyone reading a receipt for a number should
> take it from a `RESULT:` line, not from a paragraph.
