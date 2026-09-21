# E-impl — item E (issue 1487): the T1 verdict now says what did NOT run

**Crew** E implementer. **Date** 2026-09-20. **Tree** `fluid-editing` at `9fcf9177`.
Measurements in a clone of that commit at `/var/tmp/xsr_e/E/x` (`./configure` + `make`
from scratch, both rc 0); the sabotage sweep in a copy of that clone at
`/var/tmp/xsr_e/E/y`; the developer-condition gate in the main working tree, whose
`src/xschem` `make -C src` reported *"Nothing to be done"* — i.e. already current with its
sources. **Nothing committed.**

| file changed (main working tree) | what changed |
|---|---|
| `tests/run_regression.tcl` | `summarize_all` carries a case's `skip:` lines and its last `RESULT:` line, **uncounted**; new `t1_skips` running total; `skips=` in `T1-RUN-END`; the stdout `VERDICT:` echo names skips and adds a `NOTE:` when there are any |
| `tests/headless/test_regression_concurrency_1476.tcl` | new **section V5**, 7 rows (`V5z`, `V5a`–`V5f`); suite **37 → 44 checks** |
| `CLAUDE.md` | an "uncounted lines" bullet, `skips=` in the documented trailer, and the `wc -l` arithmetic |

⚠ **Another crew is live in the same tree.** By the end of this item `git status` also
showed `src/actions.c`, `src/save.c`, `src/xschem.h`, `tests/headless/full_audit.sh`,
`tests/headless/run_suites.sh`, `tests/headless/gated_xschem.sh` and two new files
(`tests/headless/suite_cwd.sh`, `tests/headless/test_untitled_autosave_1486.tcl`) modified
— item F's (issue 1486). I touched none of them, and because `run_suites.sh` is mid-edit I
ran suites with the bare `./src/xschem --nogui --pipe -q --nolog --script …` spelling
rather than through it. My three files are byte-for-byte mine
(`tests/run_regression.tcl` `97352a4ea77d0b7148416534541d3251`,
`test_regression_concurrency_1476.tcl` `dfbc86c4572ca3e88a1183c8fe00cc7c`, re-checked after
the gate). See the caveat in §4 about F's rebuild during my gate.

---

## 1. The defect, measured on `9fcf9177`

### 1.1 Isolated: the same case log through both drivers

`summarize_all` was lifted out of each driver by text (`/var/tmp/xsr_e/E/unit_demo.tcl`,
`info complete` on `proc summarize_all …`) and run in a fresh `interp` over ONE synthetic
case log holding `ok:` lines, two `skip:` lines and `RESULT: ALL PASS (70 checks)`:

```
---- BEFORE  (t1_skips=0)            <- the driver at 9fcf9177
synth.log
Total num fail: 0
---- AFTER   (t1_skips=2)
synth.log
skip: A2 the fork leg -- no executable at '/nowhere/ngspice', so this leg did not run
skip: A4 needs a display
RESULT: ALL PASS (70 checks)
Total num fail: 0
```

**The BEFORE block is two lines and is byte-identical to the block of a case that skipped
nothing.** That is the whole defect, with no T1 and no xschem in the way.

### 1.2 A full T1 at `9fcf9177`, in the clone

`cd tests && tclsh run_regression.tcl`, rc 0, trailer:

```
T1-RUN-END pid=1261580 cases=87 blocks=86 counted_failures=4 elapsed=565s end=2026-09-20 21:30:09
```

| measured on `tests/results.1261580.log` | value |
|---|---|
| `^skip:` lines in the verdict | **0** |
| `^RESULT:` lines in the verdict | **0** |
| `^skip:` lines in that same run's case logs | **5**, all in `tests/headless/test_op_annot.log` |
| `wc -l` | 181 |

The five rows the run could not measure and did not report — `M1/M2`, `O14/O36/O38`,
`W23`, `W29`, `V53` of `test_op_annot` — plus its `RESULT: ALL PASS (485 checks)`, were in
the case log and nowhere in the verdict. This reproduces the issue's stage-F measurement
(8 `skip:` lines in the case logs, 0 in the verdict) on this box; here it is 5 rather than
8 because this clone's throwaway HOME still resolves the fork ngspice through
`XSCHEM_TEST_REAL_HOME`, so `test_ase_converge_1459` and `test_ase_sp_1452` did not skip
their fork legs.

