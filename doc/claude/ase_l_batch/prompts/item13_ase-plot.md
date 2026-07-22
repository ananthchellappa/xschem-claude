# Item 13 ase-plot — implementation prompt (ROUND 3, Waveform Viewer)

Scout-verified 2026-07-21 at HEAD cd4eda97 (branch fluid-editing, working
tree carries pre-batch dirty files — see the staging ban below). All
file:line anchors below re-verified from source THIS session.

AUTHORITATIVE CONTRACT: doc/claude/specs/waveform_viewer.md, "ASE
integration" bullet list (:66-75) + item 13 line (:94). That file is
UNTRACKED (`?? doc/claude/specs/waveform_viewer.md`) — you may EDIT it (see
D12) but must NEVER `git add` it; the driver's ledger commit carries it.
Context receipts: receipts/08 (Select-On-Design machinery + click-test
patterns), receipts/11 (viewer shell + raw_file hook + write-not--r
correction), receipts/12 (viewer core model/menus + setprop-flag-order and
raw-add landmines).

## Scope — wire ASE-L to the Waveform Viewer

Product files: `src/ase.tcl`, `src/ase_window.tcl`, `src/wave_viewer.tcl`.
Tests: NEW `tests/headless/test_ase_plot.tcl` + two flipped assertions in
`tests/headless/test_ase_window.tcl`. Pure Tcl, zero C changes, no build
needed, no Makefile.in change (no new src files; ship list already carries
all three product files at src/Makefile.in:22-23; source sites
src/xschem.tcl:14106/14108/14110).

1. **Results > Direct Plot goes LIVE** — enters the item-08 click mode in a
   new `plot` flavor: clicks queue TRACES, ESC ends → viewer raised-or-
   opened, one new stacked graph per invocation, raw attached.
2. **Outputs Plot checkboxes live** — after each successful run, plot==1
   rows auto-plot into the viewer; v1 always-replace (the auto-plot graph is
   cleared and rebuilt each run; Direct-Plot graphs untouched).
3. **`~` strip button live** — raise-or-open the session's viewer, no
   traces added.
4. **Raw wiring** — `ase::last_rawfile <session>` + sim-type helper;
   op-only results → ciw_echo notice, nothing plotted, no crash.
5. **Session lifecycle** — closing the ASE session closes its viewer
   (MUST BE ADDED — see D10: the item brief's "already item-11 semantics"
   claim is FALSE in code); re-run replaces raw (clear + re-read), stale
   traces re-resolve or show cleanly.
6. Tests + ≥2 sabotages (plan prescribes 3).

## Corrected anchors (verified 2026-07-21; trust these, not the spec's)

src/ase_window.tcl (2661 lines):
- :62-111 `ase::ui` namespace vars; the `sod` array block is :103-111
  (sod(active), per-key canvas/flavor/prevpress/prevrel/prevesc/count).
- :193 `ase::ui::open`; :217-242 `ase::ui::close` — **contains NO wviewer
  call today** (grep "wviewer" over src/ase_window.tcl returns nothing);
  note its ordering comment: sod_end is deliberately called AFTER destroy.
- :246 `build`. Results menu :329-339; the entry to flip is :333
  `$top.mb.results add command -label {Direct Plot} -state disabled`
  (the Annotate entries :334-338 STAY disabled; the Results cascade itself
  is not disabled).
- Action strip :377-402; the button to enable is :398
  `button $top.strip.plot -text ~ -width 5 -state disabled`.
- :616 output_display_name, :627 output_result_key, :637 output_kind.
- :687 `sod_expr` (v(<net>)/i(<inst>), lowercased), :697 `sod_merge`.
- :727 populate, :779 refresh_output_values (per-row `$tv set $i value`).
- :1096 `select_on_design {key flavor}` (seizes <ButtonPress-1>/
  <ButtonRelease-1>/<Key-Escape> on the design canvas, saves prev binding
  STRINGS), :1127 `sod_end` (restores verbatim, `array unset sod $key,*`,
  then raises the ASE window), :1156 `sod_click` (classify → sod_queue),
  :1194 `sod_queue` (session outputs write + populate), :1216
  `output_editor_from_design` (2-arg select_on_design call — keep working).
