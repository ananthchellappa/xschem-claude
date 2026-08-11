# Batch F item 08 — D2: the joint X domain (`graph_fullxzoom`), pinned as `XD2`

Branch `fluid-editing`, parent `da93e9ba`. The rulings live in `doc/claude/specs/mixed_signal_signal_browser.md` § "D2 — the joint X domain (batch F item 8, 2026-08-10)" — that is the rule; this is the evidence.

## 1. Files changed

```
 src/draw.c                                         486 ++++-----   rewrite + 4 new statics
 tests/headless/test_node_token_split.tcl           412 ++++-       130 -> 168 checks
 doc/claude/specs/mixed_signal_signal_browser.md    174 +++-        D2 row + new D2 section
 tests/headless/test_wave_crossdb_trace.tcl          40 +--         109 checks, XD2 RESTATED
 src/wave_viewer.tcl                                 28 +--         comment block only
 doc/claude/issues/0305-...-node-walkers.md          17 +-          defect 2 closed
 doc/claude/batch_F/receipts/08-d2-joint-x-domain.md (new)          this file
```

`graph_fullxzoom()` was rewritten and **moved below** `node_token_split()`, becoming its **seventh caller** — it was the one `node=` walker that never parsed `%` at all, which is the defect. Four new statics between them: `graph_shares_x()` (THE shared-X membership predicate, extracted — `graph_axis_zoom()` held the second hand-written copy and was moved onto it), `graph_x_extent()` (one contribution; sweep resolved BY NAME per database, clamped against that database's `nvars`), `graph_x_union_add()` / `graph_x_union_rect()`.

## 2. Decisions taken, and the evidence

Five rulings, all written into the spec section named above. No human was asked; nothing was left open.

* **D2-1 — the union, and what contributes:** every `%<rawfile>` a `node=` entry names *and that resolves*, plus the strip's own database *only when a trace actually plots from it*. Evidence both ways — unconditional, the strip is still sized by the registry cursor (the defect); absent, an empty strip gets no window at all (`XD12` red under S3). The strip's own DB is measured *after* the last per-trace switch is unwound (`XD15`; S6c reddens it and little else).
* **D2-1a — a traceless strip contributes NOTHING to a group that has traces.** The review round's confirmed defect: the first cut folded the current DB in unconditionally and `wviewer::add_graph` appends exactly such a strip, so one empty member dragged the cursor's database into the group's union and the group then disagreed. Only a WHOLLY traceless group takes the fallback, on a second pass over the same group. Measured in the real viewer: the same VCD-only strip answered `0..2e-06` beside an empty strip, `0..5e-07` after. `XD16 XD16b XD17`; `XD12` keeps the lone-empty case; `XD19`/`XD19b` separate "no traces" from "traces, none resolvable".
* **D2-1b — a BARE entry follows the registry cursor, and the viewer builds bare entries.** `wviewer::db_suffix` returns `{}` for a trace picked from the current DB, so a production mixed strip is one bare entry + one `%` and **its window does move when the current database changes**. Ruled correct (the bare trace stops being drawn too) rather than patched, and stated out loud because the first cut's eyeball instruction asserted the opposite. `XD22`/`XD22b`.
* **D2-1c — the union is over ONE X quantity: the TARGET rect's `sweep=`.** A confirmed review finding plus its mirror, found while fixing it. Per-member `sweep=` folded an X-Y strip's VOLTAGE range into a locked time strip (`x2=0.65` on a 2 ns strip); column-0 fall-through for a database lacking the named variable folded TIME into a VOLTAGE window. `XD18 XD18b XD18c`.
* **D2-2 — degenerate inputs.** Empty / column-less / dataset-less / all-NaN contributes nothing; a single-sample DB contributes and can only widen (`XD10`); a union degenerate *on its own* is REFUSED and `x1/x2` keep the existing window (`XD11`), because zero width divides every X transform by `gr->gw == 0` — the parent really does answer `{1e-06 1e-06}`. The spec records that the NaN half is load-bearing (`XD21b`) while the empty-DB guards are undefendable (§4).
* **D2-3 / D2-4 — the union is the GROUP's, through one predicate, and what is deliberately not unioned** (`%` counted when it resolves, not when the expression does; `sim_type=` still gates X propagation; interactive pan/zoom not re-based). Detail in the spec. Issue `0305`'s defect 2 is marked FIXED and its "raised, NOT confirmed" item resolved without a reproducer: the column is now resolved once per contributing database, after every switch.

## 3. Tests, check counts, verbatim results

`tests/headless/test_node_token_split.tcl` — **168 checks** (was 130), 38 of them the new `XD` leg, true headless; fixture from the file's own `mkraw`/`mkvcd` plus `mkraw_one`, `mkraw_zero`, `mkraw_nan`; no simulator. `tests/headless/test_wave_crossdb_trace.tcl` — 109 checks, its `XD2` **RESTATED not deleted** (it used to pin the defect; it now asserts the union at viewer level).

```
RESULT: ALL PASS (168 checks)
```

**PARENT CONTROL, re-measured by the closer** (`git show HEAD:src/draw.c` rebuilt, then restored byte-exact md5 `7666d9c1…` and re-run green). The values are the defect: the same mixed strip answers `{0 5e-07}` with the VCD current where the union says `{0 2e-09}`, and `{1e-06 1e-06}` — zero width — with a single-sample raw current. The spec's "Proof" said 17, then 167; it now says 29 of 168 and quotes this line.

```
RESULT: 29 FAILED (139 passed)
```

Suites, `DISPLAY=:0` + `GUI_GATE=1`, panel live. `run_suites.sh --nogui` **9/9**: node_token_split 168, wave_hilight 139, wave_markers 437, wave_crossdb_trace 51, ase_cosim 310, vcd_read 187, vcd_time_base 124, raw_read_dispatch 51, raw_ascii_point_bounds 90. GUI arm **10/10**: wave_viewer 400, wave_modes 488, wave_trace_menu 397, wave_snap 106, wave_drag_preview 94, wave_axis_zoom 370, wave_legend 77, graph_box_zoom_xy 10, graph_context, wave_crossdb_trace 109 — every count identical to item 2's receipt.

**CLOSING AUDIT — a DIFF against `doc/claude/batch_F/baseline_status.txt` (exists, 7a592f9c: 277 PASS / 26 FAIL / 0 CRASH / 2 TIMEOUT / 1 SKIP over 306 + 58 wireedit).** `DISPLAY=:0` verified 5120×1440 with zero `+-327` sentinels; `GUI_GATE=1`; one clean run, nothing else going.

```
SUMMARY: 283 pass  23 fail  1 crash/timeout  0 skip  (total 307)
WIREEDIT: ALL PASS
SCRATCH:  0 leaked dir(s)
```

Joined by NAME and STATUS in both directions (the 58 `test_wireedit_*` baseline rows are
excluded from the join because full_audit collapses them into one line; `WIREEDIT: ALL PASS`
covers them). **14 rows moved.**

* **RED-WARD (4), every one re-ran PASS individually** under `run_suites.sh`, `DISPLAY=:0`,
  `GUI_GATE=1`, `RESULT: 4/4 runs passed`: `test_wave_modes` PASS→FAIL (re-run ALL PASS, 488),
  `test_wave_trace_menu` PASS→FAIL (ALL PASS, 397), `test_wave_sigsearch` PASS→FAIL (ALL PASS,
  233), `test_wave_sigbrowser_i1315` PASS→FAIL (ALL PASS, 191 — the known 6-of-8 flake). Two of
  the four are in this item's own family and both had already run 488/397 green in the GUI arm
  before the audit, i.e. the same binary gives both answers.
* **GREEN-WARD (9), all baseline-side red and unattributable** (the baseline binary predates
  items 1–8): `test_ase_persist` FAIL→PASS, `test_fluid_bodyshove_guards_0132` FAIL→PASS,
  `test_fluid_editing` FAIL→PASS, `test_placement_wire_gate` TIMEOUT→PASS,
  `test_rotate_stretch_dangling_0103` SKIP→PASS, `test_wave_axis_zoom` FAIL→PASS,
  `test_wave_crossdb_trace` FAIL→PASS, `test_wave_markers` FAIL→PASS, `test_wire_vertex_grab`
  FAIL→PASS.
* **NEW ROW (1):** `test_wave_sigbrowser_digital`, absent from the baseline, PASS (item 5's file).
* `test_node_token_split` PASSes in the audit. `test_ase_plot` stays TIMEOUT, as in the baseline.

**No test went red that the baseline does not have red and that did not re-run PASS.**

## 4. Sabotage table

Each patch applied ALONE onto a byte-exact restored tree, rebuilt, run, restored, rebuilt, md5-verified. **Every one of the 38 `XD` checks and all 6 restated checks appears below; none is unsabotaged.**

| sabotage | what was broken | checks that went RED | restored green? |
|---|---|---|---|
| **S1** | **the item's own defect**: per-trace `%` ignored, all sized against the strip's own DB | XD1 XD1b XD2 XD3 XD4 XD5 XD6 XD7 XD8 XD9 XD10 XD11 XD15 XD16 XD16b XD17 XD19 XD19b XD20 XD20b XD21 XD21b XD22 (23) | yes |
| **S2** | **the shared-X agreement**: group loop dropped, rect `i` measures itself | XD6 XD7 XD16b XD19b — **XD5 stays green**, the asymmetry the group rule predicts | yes |
| **S3** | **one contributing database dropped** from the union | XD12 XD15 XD18 XD18b XD18c XD22b | yes |
| **FS1** | confirmed review defect: a traceless strip folds the cursor's DB into the group's union | XD16 XD16b XD17 | yes |
| **FS4** | confirmed review defect: each member measured in its OWN `sweep=` | XD18 XD18b XD18c | yes |
| FS2 | traceless second pass gated on `!got` instead of `!nodes_seen` | XD19b (1 of 168; green before this check existed) | yes |
| FS3 / FS5 | the traceless second pass deleted / the named-sweep-absent refusal deleted | XD12 / XD18c (1 of 168) | yes |
| FS7 / FS11 | `if(v != v) continue;` deleted, NaN into the fold / a BARE entry made to contribute nothing | XD21b (1 of 168) / XD15 XD18 XD18b XD18c XD22b | yes |
| S4 / S6c | the degenerate-union refusal deleted / the per-node `node_db_restore()` deleted | XD11 (1 of 168) / XD15 XD22b | yes |
| S6d / S7 | **all three** database restores deleted / `node_db_prev_restore()` deleted (the cursor is a PAIR) | XD12 XD13 XD15 / NDR7 XD14 | yes |
| S9 / S13 | `graph_shares_x()` forced to "everything shares X" / the min/max fold made last-contributor-wins | XD1b XD8 XD11 XD12 XD15 XD16 XD16b XD18 XD19 XD19b XD20 XD21 XD22 XD22b / XD2 XD5 XD6 XD7 XD10 XD15 XD22 | yes |
| S14 | a **seventh hand-rolled `%` parse** put back — exactly what issue 0305 forbids | NDX1 NDX2 **NDX3** | yes |
| S15 / S5 | the sweep no longer resolved by name / the `nvars` clamp deleted | **NDR2** XD18b XD18c / **NDR3** | yes |
| S16–S22, FFg, FFh | fixture guards: each synthesized database written empty or unreadable, the `raw switch 0` dropped, the "absent" DB pointed at a registered one, the isolating `unlocked` dropped | XD0 XD0b XD0c XD0d XD0e XD0f XD0g XD0h (each alone) | yes |
| FFzero / FFnan | the "zero-point" raw given two real points / the "all-NaN" sweep column given real times | XD20 XD20b / XD21 XD21b | yes |
| count guard / S1 on the GUI arm | one check call removed (it also fired for real when XD19b was added: `RAN 166 of 165`) / the crossdb suite re-run under S1 | **NDZ1** / **crossdb `XD2`**: `1 FAILED (108 passed)` → `ALL PASS (109 checks)` | yes |

**UNCAUGHT, named not hidden.** (a) D2-2's empty-database guards: `FS6`, `FS6b`, `S6e` and all three at once (`FS6d`) each left 168/168 green — structural, not a missing fixture (a zero-sample DB drives a zero-iteration loop and the degenerate refusal catches the rest). `XD20`/`XD20b` pin the BEHAVIOUR, not the guards. (b) The first cut's `S6`/`S6b`: three redundant restore layers, so no single deletion is observable; only `S6d` reddens `XD13`.

## 5. What was NOT verified

* **EYEBALL OWED — this is the verdict.** (1) The reference co-sim strip under `f`: the window must span 0..2 µs, with the VCD square wave drawn across its own 500 ns and then simply ending. (2) Then make the VCD current and press `f` again: **the window MOVES to 0..5e-07 and that is correct** (D2-1b — the bare analog trace stops being drawn too); do not report it as a bug, the first cut's receipt said the opposite. (3) The degenerate refusal leaves the window alone, which looks like a dead key — if that reads badly the fix is a `ciw_echo`, not a zero-width window. The fixer round moved the pixels again, so no earlier look would still cover this.
* **D2-3's "the group is the MASTER's, not rect `i`'s" is verified BY INSPECTION only** — `--nogui` never sets `xctx->graph_master` (MOUSE state), so `master` is forced to `i`; substituting `graph_shares_x(i,k)` leaves the file green. **`graph_axis_zoom()`'s move onto `graph_shares_x()` is read, not driven** (no headless case reaches it; `test_wave_axis_zoom` 370/370 and `test_graph_box_zoom_xy` 10/10 are indirect). **The `f` key branch at `callback.c:2565` is driven by nothing in the repo** — tests and `wviewer::fit` both enter via `xschem setprop rect 2 <n> fullxzoom`, the call `wviewer::regenerate` uses; a reviewer drove the real key once through `xschem callback` and it worked.
* **Raised but NOT confirmed, recorded and not acted on:** within one rect the union blends sweep *quantities* (an AC-frequency DB beside a transient one) — no reproducer, and the parent is no better; `±inf` is not skipped the way NaN is and would give the infinite window the brief warned of — pre-existing, not shown reachable; `graph_x_union_rect()` now calls `extra_rawfile()` for every member's `rawfile=`, which can load databases a `fullxzoom` never used to touch — no wrong answer and no leak observed, but no timing taken.
* **The leak gap is CLOSED**, by two independent differential probes through `src/track_memory.awk` (K=5 vs 200, K=20 vs 400): flat 40–41 unfreed pointers at both ends against a control climbing 61→441. The cost is real though: one `f` on G strips does G² rect walks, no memo, deliberately.
* **Audit noise, fourth demonstration.** This item has now been audited four times by four agents. The four red-ward sets are almost disjoint — implementer: altf5_ciw, cmdmode_descend_0201, rotate_stretch_reconnect, fluid_editing, pristine_untitled_viewer_0172; verifier: deselect_mode, wave_hilight, four fluid/rotate SKIPs; fixer: cmdmode_descend_0201, hover_highlight, wave_modes, wave_snap, wave_hilight, three sigbrowser rows; closer: wave_modes, wave_trace_menu, wave_sigsearch, wave_sigbrowser_i1315 — and every row in all four re-ran PASS. Do not read the count.
