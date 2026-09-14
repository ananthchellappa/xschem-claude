# Issue 1459 — the simulator said which nodes would not converge, and nobody ever read it

**Stage 10, task 1 of two — the DECK half.** Files I own and touched, and nothing else:
**`src/ase.tcl`**, **`tests/headless/test_ase_converge_1459.tcl`** (new),
**`tests/headless/test_ase_core.tcl`**, **`tests/headless/test_ase_persist.tcl`**,
**`tests/run_regression.tcl`**, plus `doc/claude/issues/1459-*.md`,
`doc/claude/issues/NUMBERING.md` and this receipt.

**`src/ase_window.tcl` was NOT opened for writing.** Its md5 is byte-identical to the
pristine snapshot taken before I started — `d273ac3870211ce5a73b18174f74d4b3` — verified after
every one of the thirty-five sabotage restores. The ladder pane, the remedy assistant, the
canvas highlight and the health strip are task 2's.

No commit, no `git add`, no stash, no restore, no clean, no push. `tests/run_regression.tcl`
**not run** (issue 0990 — the driver's, solo). **No simulation on any bench under `sky130A/`
or `ihp-sg13g2/`**: every simulator run below is a hand-written deck or an ASE-L-rendered deck
under `/tmp/stage10` or the suite's own scratch dir, against an explicit binary path. Nothing
under `~/.xschem/` was opened for writing.

**Floors:** `test_ase_converge_1459` **NEW, 76 both arms, identical rows**;
`test_ase_core` **636 → 638** (both arms); `test_ase_persist` **unmoved at 49 headless /
153 display** — one row's *expectation* moved, not the count. Each file's own `AND RAISED`
paragraph is in the same diff.

`src/ase.tcl` **+948** (441 comment/blank, **507 code**), `test_ase_converge_1459.tcl`
**1265 new**, `test_ase_core.tcl` **+33 −6**, `test_ase_persist.tcl` **+18 −4**,
`run_regression.tcl` **+18 −1**.

---

## ⚠ THE HEADLINE: THE BRIEF ASKED ME TO FIND THE SPELLING THAT TURNS RUNG 4 OFF, AND THE ANSWER IS THAT IT WAS NEVER AN OPTION

The driver measured three deck spellings that could not switch `optran` off —
`.options optran 0 0 0 0 0 0`, `.options optran=0`, `.options optran = 0 0 0 0 0 0` — each at
rc 0 with no complaint, and wrote: *"finding the spelling that works is YOUR job, and it must
be proved with a deck that fails to converge when it is applied."*

**`optran` is a COMMAND, not an option.** It is in `spcp_coms[]` (`commands.c:672-675`) and
absent from `OPTtbl[]`, so every `.options` spelling of it is a name the options parser has
never heard of — accepted and inert, the fourth case of that class this stage found. The
spelling that works is the command inside `.control`, with argument 4 set to zero
(`optran.c:182-185`).

**Proved, on both binaries, with the deck the brief demanded:**

| deck (`.control`) | apt 45.2 | the fork |
|---|---|---|
| `optran 0 0 0 100n 10u 0` — only the transient rung | rc 0, `v(out) = 9.999550e-01` | identical |
| `optran 0 0 0 0 10u 0` — nothing left | **rc 1**, `The operating point could not be simulated successfully` | identical |

That is a checkbox that means OFF, and the difference between the two rows is one digit.

⚠ **And the first version of that proof measured nothing, for a reason the brief could not
have known.** I built the "off" deck as `.options noopiter gminsteps=0 srcsteps=0` plus
`optran 1 1 1 0 10u 0`, expecting the run to die. It converged, rc 0 — because **`optran`'s
first three arguments override those three options on the same task, silently.** The XOR rule
this stage exists to enforce bit the test written to prove a different half of it. Row EE1
carries the story in its own comment.

---

## ⚠ AND A SECOND HEADLINE THE PLAN DID NOT KNOW: §10c'S "FASTEST FIX" SILENTLY CHANGES THE ANSWER

PLAN.md §10c: *"`wrnodev <file>` after a converged `op` plus a `.include <file>` row — the
fastest fix for a bench that takes four minutes to find its operating point."*

`wrnodev` writes **`.ic`** cards (`com_wr_ic.c:63`, and it takes exactly one argument, the
file name — there is no `.nodeset` writer). And `.ic` in a **transient** operating point is a
clamp applied for every Newton phase **with no `INITF` qualification** (`cktload.c:146-173`),
so it is never released.

**MEASURED 2026-09-13, both binaries, one bench, one edit:**

| run | `v(a)` at t = 0 |
|---|---|
| saved at 5 V | the file says `.ic v(a) = 2.5` |
| re-run at 3 V, no file | `1.500000e+00` ← correct |
| re-run at 3 V, the file `.include`d verbatim | **`2.500000e+00`** ← wrong |
| re-run at 3 V, the same values re-spelt `.nodeset` | `1.500000e+00` ← correct |

rc 0 and nothing on either stream, in all three. So the restore ships in two modes: **`seed`
(the default) re-spells the simulator's own file as `.nodeset`**, released before the final
Newton phase and therefore unable to change the answer; **`force`** is the verbatim
`.include`, for a user who means `.ic`. Row **WR4** is the re-spelling, **WR4b** is that
`seed` is the default, and **EE5** runs all three columns of that table on both binaries.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| `optran` is a command and `.options optran …` is inert | **MEASURED HERE**, both binaries, `.options optran 1 1 1 0 10u 0` left `Note: Transient op started` in the log and the transient answer in the vector |
| `optran <a> <b> <c> 0 <stop> 0` really disables rung 4, and every rung off really kills the run | **MEASURED HERE**, both binaries, the two-row table above |
| `optran`'s args 1–3 override `.options noopiter/gminsteps/srcsteps` silently | **MEASURED HERE**, both binaries — found by my own EE1 failing to fail |
| a REAL starred `Last Node Voltages` table | **CAPTURED HERE**, both binaries, byte-identical. The driver could not capture one because `optran` was unkillable by the spellings tried; with the command spelling it is one deck. Two variants captured: node-voltage stars + a branch star, and hierarchical + 37-character names |
| the table with NO star in it | **CAPTURED HERE**, both binaries — `optran 0 0 0 0 10u 0` on an RC: nothing ever iterates, so no row can differ from itself |
| a 37-character node name pushes both value columns right | **MEASURED HERE** — `%-30s` does not truncate. This is the whole case for whitespace parsing |
| `v1#branch` is a branch current inside a table headed "Last Node Voltages" | **MEASURED HERE**, in the same capture |
| `wrnodev` filters `#branch` OUT while `CKTncDump` keeps it IN | **READ** from `com_wr_ic.c:64` and `cktncdump.c:24`, **and confirmed** in the captured file and table |
| `wrnodev` works after a plain `op` | **MEASURED HERE**, both binaries, file contents quoted in the suite. `convergence.md`'s *"you need to execute stop … tran … resume"* is about having no solution at all, not about needing a transient |
| the `.ic`-clamp table above | **MEASURED HERE**, both binaries, four runs |
| the folded log is systematically reordered | **RE-MEASURED HERE**, and the fixture in the suite IS that capture — all 13 stderr lines before all 13 stdout lines |
| the ladder's literal text, gmin / source / transient, with and without `ngdebug` | **CAPTURED HERE** on both binaries; five transcripts |
| `rusage devtimes` prints nothing | **MEASURED HERE**, both binaries, **and traced to source**: `resource.c:322` reads `CKTstat->devCounts[]`, written only inside `#ifdef PER_DEVICE_STATS`, and `cktload.c:30` is the literal line `// #define PER_DEVICE_STATS` |
| the four `rusage` counters that DO work | **MEASURED HERE**, both binaries, one keyword at a time and all four on one line |
| `optran`'s step-size clamp and its rc-0 error | **MEASURED HERE**, both binaries, five argument shapes |
| `9.999550e-01` on a 1 kΩ / 1 nF RC | **RE-MEASURED HERE**, both binaries; it reproduces the driver's `optran-and-ncdump-verified.md` §1 exactly |
| `cktop.c` has no rung-1 message in either direction | **READ** from `evidence/convergence.md` §4.3's table, **and confirmed by measurement**: `.options noopiter` and a failing Newton give the same first line on both binaries |
| `cktncdump.c:23-39`, `cktload.c:146-173`, `optran.c:173-185`, `commands.c:672-675`, `resource.c:322-335`, `cktload.c:30` | **READ** from the ngspice tree here. Their *behaviour* is measured above; their line numbers are not |
| baselines: core 636, preflight 235, sp 58 both arms, dialogs 37 / 1 FAILED (384) with `G2sens` = `{1 1 0 1 0 Entry Entry normal}`, simcaps 211, meas 113, optier 109 | **RE-MEASURED HERE** before I edited anything; all seven matched the brief exactly |
| 104 committed `.state` files | **COUNTED LIVE** and round-tripped live, 104 of 104, with a non-vacuity control |

---

## What shipped

**Core (schema) — not one simulator word.** Three state keys `opstrategy` / `opstate` /
`runhealth`, all `{}` by default, all in `ase::omit_if_empty` and all in `ase::schema_keys`;
`ase::conv_hook` (one place that says "a backend with no hook gets no fallback content");
`ase::ncdump_parse` / `ase::ncdump_failing`; `ase::ladder_rungs` / `ase::ladder_rung` /
`ase::ladder_parse` / `ase::ladder_ran_notes` and the `ase::ladder_cache_clear` memo dropped
by `ase::register_backend` beside the other two; `ase::opstrategy*` accessors,
`ase::optran_line`, `ase::opstrategy_refusals`; `ase::opstate*`, `ase::opstate_path`,
`ase::wrnodev_lines`, `ase::opstate_refusals`; `ase::runhealth_armed` /
`ase::runhealth_lines` / `ase::runhealth_parse`.

**Adapter (content).** `ncdump_parse`, `ladder_rungs`, `_ladder_markers`, `_ladder_trials`,
`ladder_parse`, `optran_line`, `opstrategy_options`, `opstrategy_arg_refusals`,
`opstate_lines`, `opstate_arg_refusals`, `runhealth_lines`, `runhealth_parse` — eleven new
hooks on `ase::register_backend ngspice`.

**Four wiring sites in `render_deck`, and every one of the four positions is a decision:**

| what | where | why |
|---|---|---|
| the `.nodeset` / `.include` restore | **deck level**, above `.control` | a dot card is not a command in there. Position within the deck is free — `.nodeset`/`.ic` are pass-3 (`inppas3.c:23-169`) |
| `optran …` | **inside `.control`, above every analysis**, inside the "at least one enabled analysis" guard | it is a command; with a live circuit it writes `ci_defTask` directly, so it governs what FOLLOWS it and nothing before |
| `wrnodev …` | inside `.control`, on the **op** row, **below the `$sim_status` guard** | the guard `quit 1`s on failure, so a failed operating point can never overwrite a good saved one with the zeros `CKTncDump` prints |
| `rusage …` | **last inside `.control`**, above the completion marker | issue 1433 row CK17 says the marker is *"the last line inside .control"*, and another issue's pinned anchor does not move |

**A third refusal tier in `render_deck`**, beside the precheck's and the measurement's, because
a `.state` can be hand-edited — and it raises with the **evaluator's own sentence**, not a
second spelling of it (row OT7b asserts the identity).

---

## ⚠ THE ONE THE PLAN GOT WRONG IN THE OTHER DIRECTION: `rusage devtimes`

PLAN.md §10c names `rusage devtimes` for the health strip. It prints **nothing**, on both
binaries, at rc 0 — and it is not "unsupported", it is **compiled out**: `resource.c:322-335`
loops over `CKTstat->devCounts[]` and `continue`s on every zero, and the only writers of that
array sit inside `#ifdef PER_DEVICE_STATS`, whose definition at `cktload.c:30` is the literal
commented-out line `// #define PER_DEVICE_STATS`. On the fork an **unknown** keyword at least
draws `Note: no resource usage information for …`; `devtimes` draws nothing, because it is
recognised and empty. apt 45.2 is silent for both.

So the strip is `rusage tranpoints accept rejected totiter` and **row RH2 asserts that
`devtimes` is not in it**. Sabotage **m23** puts it back and RH2 reds.

---

## Both arms, before and after, from the `RESULT:` line

Baselines re-measured here before any edit; all seven matched the brief exactly.

| suite | headless BEFORE | headless AFTER | display BEFORE | display AFTER |
|---|---|---|---|---|
| `test_ase_converge_1459` | — (new) | **ALL PASS (76)** | — (new) | **ALL PASS (76)** |
| `test_ase_core` | ALL PASS (636) | **ALL PASS (638)** | ALL PASS (636) | **ALL PASS (638)** |
| `test_ase_persist` | 49 rows | **ALL PASS (49)** | 153 rows | **ALL PASS (153)** |
| `test_ase_dialogs` | ALL PASS (37) | ALL PASS (37) | 1 FAILED (382+2) | **1 FAILED (384)** |
| `test_ase_sp_1452` | ALL PASS (58) | ALL PASS (58) | ALL PASS (58) | ALL PASS (58) |
| `test_ase_meas_1443` | ALL PASS (113) | ALL PASS (113) | ALL PASS (113) | ALL PASS (113) |

⚠ **`test_ase_persist`'s "before" is a red I caused and then fixed**, and it is worth naming:
the schema key list has **a second copy** in that suite, so updating only `test_ase_core.tcl`
left `1 FAILED (48 passed)` / `1 FAILED (152 passed)`. Measured both arms before and after the
repair; the row COUNT never moved. The brief's "suites that move" did not mention it, and
nothing but running the suite could have.

The one display red is **`G2sens`**, issue **1436**, standing before I started, value
unchanged at `{1 1 0 1 0 Entry Entry normal}`. It is the only failure on either arm of any
suite below, and it is not mine.

**Neighbourhood, headless, all ALL PASS and all with a `RESULT:` line:**

| suite | | suite | |
|---|---|---|---|
| `test_ase_preflight` | 235 | `test_ase_simreg_0931` | 117 |
| `test_ase_window` | 56 | `test_ase_simcaps_0948` | 211 |
| `test_ase_launch` | 28 | `test_ase_simdlg_0937` | 5 |
| `test_ase_interact` | 10 | `test_ase_current_repair` | 51 |
| `test_ase_options_1437` | 75 | `test_ase_result_case` | 31 |
| `test_ase_view` | 32 | `test_ase_simchoice_1395` | 31 |
| `test_ase_optsheet_1441` | 62 | `test_ase_predeck_1439` | 78 |
| `test_ase_effective_1442` | 92 | `test_ase_optier_0963` | 109 |
| `test_ase_final` | 82 | `test_ase_cosim` | 341 |
| `test_ase_plot` | 31 | `test_ase_sod_case` | 53 |
| `test_ase_savestate_adopt` | 13 | `test_ase_dirty` | SKIP (needs a display) |

⚠ **Section EE starts real simulators, on BOTH binaries, and both ran** — `grep -c SKIPPED`
on both arms' logs is **0**. Every run in this receipt printed a `RESULT:` line; there is no
run whose absence of output I am reading as a pass.

**`.state` byte identity: 104 committed files, 0 mismatches** — measured live through
`ase::state_load` → `ase::state_serialize`. **With its non-vacuity control in the same loop**:
the first file with one new key set re-serializes **differently**, so the loop is comparing
rather than agreeing with itself. `test_ase_core` row **CP7** (the corpus row) and **R1x** (the
new pair) both red under sabotage **m26**.

---

## THE SABOTAGE CAMPAIGN — 35 mutations, 33 killed, 1 declared equivalent, 1 that deleted a row


One runner at a time, each on its own line; restore is `cp` from a pristine snapshot with an
**md5 compare printed every time** — `restore: OK` on all **35 of 35**, `MISMATCH` **0 of 35**,
and the tree's `src/ase.tcl` md5 after the last one is the pristine `7b65e8d18b3be8773cb0697317260a66`.
The table is a name+status diff, never a count. `core` means `test_ase_core`. **Every row below
was re-run against the FINAL suite in one sweep**, so no number here predates a row I added
later.

| # | what I broke | conv | core | rows that reddened |
|---|---|---|---|---|
| **m1** | the table is parsed by COLUMN POSITION | 5 FAILED | — | `NC1` `NC1b` `NC4` `NC5` `NC5b` |
| **m2** | the star is never detected | 7 FAILED | — | `NC1` `NC2` `NC4` `NC5` `NC5b` **`EE4/apt`** **`EE4/fork`** |
| **m3** | "table present" means every row is the problem | 7 FAILED | — | `NC1` `NC2` `NC3` `NC4` `NC5` `EE4/apt` `EE4/fork` |
| **m4** | branch currents are offered to the canvas by default | 5 FAILED | — | `NC2` `NC4` `NC5` `EE4/apt` `EE4/fork` |
| **m5** | an unparseable line ENDS the table | 1 FAILED | — | `NC5` |
| **m6** | the numeric test on the value fields is dropped | 1 FAILED | — | **`NC5`** — see below |
| **m7** | a start marker sets `running` unconditionally | 2 FAILED | — | **`LD2b`** `LD6b` |
| **m8** | a failure marker wins over a success marker | 1 FAILED | — | **`LD6b`** — see below |
| **m9** | rung 1 is reported as FAILED | 9 FAILED | — | `LD2` `LD2b` `LD5` `LD6` `LD6b` `LD8` `LD9` `EE2/apt` `EE2/fork` |
| **m10** | an unterminated tail is never pending | 1 FAILED | — | `LD4` |
| **m11** | **DECLARED EQUIVALENT** — one trial per line instead of `-all` | ALL PASS | — | **none, and the reason is a measurement** — see below |
| **m12** | the ramp argument carries a value from the state | 1 FAILED | — | **`OT2b`** — see below |
| **m13** | the `.options` spelling is emitted instead of the command | 10 FAILED | — | `OT2` `OT2b` `OT3` `OT4` `OT5` `OT6` `OT10` `DK1b` `EE2/apt` `EE2/fork` |
| **m14** | the XOR clash check is dropped | 2 FAILED | — | `OT7` `OT7b` |
| **m15** | the every-rung-off check is dropped | 2 FAILED | — | `OT8` `DK2` |
| **m16** | the silently-replaced step is passed down | 2 FAILED | — | `OT9` `OT9b` |
| **m17** | the strategy line is emitted BELOW the analyses | 3 FAILED | — | `OT10` `EE2/apt` `EE2/fork` |
| **m18** | **THE HEADLINE** — the seed restore emits the `.ic` file verbatim | 6 FAILED | — | `WR4` `WR4c` `WR7` `DK1b` **`EE5/apt`** **`EE5/fork`** |
| **m19** | the save is emitted ABOVE the `$sim_status` guard | 1 FAILED | 5 FAILED | `WR7` · `C4` `C5` `CK21` `D1` `WK7` |
| **m20** | the restore cards move INSIDE `.control` | 1 FAILED | — | `WR7` |
| **m21** | the missing-file refusal is dropped | 1 FAILED | — | `WR6` |
| **m22** | the no-OP-row refusal is dropped | 1 FAILED | — | `WR5` |
| **m23** | the health line gains `devtimes` | 1 FAILED | — | **`RH2`** |
| **m24** | the health parser drops one counter | 3 FAILED | — | `RH3` `EE2b/apt` `EE2b/fork` |
| **m25** | the health line goes BELOW `.endc` | 5 FAILED | — | `RH4` `EE2/apt` `EE2/fork` `EE2b/apt` `EE2b/fork` |
| **m26** | the three keys leave `ase::omit_if_empty` | ALL PASS | 2 FAILED | **`CP7`** `R1x` |
| **m27** | **D34 BROKEN** — no hook falls back to ngspice content | 5 FAILED | — | `NC6` `LD12` `OT11` `RH5` `WR8` |
| **m28** | a rung not named in the strategy defaults to OFF | 1 FAILED | — | `OT6` |
| **m29** | **PLAN.md's OWN SENTENCE** — the rung notes are unconditional | 1 FAILED | — | **`LD11`** |
| **m30** | ATTACK THE INPUT — only the first table is read | 1 FAILED | — | `NC4` |
| **m31** | `render_deck`'s third refusal tier is removed | 2 FAILED | — | `DK2` `OT7b` |
| **m32** | the `.ic` file's comment header is taken as cards | 1 FAILED | — | **`WR4c`** |
| **m33** | the "anything after it" test counts whitespace | 1 FAILED | — | `LD4` |
| **m34** | `register_backend` stops dropping the rung memo | 1 FAILED | — | **`LD1b`** |
| **m35** | the tokeniser becomes a split on literal spaces | ALL PASS | — | **none — the row it was written for was DELETED.** See below |

(`—` in the core column means `ALL PASS (638)`.)

### The results worth reading twice

* **m18 is the issue, end to end.** `WR4` is the Tcl claim, `WR7` is the position, `DK1b` is
  the deck, and **`EE5` is the real simulator on both binaries answering `2.500000e+00` where
  it should answer `1.500000e+00`.** Five rows and two binaries, from one gate.
* **m6 survived my first list, twice.** `NC5` injects a stderr line into the table; my first
  version injected two lines that the field COUNT already turned away, so the numeric test was
  never exercised. The second version injects `v(out) = 9.999550e-01` — a real `print` line,
  on the same stream as the table, **three whitespace-separated tokens in a three-column
  table**. It *still* passed, because the row asked only for the starred names and the extra
  row carries no star. **It reds only once the row asks for the row COUNT as well.** That is
  issue 1457's surplus lesson inside a canned-text row.
* **m8 needed a row nobody would have written.** `LD6` (dynamic failed, then true completed)
  passes under m8, because the success line is simply the last one seen. **`LD6b` is the same
  fixture REVERSED** — and on a folded log the order is whatever two buffers decided, which is
  this stage's whole premise. One mutation, one arrangement, and only one of them can see it.
* **m12 is the sabotage my first list did not have, exactly as the brief warned.** The plan
  says *"the ramp argument is ALWAYS emitted as 0"* and nothing tested it against a state that
  asks for a ramp. `OT2b` now feeds three ramp spellings into a hand-edited `.state` and
  demands `optran 1 1 1 100n 10u 0` from all of them.
* **m29 is PLAN.md's own sentence as a mutation.** §10b wants *"this operating point may come
  from a transient"* on the OP form. Unconditional, it tells a user their exact operating point
  is suspect when it is exact — measured, the shipped defaults leave rung 4 **armed and never
  called**. `LD11` asks for the sentence on a run that descended, the *gmin* sentence on a run
  that stopped there, and **nothing** on a run that solved at rung 1.
* **m11 is declared equivalent, with the measurement behind it.** The `-all` on the trial
  regexp is defensive: `Trying gmin = <v> ` and `Supplies reduced to <p>% ` end without a
  newline and the FOLLOWING `Note:` supplies it, so **no measured line ever carries two
  trials** — five captured transcripts, both binaries, and the `os.read` chunk transcript in
  `evidence/ladder-streams.md`. `-all` and "first match only" are the same function on every
  input this parser can receive. Kept because it is correct and free; recorded here because an
  unreddened mutation that is not declared is an unreddened mutation that is hidden.
* **m35 deleted a row instead of proving one.** I wrote an `NC7` asserting that a CRLF log
  parses identically (the tree targets Windows — `XSchemWin/`). **Three independent
  mutations failed to make it fail**: a charset-less `string trimright`, `\S+` tokenising and
  `string trim` before any split each handle `\r` on their own. Per this batch's own doctrine —
  *"a row that cannot be made to fail proves nothing"* — the row was **removed**, and the
  finding is recorded here instead: CRLF robustness holds through three paths and no single
  plausible edit breaks it.

### The six ways a row fails to fail

1. **Fixtures that never disagree.** Every extractor has a control that must answer empty:
   `NC3b` (a log with no table), `LD4b` (the same tail with its newline back), `OT7c` (the
   same Options rows with no strategy), `RH3b` (a log with no counters), `WR7b` (the save
   rides the OP row and no other), `DK1b` (a bench that DOES ask changes the deck in exactly
   four places), and the `.state` loop's own control.
2. **Position asked where the mechanism is last-writer-wins.** Inverted deliberately four
   times — `OT10`, `WR7`, `RH4` and `DK1b` assert deck POSITION, because all four wiring sites
   are order-sensitive for a measured reason, and m17/m19/m20/m25 are the four mutations.
3. **An extractor that returns nothing.** Every reader is total and answers a comparable
   value: `NOPROC`, `RAISED:…`, `NORUNG`, `NOT0`, `-1`, `{}`. Every `c_ans` call goes through
   one wrapper.
4. **A sabotage missing from the generator.** Mine was short by **three**, and all three were
   expensive: **m12** (the ramp), **m8's reversed arrangement**, and **m6's row-count
   direction**. Each is now a row that did not exist when I started.
5. **Two halves tested in different suites.** Section **EE** is the answer: the deck ASE-L
   renders is RUN, and its real log is read back through ASE-L's own parsers, on both
   binaries.
6. ⚠ **A one-directional row.** `EE2` asks *"did the parser find the rungs it expects"* and
   would pass with a rung it has never heard of sitting unread in the same log. **`EE3` asks
   the other way**: every `Note:`/`Warning:`/`Error:` line the real ladder printed must be
   claimed by a marker or by a declared ignore, with the count of CLAIMED lines as its
   positive control so an always-empty answer cannot pass by doing nothing. A new upstream
   rung, a renamed message, or a variant nobody wired up shows up there **by its own text**.

---

## ⚖ R9 — every new user-facing sentence, verbatim

**None of these is implemented in a widget** — `src/ase_window.tcl` is untouched — but core
mints them, so they are mine to file and the user's to ratify. `owed.sh add rule 1459`.

### The four rung labels

```
Newton from the initial guess
gmin stepping
Source stepping
Transient operating point
```

### The transient rung's caution, shown beside its control

```
ON by default in this simulator. It hands back the TRANSIENT state at its stop time as the operating point: measured 0.9999550 instead of 1.0 on a 1 us RC.
```

### The three "which rung answered" sentences — CONDITIONAL, one per rung that really answered

```
This operating point came from gmin stepping, not from a plain solve.
This operating point came from source stepping, not from a plain solve.
This operating point came from a transient, not from a DC solve.
```

### The refusal sentences, each with its fix

```
the Options sheet sets <names>, and the operating-point strategy overrides those rows without saying so
   fix: remove those rows from the Options sheet, or switch the strategy off
every step of the operating-point strategy is switched off, so nothing would solve the operating point
   fix: switch at least one step back on
the transient step <s> is larger than the stop time <t>, and the simulator rejects the whole setting when it is
   fix: use a step of at most <t/50>
the simulator silently replaces a transient step larger than the stop time over 50 with <t>/50, so <s> would not be the step it used
   fix: use a step of at most <t/50>
'<s>' is not a time this simulator can read
   fix: give the transient step as a number, e.g. 100n
'<t>' is not a time this simulator can read
   fix: give the transient stop time as a number, e.g. 10u
the transient operating point needs a stop time greater than zero
   fix: give a stop time, e.g. 10u
there is no enabled OP row, so there is no operating point to save
   fix: enable an OP analysis, or switch the save off
no file is named for the saved operating point
   fix: name a file
the saved operating point '<path>' cannot be read, and seeding from it needs its contents
   fix: run once with Save operating point ticked, or restore with force
'<mode>' is not a way to restore an operating point
   fix: choose seed or force
```

The one singular/plural variant is real: with one clashing row the first sentence reads
*"sets noopiter, and the operating-point strategy overrides that row"*.

`render_deck`'s third tier raises `ase: <one of the sentences above>; nothing was rendered` —
the evaluator's own words, not a second spelling (row `OT7b` pins the identity).

⚠ **Two words I want the user's eye on specifically.** `seed` and `force` are the two restore
modes and they appear in a refusal (*"choose seed or force"*). They are the names the deck
half needs; whether the FORM calls them that is task 2's copy and the user's ruling.

---

## Corrections to this brief and to `PLAN.md`

| | |
|---|---|
| **C1** | ⚠ **§10's four named procs are ALL CONTENT under D34/D36, and the plan names them as if they were core.** `CKTncDump`'s layout, the ladder's line text, `optran` and `wrnodev` are every one of them a fact about ngspice. Each therefore ships as a PAIR — an `ase::…` reader that asks a hook, and an `ase::backend::ngspice::…` speller. Eleven hooks, not four procs, and that is where the line-count difference comes from |
| **C2** | ⚠ **§10c's `rusage devtimes` is compiled out in every stock build.** `// #define PER_DEVICE_STATS`. Measured silent on both binaries, at rc 0. **Must not be offered**; row RH2 forbids it |
| **C3** | ⚠ **§10c's `.include <file>` restore silently changes a transient's answer**, because `wrnodev` writes `.ic` and `.ic` is a never-released clamp in the transient operating point. The plan's one-line shape needed a mode. Measured; see the second headline |
| **C4** | ⚠ **§10b's OP-form sentence must be conditional.** Already recorded in `evidence/optran-and-ncdump-verified.md` §2 and now *implemented* — `ase::ladder_ran_notes`, row LD11, sabotage m29 |
| **C5** | ⚠ **The brief's own proof recipe for the rung-4 checkbox is self-defeating.** Combining `.options noopiter gminsteps=0 srcsteps=0` with an `optran` line does NOT leave only rung 4: args 1–3 override the options. The deck that proves it is the `optran` line alone |
| **C6** | ⚠ **§10a's starred table IS capturable**, and this receipt carries two variants from real runs on both binaries. The driver's failure to capture one was the `.options` spelling, not the diagnostic |
| **C7** | **`test_ase_persist.tcl` is a SECOND copy of the schema key list.** Not in the brief's suites-that-move list; found only by running it. Left as two copies with a comment saying why, and saying that a third would be a defect |
| **C8** | ⚠ **An eighth measured binary difference:** apt 45.2 does **not** print `Note: Optran is deselected.`; the fork does. Same behaviour, different evidence — so the absence of that line is not evidence the rung is armed (row LD10) |
| **C9** | ⚠ **A ninth:** apt 45.2 answers an **unknown** `rusage` keyword with complete silence; the fork prints `Note: no resource usage information for …`. Never read back your own flag |
| **C10** | **`optran 1 1 1 200n 10u 0` DOES trip the `finaltime/50` note**, although 200 n is 10 µ / 50 exactly in decimal — `INPevaluate` lands a hair above `1e-5/50.`, and ASE-L's own parse lands in the same place, so the refusal fires exactly where the simulator's note does. Row OT9 pins the boundary at 200n/199n |
| **C11** | **`wrnodev` and `CKTncDump` filter the same node list DIFFERENTLY**: `wrnodev` drops every `#`-bearing name including `#branch` (`com_wr_ic.c:64`), `CKTncDump` keeps `#branch` and drops only internal `#` nodes (`cktncdump.c:24`). A caller that assumes one filter for both is wrong about one of them |
| **C12** | **`PLAN.md`'s ≈ +260 for `src/ase.tcl` is +948** (441 comment/blank, 507 code) — three surfaces (parser, emitter, refusal) times two sides (schema, content), plus the wiring and the third tier. Recorded because the sequencing table's line counts feed the batch's own estimates |
| **C13** | **The `-all` on the trial regexp is not load-bearing** (m11): no measured log line carries two trials |
| **C14** | **CRLF robustness holds through three independent paths** and no plausible single mutation breaks it, so the row asserting it was deleted rather than shipped green-and-unfalsifiable |

---

## What I did NOT ship, and why

* **No change to `src/ase_window.tcl`.** md5 verified identical after every sabotage restore.
  The ladder pane, the remedy assistant, the canvas highlight and the health strip are task 2.
* **No canvas highlight and no `ase::netlist_map` call.** `ase::ncdump_failing` produces the
  list; mapping it onto nets and lighting them is task 2, and the `kind` key is there so task 2
  never tries to light a branch current.
* **No live pane and no second capture channel.** `ase::ladder_parse` is built for BOTH — it
  reads a finished file correctly and reports an unterminated trailing trial as the rung in
  progress (rows LD3, LD4, LD4b). Un-folding `run_cmd`'s `2>@1` is a change to the capture and
  is task 2's to price.
* **No `optran` ramp control.** Argument 6 is emitted as `0` and there is no state key that can
  change it (row OT2b).
* **No `.options optran` compatibility.** It is inert and offering it would be a control that
  does nothing.
* **`tests/run_regression.tcl` not run** — the driver's, solo (issue 0990).

---

## Ledger

Backed up before the write: `/tmp/stage10/owed/backup_205530` (`cp -a` of
`~/.claude/xschem_owed`).

| | rule | look | suite |
|---|---|---|---|
| **before** | 172 | 65 | 10 |
| **after** | **173** | 65 | 10 |

* `add rule 1459` — printed `recorded`. The labels, the caution, the three conditional
  sentences and the twelve refusal sentences above. **The user's to answer**; nothing is
  blocked on it.
* **No `look` filed, deliberately.** This task ships **no pixels**: `src/ase_window.tcl` is
  untouched and every new string is data a widget will later read. Task 2 owes the eyeballs —
  and PLAN.md §10's own "Re-measure on the dev display" paragraph already says the lit nets
  must be looked at on the user's **real** screen (`AUDIT_DISPLAY=$DISPLAY`, not `:99`).
* **No `suite` debt filed, deliberately.** `test_ase_converge_1459` has no GUI leg: **76 checks
  and identical `ok:` lists on both arms** (`diff` is empty). A `:0` debt is owed by a GUI
  feature's suite, and this is not one.

One added, **none destroyed**. No `clear` of any kind was issued.

---

## Debts this task leaves

1. ⚖ **The nineteen sentences above** — `owed.sh add rule 1459`. **Blocking nothing.**
2. 🔭 **Task 2 inherits three things this half measured and did not use**: the `kind` key
   (do not light a branch current), the `pending` rung (a live pane must read BYTES, not
   lines), and `ase::ladder_ran_notes` (the OP-form sentence is earned, not assumed).
3. ⚠ **`run_cmd`'s `2>@1` is still the only capture**, so the ladder reaches every reader out
   of order. Every parser here is content-matched and immune; a **live** pane is not, and the
   second channel is task 2's to price. `evidence/ladder-streams.md` §2 has the measurement.
