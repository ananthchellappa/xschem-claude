# Batch F item 02 — issue 0305 residuals: one bracket, one epilogue, one sweep name

Branch `fluid-editing`, base `7a592f9c`. Not pushed. Two rounds: implementation, then a fix
round closing all five confirmed review findings. Every ruling is in
`doc/claude/specs/mixed_signal_signal_browser.md` §D1b (and its "fix round" sub-section).

## 1. Files changed
```
 src/draw.c 304 · src/scheduler.c 32 · src/xschem.h 3 · test_node_token_split.tcl 408
 specs/mixed_signal_signal_browser.md 146 · issues/0305-...-node-walkers.md 97
 6 files changed, 928 insertions(+), 62 deletions(-)   NEW: leakprobe_fullyzoom.tcl (76)
```
`draw.c` = the six `node=` walkers + `graph_closest_wave()` + `node_db_prev_restore()`;
`scheduler.c`/`xschem.h` = one read-only `xschem get` branch + prototype. Test file
**91 → 130 checks**, nothing renamed, renumbered or deleted.

## 2. Decisions taken, and the evidence for each
* **(a) RULED — `find_closest_wave()` gets `graph_point_at()`'s two-level bracket, not a swap.**
  Its graph-level `rawfile=` switch was made once per NODE inside the walk and unwound by one
  `extra_rawfile(5,…)`; mode 5 *swaps* `extra_idx`↔`extra_prev_idx` — not a pop — and ran
  whether or not the switch had taken. Now: switch once above the loop behind a `switched` flag,
  restore by absolute index per node and once at the end. Evidence R-A/S2 — reinstating the swap
  reddens NDC1–NDC6: entered on slot 3, one pick on a nested strip left the **session** on the VCD.
* **(b) RULED — one epilogue reached by `goto`; a refusal never hand-copies the cleanup.** Both `return 0`s
  in `graph_fullyzoom()` became `goto fullyzoom_done`. Evidence is a *measurement*: `-d 3 -l log` +
  `src/track_memory.awk`, K=5 vs K=55 in two child processes — **fixed 830/830 (slope 0); the free deleted
  895/1545 (slope 13 B = `strlen("bad;v(wonly)")+1`)**; permanent as NDK0–NDK2, child in the repo.
  **Corrects 0305's addendum twice** (issue, draw.c comment, §D1b): `express` never leaked (scoped in
  `if(!bus_msb)`, freed above both refusals), and the refusals are **not symmetric** — the graph-level one
  is loop-invariant, fires only on iteration 1 where nothing is outstanding, so both the leak and the
  missed `extra_idx` restore belonged to the **per-trace** refusal alone.
* **(c) RULED the same defect class and FIXED here, not deferred.** A `sweep=` list shorter than the
  `node=` list carries the previous entry's token forward, so a 5-column raw's column 4 was subscripted as
  a 3-column VCD's `values[4]`. Not latent: reverting it kills the headless file with `FATAL: signal 11`
  (S4) and SIGSEGVs an on-display probe inside `zoom_full`'s own redraw (S5). All six walkers now keep
  `sweep_name`, re-`get_raw_index()` after the switch, and clamp against the switched-in `nvars`.
* **RULED — a function reachable only from a gesture gets a read-only query verb**: `xschem get
  graph_closest_wave <graph_idx> <px> <py>` → `"<dataset> <node_index>"`, because `find_closest_wave()`'s
  sole caller is `callback.c`'s graph `t` arm — which is exactly why its restore drifted through item 1
  untouched. Fail-soft `-1 -1`; not a stub — S9 (drop its canvas→schematic transform) reddens 4 NDC checks.
* **RULED — the registry cursor is a PAIR; restore both halves, in every walker** (finding 1).
  Nothing restored `extra_prev_idx`, where `raw switch_back` goes: after `raw switch 1; raw switch
  3`, one `graph_closest_wave` / `graph_trace_at` / `wave_hilight_points` / refused `fullyzoom`
  sent `switch_back` to 2 instead of 1. Two of those four are unchanged HEAD code, so **fix the
  family, not just the new verb** — the idiom is user-facing (`xschem.tcl:4743`). New
  `node_db_prev_restore()`, once per walker and *after* `node_db_restore()` (itself a switch,
  which re-clobbers `prev`). Evidence R-F…R-K, R-Q.