---

## 2. The fix

**`tests/run_regression.tcl`, `summarize_all`** — two new `elseif` arms, **after** the
counted arm and after the `NOGOLD|NODISPLAY` arm:

* `^skip:` → printed verbatim, `incr num_skip`, **never counted**;
* `^RESULT:` → held in `result_line` and printed once, immediately above
  `Total num fail:`, so every block has the same shape and the check count is always in
  the same place. The **last** one wins (defensive: no case log in the tree carries more
  than one today — measured, `/usr/bin/grep -c '^RESULT:'` over all 87 case logs of a run
  gives 0 or 1 — but a suite that printed a per-section summary first would otherwise
  leave a stale count in the verdict).

**Why the arms go last, and it is the safety property, not style.** The counted arm is
tested first, so **the four counted shapes gain and lose no member**. Measured in the
isolated harness with a `skip:` line whose reason ends in the word `FAIL`:

```
---- BEFORE  (t1_skips=0)            ---- AFTER  (t1_skips=1)
synth.log                            synth.log
skip: A4 ... ends in the word FAIL   skip: A2 the fork leg -- ...
Total num fail: 1                    skip: A4 ... ends in the word FAIL
                                     RESULT: ALL PASS (70 checks)
                                     Total num fail: 1
```

**1 before, 1 after, printed once in each.** Put the skip arm first and `skip: ` becomes a
universal escape hatch by which any suite hides a `FAIL`-shaped line — row `V5e`, and
sabotage **S3**, hold that.

**`T1-RUN-END` gains `skips=`**, between `counted_failures=` and `elapsed=`; `end=` stays
last, `T1-RUN-BEGIN` is untouched, and `canonical=` is still the header's last field
(row `V4b` still green). Neither sentinel can match a counted shape (`V4a` still green).
Stdout's `VERDICT:` line now reads *"N counted failure(s) and M skipped row(s) over 87
case(s)"*, and when M > 0 a `NOTE:` names the grep that lists them.

---

## 3. The same measurements, after

### 3.1 A full T1 in the clone, fix in place

```
T1-RUN-END pid=1420874 cases=87 blocks=86 counted_failures=4 skips=5 elapsed=578s end=2026-09-20 21:40:34
VERDICT: this run's answer is results.1420874.log (4 counted failure(s) and 5 skipped row(s) over 87 case(s))
NOTE: 5 row(s) announced that they did NOT run -- `/usr/bin/grep -n '^skip:' results.1420874.log` names them, ...
```

| | before (`1261580`) | after (`1420874`) |
|---|---|---|
| `cases=` / `blocks=` | 87 / 86 | 87 / 86 |
| `counted_failures=` | 4 | 4 |
| `skips=` | *(field did not exist)* | **5** |
| `^skip:` lines in the verdict | 0 | **5** |
| `^RESULT:` lines in the verdict | 0 | **73** |
| `wc -l` | 181 | **259** |

The `test_op_annot` block, which was two lines, is now:

```
headless/test_op_annot.log
skip: M1/M2 need a display — actions.c:4422's text loop is inside `if(has_x && selected != 2)`
skip: O14/O36/O38 need a display — draw()'s whole body is inside `if(has_x)` (draw.c:10377), and `new_schematic create_window` is a Tk call
skip: W23 the walk adds no descend/go_back/netlist lines, and pops its suppress scope  (no action log -- run with --logdir)
skip: W29 the Graphs-cascade menu item and its three outcomes  (needs a display -- the cascade is built under `if {[info exists has_x]}`)
skip: V53 needs a display - winfo does not exist under --nogui, so the Tk liveness probe in cadence::_annot_viewer_db, which is the thing under test, is never reached
RESULT: ALL PASS (485 checks)
Total num fail: 0
```

A **failing** case now states its size too, which it never did:
`headless/test_ase_optier_0963.log` … `RESULT: 1 FAILED (108 passed)` … `Total num fail: 2`.

The verdict is still valid UTF-8 (`iconv -f UTF-8 -t UTF-8`, rc 0); the em dashes in
`test_op_annot`'s skip text round-trip as `342 200 224` (U+2014).

