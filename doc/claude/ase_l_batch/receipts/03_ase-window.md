# Receipt — item 03 ase-window

Verdict: **DONE** ([x] in PLAN.md ledger).
Commit: `5f94d6d69757dd97e` — `feat(ase): ASE-L session window — panes, live
log, run/stop, design window`. NOT pushed (batch policy).

## What landed

`ase::open_state` is now the real ASE-L session window (v0 textwindow body
replaced; name + signature stable per the item-02 contract — LibMgr/descend
dispatch from item 02 lands here unchanged). 9 files, +1290/−41:

- **`src/ase_window.tcl` (NEW, 711 lines, namespace `ase::ui`)** — one
  `.ase<N>` toplevel per state view; `N` from the new C seam
  `xschem allocate_window_number` so ASE windows share the SAME file-scope
  counter `assign_window_number()` uses (no collision with future editor
  windows; NOT a hardcoded constant). Title
  `ASE-L (<N>) — <lib>/<cell> [<view>]` + ` *` dirty marker;
  `notify_window_active` fires on FocusIn (CIW/LibMgr pattern).
- **Panes** (editable, backed by the session dict): variables, analyses with
  per-type arg forms (op/dc/ac/tran), outputs, models/corner, options,
  rundir + simulator combobox fed by `ase::backend_names`. Every
  Return/FocusOut/checkbox/combobox commit harvests through
  `ase::session_update` with a rowbase merge that preserves unshown keys —
  untouched panes never dirty the session.
- **Session menu** — Save State / Load State / Revert State; **Design
  Window** raises the design's editor window if open (`xschem windows` scan +
  `new_schematic switch`) else opens via the libmgr `-gui` load precedent
  with gated action-log + `after 120 force_window_repaint` (WSLg lesson);
  Close discards-with-notice.
