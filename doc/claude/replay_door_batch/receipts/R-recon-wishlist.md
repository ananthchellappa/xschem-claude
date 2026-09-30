# RECEIPT R — wish-list candidate recon (read-only)

**Stage:** R · **Crews:** 6, run in parallel · **Date:** 2026-09-29 · **Tree:** `e05a9769`, branch
`fluid-editing` · **Changed in the tree:** nothing, this was read-only.

## Why this stage exists

The driver's own scouting of `doc/claude/specs/wish_list.txt` had been **wrong three times in two
days**: it called six shipped waveform items unshipped, it claimed Ctrl-A reached `select_all()`
when it toggled a cursor (issue 1617), and it claimed `getprop` had nine arms when it had seven
(issue 1618). So the next target was **measured against the binary and the code** rather than read
off the list. Six candidates, one crew each, every crew told to refute rather than agree.

## The headline

**Old-list item 3's engine is DONE and fenced; its macro surface is ZERO.** `replay_action_log`
round-trips a recorded log byte-identically and is reachable only by typing it into the CIW. That
is what this batch acts on. Four of the six annotations on the user's list are now wrong, and the
crews say which.

## Verdict table

| item | verdict | size | fenceable | list annotation still true? |
|---|---|---|---|---|
| Old-list item 3: "Logging of all user interactions to enable | **PARTIAL** | LARGE | FULLY | **NO** |
| 11. "WV: Context menu to split/combine strips (and log to CI | **PARTIAL** | MEDIUM | FULLY | **NO** |
| 17. WV: Cursor on trace based on current mouse-position, wit | **SHIPPED** | SMALL | MOSTLY | **NO** |
| 2. Wire labels creation in schematic view with Cadence UX. 6 | **PARTIAL** | MEDIUM | FULLY | yes |
| 26. Support similar use model to Cadence's o=car(geGetSelSet | **PARTIAL** | MEDIUM | FULLY | **NO** |
| new-list item 7: "Efficiency coach / key promoter / notifica | **ABSENT** | LARGE | MOSTLY | yes |


==============================================================================

## Old-list item 3: "Logging of all user interactions to enable macros and script creation from log files. WIP - but 25% DONE by Claude Code"

**Verdict:** `PARTIAL` · **Size:** `LARGE` · **Headless-verifiable:** `FULLY` · **List annotation correct:** `False`

### What was measured

MACHINERY, by symbol. Core sink `log_action()` in src/util.c, with siblings `log_action_noecho()`, `log_output()`, `log_action_descend()`, `log_action_stash_select_at()`, `actionlog_suppress_push()/pop()`, `actionlog_name()`. State in src/globals.c: `actionlog_fp`, `actionlog_filename`, `actionlog_cmd_logged` (wrapper-dedup flag), `actionlog_suppress` (depth counter), `actionlog_suppress_echo`, `actionlog_pending`, `select_at_suppress_log`, `select_at_add`. `--logdir` parsed in src/options.c into `cli_opt_logdir`, log opened from src/main.c. Tcl subcommands: `xschem log_action` (scheduler.c, with -noecho/-result/-error/-suppressecho/-suppress push|pop/-reset/-emitted), `xschem set_action_log_cmd`, `xschem set_action_nolog`. Tcl side: `src/ciw.tcl` (`ciw_exec`, `ciw_capture_puts`, `ciw_log_outcome`), `replay_action_log` in src/xschem.tcl, `wviewer::log_action` in src/wave_viewer.tcl.

STRUCTURE = HYBRID: three chokepoints plus ~254 opt-in sites. It is NOT one chokepoint, and it is NOT purely opt-in.

Chokepoint 1, bound input: `dispatch_input_action()` (src/callback.c). Tcl-backed actions log `d->tcl` unconditionally; C-backed ones log ONLY `if(d->log_cmd)`, and log_cmd is pushed from actions.csv's `command` column by the `foreach row $action_table` loop in src/xschem.tcl. Measured on `action_registry[]` (65 entries): 31 Tcl-backed (28 log, 3 nolog) + 34 C-backed (20 have log_cmd, 5 nolog, 9 have no csv command). So 48 of 65 emit at Layer A.
Chokepoint 2, context menu: `context_menu_action()` + `ctxmenu_log_cmd[]` (callback.c) — 22 picks, a COMPLETE classification: 6 replayable commands, 4 `#` markers, 12 NULL (gesture starts -> Layer C, plus abort).
Chokepoint 3, verb boundary: `perform_action()` / `run_core()` / `core_log_action()` (scheduler.c) — one log site for the migrated verbs. `/usr/bin/grep -c 'return perform_action('` = 29, against 323 distinct `strcmp(argv[1], "...")` verbs in scheduler.c. Opt-in per verb.

NOT behind any chokepoint: the legacy `switch (key)` in callback.c, lines 7537-9211 at HEAD, 81 case labels, only 7 log_action lines inside; the rest rely on self-logging cores.

Opt-in site count: 133 non-comment C call sites (actions.c 20, callback.c 29, scheduler.c 50, editprop.c 7, draw.c 7, select.c 6, save.c 5, util.c 7, xinit.c 2) + 121 Tcl `xschem log_action`/`wviewer::log_action` sites (wave_viewer.tcl 36, xschem.tcl 28, library_manager.tcl 21, ciw.tcl 13, action_registry.tcl 8, others).

LIVE BINDING TABLE, from the binary: `xschem bindings dump` -> CHORDS=78, UNIQUE_ACTION_IDS=48. actions.csv: 166 data rows, 163 type=command, 155 with a nonempty command, 39 with nolog set.

REPLAYABLE: YES, and I measured it end to end. Recorded a log headless (`--nogui --pipe -q --logdir`), then `source`d it in a fresh process: "REPLAY-OK", no error, and the replay process's own log came back BYTE-IDENTICAL to the input log — a log-idempotent round trip. `replay_action_log` (src/xschem.tcl) is the safe in-session seam, wrapping `source` in `xschem log_action -suppress push/pop` (a depth counter, so nested composites stay suppressed). 29 suites drive record->replay per verb through it. `tests/headless/test_action_replay.sh` does the two-process record->replay->diff.

BUT ZERO MACRO SURFACE. `/usr/bin/grep -rin macro src/*.c src/*.tcl src/actions.csv` returns only unrelated C-preprocessor and font comments — "macro" does not exist as a feature. `replay_action_log` has NO actions.csv row, no menu entry, no keybinding, no file dialog; it is reachable only by typing it into the CIW. The only user-facing row in actions.csv for this whole feature is `tools.raise_ciw` (Alt+F5, "Raise CIW window").

CONFIRMED GAPS. (a) Selection is unlogged: `/usr/bin/grep -rn "select_all\|unselect_all" src/*.c | grep -i log_action` returns NOTHING, and the Ctrl-A arm of the legacy switch (callback.c case 'a', `rstate == ControlMask`) calls `select_all();` raw — with a `/* select all ... */` comment and no log. Scripted `xschem select_all` also produced no line in my measured log. Selection is the commonest macro prefix, so this is the sharpest gap. (b) Scripted verbs do not log; only interactive paths do. Of 20 verbs driven headless, 9 logged (`set cadsnap`, `trim_wires`, `align`, `rotate`, `flip`, `delete`, `undo`, `redo`, `netlist`) and 11 did not (`load`, `select_all`, `copy_objects`, `unselect_all`, `wire`, `line`, `rect`, `zoom_in`, `zoom_out`, `pan`). `xschem load` logs only on the dialog path (`if(!filename && tcl_braceable(f))` in actions.c). (c) 4 of 22 context-menu picks are non-replayable `#` markers.

INTERACTIVE PATH IS MUCH BETTER THAN THE SCRIPTED ONE. Driving real `xschem callback .drw 2 ...` key events on the dev display :99 produced real replayable lines: `xschem add_wire_label`, `xschem add_symbol_pin`, `xschem undo`, `xschem zoom_full`, `xschem delete`, `xschem set enable_stretch 1`, `xschem netlist -erc`, `xschem save`.

REFUTED, against doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md (dated 2026-07-14, its own "roughly 70% landed" now stale, and it cites bare file:line coordinates that have rotted): its claim "Ctrl-X (cut) and the Delete key ... log nothing" is FALSE — the case 'x' ControlMask arm self-logs `log_action("xschem cut")`, and the Delete key produced `xschem delete` in my measured log. Its "Edit Copy completely silent" is FALSE — the case 'c' ControlMask arm self-logs `log_action("xschem copy")`. Its "File Save silent" is FALSE — Ctrl-S produced `xschem save`. Its claim that wire/rect/line/arc/poly/text property edits emit only a non-replayable `# property-edit` marker is FALSE — `log_prop_edit_one()` in src/editprop.c emits real `xschem setprop <type> ... allprops <p>` lines through `log_action_argv`.

### What is left

Three separable increments, smallest first.

1. SMALLEST USER-VISIBLE INCREMENT — expose replay. The engine is done, safe and fenced; it just has no door. Add one actions.csv row (a `tools.*` command row, menu `tools`, label along the lines of "Replay Action Log...") plus a small Tcl proc that runs a file chooser and calls the existing `replay_action_log $file`. No C change at all. This is what converts the feature from "a diary" into "a macro player", and it is the single highest leverage-per-line step on either wish list. Needs user ratification of the menu wording (see user_visible_surface).

2. CLOSE THE SELECTION GAP — make `select_all()` and `unselect_all()` self-log `xschem select_all` / `xschem unselect_all`, guarded by `actionlog_suppress` like every other core. Currently they are the only wholly unlogged selection primitives, and a macro cannot record "select everything, then act", which is the commonest idiom. Small: two log sites plus the Ctrl-A legacy-switch arm. Red-first is easy here — assert the line's presence in a recorded log before writing it.

3. PROTECT WHAT EXISTS (no user-visible value, but everything above rests on it) — add the `OVERALL: ok ($npass checks)` sentinel to the 29 replay round-trip suites and register them in `hcases`. See fence_situation: they all pass today and are blocked only by the missing sentinel. This is 29 separate epilogue edits because there is no shared helper, and registration itself needs gating.

A fourth, larger item if the goal is literally "all user interactions": migrate the remaining legacy `switch (key)` cases (81 labels) onto the binding table so Layer A covers them structurally instead of by per-case self-log, and continue the `perform_action` migration past 29 of 323 verbs. That is the open-ended half and should not be attempted as one batch.

### The fence

The fence that matters is the `test_perform_action_*` family plus its neighbours, and it is in the issue-1615 trap wholesale.

29 files round-trip a record->replay through `replay_action_log`: all 28 `test_perform_action_*.tcl` that use it, plus `test_actionlog_suppress_gate.tcl` and `test_selflog_grep_guard.tcl` (`ls tests/headless/test_perform_action_*.tcl | wc -l` = 29; `grep -l replay_action_log tests/headless/test_*.tcl | wc -l` = 29). For every one of them I measured reg=0 and sentinel=0. They are NOT in `hcases` or `dcases`, and NONE prints `OVERALL: ok` — each ends with `puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : ...}]` then `exit [expr {$::fails != 0}]`. `banner_complete` in tests/banner_rule.tcl is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` and implements no `RESULT: ALL PASS` spelling, so registering any of them today would gate RED with `OVERALL_ok=0` while all their own checks pass — byte-for-byte the `test_wave_sigbrowser_panes` failure at 809c03d1. Same for `test_action_log_dispatch.tcl`, `test_gesture_end_log.tcl`, `test_ciw.tcl`, `test_ciw_puts_capture.tcl`, `test_action_log_libmgr.tcl`: all reg=0, sentinel=0.

Unlike the wave case there is NO shared epilogue helper to fix once: all 29 define their own inline `proc check` (`grep -lE "^proc check " tests/headless/test_perform_action_*.tcl | wc -l` = 29), so it is 29 edits, not one `wvbs_finish`.

The ONE registered suite is `tests/headless/test_ciw_actionlog_output.tcl` — `hcases` only (run_regression.tcl line 54, `"headless/test_ciw_actionlog_output"`), and it does carry the sentinel (2 occurrences, and its header says 'Prints "OVERALL: ok" on success'). But its scope is issue 0129 only: CIW transcript ordering, the exit/quit pre-eval flush, and `ciw_capture_puts` buffering. It fences NO coverage and NO replay. So action-log coverage and replayability are fenced by NOTHING in the gate.

`tests/headless/test_action_replay.sh` is the only cross-process record->replay->diff proof and it is run by nothing automatic: T1 has zero `.sh` entries (`grep -c '\.sh"' tests/run_regression.tcl` = 0) and `full_audit.sh` globs only `.tcl` (`mapfile -t files < <(ls "$HERE"/test_*.tcl | sort)`).

They do pass today: `timeout 240 tests/headless/run_suites.sh --nogui test_perform_action_rotate` -> `PASS | test_perform_action_rotate run 1/1 RESULT: ALL PASS`. Note that arm reported "ATTACHED to persistent dev display :99" even with `--nogui`, so that run is not a DISPLAY-unset measurement.

### User-visible surface (the user's to ratify)

Increment 1 adds a new menu entry and new user-facing wording: a Tools-menu item to replay an action log, plus a file-chooser dialog title. Both the menu label and its `help` string are new user-visible text and need the user's ratification, and per the repo's UI-copy rule the wording must be terse. There is also a genuine product question inside it that is the user's, not mine: replaying a log mutates the open schematic, so does the entry replay into the current session (what `replay_action_log` does today, using the suppress seam) or into a fresh one. That is one ruling, worth raising on its own.

Increment 2 changes observable behaviour only inside the log file: two new line spellings (`xschem select_all`, `xschem unselect_all`) appear in `Xschem.log` and in the CIW pane where they previously did not. No menu, no keybinding, no dialog. Arguably internal, but it does alter what a user sees scrolling past in the CIW.

Increment 3 has no user-visible surface at all.

### Traps for the implementer

1. THE JULY AUDIT DOC CONTRADICTS THE CODE IN FOUR PLACES. `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` is dated 2026-07-14, still says "roughly 70% landed", and cites bare file:line coordinates that have rotted. Its claims that Ctrl-X, the Delete key, Edit Copy and File Save are silent, and that property edits emit only a `# property-edit` marker, are all FALSE at HEAD — I verified each. Do not cost work off that table.

