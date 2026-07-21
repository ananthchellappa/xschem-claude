# Item 03 — ase-window (P3 of doc/claude/specs/ase_l.md)

You are the IMPLEMENTER. Repo: /home/qflow/dev/xschem/claude_1/xschem, branch
fluid-editing. Read doc/claude/ase_l_batch/RUNBOOK.md and the spec
doc/claude/specs/ase_l.md (section "UI sketch" + "Subprocess + log streaming")
first. Items 01+02 landed (commits 20cc4df9, 307eaa64): src/ase.tcl has the
core (state I/O, backend registry, ngspice backend, ase::netlist/run/wait/
last_result) and a v0 `ase::open_state <lib> <cell> <view>` (read-only
textwindow). LibMgr (`libmgr::view_handler` / `libmgr::open_view`) and
hi_descend (`hi_descend_do`) already dispatch ngspice_state* views to
`ase::open_state` — item 03 needs NO dispatch work; you replace the BODY of
`ase::open_state` with the real ASE-L session window. Read src/ase.tcl and
both receipts (doc/claude/ase_l_batch/receipts/01_ase-core.md,
02_view-dispatch.md) before coding.

## Goal

`ase::open_state` opens (or raises) ONE ASE-L Tk session window per state
view: editable panes backed by a headless-testable session model, Session /
Simulation menus, live-streamed run log, Run/Stop with Cadence-style status
colors, Design Window raise-or-open, Cadence window number in the title.
Contracts that MUST survive:
- `ase::open_state {lib cell view}` name + signature + return codes (1 =
  view resolved, 0 = missing view, never an error) — test_ase_view V6.
- Headless (`![info exists ::has_x]`) calls of `ase::open_state` make NO Tk
  calls (session-model bookkeeping is fine).
- src/ase.tcl stays Tk-free (the open_state has_x-guarded delegation to the
  new GUI file is the ONE seam); all widget code goes in NEW
  src/ase_window.tcl.
- tests test_ase_core.tcl (33 checks) and test_ase_view.tcl must end green.
  test_ase_view's G1/G2 legs and its `find_state_viewer` helper assert the v0
  textwindow (toplevel titled exactly the .state path) — that surface is
  REPLACED by this item, so a minimal, declared update of those legs (assert
  the ASE window instead) is IN SCOPE (details below). Do not weaken V1-V11.

## Verified anchors (scout re-checked 2026-07-20 from source; cite these, the
PLAN.md sketch lines had drifted)

Window numbering (spec doc/claude/specs/window_numbering.md):
- Allocator: `static int window_number_counter = 3;` src/xinit.c:59;
  `assign_window_number()` xinit.c:597-600 (`xctx->window_number =
  window_number_counter++`), called ONLY at the 3 editor birth sites
  (xinit.c:1939 create_new_window, :2092 create_new_tab, :3320 startup).
  Monotonic, never reused (spec D2); CIW=1 ciw.tcl:106, LibMgr=2
  library_manager.tcl:79 are reserved constants; scratch ctxs stay 0 (D8).
- `xschem get window_number` scheduler.c:4250-4252 ('w' bucket of get).
- `notify_window_active {num {name {}}}` proc src/ciw.tcl:129-135 (dedupe on
  ::last_active_window); editor FocusIn call sites xschem.tcl:13753 and
  :13759 inside proc `switch_window` (:13741) — the PLAN's "xschem.tcl:13724"
  anchor is this proc, drifted.
- `xschem windows` scheduler.c:~11687-11716 → list of
  `{win_path top_path group xwindow current_name number}`; current_name is
  the context's full sch path, number the Cadence number (6th field).
- `xschem new_schematic switch <win_path>` = programmatic context switch
  (precedent xschem.tcl:5602, :5858); `xschem activate_window <xid>` =
  EWMH raise without remap (scheduler.c xschem_cmds_a, issue 0054).

