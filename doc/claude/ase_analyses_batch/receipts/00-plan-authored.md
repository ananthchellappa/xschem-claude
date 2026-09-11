# Receipt 00 — the plan was authored, verified against three lenses, and repaired

**Date.** 2026-09-09.
**Scope.** `doc/claude/ase_analyses_batch/` only. **No file under `src/` was touched, no suite row
was added, no issue was minted, `doc/claude/issues/NUMBERING.md` was not advanced** — its tail still
reads *"The next free number is 1400."* `git status` in `/home/analog/dev/xschem-claude` shows no
tracked file modified; this batch directory remains untracked, as do the two neighbouring ones.

---

## What was produced

The six canonical files `evidence/ase-conventions.md` §10.1 names, plus `evidence/` and this
`receipts/` directory:

| file | lines | what it is |
|---|---|---|
| `PLAN.md` | 2777 | **THE deliverable, authoritative.** Shape B: §0 corrections and measured facts, the three-axis split, fifteen stages each with *What you see* / *Files and procs* / *Suites that move* / *Re-measure on the dev display* / *Rulings in this stage*, the ADE-L comparison, the ruling ledger, the costed refuse-list, the sequencing table, what is still open, and one upstream bug with its patch shape |
| `APPENDIX_ngspice_analyses.md` | 2772 | the ngspice side at the parameter level — eleven analyses plus the pseudo-analysis, both option catalogues, the results routing (now normative), the trap and defect register, what it does not cover |
| `DECISIONS.md` | 613 | D1–D33 and ⚖ R1–R9, the user's carried unresolved with options, trade-off and a recommendation |
| `LEDGER.md` | 600 | baseline measured before any crew, one empty section per stage 0–14, the debts this batch already knows it will leave |
| `CREW_BRIEF.md` | 344 | the standing rules with their scars, the "do not change designs" doctrine in three senses, the preflight, the reading order |
| `README.md` | 150 | the request verbatim, the file table, the one-paragraph version, how it was produced |

The user's request is quoted **verbatim and identically** in `README.md`, `CREW_BRIEF.md` and at the
head of `PLAN.md`, with no paraphrase anywhere.

---

## What was measured for this pass

All against `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46-419-gccebdf2a2`) and,
where named, `/usr/bin/ngspice` (`ngspice-45.2`), in a scratch directory. Nothing was run on a bench
under `sky130A/`; no simulation touched `~/.xschem/`.