- :2350 raise_design_editor, :2370 design_window.
- :2557 `run_finished` — the ec==0 arm is :2569-2575 (session results attr
  + refresh_output_values + set_status ok); auto-plot hooks in here.
- :2584 run_started, :2593 do_run, :2622 do_run_existing, :2636 do_stop.

src/ase.tcl (743 lines):
- :29 schema_keys, :34 last_run, :46 state_get, :115 state_default.
- :187 register_backend (required hooks list :189 includes `raw_file`),
  :200 backend_hook, :222 rundir.
- :242 netlist, :285 run, :302 run_existing, :329 run_deck, :371 run_done,
  :395 wait, :408 last_result.
- Session model: :422 session_key, :440 session_open, :459 session_state,
  :467 session_update, :487 session_save, :499 session_load, :520
  session_close, :528/:534 session_setattr/getattr.
- :556 open_state (has_x-guarded GUI seam).
- ngspice backend :589-743: render_deck :596; analyses emit in FIXED order
  op dc ac tran :646-658; **raw artifact = in-.control `remzerovec` +
  `write [raw_file $state]` emitted only when ≥1 analysis enabled
  :673-680** (NOT `-r` — receipts/11 probe: `-b -r` is dead when a
  .control block exists; the item brief's "(-r)" is a stale mechanism
  reference, outcome verified equivalent); run_cmd :688 (`ngspice -b`,
  no -r, no -o); log_file :693; raw_file :704
  (`<rundir>/<cell>_ase.raw`); result_probe :717; registration :737-742.

src/wave_viewer.tcl (1300 lines):
- :89-138 namespace vars; `layouts` :120 (token → {sharedx graphs}).
- :143 title_for, :163 window_for, :173 token_for_canvas, :185 `forget`
  — **kills layouts+mirrors on close/destroy** (a reopened viewer starts
  from an empty layout; persistence is item 14, NOT yours).
- :209 `open {token}` — raise-or-open, requires `ase::session_state $token`
  non-empty, headless returns 0; :298 `close {token}`; :310 in_ctx; :326
  with_edit.
- Model: :353 empty_graph, :358 layout_for, :366 set_graphs (pure dict —
  no Tk/xschem calls), :376 graph_geometry, :383 next_color, :404
  `graph_props` — reads ONLY known keys via dget, so an extra `auto 1`
  marker key on a graph dict is ignored harmlessly (D4 relies on this),
  :441 validate_rpn, :468 auto_expr_name, :492 `regenerate` (guards
  `xschem raw loaded >= 0`; `xschem setprop -fast rect 2 N fullx/yzoom` —
  flags PRECEDE the object word, receipts/12 deviation a), :550
  place_graph_rect, :561 display_raw, :586 `add_trace {token gi rpn
  {name {}}}` — returns {} or a user-displayable error, never throws;
  multi-token rpn → `xschem raw add` (name must match
  `^[A-Za-z_][A-Za-z0-9_]*$`, auto expr<N> otherwise); single-token with
  no raw loaded is recorded UNVALIDATED ("a trace may be recorded before
  the first run — item 13 wires raws" — that comment at :613-615 is your
  designed-in seam); gi out of range clamps to the LAST graph; :636
  add_graph, :647 sharedx_toggle.
- :1157 over_graph, :1179 key_filter, :1231 strip_bindings, :1251
  build_menubar.

