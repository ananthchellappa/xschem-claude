# Spec — Action Logging & CIW

**Feature:** a replayable session log of user actions, plus a live log/command
window (the **CIW**, Command Interpreter Window, after Virtuoso's).
**Branch:** `feature/action-logging`. **Owner of intent:** user (ananth.ch).
**Companion plan (analysis + phasing detail):** `claude_suggs/plan_action_logging.md`.

This document is the spec — *what* the feature is and the decisions that bind it.
The plan doc holds the codebase analysis and implementation phasing.

---

## 1. The log file

- xschem writes a log to **`Xschem.log` in the current working directory** it was
  launched from.
- If that name is taken, use the first free name in the increment sequence:
  `Xschem.log.1`, `Xschem.log.2`, … (same idiom as the `untitled.sch` /
  `untitled-1.sch` namer).
- **`--logdir <dir>`** overrides the directory. The directory is created if
  absent; if it cannot be created (or exists but is not a directory), xschem
  **exits with an error message** (exit 1). File-open failure inside a good
  directory is non-fatal — logging is simply disabled.
- The log is opened only for an **interactive session (`has_x`) OR when
  `--logdir` is given explicitly** — headless script/netlist/test runs don't
  litter the cwd, while automation can opt in.
- **`--nolog`** disables the feature entirely: no log file AND no CIW auto-open
  (§3). For test/automation runs, where short-lived windows also leak WSLg
  ghost frames (issue 0002). Combining it with `--logdir` is contradictory →
  xschem **exits with an error** (exit 1). Manual `ciw_create` still works
  under `--nolog` as a plain command console (commands run and echo pane-side,
  nothing is recorded).
- The log has its **own `FILE*`** (`actionlog_fp`), strictly separate from the
  `--log`/`errfp` debug stream: replayable commands must never be mixed with
  debug output.
- The header line is a Tcl comment (`# xschem action log …`) so the file is
  source-able from line 1.

## 2. What gets logged — replayable actions

- **Every user action** is logged.
- Each logged line MUST be a command executable in Tcl — a real `xschem …`
  command — so the log is **replayable**, not a prose audit.
- **Granularity = the action's *effect***, when that effect is achievable
  through Tcl. A multi-event gesture collapses to its single resulting command:
  - RMB click+release without moving → context-menu pick → the chosen action's
    command.
  - RMB press+drag+release → one zoom-rectangle action →
    `xschem zoom_box x1 y1 x2 y2`.
- Actions with **no Tcl form** get a non-replayable `#`-comment marker, e.g.
  `# <action not reproducible through TCL>`. For click-select specifically, the
  marker records what and where (`# selected instance at <x> <y>`), upgradeable
  once a Tcl referent exists (see §6).
- Commands typed into the CIW (§3) are **also written to the file** — they are
  already replayable Tcl, so the file stays a faithful, sourceable session
  record. Their results/errors are NOT written to the file (pane-only), keeping
  the file sourceable. A typed command that **errored** is written as a
  `# failed: <cmd>` comment instead of raw (replaying it would abort the
  `source`); recording therefore happens after evaluation.

### Action sources (the three layers)

| Layer | Where | Notes |
|---|---|---|
| A. Bound keys/buttons/wheel | `dispatch_input_action()` (`callback.c`) | Tcl-backed actions log their `d->tcl` verbatim; C-backed actions need the canonical command surfaced to C from the single source (`actions.csv` col 6 / `ActionDef`) — never hand-written per call site. |
| B. Right-click context menu | `context_menu_action()` (`callback.c`) | Today an int→direct-C-call switch; must emit (cleanest: *invoke*) the equivalent `xschem …` command. |
| C. Multi-phase drag gestures | `zoom_rectangle()`, move/copy/wire/line/rect/poly END states | Log at the gesture's END, where final params are known. |

Known coverage gaps to be closed by minting subcommands (thin wrappers over
existing C): `pan`, `scroll`, `snap` halve/double, middle-button pan.

## 3. The CIW — live log window

A standalone Tk toplevel, similar in spirit to Virtuoso's Command Interpreter
Window. Not full-featured for v1.

- **Two areas**, separated by a **user-adjustable split** (a vertical
  `panedwindow` with a draggable sash — natively supported by Tk):
  - **Upper pane — log display.** Read-only text widget. Every line written to
    the action log is mirrored here in real time (fed from the single
    `log_action()` sink — one extra call at one place, via a guarded Tcl proc).
  - **Lower pane — command entry.** Starts at one line in height (slightly
    taller/padded for aesthetics). The user enters commands that are fed to the
    xschem Tcl interpreter. Dragging the sash resizes the two panes (e.g. to
    grow the entry area or give the log more room). UX refinements (2026-06-11,
    user feedback): the sash is a **wide raised bar** (the Tk default hairline
    was undiscoverable and a poor drag target); the entry is a **text widget
    whose height follows the sash** (an `entry` cannot grow — dragging just
    left dead space), so long commands wrap into view in a taller entry area;
    **Return executes** (never inserts a newline); neither pane can be
    collapsed below a minimum. Shell-style line editing (2026-06-11, pulled
    forward from §6): **Ctrl-Backspace** deletes the previous word
    (whitespace-skipping); **Up/Down** walk the command history
    (history-always semantics; the first Up stashes the half-typed draft,
    Down past the newest entry restores it; consecutive duplicates collapse;
    failed commands are recalled too).
- **Echo (Virtuoso style):** a typed command appears in the log pane, followed
  by its return value or error message, visually distinct from action-log lines.
- **File logging of typed commands:** yes (see §2) — commands go to
  `Xschem.log`; results/errors stay pane-only.
- **Opening: auto-open at startup** for interactive sessions (`has_x`) — the
  same condition under which the action log opens. Closing the CIW does not
  exit xschem; lines keep flowing to the file regardless of whether the CIW is
  open. (If auto-open proves intrusive, an rc toggle may be added later — not
  v1.)

## 4. Decisions (locked)

1. **Log-line format** = whatever is a valid `xschem …` Tcl command (the
   `verb(point1, point2)` notation in the original ask was conceptual).
2. **Default location** = the launch cwd; only `--logdir` overrides.
3. **Granularity** = log the effect; gestures collapse to one command.
4. **Object-reference gap accepted for v1**: click-select cannot be faithfully
   replayed (no Tcl entry point for `find_closest_obj()`; pins/text have no
   stable Tcl referent) → `#`-marker with what/where.
5. **Minimal scope first** — land the smallest useful slice, defer breadth.
6. **CIW echo** = command + result/error in the pane.
7. **CIW typed commands** are written to the log file; results are not. Failed
   commands are recorded as `# failed: <cmd>` comments so the file stays
   source-able.
8. **CIW auto-opens** at startup of interactive sessions, **unless `--nolog`**
   was given; test/automation runs pass `--nolog`.
9. **CIW pane split is user-adjustable** (draggable `panedwindow` sash); the
   entry pane merely *starts* at one line.
10. **`--nolog` + `--logdir` is fatal** (exit 1) — explicitly asking for a log
    location while disabling logging is a confusion worth surfacing.

## 5. Status / phasing

- **Phase 0 — DONE** (commit `4334b00f`): log file + rotation + `--logdir` +
  `log_action()` sink (`util.c`), wired in `main.c`; `xschem.help` documents the
  option; smoke `tests/headless/test_action_log.sh`.
- **CIW — DONE** (this spec §3; built before Phase 1 so the log is visible in
  real time as call sites land). `src/ciw.tcl` (`ciw_create`/`ciw_echo`/
  `ciw_exec`), sourced + auto-opened from `xschem.tcl`; `log_action()` mirrors
  each line to the pane (content passed through a Tcl variable, never
  substituted into the eval string); new subcommands `xschem log_action
  [-noecho] <text>` and `xschem get actionlog_filename`; smoke
  `tests/headless/test_ciw.tcl`.
- **Phase 1 Layer A slice 1 — DONE** (commit `ec8de190`): Tcl-backed actions
  logged at `dispatch_input_action` (verbatim on success, `# failed:` comment
  on error, recorded after evaluation); smoke
  `tests/headless/test_action_log_dispatch.tcl`. Layer B (context menu) open.
- **Phase 1 Layer A slice 2 — DONE** (plan
  `claude_suggs/plan_layerA_slice2_cbacked_logging.md`): C-backed actions log
  the canonical `actions.csv` command, pushed into the C registry at startup
  (`xschem set_action_log_cmd`; csv stays the single source). Equivalence
  audit passed 6 of 7 candidate ids; `attach_labels` excluded via the new csv
  `nolog` column (key = interactive dialog form, csv command = non-interactive
  — not equivalent). Empty-command ids (scroll/pan/gesture/routing) stay
  silent pending Phase 3 minting. Smoke includes the first record→replay
  assertion (replaying the log restores the zoom).
- **`--nolog` — DONE** (decisions 8/10 above; plan
  `claude_suggs/plan_nolog_option.md`): resolves issue 0002 by keeping test
  runs from auto-opening short-lived CIWs; adopted by `run.sh` and the GUI
  smoke invocation pattern; smokes `tests/headless/test_nolog.tcl` + extended
  `test_action_log.sh`.
- **Phase 2** — Layer C (gesture END hooks).
- **Phase 3** — mint `pan`/`scroll`/`snap` subcommands to close coverage gaps.
- **Acceptance test (the real one) — DONE** (`tests/headless/test_action_replay.sh`):
  record → replay → diff across two processes. Process A loads a fixture, is
  driven through bound actions via `xschem callback …`, snapshots state; process
  B loads the same fixture fresh, `source`s A's `Xschem.log`, snapshots; the
  snapshots must match. Diffs the geometry-INDEPENDENT state the log reproduces
  — the relative zoom transform (final/baseline), the colorscheme flag, object
  counts — not the absolute view (origin/absolute zoom depend on the mouse and
  the drawing-area size, which the log does not capture; see issue 0005). Guards
  against a vacuous pass (asserts the transform is non-trivial) and checks the
  log holds the expected replayable commands.

## 6. Future (explicitly not v1)

- `xschem select_at x y` exposing `find_closest_obj()` → click-select becomes
  replayable; stable Tcl referents for pins and text.
- Faithful full-session replay (causal chain: selections, descend/go_back,
  load) — v1 is a per-action, replay-where-possible log.
- CIW niceties: multi-line entry (composing across lines; the entry already
  *displays* wrapped lines), search/filter in the pane, rc toggle for
  auto-open, history persistence across sessions. (Command history itself
  landed 2026-06-11 — see §3.)