Subprocess / status plumbing (all in src/xschem.tcl, git-clean):
- `execute {status args}` :352-396 — per-id array entries documented
  :223-239: `execute(pipe,$id)` holds the Tcl pipe channel (:380),
  `execute(data,$id)` the accumulated stdout (:383), `execute(callback,$id)`
  taken from `execute(callback)` (:360-362).
- `execute_fileevent` :242-326 — appends 1024-byte chunks:
  `append execute(data,$id) [read $execute(pipe,$id) 1024]` (:245). A
  `trace add variable ::execute(data,$id) write` therefore fires per chunk —
  the live-log trace granularity IS usable (decision D3 below). On EOF:
  exitcode into `execute(exitcode,$id)` + `(exitcode,last)` (:295-296),
  callback eval'd at #0 (:310-313), then `execute(pipe,$id)` and
  `execute(data,$id)` unset (:318-319; the unset also kills any element
  trace; `vwait ::execute(pipe,$id)` wakes on it — ase::wait does this).
- `kill_running_cmds {{lb {}} sig}` :401-… — FIRST-ARG-NUMERIC branch:
  `kill_running_cmds <id> <sig>` kills via
  `exec kill $sig [pid $execute(pipe,$id)]` (:403-410). The pid accessor the
  item detail asked the scout to verify ALREADY EXISTS — add none.
- `simulate` :4011-4087 — launch turns the Simulate button orange
  (:4068-4073); completion callback `set_simulate_button {top_path win_path}`
  :13662-13693: exitcode 0 → `Green`, nonzero → `red`, none → `$simulate_bg`
  (the captured default background, xschem.tcl:14479). Mirror the SEMANTICS
  (orange=running, Green=ok, red=fail) on ASE's own widgets; capture your
  button's default `-background` at creation for the idle color instead of
  depending on the `simulate_bg` global.
- `textwindow {filename {ro {}}}` :11657 — creates `.win<N>` titled with the
  filename; non-empty `ro` omits Save (the read-only viewer for Netlist/Log).
- `force_window_repaint {win {tries 0}}` :5495; the WSLg deferred-repaint
  idiom is `after 120 [list force_window_repaint [xschem get current_win_path] 0]`
  (library_manager.tcl:494).

Dispatch already landing here (do not touch, just keep the contract):
- `libmgr::view_handler` library_manager.tcl:440-447; divert in
  `libmgr::open_view` :463-464 (proc starts :452); `open_view_ro` divert
  before `xschem set readonly 1`; the editor `-gui` load arm with gated
  action-log :480-489 + WSLg repaint :494 — this arm is the Design Window
  open-precedent to copy.
- `hi_descend_do` state-row intercept xschem.tcl:5895-5907
  (`return [ase::open_state $lib $cell [lindex $row 0]]`);
  `hi_descend_finish` refuse :5768-5776.
- src/ase.tcl: `ase::open_state` v0 body :297-312 (REPLACE); `ase::run`
  :199-239 (returns execute id; takes optional completion callback eval'd at
  #0 by `ase::run_done` :244-264 AFTER log flush + result probe);
  `ase::wait` :268-277; `ase::last_result` :281-285; `ase::rundir` :134-142;
  `ase::netlist` :154-189 — NOTE its GUI guard: with has_x and the design NOT
  the current schematic it ERRORS ("open its design window first"), by design
  (item-01 decision); the Run flow below handles this via Design Window.
  `variable backends` :28 (dict name→hooks).
- ase.tcl is sourced at xschem.tcl:14106; shipped via `install_shares`
  src/Makefile.in:22 (tmpasm — edit the .in, never src/Makefile).
- Test patterns: tests/headless/test_ase_view.tcl G1-G3 :164-212 (green under
  WSLg; real double-click as two Press/Release pairs — Tk rejects
  `event generate <Double-1>`; partial-skip banner "gui legs skipped (no
  DISPLAY)" + `RESULT: ALL PASS`); geometry-ready retry proc
  tests/headless/test_wire_stub_bindings.tcl:43-50
  (`wm geometry . 1000x800` + update loop until .drw mapped >300px).
- full_audit.sh: default arm runs `--pipe -q --nolog --script` (:130) and
  auto-discovers test_*.tcl; `is_pass` wants `RESULT: ALL PASS` (:86),
  `is_skip` wants `RESULT: SKIP` (:92). test_ase_window belongs in the
  DEFAULT arm — do NOT add it to nogui_tests (:69), do NOT edit full_audit.sh
  at all.

## Scout decisions (resolved micro-decisions — follow unless code reality
contradicts, then document)

