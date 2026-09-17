# R1-build — both runs proceed, every verdict says whose it is and whether it finished

**Status:** DONE

**Headline.** The driver's own bookkeeping is now parallel-safe and every verdict is
self-identifying. `test_regression_concurrency_1476` goes **20 → 36 checks, ALL PASS**;
**16 of the 36 were observed RED on today's tree before the fix** and are quoted below.
The collateral readers of this driver's source are all still green:
`test_suite_watchdog_1403` **32/32**, `test_audit_classifier` **75/75** (K17), and
`test_op_annot` **485/485** (V57).

⚠ **Three things in the brief were wrong and one of its estimates was wrong by 4×.** The
brief's "~6 lines" for Part 1 is **26 code lines**; issue 1478's prescribed fix shape for
the same part **would have reopened the race it closed**; and the suite's section V
**cannot reach the golden-case path at all**, so the riskiest new mechanism in this build
was untestable by the rows the brief pointed at. All three are below.

---

## Files touched

| file | +/- | what |
|---|---|---|
| `tests/run_regression.tcl` | +305/−81 (732 → 956 lines) | per-run verdict + per-case logs, sentinels, `fconfigure`, counters, lock demoted to a publish mutex |
| `tests/test_utility.tcl` | +48/−2 (328 → 373) | `t1_log_tag` / `t1_run_file`; `print_results` writes the per-run name |
| `tests/headless/test_regression_concurrency_1476.tcl` | +274/−13 (491 → 752) | section P (7 rows), V1b rekeyed, V2a rekeyed, V1c–V1f, V3a–V3d, V4a |
| `.gitignore` | +17/−5 | per-run `_output.txt` siblings; lock comment retuned |
| `doc/claude/ledger/crew.js` | +13/−3 | "run it SOLO" → both runs proceed; read the trailer |
| `doc/claude/ledger/crew_annotate.js` | +4 | trailer/header reading rule |
| `doc/claude/ledger/crew_opfix.js` | +4 | same |
| `doc/claude/op_param_batch/item_pipeline.js` | +4 | same |

**Not touched, deliberately:** `CLAUDE.md` (another crew holds it — the list it needs is at
the end of this receipt), `DECISIONS.md`, `LEDGER.md`, `PLAN.md`, and the four suite files
the driver reserved.

---

## What was built

### Part 1 — per-run per-case logs (83 of the 88)

Every case log is now written under `<name>.<pid><suffix>` and **published back** to its
canonical name once that case's verdict is computed: `<tc>.log`, `<tc>_output.txt`,
`<hc>.log`, `<dc>.disp.log`, `stefan_xschemtest.log`. `t1_run_file` (in `test_utility.tcl`)
spells the rule once for both sides; `t1_publish` restores the canonical name with the same
contract as `publish_results` — it runs after the verdict, so a failure is a warning and
never a death.

⚠ **The tag travels in the environment, and that is not gold-plating.** `<tc>.log` is
written by `print_results` in the **case's own process** (`tclsh open_close.tcl`), so the
driver and the case cannot both call `[pid]` and get the same answer. The driver sets
`T1_LOG_TAG` to its own pid; both sides read it through the one proc. **An unset tag means
the old name**, so `cd tests && tclsh open_close.tcl` still writes `open_close.log` — the
by-hand path CLAUDE.md documents is unchanged.

### Part 2 — per-run verdict, canonical name, lock demoted

Each run fills `results.<pid>.log`; `results.log` is **copied** from it at the end and
tracks the most recent completed run. Nothing is refused, nothing waits, nothing is
truncated.

**Copy, not rename** — deliberately. A rename would hand the canonical name over and
**delete this run's own answer**, which is exactly the "lost cleanly" outcome
`DECISIONS.md:64-70` identified: the second finisher erases the first's verdict, tidily
instead of mid-write. Both answers now survive under their own names.

**What happened to `T1_LOG_LOCK_WAIT` / `T1_LOG_LOCK_TTL`** (the brief asked for this
explicitly):

* The lock is no longer held for the run. It brackets **one file copy** — so the canonical
  file can never be a mixture of two runs' bytes — and is otherwise armed only as the
  evidence-based stale-lock logic, which is kept because it is the only correct code in
  this tree for *"is that pid still the thing that took this"* (a bare `kill -0` answers
  yes for a recycled pid).
* `T1_LOG_LOCK_WAIT` **0 → 60**. Its old default was 0 *because nobody should wait 400 s by
  accident*; the only thing it can now wait for is a file copy, so a default of 0 would make
  the lock decorative.