| probe | result | what it settled |
|---|---|---|
| `find . -name '*.state'` / `git ls-files \| grep -c '\.state$'` | **105 / 104**; the extra is `sky130A/…/tb_bandgap/debug_st1/tb_bandgap.state`, untracked | PLAN's acceptance number was inverted in six places |
| `sens v(mid) r*:r ac lin 5 1k 5k` | swept **1.000000e+03, 8.000000e+05, 6.400000e+08, 5.120000e+11, 4.096000e+14** | the SENS-AC `lin` geometric-sweep trap, un-fenced in PLAN |
| `sp lin 2 100meg 1g` / `sp lin 3 100meg 1g` | **1 row / 3 rows** | `sp` carries `ac`'s two-point defect; Stage 9 had no rule |
| `tf v(b) v1` then `display` | `Transfer_function`, `output_impedance_at_V(b)`, `v1#Input_impedance` | PLAN spelled the first one lower-case |
| `option method=gear` + `op` + bare `option` | `Integration Method = GEAR`, `MaxOrder = 2`, **no warning** | APPENDIX §3.1.1's "REJECTED from the `option` command" was false |
| `.options bogusdot=1` + `option bogusopt=3`; and `.options frobnicate` + `.op` | **no message on either route**; bare `set` lists both invented variables | APPENDIX §3.1's "`Error: unknown option`" was false on ASE-L's route |
| the four-line DISTO deck, both binaries | **rc 139 on both** | the segfault is upstream, and the quoted reproducer works |
| the `[A-M2]` / `[A-M4]` / `[A-M5]` / `[A-M6]` decks, as now written into the APPENDIX | all four reproduce their quoted numbers and literals | the inlined decks are real reproducers, not prose |
| `tran 1u 20u` family on a fully quoted RC + pulse deck | **111 / 89 / 156 / 110 / 21** | §2.4's point-count table was unfalsifiable without its deck |
| `/usr/bin/ngspice` `help pss` / `help sp` | both answer; self-identifies `ngspice-45.2` | a PSS-capable binary is already on this machine; no rebuild needed for Stage 14 or Stage 2's Detect leg |
| `cktntask.c:120-122` | `TSKnumSrcSteps = 1; TSKnumGminSteps = 1; TSKgminFactor = 10;` | `gminsteps` defaults to **1**; the `10` is `gminfactor` |
| `cktsopt.c:111-113` | `case OPT_DEFAS: task->TSKdefaultMosAD = …` | `.options defas` sets the **drain** area |
| `analysis.c:36-59`, `cktsopt.c:389-403`, `commands.c:324/332` | twelve `analInfo[]` entries, one of them the non-runnable `OPTinfo`; two verbs gated | **eleven** analysis types, **nine** unconditional, ten runnable in this build |
| `test_ase_simreg_0931.tcl:732-743`, `:791` | `a_runcmd_said` returns `[list $::a_rc2 …]` and `$::a_rc2` is `[a_runcmd $deck]` | row **D4 does pin argv** — PLAN's §0.1 "correction" was itself false |
| `grep -rn 'chana\.' tests/headless/test_*.tcl \| grep -v …` | exactly **six** lines, all in `test_ase_dialogs.tcl` | five was wrong in DECISIONS and LEDGER |
| `grep -rn 'E12' tests/headless/` and `check` names in `test_ase_cosim.tcl` | `E12` in two suites, neither byte-identity; cosim's checks are `RD1`–`RD11`, `E5` only in comments | two citations named rows that do not mean what was claimed |
| `ase::ui::chana_ok` (`ase_window.tcl`, hint `:4650-4657`) | `else { set row [dict create type $type] }` then `lappend rows $row` | picking a new type and pressing OK already adds a row; ⚖ R4 costs no reach |
| `acan.c:103-114`, `niiter.c:37-39`, `noisean.c:511`, `span.c:417-427`, `trcvdefs.h:20`, `acsetp.c:34-39` | read line by line | four citation-drift claims checked; three rejected, one applied |

---

## What was verified, by which lens

Three verification lenses ran over the finished documents and returned **44 findings** between them,
with a large overlapping "confirmed correct" set. The overlap is itself evidence: the plot literals,
the `setplot previous` walk with its 1:1 sidecar, the 57/29/14 `OPTtbl` split, the exact `DEVdisto`
and `DEVnoise` device lists, every `md5` and line count in `LEDGER.md`'s baseline, every proc named
in `CREW_BRIEF.md`'s preflight, and all twelve `help <verb>` results reproduced independently.

* **facts** — 20 findings, 5 of them damaging enough to mislead an implementer.
* **conventions** (house shape) — 13 findings; PLAN's Shape B adoption confirmed faithful, the
  failures all *between* documents rather than inside PLAN.
* **coverage** — 12 findings; all twelve `analInfo[]` entries confirmed placed with a stage or a
  reasoned refusal, and three capabilities found unreachable-and-unnamed.

---

## What was applied

**Every finding that survived verification.** Grouped by what it repairs.

### The five that would have produced wrong work

1. **PLAN §0.1 was itself false.** It claimed row **D4** of `test_ase_simreg_0931` "asserts nothing
   about argv" and that only A2/B5/B6/B11 pin `run_cmd`'s word order. D4 pins the full command line
   through `[lindex $D4SAID 0]`, and **B12** pins it too. §0.1 is rewritten as a six-row table
   (A2/B5/B6/B11/B12/D4, plus L11 for the exe alone), carries a visible ⚠ CORRECTION saying what it
   used to say, and records that `DECISIONS.md` ⚖ R1 and `LEDGER.md` Stage 7 were **right** and this
   plan was the outlier. Stage 7's "⚠ It is **not** row D4" is replaced by the six-row list with
   "re-baseline all six in one commit or five go red". New correction **C28**.