C raw API (scheduler.c:8370-8488 doc block): `xschem raw read filename
[type]` :8375 (returns 1 on success); `raw clear` :8381 (no args = unload
all raw files of the CURRENT ctx); `raw loaded` :8424 (**INDEX semantics:
>= 0 loaded, -1 not — never boolean**); `raw sim_type` :8430; `raw add
varname [expr]` :8480 ("If varname is already existing and expr given
recalculate data" — re-run re-adds are safe); `raw index node` :8433
(-1 when absent). Raw storage is per-context — always
`xschem new_schematic switch <viewer .drw>` first.

Tests:
- tests/headless/test_ase_window.tcl:404-419 (W1m block): :414-415
  `check "W1m Results Direct Plot disabled" ... disabled` — FLIP;
  :475-479 (W1s block): :479 `check "W1s plot placeholder disabled"
  [$top.strip.plot cget -state] disabled` — FLIP. Update the file header
  comment accordingly. These are the ONLY test_ase_window changes.
- tests/headless/test_ase_interact.tcl — copy these patterns: main_ready
  :44-59, tv_find :62-68, clone fixture + scratch library.defs :100-118,
  state-file fixture shaping through public state_load/state_save
  :122-126, open_state/window_for :156-168, REAL Motion+Press+Release
  gesture with pixel = (w+origin)/zoom after zoom_full :187-207, direct
  `ase::ui::sod_click $key <x> <y>` legs (wire 550 -330 → v(d); vsource
  600 -300 → i(v1); net label 500 -330; non-source 400 -300), REAL
  <Key-Escape> retry loop gated on "seized binding reverted" :246-268.
- tests/headless/test_wave_viewer.tcl — copy: scratch registry pointing at
  the COMMITTED trees :84-101 (never the pre-batch-dirty workarea
  library.defs), dc-sweep fixture shaping :106-119 (dc V2 0 1.8 0.01 →
  181 points), rawq error-guard :173-176, V5 raw assert shapes :177-187,
  send_key :275-293, viewer_ready :305-312, toplevel_count :295-301.
- tests/headless/full_audit.sh:69 `nogui_tests` — test_ase_plot is NOT
  listed there (default arm: GUI legs DISPLAY-guarded self-SKIP). Do NOT
  edit full_audit.sh; discovery is automatic (`test_*.tcl`).

## Scout micro-decisions (binding — implement as stated)

- **D1 mode plumbing**: extend `select_on_design` to
  `{key flavor {mode outputs}}`; store `sod($key,mode)` and (plot mode)
  `sod($key,queue) {}`. `sod_click`'s queue step routes on mode: `outputs`
  → sod_queue (unchanged), `plot` → new `dp_queue` (lappend to
  sod($key,queue), exact-string dedupe via lsearch, incr sod($key,count),
  ciw_echo per queue). `sod_end` captures mode+queue BEFORE
  `array unset sod $key,*`; for `plot` it SKIPS the raise-the-ASE-window
  arm and calls `dp_finish $key $queue` instead (binding restore stays
  IDENTICAL for both modes). Existing 2-arg callers (menus :301-306,
  output_editor_from_design :1222, test_ase_interact) are untouched by the
  default. Rationale: reuses the seize/restore machinery verbatim; item-08
  tests keep passing unmodified.
- **D2 Direct Plot queues TRACES ONLY** — session `outputs` are NOT
  written (spec :68 "queues traces"; Cadence Direct Plot creates no save
  entries). Test asserts outputs unchanged across a Direct-Plot round.
- **D3 dp_finish policy** (new proc, ase_window.tcl): (1) sim gate first:
  `ase::plot_sim_type [ase::session_state $key]` eq `op` → ciw_echo
  "op results have no sweep — nothing to plot" (wording free), discard
  queue, return — viewer untouched; (2) `wviewer::open $key`
  (raise-or-open; if it returns 0, ciw_echo + return); (3) raw:
  `set rf [ase::last_rawfile $key]` — non-empty → `wviewer::attach_raw
  $key $rf [ase::plot_sim_type ...]`; empty → ciw_echo "no simulation
  results yet — run first" and CONTINUE (traces still recorded: the
  add_trace pre-run seam; they resolve at the next attach_raw); (4) queue
  non-empty → `wviewer::add_graph $key` then for each queued expr
  `wviewer::add_trace $key <new last index> $ex` (nonempty return →
  ciw_echo + skip that trace, continue); empty queue → no new graph, the
  raise from (2) stands. Mode always exits clean (bindings already
  restored by sod_end before dp_finish runs).