* `T1_LOG_LOCK_TTL` **14400 → 300**. It had to outlast a whole run; now it only has to
  outlast a copy.
* New `T1_VERDICT_KEEP` (default 86400) sweeps dead runs' `results.<pid>.log`, on the
  `sweep_dead_run_dirs` contract — a pid with `/proc` present is never swept, so the failure
  direction is always "a leftover survives".
* The `t1_lock_waited` **preserve block is deleted**: it moved `results.log` aside before
  truncating it, and nothing truncates anything now. Left in place it would have moved the
  canonical file away from readers for no reason.
* **A live run is announced, never refused.** The per-run verdict *is* the liveness record —
  a `results.<pid>.log` whose pid is alive — so there is no registry and nothing to leak.

### Part 3 — the sentinels

`T1-RUN-BEGIN pid= script= start= planned_cases= verdict= canonical=` and
`T1-RUN-END pid= cases= blocks= counted_failures= elapsed= end=`, with
**`fconfigure $fd -buffering line`** immediately after the open.

⚠ **Three counters had to be built because none existed.** `summarize_all` returned nothing
and its `num_fail` was local. It now **accumulates into the globals itself**, which is why
only **two** inline sites needed touching (the NODISPLAY block and the xschemtest failure
arm) rather than the five R1-recon predicted — see REFUTED below.

---

## Rows added / changed — red before, green after

**RED baseline**, captured on the unmodified tree before any driver edit:
`RESULT: 16 FAILED (18 passed)`, rc 1.
**GREEN**, after: `RESULT: ALL PASS (36 checks)`, rc 0.

| row | red before | green after |
|---|---|---|
| `P1-tcases-output-is-written-under-a-per-run-name` | ``observed `if {[catch {eval exec $tccmd > ${tc}_output.txt} msg opt]} {` `` | ``observed `... > $tcout ...` `` |
| `P1-hcases-log-is-written-under-a-per-run-name` | ``observed `... > ${hc}.log 2>@1 ...` `` | ``observed `... > $hclog 2>@1 ...` `` |
| `P1-dcases-displog-is-written-under-a-per-run-name` | ``observed `... > ${dc}.disp.log 2>@1 ...` `` | ``observed `... > $dclog 2>@1 ...` `` |
| `P1d-print_results-writes-a-per-run-log` | `helper=0 bare-open=0` | `helper=1 bare-open=0` |
| `P1e-the-case-and-the-driver-agree-on-the-log-name-across-processes` | `TAGGED 0 / CANON 1 / AGREE 0 (t1_run_file -> NO-SUCH-PROC)` | `TAGGED 1 / CANON 0 / AGREE 1 (-> tagcase.4242.log)` |
| `P1f-an-untagged-run-still-writes-the-name-people-type` | `PLAIN 1` (green both sides — non-vacuity, see below) | `PLAIN 1` |
| `P2a-the-block-header-is-the-canonical-name-not-the-per-run-one` | ``summarize_all ${tc}.log $fd`` | ``summarize_all $tclog $fd ${tc}.log`` |
| `V1b-canonical-name-survives-AND-is-not-what-the-run-writes` | `results.[pid].log: ABSENT` | `results.[pid].log: found` |
| `V1c-the-verdict-channel-is-line-buffered` | detail was empty — **zero** `fconfigure` in the file | ``fconfigure $fd -buffering line`` |
| `V1d-the-verdict-carries-a-run-header` | absent | present |
| `V1e-the-verdict-carries-a-completion-trailer` | absent | present |
| `V1f-no-run-is-ever-refused` | `REFUSING-banner=1 bare-exit-2=1` | `REFUSING-banner=0 bare-exit-2=0` |
| `V2a-the-second-run-verdict-exists-in-its-own-right` | `B's own verdict file=NONE FOUND, b1 blocks=0, finished-trailer=0, B rc=2` | `file=results.2178333.log, b1 blocks=1, finished-trailer=1, B rc=0` |
| `V3a-both-runs-proceed-and-both-answers-survive` | `A=NONE (0/4 blocks), B=NONE (0/1)` | `A=results.2178325.log (4/4), B=results.2178333.log (1/1)` |
| `V3b-neither-run-was-refused` | `A rc=0 B rc=2, REFUSING banner A=0 B=1` | `A rc=0 B rc=0, REFUSING banner A=0 B=0` |
| `V3c-a-truncated-verdict-is-detectable-where-counting-is-blind` | `full: finished=n/a counted=n/a` (no per-run verdict existed at all) | `full: finished=1 counted=800; cut to its first line: finished=0 counted=0` |
| `V3d-each-verdict-says-whose-answer-it-is` | `A header pid=none, B header pid=none` | `A pid=2178325, B pid=2178333` |
| `V4a-the-sentinels-do-not-count-as-failures` | `0 sentinel line(s)` (vacuity guard fired) | `4 sentinel lines, 0 matching a counted shape` |