2. **PLAN §0.5 inverted the `.state` counts** and told a crew to overwrite fourteen *correct* suite
   comments with a wrong number. Retitled, both probes quoted, the untracked 105th named, the "fix
   the comments" instruction replaced by "**do not change those comments**", and the six propagated
   "105 committed" changed to 104 (Stage 1, Stage 2's R4, Stage 11's R8, the Acceptance bullet, and
   ledger rows R4/R6/R8). New correction **C29**.
3. **`gminsteps` shipped with the wrong ngspice default** (10; it is 1) in §7a, in the `ase::opt_line`
   comment, and pre-filled into Stage 10b's ladder pane and its example emission. Because Stage 7c
   makes "Changed only" the default view and computes it from the catalogue's `default` column, a
   wrong default makes a shipped value read as *changed* and hides a real change. Fixed in all four
   places, with `cktntask.c:120-122` quoted in the registry comment. New correction **C30**.
4. **The `sens … ac lin` geometric sweep was un-fenced in PLAN.** Added as trap **T13** with the five
   measured frequencies, and as a `sens_ac_lin` `refuse` rule on Stage 5's registry entry, with the
   reason: `inc_freq()` tests `noisedef.h`'s `LINEAR 3`, not `SENS_LINEAR`.
5. **`sp lin 2` was un-fenced.** Trap **T6** amended to name both `ac` and `sp`; Stage 9 gains the
   same `lin_two` rule with `span.c:417-427` cited.

### Cross-document contradictions, now resolved

6. `DECISIONS.md` D1 and `CREW_BRIEF.md`'s heading and list: **seven → eight** copies of "what is a
   `dc` analysis", with the print anchor inserted and its issue-1243-versus-0964 provenance stated.
   `README.md`'s one-paragraph version and CREW_BRIEF's commit template follow.
7. **five → six** widget-path lines, in `DECISIONS.md` D32 and `LEDGER.md` Stage 1, with the six line
   hints and the note that the missed one is a `send_return` — a hang, not a red.
8. **"~250 rows / ~86 keywords" → 220** in `DECISIONS.md` D33 and `LEDGER.md` Stage 7, each with its
   own ⚠ CORRECTION; PLAN §0.4's "the siblings still say ~250" paragraph rewritten to say they were
   fixed here.
9. **`LEDGER.md`'s debt table** restructured: M2 (partly), M3, M4 and M6 moved into a *Closed by
   measurement* block, struck rather than deleted, each pointing at the PLAN section that closed it;
   "Debts M3 and M4 must be paid before this stage starts" struck from Stage 6; the two dead
   `../dor/*.cir` references replaced with inline deck descriptions.
10. **One `M<n>` numbering space across the batch**: `M1`–`M12` inherited from
    `evidence/design-of-record.md` §16 (so **M5** is the multi-raw family everywhere), `M13`–`M15`
    this pass's additions, `M2'` renamed **M15**. PLAN's "Still open" table renumbered and extended
    with M13/M14/M15; APPENDIX §8 and LEDGER's table agree.
11. `transfer_function` → **`Transfer_function`**; correction **C26** extended to name all three
    measured spellings and **C31** added.
12. **"Twelve analysis types … the other ten are unconditional" → eleven types, twelve grid rows,
    nine unconditional**, with `OPTinfo`'s non-runnability shown from `cktsopt.c:389-403`. APPENDIX
    §0 changed to "ten runnable in this build (eleven across builds)". CREW_BRIEF, which had it
    right, was left alone.
13. **`defas` added to Stage 7d** as an offer-with-the-defect-named row, and as trap **T14**.
14. `test_ase_cosim.tcl`'s **RD/E5** → **RD1–RD11** (and RD4/RD5/RD6 in Stage 12), with a
    parenthetical that `E5` there is a comment label, not a check name. LEDGER's Stage 6 "E5/M1" was
    already the *optier* rows and is correct; it now says so explicitly.
15. **"row E12"** dropped from `DECISIONS.md` D32 and `LEDGER.md` Stage 1, each replaced by PLAN
    Stage 1's verified byte-identity list, with a ⚠ CORRECTION naming the two unrelated `E12`s.
16. **⚖ R9's closing sentence** corrected: Stage 1 mints no sentence, **Stage 0 mints exactly one**,
    filed as a rule debt when it lands and paid with Stage 3's batch. PLAN Stage 0's "Rulings: None"
    became "None that block", and its header line and LEDGER's Stage 0 blurb follow.

### House shape

17. **`PLAN.md` cited `APPENDIX_ngspice_analyses.md` zero times** while the APPENDIX claimed every
    plan item cites it. Fixed: a pointer at the head of §0, and a *"the parameter-level source for
    this stage is…"* line on Stages 3, 4, 5, 7, 8, 9, 11, 12, 13 and 14, plus §7 on the trap table
    and §6.2/§6.3 on the plot literals. **31 citations now.**
18. **Shape B's fifth per-stage field, `### Re-measure on the dev display`, was missing from all
    fifteen stages.** Added to all fifteen, each naming what to take and whether a look debt is
    filed. Stages 0, 1 and 4 read *"None — this stage is headless by construction"* and say why.