- **D4 auto-plot marker**: the auto-plot graph is the graph dict carrying
  `auto 1` (open dicts; graph_props/dget ignore it; item 14's
  serialization will round-trip it for free). New PURE model helpers in
  wave_viewer.tcl (no Tk/xschem calls — headless-testable):
  `wviewer::auto_graph_index {token}` (index of the first `auto 1` graph,
  -1 none), `wviewer::ensure_auto_graph {token}` (find-or-append
  `[empty_graph] + auto 1`, returns index; no regenerate — callers do),
  `wviewer::clear_graph_traces {token gi}` (traces {}, graph kept).
  Clear-NOT-remove on rebuild: index stability for Direct-Plot graphs.
- **D5 auto-plot hook**: `ase::ui::auto_plot $key` called from
  `run_finished`'s ec==0 arm AFTER `set_status ok` (:2575), wrapped in
  `catch` — a viewer failure must never break the status pipeline. Logic:
  collect state outputs rows with plot==1. Zero rows → if the viewer is
  already open AND an auto graph exists, clear its traces + regenerate;
  never open a viewer to show nothing. Rows>0 → sim gate (op →
  ciw_echo notice, return — this satisfies deliverable 4's op-only arm
  for auto-plot); else `wviewer::open`, `wviewer::attach_raw` (rf must be
  non-empty here — the run just succeeded; if {} anyway, notice+return),
  `ensure_auto_graph`, `clear_graph_traces`, then per row add via
  add_trace with D6 mapping (error → ciw_echo + skip). Always-replace by
  construction; Direct-Plot graphs never touched.
- **D6 expr→trace mapping** `ase::ui::plot_map_expr {ex}` (PURE): trim;
  single token → verbatim; single token starting with `-` (and more than
  the dash) → RPN `"<rest> -1 *"` (the canonical `-i(v1)` nfet output
  becomes `i(v1) -1 *`, materialized by add_trace via `xschem raw add`);
  multi-token → verbatim (validate_rpn decides downstream). Trace name:
  the row's `name` when it matches `^[A-Za-z_][A-Za-z0-9_]*$` (add_trace's
  expression-name rule), else {} (auto). add_trace is the validation
  backstop.
- **D7** `ase::last_rawfile {key}` in src/ase.tcl (headless): {} for an
  unknown session; else resolve `[[ase::backend_hook $sim raw_file]
  $state]` (catch → {}) and return it ONLY when `[file isfile]`, else {}.
  Rationale: path is deterministic per rundir/cell, runs overwrite in
  place, file-existence == "has results"; also lets a fresh xschem session
  attach a previous run's raw (spec's saved-results seam :80-81).
- **D8** `ase::plot_sim_type {state}` in src/ase.tcl (headless): the LAST
  enabled analysis type in the fixed emit order `op dc ac tran` ({} when
  none) — render_deck :646-658 runs analyses in that order inside one
  .control, so the final analysis owns the CURRENT plot when `write`
  executes; this is both the correct `xschem raw read` type argument and
  the op-only gate. Comment the ngspice-order coupling at the proc.
- **D9** `wviewer::attach_raw {token rawfile sim_type}` in
  src/wave_viewer.tcl: registry guard, `xschem new_schematic switch
  <win_path>`, `catch {xschem raw clear}`, `xschem raw read $rawfile
  $sim_type` only when `[file isfile $rawfile]`, `wviewer::regenerate`,
  return 1 (0 on unknown token/missing file). Re-run replace = the SAME
  helper (clear+read). After clear, `raw add` vectors die: auto_plot
  re-adds its own on rebuild (raw add recalculates an existing name);
  user-dialog expression traces from item 12 go stale-but-clean — the
  engine draws nothing for an unknown node and redraw rc stays 0 (test
  asserts it); document this in the proc comment.