- D1 window-number allocation: NEW minimal C seam `xschem
  allocate_window_number` returning `window_number_counter++`. The counter is
  file-scope static in xinit.c and is the ONLY collision-free allocator: any
  pure-Tcl "max(xschem windows)+1" scheme hands out a number the C counter
  will hand out again on the next File>New Window (closed windows make the
  counter run ahead of the visible max). Implementation (C89):
  - xinit.c: `int allocate_window_number(void)` next to
    `assign_window_number()` (:597), returning `window_number_counter++`,
    with a comment naming doc/claude/specs/window_numbering.md + ASE-L.
  - xschem.h: extern decl next to `get_tab_or_window_number` (:2047).
  - scheduler.c: branch in `xschem_cmds_a` (:1560; alphabetically after
    `activate_window` ~:1578) with the house doc-comment style; result via
    `Tcl_SetResult(interp, my_itoa(...), TCL_VOLATILE)`. It MUTATES the
    counter, so it is a verb, not a `get` — and it must live in the 'a'
    dispatch fn or it is silently unreachable (scheduler-letter-dispatch
    lesson). Rebuild with `cd src && make`; no Makefile.in OBJ change needed
    (all three files already build).
  This preserves spec D2 (monotonic, never reused) across editor AND ASE
  windows. Numbers are consumed only when an ASE window is CREATED (not on
  raise, not headless).
- D2 Stop: use the EXISTING `kill_running_cmds $id -9` numeric branch — no
  new accessor (the item's "adds the minimal accessor if missing" is moot,
  it exists). -9 for a deterministic abort (close() then reports CHILDKILLED
  → nonzero exitcode → red status; SIGTERM would leave ngspice grace-period
  timing in the test). Wrap in catch and skip on Windows
  (`regexp -nocase {windows} $::OS`, the execute_fileevent idiom) — RUNBOOK
  "guard unix-only subprocess paths"; the Windows arm just ciw_echo's that
  Stop is unavailable.
- D3 live log: PRIMARY plan works — `trace add variable ::execute(data,$id)
  write` appending the delta (`string range $data $lastlen end`, keep a
  per-session lastlen) into the read-only log text widget. Granularity
  confirmed at xschem.tcl:245 (1024-byte chunk appends). Attach the trace
  immediately after `ase::run` returns the id — the pipe is fileevent-driven,
  so no data can arrive before you attach (single-threaded event loop). The
  EOF unset (:319) removes the element trace automatically; do the FINAL
  append + status color from the ase::run completion callback (run_done
  writes the log file + last_run first, so exitcode/log are ready). The
  fileevent-clone fallback is NOT needed — do not build it.
