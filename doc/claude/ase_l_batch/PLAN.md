# ASE-L mini-batch — plan + ledger

Spec: doc/claude/specs/ase_l.md (all anchors there re-verified per item by scouts).
Runbook: doc/claude/ase_l_batch/RUNBOOK.md. Branch: fluid-editing. NEVER push.

## Preflight (2026-07-20)

- Build: `cd src && make` green ("Nothing to be done for 'all'").
- Baseline fail list at batch start (2026-07-20, DISPLAY=WSLg; SKIPs fine;
  compare LIST EQUALITY — these fails are tolerated, any NEW fail is not):
  FAIL: test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
  test_cadence_window_hop_log, test_ciw, test_crossview_paste,
  test_fluid_editing, test_hi_descend, test_launch_context,
  test_lib_manager_gui, test_lib_sweep, test_palette, test_phase3_mints,
  test_pin_type_edit, test_reopen_readonly, test_select_at,
  test_selflog_output, test_verb_noun_copy_move, test_wire_split,
  test_wire_vertex_grab. TIMEOUT: test_key_graph_context.
  (Most are pre-existing WSLg/geometry+recent-file-state flakes, e.g.
  "main window has a usable size (geom=1x1+0+0)"; test_reopen_readonly R10
  poisoned by pre-batch nfet_test_claude in recent-files.)
- Pre-existing dirty tracked files (must never be staged by any item):
  `doc/claude/specs/sky130_workarea.md`, `sky130A/xschem_libs/library.defs`,
  `src/ciw.tcl`, `tests/headless/test_sky130a_libmgr.tcl`,
  `tests/run_regression.tcl`,
  `xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym`,
  `xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`.
- Untracked starting-point cell
  `sky130A/xschem_libs/sky130_tests/nfet_test_claude/` — committed by item 04
  (same feature arc), not before.

## Ledger (driver + ledger agents edit; one line per item)

- [x] 01 ase-core        — src/ase.tcl state I/O + ngspice backend + deck render + batch run, headless tests -> 20cc4df9 core landed, 33/33 headless checks + 3 exact-target sabotages, full audit at baseline
- [x] 02 view-dispatch   — ngspice_state1 view type: enumerate/resolve/create/open-dispatch, tests -> 307eaa64 dispatch+creation landed, 36/36 checks (32 headless) + 3 exact-target sabotages, audit fails strict subset of baseline
- [x] 03 ase-window      — ASE-L Tk window: panes, menus, live log, run/stop, Design Window, numbering -> 5f94d6d6 session window landed, 53 checks (19 headless) + 3 exact-target sabotages, audit fails strict subset of baseline
- [x] 04 proof-final     — sky130_tests/test_nfet_final circuit-only + state view, end-to-end Id proof -> c8d539c0 acceptance gate PASSED: Id=409.684 uA through public ase API on the committed clutter-free cell, 28/28 checks + 3 exact-target sabotages, audit fails strict subset of baseline

Verdicts: [x] done (commit in receipt) | [F] failed (reason in receipt). No DEFER in this batch.

## Round 2 — UI v2 / ADE-L parity (2026-07-21)

Authoritative contract: spec section "UI v2 — ADE-L parity rework" in
doc/claude/specs/ase_l.md (user-reviewed; palette + Value-column decisions
USER-LOCKED in the spec). Fonts/dialog idioms:
references/copy_current_cell_dialog.tcl. Same policies, same baseline fail
list as round 1; tests test_ase_{core,view,window,final}.tcl are NOT baseline
fails and must stay green (they MAY be edited when the UI they assert
changes — receipt must justify every loosened assertion).

- [x] 05 ui-shell        — chrome: title/toolbar-temp/statusbar/palette/fonts, menu tree v2, log window (pane removed), Design Window BUGFIX -> 6230ca56 v2 chrome + Design Window raise fix landed, 129 checks (91 GUI + 38 headless) + 3 exact-target sabotages, verifier lenses clean (audit caveat in receipt)
- [x] 06 panes-strip     — 3 panes w/ v2 columns + selection + ctx menus + dbl-click editors, action strip, Value fill-after-run -> 76c4cffe v2 treeview panes + action strip + Value fill landed, 185 checks (144 GUI + 41 headless) + 3 exact-target sabotages, 2 test-only WSLg fixer commits (483084e0, 7530dc39), lenses clean
- [x] 07 dialogs         — Choose Analyses, Setup Design/Model Files, Save All, Load/Save State, Simulation Options -> 0c54ed28 all nine TODO(item07) stubs replaced with real themed dialogs, 262 checks (201 GUI + 61 headless) + 3 exact-target sabotages, no fixer rounds, audit fails strict subset of baseline
- [x] 08 design-interact — Select On Design (click wires/terminals), whole-flow GUI acceptance -> 54c78d31 ROUND-2 GATE PASSED: click mode + whole-flow leg end-to-end with zero SKIPs (Id 409.7 uA, scratch-state reload identical), 63 checks (54 GUI + 9 headless) + 3 exact-target sabotages, no fixer rounds, verifier audit fails strict subset of baseline

