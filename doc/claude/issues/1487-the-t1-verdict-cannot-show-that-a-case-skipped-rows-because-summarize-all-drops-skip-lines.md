# 1487 — the T1 verdict cannot show that a case skipped rows, because `summarize_all` drops `skip:` lines

**STAMP:** `v1 claim=fixed tree=c84aee78 stamped=2026-09-20 fix=taken open=0 by=stranger-reds`

**Status: FIXED in `c84aee78`, 2026-09-20**, by the stranger-reds batch, item E — read
**Resolution** at the foot. The same blind spot in `full_audit.sh` is **not** fixed and is
filed as **1497**. **Filed 2026-09-18** by the outsider-fixes batch, stage F (docs crew), from
`doc/claude/outsider_fixes_batch/DECISIONS.md` D12, and from the S2c completeness critic's
problems 4 and 5 (`receipts/S2c_refute_r1.md`). **Class** harness / verification method:
lost coverage that reads as a pass. **Related:** **0147** (NOGOLD, the precedent for a
printed-but-uncounted line), **0891** (NODISPLAY, the same precedent reapplied), **1485**
(nine suites whose honest fix is more skips).

---

## The defect

`summarize_all` in `tests/run_regression.tcl` copies exactly two kinds of line from a case
log into the verdict (READ at `7a46275f`):

* the counted shapes `FAIL$`, `GOLD?$`, `RESULT?$` and `^FATAL`;
* the uncounted notes `^(NOGOLD|NODISPLAY)`.

A suite's `skip:` lines, which name a row it could not run and why, are **not** carried.
Neither is its `RESULT: ALL PASS (N checks)` line, which states N. So a case that skipped
six rows and one that skipped none leave identical blocks: the log name, then `Total num
fail: 0`.

## Measured on the gate that proved the batch

The stage-F gate at `7a46275f` was `T1-RUN-END cases=87 blocks=86 counted_failures=0`.
Its HOME was a copy of the real `~/.xschem`, `.gitconfig` and `.ngspice_history`, and it
did **not** include the fork ngspice under `~/dev/ngspice`. Read from its own case logs
(mtimes inside the run, 19:12:52–19:21:29), MEASURED:

| case log | `skip:` lines | its `RESULT:` | with the fork present |
|---|---|---|---|
| `headless/test_ase_converge_1459.log` | 1: `skip: EE/fork -- no executable at '…/gate_f/home/dev/ngspice/build-ver_50/src/ngspice', so this leg did not run` | `ALL PASS (70 checks)` | 76 (D17; the S2c regression refuter, 70 unset and 76 set) |
| `headless/test_ase_sp_1452.log` | 2: `SE/fork`, `SE3/fork` | `ALL PASS (58 checks)` | 61 (D17) |
| `headless/test_op_annot.log` | 5: `M1/M2`, `O14/O36/O38`, `W23`, `W29`, `V53` (need a display or an action log on the headless arm) | `ALL PASS (485 checks)` | these rows run on the display arm |

**8 `skip:` lines in the case logs, 0 in the verdict** (`/usr/bin/grep -c 'skip:'
tests/results.1176485.log` → `0`). The verdict reads as a clean sweep of 87 cases, while
the fork-ngspice legs ran nine checks fewer than D17 recorded: (76 − 70) + (61 − 58),
the gate's counts set against the round-2 refuters'. The skips are **correct**: D10 made
those rows skip by name instead of passing silently. **Only the verdict hides them.**

This is exactly the risk the S2c critic named (problem 4): whether any suite runs fewer
checks under the throwaway HOME than under a real one cannot be read from a T1 verdict.
The crews answered it only by diffing per-case `RESULT` lines by hand.

## What already shows them

`run_suites.sh` does, since D13.11: it prints each `skip:` line a suite emitted, indented
under its verdict line. The R3 prover measured `| skip: W23 … (no action log -- run with
--logdir)` under `test_op_annot`. So the armed single-suite command shows skips and the
regression run does not.

## Fix direction

1. Carry `^skip:` lines into the verdict **uncounted**, next to `NOGOLD|NODISPLAY`, and
   the case's last `RESULT:` line with its check count. Then a per-case comparison between
   two verdicts is a `diff`, not an excavation.
2. Optionally add a `skips=` field to `T1-RUN-END`, as `cases=`, `blocks=` and
   `counted_failures=` already are.