### 3.2 `wc -l` moved, and to what

**Clone, 4 counted failures: 181 → 259.** The delta is exactly `5 skips + 73 RESULT
lines = 78`. The arithmetic, which now has two more terms:

```
   2  sentinel lines (T1-RUN-BEGIN, T1-RUN-END)
+ 86  block header lines
+ 86  "Total num fail:" lines
+  4  counted failure lines
+  3  NOGOLD notes
+  5  skip: lines            <- new (issue 1487)
+ 73  RESULT: lines          <- new (issue 1487)
= 259
```

**Main tree, green: `wc -l` 255** — `2 + 86 + 86 + 0 counted + 3 NOGOLD + 5 skip + 73
RESULT`, read off `tests/results.1620712.log`, not computed. CLAUDE.md's figure is updated
from that artefact. ⚠ The two new terms are **environment-dependent** — a home without the
fork ngspice adds three more `skip:` lines — so `wc -l` is even less of a constant to check
against than it was, and the trailer states what matters.

---

## 4. No regression in the developer's condition

* **Clone, before vs after: the identical 4 counted failures**, same two cases, same row
  text, byte for byte —
  `test_ase_optier_0963` row `Z6` (`-> {c c c c {}} (exp {d d c c {}})`) plus its HARNESS
  line, and `test_ase_variant_1470` row `OT1` (`-> … {c dumppath} … (exp … {d dump} …)`)
  plus its HARNESS line. **Both are present on the unfixed driver**, so neither is mine.
  They are this clone's environment, not the branch's: `test_ase_optier_0963` is the flake
  CLAUDE.md already names, and `OT1`'s `v_tier $D_FORK` expects `{d dump}` and gets
  `{c dumppath}`, i.e. a fork-ngspice-path-dependent answer. **Not investigated further —
  out of scope (criterion 4), and filed below.**
* **Main tree, `DISPLAY` set, solo — T1 stays at ZERO.** `cd tests && tclsh
  run_regression.tcl`, rc 0, `tests/results.1620712.log`:

  ```
  T1-RUN-BEGIN pid=1620712 … planned_cases=87 home=throwaway binary=/home/analog/dev/xschem-claude/src/xschem canonical=results.log
  T1-RUN-END   pid=1620712 cases=87 blocks=86 counted_failures=0 skips=5 elapsed=569s
  ```

  **87 `Start` / 87 `Finish`**, **zero** `another regression run is live` lines (positive
  evidence it ran solo), `display arm: attached to the dev display`, `wc -l` **255**, and
  stdout's two new lines:

  ```
  VERDICT: … (0 counted failure(s) and 5 skipped row(s) over 87 case(s)); published as results.log
  NOTE: 5 row(s) announced that they did NOT run -- `/usr/bin/grep -n '^skip:' results.1620712.log` names them, …
  ```

  ⚠ **Caveat, stated because a green gate deserves one.** Item F's crew was editing the
  same tree during this run: `src/xschem.h` changed at **21:42:00** and `src/xschem` was
  **rebuilt at 21:50:02**, inside the gate's window (21:40:38 → 21:50:07). `make -C src`
  had reported *"Nothing to be done"* before I started, so the run began on HEAD's binary;
  whether its last case or two ran on F's is not knowable from the mtimes. All 87 cases
  passed regardless, and a binary swap can only manufacture failures, not mask them — but
  the **controlled** before/after is the clone pair above, not this gate, and the driver
  should read its own gate before committing.
* **`test_regression_concurrency_1476` — `RESULT: ALL PASS (44 checks)`** in the main tree,
  in clone `x` (as a T1 case, twice) and in clone `y` (as the sabotage baseline). It was
  37 before section V5. `V1a`–`V4b`, `S`, `R`, `D`, `C` rows all stayed green in **every**
  one of the 9 sabotage runs, so nothing in this change disturbs the existing rows.
* **`test_home_isolation`** (rows `H1e`, `H8` read the verdict and the trailer, including
  `{ counted_failures=1 }` with its trailing space) and **`test_home_isolation_sh`** were
  green in the clone's after-run. Inserting `skips=` between `counted_failures=` and
  `elapsed=` leaves that regexp matching.

---