### 05 ui-shell

Rework src/ase_window.tcl chrome per spec "Window chrome" + "Menu tree v2" +
"Log window":
1. Title `Analog Sim Environment <design cell>`; toolbar row under menubar
   with temperature numeric entry (state key `temperature` default 27,
   validated numeric) + `°C` label; bottom status bar
   `<win#> | Status: <Ready/Running/…> | T=<T> C | Simulator: <sim> | State: <view>`.
   Temperature emits `.temp <T>` in render_deck (ase.tcl backend + test).
2. Palette (USER-LOCKED): panels #f2f2f2, tables/entries white, header
   strips #e8e8e8, dark-red pane-title accent. Central `ase::theme` proc
   (colors + named fonts AseLabelFont Arial 10 bold / AseEntryFont Arial 13
   / AseMonoFont Courier 13, `option add *TCombobox*Listbox.font`) applied
   to EVERY ASE widget — no stock-Tk leftovers.
3. Menu tree v2 VERBATIM from spec: Launch (placeholder), Session, Setup,
   Analyses, Variables, Outputs, Simulation, Results (deferred entries
   present but disabled), Tools (disabled). Wire everything that already
   has a proc (Netlist Recreate/Display, Netlist-and-Run, Run-existing
   [must NOT re-netlist], Stop, Log); dialogs landing in item 07 get a
   `ciw_echo "coming in item 07"` stub command marked with a `TODO(item07)`
   comment.
4. Log pane REMOVED from the window; run opens a live-follow log toplevel
   (reuse v1 live-log machinery), Ctrl-W closes it, Simulation > Log
   reopens on the current log file.
5. **BUGFIX Session > Design Window**: currently does not raise/open the
   schematic. Scout: reproduce first (read receipts/03 + the current
   handler), root-cause, fix = raise if a window holds the design cellview,
   else open via load-routing precedent + `after 120 force_window_repaint`.
   Regression check in the GUI test.
6. Update tests/headless/test_ase_window.tcl for the new chrome (title,
   no log pane, menu entries exist, temp entry present, .temp in deck) —
   every assertion change justified in the receipt. ≥2 sabotages.

### 06 panes-strip

Spec sections "Panes" + "Action strip":
1. Exactly 3 panes: Design Variables (Name,Value), Analyses (row#, Type,
   Enable checkbox, view-only Arguments summary), Outputs (Name, Value,
   Plot cb, Save cb, Save Options). NO inline +/- buttons anywhere.
2. Outputs semantics: Name = user name if named else truncated expression;
   Save Options auto-cell `allv`/`alli` per spec (needs state keys for
   blanket saves — coordinate with item 07's Save All dialog: land the
   state keys `save_all_v`/`save_all_i` HERE with defaults 0, dialog later);
   Value column filled after successful run from parsed results (extend
   ase::last_result / backend result_probe to return per-output scalars;
   blank pre-run; test with the nfet fixture: id row shows ≈4.0968e-04).
3. Selection model: row multi-select within ONE pane; selecting in a pane
   clears the other panes' selections; action-strip `X` deletes the
   current selection (noun-verb) with no confirm; context menu per pane:
   Add… / Edit… / Delete.
4. Double-click row → per-item edit dialog (variables: name/value;
   outputs: name/expr/plot/save; analyses: routes to Choose Analyses with
   that analysis preselected — stub `TODO(item07)` until 07 lands, but the
   variables + outputs editors land NOW).
5. Action strip (right vertical, per spec): OP,TR / = / --> / X / N&> /
   > / ! / ~ (~ = disabled placeholder; unicode ▶ ■ acceptable for run/
   stop if they render). OP,TR + --> may stub to item 07 dialogs; = (Add
   Variable name/value dialog) lands NOW.
6. Extend test_ase_window.tcl: pane columns, checkbox toggles persist to
   state on save, X deletes multi-selection, add-variable dialog round
   trip, Value fill after run leg. ≥2 sabotages.

### 07 dialogs

