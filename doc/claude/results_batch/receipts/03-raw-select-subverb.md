# Item 3 — `xschem raw select <file> [<type>]` (R301, R113, R114) + two carried-forward tasks

## 1. Files changed

`git diff --numstat`: `src/save.c` **+266** (`raw_select()`, `raw_select_undo()`, and **R110d**, the re-stamp in `new_rawfile()`'s "file found" branch); `src/scheduler.c` **+68** (the `select` and `non_spice` arms, both inside the existing `raw`/`raw_query` dispatch in `xschem_cmds_r`); `src/xschem.h` **+9** (`extern int raw_select(...)`); `src/results.tcl` **+18/−20** (`_is_result_type` is now a one-line delegation; the reader token `table` is gone from Tcl); `tests/headless/test_results_select.tcl` **+500**; `doc/claude/specs/results_selection.md` **+217/−1**; `doc/claude/issues/status.md` and `doc/claude/results_batch/CREW_BRIEF.md` 1 line each. New files: `doc/claude/issues/0513-raw-switch-op-publish-gate-reads-the-previous-database.md` (92 lines) and this receipt.

**R113 held** — nothing added to `Xschem_ctx`; the selection is `extra_idx` (+ `extra_prev_idx`, which SEL143 rules is its other half). **R114 held** — `select` is `argv[2]` of the `raw` arm, and SEL139 reds when a sabotage wires a door into the top-level `xschem select`.

## 2. Decisions, and the evidence

Ten crew rulings, all written into `doc/claude/specs/results_selection.md` (line numbers there): **R110d** 357, **R301a** 552, **R301b** 577, **R301c** 594, **R301d** 613, **R301e** 641, **R301f** 656, **R301g** 669, **R301h** 683, **R305c** 785.

- **R301a — select re-binds EVERY slot of the run, not just the analysis named** (U11: one run is one result). Measured: `multi.raw` read under cellA, opened cellB, `raw select multi.raw tran` → 2, and the **dc sibling** then answers `loaded=0`. Dropping the sibling re-stamp reds SEL170 alone.
- **R301b — `<type>` is OPTIONAL**, against the brief and PLAN §4, which called it required because L10's by-name loop refuses without one. The verb routes through the `what==1` dedupe arm instead, which matches on filename alone. L10 **measured, not quoted** (SEL162). An explicit type still works, so this is a superset; there is no by-index form (`raw select 0` → 0).
- **R301c — ONE `extra_rawfile(1|RAW_READ_REBIND)` call**; read-vs-switch is the `extra_raw_n` delta **minus the predicted base-raw adopt** (`raw_read` leaves exactly that state). `select` is a user gesture, so it opts into the re-bind bit — dropping it reds SEL152-155,169; `adopt=0` reds SEL179 alone. Return spelling **2 switch / 1 read / 0 refused**: spec §5 said the opposite, two documents against one, and that spec line was corrected in place with a note.
- **R301d — a select of a one-point OP/DC publishes it**, gated on `xctx->raw` **after** the call and deliberately not on the `switch` arm's expression, which tests `allpoints` on the database it is *leaving* → **issue 0513 filed with a reproducer**, left unfixed (R111 binds; `raw switch` keeps its behaviour). Sabotage shows the difference is the expression, not the verb.
- **R301e/f/g/h (fixer round; all seven confirmed review findings were real and were fixed):** a refused select restores the whole cursor triple; a typeless select prefers the analysis you are on; an explicit non-spice type that does not land refuses instead of reporting success; a leading `~/` is expanded as the `raw_read` arm already does, so both verbs store one spelling.
- **F7/L3 held: nothing clears.** Clear-then-refuse sabotages red SEL174-177 and SEL207-208.
- **(a) `new_rawfile()`'s third copy — MEASURED, then FIXED as R110d.** Reachable: `xschem raw new` twice with one dataset name and no intervening clear leaves the dataset bound to the *previous* schematic. The first draft justified it by the shipped `autozero_comp` launcher; a reviewer showed that launcher's first line is `xschem raw_read`, which clears the registry — **false, and corrected in all three durable places** (spec, `save.c` comment, group-W header). The fix stands on the remaining reachability and is pinned by SEL190/191. **No speculative issue filed.**
- **(b) `xschem raw non_spice [<type>]` — TAKEN, not declined.** Other column of the same reader-table row as `raw is_digital`, which answers 0 for `table` on purpose (`test_backannotate_digital` BA12, 81/81 green). SEL182 asserts both in one check so the two verbs cannot be merged; SEL185 greps the comment-stripped `results.tcl`, word-bounded after a reviewer showed the first version was a whole-file substring grep.
- **Two spellings of one path are TWO RUNS — a measurement, not a promise.** `w/an.raw` and `w/../w/an.raw` → rc 1, rc 1, two slots; the engine dedupes by `strcmp`. `~` is the only normalisation `select` does; `file normalize` is item 4's Tcl-side call.

## 3. Checks and result

`tests/headless/test_results_select.tcl`, groups **O..AB**, **SEL138..SEL213 = 76 new checks, total 215**. Band measured free at 137; no item-1/2 id renumbered, restated or deleted.

```
PASS     | test_results_select          run 1/5  RESULT: ALL PASS (215 checks)
PASS     | test_raw_read_dispatch       run 2/5  RESULT: ALL PASS (51 checks)
PASS     | test_raw_case_mode           run 3/5  RESULT: ALL PASS (277 checks)
PASS     | test_raw_read_failure_0306   run 4/5  RESULT: ALL PASS (63 checks)
PASS     | test_backannotate_digital    run 5/5  RESULT: ALL PASS (81 checks)
RESULT: 5/5 runs passed
```
`--nogui` arm: `ALL PASS (215 checks)`. Also green: `test_wave_cursor_crossdb` 93, `test_wave_viewer` 400, `test_wave_trace_menu` 397, `test_wave_sigbrowser` 353. Pre-feature drive: pristine binary + the new checks = `35 FAILED (161 passed)`, every red in 138..195; the fixer's 18 against the byte-exact pre-fix `save.c` = `7 FAILED (208 passed)`.

**AUDIT — CLOSER'S OWN RUN, reported as a DIFF.** `GUI_GATE=1 tests/headless/full_audit.sh`, dev display `:99`:
```
SUMMARY: 332 pass  15 fail  0 crash/timeout  0 skip  (total 347)
WIREEDIT: PASS      SCRATCH: 0 leaked dir(s)      TREE: 0 appeared  0 vanished
```
Joined by test NAME and STATUS against `doc/claude/results_batch/baseline_2026-08-19_226302f9.txt` (331/15/0/0 of 346): **0 green→red, 0 red→green across all 346 shared rows, and nothing only in the baseline.** The one extra row is `test_results_select` PASS, which LEDGER.md records as added by item 1. The 15 reds are the baseline's 15, by name.

## 4. Sabotage — every new check has a red

38 drives (21 implementer, the verifier's independent set, 17 fixer), each a real rebuild, restored from a byte-exact backup (`cmp -s`; never `git checkout --`, the item is uncommitted), re-run green. Rows are grouped by drive; **all 76 new ids appear below, so no check is unsabotaged.**

| check id(s) | what was broken | red? | green after restore? |
|---|---|---|---|
| SEL138 | the "no file given" message text | yes | yes |
| SEL139, 157 | a door into the top-level `xschem select` (R114) | yes | yes |
| SEL140, 141, 144, 156 | `raw_select()` return collapsed to `return 2` | yes | yes |
| SEL142 | cursor reset to slot 0 before returning | yes | yes |
| SEL143, 196 | `extra_prev_idx = extra_idx` at the end of `raw_select()` | yes | yes |
| SEL145-148, 160 | select never reads (`what` 1 → 2) | yes | yes |
| SEL149, 159, 166, 167, 188 | `draw.c` `sch_waves_loaded()` stamp compare forced true | yes | yes |
| SEL150, 158, 163, 168, 179, 194, 202 | return collapsed to `return 1` | yes | yes |
| SEL151, 164, 171, 180, 204 | the spice dedupe match disabled (every read appends) | yes | yes |
| SEL152-155, 169 | `RAW_READ_REBIND` dropped from the select call | yes | yes |
| SEL161 | the by-name switch found-branch made off-by-one | yes | yes |
| SEL162 | L10's `if(file && type)` guard relaxed to `if(file)` | yes | yes |
| SEL165, 201, 203, 205 | the dedupe ignores `sim_type`; R301f's typeless arm disabled | yes | yes |
| SEL170 | R301a's sibling re-stamp body deleted | yes | yes |
| SEL172 | the sibling loop's `rawfile` guard deleted (re-binds the whole registry) | yes | yes |
| SEL173, 197 | a refused select returns 2 | yes | yes |
| SEL174-177, 207 | a refused select clears the registry (the F7/L3 forbidden shape) | yes | yes |
| SEL178 | the `raw_read` arm answers 0 and does nothing | yes | yes |
| SEL179 | the base-raw adopt prediction forced to 0 | yes | yes |
| SEL181, 182 | `non_spice` answers `raw_type_is_digital()` instead | yes | yes |
| SEL183 / SEL184 | the no-argument form hardcoded to 0 / to 1 | yes | yes |
| SEL185 | the reader token `table` put back into `src/results.tcl` | yes | yes |
| SEL186, 187, 189, 192 | `new_rawfile()`'s create guard forced false; found branch returns 1; own dedupe disabled | yes | yes |
| SEL190, 191 | **R110d**: `raw_restamp_design()` deleted from `new_rawfile()` | yes | yes |
| SEL193, 195, 199 | `update_op()` added to the `raw read` arm; the `?` sentinel replaced by `0` | yes | yes |
| SEL194 | the select gate removed; and, separately, replaced by the `switch` arm's expression | yes | yes |
| SEL195 | issue 0513's gate FIXED in `raw switch` (this check inverts by design) | yes | yes |
| SEL198 | `raw_select_undo()` dropped from the `!ret` refusal path | yes | yes |
| SEL200 | R301d's publish gate widened, `allpoints == 1` → `>= 1` | yes | yes |
| SEL206, 208, 210 | R301g's `sim_type` comparison inverted; the undo dropped on that path | yes | yes |
| SEL209 | every non-spice select refused, mismatch or not | yes | yes |
| SEL211 | the `raw_read` arm's own `~/` regsub removed (the environment control) | yes | yes |
| SEL212, 213 | R301h's `~/` expansion replaced by a plain copy | yes | yes |

Two checks were caught **weak by sabotage** and strengthened, not hidden: SEL162/163 first ran on a 2-slot registry where "switch to next" and "the file I named" coincide; SEL194's op fixture had to arrive from a multi-point database before the buggy gate could be told from the correct one. Negative drive: appending `_stable_sort`/`$mutable_state` to `results.tcl` reds the OLD SEL185 pattern and leaves the new one green. Harness trap worth recording: `cp -p` restores preserve mtime so `make` skips the rebuild — four drives were re-driven with plain `cp`.

## 5. NOT verified

- **No reviewer finding was left unfixed.** Nine confirmed entries = seven distinct defects (two raised twice); all reproduced on the item binary before any edit. Nothing was raised-but-unconfirmed.
- **Reviewer not-proven items, carried as known and unfixed:** `xschem raw_query select` MUTATES (pre-existing argv[1] aliasing at `scheduler.c:10335`, as `raw_query read`/`clear`/`new` already do); `results::_is_result_type Table` now answers 1 where the old Tcl answered 0 (latent — no slot can carry an uppercase reader token); the two-spellings duplication; `raw select {}` returning 0 rather than the "no file given" error, and extra positional args silently ignored; `save.c`'s `if(type && !type[0]) type = NULL;` is dead, so citing it as the L6 guard is overstated; `developer_info.html`'s `raw what = …` list not updated (already stale for `is_digital`, `casemode`, `vcd_read`).
- **Not run at all:** no installed-tree run; no leak trace (`-d 3 -l log`) around `raw_select()` or the sibling loop; no multi-tab probe (tabs do not share a registry); the VCD half of `raw non_spice` exercised by type token only, never by reading a `.vcd`; R301a's O(slots) sibling loop not timed; the pre-feature drive not re-driven independently.
- **SEL195 pins today's buggy `raw switch` behaviour on purpose** and will invert when 0513 is fixed; its own comment says so.
- **Group AB writes one file under `$HOME`** (`~/.xschem_results_select_<pid>/`) and removes it — `~` can only name `$HOME` and the C `home_dir` comes from `getpwuid`, so it cannot be redirected into `test_scratch`. If the script dies mid-group that dot-directory survives outside the repo, where `full_audit.sh`'s TREE check cannot see it. SEL211 is the control if the two homes ever disagree.
- **No eyeball owed.** The payload is a verb, a return value and a binding, all confirmable headlessly. The only human-visible side effect is R301d — a select of a one-point OP publishes it, so annotation numbers appear — and that is `update_op()`'s existing rendering, unchanged, asserted numerically (`ngspice::get_voltage o1` → `1.5`). Nothing added to `owed.sh`.
