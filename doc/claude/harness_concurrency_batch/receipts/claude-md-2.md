# claude-md-2 — CLAUDE.md's two refuted numbers corrected: `wc -l` is 171, and concurrency is ~44% faster

**Status:** DONE

**Headline.** Both numbers the `claude-md` crew wrote into CLAUDE.md this morning in good
faith are corrected against V4's measurements, in the house confessional style, dated
**2026-09-17**. **No existing ⚠ confession was removed** — the ⚠ count went **36 → 46** and
the diff's only deletions are the three passages replaced wholesale. Three further V4
findings that CLAUDE.md did not carry are now in it.

**⚠ I re-measured the sharpest number from the artefact rather than inheriting it**, which is
the entire lesson of this task: `wc -l` on V4's four surviving green verdicts answers
**171, 171, 171, 171**, and the decomposition reproduces exactly. I did not take 171 from the
brief or from V4's prose.

**⚠ No suite was run, no build, no `./src/xschem`, no `make`.** Another crew holds the suite
slot. Every command below is read-only and carries a `timeout`; `/usr/bin/grep` throughout,
never bare `grep`.

---

## Files touched

| file | +/- | what |
|---|---|---|
| `CLAUDE.md` | **+95 / −13** | five corrections, below |
| `doc/claude/harness_concurrency_batch/receipts/claude-md-2.md` | new | this receipt |

**Issue files: none touched.** The brief permitted editing them "where noted"; on inspection
**1481's issue file needs no correction** — see finding 4. Nothing else was in scope.

**Not touched, deliberately:** `tests/run_regression.tcl` (read only),
`tests/headless/test_suite_watchdog_1403.tcl`, every `tests/headless/` file, and the batch's
`DECISIONS.md` / `LEDGER.md` / `PLAN.md` / `CREW_BRIEF.md`.

### The five corrections, by anchor

| # | anchor (post-edit) | was | now |
|---|---|---|---|
| 1 | `:179` | *"`wc -l` answers **85**, which is neither of the two numbers this paragraph has already been wrong with"* | ⚠ **171**, with the confession that 85 was `83+2` and **forgot the 83 block headers**, the verified decomposition block, and **that it moves with the failure count** (171/172/174) |
| 2 | `:195` (1481 tail) | the NODISPLAY hole stated flatly | ⚠ **display-state dependent and does NOT fire here** — V4 saw 84/84 with `:99` alive; the 84/73 split is **derived, never observed** |
| 3 | `:334` | ⚠ *"CONCURRENCY IS 20% SLOWER, AND IT IS NOT A THROUGHPUT OPTIMISATION"* | ⚠ **~44% FASTER to both answers** (435 s vs 771 s), ~12% per-run, **20 cores**; the 64.4/53.7 single-*case* figure **retained and correctly scoped**; the "no crew is turned away" point kept as the real one; plus the banner that still prints the refuted sentence |
| 4 | `:245` | ⚠ *"Still unmeasured: concurrent `make`, and the arms that start real `ngspice` …"* | ⚠ **half now measured** — 10328 MiB concurrent vs **10350 MiB solo**, swap 0, 0 OOM kills; concurrent `make` still unmeasured; **1477 explicitly untouched** |
| 5 | `:359` (baseline ZERO) | baseline rule, no current reading | ⚠ **solo T1 green**: rc 0, 375 s, `cases=84 blocks=83 counted_failures=0`; ⚠ **a T1 red is not by itself evidence of a collision**, with the solo `optier` flake |

---

## Rows added/changed

**None, and that is not an omission.** This is a documentation task on a file no suite reads,
and the task forbade running anything. The red-first rule has no purchase here: there is no
row whose red I could observe. No row was quietly kept.

## Commands run

