# Item 14 persistence-accept — implementation prompt (ROUND 3 FINAL, acceptance gate)

Scout-verified 2026-07-21 at HEAD 10649ec8 (branch fluid-editing, working
tree carries pre-batch dirty tracked files — see the staging ban below).
Every file:line anchor below re-verified from source THIS session.

AUTHORITATIVE CONTRACT: doc/claude/specs/waveform_viewer.md — the
"Persistence" bullet (:76-81), the "Item 13 notes (as shipped)" section
(:83-114, esp. the auto-1 marker :94-96 and the raw seams :101-110), and
the item-14 line (:128-129). That file is currently UNTRACKED
(`?? doc/claude/specs/waveform_viewer.md`); THIS item both edits it
(deliverable 5) and — per the driver's explicit item detail, superseding
the item-13 ledger-carry arrangement — INCLUDES it in the commit file
list (a first `git add` of an untracked file; NOT a pre-existing dirty
tracked file, so the staging ban does not apply to it).
Context receipts: receipts/11 (viewer shell, raw_file hook), receipts/12
(viewer model/menus, setprop-flag-order + raw-add landmines, engine
cursor ground truth), receipts/13 (auto-1 marker must round-trip,
last_rawfile/plot_sim_type seams, semaphore-bracket after-idle landmine).

This is the ROUND-3 ACCEPTANCE GATE: if the whole-flow GUI leg
(deliverable 4) cannot pass honestly — zero SKIPs on that leg in the
proof run, no in-test workarounds — the item FAILS. No DEFER exists in
this batch.

## Scope — viewer persistence in the ASE state + whole-flow acceptance

Product files: `src/ase.tcl`, `src/ase_window.tcl`, `src/wave_viewer.tcl`.
Fixture: `sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state`
(one appended line — see D2). Tests: NEW
`tests/headless/test_ase_persist.tcl` + ONE updated assertion in
`tests/headless/test_ase_core.tcl` (R1 key count — see D3). Spec:
`doc/claude/specs/waveform_viewer.md`. Pure Tcl, zero C changes, no build
needed, no Makefile.in change (no new src files; all three product files
already ship — src/Makefile.in:22-23, source sites
src/xschem.tcl:14106/14108/14110). Tests are auto-discovered by
tests/headless/full_audit.sh — do NOT touch tests/run_regression.tcl
(pre-batch dirty).

1. **`viewer` state key** — schema key + default `viewer {}`; serialize
   the live viewer model (graphs incl. traces/axes/log + the `auto 1`
   marker) through ase::state_save; old states (no viewer key) load via
   the default merge; viewer absent/open-0 → NO viewer auto-open.
2. **Save State snapshots the live viewer** — viewer open → `open 1` +
   current graphs; viewer closed → `open 0` + last-known graphs (kept,
   not wiped).
3. **Load/open relaunch** — fresh `ase::open_state` and Session > Load
   State with `viewer open 1` relaunch the viewer AFTER the session
   window is up, restore graphs, attach raw via `ase::last_rawfile` IFF
   the rawfile exists (missing rawfile → viewer opens with layout, traces
   draw empty, ciw_echo notice, NO crash).
4. **ACCEPTANCE GATE whole-flow GUI leg** (see the test plan G-legs).
5. **Spec update** — Persistence paragraph rewritten as-shipped + an
   "Item 14 notes (as shipped)" section (item-13 notes pattern).
6. Tests + ≥2 sabotages (this plan prescribes 3).

## Corrected anchors (verified 2026-07-21 at 10649ec8; trust these)

src/ase.tcl (779 lines):
- :29-31 `schema_keys` {version simulator design rundir temperature models
  variables analyses outputs save_all_v save_all_i options includes}.
- :46 state_get; :115-130 state_default (13 keys; analyses default has op
  enabled); :136-150 state_load (merge over defaults, unknown keys
  preserved); :157-173 state_serialize (schema order then lsort'd unknown
  keys, `$k [list $v]` per line — the dirty-compare form); :176-181
  state_save.
- :222-230 rundir; :242-277 netlist (GUI guard: design must be the
  current schematic); :285 run; :302 run_existing; :329 run_deck; :371
  run_done; :395 wait (the SEMAPHORE bracket — receipts/13 landmine).