## 5. Sabotages — every new row proved able to fail

Nine exact-string sabotages, each applied to a pristine `.orig` copy so none stacks on
another (`/var/tmp/xsr_e/E/sabotage_all.py`, run in clone `y`; full log
`/var/tmp/xsr_e/E/sabotage.out`). Baseline first: `RESULT: ALL PASS (44 checks)`, all seven
new rows green.

| sabotage | what it does | rows it reddened |
|---|---|---|
| **S1** skip arm removed (`^skip:` → `0`) | the pre-fix driver, for skips | `V5a`, `V5c` |
| **S2** RESULT arm removed (`^RESULT:` → `0`) | the pre-fix driver, for the check count | `V5d` |
| **S3** skip arm tested **before** the counted arm | the escape hatch: a `skip:` prefix hides a `FAIL`-shaped line (counted 1 instead of 2) | `V5c`, `V5e` |
| **S4** `skips=` dropped from the trailer | the trailer stops stating coverage | `V5c` |
| **S5** the **first** `RESULT:` line kept, not the last | a stale per-section count reaches the verdict | `V5d` |
| **S6** skips buffered and printed under the **next** case's block | the rows are in the verdict but under the wrong case | `V5a`, `V5c` |
| **S7** `incr ::t1_blocks` per skip line | the trailer arithmetic breaks | `V5f` |
| **S8** `incr num_fail` per skip line | lost coverage manufactures a red | `V5b`, `V5e` |
| **S9** the fixture driver is never run (suite-side) | vacuity guard | all seven, `V5z` first |

Every row is covered by at least one product-side sabotage except `V5z`, which is the
vacuity guard and is covered by S9. **No pre-existing row of the suite reddened in any of
the nine runs** — the script reports "pre-existing rows also red" and never printed it.

---

## 6. What I did NOT fix, and why

* **A `skip:` line whose reason ends in the word `FAIL` is still counted as a failure.**
  Measured identical before and after (§2). Fixing it would mean testing the skip arm
  first, which is the escape hatch S3 demonstrates, or rewriting a suite's own text, which
  a verdict writer should not do. It is a corner no suite in the tree hits (`/usr/bin/grep`
  over every `skip:` line emitted in a full run: none matches a counted shape) and it is
  now pinned by `V5e` and documented in CLAUDE.md so nobody "fixes" it into a hole.
* **`full_audit.sh` still drops per-row `skip:` lines.** It has its own whole-suite skip
  concept (`is_skip`, `RESULT: SKIP`) and its own ERE readers, and its `SUMMARY:` line says
  nothing about rows that did not run. That is the same class as 1487 in a different
  reader, and it is **not** issue 1487 — criterion 4. See §7.
* **The display arm's can't-run path** (`NODISPLAY:` / `HARNESS: … display arm NOT RUN`)
  writes its block by hand and does not go through `summarize_all`; it has no skips to
  carry, and I left it alone. Its `incr t1_blocks` is present, so `blocks=` stays right —
  checked, not assumed.
* **No suite was made to emit more skips.** 1487 is about the verdict, not about coverage
  itself. The 5 rows now visible were already being skipped honestly (D10).
* **`tests/headless/run_suites.sh`** already prints skip lines (D13.11) and needs nothing;
  it is also mid-edit by item F's crew.

---

## 7. Found outside the item (filed here, not fixed)

1. **`full_audit.sh` has the same blind spot** as 1487's `summarize_all`: a suite's
   per-row `skip:` lines never reach its `SUMMARY:` line, so a full audit cannot say what
   was not measured either. Worth its own issue.
2. **`test_ase_variant_1470` row `OT1` fails in a fresh clone of `9fcf9177`** that has no
   repo-root `.xschem/` and no other local state — `v_tier $D_FORK` answers
   `{c dumppath}` where the row expects `{d dump}`. Reproduced on the unfixed driver, so
   it predates this change. It is the stranger-reds class this batch exists for (a fresh
   checkout reds), and it is not 1483/1484/1485/1486/1487.
3. **`test_ase_optier_0963` row `Z6` also failed in that clone**, in both runs. CLAUDE.md
   records `test_ase_optier_0963` as an undiagnosed flake; here it reproduced twice in a
   row in the same clone, which is a stronger signal than "flake" and points the same way
   as (2) — a fresh clone lacking local state.
