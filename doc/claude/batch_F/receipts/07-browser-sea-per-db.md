# Batch F item 07 — the browser's sea gets a database dimension (issue 0308)

Branch `fluid-editing`, base `1e5c2b64`. `DISPLAY=:0`, `GUI_GATE=1` throughout; every run through `run_suites.sh`/`gated_xschem.sh`; panel never touched; nothing pushed. Display verified before and after every measurement — `xwininfo -root` → **5120x1440**, `grep -- '+-327'` → nothing (issue 0310's stub never present). **Verdict `[E]`**, see §5.

**The defect.** `browser_reload` snapshotted one database and `browser_id_path` threw the `d:N|` prefix away, so a foreign row was looked up in the *current* inventory. Where two databases share a path — `time` is in every raw and every VCD; `x1` is a subcircuit under SPICE and a module scope under Verilog — that is not an empty pane but **the current run's signals under a foreign node, same count, same caption as the right answer**. Pre-fix `d:1|g:x1` → `{same onlyraw} "2 of 2 signals"`; ruled → `{same onlyvcd}`.

## 1. Files changed

`git diff --numstat` (added / removed), plus this receipt as a new file:

```
 377  38  src/wave_viewer.tcl                              RULING F6 / F6a / F6b
  25  13  src/ase.tcl                                      RULING F1g
 569  51  tests/headless/test_wave_sigbrowser_digital.tcl  FD56-FD69 + 5 restated
  98  11  tests/headless/test_wave_sigbrowser_i14.tcl      BD58d/BD58e, BD70d restated
  10   1  tests/headless/test_ase_cosim.tcl                FV42 leg 3 restated
 204   1  doc/claude/specs/mixed_signal_signal_browser.md  row F6 + the four rulings
 120   1  doc/claude/issues/0308-…lists-nothing.md          CLOSED
  21   0  doc/claude/issues/0309-…without-saying-so.md      reviewed, still open
 (new)   doc/claude/batch_F/receipts/07-browser-sea-per-db.md
```

## 2. Decisions taken, and the evidence

**RULING F6 — the pane resolves a row in the database the row NAMES** (spec `mixed_signal_signal_browser.md`, §F row F6 + section "F6 — the sea has a database dimension"). New pure `browser_id_split {id}` → `{<db> <path>}` is THE decode; `browser_id_path` and `browser_row_db` become its one-line projections, so the database half is an answer rather than litter and two copies of one regexp cannot drift. New `browserseadbent($token)` maps `d:<idx>` → that foreign DB's bar-matched, class-filtered entries, written in the SAME pass as the tree group it describes and emptied at the top of every refresh; `browserseadbid($token)` records the row the pane was DRAWN for. An unknown slot answers **nothing**, never the current DB's entries. *Evidence:* `FD61` (the collision), `FD59`, `FD48`. A second array rather than a wider `browserseaent`, because a dozen readers take that one's `llength` as "signals the pane can draw"; the new trailing `id` arguments are optional, so every pre-F6 call site keeps its meaning by construction.

**RULING F1g — keep RULING F1e's arm, RE-CAUSE its sentence**, taken deliberately against issue 0308's own closing line ("the arm should be DELETED"). The arm's predicate was never about the database — `browser_sea_empty` asks whether the NODE has anything to list, and now asks that of the node's own DB, so it fires exactly on a pure ancestor; only its sentence was. *Evidence:* sabotage **S14** executes 0308's prescription and prices it — 5 checks red (`FD23 FD24 FV41 FV42 FV45`), two procs orphaned.

**RULING F6a — the pane's `Descend to here` walks from the ROW's root** (`browser_sea_root_id`). The first landing made the resolver database-aware and left its one consumer walking from `browser_root_id $rows`, taking the entry from DISABLED to ENABLED-and-wrong: a false *"'m.sub' is not in the Signal Browser tree"* about a row that IS in it, and on colliding names a silent landing on the current DB's namesake. Rejected alternative (err, so the entry disables again): the TREE has descended from foreign rows since item 14, so two entries in one window would disagree. `FD65`, `FD66`.

**RULING F6b — `Send to Add Trace…` carries the row's database** (`atddb($token)` = `{<prefilled name> <registry idx>}`, consumed by `add_trace_ok`, honoured only while the Expression text is byte-for-byte the armed one — the dialog is modeless and meant to be edited). Its sibling `Plot` armed the database and it did not, so one context menu sent two entries to two runs. `FD67`, `FD68`, `FD69` (the trace the product really builds: `{x1.same fd_coll.vcd vcd}` foreign vs `{v(x1.same) {} {}}` current).

**Issue 0308 — FIXED OUTRIGHT and CLOSED**: both halves gone, the foreign non-root scope (`FD48`, restated exactly as the issue prescribed) and the foreign design root (`FD63`, `BD70d`). A commit cannot carry its own hash, so the item lands as one commit and a **one-line follow-up commit writes that SHA into 0308's closing line** — the reviewers' one outstanding bookkeeping finding, discharged rather than forwarded. **Issue 0309 — still OPEN, untouched, NOT worse**, checked as values: `browser_msg`'s `return` count still 11, `browser_show_db_scope`'s three-return tail byte-identical, `browser_names_under`/`browser_node_for` untouched. One line was written and then REMOVED for having no oracle: an explicit `atd_db_take` in `add_trace_dialog` reddened nothing (`SQ`), because `ase::ui::dialog_frame`'s unconditional `catch {destroy $w}` makes `add_trace_forget` the single owner.

## 3. Tests, check counts, verbatim RESULT lines

```
test_wave_sigbrowser_digital  RESULT: ALL PASS (73 checks)     [X arm]
test_wave_sigbrowser_digital  RESULT: ALL PASS (26 checks)     [--nogui arm]
test_wave_sigbrowser_i14      RESULT: ALL PASS (109 checks)
test_ase_cosim                RESULT: ALL PASS (310 checks)
```

Thirteen neighbouring suites also `RESULT: ALL PASS`: `test_wave_viewer` (400), `test_wave_sigsearch` (233), `test_wave_crossdb_trace` (109), `test_wave_sigbrowser` (353), `_sea` (79), `_2pane` (108), `_panes` (81), `_i11` (74), `_i12` (126), `_i1315` (88), `_keys` (49), `test_wave_grid` (399), `test_vcd_read` (187). New checks `FD56`–`FD69`, `BD58d`, `BD58e`; restated `FD19 FD23 FD24 FD25 FD48 BD70d FV42`ℓ3. Nothing renumbered or deleted.

**AUDIT — a DIFF against `doc/claude/batch_F/baseline_status.txt`**, which EXISTS (`7a592f9c`: 277 PASS / 26 FAIL / 0 CRASH / 2 TIMEOUT / 1 SKIP over 306, +58 wireedit). This run, verbatim: `SUMMARY: 281 pass  24 fail  1 crash/timeout  1 skip  (total 307)`; `WIREEDIT: ALL PASS` / `WIREEDIT: PASS`; `SCRATCH:  0 leaked dir(s)`. 307 rows against 306 because item 5 created `test_wave_sigbrowser_digital`. **Twelve rows moved, named in both directions:**

| test | baseline → now | reading |
|---|---|---|
| `test_wave_sigbrowser_digital` | *(absent)* → **PASS** | NEW ROW — item 5 created the file; 73 checks |
| `test_ase_persist` | FAIL → PASS | resolved-noise population |
| `test_ase_plot` | TIMEOUT → PASS | the known P4/P6/P8 WSLg gesture flake |
| `test_fluid_bodyshove_guards_0132` | FAIL → PASS | resolved-noise population |
| `test_wave_axis_zoom` | FAIL → PASS | resolved-noise population |
| `test_wave_crossdb_trace` | FAIL → PASS | the one two-database row of the group; re-ran 109 ALL PASS |
| `test_wave_sigbrowser_i12` | FAIL → PASS | flaky in both directions here; not stable green |
| `test_rotate_stretch_dangling_0103` | SKIP → PASS | WSLg viewable-window wobble |
| `test_rotate_stretch_reconnect_0099` | PASS → SKIP | SIDEWAYS, same wobble; re-run **ALL PASS (21)** |
| `test_wave_tabs` | PASS → FAIL | **X-server death**: its block ends `X connection to :0 broken`, no `RESULT:` line; the gate's `last_revive` stamps 20:15, inside this run. Re-run **ALL PASS (172)**. 0 references to any changed proc |
| `test_wave_trace_menu` | PASS → FAIL | collateral of the same death — it ran next, and its 3 reds are `TL1`/`TL4` legend-band picks answering `-1` (nothing under the point), the signature of a window that never mapped. Re-run **ALL PASS (397)**. 0 references |
| `test_altf5_ciw` | PASS → FAIL | the WSLg raise/key flake this batch already lists as resolved noise. Re-run **ALL PASS**. 0 references |

No red row is attributable: all four green→red/sideways rows were re-run through `run_suites.sh` in one batch, **4/4 passed**, and `grep` for `browser_sea|browserseadb|browser_id_split|atd_db|atddb|browser_row_foreign|browser_sea_root_id` returns **0** in each of the four files. Display re-verified after the audit and after the re-runs: 5120x1440, zero `+-327` windows.

## 4. Sabotage — one row per new check

Each applied ALONE by a patcher that exits 9 unless its anchor occurs exactly once, `diff` against the byte-exact GOOD printed first, `cmp`-verified restored after; 22 in all (S1–S15 at the landing, SC/SJ/SK–SQ at the fix pass). The driver's three: **S1** restore the prefix-stripping, **S2** point the lookup back at the current DB, **S3** collapse the per-DB keying to one map.

| check | what was broken | red? | restored green? |
|---|---|---|---|
| `FD56` | S7/SC `browser_sea_target_path` back to `browser_curtype` | yes (+`FD65`) | yes |
| `FD57` | S2 `browser_sea_ent` always answers the current DB | yes | yes |
| `FD58` | S6 `browser_sea_label` ignores the row | yes, alone | yes |
| `FD59` | S1 `browser_id_split` drops the db half | yes (18 FD) | yes |
| `FD60` | S10 the per-DB map is not emptied at the top of a refresh | yes, alone | yes |
| `FD61` | S2 — **the collision**: foreign `x1` reverts to `{same onlyraw}` | yes | yes |
| `FD62` | S8 the pane's Plot stops arming the row's database | yes, alone | yes |
| `FD63` | S4 `browser_sea_own` ignores the row | yes | yes |
| `FD64` | S11 `browser_forget` stops unsetting the two new arrays | yes, alone | yes |
| `FD65` | SK `browser_sea_root_id`→current root; SL the call site reverted | yes (2) | yes |
| `FD66` | SK/SL — colliding half: the walk succeeds, returns the wrong row | yes | yes |
| `FD67` | SM no arm; SN `add_trace_ok` ignores it; SO the name guard dropped | yes (3) | yes |
| `FD68` | SP `add_trace_forget` stops unsetting `atddb` | yes, alone | yes |
| `FD69` | SM/SN — the real trace reverts to `{v(x1.same) {} {}}`, no spy | yes | yes |
| `BD58d` | SJ (the reviewer's own) per-DB map fed the PRE-class-filter list | yes, alone | yes |
| `BD58e` | S2 (box-ON control; SJ cannot move it — the filter is a no-op there) | yes | yes |
| `FD19` `FD25` `FD48` | S2 / S4 / S3 | yes | yes |
| `FD23` `FD24` `FV42`ℓ3 | S13 F1g's sentence reverts to F1e's wording | yes | yes |
| `BD70d` | S1 and S2 | yes | yes |
| controls `S9`/`S15` | `browser_row_foreign` pinned to "current" / to "foreign" | 10 / 15 red | yes |

**Unsabotaged, therefore NOT evidence:** `FD21` — byte-identical to item 5's expectation, only the node it runs on moved, so it keeps item 5's oracles. `wviewer::forget`'s `unset atddb($token)` cannot be driven red at all (a window destroy always destroys the dialog first); kept as the sweep, carrying `plotdbs`' own caveat verbatim.

## 5. What was NOT verified

* **PIXELS — four eyeballs owed; this is why `[E]`.** (1) Attach a raw and a VCD sharing a scope name, tick All DBs, click the foreign scope then the current one: the panes must list different signals. (2) A foreign DB's design root must list *that* run's top level. (3) Ctrl-Alt-V onto a pure-ancestor scope — the notice should read "…that scope has no signals of its own"; *the open question only an eye can settle:* on the success path there is now NO notice, only `N of N signals` — the right amount of silence? F1g says yes. (4) RMB a foreign pane → `Send to Add Trace…` → OK: the LEGEND must name the VCD's run (`FD69` asserts the trace dict; the legend is pixels). Unaddressed by design: no caption says WHICH database a foreign pane belongs to — the collision yields two panes captioned word-for-word `2 of 2 signals`.
* **Reviewer findings raised but not confirmed: none.** All nine confirmed findings were addressed — seven by code; two ("lowest-index" copied into the spec and the issue, and 0308 lacking a hash) were over-stated and are answered with evidence: `grep -rni lowest` over the spec and the issue returns exactly one hit, inside the §D1 DEFECT 2 write-up where lowest-index IS the rule.
* **Reviewer not-proven, carried forward:** nobody eyeballed the rendered pane; nobody re-ran the full sabotage table (one ran `S2` alone, one a whole-file pre-item A/B); "0309 not worse" was verified by reading, not by running 0309's case; `test_ase_core` PASS→FAIL was seen by one reviewer and shown by a pre-item source swap to be **not attributable** — unchased, the driver should chase it separately; `test_wave_sigbrowser_sea`, `_i12`, `_i1315` and `test_wave_sigsearch` are flaky in BOTH directions here, so their single ALL PASS lines are not stable green; one reviewer saw ONE unreproduced run (just after a WSLg X abort, under load) where a foreign root listed the current DB's names, and failed to reproduce it nine times.
* **Declared limits (in the spec, not defects):** the per-DB map is populated only under All-DBs (a foreign row cannot be in the tree without the box); a foreign PANE is bar-filtered while a foreign TREE is not (item 15's declared asymmetry, unchanged); `browser_sea_empty` re-derives the row from the treeview while the gestures read `browserseadbid`, and no reviewer could construct a disagreement; the TREE's `browser_send_to_add_trace` still hands a bare name onward (a pre-existing §D1 DEFECT 2 gap, not widened into here); `test_wave_crossdb_trace.tcl:685` keeps a half-stale comment rather than drag a clean file into this commit.
* **The audit's green→red set is run-specific on this machine** — three audits of essentially this tree gave three nearly disjoint red sets. Attribute only by NAME + a re-run + a reference count, never by the red count.
