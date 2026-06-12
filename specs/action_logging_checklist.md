# Action Logging & CIW — spec checklist

One row per smallest checkable spec, derived from `specs/action_logging.md`.
Update the **Implemented?** column as features land (yes / no / partial / deferred).
Statuses are verified against the code, not the phasing notes, before flipping.

## 1. Log file (spec §1) — Phase 0

| # | Spec | Implemented? |
|---|------|--------------|
| 1 | Log written to `Xschem.log` in the launch cwd | yes |
| 2 | Name taken → first free `Xschem.log.1`, `.2`, … | yes |
| 3 | `--logdir <dir>` overrides the log directory | yes |
| 4 | `--logdir` directory created if absent | yes |
| 5 | Uncreatable / non-directory `--logdir` → error message + exit 1 | yes |
| 6 | File-open failure inside a valid dir is non-fatal (logging disabled) | yes |
| 7 | Log opened only for interactive (`has_x`) sessions or explicit `--logdir` | yes |
| 8 | Log has its own `FILE*` (`actionlog_fp`), separate from `--log`/`errfp` | yes |
| 9 | Header line is a Tcl comment → file source-able from line 1 | yes |
| 10 | `--logdir` documented in `xschem.help` | yes |
| 58 | `--nolog` disables the log file (even in interactive sessions) | yes |
| 59 | `--nolog` suppresses the CIW auto-open | yes |
| 60 | `--nolog` + `--logdir` → error message + exit 1 | yes |
| 61 | Test invocations pass `--nolog` (`run.sh`, GUI smoke pattern; exceptions: the logging/CIW smokes) | yes |
| 62 | Manual `ciw_create` under `--nolog` = plain console, nothing recorded | yes |
| 63 | `--nolog` documented in `xschem.help` | yes |

## 2. What gets logged (spec §2)

| # | Spec | Implemented? |
|---|------|--------------|
| 11 | Every user action is logged | partial — bounded by design: click-select (issue 0005, row 17), stdin-REPL/TCP commands (issue 0003), menu picks, and keys still living in the un-migrated C switch (they never reach `dispatch_input_action`; they log only where a Layer B/C hook covers their effect) |
| 12 | Each logged action line is an executable `xschem …` Tcl command (replayable) | yes |
| 13 | Granularity = the action's effect; multi-event gestures collapse to one command | yes (Layer C: one command/marker per completed gesture; manhattan wire = one line per stored segment) |
| 14 | RMB click → context-menu pick logged as the chosen action's command | yes (replayable subset, row 25; dialogs/object-ref picks = `#` markers) |
| 15 | RMB press+drag+release logged as `xschem zoom_box x1 y1 x2 y2` | yes |
| 16 | Actions with no Tcl form logged as a `#` non-replayable comment marker | partial (Layer B dialogs/object-ref + Layer C paste-drop/sympin/rot-flip-move/point-edit; click-select still silent, row 17) |
| 17 | Click-select marker records what and where (`# selected instance at <x> <y>`) | no |
| 18 | Commands typed into the CIW are written to the log file | yes |
| 19 | Typed-command results/errors are NOT written to the file (pane-only) | yes |
| 20 | Failed typed command written as `# failed: <cmd>` comment (file stays source-able) | yes |
| 21 | Typed-command recording happens after evaluation (so failure is known) | yes |

## 3. Action sources — the three layers (spec §2, Phases 1–3)

