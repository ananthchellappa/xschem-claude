# 0147 — Regression harness resolves the binary as bare `xschem`: the whole suite silently no-ops, and stale logs are re-reported as current results

**Status:** FIXED
**Branch:** fluid-editing
**Area:** `tests/test_utility.tcl`, `tests/run_regression.tcl` (+ a wrong
instruction in `CLAUDE.md` `## Tests`).
**Found:** 2026-07-25, while reporting "pre-existing failures" during the 0142-0146
waveform work — the report itself was wrong twice because of this defect.
**Severity:** high — not a broken feature, a **broken instrument**. It cannot
distinguish "binary missing" from "test broken", and it hid a real red test
(see *Impact*).

## Symptom

`cd tests && tclsh run_regression.tcl` ends with 24 `FAIL` lines in
`tests/results.log` and then dies:

```
couldn't execute "xschem": no such file or directory
    while executing
"exec $xschem_cmd --nogui --pipe -q --script xschemtest.tcl > stefan_xschemtest.log 2>@1"
    (file "run_regression.tcl" line 109)
```

Every one of those 24 lines is misleading: **21 are cases that never ran**, and
**3 are a week-old log being replayed**. Meanwhile 2654 jobs that really did fail
contributed **zero** counted failures.

## Root cause

Three layers, all verified in this checkout.

### 1. The spawn never happens — `tests/test_utility.tcl:24`

```tcl
set xschem_cmd "xschem"
```

A bare command name resolved via `PATH`, with no fallback to `$XSCHEM` or the
in-tree build. Nothing named `xschem` is installed here (`which xschem` → nothing;
`make install` was never run; only source-tree builds exist). So:

- **21 headless cases** (`run_regression.tcl:90`,
  `eval exec {$xschem_cmd --nogui --pipe -q --script ${hc}.tcl} > ${hc}.log 2>@1`):
  Tcl `exec` raises before any child exists, the `>` redirect still truncates the
  log to 0 bytes, and lines 96-98 append a **synthesized** `exit=1` HARNESS line.
  Verified: all **17** `tests/headless/*.log` files are exactly **one line** — that
  synthesized line, with **no test output whatsoever**.
- **3 golden cases** interpolate `$xschem_cmd` into `/bin/sh` job strings
  (`netlisting.tcl:97`, `open_close.tcl:64`, `create_save.tcl:66`), so `sh` returns
  **127**. Verified `exit 127` counts: `netlisting_output.txt` **748**,
  `open_close_output.txt` **1901**, `create_save_output.txt` **5** — 2654 dead jobs.
- **`run_regression.tcl:109`** is the same `exec`, **unguarded by `catch`**, so it
  aborts the interpreter with a raw Tcl error *after* `results.log` was closed.

### 2. The golden cases fail *silently* — `tests/test_utility.tcl:116`

```tcl
proc print_results {testname pathlist num_fatals} {
  if {[file exists ${testname}/gold]} {          ;# <-- silent early-out
```

`tests/netlisting/gold`, `tests/create_save/gold` and `tests/open_close/gold`
**do not exist and are not in git** (only 6 gold files are committed, all under
`tests/headless/gold/`). So `print_results` never writes `<case>.log`, prints
"No gold folder. Set results as gold please." to stdout, and `summarize_all`
(`run_regression.tcl:48-64`) emits the **non-counting** note
`Couldn't open <case>.log to read`. A case in which all 1901 jobs died reports
nothing at all.

This is the asymmetry that makes the suite actively deceptive: the headless cases
fail **closed** (loud, synthesized FAIL), the golden cases fail **open** (silent).

### 3. Stale logs are re-reported as current

Nothing deletes `<case>.log` before a run. `tests/create_save.log` is dated
**2026-07-18 22:12** — a week stale, untracked — and contains exactly:

```
1. 0_examples_top_debug.txt: FAIL
3. pcb_test1_debug.txt: FAIL
7. rom8k_debug.txt: FAIL
```

`summarize_all` re-greps it every run and reports those three as this run's
result. They are **phantoms**: not netlisting failures, not from this run, not
from any recent run. (Worse, a "reproduce it on a clean baseline" check re-reads
the same stale file and appears to confirm them — which is exactly how they were
mis-reported before this issue was written.)

## Impact — it hid a real failure

Underneath the noise, one case was genuinely red. `test_gf180mcud_libmgr.tcl`
asserted `gf180mcu_tests has 59 cell dirs`; the library now has **62**. It went
red at 61 with `6c3e620c` (2026-07-24) and nobody could see it, because the
harness never launched the binary. Running it directly:
`RESULT: 1 FAILED (28 passed)`.

Fixed alongside this issue by turning the exact count into a **floor**
(`>= 59`, reporting the actual count) — `gf180mcu_tests` is a live test library
that legitimately grows, unlike the PDK libraries pinned exactly beside it
(`gf180mcu_pr == 66`, `sky130_stdcells == 437`). `sky130_tests` has no count
assertion, which is why its sibling test stayed green.

## Fix (as applied)

1. **`test_utility.tcl`** — `xschem_cmd` resolves `$XSCHEM` → in-tree
   `[info script]/../src/xschem` → `PATH`, absolutised with `file normalize`
   (`info script` anchors to this file, so it holds from any cwd; the path is
   interpolated into `sh` strings that `cd` first). Verified: resolves to
   `.../src/xschem` both from `tests/` and from a foreign cwd.