19. **The spec-of-record amendment** was a single unanchored sentence in the Acceptance boilerplate
    owned by no stage. It is now a five-row table naming each paragraph by **heading**, quoting its
    first words, giving a parenthesised line hint and **naming the owning stage**; `LEDGER.md`'s
    per-stage template and all fifteen stage blocks gain a `spec paragraphs rewritten` row; and
    Stage 0 gains sub-item **0d** for the **two** stale top-only sentences (`:946-947` and `:997`),
    which the file's own issue-0643 section at `:697` already contradicts.
20. **`README.md`** declared PLAN / APPENDIX / DECISIONS / LEDGER unwritten. Its file table now lists
    all six with one-line descriptions and the "Not written yet" paragraph is gone.
21. **`CREW_BRIEF.md`** sent every crew to `evidence/design-of-record.md` as *"it is the plan"* and
    never named PLAN.md. Its opening and its nine-step reading order now put **PLAN.md third, in
    full**, with the APPENDIX beside it and the design of record read *"as evidence, not scripture"*.
22. `DECISIONS.md`'s four bare line citations in running text (`ase_window.tcl:83`, `ase.tcl:10863`,
    `:665`, `:110`) converted to proc/variable names with parenthesised hints — its own stated rule.
23. Stage 0's code sketches no longer hard-code issue **1400**; they read `# <ISSUE>:` with the
    substitution rule stated under each block.

### Coverage gaps

24. **Three capabilities were unreachable and named in no refusal**: the ~23 `rusage` per-phase
    timers beyond the four in Stage 10c's strip, `snsave`/`snload`, and `aspice`. All three are now
    costed bullets in *What this plan refuses, and why*, and Stage 12's line corrected to say
    `snsave`/`snload` are refused **generally**, not only on an event deck.
25. **The results-routing table** lived only in `evidence/design-of-record.md` §9.1 — a document PLAN
    demotes — while D30 makes routing *normative*. Lifted into **APPENDIX §6.2** with `destination`
    and `label shown` columns and four rows it lacked (`.four`, `meas`, event nodes, contributors),
    carrying both ⚠ notes verbatim; Stage 6d and the Stage 1 registry contract now point there.
26. **A new section, *The ADE-L comparison, and what it rests on***, opening with *"Every statement
    about Cadence ADE-L in this plan is recollection, not measurement — no ADE-L was run for this
    batch"*, walking all fifteen rows of `evidence/ase-ui.md` §6 with the stage that answers each,
    `— (UX batch)` on row 4, and **`NOT ANSWERED HERE`** on row 10 with ⚖ R4's tension left visible.
27. **"ADE-L has no sensitivity analysis at all"** (Stage 5a) replaced by the defensible version:
    ADE-L exposes `sens`; what it lacks is a computed eligibility picker. The same treatment was
    given, unprompted, to Stage 13's *"a category ADE-L does not have at all"* — Spectre has a
    transient-noise capability, so the claim is now about the *Choosing Analyses form's* surface and
    is flagged as the weakest of the nine "ahead of ADE-L" claims.
28. **Stage 2 gains a fourth "What you see" bullet** — picking a type the bench lacks and pressing OK
    already adds a row (`ase::ui::chana_ok`), so ⚖ R4 costs no reach — and ⚖ R4's ledger row says so,
    because the recommendation is only defensible with it stated.