- D4 model/view split: headless session model in src/ase.tcl (pure dict, no
  Tk), Tk widgets in NEW src/ase_window.tcl (namespace `ase::ui`). ase.tcl's
  header carve-out shrinks back to "open_state delegates to ase::ui under
  has_x". Session API (exact names — the headless test drives these):
  - `ase::session_key lib cell view` → `lib/cell/view` string key.
  - `ase::session_open key path` → state_load + register
    {path, state, saved(=state)}; re-open refreshes from disk only when NOT
    dirty (a dirty session keeps its edits; re-open just raises).
  - `ase::session_state key` → current dict ({} if unknown key).
  - `ase::session_update key newstate` → replace dict; dirty = (state ne
    saved, dict-compared via canonical `ase::state_save`-order string or
    plain dict equality on the canonical keys + unknowns).
  - `ase::session_dirty key` → 0/1.
  - `ase::session_save key` → `ase::state_save path state`; saved←state.
  - `ase::session_load key` → re-read file from disk (Session>Load State);
    saved←state←file.
  - `ase::session_revert key` → state←saved.
  - `ase::session_close key` → unregister.
  - `ase::backend_names` → `lsort [dict keys $backends]` (simulator
    combobox values; TIP-278: `variable backends` first).
  - Notify seam: `ase::session_notify` variable (command prefix, default {});
    session_update/save/load/revert invoke it with the key when set.
    ase_window.tcl sets it to refresh title (dirty `*`) + panes. Headless it
    stays {} — no Tk reachable.
- D5 open_state body (in ase.tcl):
  1. resolve `xschem cellview_path $lib/$cell $view`; {} → ciw_echo error
     (has_x-guarded as today) + return 0.
  2. `set key [ase::session_key ...]`; `ase::session_open $key $path`
     (headless too — pure dict).
  3. `![info exists ::has_x]` → return 1 (no Tk, contract kept).
  4. window already exists for key (`ase::ui::window_for $key` ne {} &&
     winfo exists) → deiconify + raise + focus, return 1 (re-open raises —
     NO new number).
  5. else `ase::ui::open $key $lib $cell $view`, return 1.
- D6 window identity: toplevels named `.ase<N>` where N = the allocated
  window number (unique forever, so no collision with textwindow's .win<N>);
  `ase::ui::window_for key` maps session key → toplevel path (test seam).
  Title `ASE-L ($N) — $lib/$cell [$view]`, dirty appends ` *`.
  `bind .ase$N <FocusIn> [list +notify_window_active $N "ASE-L $lib/$cell"]`
  (the CIW/LibMgr pattern; dedupe is inside notify_window_active).
  Window close (WM_DELETE_WINDOW + Session>Close) destroys the toplevel,
  removes any live-log trace bookkeeping and calls `ase::session_close`
  (decide-and-document: prompt says discard-on-close is fine, no modal
  save-nag required for v1; a dirty session close ciw_echo's a notice).
- D7 panes (all inside the one toplevel; entry-grid approach — simplest
  reliably-scriptable widgets; exact layout is implementer latitude, the
  BEHAVIOR below is not):
  - variables: one row per entry {name value}: name label/entry + value
    entry. analyses: per-type labelled frames op/dc/ac/tran, each an
    `enabled` checkbutton + the type's arg entries (op: none; dc:
    source/start/stop/step; ac: points/start/stop/dec; tran: step/stop —
    the spec schema fields). outputs: rows {name expr save-checkbox}.
    models: rows {file section}. options: rows {name value}.
    rundir: entry; simulator: ttk::combobox -values [ase::backend_names]
    -state readonly.
  - Every commit-edit path (Return/FocusOut on an entry, checkbox toggle,
    combobox selection) rebuilds the state dict from the widgets and calls
    `ase::session_update` — the ONE write path; the notify hook repaints the
    title. Widgets are (re)populated from `ase::session_state` on open and
    after save/load/revert notifications. Add/remove-row buttons for the
    list panes (variables/outputs/models/options) — Cadence has them and
    item 04's proof edits variables; keep them minimal (append empty row /
    delete last-focused row).