2. **`test_utility.tcl` `print_results`** — now **always** writes `<case>.log`.
   A missing `gold/` produces a non-counting `NOGOLD:` line *in the log*
   (previously stdout-only, where `summarize_all` could never see it), and
   `num_fatals` is emitted on **both** paths — it used to be discarded entirely
   when gold was absent, which is how 2654 dead jobs summarised as zero failures.
   Also fixed an undefined `$f` in the open-error message.
3. **`run_regression.tcl`** — `file delete -force ${tc}.log` before each golden
   case, so a previous run's log can never be replayed as current.
4. **`run_regression.tcl` `summarize_all`** — a missing log is now a counting
   `HARNESS: ... FAIL`, not a silent note.
5. **`run_regression.tcl`** — the final `xschemtest.tcl` `exec` is wrapped in
   `catch`, moved **inside** the `results.log` block, and its failure recorded as
   a FAIL instead of aborting the interpreter after the log was closed.
6. **`CLAUDE.md` `## Tests`** — documents the resolution order, states plainly
   that `create_save`/`open_close`/`netlisting` have **no committed baseline** and
   can only report `NOGOLD`, and explains how to read `results.log` (incl. that
   `couldn't execute` / `exit 127` invalidates the whole run).
7. **`0016` Part 4** — its "the last line's error is cosmetic" note was true only
   for the benign rc=10 fall-through and actively misleading for the
   `couldn't execute` variant; corrected in place with the distinguishing rule.

8. **`summarize_all`** also echoes `^NOGOLD` **uncounted**. Caught by
   self-review of the fix: without it a case with no baseline summarised as a
   bare `Total num fail: 0`, which reads exactly like a pass — the same hollow
   shape this issue is about, just moved.
9. **Robustness** (from adversarial review): a **bare** `$XSCHEM` (e.g.
   `XSCHEM=xschem`, meaning "find it on PATH") is no longer `file normalize`d
   into a bogus cwd-relative path; `$xschem_cmd` is single-quoted in the three
   `sh` job strings like its neighbouring `'$path'` interpolations; and the two
   Tcl `exec` sites dropped `eval`, so a binary path containing spaces stays one
   argument.

### Post-fix baseline (this workarea, no `$XSCHEM`, nothing installed)

| | before | after |
|---|---|---|
| `results.log` FAIL lines | 24 (3 phantom + 21 never-ran) | **0** |
| `sh` jobs exiting 127 | 2654 (748+5+1901) | **0** |
| headless case logs | 17 × 1-line stub, no test output | real output, `OVERALL: ok` (e.g. `test_instance_update` 100 lines) |
| golden cases | silent; no log written | run, produce 10 / 1901 / 1496 result files, log `NOGOLD` |
| end of run | aborts: `couldn't execute "xschem"` | exits 0, xschemtest recorded |

`hilight_hier_oracle`, `buried_hilight` etc. were never failing — they had simply
never run. They now pass (`OVERALL: ok`).

**The suite still verifies nothing for `create_save`/`open_close`/`netlisting`**
until someone promotes a `gold/` baseline; `results.log` now says so out loud
instead of implying a pass.

## Original fix scope (all in `tests/`, plus one doc)

1. **`test_utility.tcl:24`** — resolve in order: `$env(XSCHEM)` → in-tree
   `[file dirname [info script]]/../src/xschem` → `PATH`. Must be **absolutised**
   (`file normalize`): it is interpolated into `sh` job strings that `cd`
   elsewhere first, so a relative path would resolve against the wrong directory.
   This alone is the functional fix. Mirrors what `tests/headless/full_audit.sh`
   already does (`XSCHEM="${XSCHEM:-$REPO/src/xschem}"`).
2. **`run_regression.tcl`** — `file delete -force ${tc}.log` before each golden
   case, killing stale-log replay.
3. **`summarize_all` else-branch** — a missing log must count as a FAIL, not a
   note.
4. **`run_regression.tcl:109`** — wrap in `catch` and summarise into `results.log`.
5. Optional: report `POSIX ENOENT` rather than the fake `exit=1`; quote
   `'$xschem_cmd'` in the three `sh` strings.
6. **`CLAUDE.md` `## Tests`** — it prescribes `cd tests; tclsh run_regression.tcl`
   with no mention of the prerequisite, and states "Tests invoke the built binary",
   which is false as written. Point at `tests/headless/run.sh` /
   `full_audit.sh` — or direct `./src/xschem --nogui --pipe -q --script <t>.tcl`
   — as the trustworthy signal.

## Why file it, given it is "already known"

The **workaround** (`PATH=$REPO/src:$PATH XSCHEM_SHAREDIR=$REPO/src`) is recorded
in at least nine places — auto-memory `nogui-headless.md`, `editor-missing-fallback.md`
("stale logs get re-counted"), `rotate-stretch-anchor-tails-0103.md`, and several
`doc/claude/suggestions/*` session notes that all say "do NOT trust
run_regression.tcl here". The **in-tree defect is tracked nowhere**: no issue, no
spec. Issue `0016` covers the *installed-binary* variant (Trap B: wrong
`XSCHEM_SHAREDIR`) and explicitly dismisses the line-109 error as "cosmetic",
which is true of that variant but hides this one. The result is that every fresh
session rediscovers it from scratch and mis-reports the output — as happened here.

Related: `doc/claude/issues/0016-tutorial-true-headless-and-distinguishing-env-failures.md`,
memory `green-but-hollow` (this is its inverse: red-but-hollow).