2. THE "25%" IS BOTH TOO LOW AND TOO HIGH. Too low for machinery (three chokepoints, ~254 sites, a safe replay seam, 29 round-trip suites). Too high for the stated purpose: macros are 0%, because nothing exposes replay to a user. Percentages hide that split, which is why the answer here is a structure.

3. `nolog=1` IS NOT A GAP. 39 of 166 actions.csv rows are nolog, and counting them as unlogged is wrong. Most are gesture STARTS whose effect is logged at the gesture END (`tools.insert_wire`, `insert_line`, `view.zoom_box`, `edit.move_objects`), or dialog-opening rows whose core self-logs the RESOLVED referent afterwards (`file.open` -> `xschem load {<path>}`). nolog frequently means "logged better, elsewhere".

4. ABSENCE OF A LOG LINE IS NOT ABSENCE OF COVERAGE, AND I WALKED INTO THIS. On the GUI arm my fixture load silently failed (`xschem get instances` = 0 with `file exists` = 1), so every selection-dependent probe read "not logged" when in truth nothing was selected to act on. Always assert the EFFECT alongside the log line; a bare "no new log line" result is uninterpretable.

5. SCRIPTED VERB != INTERACTIVE PATH, and the scripted one badly under-reports. Headless `xschem <verb>` logged 9 of 20; the same operations reached through `xschem callback` key events logged real commands. Anyone measuring coverage with a `--script` driver will conclude the feature is far worse than it is.

6. `xschem load <path>` LOGS ONLY ON THE DIALOG PATH, by design — `if(!filename && tcl_braceable(f))` in actions.c. A scripted load is silent deliberately, so replay does not re-open a file dialog. Do not "fix" it.

7. WRONG KEYSYM CASE READS AS A COVERAGE GAP. I probed 'o' (111) and got nothing; the binding is on 'O' (79). Two of my first-pass "misses" were my own keysyms. Take the chords from `xschem bindings dump`, not from memory.

8. THE THREE READERS DISAGREE, AND THE TWO THAT ACCEPT THESE SUITES ARE THE TWO THAT ARE NOT THE GATE. `run_suites.sh` and `full_audit.sh` accept `RESULT: ALL PASS`; `banner_complete` accepts only `OVERALL: ok`. A green `run_suites.sh` run says nothing about whether a suite can be registered. Check the epilogue against `tests/banner_rule.tcl`.

9. THE SENTINEL MUST GO BEFORE THE `RESULT:` LINE. `summarize_all` publishes a case's LAST `RESULT:` line into the verdict, so add `OVERALL: ok ($npass checks)` additively above it — the same ordering the `wvbs_finish` fix used. Also note these suites track `$::fails` and mostly do not track a pass count, so a `($npass checks)` suffix needs a counter added too.

10. REGISTERING ALL 29 IS A BIG GATE MOVE. T1 goes from 107 cases / 106 blocks to roughly 136 / 135, and `wc -l`, `blocks=` and possibly `skips=` all shift. Per CLAUDE.md registering a suite is itself a change that needs gating, and the "skips=8 for thirteen figures" run is a coincidence of what was registered, not a property — do not check the new trailer against 8.

11. `--nogui` VIA `run_suites.sh` STILL ATTACHES TO :99. My one suite run printed "display arm: ATTACHED to persistent dev display :99" under `--nogui`, so it is not a DISPLAY-unset measurement. If DISPLAY-unset behaviour matters (issue 1483 class), measure it separately.

12. DIALOG-OPENING KEYS HANG A HEADLESS PROBE WITH NO UPPER BOUND. My first two key-drive runs stalled on 'q'/'i'/'b'/'t' (modal `vwait`). Put `timeout` on every such run and write results to a FILE with line buffering — under `--pipe` the suite's `puts` never reached my stdout, so a stalled run left me nothing until I switched to a file.


==============================================================================

## 11. "WV: Context menu to split/combine strips (and log to CIW!). And delete/add strip"  +  12. "WV: Context menu on a trace - be able to move to new strip (and log command!)"

**Verdict:** `PARTIAL` · **Size:** `MEDIUM` · **Headless-verifiable:** `FULLY` · **List annotation correct:** `False`

### What was measured

ITEM 12 IS SHIPPED — menu, command, CIW log, fence, and a real-binary pass.

* Menu exists: `wviewer::trace_menu_build` mints `<toplevel>.wvtracemenu` via `wviewer::ctx_menu_widget`. It contains EXACTLY three entries: (0) a disabled header = `wviewer::trace_label` of the picked trace; (1) a separator; (2) command `{Move to Separate Strip}` -> `wviewer::move_trace_to_new_strip $gi $ti $token`. That is the whole inventory.
* Gesture traced end to end: `wviewer::strip_bindings` binds `<ButtonPress-3>` and `<ButtonRelease-3>` to `wviewer::btn3_filter`, which on a zero-travel release (`wviewer::b3_click_tol`) with no modifier (`$s & 13` refusal) and no armed marker calls `wviewer::ctx_menu_post` -> `wviewer::trace_menu_post` (tried first) -> `wviewer::strip_menu_post`. Gate is `wviewer::trace_menu_pick` (trace band via `wviewer::trace_at`, legend band via `wviewer::legend_at`).
* Logged to the CIW: `move_trace_to_new_strip` ends with `wviewer::log_action [list wviewer::move_trace_to_new_strip $from_gi $from_ti $token]`; `wviewer::log_action` is `catch {xschem log_action $line}`; the `log_action` arm in `scheduler.c` appends to the replayable Xschem.log AND mirrors the line to the CIW pane. So "log command!" is met.
* REAL BINARY, run just now: `tests/headless/run_suites.sh --nogui test_wave_trace_menu` -> `PASS | test_wave_trace_menu run 1/1  RESULT: ALL PASS (71 checks)`, exit 0. (71 only, because the TG*/TR* legs self-skip headless: `SKIPPED: TG* GUI legs (no DISPLAY)`.)
* Fenced by `tests/headless/test_wave_trace_menu.tcl` rows TG8 (asserts entry 0 label+state, entry 1 is a separator, entry 2 label is `Move to Separate Strip`, entry 2 `-command` is the fully-resolved `wviewer::move_trace_to_new_strip $mgi $mti $tok`, then `$m invoke 2` and checks a strip was added and the trace is alone in it), TG9/TG10/TG11 (real `<ButtonPress-3>`/`<ButtonRelease-3>` events with `tk_popup` renamed to a spy), TR1-TR5.

ITEM 11 IS ROUGHLY 1 OF 4 — the strip menu exists with ONE entry, and of the four named operations one is fully there, one is a logging one-liner away, one exists as a command but is not on any menu, and one does not exist at all.

* Strip context menu exists: `wviewer::strip_menu_build` mints `<toplevel>.wvstripmenu`, EXACTLY three entries: (0) disabled header `"Strip [expr {$gi+1}] — $nc traces"`; (1) separator; (2) command `{Split Strip}` -> `wviewer::split_strip $gi $token`. Gate `wviewer::strip_menu_pick` (inside a strip, inside `plotbox_at`, >= 2 drawn traces, and NO trace under the pointer so it partitions against the trace menu).
* SPLIT — PRESENT and LOGGED. `wviewer::split_strip` (logs `[list wviewer::split_strip $gi $token]`), `wviewer::split_target_strip` behind menubar Graph > `{Split Strip}`, pure core `wviewer::plan_split` / `wviewer::split_graph_in_graphs` / `wviewer::target_after_split`. Semantics: one strip per DRAWN trace, node 0 keeps the original strip — not a two-way split.
* COMBINE — ABSENT AT EVERY LEVEL. `/usr/bin/grep -niE 'combine|merge|unsplit|join strip'` over `src/wave_viewer.tcl` returns only `dict merge`, `rawhist_merge`, `wave_hilight_merge` and two "coalesce a resize storm" comments. Nothing in `doc/claude/specs/` or `doc/claude/issues/` either. No proc, no menu label, no spec paragraph, no issue file.
* DELETE STRIP — the COMMAND exists and logs, but is on NO context menu. `wviewer::delete_items {graphs pairs {markers {}} {token {}}}` takes a list of strip indices as its first argument and ends with `wviewer::log_action [list wviewer::delete_items $delg $dpairs $delm $token]`. Its only GUI route is menubar Graph > `{Delete...}` -> `wviewer::delete_dialog` -> `wviewer::delete_ok`, which maps listbox rows tagged `graph` into `delg`. `wviewer::delete_empty_strips` (menubar `{Delete Empty Strips}`, bare `e`) deletes only EMPTY strips and logs.
* ADD STRIP — the COMMAND exists but is NOT LOGGED. `wviewer::add_graph $token` (menubar Graph > `{Add Graph}`) does capture -> `lappend gs [wviewer::empty_graph]` -> `set_graphs` -> `regenerate` -> `return 1`, with NO `log_action` call and NO `push_undo`. Verified mechanically: `awk '/^proc wviewer::add_graph /,/^}/' src/wave_viewer.tcl | /usr/bin/grep -c log_action` -> **0**. It has no keybinding and is on no context menu. So today it violates item 11's "log to CIW!".
* For completeness, the 24 `log_action` call sites in `src/wave_viewer.tcl` are: `set_plot_mode`, `set_plot_dest`, `set_target_strip`, `move_strip`, `move_trace`, `move_traces`, `move_trace_to_new_strip`, `split_strip`, undo/redo (`wviewer::$dir`), `clear_all`, `grid_toggle`, `rawbar_load`, `browser_toggle`, `delete_all_markers`, `delete_empty_strips`, `delete_items`, `set_wave_hilights`, `net_hilight_style_index_for`, `set_case_mode`, `select_tab`, `new_tab`, `close_tab`, `paste_payload`, `close`, plus the `wvdiag` diagnostic lines. `add_graph` and `add_trace` are the notable absentees.

THE FIVE OPERATIONS, BY SYMBOL:
1. add strip — `wviewer::add_graph` PRESENT, unlogged, no menu entry beyond the menubar.
2. delete strip — `wviewer::delete_items` (arbitrary strips) + `wviewer::remove_graphs` (pure) + `wviewer::delete_empty_strips` (empties only) PRESENT and logged; dialog-only GUI route.
3. split a strip — `wviewer::split_strip` / `wviewer::split_target_strip` / `wviewer::plan_split` / `wviewer::split_graph_in_graphs` PRESENT, logged, already on the strip context menu.
4. combine strips — ABSENT. Composable from `wviewer::move_traces` + `wviewer::remove_graphs`/`delete_empty_strips`, but no such proc exists.
5. move a trace to another strip — PRESENT three ways: `wviewer::move_trace` (to a named existing strip, logged), `wviewer::move_traces` (a set, logged), `wviewer::move_trace_to_new_strip` (logged, the one on the menu). Also LMB drag: `wviewer::trace_drag_arm` -> `trace_drag_motion` -> `trace_drag_drop` -> `move_traces`, with `wviewer::reuse_strip_for_trace_move` and `wviewer::movable_pairs`.