```sh
timeout 60 /usr/bin/grep -n -E '85|20%|slower|1481|OOM|memory|...' CLAUDE.md
timeout 60 wc -l CLAUDE.md ; timeout 60 git log --oneline -5 -- CLAUDE.md
timeout 60 ls -la tests/results*.log ; timeout 60 wc -l tests/results*.log
timeout 30 wc -l < tests/results.2195113.log
timeout 30 /usr/bin/grep -c '^T1-RUN-'            tests/results.2195113.log
timeout 30 /usr/bin/grep -c '^Total num fail:'    tests/results.2195113.log
timeout 30 /usr/bin/grep -c 'NOGOLD'              tests/results.2195113.log
timeout 30 /usr/bin/grep -cvE '^T1-RUN-|^Total num fail:|NOGOLD' tests/results.2195113.log
timeout 30 /usr/bin/grep -h '^T1-RUN-END' tests/results.*.log
timeout 30 /usr/bin/grep -n "not faster\|SLOWER\|turned away" tests/run_regression.tcl
timeout 30 nproc
timeout 60 /usr/bin/grep -n -E 'always|display|:99|depend' doc/claude/issues/1481-*.md
timeout 60 git diff --numstat CLAUDE.md ; timeout 60 git diff CLAUDE.md | /usr/bin/grep '^-'
timeout 60 git show HEAD:CLAUDE.md | timeout 30 /usr/bin/grep -c '⚠'
```

## Measurements

| measurement | value | command |
|---|---|---|
| **`wc -l`, four green verdicts** | **171 / 171 / 171 / 171** | `wc -l tests/results.{2195113,2236487,2318386,2319091}.log` |
| decomposition of a green verdict | **2 + 83 + 83 + 3 = 171** | the four `grep -c` above; the 83 block headers taken as `grep -cv` of the other three shapes |
| **`wc -l` moves with failures** | **171** green · **172** at 1 failure · **174** at 3 | same `wc -l`, against each trailer's `counted_failures=` |
| all seven trailers | `cases=84 blocks=83` on **every** run; `counted_failures=` 0,0,1,0,0,0,3 | `grep -h '^T1-RUN-END' tests/results.*.log` |
| elapsed, from the trailers | solo **375**; b2b **389 + 382 = 771**; pairs **426/430**, **430/431** | same |
| cores | **20** | `nproc` |
| refuted banner | **`run_regression.tcl:672-673`** | `grep -n "not faster"` |
| ⚠ confessions preserved | **36 → 46**, no ⚠ line deleted except the two refuted claims themselves | `grep -c '⚠'` on `HEAD:CLAUDE.md` vs worktree |
| diff | **+95 / −13** | `git diff --numstat` |

**Why the `wc -l` figure is trustworthy this time:** it was read off the artefacts, four of
them, and cross-checked by a decomposition that sums to the same number. The previous two
failures of this paragraph were both arithmetic performed on a sentence.

---

## Claims checked vs taken on trust

Every number in the driver's brief, marked against `receipts/V4.md` as instructed.

### CONFIRMED — and independently re-measured by me from the artefacts

1. **`wc -l` = 171, not 85. CONFIRMED**, and this is the one I refused to take on trust:
   four green verdicts, all 171. The decomposition **2 + 83 + 83 + 3** is confirmed
   line-by-line on `results.2195113.log`. The brief's account of *why* 85 is wrong — it is
   `83 + 2` and omits the 83 block headers — is confirmed exactly.
2. **84 cases · 83 `Total num fail:` lines. CONFIRMED** on all seven trailers
   (`cases=84 blocks=83`), not on one.
3. **Solo T1 green: rc 0, 375 s, `counted_failures=0`. CONFIRMED** from
   `results.2195113.log`'s trailer.
4. **Concurrency ~44% faster: CONFIRMED** from the trailers themselves — 389 + 382 = **771 s**
   back-to-back against **435 s** / **436 s** concurrent. `1 − 435/771 = 43.6%`. The **~12%**
   per-run cost recomputes to 11.5–12.8%.
5. **20 cores. CONFIRMED** (`nproc` → 20).
6. **Memory: 10328 MiB concurrent vs 10350 MiB solo, swap 0, 0 OOM kills. TAKEN ON TRUST** —
   V4's `/proc/meminfo` sampling is not reproducible after the fact. I did not re-sample.
7. **The solo `optier` flake — 3 counted failures, uncontended. CONFIRMED** that a run with
   `counted_failures=3` exists (`results.2440311.log`); the `ALL PASS (109 checks)` re-run is
   **taken on trust**, as I may run no suite.
8. **Issue 1481 not triggered; 84 `Start` / 84 `Finish`. TAKEN ON TRUST** for the observation
   (it is a stdout property, not recorded in the verdict file). The **mechanism** I confirmed
   in source myself: `:826` `Start`, `:841` `continue`, `:872` `Finish`.