* **Two more confirmed findings, fixed:** `dbg(0,"closest dataset=…")` is an unconditional `fprintf` — a
  query verb must not write stderr per call; now `dbg(1,…)`, 25 lines per suite run → 0 (R-M/NDR8). The
  mouse-mirror put-back was watched by nothing; NDC9 watches it through `xschem closest_object` (R-E).

## 3. Tests, check count, verbatim results
`tests/headless/test_node_token_split.tcl` — **130 checks** (was 91), true headless:
```
RESULT: ALL PASS (130 checks)
```
`run_suites.sh --nogui`, `DISPLAY=:0`, `GUI_GATE=1`: `RESULT: 9/9 runs passed` — node_token_split
130, wave_hilight 139, wave_markers 437, wave_crossdb_trace 51, ase_cosim 201, vcd_read 187,
vcd_time_base 124, raw_read_dispatch 51, raw_ascii_point_bounds 90 (identical to item 1). GUI
arm under the live panel: `RESULT: 9/9 runs passed` — wave_viewer 400, wave_modes 488,
wave_trace_menu 397, wave_snap 106, wave_drag_preview 94, wave_axis_zoom 370, wave_legend 77,
graph_box_zoom_xy 10, graph_context. **Closing audit** — `full_audit.sh`, `DISPLAY=:0`, `GUI_GATE=1`, user's
panel live, nothing else running, diffed by test NAME and STATUS both ways against
`doc/claude/batch_F/baseline_status.txt` (exists; shot at `7a592f9c` on the same `:0`):
`SUMMARY: 270 pass 28 fail 1 crash/timeout 7 skip (total 306)` · `WIREEDIT: ALL PASS` (58/58, name for name) · `SCRATCH: 0 leaked dir(s)`; baseline 277/26/0/2/1.
Counts are not the finding — **23 of 364 rows moved and all 23 were re-run individually GREEN**. The X server died mid-run: `test_wave_sigbrowser`
and `test_wave_sigbrowser_i1315` each END with `X connection to :0 broken` verbatim, so those two rows ARE the death. I improvised no display.
GREEN→WORSE (15, every one re-run PASS) — FAIL: test_altf5_ciw, test_deselect_mode, test_graph_context, test_launch_context, test_multi_window,
test_wave_sigbrowser, test_wave_sigbrowser_i1315, test_wave_trace_menu. SKIP (the X-gated self-skip; two needed a second attempt):
test_drag_keeps_selection, test_fluid_backbone_short_vertical_0098, test_fluid_drag_onto_backbone_row_0106, test_fluid_loop_0088,
test_fluid_relay_manhattanize_0107, test_fluid_reversal_0096, test_fluid_sibling_pin_backbone_short_0098. Not one touches a graph rect or the registry.
WORSE→GREEN (8, each re-run PASS; all baseline-side red and unattributable, the baseline binary predating this change): test_ase_persist,
test_ase_plot (TIMEOUT), test_fluid_bodyshove_guards_0132, test_rotate_stretch_dangling_0103 (SKIP), test_wave_axis_zoom, test_wave_crossdb_trace, test_wave_markers, test_wire_vertex_grab. `test_node_token_split` PASSes in the audit; `test_placement_wire_gate` stays TIMEOUT.

