# Toward a Virtuoso-grade CIW: action-log coverage analysis and a plan to close the gap

**Date:** 2026-07-02 · **Branch:** `fluid-editing` · **Author:** coverage audit session

This is a global write-up of one problem: *the XSCHEM action log and CIW record
only part of what a user does, and none of what commands return.* It states the
goal (parity with, then improvement on, Cadence Virtuoso's CIW), maps where we
are, explains why the gaps exist structurally rather than incidentally, and lays
out a solution that is one coherent design rather than a pile of patches.

The detailed per-surface defects are filed as issues **0061–0071** (index issue:
0071). This document is the layer above them — the *why* and the *shape of the
fix*. The feature spec is `doc/claude/specs/action_logging.md`; the checklist is
`action_logging_checklist.md`.

> **Thesis.** Coverage is not missing by accident. Logging was installed at four
> *GUI edges*, while the mutating commands at the *core* stay silent. To reach —
> and beat — Virtuoso, move the record point from the edges to the core, and add
> a second stream for command output. One choke point, two streams.

---

## 1. The benchmark: what Virtuoso's CIW actually gives the user

Cadence Virtuoso's **CIW** (Command Interpreter Window) is the gold standard this
feature is chasing. What makes it valuable is not the window — it is the
*discipline* behind it:

1. **Every user action echoes as a runnable command.** Draw a wire, place an
   instance, move a selection, change a property — the CIW prints the equivalent
   **SKILL** call (`schCreateWire`, `dbCreateInst`, `hiMove`, …). The GUI is a
   thin skin over a scriptable core; the CIW is that core narrating itself.
2. **One transcript carries three things:** the echoed commands (input), the
   **return value** of each, and any **warnings/errors**. You read one scrolling
   log and see cause *and* effect.
3. **A command line at the bottom** evaluates SKILL in the same interpreter, with
   history and completion.
4. **A persistent on-disk transcript** (`CDS.log`) mirrors the session.
5. **It teaches.** Because every click prints its SKILL form, the CIW is how users
   learn the scripting API — do it once by hand, read the command, script it next
   time.

The essential property: **the GUI and the script language are the same surface,
and the CIW is the faithful, complete, replayable narration of that surface —
input and output together.**

XSCHEM already has the raw ingredients: one dispatcher (`xschem <subcommand>` in
`scheduler.c`), a Tcl interpreter, a CIW window (`src/ciw.tcl`), and an action log
(`log_action`, `src/util.c`). What it lacks is *completeness of coverage* and
*output capture*. Those two gaps are this document's subject.

---

## 2. How XSCHEM logs today

Two functions in `src/util.c` are the sink:

- `log_action(fmt, …)` — writes one replayable `xschem …` line to the log file
  **and** mirrors it to the CIW via `log_action_echo` → `ciw_echo`.
- `log_action_noecho(fmt, …)` — file only (used by the CIW's own typed-command
  recorder so it does not double-echo).

The CIW (`src/ciw.tcl`) shows the log-file stream in its upper pane and offers a
Tcl command entry in the lower pane. Typed commands are echoed (`> cmd`),
evaluated, their **result shown in the pane only**, and the command (not the
result) appended to the file — raw on success, `# failed: <cmd>` on error, so the
file stays `source`-able (**spec decision 7**).

Crucially, `log_action` is called from exactly **four GUI edges**:

| Edge | Where | What it captures |
|---|---|---|
| **File menu** | `menu_action_logged` via `build_menu_from_table` (`action_registry.tcl`) | every File-menu pick |
| **Bound-key dispatch** | `dispatch_input_action` (`callback.c:3409`) | keys/buttons/wheel that are *registered* |
| **Gesture ENDs** | `end_move_copy_logged` + `new_wire/line/rect/arc/polygon` (`callback.c`, `actions.c`) | drag completions |
| **Context menu** | `context_menu_action` retval table (`callback.c:2697`) | right-click picks |

Everything else that mutates state does so through a C subcommand that **does not
self-log** — the only self-loggers are `create_instance`, `saveas`, `load`,
`load_new_window`, `library_manager`, and `exit`. That asymmetry is the whole
problem.

---

## 3. The coverage map

### 3.1 What *is* logged

File menu · registered bound keys (zoom/scroll/undo/redo/hilight family/snap/
place-inserts/…) · drag gestures (wire/line/rect/arc/polygon, move/copy, pan,
zoom-box, place-symbol, place-text) · context-menu picks · `create_instance`,
`saveas`, `load`, `load_new_window`, `exit` · Phase-3 mints (scroll/pan/snap/
toggles/polygon).

### 3.2 What is *not* logged — the gaps (issues 0061–0070)

| Surface | Examples | Issue | Sev |
|---|---|---|---|
| **Non-File menubar** | Edit Cut/Delete/Undo/Redo, flip/rotate, Tools wire-surgery, Symbol generators, Highlight rename-dups, annotate-op, Netlist | 0061 | HIGH |
| **Toolbars** | main toolbar (save/cut/undo/trim/netlist/…), recent-component palette, tab bar | 0062 | HIGH |
| **Property dialogs** | wire/rect/arc/line/poly/text property forms, global attrs, external-editor edits, object reorder — `editprop.c` has **0** `log_action` | 0063 | HIGH |
| **Library Manager** | git check-in/checkout/revert, create/rename/delete/copy cell·view·lib | 0064 | MED |
| **Net-hilight-style editor** | style Apply/OK | 0065 | LOW |
| **`xschem set`** | Options/View toggles, snap/grid, netlist-format, header, **change-layer** | 0066 | MED |
| **Raw Tk binds** | `+`/`-` bus-index, cadence hilight 8/9/0/F5, apply_hilight, place_libmgr, deeploc_note | 0067 | MED |
| **Un-migrated legacy keys** | clipboard Ctrl+C/X/V/Del, orient-in-place, property Q, net-label ports, make_symbol A, align, trim/break | 0068 | MED |
| **Gesture `#` stubs** | paste/merge drop, place-symbol-pin, rotate/flip-during-move | 0069 | MED |
| **Command output/results** | results, `puts`, netlist/ERC/check reports reach neither CIW nor file | 0070 | HIGH |

Pre-existing, related, not re-filed: **0003** (stdin/TCP channels), **0004** (TCP
auth), **0005** (stable object referents for click-select / control-point),
**0055** (libmgr locate arg — FIXED).

---

## 4. Root-cause analysis: edges vs core

Two independent root causes produce the whole table.

### 4.1 Logging is welded to entry points, not to the command

Because the mutating subcommands are silent, coverage exists only where a wrapper
was added. There are dozens of entry points (eight menus, two toolbars, a tab
bar, N property dialogs, the Library Manager, raw rc binds, the legacy key
switch), and each unwrapped one is a hole. This is the same *mechanism-vs-policy*
mistake documented in
`code_analysis/hardcoded_to_data_driven_keybindings_tutorial.md`, one level up:
the *record* of an action is policy that has been scattered across every place an
action can be *triggered*, instead of living at the single place it is *performed*.

The File menu is the proof of the alternative: it is table-generated and wrapped
once (`menu_action_logged`), so it is uniformly covered. Every hand-written menu
is a hole precisely because it skipped that funnel.

### 4.2 The file is defined as replay-only, so output has nowhere to go

Spec decision 7 keeps results out of the log file so the file stays `source`-able.
That was the right call for *replay*, but it means the file is structurally
incapable of carrying output, and the CIW only shows output for commands *typed
into it* (via `ciw_capture_puts`, scoped to `ciw_exec`). A menu/key/toolbar
command's return value and its `puts` are discarded; netlist/ERC/`check` reports
go to a separate infowindow or the statusbar or stderr. So "the CIW is a faithful
transcript" is false today for output — the second half of Virtuoso's value
proposition is entirely absent.

---

## 5. Proposed solution — one choke point, two streams

The design goal is to make the two root causes go away at their source, not to
add a 40th wrapper.

### 5.1 Principle: record where the action is *performed*, not where it is *triggered*

Move the record point to the **core**: have the mutating `xschem` subcommands
self-log their canonical replayable form. Then menus, toolbars, keys, dialogs, and
scripts are all covered *by construction*, because they all funnel through the
same dispatcher. This is the single highest-leverage change and it collapses
issues 0061, 0062, 0063 (partly), 0066, 0067, 0068 into one mechanism.

The one hazard is **double-logging on replay**: when the log is `source`-d, each
line calls the subcommand, which must *not* log again. XSCHEM already solves local
instances of this (the slick property form logs from Tcl precisely because C
`apply_instance_properties` stays silent; scheduler coordinate-form replay
deliberately bypasses `new_*`). Generalize that into one flag:

```
xctx->suppress_action_log   /* set while sourcing/replaying or during a
                               programmatic/internal call; log_action() early-returns */
```

Wrap the log-file `source` path and any internal command invocation with it. With
that guard, a subcommand can self-log unconditionally and replay stays clean. This
is the "self-log at core" option named in issue 0071 §2.

**Migration, not big-bang.** Not every subcommand needs a hand-written line at
once. Order of attack:
1. Add the suppress-log guard + a `log_action` helper that takes the already-parsed
   argv (a generalization of `callback.c`'s `log_action_argv`).
2. Self-log the high-value silent mutators first: `cut`, `delete`, `paste`,
   `undo`/`redo`, flip/rotate family, `trim_wires`/`break_wires`, `align`,
   `setprop`/`edit_prop` commit, `change_layer`, `change_elem_order`, the symbol
   generators.
3. Delete the now-redundant per-edge intentions (the File-menu wrapper can stay;
   it becomes belt-and-suspenders, or is dropped once cores self-log).

### 5.2 Two streams: replay-pure file, full transcript CIW (fixes 0070)

Separate *replay* from *transcript* instead of forcing one file to be both.

- **Stream 1 — the replayable log** (unchanged contract): only `xschem …`
  commands, `source`-able. This is `Xschem.log` as it exists.
- **Stream 2 — output/results**, delivered two ways:
  - **CIW pane:** every command — however invoked — echoes its input line (already
    happens via `log_action`) *and* its result/error. Add a sink
    `log_result(text, tag)` that mirrors to the CIW with the `result`/`error` tag.
    Wire it into `ciw_exec` (today pane-only for typed commands) and into the
    GUI-dispatch path (capture `Tcl_GetStringResult` after menu/key/toolbar
    dispatch). Redirect the netlist/ERC/`check`/`print_hilight_net` report writers
    to also echo the CIW.
  - **File:** write results to the log file as **comment lines** (`#= <result>`,
    `#! <error>`), so the file stays `source`-able (comments are ignored on
    replay) yet carries the full transcript. This is option (a)+(b) from issue
    0070; it is the design that matches Virtuoso's single-transcript feel without
    breaking replay.

Decision needed from the spec owner: comment-in-file vs a separate `Xschem.out`
sidecar. Recommendation: comment-in-file — one artifact, one scroll, still
`source`-able. (Sidecar stays an option if replay purists object.)

### 5.3 Replayable forms for the gesture stubs (fixes 0069, needs 0005)

The `#`-marker gestures (paste/merge drop, place-symbol-pin, rotate/flip-during-
move) need genuine subcommands:
- **place-symbol-pin:** read the pin back post-drop and emit `xschem
  add_symbol_pin x y …` (the `PLACE_SYMBOL`/`PLACE_TEXT` read-back path already
  exists at `callback.c:1587/1606`).
- **paste/merge drop:** mint `xschem paste_at dx dy` (or a merge variant) over the
  current clipboard/merge buffer.
- **rotate/flip-during-move:** either an anchor-preserving transform subcommand or
  decompose into `move_objects` + `rotate/flip` about the recorded anchor.

Click-select and control-point drags (0005) need **stable object referents** — the
one genuinely hard, deferred piece. It touches the object model and file format
(see 0005 and `code_analysis/stable_handles_extension_strategy.md`). It is the
last mile to *full* replay and can trail the rest.

### 5.4 Library Manager and config (fixes 0064, 0066-config)

Library-Manager ops mutate git/disk outside the schematic buffer; "replay" means
re-running the library op. Give them `xschem library_manager <op> <lcv> …`
subcommands (extending the argument-carrying form issue 0055 established) and let
those self-log. Session config (`xschem set …`) splits: content-affecting sets
(`rectcolor`/change-layer, `header_text`) self-log like any mutator; pure-display
sets get a `nolog` classification (extend the Phase-3 toggle-mint precedent), so
the transcript is not drowned in view noise but content changes are faithful.

---

## 6. Where this lands vs Virtuoso

| Capability | XSCHEM today | XSCHEM proposed | Virtuoso CIW |
|---|---|---|---|
| GUI action → replayable command | partial (4 edges) | **complete (core self-log)** | complete |
| Command entry + history + completion | ✅ (CIW) | ✅ | ✅ |
| Result of each command in transcript | typed-only | **all commands** | ✅ |
| Warnings/errors in transcript | typed-only | **all commands** | ✅ |
| Reports (netlist/ERC/check) in transcript | ✗ (infowindow) | **echoed to CIW** | ✅ |
| Persistent on-disk transcript | replay-only file | **replay file + output comments** | `CDS.log` |
| `source`-able replay of a session | partial | **complete (guard + referents)** | scriptable |
| Teaches the scripting API by narrating clicks | partial | **yes** | yes (its hallmark) |

The proposed end state matches Virtuoso on every row and **exceeds** it on one:
XSCHEM's file can be *both* a faithful transcript *and* a directly `source`-able
replay script (comments carry output, commands carry actions) — Virtuoso's
`CDS.log` is a transcript you read, not a script you replay verbatim.

---

## 7. Roadmap (suggested order)

1. **Output stream (0070).** Highest user-visible value, independent of the core
   refactor. Add `log_result` + comment-lines + CIW echo of GUI results and
   reports. Ship the "full transcript" half first.
2. **Suppress-log guard + core self-log, high-value mutators (0061/0062/0063/
   0066/0067/0068).** The structural fix; retire per-edge wrappers as cores take
   over.
3. **Gesture subcommands (0069).** Mint `add_symbol_pin`/`paste_at`/transform;
   remove the `#` stubs.
4. **Library Manager + config classification (0064/0066).**
5. **Net-hilight-style editor (0065).** Small, self-contained.
6. **Stable referents (0005).** The hard, deferred last mile to full click-select
   replay. Its own project.
7. **Command channels (0003/0004).** stdin REPL + TCP logging and TCP auth — the
   remaining non-GUI channels.

---

## 8. Open decisions for the spec owner

- **D1 — output in file:** comment-lines in `Xschem.log` (recommended) vs separate
  `Xschem.out` sidecar vs CIW-only. (Issue 0070.)
- **D2 — record point:** self-log at C core with a replay-suppress guard
  (recommended, collapses six issues) vs keep wrapping edges one by one. (Issue
  0071 §2.)
- **D3 — config verbosity:** which `xschem set` variables are `nolog` (pure
  display) vs logged (content/behavior). (Issue 0066.)
- **D4 — scope of "faithful":** do we commit to full click-select replay
  (requires 0005 object-model surgery) or accept `#`-marker coordinates for
  selection, matching today's spec decision 4?

Answering D1 and D2 unblocks the bulk of the work; D3 is a tuning pass; D4 gates
only the final last-mile.

---

## 9. Implementation log

**2026-07-02 — slice 1 (D1 + D2 infrastructure + first mutators).** User approved
D1 (comment-lines) and D2 (self-log at core + guard). Landed:

- **Guard/dedup plumbing** — three globals (`actionlog_cmd_logged`,
  `actionlog_suppress_echo`, `actionlog_suppress`) + guards in `log_action`/
  `log_action_noecho`; `log_output()` writes `#=`/`#!` per-line comments; Tcl
  surface `xschem log_action -result|-error|-reset|-emitted|-suppressecho`.
- **Dedup wired** into all four recorders (`dispatch_input_action`,
  `context_menu_action`, `menu_action_logged`, `ciw_exec`): a core self-log is
  written exactly once regardless of the path that triggered it.
- **First mutators self-log** at their `scheduler.c` core: `cut`, `delete`,
  `undo`, `redo` — now recorded from menu, toolbar, key, and context menu alike.
- **Output stream (§5.2)** — CIW-typed and menu-pick results/errors now reach the
  file (as comments) and the CIW pane.
- **Test** `tests/headless/test_selflog_output.tcl` (raw self-log, wrapper dedup,
  `-emitted`, result/error/multi-line comments, source-ability) — 11 checks, added
  to `full_audit.sh`. Existing log tests (dispatch/context-menu/gesture/libmgr)
  still pass; golden regression clean.

This proves the thesis: adding one guarded `log_action` line at a command's core
closed that command across *all* its entry points at once, with no per-edge
wrapper. Remaining mutators follow the same one-line pattern (roadmap §7 step 2).

**2026-07-02 — slice 2 (transform family self-log, part of 0061/0062).** Continued
roadmap §7 step 2 with the geometry-transform verbs. Landed:

- **Seven mutators self-log** at their `scheduler.c` cores: `flip`, `flipv`,
  `rotate` (each logs `xschem <v> x0 y0` with the pivot, so replay is
  deterministic), `flip_in_place`, `flipv_in_place`, `rotate_in_place` (per-object
  pivot, bare form), and `align`. The flip/rotate cores self-log **only in the
  standalone `else` branch** — the `STARTMOVE`/`STARTCOPY` branches are flip/rotate-
  *during-move*, an unfinished gesture logged by the move END (issue 0069), so
  logging there would double-count.
- **Closed by construction across every edge at once:** these verbs were driven by
  hand-written Edit-menu items (`-command {xschem flip}`, `xschem.tcl`), the
  context menu, the toolbar, and the registered Shift-F/V/R · Alt-F/V/R/U keys.
  The menu/ctx/toolbar paths were previously **unlogged** (0061/0062); the key path
  logged via its wrapper. One core line covers all of them, and the existing
  `actionlog_cmd_logged` dedup makes the key-wrapper skip its now-redundant copy.
- **Test** `test_selflog_output.tcl` extended with a transform-family section
  (8 checks: each verb self-logs exactly once + wrapper dedup for `rotate`) — all
  pass. `test_action_log_dispatch` / `test_gesture_end_log` still green;
  `test_phase3_mints`' two `snap` failures are pre-existing (verified on baseline),
  unrelated.

Next mutators (same pattern): `paste`/`merge` (needs the gesture `paste_at` form,
0069), `trim_wires`/`break_wires`, `setprop`/`change_layer`/`change_elem_order`
(arg-carrying — log the parsed form), symbol generators (`make_symbol`).

**2026-07-02 — slice 3 (wire surgery self-log, part of 0061/0062).** Same one-line
pattern, wire-surgery verbs:

- `trim_wires` → `xschem trim_wires` (no args, unconditional). Its core calls the
  `trim_wires()` *C function*, which is also reached internally by `align` and
  gesture autotrim — those do **not** hit the subcommand case, so no double-log.
- `break_wires` → emits the **exact canonical form**: bare `xschem break_wires`
  when `remove==0`, else `xschem break_wires <n>` (the `Ctrl-!` "remove running-
  through" variant is `xschem break_wires 1`). Preserving the arg keeps replay
  faithful.
- Both were driven raw from the Tools menu (`-command "xschem trim_wires"`) and the
  toolbar (`toolbar_add ToolJoinTrim "xschem trim_wires"`) — previously unlogged
  (0061/0062) — plus the registered `&` / `!` / `Ctrl-!` keys (wrapper → now dedup).
- `test_selflog_output.tcl` gains a wire-surgery section (4 checks: trim/break bare/
  break-with-arg + trim wrapper dedup) — all pass (24 total in the file now).

(`wire_cut` — the mouse-position break at `Alt-Right`/`Alt-Shift-Right` — is deferred
with the other coordinate/gesture forms, 0069.)

**2026-07-02 — slice 2/3 review remediation (high-effort code review).** A workflow
review of the two self-log commits surfaced a correctness-of-claims problem and two
pre-existing bugs the diff touched. Addressed:

- **Keyboard shortcuts are NOT covered — claims corrected.** The Shift-F/V/R and
  Alt-F/V/R/U keys (and `&`/`!` for trim/break) are handled by callback.c's *inline
  legacy switch* (`case 'F'/'R'/'v'/'V'/'u'/'&'/'!'`), which calls `move_objects`/
  `trim_wires`/`break_wires_at_pins` directly and never enters the scheduler branch —
  so the self-log does **not** fire for them. This is not a regression (those keys
  were never logged) but the slice-2/3 comments, commit messages and test overstated
  it. The self-log genuinely covers the **menu item, toolbar, context menu and any
  scripted `xschem <verb>`** — real, previously-unlogged gains. The keys are the
  un-migrated-legacy-key gap (issue 0068); closing them means teaching those inline
  handlers to log (or routing them through the dispatcher).
- **Read-only holes closed (0041).** `flip`/`rotate`/`trim_wires` had
  `scheduler_readonly_reject`; `flipv`, `flip_in_place`, `flipv_in_place`,
  `rotate_in_place` and `break_wires` did **not** — so via menu/script they mutated a
  read-only design, and the diff made it worse by *logging* the illegal edit. Added
  the guard to all five (the inline key handlers already had `readonly_block()`).
  Test §3d asserts each rejects with no log line. (`break_wires_at_pins` does its own
  conditional `push_undo`, so no undo bug — that review sub-claim was refuted.)
- **`rotate_in_place` gesture geometry bug fixed.** Its `STARTMOVE`/`STARTCOPY`
  branch used `FLIP|ROTATELOCAL` (copy-pasted from `flip_in_place`), so a rotate-in-
  place *during a move/copy* mirror-flipped instead of rotating. Both the standalone
  branch and callback.c's inline Alt-R use `ROTATE|ROTATELOCAL`; corrected to match.
  Pre-existing, unrelated to logging, but confirmed and trivial so fixed here.
- **Minor:** `break_wires` self-log canonicalized to bare vs `1` (the function reads
  `remove` as a boolean, so `%d` of e.g. `2` was misleading); `align` gained a
  trailing `Tcl_ResetResult` so it doesn't leak a sub-call's stale interp result.
- **Accepted as-is:** transforms/surgery self-log even on an empty selection (a
  replayable no-op line). Consistent with slice-1 `cut`/`delete` and with Virtuoso's
  narrate-every-action model; not gated.

**2026-07-02 — slice 4 (keyboard shortcuts closed, issue 0068 for these verbs).**
The F4 gap above is now closed for the transform/surgery family. Each inline handler
in callback.c's legacy key switch got a `log_action` in its **standalone branch**,
emitting the same canonical form the scheduler does:

  Shift-F `case 'F'` → `xschem flip x0 y0`      Alt-F `case 'f'`/EQUAL_MODMASK → `xschem flip_in_place`
  Shift-R `case 'R'` → `xschem rotate x0 y0`    Alt-R `case 'r'`/EQUAL_MODMASK → `xschem rotate_in_place`
  Shift-V `case 'V'` → `xschem flipv x0 y0`     Alt-V `case 'v'`/EQUAL_MODMASK → `xschem flipv_in_place`
  Alt-U   `case 'u'`/EQUAL_MODMASK → `xschem align`
  `&` `case '&'` → `xschem trim_wires`          `!` `case '!'` → `xschem break_wires` (Ctrl-`!` → `... 1`)

- **Pivot** = `xctx->mx_double_save`/`my_double_save` — the anchor `move_objects`
  actually uses, identical to the scheduler's `x0`/`y0`.
- **No double-log:** a live keypress reaches *only* the inline handler (these chords
  have no entry in the input-binding table, so `dispatch_input_action` returns 0 and
  the legacy switch runs); the scheduler branch is reached only by a text
  `xschem <verb>` command (menu/toolbar/script/replay). The two paths are disjoint,
  so exactly one line is written per action regardless of how it was invoked.
- **Read-only safe:** each handler already `break`s on `readonly_block()` before the
  edit, so the log fires only for an edit that actually happened.
- **Gesture-safe:** logging sits in the standalone `else` only; rotate/flip-*during-
  move* stays unlogged (gesture, 0069).
- **Test** `test_selflog_output.tcl` §3e drives all ten chords via `xschem callback`
  (headless `event generate` is unreliable) and asserts a *new* matching line per
  chord (count-delta ≥ 1, so a line from an earlier section can't mask a dead
  handler). Sabotage-verified: neutralizing one handler's `log_action` fails exactly
  its check and no other. 39 checks total, all pass.

With this, the transform/surgery verbs are logged from **every** live entry point —
menu, toolbar, context menu, keyboard, and script. `wire_cut` (mouse-position break)
remains the only wire-edit key still deferred (coordinate/gesture form, 0069).
