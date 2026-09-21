# 1483 — four T1 suites segfault mid-run under `--nogui` when `DISPLAY` is unset, so a headless box never sees T1 at ZERO

**STAMP:** `v1 claim=fixed tree=2288d437 stamped=2026-09-20 fix=taken open=0 by=driver`

**Status: FIXED 2026-09-20 in `2288d437`** — filed 2026-09-18 by the outsider-fixes batch, stage F (docs crew), on
the driver's instruction (`doc/claude/outsider_fixes_batch/DECISIONS.md` D12, corrected
by D13.12). **Class** product defect — a crash — found through the harness.
**Related:** **0227** (a headless `xschem callback` segfaults on a NULL `Display*` in
`update_statusbar()`), **0834** (`xschem callback` segfaults under `--nogui`), **0467**
(`test_undo_selection` segfaults at teardown). The relation to any of them is
**INFERRED, not verified** — see "What is not known".

⚠ **The outsider audit filed this as F14, "four suites segfault in a fresh clone". That
label is wrong, and every S2c receipt carried it forward.** A fresh clone has nothing to
do with it. The S2c completeness critic measured the cause (DECISIONS D13.12), the
regression refuter confirmed it, and this crew re-measured it at `7a46275f`: **the four
crash when `DISPLAY` is unset, and pass when it is set** — fresh HOME, copied real HOME,
fresh clone or main tree alike.

---

## The defect

`cd tests && env -u DISPLAY HOME=<scratch> timeout 600 ../src/xschem --nogui --pipe -q
--script headless/<t>.tcl`, main tree at `7a46275f`, one scratch HOME per suite, the four
run in parallel. **MEASURED** by this crew, 2026-09-18:

| suite | last `ok:` row printed | `ok:` rows printed | `while editing:` | rc | the same suite in the stage-F gate, DISPLAY set |
|---|---|---|---|---|---|
| `test_unused_attr_0970` | `UF28` | 57 | `uapass` | 1 | `RESULT: ALL PASS (67 checks)` |
| `test_auto_specialize_1201` | `AS65` | 66 | `aswv` | 1 | `RESULT: ALL PASS (85 checks)` |
| `test_ase_optier_0963` | `S13` | 88 | `passgate` | 1 | `RESULT: ALL PASS (109 checks)` |
| `test_op_annot` | `W30a` | 341 | `passgate` | 1 | `RESULT: ALL PASS (485 checks)` |

Each run printed `EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_<cell>_<x>`, then `FATAL:
signal 11`, and **no `FAIL` row** (a grep for `FAIL` hits one line of `test_op_annot`,
which is the text of its passing row `N9`). The right-hand column is read from the gate's
own case logs (`tests/headless/<t>.log`, written 19:14–19:17 during the run whose verdict
is `tests/results.1176485.log`).

**It is a crash mid-suite, not on exit.** The S2c critic's note called it a crash "on
`--nogui` exit"; the rows say otherwise. `test_unused_attr_0970` printed 57 `ok:` rows
against 67 checks, and the statement after its `UF28` check is not an exit.

**The same four rows, in every earlier measurement.** The S1 crew saw `W30a`, `S13`,
`UF28` and `AS65` in a `git archive` export and again in a full-clone control
(`receipts/S1.md` §7). The export's T1 ran with `env -u DISPLAY`. The receipt does not
state the control's DISPLAY, and that it too was unset is INFERRED from the identical
crash. The S2c critic got `signal 11` after
`UF28` with DISPLAY unset and `ALL PASS (67 checks)` with `DISPLAY=:199`, and likewise
`test_auto_specialize_1201` at 85. The regression refuter got `signal 11` for
`test_ase_optier_0963` with DISPLAY unset **even under a copy of the real home**, and
`ALL PASS (109)` with `DISPLAY=:197` (`receipts/S2c_refute_r1.md`). The R3 prover's
DISPLAY-unset T1s held exactly these four, two counted lines each (a `FATAL: signal 11`
and a `HARNESS` line), and so did the pre-fix base, block by block
(`receipts/S2c-R3-prove.md`).

## Why it matters: T1's ZERO is a DISPLAY-set ZERO

Every recorded T1 ZERO, including the stage-F gate at `7a46275f` (`T1-RUN-END cases=87
blocks=86 counted_failures=0`), was taken with `DISPLAY` inherited from the shell. **With
`DISPLAY` unset the same tree is `cases=87 blocks=86 counted_failures=8`** (measured by
the regression refuter on five runs and by the R3 prover on two; `wc -l` 185). That is
the CI box, the container, and the SSH session with no forwarding: exactly the stranger
the outsider audit was measuring. They clone, build, run the documented command, and get
eight counted failures in suites nobody touched. By CLAUDE.md's own rule (a standing red
is a defect, not furniture) that is a red baseline for everyone without an X server.

## RESOLUTION — FIXED 2026-09-20, commit `2288d437`

Both questions below are answered, and both answers are MEASURED. The section is kept as
filed, because what it guessed and what was true are different in an instructive way.