**`V3c` is the one to read.** After the fix it reports *a run carrying **800** counted
failures, truncated to its first line, scores **ZERO***. That is issue 1477 stated as a
measurement rather than a paragraph, and the trailer is the only thing that disagrees.

### Two rows that are honestly not red-first, and why they are kept

* **`P1f`** is green on both trees by construction — it asserts the *unchanged* behaviour
  (`T1_LOG_TAG` unset ⇒ `plaincase.log`). It is the **non-vacuity half of P1e**: without it,
  P1e could be satisfied by a change that broke the by-hand path CLAUDE.md documents. It is
  the same shape as the existing `R1b` and `C1a` guards in this suite.
* **`V1a`** (lock evidence) was green before and is required to stay green — it is what says
  out loud if anyone deletes the demoted lock rather than keeping it armed.

### `V3c`'s first draft was wrong, and it is recorded rather than quietly fixed

It originally asserted `counted(full) == counted(cut)` — "truncation does not change the
count". **Measured false the moment the fix landed:** 800 against 1. The property is not
that the count is *preserved* but that it can only go **down, toward "clean"**, so counting
can never raise the alarm. Stated as equality the row would have passed only on green
fixtures and lied about the mechanism.

### `V1c`'s detail string quoted a comment, not the code

`src_line $RR {fconfigure}` matched the ⚠ paragraph *above* the code and printed that. The
verdict was correct (the check uses the full expression); the **detail lied** — this batch's
own **D2 defect class**, reproduced inside the fix for it. The needle is now
`fconfigure[^\n]*-buffering`.

---

## Commands run

Every command carried a `timeout`. Never a bare `xschem`.

```sh
timeout 600 make -C src                       # RELINKED -- see "the binary was stale"
timeout 300 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_regression_concurrency_1476.tcl
timeout 300 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_suite_watchdog_1403.tcl
timeout 300 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_audit_classifier.tcl
timeout 400 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_annot.tcl
timeout  60 tclsh <probe> <git show HEAD:tests/test_utility.tcl> <dir>   # P1e/P1f red
timeout  60 tclsh <probe> tests/test_utility.tcl <dir>                   # P1e/P1f green
git check-ignore -v <five REAL per-run files>
```