- D8 menus/buttons:
  - Session: Save State (`ase::session_save`), Load State
    (`ase::session_load` + repopulate), Revert (`ase::session_revert` +
    repopulate), Design Window, Close.
  - Simulation: Netlist, Run, Stop, View Netlist, View Log. Buttons row:
    [Netlist] [Run] [Stop] + status light (a small label whose -background
    carries idle/orange/Green/red).
  - Netlist: `ase::netlist [ase::session_state $key]` under catch → on
    success `textwindow $nl ro`; on error ciw_echo the message (no popup).
  - Run: if design is not the current schematic (`[file normalize [xschem
    get schname]] ne` resolved design path) call the Design Window flow
    first, `update`; if STILL not current → ciw_echo error + status red +
    return. Else `set id [ase::run $state [list ase::ui::run_finished $key]]`
    (catch → ciw_echo + red), store id in the session, attach the D3 trace,
    status orange, clear the log widget. `ase::ui::run_finished` appends the
    tail delta, sets Green/red from `::execute(exitcode,last)` (run_done has
    already flushed the log + parsed results), drops the run id.
  - Stop: no live id → ciw_echo notice; else D2 kill. Status turns red via
    the normal completion path (the killed pipe EOFs into run_finished).
  - View Log: `textwindow [<backend log_file hook> state] ro` if the file
    exists, else ciw_echo notice. View Netlist: same on <rundir>/<cell>.spice.
- D9 Design Window (`ase::ui::design_window key`):
  1. resolve design {lib cell view} from the session state via
     `xschem cellview_path` (default view schematic — ase::netlist idiom
     ase.tcl:159-171); error → ciw_echo, return 0.
  2. scan `xschem windows`: entry with `[file normalize [lindex $e 4]]` ==
     path → `xschem new_schematic switch [lindex $e 0]` (deterministic
     context switch, does not rely on WM focus) + raise the owning toplevel
     (`[lindex $e 1]` — "." means the main window `.`): wm deiconify +
     raise + focus (optionally `xschem activate_window [winfo id $top]`).
     Return 1.
  3. else open via the libmgr::open_view `-gui` precedent VERBATIM
     (library_manager.tcl:484-489 + :494): `xschem log_action -reset`,
     `xschem load -gui $f`, gated `xschem log_action "xschem load -gui {$f}"`,
     then `after 120 [list force_window_repaint [xschem get current_win_path] 0]`.
     Return 1.
- D10 test_ase_view.tcl minimal update (declared in the commit message):
  replace `find_state_viewer` with a lookup through `ase::ui::window_for`
  (or .ase* title scan); G1 asserts the double-click opened the ASE session
  window; G2 asserts open_view_ro opened it AND `xschem get readonly`
  stayed 0 (unchanged assertion); the V6 GUI-side cleanup destroys the ASE
  window via its Close path. NOTHING else in that file changes; headless
  V1-V11 must pass untouched.
- D11 file shipping: src/ase_window.tcl added to `install_shares`
  src/Makefile.in:22 (next to ase.tcl) and sourced from xschem.tcl
  immediately after the :14106 `source ...ase.tcl` line. No CMakeLists.txt
  change (item-01 precedent: ase.tcl was not added there). ase_window.tcl is
  proc-definitions-only at source time (safe under --nogui).

## Deliverables

1. src/xinit.c + src/xschem.h + src/scheduler.c: `xschem
   allocate_window_number` (D1). Build green: `cd src && make`.
2. src/ase.tcl: session model API + backend_names + notify seam (D4),
   open_state body replacement (D5), header comment updated.
3. src/ase_window.tcl (NEW): `ase::ui` — window build (D6/D7), menus/buttons
   + status light + live log pane (D8, D3), Design Window (D9), Stop (D2).
4. src/xschem.tcl: one `source $XSCHEM_SHAREDIR/ase_window.tcl` line after
   ase.tcl. src/Makefile.in: install_shares += ase_window.tcl (D11).
5. tests/headless/test_ase_window.tcl (NEW, below) green headless AND under
   DISPLAY; tests/headless/test_ase_view.tcl G-legs updated (D10);
   test_ase_core untouched and still 33/33.

## Test: tests/headless/test_ase_window.tcl

