# 1486 — suites write xschem's untitled autosave into their cwd, and the checkout's op_param project file is the user's, not litter

**STAMP:** `v1 claim=open tree=7a46275f stamped=2026-09-18 fix=partial open=2 by=F-docs`

**Status: OPEN, partly fixed — filed 2026-09-18** by the outsider-fixes batch, stage F
(docs crew), from `doc/claude/outsider_fixes_batch/DECISIONS.md` D12 and D13.3. **Class**
harness writes outside its scratch. `open=2` counts the two open items at the foot.
**Related, read first:** **0609** (the `untitled~.sch` leak is 80 suites wide), **1480**
(nothing sweeps the `untitled*` residue class), **0673** and **0687** (two producers),
**0060** (why untitled buffers are backed up on purpose), **1381** Part 2 (a user's
op_param settings file destroyed as "litter" once already), **1273** (which directory is
the project).

⚠ **READ THE SECOND HALF BEFORE ACTING ON THE FIRST.** DECISIONS D12 listed the op_param
project tier, `.xschem/op_param_lists.conf`, under "suites write into the cwd", adding that
*"this checkout's root has carried one since 2026-09-09"*. **That file is the user's own
Save, not test litter**, and reading it as litter is how one was quarantined on
2026-09-07 (issue 1381). This issue files the D12 line **corrected**. It is not
evidence against the file.

---

## Half 1 — the untitled autosave (`untitled~.sch`), MEASURED

xschem backs up an unsaved untitled buffer as `untitled~.sch` **in the current
directory**, deliberately (issue 0060, `write_backup()` in `src/save.c`). A suite that
leaves an untitled buffer therefore drops the file wherever it was run from. The leak's
breadth is 0609's subject and its sweep is 1480's. What this batch added:

* **With cwd = the tester's HOME, a documented command destroyed the tester's own
  autosave.** MEASURED by the S2c safety refuter (`receipts/S2c_refute_r1.md`, runs
  `cwd2_*`): `run_suites.sh` run from `~` **overwrote** a pre-existing `~/untitled~.sch`
  (`test_signal_short_nohier_0230`) or **deleted** it (`test_crossview_paste`). That file
  is xschem's autosave of the tester's unsaved work. The R3 prover measured the unfixed
  base changing a seeded `~/untitled~.sch` from 101 B to 219 B
  (`receipts/S2c-R3-prove.md` §2).
* **Fixed for `run_suites.sh` and `gated_xschem.sh`** by D13.3 in `7a46275f`. Both now
  make their path arguments absolute and change to the repository root before running
  anything, as `full_audit.sh` already did. The R3 prover ran them from the canary home,
  seeded and empty, and found it byte-identical, `untitled~.sch` included (`rs_canary_fix2_*`
  and §10).
* **Still written in the checkout on every green T1.** `tests/untitled~.sch` has mtime
  **2026-09-18 19:14:29**, inside the stage-F gate's run (19:12:52–19:21:29, verdict
  `tests/results.1176485.log`; MEASURED by `stat`). That is 1480's measurement again, and
  it stays 1480's.

## Half 2 — the op_param project tier: the correction

* **What is true (READ):** `op_param_lists::conf_path project` is
  `[file join [pwd] .xschem op_param_lists.conf]`, so the tier follows the cwd (the
  S2a map; `src/op_param_lists.tcl`'s header lists `<pwd>/.xschem/op_param_lists.conf` as
  "the project tier"). A Save with project scope from a suite whose cwd is X writes
  `X/.xschem/op_param_lists.conf`. `test_op_param_store_1245.tcl`'s comment above `CT1`
  records a probe that did exactly that into `/home/analog/.xschem/` with cwd `$HOME`, and
  was restored.
* **What the suites do about it (READ):** the three suites that exercise the tier
  (`test_op_param_store_1245`, `test_rdw_keys_1245` and `test_rdw_window_1245`) take the
  checkout file's identity (size and mtime, or `ABSENT`) before they run and compare it
  at a hygiene row (`H1`, `SD4`, `BT9`; issue 1381). Where they press Save, their comments
  say they move the cwd off the repository root: `test_op_param_store_1245`'s `CT` rows
  redirect both `::USER_CONF_DIR` and the cwd into scratch, and `test_rdw_window_1245`'s
  section says it "NEVER PRESSES SAVE AT THE REPO ROOT".
* **What nobody measured:** no crew in this batch observed a suite writing the project
  tier. The D12 line rests on the S2a map (READ) plus the presence of the file.
* **The file itself (MEASURED):** `<repo>/.xschem/op_param_lists.conf`, untracked, mtime
  **2026-09-09 09:58:51**, 19 non-comment rows beginning `version 2` and `list class mos
  summary`. Issue 1381 records the user's Save as "a nine-parameter summary list for
  class MOS", and `src/op_param_lists.tcl`'s DD-6 comment says *"the user has a real
  nine-row one at `<repo>/.xschem/op_param_lists.conf`"*. **It is theirs. Do not delete,
  move or "clean" it.**

## Still open

1. **A bare invocation from another cwd still writes `untitled~.sch` there.** D9 keeps
   the bare `./src/xschem … --script <t>.tcl` un-armed, and nothing changes its cwd. Typed
   as documented, from the repository root, it lands in the checkout (0609). Typed with
   absolute paths from `~`, it would land in the tester's home and overwrite their
   autosave, as the drivers did. INFERRED from D13.3's diagnosis, not re-measured after
   the fix.
2. **Suites run through `run_suites.sh` now always read the tester's project tier.**
   Since D13.3 the cwd is always the repository root, and `op_param_lists::load` reads
   `<pwd>/.xschem/op_param_lists.conf` at startup (issue 1380). A suite whose expectations
   assume the shipped default lists would see a tester's saved rows instead. INFERRED,
   not measured: every crew in this batch ran in clones without the file.

## Evidence

`doc/claude/outsider_fixes_batch/DECISIONS.md` D12 and D13.3,
`receipts/S2c_refute_r1.md` (safety refuter, measurement 5), `receipts/S2c-R3-prove.md`
§2 and §10, `receipts/S2a.md` (the project-tier map line), and issue 1381 Part 2.