**No T1 was run** (briefed not to; a separate verification crew owns it).
**Solo-ness confirmed before measuring:** `pgrep -af 'run_regression|open_close|create_save|netlisting'`
returned only my own shell's self-match; the six live `xschem`/`wish` processes are all from
**`/opt/xschem-repo`** (the user's `pdk_launcher`), a different tree.

---

## Measurements

| measurement | value | command |
|---|---|---|
| suite before | **16 FAILED / 18 passed**, rc 1 | the suite, pre-edit |
| suite after | **ALL PASS (36 checks)**, rc 0 | the suite, post-edit |
| watchdog 1403 | 32/32 before **and** after | `test_suite_watchdog_1403` |
| audit classifier | 75/75, K17 green | `test_audit_classifier` |
| op_annot V57 | 485/485, V57 green | `test_op_annot` |
| case lists | **3 / 69 / 11** (+1) = **84** | `sed -n '23p' / '27,93p' / '309,318p' \| grep -o '"[^"]*"' \| wc -l` |
| driver added lines | **297** total, **113 code** | `git diff -U0 \| grep '^+[^+]' \| grep -vcE '^\+[[:space:]]*#'` |
| test_utility added | **48** total, **15 code** | same |
| Part 1's own share | **26 code lines** | grep of the naming/publish/handshake lines in the diff |
| `results.log` untouched | 4785 B, mtime 1789642203 — unchanged | `stat -c '%n %s %Y'` |
| strays in `tests/` | **none** | `ls tests/results.*.log tests/*.[0-9]*.log …` |
| untitled litter | **none** (`ls`, not `git status` — issue 1480) | `ls untitled*.s* tests/untitled*.s*` |

---

## Claims checked vs taken on trust

### CONFIRMED

* **88 fixed-name files / 83 verdict inputs.** Re-derived from the artefact: 3 tcases ×2 +
  69 hcases + 11 dcases + `stefan_xschemtest.log` + `results.log` = **88**; the three log
  classes = **83**. Counts taken from `grep -o '"[^"]*"' | wc -l` on the three list ranges,
  not from a paragraph.
* **`:620` `<hc>.log`, `:571` `<tc>.log` delete, `:321-351` `summarize_all`** — all three
  read at HEAD before editing; all three exactly as described.
* **Zero `fconfigure`/`flush` in the driver.** Confirmed: V1c's red detail string came back
  **empty**, because there was no line to quote.
* **No shell script reads `results.log`.** `grep -rn "results\.log" --include=*.sh .` → **rc
  1, zero hits**. `run_suites.sh` and `full_audit.sh` are untouched by this change.
* **The reader list.** `crew.js:184-189,504`, `crew_annotate.js`, `crew_opfix.js`,
  `item_pipeline.js`, `.gitignore:96,118-123` — all present and all updated.
  `tests/hilight_xwin_sync.tcl:32` has an unrelated `results.log` of its own under
  `tests/hilight_xwin_sync/`; correctly left alone.
* **The 1476 suite really does copy `run_regression.tcl` and run two copies of it**
  (`mkdrv` → `drvA.tcl`/`drvB.tcl`). Checked before and after, as the brief required: `V0a`
  (`injection A=1 B=1`) is green on both trees, so the copies were built and driven in both
  the red and the green measurement.
* **`.gitignore` coverage, on REAL files** (V2's lesson): all five per-run shapes matched —
  `tests/create_save.99999_output.txt` → `:136`, the four `.log` shapes → `:94`/`:95` — and
  `git status --porcelain` showed none of them while they existed.

### CORRECTED

1. ⚠ **"~6 lines" for Part 1 is wrong: it is 26 code lines.** The estimate costed only the
   redirection targets. It missed three things that are not optional: the **cross-process
   `T1_LOG_TAG` handshake** (`<tc>.log` is written by the case, not the driver), the
   **publish-back** at each site, and the **`summarize_all` label argument** that 1478 §3
   requires. Still small — but 4× the number in the brief, and the brief's number would have
   bought a fix that renamed files and broke the verdict's contents.
2. ⚠ **Issue 1478 §3's prescribed fix shape would have REOPENED THE RACE.** It proposes
   publishing each log back to its canonical name **before** `summarize_all`, to keep the pid
   out of the block header. That fixes the header and puts the collision straight back:
   between the rename and the read, the other run can publish its own file onto that name and
   be scored instead. The shape that closes both is to **separate the two jobs** — read the
   private name, print the public one — which is one extra argument. **This is the fifth
   issue file in this batch whose prescribed fix would have shipped a no-op or a
   regression**, after 0867, 0990, 0805 and 0609.
3. ⚠ **The brief's own rows could not reach the riskiest mechanism.** Section V neuters the
   case lists (`set tcases {}`), so the golden-case path — the only place a **cross-process**
   name agreement happens — is never walked there. Had the handshake been wrong, every T1
   would have counted three synthesized `case produced no log (never ran?): FAIL` lines in
   the suite whose baseline is ZERO, and no row in the brief's plan would have caught it.
   `P1e`/`P1f` were added for exactly this and were observed red against
   `git show HEAD:tests/test_utility.tcl`.
4. ⚠ **The binary was STALE when I started.** `timeout 600 make -C src` **relinked** —
   R1-recon had recorded "Nothing to be done for 'all'" hours earlier, so something moved
   under the objects in between. Every measurement in this receipt was taken after that
   rebuild. This is CLAUDE.md's own "rebuild before any audit that is meant to be evidence"
   rule paying out inside a single batch.

### REFUTED

5. ⚠ **"Five call sites would have to accumulate" (R1-recon, Part C).** Only **two** did.
   Making `summarize_all` increment the globals itself covers `:587`, `:633` and `:704` in
   one place; the two arms that write their own block (NODISPLAY, xschemtest) are the only
   hand-counted sites. The counter that cannot drift is the one nobody has to remember.

### Taken on trust (NOT verified by me)

* R1-recon's measured `<hc>.log` collision (two real failures counted as 0, and the phantom
  red). I re-read the mechanism in the code and fixed it; I did not re-run that collision.
* The pre-fix phantom counts (407/432/757) and the 64.4 s / 53.7 s throughput figures, which
  I quote in comments and row text.
* That `T1` is at zero today. **I ran no T1.**
* `tests/results/.actionlogs` — the shared display-arm `--logdir` (issue 1478's fourth path).
  **Deliberately out of scope**, untouched and still shared.

---

## Corrections to PLAN.md / DECISIONS.md — and one new finding

* **A new one, not in any issue file:** the dcases **NODISPLAY** path `continue`s *before*
  printing its `Finish` line, so on a box with no dev display a run prints **84 `Start` and
  73 `Finish`** lines. CLAUDE.md's "count `Start`/`Finish` pairs for cases" rule silently
  under-counts by 11 there — and a reader who counted `Finish` would conclude eleven cases
  vanished. The new trailer makes this moot by **stating** `cases=` and `blocks=`, but the
  asymmetry is still in the code and nothing else records it.
* **`DECISIONS.md:129` stays refuted**, and this build is the closure: the lock protected 1
  of 88; 83 are now structurally per-run and the 84th (`results.log`) is published rather
  than shared.
* **`CREW_BRIEF.md:29-30`'s "confirm its mtime moved" is now obsolete** — it was correct
  until this commit. The trailer supersedes it, and R1-recon predicted exactly this.

---

## ⚠ For the driver — CLAUDE.md (I did not touch it; another crew holds the file)

Seven changes, in the order they appear:

1. **`:91-107` "Reading `results.log`"** — the first instruction must become **read the
   trailer**: a verdict with no `T1-RUN-END` line *did not finish*, whatever its contents.
2. **`:108-119` the fossil bullet** — "only its mtime ever said otherwise" is **no longer
   true**: `T1-RUN-BEGIN` names the pid and start time, so a fossil is self-identifying from
   content. Keep the history; change the instruction.
3. **`:118` the arithmetic block** — the verdict now carries **two sentinel lines** in
   addition to its 83 `Total num fail:` lines, and the trailer states `cases=` / `blocks=` /
   `counted_failures=` itself. Also worth adding the **NODISPLAY `Start`/`Finish` asymmetry**
   above.
4. **`:140-160` the 1477 bullet** — "every prefix of a green run is itself a green run"
   remains true of *counting*, and is now **detectable**: no trailer ⇒ did not finish. The
   channel is line-buffered, so a killed run leaves a genuine prefix rather than 0 bytes.
5. **`:186-196` "CHECK MTIME, NOT THE MD5"** — still correct, now secondary to the trailer.
   Note that a green verdict is **no longer byte-deterministic**: the sentinels carry a pid,
   a timestamp and an elapsed time.
6. **`:197-215` the SOLO bullet — the biggest change.** "A second run is refused loudly …
   exits 2 and writes nothing" is **obsolete**. Both runs proceed; nobody waits; nobody is
   refused; **`rc 2` no longer means "nothing ran"**. `T1_LOG_LOCK_WAIT` is now the *publish*
   wait (default **60**, was 0), `T1_LOG_LOCK_TTL` is **300** (was 14400), and
   `T1_VERDICT_KEEP` (86400) is new. ⚠ **And it must say that concurrency is 20% SLOWER to
   both answers than back-to-back** — what it buys is that no crew is turned away.
7. **`:65`/`:59`** — a crew should be told its own answer is `tests/results.<pid>.log`
   whenever another run may have been live.

---

## Left dirty

Eight modified files, no new untracked ones. `git status --porcelain`:

```
 M .gitignore
 M doc/claude/ledger/crew.js
 M doc/claude/ledger/crew_annotate.js
 M doc/claude/ledger/crew_opfix.js
 M doc/claude/op_param_batch/item_pipeline.js
 M tests/headless/test_regression_concurrency_1476.tcl
 M tests/run_regression.tcl
 M tests/test_utility.tcl
?? .xschem/
?? doc/claude/rdw_lists_batch/
?? doc/claude/rdw_sim_batch/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

The four untracked entries pre-date this task (they are in the session's opening status).
This receipt is the only file I created. **Nothing committed.**

`tests/results.log` is **byte-for-byte G1's** (4785 B, mtime 1789642203) — I never ran the
driver in `tests/`. No `results.<pid>.log`, no `.lock`, no per-run `_output.txt`, no
untitled litter (checked with `ls`, not `git status`).

⚠ **The binary was rebuilt** (`make -C src` relinked at the start). The tree's `src/xschem`
is newer than it was when this task began.

## Owed to the user

**Nothing, and I did not touch `owed.sh`.** Every decision here is internal harness
engineering of exactly the kind `DECISIONS.md:103-124` records as the driver's — the user's
input was *"make it fault-tolerant and find a way for both runs to proceed"*, and that is
what was built. The knob retunings (`T1_LOG_LOCK_WAIT` 0→60, `T1_LOG_LOCK_TTL`
14400→300, new `T1_VERDICT_KEEP`) are recorded above for the driver, not for the user: no
sentence any of them produces reaches a person outside this harness.
