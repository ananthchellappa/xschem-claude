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