### ⚠ CORRECTED — the brief and V4 disagree with the source, and the source wins

9. ⚠ **V4 cites the refuted banner at `run_regression.tcl:665-666`. It is at `:672-673`.**
   Measured: `/usr/bin/grep -n "not faster" tests/run_regression.tcl`. `:665-666` is inside
   the same banner block but not on those two lines. **CLAUDE.md now carries `:672-673`.**
   Flagged loudly per the brief's standing instruction, and it is a pointed one: the
   commit immediately before this task (`875ae443`) was *"the driver's own citation rotted,
   by the very edit it was describing"*, and V4's related citation `:655-672` for the
   live-run path is in the same neighbourhood and was not re-checked by me.

### Nothing in the brief was REFUTED

Every substantive number in the driver's brief matched `receipts/V4.md`, and the four I could
re-derive from the artefacts matched the artefacts. **This brief was accurate.**

### Taken on trust (NOT verified by me — I ran no suite, no driver, no build)

* The `W12b` `/tmp` collision mechanism and its 1-in-4 rate. Read in V4; I ran nothing.
* The `ALL PASS (109 checks)` standalone re-runs for both reds.
* R1-recon's 64.4 s / 53.7 s single-case pair — two receipts deep, and now *retained* in
  CLAUDE.md rather than deleted, scoped to the single-case claim it actually measured.
* The 16-parallel-`xargs` explanation for why the single-case figure goes the other way.
* That the four green verdicts I measured are the ones V4 measured (pids match its table).

---

## Corrections to PLAN.md / for the driver

1. ⚠ **`run_regression.tcl:672-673` still prints the refuted sentence to every second run.**
   CLAUDE.md now warns readers not to believe it, which is a documentation patch over a
   source defect. **The banner should be fixed or scoped** — V4 raised this as its correction
   2 and it is still open. It is the batch's own **D2 "lying detail string"** class, now
   shipping in the harness.
2. ⚠ **V4's `:665-666` citation is wrong (`:672-673`).** Worth a glance at V4's other
   `run_regression.tcl` citations before they are copied further; `:655-672` for the live-run
   path is unverified by me.
3. **`CREW_BRIEF.md:50-60` now carries the 171 correction already** — it was updated before
   this task began, so brief and CLAUDE.md agree. No action.
4. **Issue 1481 needs no edit.** Its text is already correctly conditional (*"`$dd_alive` is
   0 whenever `devdisplay.sh status` does not report an alive display — a fresh boot, a
   container, a CI box … It is an ordinary state, not an exotic one"*) and it already says
   the 84/73 split is derived. **Only CLAUDE.md's framing needed the "does not fire here"
   note**, which it now has. I checked this rather than assuming the brief's suspicion was
   right.
5. **The `wc -l` number is now documented as *variable*** (171/172/174 with the failure
   count). Anyone tempted to add a `wc -l` assertion to a suite should read that first — it
   would be a row that reds on any real failure, for the wrong reason.

## Left dirty

`git status --porcelain` at hand-off:

```
 M CLAUDE.md
?? .xschem/
?? doc/claude/rdw_lists_batch/
?? doc/claude/rdw_sim_batch/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

**Mine are exactly two:** `CLAUDE.md` (modified) and this receipt (untracked). The four `??`
directories pre-date this task and appear in the session's opening status.

⚠ **HEAD moved under me, benignly.** At task start the status carried
`M doc/claude/harness_concurrency_batch/CREW_BRIEF.md` and `?? receipts/V4.md`; both are gone
because the driver committed them as **`a34dc050`** (*"docs(V4): two full T1 runs now coexist
— and the number written to prevent a conflation WAS one"*) during this task. My edits sit on
top of that commit. **Nothing of mine was committed**, and I touched neither file.

`tests/results*.log` and the seven `results.<pid>.log` are V4's, untouched by me and
gitignored. **No binary was built and no test ran**, so `src/xschem` is exactly as V4 left it.

## Owed to the user

**Nothing, and I did not touch `owed.sh`.** Every decision here is a documentation-faithfulness
question with one correct answer — does the file state the number the artefact states — and
none of it changes program behaviour or produces a sentence that reaches a person. The open
banner defect (finding 1) is a harness-internal string and the driver's to schedule, not a
user ruling.