3. ⚠ **Both change `wc -l`.** CLAUDE.md's green figure (177 at `7a46275f`) and
   `test_regression_concurrency_1476`'s V rows would move, so update them in the same
   change, from a measured run. ⚠ **A carried line must not be able to score.** A `skip:`
   reason that happens to end in `FAIL` would match `FAIL$`. Test the new branch after
   the counted one, as `NOGOLD` is, or anchor it.

## Evidence

`tests/results.1176485.log` and the case logs named above (the stage-F gate);
`doc/claude/outsider_fixes_batch/receipts/S2c_refute_r1.md` (critic problems 4 and 5;
regression refuter point 10); `DECISIONS.md` D10, D13.11, D17.

---

## Resolution — landed in `c84aee78`, 2026-09-20 (stranger-reds batch, item E)

Receipts: `doc/claude/stranger_reds_batch/receipts/E-impl.md` (the land) and `E-verify.md`
(the one fix round). Batch decisions: that batch's `DECISIONS.md` **D11** and **D12**.
Files: `tests/run_regression.tcl`, `tests/headless/test_regression_concurrency_1476.tcl`,
`CLAUDE.md`, and the completion banner the registration below required in
`tests/headless/test_untitled_autosave_1486.tcl`.

### What was done

* **`summarize_all` carries two more kinds of line, both uncounted**: every `^skip:` line a
  case emitted, verbatim, and its **last** `^RESULT:` line, printed immediately above
  `Total num fail:` so every block has the same shape and the check count is always in the
  same place. Where a case states its size only in a completion banner, that banner's
  parenthesised count is carried **instead**, and only when no `RESULT:` line was seen.
* **`T1-RUN-END` gains `skips=`**, between `counted_failures=` and `elapsed=`. `end=` stays
  last, `T1-RUN-BEGIN` is untouched and `canonical=` is still the header's last field.
  Stdout's `VERDICT:` line names both numbers and a `NOTE:` names the grep that lists the
  skips. So `counted_failures=` is the claim about correctness and `skips=` is the claim
  about coverage, and a reader needs both.
* **`headless/test_untitled_autosave_1486` was registered as the 73rd `hcases` entry** —
  item F's guard, which was otherwise green but ungated.

### ⚠ A skip can never manufacture a red, and that is a property of where the arm sits

Both new arms go **after** the counted arm, so the four counted shapes gain and lose no
member. MEASURED in an isolated harness (`summarize_all` lifted out of the driver by text
and run in a fresh `interp` over synthetic case logs, no T1 and no xschem in the way): a
`skip:` line whose reason ends in the word `FAIL` scores **1 counted failure before and 1
after**, printed once in each. Driven over hostile corpora with 0, 1, 12 and 200 skips and
forged sentinels, `counted_failures` is identical before and after. Put the skip arm first
and `skip: ` becomes a universal escape hatch by which any suite hides a `FAIL`-shaped line:
row **`V5e`** and sabotage **S3** hold that, and **S8** (`incr num_fail` per skip line) holds
the other direction, where lost coverage manufactures a red.

### ⚠ Carried text is sanitised at ALL FOUR carry sites, and the counted arm is the dangerous one

The project already defends the invariant that only the real trailer may carry `T1-RUN-END`
(`t1_hdr_word`, D13.17 of the outsider-fixes batch). The two new arms copied a suite's own
text into the verdict verbatim, so the review asked for those two to be sanitised. The fix
round found the one the review had not named: **a `skip:` or `RESULT:` line can only forge
mid-line — it starts with its own prefix — while the COUNTED arm has carried lines verbatim
since long before this issue, and carries them at column 0.** A case-log line reading
`T1-RUN-END pid=1 cases=999 … -- forged: FAIL` is taken by the counted arm and printed at
column 0, which is a perfect trailer that even an anchored `^T1-RUN-END ` reader accepts.

New `t1_carry_line` therefore runs on **all four** sites (counted, `NOGOLD|NODISPLAY`,
`skip:`, and the held `RESULT:`/banner line). It rewrites exactly two structural shapes and
nothing else: the sentinel word `T1-RUN-` → `T1_RUN_`, and `^skip:(\S)` → `skip: \1`.
MEASURED on a fixture verdict, before → after:

| | before | after |
|---|---|---|
| lines containing `T1-RUN-END` | **3** | **1** |
| lines matching `^T1-RUN-END ` (the anchored readers' shape) | **2** | **1** |
| lines wearing the block-header shape `^\S+\.log$` | **5** (4 real + a phantom) | **4** |

The phantom was `skip:/tmp/stale/c9.log` — a skip line with no space after the colon, which
every reader that splits the verdict into blocks counts as a fifth case. Tightening
recognition to `^skip:\s` was **rejected**: it could only fail by silently dropping a line,
which is this issue's own defect reintroduced by its own fix, and it would be a second
spelling of a shape `run_suites.sh` already matches as `^skip:` (issue 0689's disease).
Normalising instead keeps recognition and fixes the shape.

### The new figures, read off the gate rather than computed

`tests/results.2325750.log`, the batch's joint E+F gate, solo, `DISPLAY` set:

```
T1-RUN-BEGIN pid=2325750 … planned_cases=88 … home=throwaway binary=…/src/xschem canonical=results.log
T1-RUN-END   pid=2325750 cases=88 blocks=87 counted_failures=0 skips=5 elapsed=532s
```

**`cases=88`, `blocks=87`** (the 1486 case is the 73rd `hcases` entry; list lengths
`3 / 73 / 11`), **`wc -l` 260 on a green verdict**, with 5 `^skip:`, 74 `^RESULT:` and 2
`^OVERALL:` lines in it. The arithmetic, for whoever has to recognise a truncated file:

```
   2  sentinel lines (T1-RUN-BEGIN, T1-RUN-END)
+ 87  block header lines
+ 87  "Total num fail:" lines
+  3  NOGOLD notes
+  5  skip: lines               (this issue)
+ 74  RESULT: lines             (this issue)
+  2  OVERALL: ok (N checks)    (this issue, the banner-only fallback)
= 260
```

⚠ **Two of those terms are environment-dependent, so `wc -l` is an even worse constant to
check against than it was.** `skips=` is **5** on a box whose `XSCHEM_TEST_REAL_HOME`
resolves the fork ngspice and **8** on one that does not — the stage-F gate's own figure,
and the measurement this issue was filed on. Read `cases=`, `blocks=`, `counted_failures=`
and `skips=` off `T1-RUN-END`; count nothing you can read.

Other measured figures: `test_regression_concurrency_1476` **37 → 46 checks** (section V5 is
nine rows, `V5z` and `V5a`–`V5h`, over six stand-in cases); **16 sabotages** (S1–S16), each
reddening exactly one row or row pair and leaving every pre-existing row of that suite green;
`test_home_isolation` `ALL PASS (116 checks)` and `test_audit_classifier` `ALL PASS (75
checks)`, the latter because the banner fallback consumes `banner_rule.tcl`'s own
`banner_complete` rather than spelling the banner shape a fourth time.

⚠ **The registration needed a prerequisite, and the failure would have been silent.**
`test_untitled_autosave_1486` printed a `RESULT:` line and no `OVERALL:` line at all;
`run_suites.sh` scores from `^RESULT` and never needed one. MEASURED on the suite's own
output before the banner was added: `banner_complete = 0`, `regression_case_failed(0) = 1`
— registering it as it stood would have appended `HARNESS: … did not complete cleanly` and
counted a failure in the one file whose baseline is ZERO, while all 13 of its checks passed.
That is issue **0689**'s false red arriving from the other side. After: `banner_complete = 1`,
`regression_case_failed(0) = 0`.

### ⚠ What the fix does NOT cover

* **`full_audit.sh` still drops per-row `skip:` lines** — the same class in the other
  documented driver, whose `SUMMARY:` line therefore still cannot say what was not measured.
  Filed as **1497**, not fixed here (the batch's acceptance criterion 4).
* **A `skip:` line whose reason ends in the word `FAIL` is still counted as a failure.**
  Measured identical before and after. Fixing it would mean testing the skip arm first — the
  escape hatch above — or rewriting a suite's own text, which a verdict writer should not do.
  No suite in the tree hits it (measured over every `skip:` line emitted in a full run) and
  `V5e` now pins it so nobody "fixes" it into a hole.
* **`t1_carry_line` is not a total neutraliser**, by construction: a carried line from the
  counted or `NOGOLD` arm with no whitespace at all and ending in `.log` would still wear the
  block-header shape. No emitter in the repository is near that shape; it is written into the
  proc's comment rather than left implicit.
* **The display arm's can't-run path** (`NODISPLAY:` / `HARNESS: … display arm NOT RUN`)
  writes its block by hand and does not pass through `summarize_all`. It has no skips to
  carry; its `incr t1_blocks` was checked, not assumed, so `blocks=` stays right.
* **No suite was made to emit more skips.** This issue is about the verdict, not about
  coverage itself: the rows now visible were already skipping honestly.