- :423-433 `ase::plot_sim_type` (LAST enabled analysis in fixed op dc ac
  tran emit order; {} when none); :441-448 `ase::last_rawfile <key>`
  (backend raw_file path IFF the file exists — the has-results predicate
  AND the saved-results seam; keyed by SESSION key, needs a registered
  session).
- Session model: :457 session_key; :476-485 session_open; :495
  session_state; :503-509 session_update (fires session_notify); :513-519
  session_dirty (serialize compare); :523-531 session_save (writes the
  session's own path, saved <- state); :535-543 session_load; :547
  session_revert; :556-560 session_close; :564-574 setattr/getattr.
- :592-621 `ase::open_state <lib> <cell> <view> {ro 0}` — the ONE
  Tk-guarded seam. Headless returns 1 at :611 BEFORE any Tk. Raise arm
  :612-618 (window exists → deiconify/raise/focus, return 1). Fresh-open
  arm :619 `ase::ui::open $key $lib $cell $view`.
- ngspice backend :625-779: render_deck :632 (emits `write [raw_file]`
  when >=1 analysis enabled :709-716); raw_file :740-746
  (`<rundir>/<cell>_ase.raw`); result_probe :753.

src/ase_window.tcl (2861 lines):
- :62-117 `ase::ui` namespace vars (wins/wnum/meta, dlg, sod...).
- :198-216 `ase::ui::open` — allocate window number, build, populate,
  `return $top`. THE fresh-open-only hook point (D6).
- :222-251 `ase::ui::close` — session_close, destroy, then
  `catch {wviewer::close $key}` at :246 (item-13 lifecycle), sod_end
  last. Note: session is unregistered BEFORE wviewer::close, so any
  snapshot attempted there would no-op — do NOT snapshot at close (D5).
- build: Session menu :270-282 (Design Window :272, Load State :277,
  Save State :279, Close :282); Simulation menu :321-336 ({Netlist and
  Run} :329); Results menu :342-351 ({Direct Plot} :344, live);
  strip `~` button :411-412 (`$top.strip.plot`, live).
- :452-498 build_pane (pane tv at `$top.body.{vars,ana,outs}.tv`;
  <Button-1> checkbox-cell flip via pane_click :526-544 — outs plot/save
  cells flip via toggle_flag :548-564).
- :757-804 populate (values wrapped in ase::format_value); :809-826
  refresh_output_values.
- Dialog scaffold :867-899: bind_dialog_esc :867, dialog_frame :874,
  dialog_row :882 (entries at `$w.<ename>`), dialog_buttons :890
  (`$w.btns.proceed` / `$w.btns.cancel`, ESC by construction).
- Choose Analyses :1507-1534 (`$top.chana`; radios `$w.types.{op,dc,ac,
  tran}` with -command chana_show; Enable checkbutton `$w.enable` on var
  `::ase::ui::dlg($key,anen)`); chana_show :1539-1559 (dc quick fields →
  entries `$w.source $w.start $w.stop $w.step`, each <Return> bound to
  chana_ok); chana_ok :1566-1605 (validates enabled → non-empty fields;
  commits the shown type ONLY; closes via chana_cancel).
- Select-On-Design/Direct-Plot: select_on_design :1130-1161; sod_end
  :1171-1200; sod_click :1210-1249; dp_queue :1275-1285; dp_finish
  :1297-1322 (op gate, wviewer::open, last_rawfile→attach_raw, ONE new
  graph per invocation); direct_plot :1327-1329; open_viewer :1333-1335.
- Load State: load_state_dialog :2131-2170; load_state_ok :2202-2227;
  `do_load_state_from` :2234-2242 (content import: state_load →
  session_update → populate — the D7 hook point).
- Save State: save_state_dialog :2249-2274 (`$w.lib` combobox + `$w.cell`
  `$w.view` entries prefilled, <Return> → save_state_ok); save_state_ok
  :2309-2328; `do_save_state_as` :2339-2372 (own-view arm →
  ase::session_save; missing view → `library_new_view $l $c $v
  ngspice_state1` then state_save overwrite; different existing view →
  state_save overwrite) — the D5 snapshot hook point; plain seam
  `ase::ui::save_state` :2442-2444 (also snapshots, D5).
- run pipeline: auto_plot :2691-2734 (op gate; wviewer::open;
  last_rawfile; attach_raw; ensure_auto_graph; clear+re-add through
  plot_map_expr); auto_plot_idle :2746-2748 (`after idle` — semaphore
  landmine); run_finished :2753-2780; run_started :2784; do_run
  :2793-2817 (routes through design_window when the design is not
  current); do_stop :2836-2848.
- design_window :2496-2516; raise_design_editor :2476-2488.

src/wave_viewer.tcl (1391 lines):
- :89-138 namespace (windows, graphbb, `layouts` :120, palette, mirrors
  cva/cvb/cvr/`sharedx` :131-134).
- :185-203 `forget` — layouts + mirrors DIE with the window (why "last-
  known graphs" must come from the STATE dict, not from wviewer).
- :209-293 `open` — raise-or-open; headless returns 0 at :219; fresh open
  inits `layouts` only when absent :262-264 and zeroes the mirrors
  :265-268 (restore must overwrite AFTER open).
- :298-306 `close`; :325-331 `switch_ctx` (verify-or-bail); :344-361
  `with_edit`.
- Model helpers (pure): dget :366; empty_graph :373 (traces logx logy
  x1 x2 y1 y2, {} = auto); layout_for :378-382 ({sharedx graphs});
  set_graphs :386-392; auto_graph_index :405-412; ensure_auto_graph
  :416-423 (`auto 1` marker); clear_graph_traces :428-436; graph_geometry
  :440; next_color :447; graph_props :468-495 (reads only known keys —
  `auto` never leaks into rect props); validate_rpn :505.
- :556-608 `regenerate` (clear + rects + engine autozoom only when
  `xschem raw loaded >= 0` :583 — a raw-less regenerate is safe: rects
  keep template ranges, redraw rc 0); :654-667 `attach_raw` (switch_ctx +
  raw clear + raw read [type omitted when {}] + regenerate; returns 0 on
  missing file WITHOUT clearing); :675-723 `add_trace` (multi-token RPN →
  `xschem raw add $name $rpn`, vec = name); :727-735 add_graph; :738-748
  sharedx_toggle; :757-783 cursor_toggle (parks at mid of graph-0 x
  range); :813-833 interp_value; :869-912 readout_refresh (label text
  `A: x=<fmt>  <disp>=<fmt>...`, test seam); :1342-1391 build_menubar
  (`$top.wvmenubar`; Cursors menu entries {Cursor A} {Cursor B}
  {Readout}).

tests (patterns to copy, not to edit unless named):
- tests/headless/test_ase_plot.tcl — the whole-file shape to clone:
  scratch CLONE of the committed cell :95-115, `$::SKYWATER_MODELS`
  resolution :93, main_ready :55-64, viewer_ready :208-215, rawq :68-71,
  D-wire click coords `sod_click $key 550 -330` :281/:371, vsource
  `600 -300` :373, REAL-ESC retry loop :380-393, P6 pre-run
  `xschem new_schematic switch .drw` :439 (WSLg focus), cleanup + verdict
  :491-499.
- tests/headless/test_ase_dialogs.tcl — send_key :115-133 / send_return
  :136-138 (focus-gated, done-expr-proven delivery; COPY these helpers).
- tests/headless/test_ase_window.tcl — tv_bbox :99 + cell-click pattern
  :115/:132 for real checkbox-cell Button-1 clicks.
- tests/headless/test_wave_viewer.tcl — G15 cursor legs :698-744: menu
  invoke, `xschem set cursor1_x`, readout text asserts, engine ground
  truth `xschem raw value <var> <idx>` and `xschem raw value <var> {}`
  (cursor-B backannotate).
- tests/headless/test_ase_core.tcl — R1 :91-105 (the 13-key assert
  :93-94 → MUST become 14 incl. `viewer`; justify in receipt), R4
  byte-stability :133-140 (needs no edit — it derives from
  state_default).
- tests/headless/test_ase_final.tcl — F3 :75-79 asserts the COMMITTED
  state file round-trips BYTE-IDENTICAL through state_load → state_save.
  This is WHY the committed fixture gains the `viewer {}` line (D2);
  test_ase_final itself is NOT edited.
- tests/headless/test_ase_interact.tcl :433 — scratch-view-name precedent
  (`ngspice_scratch1`); use a DIFFERENT name (e.g. `ngspice_persist1`).

Fixture: sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/
test_nfet_final.state — 13 lines, state_save-canonical, currently ends
`includes {}`.

Creation path: src/library_defs.tcl:703 `library_new_view` seeds
ngspice_state* views from `ase::state_default` (:716) — new views gain
`viewer {}` automatically once D1 lands; no change there.

## Scout micro-decisions (binding — implement as stated)

- **D1 schema**: append `viewer` LAST in `ase::schema_keys` (after
  `includes`) and add `viewer {}` to `ase::state_default`. Default is the
  EMPTY dict (not `{open 0 graphs {}}`): a session that never touched the
  viewer keeps a clean `viewer {}` line; absence of an `open 1` key is
  the no-auto-open condition.
- **D2 committed fixture**: append the line `viewer {}` to the committed
  test_nfet_final.state (keeps test_ase_final F3 byte-identity green
  under the new default — the same regeneration precedent as
  temperature/save_all_* in items 05-07). The OLD-state fixture for
  compat proof is therefore synthetic: the test writes a viewer-less
  state file itself (R3-style, test_ase_core :117-131 precedent).
- **D3 test_ase_core R1**: update ONLY the R1 expected key list to
  include `viewer` ("exactly the 14 schema keys"). Every other
  test_ase_* / test_wave_viewer / test_ase_plot file stays untouched and
  must stay green.
- **D4 viewer dict shape** (fixed build order for deterministic bytes):
  `open <0|1> sharedx <0|1> rawfile {} graphs <list of model graph
  dicts>`. `sharedx` IS persisted (the live layout is {sharedx graphs} —
  dropping it would silently lose the Shared-X toggle on reload; the spec
  dict is open, deliverable 5 documents the superset). `rawfile` is the
  spec's saved-results seam: v1 snapshot ALWAYS writes `{}` (= "current
  run's raw"); restore honors a non-{} hand-edited value (absolute used
  as-is, relative resolved against `[ase::rundir $state]`), attach IFF
  that file exists, else fall back to ase::last_rawfile + the notice arm.
  Graph dicts go in VERBATIM from the model (traces incl. expr/name/vec/
  color, logx/logy, x1/x2/y1/y2 with {} = auto, and the `auto 1` marker —
  receipts/13: the marker MUST round-trip or always-replace breaks after
  reload). Cursor state (cva/cvb/cvr) is NOT persisted — mirrors die with
  the window by item-12 design; the acceptance leg re-enables Cursor A
  after relaunch.
- **D5 snapshot semantics + placement**: new PURE-ish helper
  `wviewer::snapshot {token prev}` in src/wave_viewer.tcl:
  window open ([wviewer::window_for $token] ne {}) → `[dict create open 1
  sharedx <live layout sharedx> rawfile {} graphs <live layout graphs>]`;
  window closed → `$prev eq {}` ? `{}` : `[dict replace $prev open 0]`
  (graphs KEPT, not wiped). The closed arms are headless-testable. GUI
  orchestrator `ase::ui::viewer_snapshot {key}` (src/ase_window.tcl):
  read the state's viewer value, call wviewer::snapshot, and IFF the
  result differs, `ase::session_update` it into the session state.
  Call it FIRST in `ase::ui::do_save_state_as` (:2339, covers all three
  target arms incl. save-as-to-other-view) and in the plain seam
  `ase::ui::save_state` (:2442). Do NOT snapshot in ase::session_save
  itself (ase.tcl stays wviewer-free) and do NOT snapshot at session/
  viewer close (the session is already unregistered at the :246
  wviewer::close — in-memory viewer layout is discarded on close like
  any unsaved edit; document this in the spec notes). Accepted side
  effect (document): save-as to a DIFFERENT view leaves the session
  dirty-marked when the snapshot changed the in-memory state — honest,
  since the session's own file now differs.
- **D6 relaunch hook (open)**: at the END of `ase::ui::open` (:215,
  after populate, before `return $top`) call the new orchestrator
  `ase::ui::viewer_restore $key`. FRESH-open only, deliberately NOT the
  ase::open_state raise arm (:612-618): re-raising an existing session
  must not resurrect a viewer the user closed. Headless is naturally
  excluded (ase::ui::open only runs under has_x).
- **D7 relaunch hook (Load State import)**: at the end of
  `ase::ui::do_load_state_from` (:2240, after populate) call
  `ase::ui::viewer_restore $key`. Gate INSIDE viewer_restore: it acts
  ONLY when the state's viewer dict has `open 1`; open 0 / absent /
  `viewer {}` → return 0, no viewer action (an already-open viewer is
  left exactly as it is — minimal contract arm; document).
- **D8 restore mechanics**: new `wviewer::restore {token vdict rawfile
  sim_type}` in src/wave_viewer.tcl: (1) `wviewer::open $token` (0 → bail
  0, headless-safe); (2) overwrite the layout: `dict set layouts $token
  [dict create sharedx [dget $vdict sharedx 0] graphs [dget $vdict
  graphs {}]]` + sync the `sharedx($token)` menu mirror; (3) rawfile
  ne {} && isfile → `switch_ctx` + `catch {xschem raw clear}` + `xschem
  raw read $rawfile ?$sim_type?` (omit the type word when sim_type is {}
  — receipts/13: absent arg != empty arg); (4) RE-MATERIALIZE expression
  traces: for every model trace whose `expr` is multi-token RPN
  (`[llength [regexp -all -inline {\S+} $expr]] > 1`) and `vec` ne {},
  `catch {xschem raw add $vec $expr}` in the viewer ctx (this is what
  makes the auto graph's `id` trace re-resolve — without it the readout
  interp throws and the trace draws empty even with the raw attached);
  (5) ONE `wviewer::regenerate` at the end (do NOT call attach_raw — it
  regenerates internally and would double-regenerate before the
  re-materialize; inline the clear/read per step 3). Return 1. With NO
  usable rawfile, steps 3-4 are skipped and regenerate alone runs —
  probe-verified safe (regenerate autozooms only when `raw loaded >= 0`,
  redraw rc 0 on unresolved nodes).
  `ase::ui::viewer_restore {key}` (src/ase_window.tcl) orchestrates:
  read viewer dict; gate on open==1; resolve the raw per D4 (vdict
  rawfile override else `ase::last_rawfile $key`); sim_type =
  `ase::plot_sim_type [ase::session_state $key]` (NO op-only gate here —
  restoring an op raw is harmless, unlike plotting into it); call
  wviewer::restore; when no rawfile was attached, `catch {ciw_echo "ase:
  no simulation results for this state — viewer restored, traces will
  fill after a run"}`. Returns wviewer::restore's rc.
- **D9 no C changes, no new dispatch**: everything goes through existing
  seams; scheduler.c untouched.
- **D10 tests file**: NEW `tests/headless/test_ase_persist.tcl` (clone
  the test_ase_plot skeleton: hermetic scratch clone, both-arm layout,
  self-cleanup). Do NOT extend test_wave_viewer.tcl — it must stay green
  and untouched.
- **D11 windows/portability**: pure Tcl, no subprocess beyond the
  existing run path; nothing new to guard.

## Deliverables (exact)

1. src/ase.tcl: `viewer` appended to schema_keys; `viewer {}` in
   state_default. Nothing else in ase.tcl changes.
2. src/wave_viewer.tcl: `wviewer::snapshot`, `wviewer::restore` (D5/D8),
   plus the file-header comment gaining one line pointing at the item-14
   persistence contract.
3. src/ase_window.tcl: `ase::ui::viewer_snapshot`, `ase::ui::viewer_restore`,
   hooked per D5 (do_save_state_as + save_state) / D6 (ase::ui::open) /
   D7 (do_load_state_from).
4. Committed fixture gains the trailing `viewer {}` line (D2).
5. tests/headless/test_ase_core.tcl R1 updated to 14 keys (D3; receipt
   must justify).
6. NEW tests/headless/test_ase_persist.tcl per the test plan.
7. doc/claude/specs/waveform_viewer.md: Persistence bullet (:76-81)
   rewritten as-shipped + new "## Item 14 notes (as shipped, 2026-07-21)"
   section after the item-13 notes covering: the D4 dict shape incl.
   sharedx + rawfile seam semantics; snapshot-at-Save-only (no continuous
   sync, viewer-layout edits do not dirty the session until Save; close
   discards); fresh-open-only relaunch (raise arm exempt); Load State
   open-1-only arm; RPN re-materialize on restore; missing-raw notice
   arm; cursors not persisted.

## Test plan — tests/headless/test_ase_persist.tcl (named checks)

Both-arm layout (test_ase_plot precedent): headless R-legs always run;
GUI G-legs behind the has_x guard with main_ready/viewer_ready +
`auto_execok ngspice` self-SKIPs for AUDIT robustness only — the PROOF
run (WSLg DISPLAY + ngspice present) must report ZERO SKIPs on G1-G8 and
the receipt must show that run. Hermetic scratch clone `_ase_persist_[pid]`
of the committed cell + scratch library.defs + scratch rundir, exactly the
test_ase_plot :85-115 pattern. Copy send_key/send_return
(test_ase_dialogs :115-138) and tv_bbox/cell-click (test_ase_window :99+).

Headless R-legs (also pass under `--nogui`):
- R1 "state_default has viewer {}" + "14 schema keys" (dict keys check).
- R2 viewer round-trip byte-stability: build a state with
  `viewer {open 1 sharedx 0 rawfile {} graphs {...}}` where graphs =
  one `auto 1` graph carrying trace
  `{expr {i(v1) -1 *} name id vec id color 4}` + one plain graph carrying
  `{expr v(d) name {} vec v(d) color 4}`; state_save → state_load →
  state_save; byte-compare the two files; assert the reloaded dict's
  graphs value is IDENTICAL to the input (incl. `auto 1`).
- R3 old-state compat: write a state file WITHOUT the viewer key (13-key
  content) + one unknown key; state_load → viewer == {} (default merged),
  unknown key preserved; re-save contains `viewer {}` as the last schema
  line before the unknown key.
- R4 snapshot closed arms (pure, no window): `wviewer::snapshot tokX {}`
  → `{}`; `wviewer::snapshot tokX {open 1 sharedx 1 rawfile {} graphs G}`
  → same dict with `open 0` and graphs G KEPT.
- R5 headless open_state: session on an open-1 state under --nogui →
  returns 1, `wviewer::window_for` stays {} (no Tk side effects).

GUI G-legs (the ACCEPTANCE GATE — zero SKIPs in the proof run):
- G1 fresh session: `ase::open_state sky130_tests test_nfet_final
  ngspice_state1` → 1; session window up; committed-shape state (no
  viewer auto-open: `wviewer::window_for $key` == {}).
- G2 Choose Analyses through the REAL dialog: `$top.mb.analyses invoke
  Choose…` → `$w.types.dc` invoke → set Enable (checkbutton invoke or
  the dlg($key,anen) var + invoke — use the widget) → fill
  `$w.source`=V2 `$w.start`=0 `$w.stop`=1.8 `$w.step`=0.01 →
  send_return on `$w.step` with done = dialog destroyed. Assert state:
  dc row `{type dc enabled 1 source V2 start 0 stop 1.8 step 0.01}`-
  equivalent AND op row still enabled 1; `ase::plot_sim_type` == dc.
- G3 Outputs plot checkbox via a REAL <Button-1> on the id row's Plot
  cell (tv_bbox + event generate); assert state id row plot 1.
- G4 Netlist and Run: `$top.mb.sim invoke {Netlist and Run}`; ase::wait;
  update; exit 0; status Ready/Green; viewer auto-opened + mapped
  (viewer_ready); in the viewer ctx: `raw loaded >= 0`, `raw sim_type`
  dc, `raw points` 181; auto graph index 0 with EXACTLY the id trace;
  `raw index id >= 0`; redraw rc 0.
- G5 cursor A + readout: `$vtop.wvmenubar.cursors invoke {Cursor A}`;
  `xschem set cursor1_x 1.8`; `wviewer::readout_refresh $key` (G15
  precedent); ground truth `set truth [xschem raw value id 180]`
  (last sample, Vgs=1.8): assert |truth*1e6 − 409.68| < 1.0 (hundreds of
  µA sanity) AND the readout A-line contains `x=[ase::format_value 1.8]`
  and `id=[ase::format_value $truth]` (eng notation, e.g. 409.7u).
- G6 Direct Plot: `$top.mb.results invoke {Direct Plot}`;
  `ase::ui::sod_click $key 550 -330` (the D wire); REAL <Key-Escape> via
  the test_ase_plot :380-393 retry loop; assert exactly ONE new graph,
  not auto-marked, traces exactly {v(d)}; auto graph untouched; outputs
  unchanged.
- G7 Save State to a scratch view: `$top.mb.session invoke {Save State}`;
  clear `$w.view` and type `ngspice_persist1`; send_return with done =
  dialog destroyed. Assert the created file
  `<clone>/test_nfet_final/ngspice_persist1/test_nfet_final.state`
  exists, loads, and its viewer dict has open 1 + 2 graphs + the auto
  marker on graph 0 + the id and v(d) traces (exact model dicts).
- G8 close + relaunch (the gate's heart): `$top.mb.session invoke Close`;
  assert session AND viewer toplevels gone (item-13 P7 semantics).
  `ase::open_state sky130_tests test_nfet_final ngspice_persist1` → 1;
  NEW session window up; viewer RELAUNCHED (`wviewer::window_for` on the
  NEW key ne {} + mapped); layout restored: 2 graphs, auto index 0, auto
  graph trace id, DP graph trace v(d); raw re-attached (loaded >= 0,
  sim_type dc, points 181); `raw index id >= 0` (RPN re-materialized);
  redraw rc 0; cursor A re-enabled through the RELAUNCHED viewer's menu +
  `set cursor1_x 1.8` + readout again contains
  `id=[ase::format_value $truth]` (same ground truth — traces truly
  re-resolve).
- G9 no-auto-open arms: close the G8 session. Rewrite the scratch view's
  state through the public schema: (a) viewer `open 0` (graphs kept) →
  reopen → session up, NO viewer window → close; (b) viewer key REMOVED
  entirely (old-state fixture live) → reopen → session up, NO viewer →
  close.
- G10 missing-raw arm: restore viewer `open 1` in the scratch state,
  DELETE `<rundir>/test_nfet_final_ase.raw` → reopen → session up,
  viewer up, layout restored (2 graphs, traces present in the MODEL),
  `xschem raw loaded` errors-or-negative (rawq pattern), redraw rc 0,
  NO crash (the whole leg inside the file's big catch must not trip).
  Close.
- G11 rawfile-seam arm (D4): set the scratch state's viewer `rawfile` to
  the RELATIVE name `test_nfet_final_ase.raw`, recreate the raw (rerun is
  unnecessary — copy/keep from a G8-era backup taken BEFORE G10's delete)
  → reopen → raw attached (loaded >= 0). Close.
  (Take the raw backup right after G8 while it still exists.)

Test hygiene: every leg's check named as above; scratch fully deleted at
the end (verify no `_ase_persist_*` left); `set no_recent_files 1`;
repo-root-relative standalone repro comment in the header (test_ase_plot
:36-40 pattern).

Protected suites — re-run at the final product code and keep green:
test_ase_core (66 → with the R1 edit), test_ase_view, test_ase_window,
test_ase_dialogs, test_ase_final (28, --nogui arm), test_ase_interact,
test_wave_viewer (GUI + --nogui arms), test_ase_plot. Remember
test_ase_core/test_ase_final run in full_audit's --nogui arm
(receipts/12 deviation c). Then a full_audit.sh run; fails must be a
subset of the baseline list below (WSLg flakes: rerun-first policy).

## Sabotage plan (each: post-commit, `git diff` confirms the tree holds
NOTHING but the sabotage, revert via targeted `git checkout -- <file>`,
clean re-run green)

- S1 `wviewer::snapshot` returns `$prev` unchanged (open-1 arm dead) —
  src/wave_viewer.tcl. Predicted fails: R4 open-0 flip check; G7 viewer-
  dict checks (open 1 / graphs / auto marker / traces); G8 relaunch
  family (viewer never relaunches: window/layout/raw/readout checks) and
  the G9-G11 arms that depend on G7's written dict. R1-R3/R5 + G1-G6
  stay green.
- S2 `wviewer::restore` skips step 2 (layout overwrite dropped) —
  src/wave_viewer.tcl. Predicted fails: exactly the G8 layout checks
  (graph count 2 / auto index / id / v(d) / raw index id / readout id
  line) + G10 layout-restored checks + G11 passes-or-fails only its
  attach check per wiring (viewer still opens; raw still attaches in
  G8). G7 and all R-legs stay green.
- S3 `ase::state_default` loses `viewer {}` — src/ase.tcl. Predicted
  fails: R1 both checks, R3 re-save-contains-viewer check; test_ase_core
  R1 (14-key) also fails — run that suite too under S3 to witness; GUI
  legs unaffected (the session states carry explicit viewer keys by
  then... EXCEPT G1's committed-shape open has viewer {} from the D2
  fixture line, unaffected). Confirm the exact realized set and record
  it in the receipt.

## Commit — ONE commit, explicit file list, nothing else

```
git add src/ase.tcl src/ase_window.tcl src/wave_viewer.tcl \
        tests/headless/test_ase_persist.tcl \
        tests/headless/test_ase_core.tcl \
        sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state \
        doc/claude/specs/waveform_viewer.md
```

Nothing else — in particular NEVER stage the pre-batch dirty tracked
files: doc/claude/specs/sky130_workarea.md,
sky130A/xschem_libs/library.defs, src/ciw.tcl,
tests/headless/test_sky130a_libmgr.tcl, tests/run_regression.tcl,
xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym,
xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch
— and no `_nhangle_*`/`_allm_*`/junk dirs. Commit message: normal prose,
"(item 14)" tag, Co-Authored-By trailer per repo convention. NEVER push.

## Baseline full_audit fail list (pre-existing, tolerated, NOT yours)

FAIL: test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
test_cadence_window_hop_log, test_ciw, test_crossview_paste,
test_fluid_editing, test_hi_descend, test_launch_context,
test_lib_manager_gui, test_lib_sweep, test_palette, test_phase3_mints,
test_pin_type_edit, test_reopen_readonly, test_select_at,
test_selflog_output, test_verb_noun_copy_move, test_wire_split,
test_wire_vertex_grab. TIMEOUT: test_key_graph_context. Known WSLg
flakes (NOT regressions if a direct re-run passes): test_deselect_mode,
test_hover_highlight, test_ase_window-in-parallel-audit. SKIPs fine
elsewhere; the G1-G11 acceptance legs must show zero SKIPs in the proof
run.

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

## Landmines (from receipts, re-verified in code this session)

- run_finished executes inside ase::wait's SEMAPHORE bracket where
  `new_schematic switch` silently no-ops (auto_plot_idle exists for
  exactly this — src/ase_window.tcl:2736-2748). viewer_restore runs from
  normal event context (open_state / Load State), NOT from run
  completion — do not move it into a run callback without the after-idle
  + switch_ctx pattern.
- `xschem raw read` absent-type != empty-type: omit the word entirely
  when sim_type is {} (attach_raw :660-664 shows the shape).
- `xschem setprop` flags PRECEDE the object word
  (`xschem setprop -fast rect 2 $gi fullxzoom`) — only relevant if you
  touch regenerate (you should not need to).
- `xschem raw add` never reports evaluator errors — the restore
  re-materialize (D8 step 4) re-adds vectors whose RPN was ALREADY
  validated when the trace was created; keep the catch, add no new
  validation path.
- The auto graph is identified ONLY by its `auto 1` model marker —
  serialization must carry it verbatim or post-reload runs will append a
  second auto graph (receipts/13).
- wviewer::forget wipes layouts + mirrors on close — "last-known graphs"
  can only come from the state dict (D5 closed arm), never from wviewer.
- WSLg: generated keys need the focus-gated retry helpers; menu `invoke`
  is the reliable path for menu entries; window raises via
  raise_activate_toplevel semantics already inside the product procs.
- Test processes: one xschem per test file; the acceptance test must run
  from repo root; `exit` with the fail-count verdict line
  (`RESULT: ALL PASS (N checks)`) exactly like test_ase_plot.