| # | Spec | Implemented? |
|---|------|--------------|
| 22 | Layer A: bound keys/buttons/wheel logged at `dispatch_input_action()` | yes (Phase 3 minted the 14 empty-command ids; only view.zoom_rect stays silent by design — its END logs `zoom_box`; nolog rows excluded: attach_labels + the 14 gesture starts) |
| 23 | Layer A: Tcl-backed actions log their `d->tcl` verbatim | yes |
| 24 | Layer A: C-backed actions log the canonical command from the single source (`actions.csv` col 6 / `ActionDef`), never hand-written per call site | yes |
| 25 | Layer B: context-menu picks emit the equivalent `xschem …` command (replayable picks); dialogs/object-ref picks get `#` markers; gesture-start picks deferred to Layer C | yes |
| 26 | Layer C: zoom-rectangle gesture logged at gesture END with final params | yes |
| 27 | Layer C: move/copy gesture END logged | yes (translation + kissing; placement drops log the placed instance/text; rot/flip-during-move + paste/sympin drops = `#` markers) |
| 28 | Layer C: wire/line/rect/poly draw gesture END logged | yes (wire/line/rect/arc/polygon commands at the new_* store sites; polygon coordinate form minted in Phase 3) |
| 29 | Mint `pan` subcommand (coverage gap) | yes (`xschem pan up\|down\|left\|right` half-step + `xschem pan dx dy` drag replay) |
| 30 | Mint `scroll` subcommand (coverage gap) | yes (`xschem scroll up\|down\|left\|right`) |
| 31 | Mint `snap` halve/double subcommand (coverage gap) | yes (`xschem snap half\|double`) |
| 32 | Middle-button pan gesture logged | yes (`xschem pan dx dy` at the un-pan sites; no-motion clicks silent) |

## 4. The CIW — live log window (spec §3)

| # | Spec | Implemented? |
|---|------|--------------|
| 33 | CIW is a standalone Tk toplevel | yes |
| 34 | Two areas in a vertical `panedwindow` | yes |
| 35 | Upper pane: read-only log display | yes |
| 36 | Every action-log line mirrored to the log pane in real time | yes |
| 37 | Pane mirror fed from the single `log_action()` sink via a guarded Tcl proc | yes |
| 38 | Log content passed to Tcl via a variable, never substituted into the eval string | yes |
| 39 | Lower pane: command entry feeding the xschem Tcl interpreter | yes |
| 40 | Entry pane starts at one line in height (padded for aesthetics) | yes |
| 41 | Draggable sash adjusts the log-pane / entry-pane height split | yes |
| 42 | Echo: typed command appears in the log pane | yes |
| 43 | Echo: command's return value or error shown in the pane, visually distinct from action-log lines | yes |
| 44 | CIW auto-opens at startup of interactive (`has_x`) sessions | yes |
| 45 | Closing the CIW does not exit xschem; file logging continues regardless | yes |
| 46 | `xschem log_action [-noecho] <text>` subcommand | yes |
| 47 | `xschem get actionlog_filename` subcommand | yes |
| 64 | Sash is a wide, visible grab target (not the Tk hairline default) | yes |
| 65 | Entry-area height follows the sash; long commands wrap into view | yes |
| 66 | Return in the entry executes, never inserts a newline | yes |
| 67 | Neither CIW pane can be collapsed below a minimum size | yes |
| 68 | Ctrl-Backspace in the entry deletes the previous word (shell-style) | yes |

## 5. Tests (spec §5)

| # | Spec | Implemented? |
|---|------|--------------|
| 48 | Phase-0 smoke: `tests/headless/test_action_log.sh` | yes |
| 49 | CIW smoke: `tests/headless/test_ciw.tcl` | yes |
| 50 | Acceptance smoke: record → replay (`source` log into fresh instance) → diff state | yes |

## 6. Explicitly not v1 (spec §6)

| # | Spec | Implemented? |
|---|------|--------------|
| 51 | `xschem select_at x y` exposing `find_closest_obj()` → replayable click-select | deferred |
| 52 | Stable Tcl referents for pins and text | deferred |
| 53 | Faithful full-session replay (causal chain: selections, descend/go_back, load) | deferred |
| 54 | CIW command history (Up/Down, draft stash, dup collapse) | yes |
| 55 | CIW multi-line entry | deferred |
| 56 | CIW search/filter in the log pane | deferred |
| 57 | rc toggle for CIW auto-open | deferred |