Spec "Menu tree v2" + "Choose Analyses dialog" + "Dialog style" (idioms
from references/copy_current_cell_dialog.tcl — named fonts, type-to-filter
ttk::combobox, Return=proceed, per-window state arrays cleaned on destroy):
1. **Choose Analyses**: top radio section (op/dc/ac/tran), bottom
   per-analysis form (Enable + quick fields: DC source/start/stop/step,
   TRAN step/stop, AC points/start/stop) + Options button (simulator-side
   nuanced options; minimal form OK). Replaces item-06 stubs (OP,TR
   button, analyses dbl-click preselect).
2. **Setup > Design**: Library/Cell/View dropdowns; View lists ONLY
   schematic views once Cell chosen; writes state `design`.
3. **Setup > Model Files**: one row per model file + corner entry (e.g.
   tt); add/delete rows via context menu + strip X consistency.
4. **Outputs > Save All**: checkboxes all-voltages / all-terminal-currents
   (+ levels field, may be inert v1); writes `save_all_v`/`save_all_i`;
   deck mapping allv → `.save all`, alli → `.options savecurrents`
   (render_deck + test); Outputs pane Save Options column reacts.
5. **Session > Load State**: library-browser dialog (Create Instance
   browser precedent — scout: src/create_instance.tcl) filtered to
   simulation-state views; loads into THIS session (dirty-check prompt).
6. **Session > Save State**: always Save-As — Library dropdown +
   editable Cell/View entries prefilled; read-only-opened view +
   same-target overwrite → confirmation popup; saving to a new view
   creates it (item-02 creation path).
7. **Simulation > Options**: minimal ngspice options dialog (rows of
   name/value, feeds state `options`).
8. Extend test_ase_window.tcl (or new test_ase_dialogs.tcl): each dialog
   opens, round-trips its state key, Save-As creates a new view dir,
   read-only overwrite confirm path, .save all/.options savecurrents in
   deck. ≥2 sabotages.

### 08 design-interact