## 4. Sabotage table — every one of the 39 new checks has a row; none is unsabotaged
| check(s) | what was broken | red | green on restore |
|---|---|---|---|
| NDF18, NDF19, NDF20, NDC0, NDL0 (premises) | `get graph_rects` made to under-count by one; `graph_plotbox_at()` given `if(i>=4) return 0`; the "absent" per-trace database made to exist on disk; `save.c` `extra_rawfile()`'s index switch forced to slot 0 | yes | yes |
| NDC1 NDC2 NDC3 NDC4 NDC5 NDC6 | **the item's own defect: the graph-level restore back to the mode-5 SWAP** (R-A/S2); NDC3 also fires alone under S1, the per-node `node_db_restore()` deleted | yes | yes |
| NDC7, NDC8, NDC9 | the verb's bad-rect-index refusal made to answer for real; its arity arm's fail-soft `-1 -1` changed to `0 0`; the two mouse-mirror put-back lines deleted (R-E, finding 5's own reproducer) | yes | yes |
| NDL1 NDL2 NDL4 | **the PER-TRACE refusal back to the pre-item `return 0` bypass** (R-B/S3) | yes | yes |
| NDL3 | the GRAPH-LEVEL refusal back to `return 0` (R-C) | yes | yes |
| NDL5, NDW3, NDW1, NDW2 | both `graph_fullyzoom` database restores removed (S16); the `y1`/`y2` `subst_token` pair deleted; an in-range but WRONG sweep column forced after the clamp | yes | yes |
| NDR1, NDR2, NDR3, NDR4 NDR5, NDR6 | `graph_fullyzoom`'s definition moved off column 0 (locator blinded); the per-entry `get_raw_index(sweep_name,…)` re-resolve deleted; the `nvars` clamp deleted (5 of 6 each); either `goto fullyzoom_done` reverted to `return 0`; the label and both gotos renamed | yes | yes |
| NDR7, NDR8 | `node_db_prev_restore()` deleted from any one walker (R-F…R-K); the closest-wave trace back to `dbg(0,…)` (R-M) | yes | yes |
| NDU0, NDU1 NDU2 NDU3 NDU4 NDU5 | `save.c` mode 5 (`switch_back`) forced to slot 0 — the control (R-Q); then `node_db_prev_restore()` deleted from `find_closest_wave`, `graph_point_at`, `wave_hilight_envelope`, `graph_fullyzoom` (R-F/G/H/I) | yes | yes |
| NDK1; NDK0, NDK2 | **the epilogue's `my_free(_ALLOC_ID_,&ntok_copy)` deleted** (R-D, finding 4's own reproducer); then the test's `track_memory.awk` path broken and the leak child made to ignore `ND_LEAK_K` (premise + vacuity guards) | yes | yes |
| NDZ1 (restated 89→128) | `graph_plotbox_at` blinded → `RAN 93 of 116` printed verbatim | yes | yes |

Each sabotage went onto a tree restored from a byte-exact backup, rebuilt, run, restored (`md5sum` clean
after the last). **Two named sabotages were UNCAUGHT and are not evidence:** S10 (the verb's rect-index
range refusal — the `flags&1` guard behind it already answers `-1`) and S13 (`graph_fullyzoom`'s per-entry
restore — needs S12 to be observable). R-P is *deliberately* uncaught: move NDC9's mirror capture after
the queries and the broken build passes 130/130 — the capture position IS the check.

## 5. What was NOT verified
* **Raised, NOT confirmed, no code changed:** `graph_fullxzoom()` resolving `idx = get_raw_index(<first
  sweep token>)` *before* the master-rect `rawfile=` switch. The finding shipped with an **empty
  reproducer**, `graph_master` is mouse state forced to `i` headless so the branch cannot be driven, and
  the function is D2's by the spec's scope note. It stays on 0305's "still not fixed" list.
* **Reviewer not-proven, still not proven:** that `draw_graph()`'s share of (c) is more than structural
  (`NDR2`/`NDR3` count regexp hits; the SIGSEGV probe lives in a scratchpad, not the repo); that
  `find_closest_wave()`'s sweep re-resolve and `nvars` clamp have behavioural cover (its strip carries no
  `sweep=` token — delete both and every behavioural check stays green); that `graph_wave_resolve()`/
  `draw_graph()`'s cursor restores are covered by more than NDR7's call-site count (an emptied helper body
  reddens the NDU checks instead — complementary, neither alone sufficient); that `callback.c`'s `t`/`f`
  arms are driven by anything **in the repo**. **NDR8 is structural** (a process cannot read its own
  stderr, so the 25 → 0 count is here, not in a check); **NDF20's wording is loose** — the refusal fires on
  REGISTRY absence (`autoload=2` is switch-only), not disk absence.
* **Audit noise is unresolved.** The X server aborts on this box every few hours — it died in the baseline
  run and in runs of this item — and repeated audits of nearly the same tree move *different* row sets, so
  any single audit is one noisy sample. `test_wave_axis_zoom`, `test_wave_crossdb_trace` and
  `test_wave_sigbrowser_i12` are flaky in **both** directions (FAIL in the baseline, which predates this
  change) and want their own issue.
* **Noticed, not touched:** `graph_fullyzoom()` never resets `save_npoints` to `-1`, so after the first
  OP→dc-sweep transform every later entry re-applies the first entry's `datasets`/`npoints[0]`;
  `graph_fullxzoom()` never parses `%` at all (D2).
* **No eyeball owed, and none taken:** the payload is engine state — which registry slot is current, where
  `switch_back` goes, whether a refusal frees — not pixels. If a human wants one thing: `t`-key over a
  mixed analog+VCD strip and confirm the current database is undisturbed.
