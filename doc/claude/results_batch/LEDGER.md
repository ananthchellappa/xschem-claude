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
| 1 | `read-restamp-0509` | `[x]` | `7aa76dca` | 74 | 21 | 7 | no | R110 + **R110a/b/c** ruled into spec §3.1; S1/S2 red sets disjoint ⇒ both twice-written arms proven; audit 332/15/0/0 of 347, **no status moved**. |
| 2 | `results-tcl-resolver` | `[x]` | `91c6eb9a` | 139 | 34 | 11 | no | `src/results.tcl` 379 lines, sourced + in `Makefile.in` install. Scope fence held (no mutator). R201a-e/R304a-b/R305a-b/R803a/R805a ruled into spec. Audit 332/15/0/0 of 347, **no status moved**. |
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
| 0509 | 1 | **FIXED** `7aa76dca` — candidate (1) |
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

## Suites this batch has added — expected +1 PASS rows against the baseline

The baseline file stays at `226302f9` (331/15/0/0 of 346). Rather than re-shoot
it per item, the rows this batch legitimately ADDS are listed here and in the
pipeline's `BASELINE_SUMMARY`. A row not in this list, moving in either
direction, belongs to the item that moved it.

| suite | added by | total after |
|---|---|---|
| `test_results_select` | item 1 | 347 |

## Carried forward — raised by an item, not that item's to fix

| from | what | disposition |
|---|---|---|
| item 1 §5 | **A THIRD verbatim copy of the "file found" branch exists in `new_rawfile()` (`src/save.c:1570-1577`) and does not re-stamp.** Different function, different contract (`0` = already loaded); no reproducer was built either way, and 0509 closed naming it. | **Handed to item 3.** Its crew is already inside `extra_rawfile()`'s neighbourhood: MEASURE it, then either fix it or file an issue with a real reproducer. Do not file a speculative one. |
| item 2 §2 R305b | **`raw_type_is_non_spice()` (`src/save.c:1622`) has no Tcl verb**, so `results::current`'s R102 gate hard-codes the one reader token `table` beside its C predicate. `xschem raw is_digital` answers the reader table's *other* column and returns 0 for `table` on purpose. | **Offered to item 3** as a bounded extra: add `xschem raw non_spice <type>` while in the same C file, then let `results.tcl` ask the engine. The crew may decline with evidence. |
| item 2 §5 | **`results::list` shadows Tcl's `list` inside the namespace** (documented in the header; every construction written `::list`). And `resolve` does not normalize `..` while `list` returns the engine's verbatim spelling — the engine dedupes by `strcmp`. | **Both are item 4's hazard**, since "is this path already loaded?" sits on top of the second one. Named in item 4's brief. |
| item 2 §5 | Seven reviewer observations raised, **none confirmed, none filed**: 0-byte raw and `.vcd` both resolve `ok`; `named` not absolute-ised without a `rundir`; a non-existent explicit `derived` blocks the `key` fallback; a throwing `raw_content_verdict` swallowed as `ok`; whitespace-padded `rawfile` resolves `invalid`; R201e suspected-uncovered. | Left standing. Re-raise only with a reproducer. |