### APPENDIX corrections

29. **§3.1.1's `maxord`/`method` claim withdrawn** with the measurement, the guard at
    `spiceif.c:510` and the `IF_SET` declarations quoted; trap-register row **N13** left as a
    **struck tombstone** rather than deleted.
30. **§3.1's "Unknown keywords" paragraph replaced** by a ⚠ CORRECTION carrying both probe decks and
    their empty output, the `inp.c:1605-1620` / `spiceif.c:510-524` explanation, and the operational
    rule that §8.1's read-back is **mandatory**. Cross-referenced from PLAN Stage 7f.
31. **§3.1's reconstruction of "86" was itself wrong** (it said 57+29 double-counting; hidden-vars
    said 27, not 29). Corrected in both APPENDIX §3.1 and PLAN §0.4: 86 = 57 `IF_SET` + 27
    `IF_ASK`-only + `itl3`/`itl5`, a narrower set counted correctly.
32. **The `[A-M<n>]` decks are inlined**, in the shape `[R-M<n>]` uses — `[A-M2]`, `[A-M4]`,
    `[A-M5]`, `[A-M6]` and §2.4's point-count table — and §10's provenance row no longer points at a
    session scratchpad. **All four inlined decks were re-run and reproduce their quoted results**;
    where the new deck's absolute numbers differ from the old ones (§2.4's point counts, §2.5's
    variable count) the old figures are kept in a second column marked *deck not recorded* and the
    text says which relations are deck-independent.
33. `trcvdefs.h:58` → **`:20`** with the `#define` quoted; §2.5's `stop` row now quotes its own
    message (`Frequency of < 0 is invalid for AC **stop**`) instead of saying "same message", and
    keeps the ⚠ that the error arm writes `ACstartFreq`.

---

## What was rejected, and why

Four claims did not survive checking. Each is recorded here rather than silently dropped, because a
future reader would otherwise re-raise them.

1. **"`DECISIONS.md` ⚖ R1 and `LEDGER.md` Stage 7 wrongly say row D4 pins `run_cmd`; change them to
   A2/B5/B6/B11."** **REJECTED — they were right.** `test_ase_simreg_0931.tcl:790-796` compares
   `[lindex $D4SAID 0]` against `[list ngspice -b $DECK 2>@1]`, and `a_runcmd_said` (`:732-743`)
   returns `[list $::a_rc2 …]` where `$::a_rc2 = [a_runcmd $deck]`. **PLAN was the outlier**, not the
   siblings. Both were extended with the other five row names instead of corrected, and PLAN §0.1
   carries the correction. This is recorded in PLAN §0 as correction **C28** so it cannot be
   re-raised from the old wording.
2. **"`acan.c:103-114` has drifted; the LINEAR arm is at `:107-118`."** **REJECTED — `:103-114` is
   exact.** `case LINEAR:` is line 103 and its `break;` is line 114, counted with `awk`. Left as is
   in APPENDIX §2.5, §7.2 S1 and PLAN Stage 3's `lin_two` refusal string.
3. **"`noisean.c:511` has drifted; the `start != stop` test is at `:510`."** **REJECTED — `:511` is
   exact.** Line 511 is `if (job->NstartFreq != job->NstopFreq) {`; 510 is blank and 512 is the
   guarded `CKTnoise` call.
