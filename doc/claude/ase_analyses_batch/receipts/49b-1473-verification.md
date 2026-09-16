# 49b — independent verification of issue 1473 (receipt 49)

Verifier pass, 2026-09-15, tree at `03c68f3f` + the crew's uncommitted work.
`src/ase.tcl` md5 `145eeac1…` at start and at end; base `001af1ca…` taken with
`git show 03c68f3f:src/ase.tcl`. Nothing implemented, committed or fixed here.

**All twelve rows CONFIRMED.** Two things the receipt states more strongly than
the tree supports are recorded below; neither changes a verdict.

## ⚠ C1 — "CK28c is a bench of SEVEN RESIDUE rows" is not accurate

`tests/headless/test_ase_core.tcl`, `set CK28RES` (row CK28c). The bench is seven
rows, of which **six are residue kinds** — `op`, `noise`, `disto`, `tf`, `pz`,
`sens`. The seventh is `ac`, which is **not** one of the eight kinds issue 1473
names (`op`, `noise`, `disto`, `pss`, `sp`, `pz`, `sens`, `tf`). `ac` declares no
`salvage` either (measured: `ase::analysis_salvage ngspice ac` → `{}`), so the row
still measures a no-salvage bench and still passes honestly — but **`pss` and `sp`,
two of the eight named kinds, are covered by no row in the suite.**

Measured independently instead: all eight kinds answer `{}` from
`ase::analysis_salvage ngspice`, and seven of the eight were walked through the
real planner beside a live transient control (the pair yields exactly one plan
row, `tran`, so the residue type contributed nothing and the control proves the
walk ran). `pss` is confirmed by its salvage declaration only — a minimal `pss`
row makes `ase::analysis_emit_order` raise in my fixture, which is a fixture
limit, not a product fact. The receipt's *conclusion* is right; its description of
the row's coverage is not.

## ⚠ C2 — `state_roundtrip.tcl` cannot be run the way the brief words it

`tests/headless/state_roundtrip.tcl` **only defines `ase_state_roundtrip`** and has
no top-level driver, so `./src/xschem … --script tests/headless/state_roundtrip.tcl`
exits 0 having compared nothing and printing nothing. A verifier who ran it that
way and saw rc 0 would score the row green on an empty measurement. Driven through
the proc (`source` + `ase_state_roundtrip $repo`) it answers
`tracked 104  bad {}  control_disagrees 1  control_agrees 1` — both controls live.

## The sabotage campaign — the verifier's own arms, not the crew's

Six exact-anchor mutations of `src/ase.tcl` (anchor count asserted `== 1`; an arm
whose md5 equalled the fixed file's would be refused), the three suites carrying
the new rows run headless under `timeout`, reds read **by row name**, restore by
plain `cp` + md5 after every arm, `try/finally` plus SIGINT/SIGTERM/SIGHUP
handlers. All six KILLED; no restore mismatch.

| arm | mutation | rows that reddened |
|---|---|---|
| S1 | a checkpointed run is told it will be discarded (`set n {}`) | CK28 CK28b CK28d **CK28e** CK29 L12 NP7 |
| S2 | the percentage is a constant `20` | CK28b |
| S3 | `ckpt_worst_n` takes the LARGEST n | CK28b |
| S4 | a missing `before_ckpt` falls back to the discarded sentence | CK28e |
| S5 | the run door passes no plan | CK29 |
| S6 | the log header ignores the record's `ckpt` | CK29 L12 |

Final restored tree `145eeac176e59f782a6ad7b9bddf05f7` = pristine.

## What was measured, not read

* **Claim 1** — the percentage re-derived by moving the PLANNER and re-walking my
  own bench (`tran 5n/5m`, 1,000,000 points): `ase::ckpt_n` 2→`33.3`, 4→`20`,
  9→`10`, 19→`5`, 49→`2`. Hand-spelled plans `{4,9}`→20 and `{9,4}`→20 (smallest
  wins, order-independent), `{3,7,11}`→25. **Zero** literal `20` in any added
  non-comment line of `src/ase.tcl`.
* **Claim 2** — probe run against 03c68f3f's `ase.tcl` and against the fixed tree:
  11 of 12 keys byte-identical, including the CIW line, the `stop      :` field,
  the whole six-line header, and the on-disk log header of one real run. The 12th
  differs only in my own probe's pid inside a scratch path. `run_stop_cost` gains
  `before_ckpt`; `before` and `after` are unchanged byte for byte.
* **Claim 5 end to end** — ngspice's backend entry cloned whole with only
  `run_cmd` overridden by a binary that cannot exist, so nothing starts and the
  log is still written: for a checkpointed run and an un-checkpointed one the CIW
  note equals `"ase: "` + the `stop      :` field read back **out of the log file
  on disk**. The rendered deck corroborates (2 × `stop after`, 2 × `ASE-CKPT`
  checkpointed; 0 and 0 un-checkpointed). `ase::run_deck` resolves
  `ase::ckpt_rows` exactly once and hands that same variable to both channels.
* **Claim 7 CONFIRMED** — `ase::run_stopped_msg` (`src/ase.tcl:16960`) takes one
  argument and returns `ase: simulation stopped — nothing of this run was
  written`; its only caller, `src/ase_window.tcl:12548` in `ase::ui::do_stop`,
  passes the simulator name alone. A stopped checkpointed run still hears it.

## Suites, both arms, rc 0

Headless 644 / 118 / 79 / 49 / 235 / 87 / 76; display (`:99`, Xvfb + openbox)
644 / 118 / 79 / **153** / 235 / 87 / 76. 7/7 runs passed on each arm.

`tclsh tests/run_regression.tcl`, solo and in the foreground under `timeout 3600`:
rc 0, **zero** counted lines in `tests/results.log` (no `FAIL$`, `GOLD?`,
`RESULT?`, leading `FATAL`), 84 × `Total num fail: 0`, no case non-zero, no
`couldn't execute` and no `exit 127`.