Default full_audit arm (`./src/xschem --pipe -q --nolog --script ...` from the
repo ROOT; add DISPLAY for GUI legs). Copy the test_ase_view harness idioms
(check/check_true, scratch `_ase_window_[pid]` dir + scratch library.defs +
`::XSCHEM_LIBRARY_DEFS` + `::library_registry_defs_only 1`, big catch,
cleanup, `RESULT: ALL PASS (N checks)` banner, exit code). Fixture: the
embedded clean-nfet sch text from test_ase_core.tcl:39-56 + sky130A models
path (:33), state view seeded via `library_new_view aselib nfet_clean
ngspice_state1 ngspice_state1` then edited (models/variables/outputs/options
of the nfet state, rundir → scratch) through session procs + session_save.

Headless legs (ALWAYS run, no Tk):
- H1 session_open loads the seeded state; session_state design points at the
  schematic; session_dirty 0.
- H2 session_update with a changed Vgs → dirty 1; session_save → file
  contains the new value (string match on the saved file) AND dirty 0.
- H3 session_revert after another update → state back to saved, dirty 0;
  session_load re-reads disk.
- H4 open_state contract: existing view → 1 (and session registered);
  missing view → return 0, no error (catch == 0).
- H5 allocator seam: two `xschem allocate_window_number` calls → integers,
  second == first+1, first >= 3.
- H6 backend_names contains ngspice.

GUI legs (test_ase_view :165 guard `[info exists ::has_x] && [info commands
winfo] ne {}`; else puts "gui legs skipped (no DISPLAY)"). Use the
`ready`-style geometry proc (test_wire_stub_bindings :43-50) before legs that
need the MAIN window; legs that only touch the .ase toplevel don't need it.
Any leg that after retries still lacks a usable main window must puts a
"SKIPPED: <leg> (WSLg geometry)" line and not FAIL:
- W1 `ase::open_state aselib nfet_clean ngspice_state1` → 1; window_for key
  exists, toplevel name matches {.ase[0-9]+}; title matches
  `ASE-L (N) — aselib/nfet_clean [ngspice_state1]` with N == the number in
  the toplevel name; variables pane shows the seeded Vgs value (widget get).
- W2 re-open: second open_state → same toplevel path, still exactly one
  .ase* toplevel, returns 1 (raise path, no new number consumed: call
  allocate_window_number before+after the re-open → delta exactly 1, i.e.
  only the probe itself).
- W3 edit-through-widget: set the Vgs value entry's content
  (delete/insert), then `event generate <entry> <Return>` (the commit
  binding under REAL event; typing per-char is not required — the binding
  under test is Return/FocusOut, gesture-test-full-sequence lesson) → title
  ends with ` *`, session_dirty 1; invoke Session>Save State via the REAL
  menu (`.ase$N` menubar `invoke`) → file contains the new value, title `*`
  gone.
- W4 Design Window: invoke the menu entry → `xschem get schname` normalized
  == the fixture schematic path; `xschem windows` has an entry with that
  current_name (assert window list — raise-or-open both acceptable
  outcomes).
- W5 Netlist button invoke (after W4, design current) → a `.win*` textwindow
  titled with the netlist path exists and its text widget contains `XM1`;
  destroy it.
- W6 Run (guard `auto_execok ngspice`, else puts "SKIPPED: run legs (no
  ngspice)"): press Run (button invoke), `ase::wait` on the session's run
  id → log WIDGET non-empty and contains `No. of Data Rows`, contains the
  `-i(v1)` result line class, status light -background Green, log FILE
  written in the scratch rundir.
- W7 Stop (same ngspice guard): switch the session state to a long tran
  (e.g. enabled tran step 1n stop 10s) via session_update + Run; after the
  id exists and (poll ≤ ~5s for) some data arrived, press Stop; ase::wait →
  nonzero exit, status light red, `::execute(pipe,$id)` gone (clean
  teardown). Restore the op-only state after.
- W8 Close: Session>Close → toplevel destroyed, window_for key → {}.