1. **Select On Design** (Outputs > To Be Saved / To Be Plotted, and the
   --> dialog's choose-from-design button): raise-or-open the design
   schematic (reuse the item-05-fixed Design Window path), enter a click
   mode where wire click → voltage output `v(<net>)`, instance terminal
   click → current output `i(<source>)`/terminal current; each click
   queues an output row (Save or Plot flavor per entry point); ESC ends
   the mode and returns focus to ASE. Scout: reuse existing xschem click
   infra (select_at / pin_view machinery / hover) — smallest honest hook,
   document choice.
2. Whole-flow GUI acceptance leg (this round's gate): open
   test_nfet_final state → Choose Analyses enable op → add output via
   dialog → Netlist and Run → log window appears, status Ready, Outputs
   Value column shows Id ≈ 409.7 µA → Save State to a scratch view →
   reload it → panes repopulate identically. DISPLAY-guarded; self-SKIP
   only for legs WSLg physically cannot do (justify each in receipt).
3. ≥2 sabotages.

---

## Item detail

### 01 ase-core (P1 of spec)

New file `src/ase.tcl`, pure Tcl, namespace `ase::`. Loaded the same way
library_manager.tcl is (scout: find its source site + install/ship listing and
replicate; remember src/Makefile is generated from Makefile.in — edit the .in
if tcl files are listed for install; CMakeLists.txt secondary, mirror if the
precedent file appears there).

Deliverables:
1. **State I/O** — `ase::state_default` (the spec's v1 schema, spec section
   "State file schema"); `ase::state_load <path>` → dict (merge over defaults,
   PRESERVE unknown keys); `ase::state_save <path> <dict>` (stable key order,
   one `key value` per line, round-trip byte-stable for untouched files after
   load→save).
2. **Backend table** — `ase::backends` registry; v1 entry `ngspice` providing
   `render_deck`, `run_cmd`, `log_file`, `result_probe` hooks (proc-name
   indirection is fine; keep the seam honest — no ngspice literals outside the
   backend namespace except defaults in the state schema).
3. **Deck render** — `ase::backend::ngspice::render_deck <state> <netlistText>`
   → deck string: strip trailing `.end` (verified spice_netlist.c:591 emits it
   last for top .spice netlists), then `.lib` models (file+section), `.param`
   variables, `.options`, `.save` outputs (save==1), one `.control` block from
   enabled analyses in fixed order (op, dc, ac, tran) + `write`/prints needed
   for result probing, then `.end`. Only `enabled 1` analyses emit.
4. **Netlist + run** — `ase::netlist <state>` (derive design cellview path via
   `cellview_path`, load + `xschem netlist` headless-safe, return netlist file
   path; scout decides load-vs-current-context detail, must not clobber an
   open GUI window when one exists — get_save_xctx/save-restore or explicit
   guard); `ase::run <state> ?callback?` — write `<cell>_ase.spice` +
   batch-run via the `execute` infra (xschem.tcl:352; NO `$terminal`), log
   accumulates in `execute(data,$id)` and is flushed to
   `<rundir>/<cell>_ase.log` on completion; `ase::wait <id>` vwait wrapper;
   `ase::last_result` parse hook (e.g. `-i(v1) = 4.096837e-04` line grep).
5. **Headless test** `tests/headless/test_ase_core.tcl` (auto-discovered by
   full_audit.sh; do NOT touch tests/run_regression.tcl — pre-batch dirty):
   state round-trip incl. unknown-key preservation; deck render golden
   (literal expected deck for the nfet state); real ngspice end-to-end on a
   temp copy of the nfet_test_claude circuit WITHOUT its commands/corner
   instances (build the clean sch in the test or netlist a fixture under
   tests/headless/fixtures/), assert Id parsed ≈ 4.0968e-04 (rel tol 1e-3);
   run-dir defaulting; ngspice-missing → clean error path (guard with
   `auto_execok ngspice`, SKIP the sim leg if absent). ≥2 sabotages.

Constraints: no Tk calls anywhere in ase-core paths (must run --nogui);
`ciw_echo` only under `has_x`; TIP-278 namespace discipline; model paths via
the state file, not hardcoded (test uses sky130A workarea models path).

### 02 view-dispatch (P2 of spec)

Make `ngspice_state1` a first-class view. Anchors (scout re-verifies lines):
- `cell_views` library_defs.tcl:261 + `cellview_resolve` :209/:222 already
  glob `<cell>.*` — confirm `.state` discovery/resolution with a probe, no
  code change expected here.
- **Open dispatch**: `libmgr::open_view` library_manager.tcl:432 (all LibMgr
  opens funnel here: dbl-click :136, ctx menus :183/:199, open_view_ro :558).
  Add view-type dispatch table (proc `libmgr::view_handler <view>` or dict):
  `schematic|symbol` → status-quo load; `ngspice_state*` → `ase::open_state
  <lib> <cell> <view>`. Item 02 ships `ase::open_state` v0 = read-only
  `textwindow` on the .state file + `ciw_echo` notice (item 03 replaces body;
  keep the name STABLE — it is the item-03 contract).
- `hi_descend_enum_views` xschem.tcl:5697: `.state` → type `ngspice_state`;
  `hi_descend_finish` xschem.tcl:5764: state views must not fall into the
  binary schematic/symbol descend — route to `ase::open_state` or refuse with
  a `ciw_echo` message (scout picks; document in prompt).
- **Creation**: `newview_dialog` combobox library_manager.tcl:1204/1214 gains
  `ngspice_state1`; `do_new_view` :1154 → `library_new_view`
  library_defs.tcl:701/709 must seed the new `.state` file with
  `ase::state_default` SERIALIZED via `ase::state_save` (never an empty file —
  loader must not need an empty-file special case), with `design` pointing at
  the cell's schematic view. `save_as_form.tcl:47/71` type mapping extended.
- Read-only/git plumbing: `libmgr::tracked_views`/git target work on any view
  dir — confirm, no change expected.

Test `tests/headless/test_ase_view.tcl`: cell_views lists the new view;
cellview_path resolves the .state file; library_new_view seeds a loadable
valid dict whose design points at the schematic; dispatch-table unit check
(handler lookup returns ase::open_state for ngspice_state1, editor path for
schematic/symbol — call the table proc directly, no Tk needed); descend
enum/finish routing check headless where possible; GUI legs (real
.libmgr double-click) DISPLAY-guard self-SKIP. ≥2 sabotages.

### 03 ase-window (P3 of spec)

`ase::open_state` becomes the real ASE-L session window (replaces v0 body;
one toplevel per state view, re-open raises). Spec section "UI sketch".

Deliverables:
1. Toplevel `.ase<N>`; title `ASE-L (<win#>) — <lib>/<cell> [<view>]`; window
   number via `notify_window_active` pattern (ciw.tcl:106 / 
   library_manager.tcl:79; scout reads the window-numbering spec/code for the
   allocator used by editors at xschem.tcl:13724 and allocates the next free
   number the same way, NOT a hardcoded constant).
2. Panes (editable, backed by the state dict in a namespace-per-window var):
   variables, analyses (per-type arg forms op/dc/ac/tran), outputs,
   models/corner, options, rundir+simulator (simulator combobox from
   `ase::backends`). Dirty-marker in title (`*`); Save State / Load State /
   revert.
3. Session menu: Save State, Load State, **Design Window** (raise the design's
   editor window if open, else open via the existing load-routing
   (`xschem load -gui` / load_new_window precedent in libmgr::open_view
   library_manager.tcl:432ff) + `after 120 force_window_repaint` WSLg lesson),
   Close.
4. Simulation menu + buttons: Netlist (ase::netlist, view result via
   `textwindow`), Run (ase::run wired to a **live log pane**: trace on
   `execute(data,$id)` appending the delta into a read-only text widget —
   fallback own-pipe fileevent clone if trace granularity is unusable), Stop
   (kill via pid from `execute`'s pipe — scout verifies how execute exposes
   the pipe/pid and adds the minimal accessor if missing), View Log (open
   `<cell>_ase.log`). Run/Stop button status orange/green/red mirroring
   `set_simulate_button` (xschem.tcl:13633) semantics.
5. LibMgr/desc dispatch from item 02 now lands here unchanged
   (`ase::open_state` name stable).

Test `tests/headless/test_ase_window.tcl`: DISPLAY-guarded GUI test (self-SKIP
headless): open state view → toplevel exists, panes populated from dict; edit
a variable via the widget → Save State → file contains new value; Run on the
nfet fixture → log widget non-empty, contains `Data Rows`/result line, status
green; Design Window raises/opens the schematic (assert window list); Stop on
a long tran run leaves status red/aborted cleanly. Keep every leg driven
through the REAL Tk event sequence where a binding is under test
(gesture-test-full-sequence lesson). ≥2 sabotages. Headless-safe legs (state
sync procs) run without DISPLAY.

### 04 proof-final (P4 of spec)

1. New cell `sky130A/xschem_libs/sky130_tests/test_nfet_final/`:
   - `schematic/test_nfet_final.sch`: ONLY `sky130_fd_pr/nfet_01v8` M1
     (`W=1 L=0.15 nf=1`), `devices/vsource` V1 (`value=Vds`) + V2
     (`value=Vgs`), `devices/gnd`, `devices/lab_wire` D and G — geometry may
     copy nfet_test_claude minus corner + simulator_commands_shown. NO
     netlist_commands-type instances, NO model include, NO .control anywhere.
   - `ngspice_state1/test_nfet_final.state`: design → the schematic view;
     models `{file <sky130A models>/sky130.lib.spice section tt}` (path via
     the same `$::SKYWATER_MODELS`-style resolution the workarea rc sets —
     scout decides literal-vs-variable, must work headless from repo root);
     variables Vgs 1.8, Vds 1.0 (exercises `.param`); options savecurrents;
     analyses op enabled; outputs `-i(v1)` save.
2. End-to-end test `tests/headless/test_ase_final.tcl`: through the PUBLIC ase
   API only (state_load → netlist → render_deck → run → parse): Id ≈
   409.7 µA (|Id·1e6 − 409.68| < 1.0); netlist artifact asserted free of
   `.control`/`.lib` BEFORE deck append (proves de-clutter); state file
   round-trips; view enumerated by cell_views. ≥2 sabotages.
3. Commit includes the `nfet_test_claude/` starting-point cell (preflight
   note) + sky130A README "ASE-L" paragraph (README is NOT in the pre-batch
   dirty list — verify before staging).
4. This item is the acceptance gate for the whole batch: if Id mismatches or
   the schematic needs any sim clutter to pass, the item FAILS (no
   workarounds inside the test).

## Round 2 addendum

- [x] 09 eng-notation    — engineering-notation display for ASE values, gated ase_eng_notation, rc comment -> 05b2a708 formatter+gate+rc comments landed; workflow died pre-verify, driver ran 3 lenses directly (hygiene/tests/spec ALL ok, sabotage failed exactly 4 u-suffix checks), receipt 09

### 09 eng-notation

User request 2026-07-21: ASE-L displays values in ENGINEERING notation
(exponent multiple of 3, SPICE SI suffix) — e.g. 1.04e-4 displays as `104u`.
Applies to: Variables pane Value column AND Outputs pane Value column
(post-sim evaluated values). Edit dialogs / entry fields keep RAW values
(round-trip safety); the state file ALWAYS stores raw values — formatting is
display-only at pane-render time.

1. `ase::format_value <v>` in src/ase.tcl (headless-testable): engineering
   notation, SPICE-compatible suffixes f p n u m (none) k Meg G T; ~4
   significant digits, trailing zeros trimmed (1.04e-4 → 104u, 4.096837e-4
   → 409.7u, 1e-3 → 1m, 27 → 27, 1.5e6 → 1.5Meg, 0 → 0, negatives keep
   sign); out-of-suffix-range (|v| >= 1e15 or < 1e-18 nonzero) falls back
   to %g; non-numeric input returned verbatim (expressions, blanks).
2. Gate: Tcl global `ase_eng_notation`, default 1 via set_ne (rc may
   preset). 0 → panes show plain %g/scientific. Both pane render paths go
   through the formatter.
3. cadence_style_rc INFORMATIONAL comment (scout: pick the rc(s) users
   actually source — sky130A/cadence_style_rc and siblings; the file is NOT
   in the pre-batch dirty list — verify before staging):
   `# ASE-L shows values in engineering notation (104u). To recover
   scientific notation:  set ase_eng_notation 0`
4. Tests (extend test_ase_core.tcl formatter table headless + a GUI pane
   leg in test_ase_window.tcl: variable 1.04e-4 renders 104u, toggle var →
   scientific, state file still stores raw). ≥2 sabotages.
5. Spec ase_l.md UI-v2 section: one paragraph documenting the behavior +
   gate (commit it).

- [x] 10 esc-dismiss     — every ASE-L dialog dismissible with ESC (cancel semantics, cleanup preserved) -> d8ab6769 central bind_dialog_esc in dialog_buttons (9 scaffold dialogs + future ones by construction) + 4 explicit sites + chana_x_cancel anextra-leak fix, 133 GUI + 16 headless checks + 3 exact-target sabotages, audit fails strict subset of baseline (one WSLg flake green on direct re-run)

### 10 esc-dismiss

User request 2026-07-21: ANY dialog opened through ASE-L must be dismissible
with ESC.

1. Scout: enumerate EVERY toplevel dialog created by src/ase_window.tcl (and
   ase.tcl if any): Choose Analyses (+its Options subdialog), Add Variable,
   variable/output row editors, Setup Outputs (-->), Setup > Design, Model
   Files, Save All, Load State browser, Save State (Save-As), Simulation >
   Options — plus any others found in code. For each, identify its CANCEL
   path (the command that cleans per-window state arrays and destroys).
2. ESC must invoke that SAME cancel path — never a bare `destroy` that
   leaks the per-window state arrays (references/copy_current_cell_dialog.tcl
   cleanup idiom). Central helper (e.g. `ase::bind_dialog_esc <w> <cancelcmd>`)
   applied at every dialog creation site; new future dialogs get it by
   construction if there is a common dialog-constructor path (scout decides,
   document).
3. Non-collisions: tk_messageBox/confirm popups already ESC-cancel natively —
   leave; the item-08 Select-On-Design ESC (schematic-side mode end) is
   UNRELATED and must stay untouched (regression leg proves it still works).
   ESC on the ASE MAIN window stays unbound (no accidental session close).
4. Tests (GUI legs in test_ase_dialogs.tcl): for EACH enumerated dialog —
   open, press ESC (focus-gated generated key event, send_return-pattern
   helper generalized to send_key if needed), assert: dialog destroyed,
   per-window state arrays cleaned (info exists = 0), NO state mutation
   (dict unchanged vs pre-open snapshot). Plus: ESC in an ENTRY inside a
   dialog still dismisses (event bubbles); Select-On-Design ESC regression
   leg; main-window ESC does nothing. ≥2 sabotages.

## Round 3 — Waveform Viewer (2026-07-21)

Authoritative contract: doc/claude/specs/waveform_viewer.md (user-locked:
engine-reuse window architecture; viewer session persists INSIDE the ASE
state dict; v1 = analog core). Same policies/baseline as round 2 (incl. WSLg
flake list + send_return/send_key helpers). ASE tests
test_ase_{core,view,window,dialogs,final,interact}.tcl must stay green.

- [x] 11 viewer-window   — standalone viewer toplevel: graph-only canvas, stripped editing, viewer menus, theme, numbering -> cd332719 viewer window shell landed (readonly-for-life untitled buffer via load_new_window, canonical bind-sweep strip + per-window toolbar strip, themed viewer menubar, raw-fed graph sanity + ne555 regression legs), 68 GUI + 15 headless checks + 4 exact-target sabotages, 2 fixer commits (2c3ac80d bind-sweep, 0a90b9db toolbar strip), lenses clean
- [x] 12 viewer-core     — trace/graph model, add/remove trace, cursors A/B readout, zoom/fit, log axes, expression waves -> c143cedb viewer core landed (model-as-source-of-truth regenerate, live Graph/Cursors/View menus, validated expression waves, interpolated cursor readout cross-checked vs engine), 149 GUI + 36 headless checks + 3 exact-target sabotages, no fixer rounds, verified clean
- [x] 13 ase-plot        — Results>Direct Plot click mode, Outputs Plot checkboxes auto-plot, `~` button live, raw wiring -> 10649ec8 ASE wired to the viewer (Direct Plot queues clicks into ONE new stacked graph per invocation, always-replace auto-plot of Plot-checked outputs after each run with Direct-Plot graphs untouched, `~` raise-or-open, last_rawfile/attach_raw clear+read+regenerate re-run replace, op-only notice; run_finished semaphore-bracket landmine fixed via after-idle auto_plot + switch_ctx guard), 85 checks (25 also --nogui) + 3 exact-target sabotages, no fixer rounds, verified clean
- [x] 14 persistence-accept — `viewer` state key round-trip, Save/Load relaunch, dc-sweep end-to-end ACCEPTANCE GATE -> 435a6fc9 ROUND-3 GATE PASSED: viewer persisted as 14th state key (snapshot/restore incl. auto marker + rawfile seam), whole-flow dc leg green 3x with ZERO SKIPs (cursor readout 409.7u vs raw ground truth, both graphs relaunch on reopen), 109 checks (17 also --nogui) + 3 exact-target sabotages, no fixer rounds, one reality-forced C fix (draw.c graph_fullxzoom -1-master SIGSEGV clamp), verified clean

Item details live in the spec's "Round-3 batch items" section + per-item
notes passed by the driver; scouts re-verify all spec file:line anchors.

## Round 4 — Launch-from-schematic + dirty-save-prompt (2026-07-21)

User asks (2026-07-21): (1) a hosted technology (sky130A/gf180mcuD) needs a
DEFAULT MODEL setup that loads by default, and a schematic window needs
Tools > Launch ASE-L that opens a fresh minimal ASE-L session (no vars/
analyses/outputs, but the tech default model already in place), bound to the
current schematic — like Cadence Tools>ADE-L. (2) BUG: opening an
ngspice_state1 view, editing, then quitting does NOT prompt to save.

Same policies/baseline as prior rounds (WSLg flakes rerun-first;
send_return/send_key helpers). ASE tests test_ase_{core,view,window,dialogs,
final,interact,plot,persist} + test_wave_viewer must stay green.

- [x] 15 launch-ase      — Tools>Launch ASE-L on current schematic + per-tech ASE_DEFAULT_MODELS default -> 4112e1c9 Tools>Launch ASE-L opens a fresh untitled session bound to the current schematic with the tech default models preloaded (raise-not-duplicate on relaunch); ::ASE_DEFAULT_MODELS feeds state_default behind an info-exists guard, sky130A/gf180mcuD rcs set it; 38 checks (22 headless) + 3 exact-target sabotages, audit fails strict subset of baseline (3 WSLg flakes green on direct re-run)
- [x] 16 dirty-prompt    — save-prompt (yes/no/cancel) on ASE session close + on xschem quit -> 750b3577 a dirty ASE session now prompts yes/no/cancel on close (WM_DELETE/Ctrl-W/Session>Close) and on xschem quit (guarded ASE sweep, Cancel on any aborts the whole quit); Yes routes through Save-As so RO-opened + untitled sessions never silently overwrite, No discards, Cancel keeps window+per-window state intact; 41/41 checks (test_ase_dirty, DISPLAY-guarded self-SKIP) + 3 exact-target sabotages, all 11 protected ASE/wave suites green, audit fails strict subset of baseline; +f04703e0 round-1 fixer hardens ask_save_close against a build-time teardown race (catch-guarded focus + skip tkwait when window gone) so DR4 stops WSLg-flaking

### 15 launch-ase

Anchors (scout re-verifies): Tools menu xschem.tcl:14201 (per-window
`.menubar.tools`), entries ~14665-14667 (add after Net styles separator);
`ase::state_default` ase.tcl:116 (models {} today) + model render ase.tcl:
642-643; `ase::open_state {lib cell view {ro}}` ase.tcl:594 (loads existing
.state); seed pattern `library_new_view` ase.tcl:716-718; workarea model
sets sky130A/cadence_style_rc:31 (SKYWATER_MODELS), gf180mcuD/cadence_style_
rc:34 (180MCU_MODELS); ase.tcl+ase_window.tcl sourced unconditionally
xschem.tcl:14106/14108.

1. **Per-tech default models global**: `ase::state_default` reads
   `::ASE_DEFAULT_MODELS` (a list of `{file <path> section <sec>}` dicts) if
   set, else `models {}`. Set via set_ne default empty in ase.tcl. This also
   improves item-02 newview seeding (fresh state views inherit the default).
   Workarea rcs set it per technology:
   - sky130A/cadence_style_rc: `set ::ASE_DEFAULT_MODELS [list [list file
     [file join $::SKYWATER_MODELS sky130.lib.spice] section tt]]`.
   - gf180mcuD/cadence_style_rc: scout determines the correct gf180 model
     file + section from the gf180mcuD workarea (existing benches/corner
     symbol emit — match what a working gf180 op sim uses); set the same
     shape. If the honest default is ambiguous, set the tt/typical corner
     and note it. (These rc files are NOT in the pre-batch dirty list — item
     09 already committed to them at 05b2a708 — verify clean before staging.)
2. **Path→design resolver**: add a helper (library_defs.tcl or ase.tcl)
   reversing an abs schematic path to `{lib cell view}` by matching
   `xschem get schname` against the registered library roots
   (`xschem libraries`/library_list). Symbol/non-schematic current view →
   honest error via ciw_echo (ASE simulates schematic designs).
3. **Tools > Launch ASE-L**: new entry opens a FRESH in-memory ASE session
   bound to the current schematic's design (Cadence-like untitled session —
   NOT a .state file on disk until the user does Save State). Minimal:
   state_default (→ tech default models present, vars/analyses/outputs
   empty). If an ASE session already targets this design, raise it instead
   of duplicating. Needs a new `ase::launch_for_current` (resolve design →
   new_session) + an `ase::new_session {lib cell view}` blank-session entry
   distinct from open_state's file-load. Session key/title for an untitled
   session: `<cell> (unsaved)` or similar; scout picks, documents; the
   dirty-baseline is the initial default state (NOT dirty until edited — so
   item-16's prompt does not fire on an untouched launch).
4. Status-bar / title reflect untitled state; Save State (Save-As) persists
   it as an ngspice_state view (creation path from item 02).
5. Tests: test_ase_window.tcl (or new test_ase_launch.tcl) — headless: the
   resolver maps a known workarea schematic path → correct lib/cell/view +
   errors on a bogus/symbol path; state_default honors ::ASE_DEFAULT_MODELS
   (set global → models present; unset → empty); GUI: from a loaded
   test_nfet_final schematic, Tools>Launch ASE-L opens a session whose
   models pane shows the sky130 default and whose vars/analyses/outputs are
   empty; second launch on same design raises, not duplicates. ≥2 sabotages.

### 16 dirty-prompt

Anchors (scout re-verifies): dirty detect `ase::session_dirty` ase.tcl:515;
title marker refresh ase_window.tcl:2461/2503; close `ase::ui::close`
ase_window.tcl:227 (WM_DELETE→ it at :212; the :234 dirty check LOGS ONLY);
cleanup unsets :238-246; save `ase::ui::save_state_dialog` :2258 /
`do_save_state_as` :2409 (Save-As only, returns success/cancel — verify the
return contract); precedent `ask_save` xschem.tcl:9537 (yes/no/cancel);
app quit `quit_xschem` xschem.tcl:13426 (does NOT iterate ASE windows).

1. **On ASE session close** (WM_DELETE + any Ctrl-W/File>Close): if
   `ase::session_dirty`, prompt yes/no/cancel (mirror ask_save styling/
   return semantics; use the ASE theme). Yes → save_state_dialog; if the
   save is completed, proceed to close, if the Save-As is cancelled, ABORT
   the close (treat as Cancel). No → close discarding. Cancel → abort close,
   leave the window + per-window state arrays intact (no cleanup).
2. **On xschem quit** (`quit_xschem`): before exit, iterate open ASE
   sessions (`ase::ui::wins` or the session registry); for each dirty one,
   run the same prompt; a Cancel on ANY aborts the whole quit. Guard so the
   sweep is a no-op when no ASE sessions exist (must not change normal quit
   behavior / other windows). Scout confirms whether quit_xschem already has
   a dirty-schematic sweep to slot alongside, or if ASE needs its own hook.
3. Read-only-opened view: a dirty session whose backing view was opened RO,
   on Yes-save, goes through Save-As (its overwrite-confirm path from item
   07) — never silently writes the RO view.
4. Untitled launched sessions (item 15): dirty prompt on close if edited;
   Yes → Save-As creates the view.
5. Tests: GUI legs in test_ase_window.tcl (or test_ase_dirty.tcl) —
   edit a variable → session_dirty true; WM_DELETE → prompt appears
   (assert dialog exists), Cancel → window survives + state intact, No →
   window gone, Yes → Save-As path invoked; unedited session closes with NO
   prompt; quit path leg with a dirty session prompts (drive quit_xschem's
   ASE sweep directly if full-exit is untestable headless — document).
   Use send_return/send_key. ≥2 sabotages.
