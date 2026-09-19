# 1485 — nine T1 suites go red in a `git archive` export because they read their corpus through git

**STAMP:** `v1 claim=open tree=7a46275f stamped=2026-09-18 fix=none open=9 by=F-docs`

**Status: OPEN — filed 2026-09-18** by the outsider-fixes batch, stage F (docs crew), from
`doc/claude/outsider_fixes_batch/DECISIONS.md` D1 and D12 (outsider audit **F21**).
**Class** stranger-facing false red in T1. Nine suites, one shared shape. `open=9` counts
the suites in the table below.

---

## What happens

A GitHub "Download ZIP", a release tarball or a `git archive` export has no `.git`. It
builds cleanly, and T1 in it then reports suites red that are green in a clone. Each of
them lists or reads its corpus through `git ls-files` or `git rev-parse`, and then **uses
git's error text as data**: as a file path, as an empty list, or as a dict to parse.

The tenth red case in the audit's count, `test_issue_stamp`, was the batch's own
regression and is **fixed** (Item 1, `aa5cece0` / `d42fc517`). Per D1 none of the nine
below was touched: they share the checker's symptom, not its code.

## The nine, MEASURED by the S1 crew (`receipts/S1.md` §7)

Command: `cd <export>/tests && env -u DISPLAY HOME=<fresh scratch> timeout 1800 tclsh
run_regression.tcl`, at the 85-case tree. Final run `T1-RUN-END pid=2248951 cases=85
blocks=84 counted_failures=29`. The control re-ran each case exactly as T1 runs it, in a
**full clone**, each with its own fresh HOME.

| case | counted | failing line in the export | full-clone control |
|---|---|---|---|
| `test_ase_core` | 6 | `CP1`–`CP4` and `CP7` FAIL, then `couldn't open "GIT-LS-FILES-FAILED"` | `ALL PASS (675)` |
| `test_ase_simcaps_0948` | 2 | `W6 … -> {0} (exp {1}) : FAIL` (the corpus read swallowed to empty) | `ALL PASS (211)` |
| `test_ase_options_1437` | 2 | `DL5 … -> {RAISED:fatal: not a git repository …}` | `ALL PASS (75)` |
| `test_ase_predeck_1439` | 2 | `RD10 … -> {RAISED:fatal: not a git repository …} (exp {5 0 5})` | `ALL PASS (78)` |
| `test_ase_sp_1452` | 2 | `SC1 every tracked state file still round-trips … -> {0 {} 0 0 …}` | `ALL PASS (58)` |
| `test_ase_trnoise_1466` | 1 | died after 58 ok: `couldn't open "<export>/fatal: not a git repository …"` | `ALL PASS (80)` |
| `test_ase_trnoise_gui_1467` | 2 | `N0 … -> {RAISED:couldn't open "<export>/fatal: not a git repository …"}` | `ALL PASS (19)` |
| `test_ase_variant_1470` | 1 | died after 75 ok, the same `couldn't open "<export>/fatal: …"` | `ALL PASS (76)` |
| `test_ase_simwin_variant_1471` | 2 | `ST1 … -> {RAISED:dict element in quotes followed by ":" instead of space}` | `ALL PASS (12)` |

**20 counted lines in total.** The same run's other nine counted lines are not this
issue: eight are the four DISPLAY-unset segfaults (issue **1483**; the run had DISPLAY
unset), and one is `create_save`'s first-run `~/.xschem` mkdir race (audit F25), which the
throwaway HOME now pre-creates away (`7a46275f`).

Two causes in the table are READ from code, not traced. `test_ase_core` has
`set CPF {GIT-LS-FILES-FAILED}`, a sentinel that ends up used as a path, and
`test_ase_simcaps_0948` has `if {[catch {exec git -C $repo ls-files -- *.state} W_OUT]}
{ set W_OUT {} }`. For `test_ase_simwin_variant_1471` the cause (a state round-trip
parsing git's error text) is INFERRED from the audit.

**One audit claim did not reproduce:** an F21 verifier wrote that `test_ase_variant_1470`
(`OT1`) and `test_ase_sp_1452` (`SE1`) were already red in a fresh-HOME **git** clone. On
this box both passed in the full-clone control (76 and 58). The difference is UNKNOWN.
Note that `SE1` is also the row issue **1484** reddens in an uppercase path, which may be
the explanation. That is INFERRED.

## Fix direction

The remedy has already been built once, in `tests/headless/issue_stamp.tcl`: **classify
the history once** (`none` when there is no `.git`), and skip each corpus-dependent row
**by name**, with a `skip:` line saying why. Never feed an error string onward as data.
A shared helper (for example in `scratch.tcl`) that answers "the tracked files matching
`<glob>`, or a named reason there are none" would serve all nine. Every row that then
skips must be visible, which is issue **1487**'s point: today a skip never reaches the T1
verdict.

⚠ **A green export run is not the goal by itself.** Skipping must be by name and loud, or
this becomes a silent loss of coverage on exactly the shape a stranger runs.

## Evidence

`doc/claude/outsider_fixes_batch/receipts/S1.md` §7 (the table, the control and the sum),
`receipts/audit_findings_in_scope.md` (F21, its verifier's upholding).
