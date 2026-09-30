# 1622 — `test_select_at` passes only with your real HOME and fails under the armed spelling

**STAMP:** `v1 claim=open tree=8ead6bb8 stamped=2026-09-29 fix=untried open=3`

Status: **OPEN**, filed 2026-09-29 while gating issue **1620**. Pre-existing — it is **not** caused
by 1620, and that was established by measurement rather than assumed.
Measured on this tree at `8ead6bb8` · Branch: `fluid-editing`
Related: issue **1620** and its "Pre-existing reds" section; batch
`doc/claude/replay_door_batch/`; CLAUDE.md's *throwaway test home* section.

## The defect

`tests/headless/test_select_at.tcl` gives **opposite verdicts depending on how it is launched**, and
the spelling CLAUDE.md declares correct is the one that fails.

| invocation | verdict |
|---|---|
| `tests/headless/run_suites.sh test_select_at` (**armed**, throwaway HOME) | **5 FAILED** |
| `tests/headless/run_suites.sh --nogui test_select_at` (**armed**, headless) | **NORESULT** — binary never reported |
| `DISPLAY=:99 ./src/xschem --pipe -q --script tests/headless/test_select_at.tcl` (**unarmed**, real HOME) | `RESULT: ALL PASS` |

The failing rows, in order, are:

```
FAIL: action log open
FAIL: SA5  command self-logs select_at (line={})
FAIL: SA6b replay reselects the same object (want={{wire 0 1 1}} got={})
FAIL: SA7b interactive click logged select_at (new=)
FAIL: SA8b shift-click logs 'select_at ... add' (new=)
```

**The first row is the cause and the other four are downstream.** `action log open` fails, so no log
exists, so every row that reads a log line back reports an empty one (`line={}`, `new=`, `got={}`).
Under the throwaway HOME that `run_suites.sh` arms, the suite cannot open its action log; with the
user's real HOME it can.

## Attribution, because this was found while suspecting something else

It surfaced during the driver's verification of issue 1620, whose crew reported `test_select_at` as
`ALL PASS` on both trees while the driver measured `5 FAILED`. That looked like a crew overclaiming.
It was not:

* At **pristine `8ead6bb8`** — a fresh `git clone --local --no-hardlinks`, `./configure && make` from
  scratch, containing **none** of 1620's changes — the armed run gives the **same 5 FAILED** and the
  headless run the **same NORESULT**.
* The failing row lists on the two trees are **byte-identical** (`diff` clean).
* The crew's own claim is true for the invocation it used: pristine HEAD invoked directly does print
  `RESULT: ALL PASS`.

So the two parties measured different environments and both reported honestly. ⚠ The generalisable
lesson is about the *report*, not the code: **a suite's verdict is only meaningful with its
invocation attached.** "`test_select_at` is green" is not a claim until it says which spelling, and
this suite is the proof, because both answers are reproducible.

## Why it matters even though nothing gates it

`test_select_at` is in **neither `hcases` nor `dcases`**, so it cannot redden T1 today. It matters for
three reasons:

1. CLAUDE.md declares `run_suites.sh [--nogui] <t>` the **armed** spelling and warns that a bare
   `./src/xschem … --script` keeps your real HOME and writes your clipboard, geometry and
   `simulations/`. So the only verdict this suite currently produces green is the one obtained the
   way the project tells you **not** to run suites.
2. Anyone who registers it — and the bounded rule obliges registration for anyone adding a fence row
   to it — inherits an immediate red, and will spend the time the driver just spent attributing it.
3. It belongs to exactly the class CLAUDE.md names: a suite whose green depends on the real HOME.
   The `scratch.tcl` suites print a `note:` when run unarmed for precisely this reason; this one does
   not, so nothing tells the reader which environment produced the answer.

## Still open (open=3)

1. **Find out why the log cannot open under the throwaway HOME** and fix the suite so it either
   arranges its own log destination or prints a legible `skip:` naming what is missing. The
   neighbouring evidence is that T1 passes no `--logdir` at all, and
   `tests/headless/test_selflog_grep_guard.tcl`'s `S5` canary already takes an explicit
   *"skipped: no --logdir"* arm for the same reason — so the shape of the answer probably already
   exists in that sibling.
2. **Register it once it is green under the armed spelling**, with the `OVERALL: ok` sentinel checked
   against `banner_complete` in `tests/banner_rule.tcl` first — `run_suites.sh` and `full_audit.sh`
   accept a `RESULT:` spelling that the gate's own reader does not, so a green standalone run is not
   evidence it can be registered.
3. **Decide whether the `NORESULT` on the `--nogui` arm is the same defect or a second one.** The
   armed display arm fails 5 rows; the armed headless arm never reports at all, which is a different
   symptom and may have a different cause. They are recorded together here because they were
   measured together, not because they are known to be one bug.

⚠ Two further unregistered pre-existing reds were measured in the same pass and are recorded in issue
1620 rather than here, because they are unrelated mechanisms: `test_selflog_output` fails six
flip/rotate rows (byte-identical at HEAD), and `test_context_menu_log` times out at 200 s with
`FATAL: signal 15`.
