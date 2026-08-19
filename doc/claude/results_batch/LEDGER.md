# Results batch — LEDGER

**Driver-owned. No crew agent may edit this file.** The driver appends the row
after each item returns.

State lives here, not in the driver's context. **After any compaction, re-read
this file first**, then `PLAN.md` §1.

---

## Batch

| | |
|---|---|
| Feature | `Results ▸ Select…` — bind a saved simulation result to an ASE-L session |
| Spec | `doc/claude/specs/results_selection.md` (966 lines, ruled §17) |
| Plan | `PLAN.md` — **§1 is the authoritative item list** |
| Decisions | `DECISIONS.md` — 10 user rulings + 2 driver rulings, none re-openable |
| Crew brief | `CREW_BRIEF.md` — in every item's `load` list |
| Pipeline | `item_pipeline.js` — Implement → Verify → Review×3 → Fix → Commit |
| Branch | `fluid-editing`, base HEAD `226302f9` |
| Push | **never** |

## Baseline

| | |
|---|---|
| File | `baseline_2026-08-19_226302f9.txt` |
| HEAD | `226302f9` |
| Display | `:99` (dev display, 1920x1080x24, openbox), `GUI_GATE=1` |
| Summary | **331 pass / 15 fail / 0 crash-timeout / 0 skip (total 346)** · scratch 0 leaked · tree 0 appeared 0 vanished |
| Reds | `test_ase_window` `test_cadence_drag` `test_ciw` `test_gf180mcud_libmgr` `test_ihp_sg13g2_libmgr` `test_lib_manager_gui` `test_lib_manager_locate` `test_lib_sweep` `test_reopen_readonly` `test_rotate_stretch_short_0104` `test_selflog_output` `test_sky130a_libmgr` `test_wave_markers` `test_wave_sigbrowser_0312` `test_wave_sigbrowser_keys` |

**Every audit is judged as a DIFF against that file, by test NAME and STATUS,
both directions. Never by the red count.**
`doc/claude/batch_F/baseline_status.txt` is **VOID** — do not diff against it.

Rolled forward when an item adds a suite of its own; both `BASELINE` and
`BASELINE_SUMMARY` in `item_pipeline.js` move together, and the roll is recorded
in the row that caused it.

## Verdict key

`[x]` done, verified by sabotaged checks · `[E]` done, pixels — a human must look
· `[D]` deferred (issue required) · `[F]` failed (issue required)

---

## Items

| # | item | verdict | commit | checks | sabotages | files | eyeball | note |
|---|------|---------|--------|--------|-----------|-------|---------|------|
| 1 | `read-restamp-0509` | | | | | | | |
| 2 | `results-tcl-resolver` | | | | | | | |
| 3 | `raw-select-subverb` | | | | | | | |
| 4 | `results-select-orchestrator` | | | | | | | |
| 5 | `rawbar-load-reexpress` | | | | | | | |
| 6 | `persistence-write-side` | | | | | | | |
| 7 | `results-select-dialog` | | | | | | | |
| 8 | `waves-menu-cadence-gate` | | | | | | | |
| 9 | `kill-second-rawinfo-parser` | | | | | | | |
| 10 | `calculator-consumes-selection` | | | | | | | |

## Issues this batch closes

| issue | item | status |
|---|---|---|
| 0509 | 1 | open |
| 0508 | 8 | open |
| 0507 | 9 | open |
| 0216 (shape only) | 4 | open |

## Eyeball debts

Item 7 is a pixel deliverable and **may not be verdicted `[x]`**. Its closer owes
`tests/headless/owed.sh add look`. Record the debt id here when it is raised.

| debt | raised by | what to look at | cleared |
|---|---|---|---|
| | | | |

## Notes and rolls

- **2026-08-19** — batch opened. Two driver rulings taken (`DECISIONS.md` §B):
  D-A = R110's re-stamp **and** the new `xschem raw select` sub-verb (the spec's
  standing assumption, rung 3's zero-C option rejected because it fixes one
  caller, not the verb); D-B = no run history, no per-run result directories, no
  read-side migration.
- **2026-08-19** — baseline shot at `226302f9`: **331/15/0/0 of 346**, byte-for-byte the same status set as the casemode batch closer audit, so the tree is stable going in. `BASELINE_SUMMARY` filled in `item_pipeline.js`.