4. **`open_close`'s NOGOLD line reports a different result-file count between two runs of
   the same tree** (1898 before, 1894 after, and 1488 vs 1456 for `netlisting`). Nothing
   to do with this change — the counts differ on the unfixed driver too — but it means a
   green verdict is not byte-deterministic even setting the sentinels aside, which is a
   thing CLAUDE.md's "byte-deterministic" history would not lead you to expect.

---

## 8. Scratch

`/var/tmp/xsr_e/E/` — my own subtree of the assigned root, never `/var/tmp/xsr_e` itself.
**Peak 1.1 GB** (`du -sh`: `x` 498 MB — clone, configured and built — plus `y` 563 MB,
the sabotage copy, plus ~1 MB of logs; `du -sb` on the subtree: 958 511 463 bytes).
Deleted at the end of the item (`rm -rf /var/tmp/xsr_e/E`); `/var/tmp/xsr_e` itself left in
place for the other crews. ⚠ A sibling `/var/tmp/xsr_e/**e**` (lowercase, created 21:26) is
**not mine** and was left untouched — the case-insensitive near-miss is worth knowing about
in a root several crews share, and it is exactly why the brief says delete `<root>/<label>/`
and never the root.

---

## 9. FIX ROUND (2026-09-20, E fixer) — what changed after this receipt was written

The item E verifier raised three "should"s and one registration task; all four were
addressed. **Full record: `receipts/E-verify.md`.** In brief, and with the numbers in this
receipt that are now superseded:

| verifier item | outcome |
|---|---|
| carried lines are copied verbatim, so a suite can forge a sentinel | **APPLIED.** New `t1_carry_line` rewrites `T1-RUN-` → `T1_RUN_` on **all four** carry sites (the counted arm included — it is the one that can forge a trailer at COLUMN 0). New row **V5g**. |
| the `RESULT:` arm drops two suites' check counts and its comment denies it | **APPLIED.** A completion banner with a parenthesised trailer is the fallback when no `RESULT:` line was seen, using `banner_rule.tcl`'s own predicate. Adds exactly 2 lines to a full verdict. New row **V5h**. |
| `^skip:` could wear the block-header shape | **REJECTED as put, hazard closed another way.** Zero emitters in the repo omit the space (measured), but `^skip:\s` could only fail by silently DROPPING a line — 1487's own defect — and would diverge from `run_suites.sh`. `t1_carry_line` normalises `^skip:(\S)` to `skip: \1` instead. |
| `test_untitled_autosave_1486` is not registered in T1 | **REGISTERED**, as the 73rd `hcases` entry — after adding the completion banner it lacked, without which `regression_case_failed` was measured **1** and T1 would have counted a HARNESS failure while all 13 checks passed. |

### Numbers in this receipt that the fix round moves

* **§3.2's `wc -l` figures.** The main tree's green verdict was **255**; with the
  banner-count fallback it is **257** on the 87-case tree, and **260** once the 1486 case
  is registered (88 cases / 87 blocks). Both re-measured by replaying the gate run's own 86
  case logs through each driver state — the replay reproduces 255 exactly, which is what
  makes 257 and 260 trustworthy. The arithmetic gains one term,
  `+ 2  OVERALL: ok (N checks)`.
* **§4's suite figure.** `test_regression_concurrency_1476` is **46 checks**, not 44;
  section V5 is nine rows (`V5z`, `V5a`–`V5h`) over six stand-in cases, not seven rows over
  three.
* **§2's claim that an absent `RESULT:` line means "the suite never stated a count"** was
  false for `headless/test_pdk_launcher` (30) and `headless/test_ihp_sg13g2_libmgr` (67),
  and the comment saying so has been replaced by the fallback plus the measurement.

### Numbers in this receipt that the fix round confirms

`counted_failures` is unchanged at every driver state — **0** at `9fcf9177`, **0** with
item E, **0** with the fix round, over the same 86 real case logs. `skips=5` on this box,
and the two sentinels remain exactly one each. Seven new sabotages (S10–S16) each reddened
exactly one of V5g/V5h and left the other 45 rows green, so nothing in §5's nine sabotages
is disturbed.