- **Simulation menu + buttons** — Netlist (`ase::netlist`, result via
  `textwindow`), Run, Stop, View Log; status light mirrors
  `set_simulate_button` semantics (orange/Green/red). **Live run log** via a
  write trace on `execute(data,$id)` appending the delta into a read-only
  text widget (spec's primary plan D3 — no fileevent fallback needed). Stop
  kills via `kill_running_cmds <id> -9` (the existing pid accessor;
  Windows-guarded, unix only).
- **`src/ase.tcl`** — headless session model (`session_key/open/state/update/
  dirty/save/load/revert/close` + `session_path`, `session_setattr/getattr`);
  `state_serialize` factored byte-identically out of `state_save` (dirty
  compare); `backend_names`; `ase::session_notify` seam. `open_state`
  registers the session headless with NO Tk, delegates to `ase::ui` only
  under `has_x`, and raises the existing window on re-open (no number
  consumed).
- **C seam** — `src/xinit.c` (`allocate_window_number()` off the shared
  counter) + `src/xschem.h` decl + `src/scheduler.c` `'a'`-dispatch branch
  (scheduler-letter-dispatch lesson honored); build green.
- **Ship** — `src/xschem.tcl` source line for ase_window.tcl;
  `src/Makefile.in` `install_shares` (generated Makefile NOT committed).

## Test

`tests/headless/test_ase_window.tcl` — **53 checks total**: 19 headless
(session model: key/open/state/update/dirty/save/load/revert/close, serialize
byte-stability, H5 allocator counter advance) + GUI legs W1–W8 (toplevel +
panes populated from dict, widget-edit→Save State→file has new value, Run on
the nfet fixture with live log `Data Rows` + `-i(v1)` result + green status,
Design Window raise/open asserted against the window list, Stop on a long
tran leaves red/aborted). Bindings under test driven through REAL Tk event
sequences; main-window legs self-SKIP on WSLg geometry, run legs self-SKIP
without ngspice. All 53 green under WSLg DISPLAY.
`tests/headless/test_ase_view.tcl` updated per D10 (find_state_viewer →
`ase::ui::window_for` lookup; G1/G2/V6-cleanup close via the real Close
path): 36/36 DISPLAY, 32/32 headless. `test_ase_core` untouched, 33/33.

## Sabotage table

| # | Sabotage | Target check(s) | Result |
|---|----------|-----------------|--------|
| S1 | ase_window.tcl `ase::ui::log_trace` appends `{}` instead of the delta | W6 log-widget checks (non-empty, `Data Rows` banner, `-i(v1)` result line) | failed EXACTLY the 3 W6 widget checks; `W6 log file written` stayed green — proves the widget path itself was exercised (run under DISPLAY+ngspice) |
| S2 | ase.tcl `session_save` writes the stale `saved` dict instead of `state` | H2 saved file contains the new Vgs value | failed EXACTLY H2 (headless `env -u DISPLAY`, 1 FAILED / 18) |
| S3 | xinit.c `allocate_window_number` returns counter without incrementing (rebuilt before run and after revert) | H5 second call == first+1 | failed EXACTLY H5 (headless, 1 FAILED / 18) |

Each: `git diff` confirmed sabotage-only, targeted `git checkout -- <file>`
revert, clean re-run green (S3 with rebuild both directions).

## Audit / fix rounds

- full_audit: **200 pass / 13 fail / 0 crash / WIREEDIT PASS**; the 13 fails
  are a STRICT SUBSET of the PLAN.md baseline (baseline entries
  test_altf5_ciw, test_cadence_window_hop_log, test_fluid_editing,
  test_launch_context, test_palette, test_verb_noun_copy_move,
  test_wire_vertex_grab, test_key_graph_context happened to pass).
  test_ase_core / test_ase_view / test_ase_window all PASS inside the audit.
  Zero non-baseline fails.
- Verifier lenses (hygiene/tests/spec) returned no problems — **no fixer
  rounds were needed** (outstanding-problems list empty at ledger time).
- Declared implementer deviations (all benign, documented):
  1. W3 needed `focus -force` before `event generate <Return>` — Tk
     dispatches key events to the focus window (keybind-test lesson); the
     shipping Return commit binding still fires as the real event.
  2. The `session_notify` GUI hook refreshes the TITLE only; pane
     repopulation happens in the Load/Revert menu wrappers — D4's
     "(+ panes)" parenthetical would destroy the entry mid-FocusOut-commit,
     so D7/D8 wording was followed instead.
  3. Small additive session helpers beyond the D4 list: `session_path`,
     `session_setattr`/`session_getattr` (the D8 "store id in the session"
     storage; the test reads run_id through it).
  4. Sabotages executed after the single commit (item-02 receipt precedent —
     the prescribed git-checkout revert flow needs the committed baseline);
     S2/S3 attributed headless via `env -u DISPLAY`, S1 under
     DISPLAY+ngspice.
  5. full_audit run once in background due to the foreground tool time cap;
     same script/flags/classification.

## Outstanding problems

None — verified clean (empty outstanding-problems list at ledger time).

## Corrected/confirmed anchors worth keeping

- **Window-number allocator**: editors get numbers from a file-scope counter
  in `src/xinit.c` (`assign_window_number()`); the new
  `xschem allocate_window_number` verb hands out numbers from that SAME
  counter — any future non-editor window type should use this verb, not a
  hardcoded constant or a Tcl-side counter.
- New `xschem` subcommands must go in the matching first-letter dispatch
  function in scheduler.c (`'a'` branch here) or they are silently
  unreachable (scheduler-letter-dispatch lesson re-confirmed).
- **execute pipe pid**: `kill_running_cmds <id> -9` is the existing kill
  path for `execute` subprocesses (numeric-id branch) — no new accessor was
  needed; unix-only, Windows-guarded.
- **Live log**: `trace add variable execute(data,$id) write` delivers usable
  incremental deltas (spec risk "trace granularity" did NOT materialize; the
  fileevent-clone fallback was never needed).
- Tk key-event tests: `event generate <widget> <Return>` only reaches the
  widget's binding after `focus -force $widget` (WSLg/headless-focus
  gotcha; complements the gesture-test-full-sequence lesson).
- Generated `src/xschem_subcommands.txt` is git-ignored (regenerated by
  make) — appears after builds, never staged, no hygiene issue.
- Item-04 contract: session model is headless-complete
  (`ase::session_open/state/update/save/...` run without Tk), so P4's
  end-to-end proof can drive the public ase API with `--nogui` untouched.

## Commit hygiene

Staged exactly the 9 prescribed files: `src/xinit.c`, `src/xschem.h`,
`src/scheduler.c`, `src/ase.tcl`, `src/ase_window.tcl`, `src/xschem.tcl`,
`src/Makefile.in`, `tests/headless/test_ase_window.tcl`,
`tests/headless/test_ase_view.tcl` (verified against
`git show --stat 5f94d6d6`). No pre-batch dirty tracked files, no generated
files (Makefile, xschem_subcommands.txt), no scratch leftovers. Not pushed.