- **D10 session close closes viewer**: VERIFIED NOT IMPLEMENTED (the item
  brief's "already item-11 semantics" is wrong — no wviewer reference
  exists in ase_window.tcl; receipts/11 never claimed it). ADD
  `catch {wviewer::close $key}` inside `ase::ui::close` (:217-242), after
  the per-key record cleanup, BEFORE/alongside the existing trailing
  `sod_end` (order vs destroy is free — wviewer::close destroys its OWN
  toplevel via `new_schematic destroy` and is registry-keyed). Headless
  safe (dict-exists guard first).
- **D11 tests**: NEW `tests/headless/test_ase_plot.tcl` (clone fixture +
  raw asserts per the pattern anchors above) + ONLY the two flipped
  assertions in test_ase_window.tcl (W1m :414-415 → live/normal state and
  a -command present; W1s :479 → normal). test_wave_viewer.tcl and all
  other protected suites untouched. Receipt must justify both flips
  (item-12 deviation-b precedent: keeping them verbatim contradicts this
  item's own deliverables).
- **D12 spec doc**: append a short "item 13" note to
  doc/claude/specs/waveform_viewer.md (op-only → notice; always-replace
  auto graph marked `auto 1`; Direct Plot queues traces not outputs;
  session close closes viewer; last_rawfile/plot_sim_type seams).
  WORKING TREE ONLY — never staged (file is untracked; driver's ledger
  commit carries it — item-08 D12 precedent).
- **D13 `~` + menu wiring**: `ase::ui::open_viewer {key}` = thin
  `catch {wviewer::open $key}` wrapper; strip button :398 loses
  `-state disabled` and gains `-command [list ase::ui::open_viewer $key]`;
  Results entry :333 becomes
  `-command [list ase::ui::direct_plot $key]` (no -state). New
  `ase::ui::direct_plot {key}` = `select_on_design $key {save 0 plot 1}
  plot` (flavor content is inert in plot mode — D2 — but keep it
  self-documenting).

## Deliverables (exact)

1. src/ase.tcl: `ase::last_rawfile` (D7), `ase::plot_sim_type` (D8) —
   both pure/headless, TIP-278 discipline, comments as specified.
2. src/wave_viewer.tcl: `attach_raw` (D9), `auto_graph_index`,
   `ensure_auto_graph`, `clear_graph_traces` (D4). No other changes.
3. src/ase_window.tcl: D1 mode plumbing (select_on_design/sod_click/
   sod_end + dp_queue/dp_finish), D5 auto_plot + run_finished hook, D6
   plot_map_expr, D10 close hook, D13 wiring (Results entry live, `~`
   live, direct_plot/open_viewer procs). Namespace comment for the sod
   array (:103-111) updated with the mode/queue fields.
4. Tests per D11 (below). Spec note per D12 (unstaged).

## Test plan — tests/headless/test_ase_plot.tcl (named checks)

Header comment lists the legs; standalone repro line
`./src/xschem --pipe -q --nolog --script tests/headless/test_ase_plot.tcl`
(headless arm additionally with --nogui). `set no_recent_files 1`.
Fixture: CLONE the committed test_nfet_final cell into a scratch lib +
scratch library.defs pointing sky130_tests at the clone and
sky130_fd_pr/devices at the committed trees; `::SKYWATER_MODELS` to the
repo models dir; rundir under the scratch; state shaping ONLY through
public ase::state_load/state_save on the CLONE. Cleanup deletes scratch.

Headless arm (BOTH arms — pure procs, no window):
- PH1 `plot_sim_type`: committed-shape analyses op-only → `op`; op+dc
  enabled → `dc`; all disabled → {}; ac+tran enabled → `tran`.
- PH2 `last_rawfile`: unknown key → {}; registered session (session_open
  on a scratch state) with no file → {}; after `close [open $raw w]`
  touch of the exact `<rundir>/test_nfet_final_ase.raw` path → that path.
- PH3 `plot_map_expr`: `v(d)` → `v(d)`; `-i(v1)` → `i(v1) -1 *`;
  `i(v1) -1 *` → verbatim; ` v(d) ` trims; bare `-` stays `-`.
- PH4 model helpers on a scratch token: ensure_auto_graph on an empty
  layout → 0 and layout gains 1 graph with `auto 1`; second call → 0,
  still 1 graph; append a plain graph then clear_graph_traces 0 → graph 0
  kept, traces {}, graph count unchanged, graph 1 untouched;
  auto_graph_index finds 0 / returns -1 pre-create.

GUI arm (guard `[info exists ::has_x] && [info commands winfo] ne {}`,
then main_ready; run legs additionally `auto_execok ngspice`; each
SKIP printed + justified):
- P1 op-only auto-plot notice: shape clone state (op enabled only, id row
  `plot 1`), open_state → window; Netlist and Run; ase::wait == 0; status
  Ready/Green; `wviewer::window_for $key` == {} (no viewer opened);
  no throw anywhere (whole file already runs under the big catch —
  keep the pattern).
- P2 op-only Direct Plot: Results menu entry state NOT disabled +
  `$top.mb.results invoke {Direct Plot}` → mode armed (ButtonPress-1
  seized, non-empty and != pre-mode string); `ase::ui::sod_click $key 550
  -330`; `ase::ui::sod_end $key` → viewer still {} (notice arm), all
  three bindings restored VERBATIM, outputs unchanged vs snapshot.
  Close the session (`ase::ui::close`), reopen below.
- P3 dc auto-plot: reshape clone state — dc enabled `V2 0 1.8 0.01`, op
  disabled, outputs `{name id expr -i(v1) save 1 plot 1}` +
  `{name {} expr v(d) plot 1 save 1}`; open_state; Netlist and Run; wait
  == 0; viewer opened (`window_for` ne {}, viewer_ready); in viewer ctx:
  `raw loaded` >= 0 (INDEX), `raw sim_type` == dc, `raw points` == 181;
  model: auto_graph_index == 0, graph 0 traces count 2; rect 0 node attr
  contains `v(d)` AND `id`; `raw index id` >= 0 (the D6-mapped
  `i(v1) -1 *` materialized); redraw rc 0.
- P4 Direct Plot live: snapshot outputs; menu invoke → mode; sod_click
  550 -330 (v(d)) + sod_click 600 -300 (i(v1)); end via a REAL
  <Key-Escape> on the design canvas using the I7 retry loop (done
  condition: seized Key-Escape binding reverted); model graphs == 2; the
  NEW graph (index 1) has exactly 2 traces with vecs v(d) and i(v1);
  auto graph 0 untouched (still 2 traces); outputs UNCHANGED vs snapshot
  (D2); bindings restored verbatim.
- P5 `~`: `$top.strip.plot cget -state` != disabled; with the viewer
  open, `$top.strip.plot invoke` → same toplevel (window_for unchanged),
  toplevel_count unchanged, model graph count unchanged (no traces
  added).
- P6 re-run replace: Netlist and Run again; wait == 0; model graphs
  STILL 2; graph 0 (auto) traces STILL 2 (rebuilt, not appended); graph 1
  (Direct Plot) traces STILL 2 (untouched); viewer ctx `raw points` ==
  181, `raw sim_type` dc; redraw rc 0 (stale-vector cleanliness).
- P7 lifecycle: `ase::ui::close $key` → session toplevel gone AND viewer
  toplevel destroyed, `wviewer::window_for $key` == {}.

test_ase_window.tcl: flip :414-415 to assert Direct Plot NOT disabled
(and `entrycget -command` non-empty), flip :479 to assert `~` state
normal; update the header-comment lines describing W1m/W1s.

Protected suites — re-run ALL green after the change, direct runs from
repo root: test_ase_core (--nogui), test_ase_view, test_ase_window,
test_ase_dialogs, test_ase_final (--nogui), test_ase_interact,
test_wave_viewer. The ONLY allowed assertion delta is the two
test_ase_window flips (justify in your report for the receipt). Then run
tests/headless/full_audit.sh; compare against the baseline fail list
below (rerun-first for the known WSLg flakes: test_deselect_mode,
test_hover_highlight, test_ase_window, test_graph_context,
test_multi_window, test_readonly_action_dispatch, test_nh_anim_rearm,
test_apply_hilight_log).

## Sabotage plan (each: post-commit, `git diff` confirms the tree holds
NOTHING but the sabotage, targeted `git checkout -- <file>` revert, clean
re-run green; each must fail EXACTLY its targets)