ANSWER TO THE DRIVER'S QUESTION: this is overwhelmingly "A MENU OVER EXISTING COMMANDS" (cheap) — with exactly ONE genuinely new command, Combine, and one one-line logging repair, `add_graph`.

### What is left

Item 12: nothing required. Optional enrichment only — add a `{Move to Strip}` cascade to `wviewer::trace_menu_build` (using `wviewer::ctx_menu_child`, the same submenu helper `browser_menu_build` already uses for its `{Plot to}` cascade) whose entries call the existing logged `wviewer::move_trace $gi $ti $to_gi $token`. That would expose the one thing the menu cannot do today: move to an EXISTING strip rather than a new one. Currently only LMB drag reaches that.

Item 11, four pieces:

(a) `add_graph` logging — one line. Add `wviewer::log_action [list wviewer::add_graph $token]` before the `return 1` in `wviewer::add_graph`. Decide at the same time whether it should also `push_undo` (every other mutation in this namespace does; `add_graph`'s own comment at the `reuse_strip_for_trace_move` site says it "takes neither an undo point" and that is currently true). Red-first row: spy `xschem log_action` and assert one line after `add_graph`.

(b) Strip context menu gains `{Delete Strip}` -> `wviewer::delete_items [list $gi] {} {} $token` — pure wiring over a command that already validates, remaps the target, remaps wave highlights, pushes undo and logs. Needs the `strip_menu_pick` gate widened: it currently refuses any strip with < 2 drawn traces (correct for Split, wrong for Delete/Add), so either the gate splits into a "can split" test and a "menu at all" test, or the entry is added `-state disabled`. This is the single most subtle bit of the whole job.

(c) Strip context menu gains `{Add Strip}` -> `wviewer::add_graph $token`, subject to the same gate widening. Note `add_graph` appends at the END; if the user expects "insert below this strip" there is no such proc — the composition is `linsert` + `set_graphs`, which `move_trace_to_new_strip` already does inline (`set gs [linsert $gs $at [wviewer::empty_graph]]`) and which would be worth lifting into a `wviewer::insert_graph {token at}` sibling.

(d) COMBINE — the only real new code. A `wviewer::combine_strips {gi_a gi_b {token {}}}` (or `combine_with_below`) following the house pattern exactly as `split_strip` does: resolve token, validate indices loudly via `ciw_echo`, `switch_ctx`, `capture_live_graph_state`, `push_undo`, re-read `graphs`, build the pair list from the source strip's traces, `wviewer::move_traces_in_graphs` into the destination, then `wviewer::remove_graphs` the now-empty source, remap the target through `wviewer::index_after_removal`, remap highlights through a new `wviewer::wavehl_after_strip_removal` call, sweep markers via `wviewer::markers_sweep_numbers`, `regenerate`, `log_action`. A pure `wviewer::combine_in_graphs` core first, as every sibling has one. Y-range reconciliation is the open design question: strip A and strip B have independent Y ranges (spec: "X is shared, Y is per-strip"), so combining must decide union / destination-wins / re-auto.

(e) Test-harness work that must land with it: add `puts "OVERALL: ok ($npass checks)"` immediately BEFORE the `RESULT:` line in the epilogues of both `tests/headless/test_wave_split_strip.tcl` and `tests/headless/test_wave_trace_menu.tcl`, then register both in `dcases` in `tests/run_regression.tcl`, and gate that registration.

### The fence

The two suites that would carry the fence EXIST, are RICH, and are BOTH INVISIBLE TO THE GATE — and one of the two reasons is the exact structural defect issue 1615 fixed for the `wvbs_*` family.

WHICH SUITES: `tests/headless/test_wave_split_strip.tcl` (SG* block) for item 11's strip menu, and `tests/headless/test_wave_trace_menu.tcl` (TG*/TR* blocks) for item 12's trace menu. Both already assert the menus ENTRY BY ENTRY — SG9 pins `{Strip 1 — 3 traces}`/separator/`{Split Strip}` plus the resolved `-command` string, TG8 pins the header/separator/`{Move to Separate Strip}` plus its resolved `-command` — so ADDING ANY ENTRY REDDENS THEM IMMEDIATELY. That is a free, mechanical red-first for every new menu item, and it is the best news in this report.

NOT REGISTERED: `/usr/bin/grep -c 'test_wave_split_strip' tests/run_regression.tcl` -> **0**; same for `test_wave_trace_menu` -> **0**. Neither name appears anywhere in the driver. The only `test_wave_*` entries in `tests/run_regression.tcl` are `"headless/test_wave_sigbrowser_panes"` and `"headless/test_wave_viewer"`, both in `dcases` ALONE. So today items 11 and 12's menus are fenced by suites that gate nothing — they are in the 334-of-418 tail, reachable only by `full_audit.sh` or a hand-run.

AND NOT REGISTERABLE AS THEY STAND: `/usr/bin/grep -c OVERALL` -> **0** in each file. `banner_complete` in `tests/banner_rule.tcl` is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` and is the only reader `run_regression.tcl` sources. Each suite rolls its OWN epilogue printing only `RESULT: ALL PASS ($npass checks)` / `RESULT: $fail FAILED (...)`. Worse, each carries a comment that names the WRONG readers as authoritative: split_strip's says *"run_suites.sh classifies on the literal string `ALL PASS` in the last RESULT line"* and trace_menu's says *"run_suites.sh (and full_audit.sh) classify a run by grepping the last RESULT line for `ALL PASS`"* — i.e. the two readers that are NOT the gate. Register either one as-is and T1 goes red with `HARNESS: ... did not complete cleanly (exit=0, OVERALL_ok=0, died=0)` on the line above its own `RESULT: ALL PASS`, which is precisely what happened at `809c03d1`.

THE FIX, and the shape it must take: add `puts "OVERALL: ok ($npass checks)"` ADDITIVELY, BEFORE the `RESULT:` line (RESULT must stay last, because `summarize_all` publishes a case's LAST `RESULT:` line). Then register in **`dcases` ALONE** — the menu rows need a mapped canvas and self-skip under `--nogui` with `SKIPPED: TG* GUI legs (no DISPLAY)` / `SKIPPED: SG* GUI legs (no DISPLAY)`. Cost: +1 case each, +0 `skip:` lines (uppercase `SKIPPED:` is not a counted or skip-counted shape, and a `dcases`-only entry's headless arm never runs at all) — the same two reasons `test_wave_viewer` costs no skip. From the current `107/106/counted_failures=0/skips=8`, registering both should give `109/108/0/8`. And registering is itself a change that needs its own gate.

REAL-BINARY EVIDENCE OBTAINED: `timeout 240 tests/headless/run_suites.sh --nogui test_wave_trace_menu` -> `PASS | test_wave_trace_menu run 1/1  RESULT: ALL PASS (71 checks)`, `RESULT: 1/1 runs passed`, exit 0. The harness reported `display arm: ATTACHED to persistent dev display :99` and a throwaway HOME. I did not run `test_wave_split_strip` (one-suite budget).

### User-visible surface (the user's to ratify)

Item 12: none. It ships as-is; the optional `{Move to Strip}` cascade would add new wording.

Item 11 puts four things in front of the user, and only the first is a real ruling:

1. WHAT "COMBINE" MEANS — this is the one genuine decision and the wish list does not make it. "Context menu to split/combine strips" on a per-strip menu has no second operand. Candidates: `{Combine with Strip Below}` (a one-click inverse of Split, needs no selection, my recommendation), or a `{Combine into Strip}` cascade listing every other strip (symmetric with `{Move to Strip}`), or "combine the SELECTED strips" (there is no strip multi-selection today — `wviewer::selection_pairs` selects TRACES, not strips, so this option would require building strip selection first). Note the wish list says "split/combine" as a pair, which argues for the one-click inverse.
2. Y-RANGE RECONCILIATION ON COMBINE — union of both, destination-wins, or re-auto. The user will SEE this as "my waveform got squashed" if it is wrong, and the spec's own "X is shared, Y is per-strip" (issue 0150) makes it a real choice rather than an implementation detail.
3. MENU WORDING for the new entries — `{Delete Strip}`, `{Add Strip}`, `{Combine with Strip Below}`, `{Move to Strip}`. Terse, and the house style already sentence-cases these (`{Split Strip}`, `{Delete Empty Strips}`, `{Add Graph}`). ⚠ NAMING INCONSISTENCY ALREADY SHIPPED that a new entry will either inherit or expose: the MENUBAR says "Graph" (`{Add Graph}`, and the menu itself is `Graph`), while every context menu, command name and status message says "Strip" (`{Split Strip}`, `Strip 1 — 3 traces`, `split_strip`, `move_trace_to_new_strip`, `delete_empty_strips`). If a context-menu `{Add Strip}` sits three pixels from a menubar `{Add Graph}` doing the identical thing, that is a user-visible wording question worth one sentence to the user.
4. DOES DELETING A NON-EMPTY STRIP CONFIRM? `wviewer::delete_items` today is reached only through a dialog where the user has explicitly selected rows and pressed OK. A one-click `{Delete Strip}` on a context menu destroys traces with no confirmation. Undo covers it (`push_undo` is in `delete_items`), so my own inclination is no dialog — but it is a behaviour the user experiences.

Per the one-ruling-at-a-time rule these are ONE conversation (item 1, what combine means), not a four-item list; 2-4 follow from it and 2 can be decided by me if the user does not care. The user cannot look at pixels right now, but none of these four needs eyes — they are all answerable in words.

### Traps for the implementer

1. ⚠ THE WISH-LIST ANNOTATION IS SILENT ON BOTH ITEMS AND THAT SILENCE IS WRONG FOR 12. Items 11 and 12 carry no "DONE!" marker, unlike items 1/3/8. Item 12 is shipped end to end — menu, command, CIW log, entry-by-entry fence, real-binary pass at 71 checks. A driver reading the blank as "nothing exists" will re-implement a working feature. Item 11's blank is roughly right but understates it: split-by-right-click already ships and logs.

2. ⚠ THE SPEC CONTRADICTS THE CODE IN AT LEAST ONE PLACE I FOUND. `doc/claude/specs/waveform_viewer.md` says a pixel band "is deliberately reserved for FUTURE LMB trace-to-strip dragging" — that future arrived: `wviewer::trace_drag_arm` / `trace_drag_motion` / `trace_drag_drop` exist and commit through `wviewer::move_traces`. Do not read that spec's future tense as present state. The spec also has no "combine" paragraph at all, which in this case does match the code (nothing exists) — but that is luck, not reliability.

3. ⚠ `strip_menu_pick` REFUSES ANY STRIP WITH FEWER THAN TWO DRAWN TRACES. That is correct for Split (a one-trace strip is already split, mirroring `split_strip`'s own `node_count < 2` refusal) and WRONG for Delete Strip and Add Strip, which are meaningful on a one-trace or empty strip. So `{Delete Strip}` naively added to `strip_menu_build` will be UNREACHABLE on exactly the strips a user most wants to delete, and no existing row will catch it because SG9 builds the menu on a 3-trace strip. Either split the gate into "should a menu post here" and "can this strip split", or add the entries with `-state disabled` driven by `node_count`. Add a row that posts the menu on a ONE-TRACE strip.

4. ⚠ THE TWO CONTEXT MENUS PARTITION THE STRIP BODY BY TWO DIFFERENT MECHANISMS, and `ctx_menu_post`'s ordering is NOT what separates them. In the plot body, `strip_menu_pick` asks `trace_at` itself and refuses any pixel the trace gate accepts. Over the LEGEND band, the trace gate accepts via `legend_at` and the strip gate cannot compete because it requires `plotbox_at`. The shipped comment says reversing the two lines in `ctx_menu_post` leaves the suite GREEN (probe-verified by whoever wrote it) — so that ordering is a second line of defence, and row SG8 is what actually pins the partition. Widening either gate for the new entries must be re-checked against BOTH mechanisms, and SG8 is the row to extend.

5. ⚠ ON A DIGITAL OR BUS STRIP THE STRIP MENU OWNS THE WHOLE BODY. `graph_wave_at` in `src/draw.c` returns -1 everywhere on a band/ribbon rendering, so `trace_at` never hits and the trace menu NEVER FIRES on such a strip. Item 12's "move this trace to a new strip" is therefore already unreachable by right-click on a digital strip — and any new trace-menu entry inherits that. The shipped comment calls this "landmine 33 working FOR us" because Split is meaningful there; it works AGAINST any trace-level entry.

6. ⚠ `btn3_filter` SWALLOWS THE PRESS ONLY ON A LEGEND HIT, and the comment spells out why widening that swallow is dangerous: outside a legend hit the C GRAPHPAN latch fires, `mx/my_double_save` is written, and a still-forwarded release would commit a box zoom. Do not touch that swallow while adding menu entries.

7. ⚠ THE MENUS ARE REBUILT ON EVERY POST, ON PURPOSE. `ctx_menu_widget` `destroy`s the path first because Tk's `menu` command ERRORS on an existing path — without the destroy the SECOND post returns {} for ever. Every `-command` closes over THIS click's indices. A cached menu would move the wrong trace or delete the wrong strip. Keep the rebuild.

8. ⚠ TARGET-INDEX AND HIGHLIGHT REMAPPING ORDER IS A DOCUMENTED FOOT-GUN THAT HAS ALREADY BITTEN TWICE. `delete_empty_strips`'s own comment records that it had the target read on the wrong side of the mutation until issue 0176, because `target_index` clamps against the LIVE strip count and reading it after `set_graphs` shrinks it TWICE. Conversely `move_trace_to_new_strip` must call `wavehl_remap_apply` AFTER `set_graphs` because that command GROWS the list. So: read the target BEFORE the mutation; apply the highlight remap AFTER it when the strip count grows, BEFORE when it shrinks. Combine does BOTH (destination grows in traces, list shrinks in strips) — this is where a Combine implementation will go wrong.

9. ⚠ `add_graph` TAKES NO UNDO POINT AND NO LOG LINE, and one shipped comment in `reuse_strip_for_trace_move` states that as a reason NOT to call it from a gesture path. If you add `log_action` and `push_undo` to it, re-read that comment's reasoning and check every caller — the comment may become false.

10. ⚠ THE FENCE SUITES' OWN COMMENTS NAME THE WRONG AUTHORITY. Both epilogues assert that `run_suites.sh` / `full_audit.sh` classification is what matters. Those are the two readers that are NOT the gate. Believe `banner_complete` in `tests/banner_rule.tcl`, not the comment in the suite you are editing. Same defect family as issues 0420/0456/0492/0629/0689.

11. Minor: `run_suites.sh --nogui` still prints `display arm: ATTACHED to persistent dev display :99`. That line describes the arm the harness selected, not whether xschem got a display — `--nogui` still means `has_x == 0` and the GUI legs still self-skip. Do not read it as "the GUI rows ran".


==============================================================================

## 17. WV: Cursor on trace based on current mouse-position, with x,y (not mouse coords, trace x,y) reported on status bar

**Verdict:** `SHIPPED` · **Size:** `SMALL` · **Headless-verifiable:** `MOSTLY` · **List annotation correct:** `False`

### What was measured

I traced the whole path end to end by symbol and then ran the suite. This item is "viewer plan item 9" (the snap cursor) + "item 10" (the status bar) in this tree, landed at `56edb7ec` and `ab1dcb47`, hardened at `12bc3fef` (issue 0193).

THE MOTION HANDLER AND THE SNAP. `handle_motion_notify()` (src/callback.c) -> when `waves_selected()` is true it calls `waves_callback()` and then, on `MotionNotify` only, `draw_graph_snap_cursor(mx, my)` (src/draw.c). Leaving every graph calls `graph_snap_clear()`.

IT IS TRACE COORDS, NOT MOUSE COORDS -- this is the distinction the user drew, and the code is explicit about it. `draw_graph_snap_cursor()` gates on `graph_plotbox_at(i, mx, my)` then calls `graph_point_at(i, mx, my, 1e30, -1, -1, &h)`, ranking strips by `h.dist`. It then stores:
  xctx->graph_snap_x = hit.seg_x;   /* RAW -- landmine 35 */
  xctx->graph_snap_y = hit.seg_y;
`seg_x`/`seg_y` are documented in `GraphPointHit` (src/xschem.h) as "the foot of the perpendicular from the query pixel onto the winning segment ... UNSCALED values at that point (interpolated)". `graph_point_at()` computes them as `best.seg_x = GS_X(nd_ex); best.seg_y = GS_Y(nd_ey);` with `pow(10.0, ...)` undoing `mylog10()` on log axes. So the published x,y is the point ON THE TRACE, interpolated along the polyline segment under the pointer -- not the sample, and not the mouse.

THE STATUS-BAR WRITE. `scheduler.c` publishes it: `xschem get graph_snap` -> `"%d %d %.10g %.10g"` = gi, wave, x, y (empty string when `!xctx->graph_snap_on`). On the Tcl side `wviewer::open` (src/wave_viewer.tcl) builds `frame $top.wvstatus` + `label $top.wvstatus.l`, packs it `-side bottom -fill x -before $top.drw`, and binds `bind $wp <Motion> "+[list wviewer::status_refresh $token]"` (appended to the KEPT generic <Motion>). `wviewer::status_refresh` reads `xschem get graph_snap`, takes `lindex 2`/`lindex 3`, and calls the pure `wviewer::status_text {mode x y}`, which returns e.g. `Plot: single    x: 1.5u    y: 900m` via `ase::format_value`.

ARMING IS AUTOMATIC IN THE VIEWER. `xctx->graph_snap` defaults 0 (per-context, the `no_grid` precedent), and `wviewer::open` does `catch {xschem set graph_snap_cursor 1}` -- so every ASE-L waveform window has it on without the user doing anything.

THE A/B CURSOR "y at a given x" MACHINERY EXISTS SEPARATELY, and item 10 deliberately does NOT use it: `wviewer::trace_cursor_value` -> `wviewer::interp_value` (which drives `xschem raw pos_at` / `xschem raw value`), feeding `wviewer::readout_refresh` and the `$top.wvreadout.a/.b` lines. That is the cursor readout bar (Cursors > Readout, `wviewer::readout_show`). The hover item reuses `graph_point_at`, not `interp_value` -- the spec says so in as many words: "Item 10 does not compute the position. It consumes item 9's published contract."

THE NEAREST-TRACE HIT-TEST EXISTS AND PREDATES THIS. `graph_point_at()` is the ranked pick (point-to-SEGMENT distance in `seg_dist`); `graph_wave_at(i, mx, my, GRAPH_TRACE_PICK_TOL)` (10 screen px) is the selection-side hit test callback.c uses for trace picking. The hover snap deliberately bypasses the tolerance (`1e30`) because the gate is the plot box.

SUITE RUN (the only thing I executed): `timeout 240 tests/headless/run_suites.sh --nogui test_wave_snap` ->
  `PASS     | test_wave_snap               run 1/1  RESULT: ALL PASS (64 checks)`
So the fence is green today. It contains exactly the rows this item needs: SP1-SP5 (per-context arming round-trip), SQ1-SQ3 (the getter contract), ST1-ST8 (the pure `status_text` formatting, incl. "ST8 the label is 'Plot:', never 'MODE:'"), and on the DISPLAY arm SG3 ("the pick names graph 0", "y is the RAW sample value (vv = 2*vsweep), not log-mapped"), SG6 (the box gate covers >40% of a vertical sweep, not a thin proximity band), SG7 (outside the plot box there is no snap), ST20 ("the viewer built its own status bar", "the editor status bar is hidden in this window"), ST21 ("the bar shows the plot mode" / "...and the snapped x/y"), ST22 (mode push).

REFUTING THE "probably unshipped" prior: the spec even records a real-session user complaint against this exact feature and its fix -- "the mouse pointer needs to be too close to the trace" -> `graph_plotbox_at` became the gate (issue 0188/0193 family). The user has already used it.

### What is left

The FEATURE is done. What is left is fence registration plus one optional increment.

(1) REGISTRATION, and it is blocked by the issue-1615 defect, not by an oversight. `tests/headless/test_wave_snap.tcl` is in NEITHER `hcases` nor `dcases` (`/usr/bin/grep -c 'headless/test_wave_snap"' tests/run_regression.tcl` = 0), so nothing gates this item. And it cannot simply be added: the suite's epilogue prints only
    puts "RESULT: ALL PASS ($npass checks)"
and ZERO `OVERALL` lines (measured: `grep -c OVERALL` on its output = 0; the registered `test_wave_viewer.tcl` has 3). `banner_complete` in tests/banner_rule.tcl is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` and is the only reader `run_regression.tcl` consults, so registering it as-is gates RED with `HARNESS: test_wave_snap did not complete cleanly (exit=0, OVERALL_ok=0, died=0)` while all 64 of its own checks pass -- precisely what happened to `test_wave_sigbrowser_panes` at `809c03d1`. Fix: add `puts "OVERALL: ok ($npass checks)"` ADDITIVELY before the `RESULT:` line (keep `RESULT:` last, because `summarize_all` publishes a case's last `RESULT:` line), then register in BOTH `hcases` and `dcases` -- `dcases` is the one that matters, since SG*/ST20-ST22 are the display-only end-to-end rows and the `--nogui` arm self-skips them with an uppercase `SKIPPED:` (uncounted, costs no `skip:`). Expect the T1 figures to move from 107/106 to 109/108 with `skips=8` unchanged.

(2) OPTIONAL INCREMENT -- the trace NAME is published but thrown away. `xschem get graph_snap` returns four fields, `"gi wave x y"`, and `wviewer::status_refresh` uses only `lindex 2`/`lindex 3`; `wviewer::status_text {mode x y}` has no parameter for the node. So the bar says `Plot: single    x: 1.5u    y: 900m` without saying WHICH trace the cursor is on. With overlapping traces in one strip that is ambiguous, and Cadence names the signal. The data is already in hand (`hit.wave`, the `hilight_wave`/`graph_trace_at` index space); this is a `status_text` signature change plus a wave-index -> display-name lookup. That IS new user-facing wording, so it needs the user's ratification before it lands.

(3) KNOWN SCOPE LIMIT, probably correct as-is: `graph_point_at()` opens with `if(gr->digital) return 0;` (and `graph_plotbox_at` has the same refusal), so there is no hover snap and no x/y readout on a DIGITAL strip. Worth a sentence to the user only if they want it there.

### The fence

The suite that would carry it is `tests/headless/test_wave_snap.tcl`. It EXISTS and is comprehensive (64 checks on the `--nogui` arm plus the SG*/ST2x display legs), and it PASSES today.

It is NOT REGISTERED: zero hits for `headless/test_wave_snap"` in `tests/run_regression.tcl`, in either `hcases` or `dcases`. The only registered wave suites are `headless/test_wave_viewer` and `headless/test_wave_sigbrowser_panes` (both in hcases AND dcases), and `test_wave_viewer` touches this item only in a prose comment -- its sole occurrence of the string `graph_snap_cursor` is inside the X1-X9 header explaining issue 0187's per-context brands. `test_wave_markers` and `test_wave_modes` are unregistered too. So NOTHING in T1 fences item 17.

Its epilogue DOES NOT print the `OVERALL: ok` sentinel `banner_complete` requires -- measured, not inferred: the suite's own output contains 0 lines matching `OVERALL`, against 3 in `test_wave_viewer.tcl`. It prints only `RESULT: ALL PASS (N checks)`, which `run_suites.sh` and `full_audit.sh` accept but the T1 driver does not. Registering it without adding the sentinel reproduces the `809c03d1` red exactly.

### User-visible surface (the user's to ratify)

Nothing new is required for the fence work in (1) -- that is pure harness, mine to decide and do.

Two things WOULD be user-visible if the item is extended:
- Adding the snapped trace's NAME to the bar changes shipped wording from `Plot: single    x: 1.5u    y: 900m` to something like `Plot: single    v(out)    x: 1.5u    y: 900m`. New wording on a surface the user already looks at, so it needs ratification -- and note the existing constraint that the label must stay `Plot:` and never `MODE:`, because the editor's own bar already uses `MODE:` for the NETLISTING mode.
- Extending the snap to DIGITAL strips would be a behaviour change (they currently refuse it deliberately).

Already-ratified and shipped, for the record: the viewer `pack forget`s the editor's `$top.statusbar` for the window's life and shows its own `$top.wvstatus` instead. Row ST20 asserts both halves.

### Traps for the implementer

1. THE WISH-LIST ANNOTATION IS THE TRAP. Item 17 carries no marker at all, while items 1/3/8 carry "DONE! Claude Code". An absent annotation on this list reads as "not started", and the feature is fully shipped and has already been through a user-reported bug and its fix. Do not schedule this as new work. (Items 14 and 16 of the same list are worth re-checking for the same reason -- `graph_markers.md`, `graph_marker_create_at` and `test_wave_markers.tcl` all exist and `test_wave_markers` is likewise unregistered.)

2. A GREEN STANDALONE RUN IS NOT PERMISSION TO REGISTER. `test_wave_snap` passes 64/64 and would still redden T1 the moment it is listed, because it prints no `OVERALL: ok`. Check any suite's epilogue against `banner_complete` in tests/banner_rule.tcl -- NOT against `run_suites.sh` or `full_audit.sh`, both of which carry their own EREs that accept `RESULT: ALL PASS`. That is why "it passes standalone" is worthless here.

3. THE SPEC IS RIGHT BUT ITS HEADLINE SENTENCE IS STALE, and the stale half is exactly the thing this item is about. `doc/claude/specs/waveform_viewer.md` says the diamond "sticks to the nearest SAMPLE of the nearest trace" and that the readout publishes "that sample's x and y". Issue 0193 changed that: the code publishes `hit.seg_x`/`hit.seg_y`, the INTERPOLATED point on the polyline segment, which below the sample spacing is not any sample at all. The in-code comment at `draw_graph_snap_cursor` is the accurate one ("the POINT ON THE CURVE, not the nearest sample ... `xschem get graph_snap` now reports an INTERPOLATED x/y"). Trust the code.

4. LANDMINE 35 IS LIVE IN THIS EXACT FIELD. Anything touching the readout must keep publishing UNSCALED values. `mylog10()` clamps a zero sample to -35, which reads back as `1e-35`; `graph_point_at` undoes it with `pow(10.0, ...)` when `gr->logx`/`logy`. Row SG3 has a check named for this ("...and specifically not the mylog10 clamp artefact"). A refactor that publishes `gr`-space values passes every "is it a number" assertion and is wrong by 35 decades.

5. DO NOT BIND A MORE-SPECIFIC MOTION SEQUENCE. Both the status bar and the readout append with `+` to the KEPT GENERIC `<Motion>` / `<ButtonRelease>`. Tk is most-specific-wins, so a `<Motion>` -> `<Motion-1>`-style tightening would PREEMPT the generic editor bind and kill the C-side canvas handling. Comments at both bind sites say so.

6. `wviewer::status_refresh` MUST NEVER THROW and MUST NOT SWITCH CONTEXT. It rides the motion pump, so an error pops Tk's bgerror modal on every mouse move; every widget touch is individually `catch`ed for that reason. It also reads the snap ONLY when this viewer's context is already current (issue 0173) -- deliberately, because "already current" IS the "pointer is here" test, and the old `wviewer::in_ctx` path left the C context on the viewer while the user was in the schematic. Related silent trap recorded in the spec: `in_ctx` runs its body at `uplevel #0` so a `set` inside creates a GLOBAL and the caller's local is untouched, whereas `with_edit` uses `uplevel 1` and does reach the caller. The observed symptom of getting that wrong was "the bar showed the plot mode and never a coordinate" -- i.e. exactly this item silently half-broken.

7. THE PERFORMANCE BRAKE IS LOAD-BEARING. `graph_point_at` walks every sample of every trace and this runs on BARE HOVER. Two guards must survive: the early-out when the mouse PIXEL is unchanged (`graph_snap_prev_mx/my` -- the repaint-level `pos_changed` test is NOT enough, it suppresses the paint but not the query), and the yield on `xctx->ui_state || xctx->graph_marker_dragmode`. Rows assert both regexes textually.

8. THE ERASE MUST STAY A `save_pixmap` COPY-BACK. `graph_snap_erase` uses `MyXCopyArea`, NOT the `gctiled` stroke that `draw_snap_cursor`/`erase_snap_cursor` use. With `FIX_BROKEN_TILED_FILL` undefined (the default here) the tiled stroke does not remove the glyph in a viewer window -- the diamond left a TRAIL across the strip, clearable only by a full redraw. A row asserts `graph_snap_shape(xctx->gctiled` appears zero times.

9. `draw_graph_snap_cursor` returns immediately when `!has_x`, so the query cannot run under `--nogui` at all. The end-to-end motion -> snap -> bar assertion only exists on the display arm, which is why `dcases` is the registration that matters. The pure formatting half (`status_text`) is the part that is verifiable true-headless, and it was split out for exactly that reason.


==============================================================================

## 2. Wire labels creation in schematic view with Cadence UX. 60% done by Claude Code (need to add support for vertical justification, and place multiple members of bus in one shot)

**Verdict:** `PARTIAL` · **Size:** `MEDIUM` · **Headless-verifiable:** `FULLY` · **List annotation correct:** `True`

### What was measured

The feature itself (Cadence-style Add Wire Label form) SHIPS: `addlabel::` namespace in `src/xschem.tcl`, `xschem add_wire_label [-place|-drop x y]` in `scheduler()`, `place_wire_label()` in `src/actions.c`, drop gate `wire_label_try_commit()` (callback.c) over `point_on_wire_or_pin()` (check.c). Both named gaps are real. Binary probed at HEAD e05a9769 (src/xschem is the newest file in src/, so not stale), all runs `env -u DISPLAY HOME=<scratch> ./src/xschem --nogui --pipe -q --nolog --script`.

(a) VERTICAL JUSTIFICATION — ABSENT, and not reachable by any wire-label UX.
- The form builds `ttk::checkbutton $w.f.vjust -text "Vertically justified" -variable addlabel::vjust -state disabled`. Repo-wide grep for readers of `addlabel::vjust` returns exactly three hits: the `variable vjust 0 ;# reserved (inert)` declaration, the `-variable` binding, and the `grid` line. The flag is WRITE-ONLY — no C branch, no Tcl proc, no test reads it.
- `place_wire_label(const char *name)` (actions.c) calls `place_symbol(-1, symbuf, mousex_snap, mousey_snap, 0 /*rot*/, 0 /*flip*/, prop, 4, 1, 0)`. Orientation is hardcoded; there is no argument and no global to change it. Measured: probe placed one label and `xschem saveas` wrote `C {lab_pin.sym} 100 0 0 0 {name=l1 lab=a[3:0]}` — rot 0, flip 0.
- A wire label is NOT an xText, so `xText.hcenter/vcenter` (src/xschem.h) is the wrong lever. The visible text is the SYMBOL's own text record: `xschem_library/devices/lab_pin.sym` line `T {@lab} -7.5 -8.125 0 1 0.33 0.33 {}` — no `hcenter=`/`vcenter=` token. `set_text_flags()` (actions.c) reads `hcenter=`/`vcenter=` from that TEXT object's own prop_ptr, and `draw_symbol()` (draw.c) passes `flip^text.flip, text.hcenter, text.vcenter` — only rot/flip compose with the instance's transform; hcenter/vcenter come straight from the symbol and are therefore shared by every label instance in every design.
- The task's caveat is confirmed exactly: generic TEXT does expose it (`slicktext::chk(vcenter)` / "Center V" in xschem.tcl's text dialog, and `property_form.tcl`'s `tok vcenter label {Center V}`), and the wire-label flow does not.
- Partial capability by accident: `xschem rotate` on a live preview works — probe gave `C {lab_pin.sym} 100 0 1 0 {name=l1 lab=NET1}` (rot=1 = text reads vertically). But it does NOT survive the queue's re-arm: with a rotate before the first drop, `xschem instance_coord l1` → `{l1} {lab_pin.sym} 100 0 1 0` and `instance_coord l2` → `{l2} {lab_pin.sym} 300 0 0 0`, because `addlabel::arm` re-issues `-place` → `place_wire_label` → rot 0.
- The machinery already exists elsewhere: `lab_orient(double dx, double dy, short *rot, short *flip)` — static in actions.c, used only by `add_pin_stubs()` — returns rot=1 for vertical text. The sibling Add-Pin form (`addpin::`) has no orientation control either, so there is no in-form precedent.

(b) PLACE MULTIPLE MEMBERS OF A BUS IN ONE SHOT — one-gesture placement ABSENT; per-member auto-increment already SHIPS.
- One shot, measured: `set ::label_new_name {a[3:0]}` + `add_wire_label -place` + ONE `-drop 100 0` → `insts=1`, `inst 0 sym=lab_pin.sym lab=a[3:0]`. One click gives one vector label, never four.
- `addlabel::place_multiple` is write-only in the same way as `vjust` (declaration, `-variable ... -state disabled`, `grid`). Nothing reads it.
- What DOES ship: with `addlabel::split_bus 1`, `addlabel::expand_names` builds a queue and `addlabel::after_drop` consumes one name per ButtonRelease. Measured on four parallel wires (winfo stubbed as the registered suite already does): queue `{a[3]} {a[2]} {a[1]} {a[0]}`, four `-drop`s → four instances `a[3] a[2] a[1] a[0]` at y=0/20/40/60, Name field draining `a[2] a[1] a[0]` → `a[1] a[0]` → `a[0]` → empty. That is Cadence's "click each wire, name auto-increments" behaviour — one click per member, not one shot. "Split bus" is OFF by default (`variable split_bus 0 ;# unchecked by default (user request)`).
- The placement flow never calls the engine's bus expansion. `expandlabel()` call sites are netlist.c, spice_netlist.c, flyline.c, plus two Tcl callers (`xschem expandlabel` in ase_window.tcl and xschem.tcl). `addlabel::expand_names` is an independent pure-Tcl regex reimplementation.

### What is left

(a) VERTICAL JUSTIFICATION. Decide the mechanism first (see user_visible_surface — it is a ruling), then:
- Cheap path (rotation semantics, what `lab_orient()` already does): add a flag the C arm reads the way `-place` reads `::label_new_name` (e.g. `::label_new_rot`, or a `-place -vjust` argument), give `place_wire_label()` a rot/flip parameter and pass it into the existing `place_symbol()` rot/flip slot, enable `$w.f.vjust` and have `addlabel::on_vjust_change` call `addlabel::start_pass`. It must be applied INSIDE `addlabel::arm`, not left to the user's `xschem rotate`, or it is lost on every re-arm (measured). Also decide whether it should instead be AUTOMATIC from the wire direction under the cursor (what `add_pin_stubs` does via `lab_orient`), which would be more Cadence-like than a checkbox.
- Expensive path (true justification semantics, text anchored differently rather than rotated): needs a per-instance override of a symbol text's hcenter/vcenter, since `draw_symbol()` takes them straight from `symptr->text[j]`. The only existing precedent for a per-instance override of a symbol text attribute is the layer one (`text_layer_<n>=` via `get_sym_text_layer()`), so this means a new token, a new read in the draw path, and save/load/undo coverage. Do not do this without the ruling.

(b) PLACE MULTIPLE MEMBERS IN ONE SHOT. Blocked on semantics — the spec itself records "(Semantics TBD by the user.)" Two candidate readings, very different costs:
- "Already met" reading: the Split-bus queue is the Cadence auto-increment behaviour (measured working). Remaining work is then only ergonomic — default Split bus ON, or retitle the checkbox — and it is entirely the user's call, not engineering.
- "One gesture" reading: a click-drag that crosses N wires names them with successive members in one gesture, or one click that drops all queued members down a bundle at a pitch. This needs a new canvas gesture during placement, a per-member run of the existing drop gate (`wire_label_try_commit()`), ONE undo for the whole set (`add_pin_stubs()` is the precedent: it drops N labels + N stubs under a single `push_undo`), and it must not put two differently-named labels on one wire (see traps).
- Independent of the ruling, worth doing: make the placement flow agree with the netlister's bus grammar, or state in the form why it does not (see traps).
- No issue file exists for either gap (only wish_list.txt and add_wire_label.md mention them), so a number must be minted per NUMBERING.md's two-check procedure — and note 0500–0599 is this branch's own reserved band, and row D9 of `test_issue_stamp` (a T1 case) reddens on a new issue file without a valid `**STAMP:**` line.

### The fence

The suite exists and gates. `tests/headless/test_add_wire_label.tcl` (156 `check` calls) is REGISTERED in `hcases` — the entry `"headless/test_add_wire_label"` is inside the `set hcases [list` block, which closes on the line ending `"headless/test_raw_schname_0514"]`; it is NOT in `dcases`. Its epilogue is `if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 }` — the `OVERALL: ok` is a whole line with nothing after it, so it satisfies `banner_complete`'s `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` in tests/banner_rule.tcl, and `RESULT:` is printed before it (note `summarize_all` publishes a case's LAST `RESULT:` line, which this ordering preserves). Nothing extra needs registering.
What it does NOT fence today: grep of the suite for `vjust`, `vertical`, `place_multiple` finds only an unrelated comment about "a multiple selection"; grep for `rot`/`flip` finds only three comment hits. So there is no row asserting a placed label's orientation and no row asserting the two checkboxes are inert — a new fence adds rows rather than fighting old ones.
Both gaps are fenceable with no human looking, and the two seams were measured: (1) `xschem add_wire_label -place` / `-drop x y` is the headless commit seam and returns 1/0; (2) orientation is readable as `xschem instance_coord <instname|index>` → `{l1} {lab_pin.sym} 100 0 1 0` (name, symbol, x, y, rot, flip). Form-level procs (`addlabel::start_pass`, `arm`, `after_drop`) run under `--nogui` because the suite already installs `proc winfo {op args} { return 1 }` and removes it with `rename winfo {}`.

### User-visible surface (the user's to ratify)

Two strings already SHIP in the form, visible but disabled, so enabling them adds no new wording: "Place multiple labels at once" and "Vertically justified" (plus the working "Split bus"). What is unratified is the SEMANTICS behind each, and the spec says so in its own words — "(Semantics TBD by the user.)" for the multiple checkbox. Concretely, four things the user has to settle:
1. What "vertically justified" means: rotate the label so its text reads along a vertical wire (rot=1, what `lab_orient` computes), or keep it horizontal and change where the text sits relative to the anchor (true justification / vcenter). If it is rotation, the shipped checkbox wording is arguably wrong — rotation is not justification — so the label may need renaming, which is user-facing copy.
2. Whether it should be a checkbox at all or automatic from the direction of the wire under the cursor (the `add_pin_stubs` "flag in the wind" behaviour), which changes every label the user places rather than only opted-in ones.
3. What "in one shot" means for a bus: the auto-increment-per-click behaviour that Split bus already delivers (measured), a drag across a bundle of wires, or one click that drops all members. The third puts several differently-named labels on ONE wire, which is an electrical statement the user should make knowingly.
4. Whether "Split bus" should default ON. It defaults OFF by an explicit user request recorded in the code comment (2026-07-12), so flipping it is theirs.
Per the one-ruling-at-a-time rule these are four exchanges, not a list; item 1 should go first because it decides whether (a) is a one-commit change or a new draw-path mechanism.

### Traps for the implementer

1. Unusually, the spec is NOT lying here — `doc/claude/specs/add_wire_label.md` says both checkboxes are "reserved (inert)" and the code agrees. But its gloss "(Will later rotate/vcenter the label text.)" silently conflates two mechanisms with very different costs, and only one of them is cheap.
2. A wire label is a `lab_pin.sym` INSTANCE, not an xText. Anyone who goes looking for `xText.hcenter/vcenter` (src/xschem.h) on the label will find the wrong object. `set_text_flags()` reads those tokens from the TEXT object's own prop_ptr, and `draw_symbol()` (draw.c) passes `flip^text.flip, text.hcenter, text.vcenter` — the instance transform composes into rot/flip ONLY. So there is no per-instance justification field, and setting `vcenter=true` on the instance's prop_ptr does nothing. The one precedent for a per-instance override of a symbol text attribute is the layer (`text_layer_<n>=` via `get_sym_text_layer()`).
3. `lab_orient()` is `static` in actions.c and used only by `add_pin_stubs()`. Reuse it (un-static it) rather than reinventing the mapping; its comment records that the rot/flip pairs were determined empirically against lab_pin.sym's `T {@lab} -7.5 -8.125 0 1 ...` anchor, so a hand-derived second copy will get flip backwards.
4. Rotation does not survive the queue. Measured: `xschem rotate` before the first drop gives `l1` rot=1 and the NEXT queued label `l2` rot=0, because `addlabel::arm` re-issues `-place` on every keystroke and `place_wire_label` hardcodes 0. A vjust flag must be read inside the arm, and it must be idempotent across those per-keystroke re-arms (the C arm deliberately tears down and re-places the preview without pushing undo).
5. TWO DIFFERENT BUS GRAMMARS, and the placement flow uses the weaker one. `addlabel::expand_names` is a pure-Tcl regex handling only `base[hi:lo]` / `base[i]`, and `addlabel::name_ok`'s regex `^[^][{}<>;:]+(\[[0-9]+(:[0-9]+)?\])?$` actively REJECTS names the engine expands. Measured side by side (`xschem expandlabel` vs `addlabel::expand_names ... 1`): `a[3:0:2]` → engine `a[3],a[1]` mult 2, form keeps the whole token AND `name_ok` refuses it (two colons); `2*a` → engine `a,a` mult 2, form places a literal label named `2*a`; `a<3:0>` → engine does NOT expand angle brackets (mult 1) while the form normalises `<>`→`[]`. `expandlabel()` is called from netlist.c, spice_netlist.c and flyline.c — never from any placement path. Do not assume a "bus" means the same thing on both sides of this feature.
6. rot/flip/x/y are NOT readable through `xschem getprop instance N …` — measured empty for all four, and there is no `xschem instance_position` (error: "invalid command"). `getprop instance` only reads instance prop_ptr tokens plus `cell::<attr>`. The working read seam for a fence is `xschem instance_coord <instname|index>`; with NO argument it returns only the SELECTED instances, which after a drop is just the last one, so a row must name the instance.
7. P2 INVARIANT LANDMINE for the "all members on one wire" reading of (b). `fluid_count_label_shorts()` (src/move.c) counts every net-label instance whose `node[0]` strcmp-differs from the physical net of the wire its pin touches, and the END enforcement gate refuses a move on a nonzero P2 delta. Measured: dropping `NET1` and `NET2` on ONE wire already emits `fluid_editing INVARIANT (P2): net label 'N2' (l2) on net 'N1' -- possible short/merge`. Dropping `a[3]`..`a[0]` on a single wire would manufacture three such shorts (the compare is a plain strcmp, so `a[3]` vs a net named `a[3:0]` counts) and would poison later move gestures over that net. The one-label-per-wire reading is clean.
8. The whole point of this form is "no stray net-labels": a label may only commit ON copper (`point_on_wire_or_pin()`, check.c; enforced by `wire_label_try_commit()`, callback.c, for both the GUI button path and `-drop`). Any one-shot multi-place must run that gate per member, and must decide what happens when member 3 of 4 lands off copper.
9. Entering the form abandons an in-progress wire/line draw (`leave_wire_draw_for` / `leave_shape_draw_for` in the scheduler branch) and `-drop` is deliberately excluded from that. A new gesture added to the placement arm has to respect the same split, or `-drop` stops being a pure commit seam and the headless fence changes meaning.
10. The suite is in `hcases` only, and `--nogui` has no real `toplevel`/`winfo`/`bind`/`event generate`. Follow the existing idiom (`proc winfo {op args} { return 1 }` … `rename winfo {}`) instead of adding a display-arm row; a row registered into `dcases` would also change T1's `cases=`/`skips=` trailer, which must then be re-measured rather than quoted.


==============================================================================

## 26. Support similar use model to Cadence's o=car(geGetSelSet()) and then o~>?? to look at properties. Currently, we have selected_set for things other than wire and selected_wire // Pending

**Verdict:** `PARTIAL` · **Size:** `MEDIUM` · **Headless-verifiable:** `FULLY` · **List annotation correct:** `False`

### What was measured

BOTH halves of item 26's machinery ship. The item's own deliverable -- one accessor spelling -- does not, and three silent-wrong-answer traps sit between the halves. All measured on ./src/xschem (mtime 17:58 today, newer than scheduler.c at 05:07 and newer than every C commit since 1618) run as `env -u DISPLAY ... --nogui --pipe -q --script`.

READ HALF -- 1618's claims CONFIRMED end to end. `xschem_cmds_g()`'s getprop branch + the new static `getprop_gfx_prop()` give a token-omitted whole-string form for rect/text/wire/line/poly/arc (instance/symbol already had one), and it feeds `list_tokens`:
  getprop line 4 0      -> |aa=L bb=2|   list_tokens -> |aa bb|
  getprop poly 4 0      -> |aa=P cc=3|   list_tokens -> |aa cc|
  getprop arc  4 0      -> |aa=A|        list_tokens -> |aa|
  getprop wire 0        -> |lab=NETA|    list_tokens -> |lab|
  getprop text 0        -> |name=T1 aa=T|
  getprop zzz  4 0      -> rc=0 || (1618's open item 1, confirmed live)
Token reads still work alongside (`getprop line 4 0 aa` -> |L|).

SELECTION HALF -- the task brief and the wish-list annotation are BOTH out of date. The `car(geGetSelSet())` half is largely ALREADY SHIPPED, in `xschem_cmds_o()`:
  `xschem objects [-selected] [-type T] [-layer L]` -> uniform Tcl-dict list over all SEVEN drawable types, WIRES INCLUDED, built by `object_descriptor()`:
    |{type wire index 0 layer 1 id 1 name {}} {type instance index 0 layer 1 id 1 name {l1}} {type text index 0 layer -1 id 1 name {}} {type rect index 0 layer 4 id 700 name {}} {type line ...} {type poly ...} {type arc ...}|
  `xschem selection` -> positional `{type index col id}` rows, all seven types plus INST_PIN (landed at commit ce6cf98f, "feat(handles)").
  `xschem object <type> @<id>|#<i>|#<layer>,<i>|<name>` resolves a durable handle; `wire_id`/`wire_index`, `rect_id`/`rect_index`, `line_id`, `poly_id`, `arc_id`, `text_id`, `instance_id` provide the handle space.
So `o = car(geGetSelSet())` ALREADY has an exact Tcl spelling, measured working:
  set o [lindex [xschem objects -selected] 0]  -> |type wire index 0 layer 1 id 1 name {}|
  dict get $o type -> |wire|
The annotation's premise is obsolete: `selected_set` genuinely has no wire arm (its code has only xRECT/xTEXT/ELEMENT branches; bare call returned |{l1}| with two wires selected), and `selected_wire` returns each wire's `lab` VALUE, not an identity -- with one labelled and one unlabelled wire it returned |{NETA} {}|, so two unlabelled wires are indistinguishable and unaddressable. That describes the pre-ce6cf98f world.

SO: 1618's "unblocks item 26" claim is TRUE, and narrower than it sounds. It is true for the four per-layer types (rect/line/poly/arc), whose descriptor `layer`+`index` feed getprop verbatim. It is NOT sufficient for wire/text/instance, and it did not touch the bridge.

THE GAP (see traps) is measured, not inferred: descriptor-to-getprop is not a uniform call for any of the three reasons below.

### What is left

The status word "Pending" is right; the annotation's factual clause is not, so rewrite the line before an implementer rebuilds the selection half that already exists.

Minimal deliverable, NO C CHANGE NEEDED (SMALL): a Tcl accessor namespace over the shipped descriptor dict that normalises the three traps in one place. Following this tree's only convention (`namespace eval ase { ... }` procs -- `namespace ensemble` appears ZERO times in src/*.tcl):
  obj::props $o        -> whole prop string   (switch on `type`: 3-arg for rect/line/poly/arc, 2-arg for wire/text/instance)
  obj::keys  $o        -> xschem list_tokens [obj::props $o] 0
  obj::get   $o <tok>  -> one value
  obj::set   $o <tok> <val>  -- setprop has the IDENTICAL split arity, so the write half needs the same shim or `o~>prop = v` stays asymmetric
Resolve `id` -> current index through the existing `xschem <type>_index <id>` / `xschem object <type> @<id>` commands rather than passing `id` to getprop (trap 1). Refuse or reconcile text's layer field (trap 3).

Separable, and arguably its own issue because it is a live silent-wrong-answer defect rather than item-26 scope: make getprop/setprop either accept an `@<id>` selector or REJECT one, instead of letting `atoi("@3")` coerce to 0 and answer about object 0.

Docs: leave property_introspection.md alone or retire it (see traps); its §3 framing "the LOCATE surface has no matching READ surface" is now half-wrong -- the read surface exists and it is the BRIDGE that is missing.

### The fence

Split, and the half item 26 depends on is unfenced.

READ half: `tests/headless/test_getprop_index_bounds.tcl` is the natural home and is REGISTERED -- `tests/run_regression.tcl` line 33, in `hcases`, and a loose `/usr/bin/grep -c` over the whole driver finds it as the ONLY `getprop` hit. Its epilogue prints a bare `OVERALL: ok` on its own line, which matches `banner_complete`'s `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` in tests/banner_rule.tcl, so it gates. Ran it just now: `PASS | test_getprop_index_bounds run 1/1 RESULT: ALL PASS (103 checks)`, `RESULT: 1/1 runs passed`. That is where the new bridge rows belong -- no new suite, no registration change, no movement in the 107/106/0/8 T1 figures.

SELECTION half: NO REGISTERED FENCE AT ALL. Every suite that drives `xschem objects` or `xschem selection` as an introspection surface is in neither list -- `test_select_at`, `test_hover_selection_repair`, `test_scripted_shape_undo`, `test_wave_sigbrowser_i12` all return hits=0 on a loose grep of run_regression.tcl (only `test_fluid_editing` is registered, and it touches `selection` incidentally). So `objects`/`object`/`object_at`/`selection` -- the entire geGetSelSet() half, and the exact surface the three traps live on -- is audit-reachable via full_audit.sh and gates nothing. Fixing that is CLAUDE.md's "a suite you add a fence to, you register in the same commit" case.

### User-visible surface (the user's to ratify)

Two things, both genuinely the user's.

1. The accessor's NAME AND SPELLING. This is documented Tcl API that users type -- Cadence's `o~>prop` has no Tcl analogue (no operator overloading, and TclOO's `$o -> prop` is unavailable at the declared floor: src/xschem.tcl still guards `info tclversion > 8.4` in eight places and CLAUDE.md declares 8.4-8.6, though `dict get` already appears 63x in xschem.tcl and 819x in ase.tcl so the dict shape itself is safe). `obj::get $o lab` is my recommendation; the namespace name and whether it reads `obj::`/`xobj::`/`ase::obj::` is theirs.

2. Whether `xschem getprop wire @3` should START ERRORING. Today it silently answers about object 0. Flipping it to an error changes a shipped command's behaviour, which is the same class of decision 1618 deferred as its own open item 1 and batch decision D6.

Note per ui-copy-style: any new error string must be terse and spell acronyms uppercase.

### Traps for the implementer

THREE MEASURED SILENT-WRONG-ANSWER TRAPS between the two halves. None is an error. This is the actual remaining work and it is written down nowhere.

T1 -- getprop ACCEPTS NO `@<id>` SELECTOR AND ANSWERS ABOUT OBJECT 0 RATHER THAN FAILING. Built three wires, deleted wire 0 so id != index: W_B at index 0 has id 2, W_C at index 1 has id 3.
  xschem object  wire @3  -> |type wire index 1 layer 1 id 3 name {}|   (correct)
  xschem wire_index 3     -> |1|                                        (correct)
  xschem getprop wire @3  -> rc=0 |lab=W_B|                             THE WRONG WIRE
The wire arm does `n = atoi(argv[3])` and `atoi("@3")` is 0. Since `id` is the one field the whole handles infrastructure exists to provide, the obvious shim keyed on `dict get $o id` is silently wrong on every schematic where anything has been deleted.

T2 -- THE ARITY IS NOT UNIFORM, AND THE MISMATCH IS A SILENT EMPTY ON FLAT TYPES. rect/line/poly/arc take `<layer> <index>`; wire/text/instance take ONE selector. Feeding the descriptor's layer uniformly:
  getprop wire 1 1      -> rc=0 ||   (layer eaten as the index, index eaten as the TOKEN NAME)
  getprop wire 0 1      -> rc=0 ||
  getprop instance 1 0  -> rc=1 |instance not found:1|
  getprop text -1 0     -> rc=1 |text object not found:-1|
So a naive uniform shim fails loudly on two types and SILENTLY on the third. Same family as 1618's own open item 1, reached from the other side. setprop has the identical split (`setprop rect lay n tok` vs `setprop wire n tok` vs `setprop text n tok` vs `setprop instance <inst> tok`).

T3 -- THE TWO SHIPPED ENUMERATORS DISAGREE ON TEXT'S LAYER, AND NEITHER VALUE FEEDS getprop text. Same text object, same run:
  xschem selection       -> |{text 0 3 1} ...|   col 3  (TEXTLAYER, from rebuild_selected_array)
  xschem objects -type text -> |{type text index 0 layer -1 ...}|  layer -1 (xctx->text[i].layer)
  getprop text 3  -> rc=1 |text object not found:3|
  getprop text -1 -> rc=1 |text object not found:-1|
Only `getprop text <index>` works. Pick either enumerator and the layer field is a trap.

DOC/CODE DIVERGENCE -- exactly the brief's trap 1, two live instances in src/scheduler.c, both claiming ids do not exist when they do:
* The `xschem selection` doc comment says "id : the session-stable wire id (see 'wire_id') for wire rows, -1 for the other types (WHICH HAVE NO STABLE ID YET)". Its own switch stamps real ids for all eight cases; the probe printed ids 1,1,1,2,699,700,0,698 across text/instance/wire/wire/arc/rect/line/poly. Only `default:` leaves -1.
* `object_descriptor()`'s header says "id is the stable id (-1 FOR TEXT, WHICH HAS NONE YET)" while its own `case xTEXT` reads `xctx->text[i].id`; xText carries an `id` field in xschem.h and the probe returned id 1 for text. An implementer trusting either comment would go build a text-id space that already exists.

SPEC -- doc/claude/specs/property_introspection.md is SAFE TO IGNORE for item 26, and 1618's staleness report on it is confirmed. Its status line says "PROPOSED (enhancement). No code yet" (false); its §2 table says line/poly/arc have "no arm at all" (1618 refuted); `scheduler.c:2686` is ~3200 off, getprop is at 5985. Crucially it BINDS AN IMPLEMENTER TO NOTHING: it never mentions item 26, `geGetSelSet` or `o~>` anywhere (grepped), and §4 is headed "Candidate approaches (TO BE DECIDED IN DESIGN)" with two non-exclusive options -- A is what 1618 shipped, B is an unratified "append a `props {k v ...}` field to xschem object/objects" which is a DIFFERENT shape from the accessor above. No syntax commitment exists.

PROCESS -- my first probe printed `corrupted size vs. prev_size` from glibc at teardown, but that run passed deliberately malformed arg counts to `xschem line`/`xschem polygon`. It did NOT recur in the three later probes with correct arities. Recording it as an observation only; per D8 one unreproduced observation is not a verdict, and it is out of item 26's scope. Worth knowing if someone fuzzes those creation verbs.


==============================================================================

## new-list item 7: "Efficiency coach / key promoter / notification menu (visit to find out where you will benefit from using shortcuts)"

**Verdict:** `ABSENT` · **Size:** `LARGE` · **Headless-verifiable:** `MOSTLY` · **List annotation correct:** `True`

### What was measured

NOTHING LIKE IT EXISTS. `/usr/bin/grep -rniE "notification|bell|badge|suggestion_queue|coach_"` over src/*.c and src/*.tcl returns zero product hits (only unrelated "unlabelled"/ASE-L results-badge prose). `grep -rniE "action_count|usage_count|use_count|invocation_count|times_used"` returns ZERO — nothing in the tree counts how often any action is invoked. No "did you know"/tip surface. The only nudge machinery that exists is `palette_emphasis_index` (src/action_registry.tcl), a deliberately one-off first-launch attention colour for a single command-palette row, whose own comment says "the spec is explicit this is a one-off".

THERE IS A DESIGN DOC, AND IT IS A PROPOSAL, NOT STATE: `doc/claude/suggestions/notifications_efficiency_coach.md`, 274 lines, header "Status: design proposal ... not yet scheduled". It names a toolbar bell, a ring buffer, Type-A/Type-B rules, a persistent queue. None of it is built.

(ii) THE KEYBINDING REGISTRY, MEASURED AGAINST THE REAL BINARY. I ran `timeout 90 env -u DISPLAY HOME=<scratch> ./src/xschem --nogui --pipe -q --nolog --script <probe>` (binary built 17:58 today, src/ clean at e05a9769):
  ROWS: 78 / DISTINCT_IDS: 48        <- `xschem bindings dump`
  registry_bound(file.save) = 0
  registry_bound(edit.copy) = 0
  registry_bound(edit.cut) = 0
  registry_bound(edit.paste) = 0
  registry_bound(edit.select_all) = 0
  registry_bound(tools.insert_wire) = 0
  registry_bound(edit.undo) = 1
  registry_bound(view.zoom_in) = 1
  ACTION_TABLE_ROWS: 166 / SHEET_LINES: 66 / listed_rows = 57
  regexp {^  Ctrl\+A\s} = 0   (my first substring probe said "Ctrl+A present"; it was matching inside `Ctrl+Alt+v  Show in Signal Browser` — the whole-chord regexp REFUTES it)
So the live registry is `input_bindings` in src/callback.c, seeded by `init_input_bindings()` (76 `set_input_binding`/`set_input_binding_idle` calls), dumped by `xschem bindings dump`, mirrored to the shipped `src/keybindings.csv` + `src/mousebindings.csv` by `save_input_bindings_file`, and rendered by `generate_keybindings_text`/`keybinding_chord_label`. It holds 78 chords / 48 action ids. `src/actions.csv` has 163 `command` rows. Cross-referencing: 47 of those 163 are bound in the registry; 33 of the 47 also carry an `accel` string; 14 are registry-only with an empty `accel` (the pans/scrolls/zoom_rect); **76 rows carry an `accel` chord claim with NO registry row**; 54 claim no chord at all.
Ctrl+S, Ctrl+C, Ctrl+X, Ctrl+V, Ctrl+A and `w` all WORK — they are arms of the legacy `switch(key)` in `handle_key_press()` (src/callback.c), 81 `case` labels over ~80 distinct keysyms with 82 `state ==` sub-branches. I read the actual arm: `case 'a': ... else if(rstate == ControlMask) { /* select all */ select_all(); }`. `dispatch_input_action()` runs FIRST, gated by `key_chord_has_binding()`, and un-migrated chords fall through to that switch.

(i) INTERACTION LOGGING (old item 3) CANNOT ANSWER "BY MENU". Traced end to end. Key/mouse: `dispatch_input_action()` logs `d->log_cmd` (C-backed) or `d->tcl` (Tcl-backed); `d->log_cmd` is pushed at startup from the actions.csv `command` column by the `foreach row $action_table { xschem set_action_log_cmd ... }` loop in src/xschem.tcl. Menu: `build_menu_from_table` sets `-command [list menu_action_logged $mcmd]` with `$mcmd` = the SAME csv `command` string, and `menu_action_logged` writes it verbatim. So the two paths emit BYTE-IDENTICAL lines, and `actionlog_cmd_logged` (set inside `log_action()` in src/util.c) exists precisely to make sure only ONE of them writes. The feature doc's own §5 says this: "the descend-absorb log records the *same* line ... whether the user pressed Ctrl+X or crawled through the E-dialog. The outcome alone cannot tell an efficient run from an inefficient one." There is no provenance token, no cost field, no `-source` flag anywhere.
BUT the provenance IS available at the call sites, and that is what makes this not blocked on item 3: `::menu_invoke_logged` (src/action_registry.tcl, issue 0930) renames and intercepts `invoke` on EVERY Tk menubar widget — its comment records that Tk's own `::tk::MenuInvoke` ends in `uplevel #0 [list $w invoke active]`, so mouse picks, keyboard traversal and a test's `$m invoke N` all arrive there. A counter increment at that one proc needs nothing from item 3.

(iii) SURFACE TO HANG IT ON — a real one exists. `xschem::notify` (src/ciw.tcl) is "THE ONE NOTIFICATION CHANNEL": four sinks (CIW pane via `ciw_echo`, durable log via `xschem::notify_log` writing `#= `/`#! ` comments, `.statusbar.12` short form via `notify_statusbar`, opt-in toplevel via `notify_popup`), plus `-menu`/`-command` remedy fields rendered as "Fix: <menu>. CIW command: <cmd>", plus a per-(subject,state) suppression latch (`notify_latch_ok`/`notify_latch_rearm`/`notify_latch_reset`) reached by `-once`/`-state`. And a toolbar exists: `toolbar_add name cmd help topwin` builds `$topwin.toolbar.b<name>` from `img<name>` with a `balloon` tooltip and `-takefocus 0`; `setup_toolbar` holds `toolbar_list`; icons are 154 embedded `image create` entries in the already-installed `src/resources.tcl`. FOCUS RULE HONOURED BY PRECEDENT: `notify_popup` uses `raise` only and never `focus`; toolbar buttons and menus are all `-takefocus 0`.
WHAT IS MISSING ON THE SURFACE SIDE: there is no bell, no badge, no panel, and no notice HISTORY — `::xschem::notify_last` holds exactly one dict (the last notice); the CIW text pane and the `#=`/`#!` lines in Xschem.log are the de-facto log. So "notification menu" as the user worded it does not exist in any form.

### What is left

All of it. Concretely, and in dependency order:

1. REGISTRY COVERAGE (correctness prerequisite, and the real blocker — not item 3). The coach's central lookup is "does this action have a chord?", and today the only live answer covers 47 of 163 registered actions, omitting Save/Copy/Cut/Paste/Select-all/Insert-wire — i.e. exactly the actions worth promoting. Either continue the `handle_key_press` switch → `input_bindings` migration for the promotable set, or add a fenced `accel`-column fallback plus a row asserting each of the 76 unbacked `accel` claims agrees with the switch arm that implements it. Without one of these the coach is silent on the common case and the feature has no value.

2. PROVENANCE-TAGGED EVENT TAP + RING BUFFER. New. Feed it from `::menu_invoke_logged` (menu picks — already universal) and `dispatch_input_action` (chords). Record {action_id, invocation, cost, timestamp}. Item 3 built neither the tag nor the buffer: its "holding area" is `actionlog_pending` (a single `char[300]`) plus `actionlog_pending_inst`, driven by `log_action_stash_select_at` / `log_action_flush_pending` / `log_action_descend`, and it absorbs exactly one `select_at` into a following `descend`. Suppress the tap during replay and headless runs through the existing `actionlog_suppress` / `actionlog_suppress_push()` / `actionlog_suppress_pop()` seam.

3. MENU PICK → ACTION ID RESOLUTION. `::menu_invoke_logged` has only the widget path, the index and the `-command` string. Reverse-mapping that string to an actions.csv id is partial: of the 57 single-line menubar `-command` strings a regex could extract from src/xschem.tcl, 45 match a csv `command` exactly and 12 do not (`command_palette $topwin`, `hi_descend`, `rdw::open`, `waves`, `xschem create_instance`, `xschem library_manager`, …). That 57 is a LOWER BOUND — the regex misses multi-line entries, and there are 146 `add command` + 53 `add checkbutton` + 18 `add radiobutton` menubar entries in xschem.tcl alone, plus 44 in ase_window.tcl and 40 in wave_viewer.tcl. The clean fix is to give every menubar entry an actions.csv row and generate the remaining menus through `build_menu_from_table` (today only the `file` menu is generated).

4. SUGGESTION QUEUE + PERSISTENCE. Counts, dedup by id, frequency+recency rank, "don't show again", threshold K. Follow the shipped precedent exactly: `write_net_hilight_editor_seen` writes a one-line sourceable breadcrumb into `USER_CONF_DIR` and it is sourced at startup.

5. SURFACE. `toolbar_add` a bell (icon appended to src/resources.tcl), a panel listing ranked suggestions with the LIVE chord from `keybinding_chord_label`, and a passive `xschem::notify ... -once <subject> -state <key>` nudge.

6. ONE Type-A RULE plus a NEW suite that prints `OVERALL: ok (<n> checks)` and is registered in run_regression.tcl in the same commit.

### The fence

NO SUITE EXISTS FOR THIS FEATURE — a new one is required. The six neighbouring suites that would carry the prerequisite work are all present, all UNREGISTERED, and all structurally UNREGISTERABLE as shipped:

  test_keybindings_help     not in hcases/dcases   OVERALL:ok sentinel = 0   needs Tk (`command_palette .`)
  test_bindings_file        not in hcases/dcases   OVERALL:ok sentinel = 0   needs X (`focus -force .drw`, `xschem callback`)
  test_binding_precedence   not in hcases/dcases   OVERALL:ok sentinel = 0
  test_action_log_dispatch  not in hcases/dcases   OVERALL:ok sentinel = 0
  test_context_menu_log     not in hcases/dcases   OVERALL:ok sentinel = 0
  test_ciw                  not in hcases/dcases   OVERALL:ok sentinel = 0

Every one ends `if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }` and prints no `OVERALL: ok` line, so `banner_complete` in tests/banner_rule.tcl (`^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$`) would score them `HARNESS: ... (exit=0, OVERALL_ok=0, died=0)` = counted FAIL even with all their own checks green. This is the exact issue-1615 `test_wave_sigbrowser_panes` defect family. 122 of the tree's headless suites do print the sentinel; these six are in the other group.

CONSEQUENCE FOR THIS ITEM: the csv↔C-table drift guard (`test_bindings_file` check 1: "shipped keybindings.csv matches the builtin table") and the cheat-sheet completeness row (`test_keybindings_help`: "every bound id has an actions.csv label") gate NOTHING today. So the registry the coach would depend on is unfenced at HEAD. A coach suite must be written with the `OVERALL: ok ($npass checks)` sentinel, `RESULT:` kept last (summarize_all publishes a case's last `RESULT:` line), and registered in the same commit: rule/queue/ranking/persistence/lookup rows into `hcases` (proven drivable — my probe got `bindings dump` and `generate_keybindings_text` under plain `--nogui`), menu-interceptor rows into `dcases` (Tk needed for `$m invoke N`).

### User-visible surface (the user's to ratify)

Substantial, and it is the largest ratification load of any wish-list item I have measured. Per the one-ruling-at-a-time rule these cannot go to the user as a batch:

1. A NEW TOOLBAR BUTTON (the bell) and its position in `toolbar_list` — a permanent new pixel on every window.
2. THE NUDGE SENTENCE itself, e.g. "You used the menu 12 times for this. Press Ctrl+K." Must be terse with uppercase acronyms per the user's UI-copy rule, and must fit the 28-character budget enforced by `xschem::notify_short` if it ever reaches `.statusbar.12`.
3. THE PANEL and its per-item verbs — the doc proposes "show me" / "Got it" / "Don't show again".
4. SURFACING THRESHOLD K — first occurrence or after N repeats. The doc's own open question 2; it decides whether the feature reads as helpful or as Clippy.
5. THE COST METRIC — flat count of interactions, or dialogs weighted heavier. Open question 1.
6. WHETHER THE COACH OFFERS TO BIND A KEY when the recommended action is unbound (open question 4) — that turns a coach into a settings editor and is a different product.
7. A GLOBAL OFF SWITCH and whether to state the local-only/no-telemetry promise in the UI.
8. WHETHER THE BELL MAY EVER CHANGE APPEARANCE ON ITS OWN while the user is drawing (the anti-Clippy line, and adjacent to the standing no-focus-stealing rule).

Nothing here can be decided by the implementer. Item 6 in particular is scope, not styling.

### Traps for the implementer

1. ⚠ A SHIPPED COMMENT NAMES A MEANING THE CODE DIVERTS FROM — the exact trap class I was warned about. src/xschem.tcl, immediately above the Help-menu entry: "Keyboard cheat-sheet generated from actions.csv (always accurate; supersedes the hand-maintained keys.help prose)". FALSE twice. `generate_keybindings_text` iterates `xschem bindings dump` and joins actions.csv only for the `label`; `action_registry.tcl`'s own comment says "The decorative actions.csv `accel` column is no longer consulted". And "always accurate" is the dangerous half: MEASURED, the sheet lists 57 rows and contains no Ctrl+S, no Ctrl+C, no Ctrl+V, no whole-chord Ctrl+A, no `w`. It is accurate about the REGISTRY, not about the shortcuts that work.

2. ⚠ THE PLAN DOC NAMES THE WRONG MENU HOOK. `doc/claude/suggestions/notifications_efficiency_coach.md` §4: "Menu clicks flow through `menu_action_logged`". `menu_action_logged` is attached in exactly ONE place, `build_menu_from_table`, called for the single menu key `file`; action_registry.tcl's own measurement is "6 of 238 command-bearing entries in a live main window were wrapped". The universal interceptor is `::menu_invoke_logged` (issue 0930), which the doc predates and never names. Build against `::menu_invoke_logged`.

3. ⚠ SAME DOC, §4 vs §5, CONTRADICT EACH OTHER. §4: "Invocation provenance is visible." §5: the log "records the *same* line ... whether the user pressed Ctrl+X or crawled through the E-dialog." §5 is right and §4 is right only about the call sites. A reader who stops at §4 will try to build this by tailing Xschem.log and it cannot work.

4. ⚠ SAME DOC, §4: "There is already a holding-area buffer that stages recent raw events and emits one coalesced outcome — the natural tap point." Overstated. It is `actionlog_pending` — one `char[300]` slot plus `actionlog_pending_inst` — and it absorbs exactly one `select_at` into a following `descend`. No ring, no cost, no provenance.

5. ⚠ `keybinding_chord_label` PRINTS GIBBERISH FOR UNNAMED KEYSYMS. Its `named` dict has 10 entries; anything else outside 33..126 renders `key<N>`. The live sheet prints `Alt+key65474  Raise CIW window`. A coach telling a user to "press Alt+key65474" is worse than saying nothing.

6. ⚠ FOUR REGISTRY ROWS ARE DOCUMENTED UNREACHABLE. `init_input_bindings` carries "⚠ THESE FOUR ROWS ARE UNREACHABLE" over the four `ACTX_OVER_GRAPH` wheel rows, because `handle_button_press` returns at `waves_selected()` fourteen branches before `handle_mouse_wheel` runs. They are kept deliberately for the `xschem bind`/csv round-trip. A coach must not recommend a chord from a row that cannot fire. `generate_keybindings_text` skips `graph.forward` with a bare `continue` (the blind spot the task named — confirmed).

7. ⚠ `toolbar_list` IS `set_ne` UNDER "Public variables that we allow to be overridden". A user rc that sets `toolbar_list` WINS, so a bell appended to the default list silently never appears for that user. Same shape for `notify_style`.

8. ⚠ THE ICON MUST GO IN `src/resources.tcl`, NOT A NEW FILE. That file is already in the install list and already holds 154 `image create` entries. Shipping a new .xpm/.gif instead means editing src/Makefile.in and re-running ./configure — the issue-0423/0424 class where `make install` ships nothing and the installed binary segfaults at startup (exit 139).

9. ⚠ `xschem::notify` SUPPRESSION IS TOTAL, LOG INCLUDED (decision D7, stated in ciw.tcl). A coach using `-once` leaves no durable record of the nudge it swallowed, so "the coach said nothing" and "the coach was latched" are indistinguishable after the fact. Build the counter's own persistence; do not infer it from the log.

10. ⚠ THE STATUSBAR FALLBACK IS A SHARED, LAST-WRITER-WINS FIELD. `.statusbar.12` is also written by hilight.c (`*BUSY*`) and CLEARED unconditionally at the end of `propagate_logic()`, and it clips silently at ~28 characters. It is not a place to park a coach hint.

11. ⚠ THE `accel` COLUMN IS THE ONLY TABLE THAT KNOWS ABOUT THE LEGACY CHORDS, AND IT IS EXPLICITLY NON-BINDING. actions.csv's own header: "The 'accel' column is a DISPLAY string only and binds nothing." 76 of its 109 chord claims have no registry row and nothing re-checks them against the switch. I spot-verified one (`edit.select_all` accel `Ctrl+A` vs `case 'a': ... rstate == ControlMask -> select_all()`) and it was TRUE — one sample, not a census. Using `accel` as the coach's source without a row asserting it against the switch is how the coach starts telling users to press keys that do nothing.

12. ⚠ MY OWN SUBSTRING PROBE PRODUCED A FALSE POSITIVE, AND IT IS THE SAME TRAP AT MEASUREMENT TIME. `string first "Ctrl+A" $txt` returned true because the sheet contains `Ctrl+Alt+v`. The anchored `regexp -line {^  Ctrl\+A\s}` returned 0. Any completeness check over the cheat sheet must anchor the chord.