4. **"`niiter.c:37-39` should be `:38-39`."** **REJECTED as a non-defect.** The clamp is at 38–39 and
   line 37 is the comment that explains it (*"some convergence issues that get resolved by increasing
   max iter"*). A citation that includes the reason is better than one that does not.

One finding was applied only in part: the instruction to make the same `RD/E5` substitution in
`LEDGER.md`'s Stage 6 and Stage 12 blocks. **`LEDGER.md` never cited cosim's `E5`** — its "E5 / M1"
is `test_ase_optier_0963`, which is correct. Only PLAN needed the change; LEDGER gained a clarifying
clause naming the suite.

---

## What the next session should do FIRST

**1. Ask ⚖ R1, and stop.**

> *Transport: keep `-b` this batch and schedule `-p` as a later stage, or move to `-p` now?*

It is the only ruling that **reorders** other stages (7, 10, 11) and it changes ⚖ R2's stakes. The
recommendation in `DECISIONS.md` is to define **one internal run interface now** — start / progress
event / abort / results-located — implement it with `-b` for Stages 0–9, and schedule `-p` as its
second implementation immediately after Stage 10, refusing `libngspice` either way.

**Ask it alone.** The user's standing preference, pinned in this project, is one question at a time
with a short conversation about each before the next is raised. Do not present the nine rulings as a
list. Do not use a multiple-choice picker where the point is to discuss.

**2. Ship Stage 0 — and it does not wait for R1.**

Stage 0 carries no ruling that blocks, moves no existing suite row, and closes the one defect a user
cannot see: an analysis type ASE-L does not know is **silently dropped**, the run completes, a
rawfile is written, nothing is produced, and the box stays ticked.

Do it **RED first**, in this order, because a fix landed without this step has no witness that the
defect existed:

1. Record **T1 solo** (`tests/headless/run_regression.tcl`, issue 0990) under a scratch `HOME` with
   `XSCHEM_DEVDISPLAY_DIR` exported and `--nolog`, **before changing a line**. That number, not
   `LEDGER.md`'s call-site table, is this batch's zero.
2. Write the new `test_ase_core.tcl` D-section row that asserts **today's silence** — a
   `{type noise enabled 1 …}` state renders a deck with no analysis command at all. **Watch it
   pass.**
3. Change the code (§0a, §0b, §0c). **Watch that row fail.** Then invert it to assert the refusal.
4. Add the other three rows: the raised error and its sentence; the control row proving D1 is still
   byte-identical and D2 still has no `dc` line; and the `PF2xx`-shaped `test_ase_preflight.tcl` row
   plus one asserting `set ase_preflight 0` **does not** defeat the type check.
5. Sabotage-verify: no-op `analysis_emit_rank`'s `{}` return, confirm exactly those rows go red,
   restore by `cp` from a pristine copy and md5-compare. **Never `git checkout/restore/stash/clean`.**
6. Fix §0d's two stale top-only sentences in `doc/claude/specs/ase_l.md` in the same commit, and
   record them in `LEDGER.md`'s new *spec paragraphs rewritten* row.
7. Mint the issue by reading **`doc/claude/issues/NUMBERING.md`'s tail at that moment** — it read
   1400 on 2026-09-09 and this receipt is exactly the kind of document the crew brief forbids
   trusting a number from — substitute it for `<ISSUE>` in the two code sketches, and file
   `owed.sh add rule <that issue>` for the one minted refusal sentence.
8. Fill in `LEDGER.md`'s Stage 0 block and write `receipts/01-stage-0-silent-drop.md`. **A stage with
   no receipt is not landed.**

**3. Then Stage 1, and treat its acceptance as a stop condition, not a target.** If re-expressing
today's four types through `ase::analysis_types` cannot reproduce `test_ase_core.tcl` **D1** under
`string equal` — the **whole** `expected_deck`, netlist and cards included, not just the `.control`
block — the descriptor's shape is wrong and the plan stops there. **Do not adjust the golden. Do not
add a compatibility arm.**

---

## Standing cautions this pass re-confirmed

* **`build-ver_50` is the binary every measurement in `evidence/` was taken against.**
  `/usr/bin/ngspice` (45.2) is for cross-checks — and it **has `pss`**, which makes Stage 14 and
  Stage 2's Detect leg testable with a second registry entry instead of a rebuild.
* **The xschem tree is dirty and moving.** Every anchor in these documents is a proc, variable or
  section name; a line number is a parenthesised hint and must be re-derived before it is quoted. The
  ngspice tree is clean at `ccebdf2a2`, so `file:line` there is stable — but four such citations were
  checked this pass and one had drifted.
* **A simulation run is a write to `~/.xschem/simulations`** when `rundir` is empty. No crew runs a
  simulation on a bench under `sky130A/`.
* **`LEDGER.md`'s `calls` column is call sites, not run rows**, and may not be quoted as a floor. The
  first crew to touch a suite replaces its figure with a measured before/after pair, per arm.