- S1 (src/ase_window.tcl): `auto_plot` early-returns before doing
  anything → P3 viewer/raw/trace checks + P6 auto-graph checks fail;
  P2/P4 Direct-Plot legs and PH legs stay green.
- S2 (src/ase_window.tcl): `dp_finish` skips the add-graph/add-trace
  step (queue discarded after the raw attach) → P4 graph-count/trace
  checks fail exactly; P3 auto-plot legs stay green.
- S3 (src/wave_viewer.tcl): `attach_raw` drops the
  `raw clear` + `raw read` pair (regenerate kept) → P3 raw
  loaded/sim_type/points + P6 raw checks fail (and P3's rect/trace
  checks that need raw-resolved adds — predict the exact set in your
  report); PH legs stay green.

## Commit — ONE commit, explicit file list, nothing else

    git add src/ase.tcl src/ase_window.tcl src/wave_viewer.tcl \
            tests/headless/test_ase_plot.tcl \
            tests/headless/test_ase_window.tcl

Message: normal prose, e.g. "feat(ase): wire ASE-L to the waveform viewer
— Direct Plot click mode, Plot-checkbox auto-plot, ~ button, raw attach"
+ body, ending with the repo trailer:

    Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>

NEVER stage (pre-batch dirty / driver-owned):
doc/claude/specs/sky130_workarea.md, sky130A/xschem_libs/library.defs,
src/ciw.tcl, tests/headless/test_sky130a_libmgr.tcl,
tests/run_regression.tcl, xschem_libs_newsym/SANDBOX/... (both files),
doc/claude/specs/waveform_viewer.md (untracked, driver's),
doc/claude/specs/ase_l.md, doc/claude/ase_l_batch/** (PLAN/receipts),
any `_nhangle_*`/`_allm_*`/scratch dirs, any `_ase_plot_*` test leftovers
(the test must clean its scratch).

## Baseline full_audit fail list (pre-existing, tolerated, NOT yours)

FAIL: test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
test_cadence_window_hop_log, test_ciw, test_crossview_paste,
test_fluid_editing, test_hi_descend, test_launch_context,
test_lib_manager_gui, test_lib_sweep, test_palette, test_phase3_mints,
test_pin_type_edit, test_reopen_readonly, test_select_at,
test_selflog_output, test_verb_noun_copy_move, test_wire_split,
test_wire_vertex_grab. TIMEOUT: test_key_graph_context. SKIPs fine.
Known WSLg flakes are NOT regressions if they pass a direct re-run.

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

## Landmines (from receipts, re-verified)

- `xschem setprop` FLAGS PRECEDE the object word (`setprop -fast rect …`).
- `xschem raw add` never reports evaluator errors — expression entry goes
  through wviewer::add_trace's validate_rpn only (never call raw add
  directly from new code).
- `xschem raw loaded` returns an INDEX (>=0 / -1), never a boolean.
- Raw data is per-context: switch to the viewer's win_path before ANY
  `xschem raw` call; `xschem get top_path` is {} under tabs — derive
  toplevels from win_path regsub (existing helpers do this).
- wviewer::forget (close/destroy) discards layouts — never cache graph
  indices across a viewer close.
- Generated pointer/key events: full Motion+Press+Release sequences, focus
  gates + retry for keys (gesture-test-full-sequence lesson); a lone
  synthetic call is not a shipping-path witness — P4's ESC must be a real
  key event.
- ase::netlist's GUI guard needs the design as current schematic — always
  go through do_run/design_window in tests, never raw ase::run under X.
- ngspice runs need `::SKYWATER_MODELS` set BEFORE the deck renders.