## Sabotage plan (≥2 required; run each after the commit, revert via targeted
`git checkout -- <file>` after `git diff` shows only the sabotage; each must
fail EXACTLY its target check(s), then clean re-run green)

- S1 (src/ase_window.tcl): break the live-log delta append (e.g. append {}
  instead of the delta in the trace handler) → W6 "log widget non-empty /
  Data Rows" fails EXACTLY (log FILE check stays green — run_done wrote it —
  proving the widget path was really exercised). Needs DISPLAY + ngspice.
- S2 (src/ase.tcl): make session_save write `saved` instead of `state` →
  H2 "file contains the new value" fails EXACTLY (headless, exact-attribution
  run with `env -u DISPLAY`).
- S3 (src/xinit.c or scheduler.c): make allocate_window_number return a
  constant (no increment) → H5 second==first+1 fails EXACTLY (rebuild before
  running; rebuild again after revert).

## Verification gates (in order)

1. `cd src && make` green (C seam).
2. Standalone: test_ase_window headless (`--nogui` NOT used — default-arm
   flags `--pipe -q --nolog --script`, but ALSO verify a true `env -u
   DISPLAY` run prints the partial-skip line and passes); test_ase_window
   under WSLg DISPLAY; test_ase_core (33/33, its nogui arm); test_ase_view
   (updated, headless + DISPLAY).
3. Sabotages S1-S3.
4. tests/headless/full_audit.sh — fail set must be a subset of the PLAN.md
   baseline (re-run any new fail in isolation before concluding; WSLg flakes
   documented in receipts 01/02). test_ase_window/test_ase_view/test_ase_core
   PASS inside the audit.

## Commit (ONE commit, stage EXACTLY these files)

- src/xinit.c
- src/xschem.h
- src/scheduler.c
- src/ase.tcl
- src/ase_window.tcl
- src/xschem.tcl
- src/Makefile.in
- tests/headless/test_ase_window.tcl
- tests/headless/test_ase_view.tcl

NEVER stage: src/Makefile (generated), tests/run_regression.tcl or any other
pre-batch dirty file (PLAN.md preflight list), scratch dirs
(`_ase_window_*`), junk dirs. Commit message: normal prose ("feat(ase): ASE-L
session window — panes, live log, run/stop, design window" or similar),
declare the test_ase_view G-leg update, Co-Authored-By trailer per repo
convention.

## RUNBOOK policy block (verbatim)

## Policies (non-negotiable)

- Git: NEVER `git reset --hard`, NEVER `git add -A`/`commit -a`, NEVER push.
  Stage explicit file lists only. Pre-existing dirty tracked files at batch
  start (listed in PLAN.md preflight) must NEVER be staged; in particular
  `tests/run_regression.tcl` is dirty pre-batch → this batch does NOT register
  tests there; tests/headless/full_audit.sh auto-discovers `test_*.tcl`.
- A green suite ≠ the changed code ran: sabotage-verify (each sabotage fails
  EXACTLY its target check, revert via targeted `git checkout -- <file>` only
  after `git diff` confirms the file holds nothing but the sabotage, clean
  re-run green).
- Headless traps: each test its own process; repo-root cwd for relative paths;
  script error idles rather than hangs; `--nogui --pipe -q --nolog --script`.
- GUI tests: DISPLAY-guarded self-SKIP (`winfo exists .` guard pattern from
  full_audit.sh); replay WHOLE Tk event sequences in the shipping rc profile.
- User-facing messages via `ciw_echo`, not puts/statusbar.
- Tcl: TIP-278 (`variable`/absolute names in namespaces); C (if any): C89,
  `_ALLOC_ID_` placeholders. Windows: guard unix-only subprocess paths.
- Do not touch `_nhangle_*`/`_allm_*`/junk dirs or anything outside declared
  scope. Do not edit generated files (Makefile from Makefile.in — tmpasm, no
  `$@`/`$<`, `@` is the delimiter).
- Commit messages: normal prose, Co-Authored-By trailer per repo convention.
