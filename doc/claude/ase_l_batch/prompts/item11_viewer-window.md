# Item 11 — viewer-window (Round 3, Waveform Viewer window shell)

You are the IMPLEMENTER. Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch
`fluid-editing`. Execute this prompt end-to-end: code, tests, sabotage-verify,
ONE commit with the explicit file list at the bottom. Work from repo root.

Authoritative contract: `doc/claude/specs/waveform_viewer.md` (user-locked
architecture; READ IT FIRST). Parent spec: `doc/claude/specs/ase_l.md`.
Runbook: `doc/claude/ase_l_batch/RUNBOOK.md`. This item = the standalone
viewer WINDOW SHELL only — traces/cursors/plumbing are items 12-13. The shell
must be a correct, themed, stripped xschem window that can display an existing
graph rect fed from a real ngspice raw file.

**This item is PURE TCL + tests. No C changes. No rebuild needed.**

## Scout-verified anchors (2026-07-21; trust these lines, spec lines drifted)

Window creation / menubar:
- `create_new_window` src/xinit.c:1873 (called from new_schematic arms
  xinit.c:2520/2527). `MAX_NEW_WINDOWS` = 20 (src/xschem.h:158) — no cap risk.
- `build_widgets` src/xschem.tcl:14168 — builds the PER-WINDOW menubar
  `$topwin.menubar` and attaches it via `$topwin configure -menu` (~:14211).
  A window's menu is swappable per-window by construction.
- `xschem load_new_window` scheduler.c:6199-6271; `-window` flag :6210 forces
  a real toplevel even in tabbed mode; empty file arg `{}` → untitled buffer
  via `new_schematic("create_window", NULL, NULL, 1)` at :6249 (the
  pristine-untitled reuse arm at :6244 only fires for non-empty paths —
  cannot swallow the viewer). `xschem new_schematic` arm scheduler.c:7324.
- PROBE-VERIFIED live under WSLg: `xschem load_new_window -window {}` →
  new real toplevel `.x1`, buffer `untitled-1.sch`, auto-assigned
  `xschem get window_number` = 4 (shared C counter). Use THIS creation path.

Read-only machinery (the strip backstop):
- `xctx->readonly` per-window (src/xschem.h:1430). `xschem set readonly 0|1`
  scheduler.c:10072-10076 (calls `set_modify(-1)` → **rewrites the wm title**
  — probe-verified clobber, see D6). `xschem get readonly` scheduler.c:4059.
- `scheduler_readonly_reject` scheduler.c:173 — 29 mutating verbs incl.
  `rect` (:8910), `setprop` (:10367), `add_graph` (:1890) refuse under
  readonly (probe-verified: `xschem rect` errors "schematic is read-only").
- `readonly_block()` callback.c:35 — interactive keyboard/menu edit gate,
  pops a MODAL tk_messageBox (this is why keys must be filtered, see D2);
  `dispatch_input_action` callback.c:4124 gates registry keys with it at
  :4136. `begin_edit()` actions.c:155 — quiet core backstop.
- `set_modify` ro_suppress actions.c:189+ — a readonly buffer can NEVER be
  flagged modified (issue 0035) → no `*`, no save-on-close prompt. Save key
  quietly skipped at callback.c:4971. `xschem set_modify 0|1|3` verb
  scheduler.c:10226.

Key/mouse binding surface:
- `set_bindings` src/xschem.tcl:13843 — all events bind on the per-window
  `.drw` widget and funnel to `xschem callback`. Generic `<KeyPress>` /
  `<KeyRelease>` are per-widget → replaceable for ONE window only. Two
  more-specific key binds also exist per-widget and must be stripped too:
  `<Control-Shift-Key-P>` (command palette) and `<Key-$hi_descend_key>`
  (default E, hi_descend).
- `src/keybindings.csv` has a ctx column canvas|graph: graph-context rows
  (all → `graph.forward`) exist for keysyms f(102), t(116), s(115 ctrl),
  A(65), B(66), a(97), b(98), arrows(65361-65364) (+ctrl variants). Keys in
  waves_callback (callback.c:540, keys verified in source): a b s m t A B
  arrows f. Un-migrated editor keys (Insert=65379, w, c, …) go through the
  legacy switch — also readonly_block-gated (modal).
