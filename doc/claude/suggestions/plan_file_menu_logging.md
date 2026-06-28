# Plan: log the File-menu effects (open / save / exit and the rest)

User request (2026-06-11): every effect achievable through the File menu is
recorded — File→Open as `xschem load {/path/file.sch}` (the existing,
replayable subcommand; no new name needed), saves likewise, and quitting the
application. Same disciplines as Layers A–C: record-after-evaluation, log the
*resolved* effect not the dialog-opening start, never double-log a replay or
a CIW-typed command.

## Audit (done)

- The File menu is the only csv-generated menu (`build_menu_from_table`,
  action_registry.tcl) — one construction point for a menu-pick logging
  wrapper, naturally gated by the existing csv `nolog` column.
- Open paths converge as: menu Open / toolbar / Ctrl+O → `ask_new_file()`
  (actions.c; dialog → resolved `f`, loads in-window or delegates to
  `xschem load_new_window {f}`); menu recent / last-closed / most-recent /
  context-menu case 9 / file_chooser → scheduler `load` branch **with
  `-gui`** and a resolved filename; menu Open-in-new-window →
  `load_new_window` branch's own dialog arm.
- `saveas()` (actions.c) is the one place the save-as dialog resolves; menu
  Save = `xschem save` (replayable verbatim; untitled falls into
  `saveas(NULL)` → covered by the saveas hook).
- Quit paths (menu Close = `xschem exit`, menu Quit = `quit_xschem`, WM
  close button) all terminate inside the scheduler `exit` branch at exactly
  two `tcleval("exit %s")` sites. Logging there (just before termination)
  also catches CIW-typed `xschem exit` exactly once: the CIW's own
  after-eval log line can never be written because the process dies first.
- `action_reload` wraps `xschem reload` in a confirm — log inside the
  confirmed branch.

## Double-log prevention (the invariant table)

| line | logged at | why no double |
|---|---|---|
| `xschem load {f}` (dialog) | ask_new_file, only when the dialog ran (`!filename`) | typed/replayed `xschem load f` never enters ask_new_file |
| `xschem load {f}` (recent/lastclosed/…) | scheduler load, only when `-gui` | replay lines never carry `-gui`; Layer B case 9's custom logcmd is REMOVED (now redundant) |
| `xschem load_new_window {f}` | ask_new_file new-window arm + load_new_window's dialog arm | the with-filename arm (used by replay and by ask_new_file's delegation) does not log |
| `xschem saveas {f} schematic\|symbol` | saveas(), only when the dialog ran (`!f`) | typed/replayed `xschem saveas path` passes f |
| `xschem save`, `xschem clear schematic`, … | the menu wrapper (after eval) | typed commands don't go through the menu; replays don't either |
| `xschem exit closewindow force` | scheduler exit, before the terminating `tcleval("exit …")` | process death prevents any other logger from running |

## Classification of the File-menu rows

- **Logged verbatim by the menu wrapper**: clear_schematic, clear_symbol,
  save, new_window_tab, open_sub_sch, open_sub_sym (the last three are
  selection/multi-window bounded — issue 0005 / checklist row 53 — same
  precedent as Layer B's descend_symbol).
- **nolog (effect logged at a resolution hook instead)**: open,
  open_new_window, open_last_closed, open_most_recent, save_as,
  save_as_symbol, reload (logged inside action_reload), close, quit
  (C exit hook).
- **nolog, silent in v1 (dialog / process-spawning, no faithful line)**:
  delete_files, new_process, merge (the drop already gets the Layer C
  marker), component_browser, the file.im_exp.* export entries.
- Accepted caveat (documented): `xschem clear schematic` confirms when the
  schematic is modified — a cancelled confirm still logs the pick (the
  wrapper can't see inside); replay then clears. Same record-the-pick
  semantics Layer B uses.

## Implementation

1. Export `tcl_braceable()` (callback.c → xschem.h) for the new hooks.
2. Hooks: ask_new_file (2 arms), scheduler load (`-gui`), load_new_window
   (dialog arm), saveas() (dialog arm, with explicit schematic|symbol word),
   scheduler exit (2 termination sites, line `xschem exit closewindow force`
   so a full-session replay terminates deterministically with no confirm).
3. Remove Layer B ctxmenu case-9 custom logcmd (superseded).
4. Menu wrapper `menu_action_logged` in build_menu_from_table +
   `xschem reload` logging inside action_reload.
5. csv: nolog on the rows listed above.
6. Tests: `tests/headless/test_file_menu_log.sh` — process 1 drives Open
   (stubbed load_file_dialog), recent (-gui), saveas (stubbed
   save_file_dialog), menu-invoked Save and Clear, action_reload (stubbed
   alert_), asserts log lines + actual effects; process 2 quits via
   `xschem exit` and the shell asserts the exit line is the log's last line.
   Regression: full smoke sweep (the wrapper runs at every startup).