**The cause is one statement, not a class of paths.** All four suites fault at
`XMaxRequestSize(display)` in the `xschem globals` branch of `scheduler.c`. Frames #0-#10
of the backtrace are byte-identical across the four, differing only in the script name.
`display` is assigned only inside `if(has_x)` (`xinit.c`), so with `has_x` 0 it is NULL
when `DISPLAY` is unset. A three-line script whose only xschem call is `xschem globals`
reproduces the crash, so no descend, walk or sub-sheet is involved at all.

**Why `DISPLAY` matters under `--nogui`** is therefore not "something reads the
environment on the descend path": `--nogui` with a `DISPLAY` set takes the same branch
with a pointer `xserver_ok()` has already `XCloseDisplay()`d, and printed a fabricated
`XMaxRequestSize=4` against a true 65535 instead of faulting. The loud mode and the silent
mode are the same defect; the silent one is why the fatal one survived, because every arm
anyone ran had a display. That freed-pointer global is now issue **1493**.

**Three of the four reach the call through the product's own `op_annot.tcl`**, inside a
`catch` that a signal ignores, so this was never a test artefact: a headless user
annotating operating points crashed.

**The relation to 0227, 0834 and 0467 is REFUTED as a cause.** Those are
`XGetKeyboardControl` in `callback.c`, reached through `xschem callback`; they still crash
on this binary and are recorded in 0227 with four measured witnesses (none of them a T1
case). 0467 is proposed there as a duplicate of 0227, its "at teardown" reading corrected.
Four further verbs that kill the process headless are issue **1492**.

**Fix direction step 1 is done** (guard in the product, not `DISPLAY` in the harness:
both Xlib calls branch on `has_x`, and the no-display arm reports `<no X server
connection>` rather than a number). **Step 2 is done in a different shape than it asked
for**: it asked for a suite that descends under `env -u DISPLAY`, which would have guarded
a path that turned out to be innocent. Instead `test_callback_argc` gained three rows
branching on the `::has_x` mirror, so the guard is counted on every box — including a
developer desktop with a display, where `run_regression.tcl` hard-codes `--nogui` and
`has_x` is 0 regardless.

**Measured after the fix:** the four suites pass headless with the check counts they have
with a display (67, 85, 109, 485); a full T1 with `DISPLAY` unset closes
`counted_failures=0` where the unfixed binary closes 8, taken twice in independent clones;
a full T1 with a display stays at 0 (`cases=87 blocks=86 counted_failures=0`, this tree,
`2288d437`). Reverting the guard reproduces the table above row for row.

Batch record: `doc/claude/stranger_reds_batch/` (item B), DECISIONS D5 and D6, receipts
`B-impl.md` and `B-verify.md`.

## What is not known

* **Which call crashes.** READ, not measured: after the last `ok:` row,
  * `test_unused_attr_0970` runs `catch {xschem load $UATOP}` and then
    `op_annot::save_cards`;
  * `test_op_annot` runs `xschem load $W_TB` and then `op_annot::save_cards` (through
    `opa_w_walk`);
  * `test_auto_specialize_1201` runs `as_door`, which loads a sheet, selects an instance
    and calls `xschem descend`;
  * `test_ase_optier_0963` reaches `n_dsc`, which calls `xschem descend 1 2`.

  The crash handler names a **child** cell each time (`passgate`, `aswv`, `uapass`). So
  the common factor looks like **walking or descending into a sub-sheet under `--nogui`
  with no X display** — INFERRED. 0227's shape (an Xlib call on a NULL `Display*`) is one
  candidate. It is not verified.
* **Why `DISPLAY` matters under `--nogui` at all.** The binary is told not to open a
  window either way. Something on the descend or walk path evidently reads the
  environment, or a Tk/X handle that exists only when `DISPLAY` is set. INFERRED from the
  on/off result; the code has not been read for it.

## Fix direction

1. Reproduce under a debugger, with the `test_unused_attr_0970` recipe above (57 rows,
   about a minute), and fix the NULL dereference in the product. Do not fix it by setting
   `DISPLAY` in the harness: a headless user's `--nogui` script would still crash.
2. Then add a T1-visible guard: a small headless suite that descends into a sub-sheet
   under `env -u DISPLAY --nogui`, so the next regression of this shape is counted on
   every box and not only on DISPLAY-less ones.

## Evidence

* This crew's runs: `/var/tmp/xschem_fixes/fdocs/{ua_nodisp.out,
  test_auto_specialize_1201.nodisp.out, test_ase_optier_0963.nodisp.out,
  test_op_annot.nodisp.out}`. Their four emergency-save dirs, named in those outputs,
  were removed.
* `doc/claude/outsider_fixes_batch/receipts/S1.md` §7,
  `receipts/S2c_refute_r1.md` (critic problem 2, regression refuter points 1–2),
  `receipts/S2c-R3-prove.md` (§1, "Every counted line in this stage").