- Editor FocusIn → `switch_window` → `notify_window_active [xschem get
  window_number]` (src/xschem.tcl:13753/13759 — spec's 13724/13730 drifted).
  ciw.tcl:106/:129, library_manager.tcl:79 are the non-editor precedents —
  NOT needed here (viewer is an editor-numbered window, D5).

Graph engine / raw (read-only for this item, cited for orientation):
- draw.c `draw_graph` 4536-4950, `draw_graph_all` 4958; waves_callback
  callback.c:540; backannotate_at_cursor_b_pos callback.c:404;
  `graph_edit_properties` xschem.tcl:4736.
- save.c: `read_dataset` :593 and `raw_read` :1002 (**spec swapped the two
  names** — same machinery, noted drift).
- `xschem raw` scheduler.c:8517 (group fn :8367): read :8529, loaded :8573,
  datasets :8676, points :8678, vars :8690. **`raw loaded` returns
  sch_waves_loaded() — an INDEX: >= 0 means loaded, -1 not. Never use it as
  a boolean** (probe: returned 0 with 181 points loaded).
- Spec's "simulate() xschem.tcl:4056 sets raw_read callback" drifted: proc
  simulate is :4011; `xschem raw_read` sites are :5608/:5861/:14055-57.
  Irrelevant here — the viewer uses `xschem raw read` directly.
- Programmatic graph rect: `xschem rect x1 y1 x2 y2 pos prop draw`
  scheduler.c:8903 on the current layer; `xschem set rectcolor 2`
  scheduler.c:10115 selects the graph layer (GRIDLAYER=2). `xschem add_graph`
  scheduler.c:1887 is mouse-interactive (starts a move) — do NOT use it
  programmatically. `xschem get rects 2` returns layer-2 rect count
  (probe-verified). Coord introspection if needed: `xschem object rect #2,N`
  scheduler.c:7408; pointer in schematic coords: `xschem get mousex_snap`
  scheduler.c:3884.
- View verbs for menus: `xschem zoom_full` :11928, `zoom_in` :11960,
  `zoom_out` :11969, `redraw` :8968 — none readonly-gated (navigation).

ASE side:
- Session token = `ase::session_key` = `"$lib/$cell/$view"` (src/ase.tcl:422);
  `ase::session_open` :440, `session_state` (design dict inside),
  `ase::open_state` :556. Sessions are registerable headless with NO Tk.
- `ase::theme` src/ase_window.tcl:121 — named fonts AseLabelFont/AseEntryFont/
  AseMonoFont (:122-131) + locked palette dict :142-143 (panel #f2f2f2,
  table #ffffff, header #e8e8e8, accent #8b0000). Reuse; do NOT redefine.
- ngspice backend src/ase.tcl: `run_cmd` :672-674 = `ngspice -b $deckpath
  2>@1` — **NO -r arg** (scout question resolved, see D3); `render_deck`
  :595-668 (deck = netlist minus .end + .lib/.param/.options/.temp/.save +
  `.control` analyses + prints + `.endc` + `.end`; the .control block is
  always emitted); `log_file` :677; hook registry validation iterates
  `{render_deck run_cmd log_file result_probe}` at :189 (register_backend),
  :290 (run), :307 (run_existing); registration dict :711-715.
  `ase::run_deck` :329+ writes `<rundir>/<cell>_ase.spice` and runs from
  `[ase::rundir $state]`.
- Ship precedent: src/Makefile.in:22 tcl file list (ase.tcl ase_window.tcl…);
  src/xschem.tcl:14108 `source $XSCHEM_SHAREDIR/ase_window.tcl`. CMakeLists
  does not list the ase tcl files — no CMake change (item-01 precedent).
- WSLg raise idiom: `raise_activate_toplevel` src/xschem.tcl:5526 (receipt 05:
  bare deiconify/raise is a WSLg no-op; stackorder updates take ~2 s → tests
  retry-poll).
- Test helpers: `send_return` tests/headless/test_ase_window.tcl:155,
  `send_key` tests/headless/test_ase_dialogs.tcl:136/:115. Env pattern for a
  hermetic sky130 run: tests/headless/test_ase_final.tcl:44-66 (scratch
  library.defs pointing at committed trees, `::SKYWATER_MODELS`,
  `::XSCHEM_LIBRARY_DEFS`, `::library_registry_defs_only 1`).
- Regression fixture: `xschem_library/examples/test_ne555.sch` exists.

## Scout probes (empirical facts you rely on — do not re-litigate)

1. ngspice-42 (`/usr/bin/ngspice`): `ngspice -b -r out.raw deck` with a
   `.control` block runs the analyses but writes **NO raw file**. Adding
   `write out.raw` inside the `.control` block writes the CURRENT (= last
   analysis) plot; a dc 0→1.8 step 0.01 yields Plotname "DC transfer
   characteristic", 181 points. Bare `write` + `-r` writes nothing.
2. Title clobber: any `xschem set readonly 0|1` toggle rewrites the wm title
   to the editor format (`xschem [4] - untitled-1.sch`) via set_modify(-1) —
   probe-verified. Re-assert the viewer title after every toggle.
3. Full chain probe (WSLg DISPLAY): load_new_window -window {} → set
   readonly 1 → `xschem rect` rejected → readonly 0 → `set rectcolor 2` +
   `xschem rect 0 0 800 400 -1 <graph props> 1` → rect on layer 2 →
   `set_modify 0` → readonly 1 → modified stays 0 → `xschem raw read
   $raw dc` → points=181 sim_type=dc → `xschem redraw` rc 0. All green.

## Scout decisions (each binding; one-line justification)

- **D1 no-save mechanism = the readonly flag** (`xschem set readonly 1` on
  the viewer context, held for the window's life): actions.c ro_suppress
  makes `modified` unsettable → no dirty prompt on close by construction;
  save verb/key are gated/quietly skipped. Every programmatic mutation goes
  through `wviewer::with_edit` which ends `xschem set_modify 0` BEFORE
  restoring readonly, so modified can never stick (probe-verified).
  **Autosave caveat (scout-probed)**: write_backup (save.c:3503) DOES back
  up untitled buffers since issue 0060 (the actions.c:200 comment is
  stale) — a with_edit mutation writes `untitled-N~.sch` into the cwd.
  with_edit must bracket its script with save/`set autosave_backup 0`/
  restore (plain mirrored Tcl var, read per-call via tclgetboolvar; the
  script must not call `update`, so no foreign edit can interleave).
- **D2 strip mechanism = readonly enforcement (backstop) + per-window
  binding filter on the viewer's .drw ONLY**: readonly alone would pop the
  readonly_block MODAL on every editing key (callback.c:4136 + legacy
  sites) — wrong UX and it hangs tests. So on the viewer .drw: replace the
  generic `<KeyPress>`/`<KeyRelease>` binds with `wviewer::key_filter`
  (allowlist below), bind `<Control-Shift-Key-P>` and
  `<Key-$hi_descend_key>` to `break`-nothing, filter `<ButtonPress-3>` /
  `<ButtonRelease-3>` (forward only over a graph — kills the schematic
  context menu; over-graph Button3 is the C engine's graph pan/zoom), and
  swallow `<Double-Button-1/2/3>` entirely (D9). All other mouse bindings
  stay verbatim (wheel zoom, drag = graph cursor/pan via waves_callback;
  canvas mouse edits are readonly-refused at quiet core guards). Per-widget
  binds → provably cannot affect other windows.
  - key_filter allowlist, forwarded to the original `xschem callback` body:
    - always: f(zoom_full/graph fullx), Z zoom_in, ctrl-z zoom_out, arrow
      keys (scroll / graph pan), Escape (abort+redraw; never closes — D10).
    - only when `wviewer::over_graph` is true (pointer inside a layer-2
      rect, computed from `xschem get mousex_snap`/`mousey_snap` + rect
      coords via `xschem object rect #2,N`): a b s m t A B (+ctrl variants)
      — the waves_callback key set; outside graphs these are editor verbs
      (m=move, t=text …) and must do NOTHING silently.
    - Ctrl-W → `wviewer::close $token` (swallowed, handled Tcl-side).
    - everything else: swallowed (instance place Insert, wire w, copy c,
      undo u, …: silent no-op — the readonly backstop still covers any
      path the filter misses).
- **D3 raw production: do NOT add `-r`** — probe 1 proves `-r` is dead with
  .control decks (the spec's "-r arg" parenthetical was a mechanism guess;
  the CONTRACT is the rawfile artifact). Instead: (a) new backend hook
  `ase::backend::ngspice::raw_file {state}` → `<rundir>/<cell>_ase.raw`
  (mirror of log_file :677); add `raw_file` to the register_backend
  required-hook list (:189) and the registration dict (:711) — leave the
  :290/:307 pre-validation loops unchanged (they validate what they use);
  (b) `render_deck` emits `write [raw_file $state]` inside the `.control`
  block, after the print lines, before `.endc`, ONLY when >= 1 analysis is
  enabled (a plot-less `write` would error). Document this as a spec
  deviation in the receipt (mechanism differs, deliverable identical).
- **D4 window creation = `xschem load_new_window -window {}`** (probe 3):
  real toplevel in both window and tabbed models, untitled buffer, no
  prompt. Record `xschem get current_win_path` (.xN.drw) + `top_path` (.xN)
  immediately after.
- **D5 window number = the C-assigned editor number** (probe: 4): the viewer
  IS an editor-created window, numbered from the same counter the
  `allocate_window_number` seam uses; its FocusIn already runs
  switch_window → `notify_window_active` — no explicit notify call, no
  allocate_window_number (that verb is for non-editor toplevels like ASE).
- **D6 title** = exactly `Waveforms <design cell> (<state view>)` (spec
  format, no number — spec verbatim); `<design cell>` from
  `dict get [ase::session_state $tok] design cell` (fallback to the token's
  cell segment when design is empty, ase_window precedent), `<state view>`
  = 3rd `/`-segment of the token. Re-assert via `wviewer::retitle` after
  every with_edit cycle AND on a `+`-appended FocusIn bind (clobber probe 2).
- **D7 menubar replacement**: build a NEW menu `$top.wvmenubar` and
  `$top configure -menu $top.wvmenubar`. Leave the detached editor
  `$top.menubar` widget ALIVE (set_modify's catch-guarded entryconfigure
  calls keep resolving; destroying it buys nothing).
- **D8 display primitive** `wviewer::display_raw <token> <rawfile>
  <sim_type> <node> ?color?`: with_edit { set rectcolor 2; `xschem rect
  0 0 800 400 -1 <props> 1`; restore rectcolor } + `xschem raw read
  $rawfile $sim_type` + `xschem redraw`. Graph props = the spec example
  shape: `flags=graph`, x1/x2/y1/y2, divx/divy, `node="<node>"`,
  `color=<color>` (default 4), `dataset=-1`, logx=0 logy=0 (mirror the
  add_graph template scheduler.c:1892-1916, with node/color filled). This
  is the item-12 seam; item 12 may reshape it — keep it small.
  Honest assertability (document in the test header): headless/GUI can
  assert raw points/vars/sim_type, layer-2 rect count/props, redraw rc 0,
  modified still 0; actual PIXEL rendering is eyeball-only.
- **D9 double-clicks swallowed** in the viewer: dbl-click-on-graph opens
  graph_edit_properties whose writeback (`xschem setprop rect`) is
  readonly-rejected today; Axes… editing is item-12 scope by the item text.
- **D10 ESC forwarded** to the C callback (abort pending op + redraw, never
  closes a window) — satisfies "ESC must NOT close" with zero code; test it.
- **D11 close** `wviewer::close <token>`: `xschem new_schematic destroy
  <win_path>` (no prompt possible, D1); registry cleanup + a `<Destroy>`
  bind on the toplevel (guarded `%W eq $top`) so WM-close also cleans;
  `wviewer::open` additionally lazily validates registry entries with
  `winfo exists` before raising (raise = `raise_activate_toplevel`, WSLg).
- **D12 statusbar/toolbar**: leave the editor statusbar as built (harmless,
  zero-risk); no toolbar work. Theme scope = the viewer MENUS + any
  wviewer-created Tk widgets get ase::theme fonts/colors; the X11 canvas is
  the graph engine's own rendering and stays untouched.

## Deliverables

1. **`src/wave_viewer.tcl` (NEW)** — namespace `wviewer::` (TIP-278
   discipline: `variable` declarations, absolute names). Public surface:
   - `wviewer::open <session-token>` — raise-or-open ONE viewer per ASE
     session token. Unknown token → `ciw_echo … error` (under has_x) +
     return 0, never a throw (ase::open_state style). Fresh-open sequence:
     `xschem load_new_window -window {}` → record win_path/top → `xschem
     set readonly 1` → build+attach viewer menubar (D7) → apply theme →
     strip bindings (D2) → retitle (D6) → register in `variable windows`
     dict token→{top win_path} → return 1. Re-open: validate + raise via
     raise_activate_toplevel, return 1 (no new window, no number consumed).
   - `wviewer::close <token>` (D11), `wviewer::window_for <token>` (registry
     lookup, {} when dead/unknown — test seam), `wviewer::with_edit <token>
     <script>` (switch to viewer ctx `xschem new_schematic switch
     <win_path>`, readonly 0, run script, `xschem set_modify 0`, readonly 1,
     retitle), `wviewer::display_raw` (D8), `wviewer::retitle`,
     `wviewer::over_graph`, `wviewer::key_filter`.
   - Viewer menubar (D7), ase::theme applied: **File** (Close, accelerator
     Ctrl+W → wviewer::close); **View** (Fit → `xschem zoom_full`, Zoom In
     → `xschem zoom_in`, Zoom Out → `xschem zoom_out`, Redraw → `xschem
     redraw` — each wrapped to run in the viewer ctx); **Graph** (Add
     Graph, Add Trace…, Delete, Axes… — ALL `-state disabled`, comment
     `TODO(item12)`); **Cursors** (Cursor A, Cursor B, Readout — ALL
     disabled, `TODO(item12)`).
   - No Tk at source time (procs only) so --nogui sourcing stays safe;
     ciw_echo only under has_x checks (RUNBOOK).
2. **`src/ase.tcl`** — D3 exactly: `raw_file` hook proc + required-hook list
   (:189) + registration dict (:711) + `render_deck` conditional
   `write <rawpath>` line (after prints, before `.endc`, only when an
   analysis is enabled).
3. **Ship**: `src/xschem.tcl` — add
   `source $XSCHEM_SHAREDIR/wave_viewer.tcl` directly after the
   ase_window.tcl line (:14108); `src/Makefile.in` — add `wave_viewer.tcl`
   to the tcl list (:22). Never edit the generated `src/Makefile`.
4. **`tests/headless/test_wave_viewer.tcl` (NEW)** — below.
5. **`tests/headless/test_ase_core.tcl`** — update ONLY the D1 golden deck
   (the fixture state has `op` enabled → the golden gains the `write …
   test_nfet_final_ase.raw` line; every other check untouched). Justify in
   the receipt. Re-run ALL six ASE tests (core/view/window/dialogs/final/
   interact) — they must stay green; test_ase_final F8/F9/F10 are
   match-based and were scout-checked to tolerate the additive write line.

Do NOT touch: existing embedded-graph behavior (no draw.c/callback.c — this
item has NO C edits at all), any committed `.state` fixture (schema
unchanged), tests/run_regression.tcl (pre-batch dirty), ase_window.tcl.

## Test plan — tests/headless/test_wave_viewer.tcl

Own process, repo-root cwd, `--nogui --pipe -q --nolog --script` for the
headless launch documented in the header; full_audit auto-discovers it (its
DEFAULT arm runs with DISPLAY; GUI legs self-SKIP without a usable display,
main_ready-style retry-poll pattern from test_ase_window.tcl:52). Hermetic
env for the run leg = test_ase_final.tcl:44-66 pattern (scratch
library.defs → committed trees, ::SKYWATER_MODELS, scratch rundir override
in a COPY of the loaded state dict — never write the committed fixture).
`set no_recent_files 1` at the top of the GUI body (recent-files leak
lesson).

Headless legs (run with or without DISPLAY):
- **V1** render_deck (fixture state, op enabled) emits exactly one
  `write <scratch-rundir>/test_nfet_final_ase.raw` line inside
  `.control`…`.endc`, after the print line.
- **V2** render_deck with ALL analyses disabled emits NO write line.
- **V3** `ase::backend_hook ngspice raw_file` resolves and returns
  `<rundir>/<cell>_ase.raw`.
- **V4** (guard `auto_execok ngspice`, else SKIP) dc sweep in the scratch
  state (spec schema shape: `type dc enabled 1 source V2 start 0 stop 1.8
  step 0.01`, op left enabled) → `ase::netlist` + `ase::run_deck` +
  `ase::wait` → exit ok AND the rawfile exists non-empty.
- **V5** (needs V4) `xschem raw read <raw> dc` → `xschem raw sim_type` eq
  dc, `xschem raw points` == 181, `xschem raw vars` >= 2,
  `xschem raw loaded` >= 0 (INDEX semantics — never boolean). Then
  `xschem raw clear`-equivalent teardown if needed for later legs.
- **V6** regression (shipped embedded graphs): `xschem load` of
  `xschem_library/examples/test_ne555.sch` (readonly via `xschem set
  readonly 1`) → layer-2 graph rect count > 0, `getprop rect 2 0`
  contains `flags=graph`-class attrs intact, `xschem redraw` rc 0.

GUI legs (DISPLAY-guarded self-SKIP; every key/knob driven through the REAL
Tk event sequence — focus -force + event generate, send_return/send_key
helper pattern; register a recording stub for `::tk_messageBox` around
G5/G6 so a sabotage FAILS instead of hanging):
- **G1** register a session headless (`ase::session_open` on a scratch
  .state whose design cell = test_nfet_final) → `wviewer::open $tok` == 1
  → new toplevel exists, `wviewer::window_for` non-empty, viewer ctx
  `xschem get readonly` == 1, schname is untitled-class.
- **G2** `$top cget -menu` is the viewer menubar; cascade labels exactly
  {File View Graph Cursors}; every Graph + Cursors entry `-state disabled`;
  the editor menubar is NOT the attached menu.
- **G3** title exactly `Waveforms test_nfet_final (ngspice_state1)`; run one
  `wviewer::with_edit $tok {}` cycle → title STILL exact (clobber
  regression, probe 2).
- **G4** viewer ctx `xschem get window_number` > 0.
- **G5** strip: focus the viewer .drw; send KeyPress Insert (instance
  place), then w (wire): after update loops — instances == 0, wires == 0,
  modified == 0, tk_messageBox stub hit-count == 0 (no readonly modal), no
  new toplevel appeared.
- **G6** send Escape the same way → viewer toplevel still exists (ESC never
  closes), stub hit-count still 0.
- **G7** `wviewer::display_raw $tok <V4 rawfile> dc {i(v1)}` (when V4 ran;
  else create the graph rect only, raw legs SKIP): layer-2 rects == 1,
  rect props carry `node="i(v1)"`, raw points == 181 in the viewer ctx,
  redraw rc 0, modified == 0 and readonly == 1 AFTER (with_edit restored),
  and NO new `untitled*~.sch` autosave backup appeared in the cwd (D1
  autosave-caveat regression; snapshot the glob before the leg).
- **G8** `wviewer::open $tok` again → same toplevel raised, no second
  window, `xschem get window_number` unchanged.
- **G9** Ctrl-W as a real event on the viewer → toplevel destroyed with NO
  dialog/prompt (stub count 0); `wviewer::window_for $tok` now {};
  `wviewer::open $tok` afterwards creates a fresh window (then close it).

Also re-run: all six test_ase_* (must stay green; only test_ase_core D1
changed, justified) and `tests/headless/full_audit.sh` — fails must be a
subset of the PLAN.md baseline (WSLg flake list: test_deselect_mode,
test_hover_highlight, test_ase_window, test_close_window_restores_prev_tab
are rerun-first, receipts/05-06 precedent).

## Sabotage plan (>= 2; each: `git diff` confirms sabotage-only, targeted
`git checkout -- <file>` revert, clean re-run green)

- **S1** src/ase.tcl: delete the `write` emission in render_deck → must fail
  EXACTLY: V1 + V4-rawfile-exists + V5 legs (headless) and test_ase_core
  "D1 golden deck" — nothing else.
- **S2** src/wave_viewer.tcl: neuter the key_filter allowlist (forward
  everything unconditionally) → must fail EXACTLY G5 (stub records the
  readonly modal request; instances stay 0 — that check remains green,
  predicted split stated in the receipt).
- **S3** src/wave_viewer.tcl: drop the retitle call at the end of with_edit
  → must fail EXACTLY the G3 title-persistence check.

## Commit — ONE commit, stage EXACTLY these files

- `src/wave_viewer.tcl`
- `src/ase.tcl`
- `src/xschem.tcl`
- `src/Makefile.in`
- `tests/headless/test_wave_viewer.tcl`
- `tests/headless/test_ase_core.tcl`

Message: normal prose, e.g. `feat(wviewer): standalone waveform viewer
window shell — stripped, themed, raw-fed graph display` + the repo's
Co-Authored-By trailer. Verify with `git show --stat` that ONLY these files
landed. Pre-existing dirty tracked files that must NEVER be staged
(PLAN.md preflight): `doc/claude/specs/sky130_workarea.md`,
`sky130A/xschem_libs/library.defs`, `src/ciw.tcl`,
`tests/headless/test_sky130a_libmgr.tcl`, `tests/run_regression.tcl`,
`xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym`,
`xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`.
Also never stage `src/Makefile`, `src/xschem_subcommands.txt` (generated),
`_*` junk dirs, or scratch/probe leftovers.

## RUNBOOK policy block (verbatim, non-negotiable)

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
