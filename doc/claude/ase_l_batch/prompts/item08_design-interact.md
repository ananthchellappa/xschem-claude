# Item 08 — design-interact (ROUND-2 ACCEPTANCE GATE): Select On Design + whole-flow GUI leg

You are the IMPLEMENTER of ASE-L mini-batch item 08 (the LAST round-2 item and
the round's acceptance gate). Repo `/home/qflow/dev/xschem/claude_1/xschem`,
branch `fluid-editing`. Read this WHOLE prompt before writing code. Everything
here was re-verified from source on 2026-07-21 by the scout; line numbers are
current as of commit `0c54ed28`.

Read first (in this order):
1. `doc/claude/ase_l_batch/RUNBOOK.md` (policies — copied verbatim at the
   bottom of this prompt, they are non-negotiable)
2. `doc/claude/specs/ase_l.md` — section "UI v2 — ADE-L parity rework"
   (NOTE: this section exists only in the WORKING TREE — the file is dirty
   with the driver's uncommitted round-2 contract; see "Spec edit + staging
   rule" below)
3. `doc/claude/ase_l_batch/receipts/05_ui-shell.md`, `06_panes-strip.md`,
   `07_dialogs.md` — the WSLg lessons (send_return, raise idiom, dblclick
   coalescing, sabotage discipline) all apply here
4. `src/ase_window.tcl` + `src/ase.tcl`

## Scope

Two deliverable groups, ONE feature commit:

1. **Select On Design** — a click mode on the design schematic that queues
   Outputs rows: wire/net-label click → voltage output `v(<net>)`; click on a
   source-class instance (symbol type `vsource`/`ammeter`) → source-current
   output `i(<instname>)`; ESC ends the mode, restores all canvas bindings
   verbatim and returns focus to the ASE window. Three entry points: Outputs >
   To Be Saved > Select On Design, Outputs > To Be Plotted > Select On Design
   (both currently `todo_stub` — src/ase_window.tcl:285-293), and a new
   "From Design…" button in the `-->` Setup-Outputs dialog
   (`ase::ui::output_editor`, src/ase_window.tcl:910-941; the strip `-->`
   button is :371-374 with the "choose-from-design is item 08" comment).
2. **Whole-flow GUI acceptance leg** (ROUND GATE) in a NEW test file
   `tests/headless/test_ase_interact.tcl`: open test_nfet_final
   ngspice_state1 → Choose Analyses ensure op enabled → add an output via the
   `-->` dialog → Netlist and Run → log toplevel appears, status returns
   Ready, Outputs Value shows Id ≈ 409.7 µA (±1 µA) → Save State (Save-As)
   to a scratch view → close session → reopen the scratch view → panes
   repopulate identically. If this leg cannot pass, or only passes via
   workarounds inside the test, the ITEM FAILS — no exceptions.

Also: remove `ase::ui::todo_stub` (src/ase_window.tcl:2072-2074) — after this
item it has ZERO callers (receipts/07 contract). test_ase_dialogs' G11 scan
(tests/headless/test_ase_dialogs.tcl:559-581) excludes the item-08 entries by
construction and only string-matches `todo_stub` in `-command` values, so the
removal cannot break it.

NO C changes. NO src/ase.tcl changes are expected (the mode is pure
window-layer; run/result_probe/session procs are reused as-is). If you find
you need a C or ase.tcl change, stop and re-read the decisions below — the
scout verified every needed query already exists.

## Verified anchors (all re-checked from source 2026-07-21)

Product code:
- src/ase_window.tcl:285-293 — the two `todo_stub {Outputs To Be Saved} 08` /
  `{Outputs To Be Plotted} 08` menu entries + the `TODO(item08)` comment.
- src/ase_window.tcl:2072-2074 — `ase::ui::todo_stub` (remove).
- src/ase_window.tcl:371-374 — strip `-->` button → `output_editor $key -1`.
- src/ase_window.tcl:910-989 — `output_editor` (fields `$w.name`/`$w.expr`,
  checkbuttons `$w.plot`/`$w.save` on vars `edchk($key,plot|save)`, rows
  gridded 0-3, `dialog_buttons` on row 4), `output_editor_ok`,
  `output_editor_cancel`.
- src/ase_window.tcl:2118-2138 — `ase::ui::design_window` (item-05-fixed
  raise-or-open; returns 1 on success, 0 unresolvable). :2098-2110
  `raise_design_editor` (uses `raise_activate_toplevel`, xschem.tcl:5526).
- src/ase_window.tcl:208-229 — `ase::ui::close` (extend: end an active mode).
- src/ase_window.tcl:678-724 `populate`; :571-594 `delete_selection` (the
  session_update + populate mutation idiom to copy).
- src/ase.tcl:421-427 `session_update`; :510-539 `open_state` (4-arg with
  trailing `ro`); :594-598 render_deck emits `.save`/`print` ONLY for rows
  with `save 1`; :644-659 `result_probe` keys results by name-else-expr —
  `output_result_key` (ase_window.tcl:612-617) is the window-side mirror.

C query surface (read-only, all existing — the "smallest honest hook" set):
- `xschem select_at <x> <y> [add] [nodraw]` — scheduler.c:9581-9650. Takes
  SCHEMATIC coordinates, selects the closest object (visual feedback), logs
  its own replayable line, returns a bare `{type n col id}` row (`wire`,
  `instance`, `text`, …) or "" on a miss.
- `xschem flylines at <x> <y>` — scheduler.c:3474-3560. Read-only dict
  `net {N} global .. members .. clusters .. segments ..`; `net` is the net
  name under (x,y) resolved via flyline_net_of (flyline.c:38-53: wires by
  .node, net-label instances by .node[0]); does NOT require the flylines
  overlay to be enabled and never writes state.
- `xschem get mousex_snap` / `mousey_snap` — scheduler.c:3884/3888: last
  snapped mouse position in schematic coords, kept current by the generic
  `<Motion>` binding → C callback. Precedent for using them inside a Tk
  handler: xschem.tcl:10767.
- `xschem getprop instance <n> name` → instname (e.g. V1);
  `xschem getprop instance <n> cell::type` → the SYMBOL's type token
  (scheduler.c:4407-4460; `<n>` may be the index from the select_at row).
- `xschem get current_win_path` → the CANVAS path of the current window
  (".drw" for main, ".xN.drw" for others — scheduler.c:3087 compares it to
  ".drw"; `xschem windows` rows are
  `{win_path top_path group xwindow current_name number}`,
  scheduler.c:11699-11730).
- `xschem get xorigin` / `yorigin` / `zoom` (scheduler.c:4270/4288/4306) and
  `X_TO_SCREEN(x) = (x + xorigin) * mooz`, `mooz = 1/zoom` (xschem.h:437-438)
  → test-side world→pixel conversion `px = (wx + xorigin) / zoom`.
- `xschem zoom_full` — scheduler.c:11928.

Tk binding model (the mode's interception mechanism):
- The canvas has GENERIC widget bindings `<ButtonPress>`, `<ButtonRelease>`,
  `<KeyPress>`, `<Motion>` → `xschem callback …` (set_bindings,
  xschem.tcl:13843-13906 — note :13895-13899). Tk fires the MOST SPECIFIC
  matching binding per tag, so adding `<ButtonPress-1>` / `<ButtonRelease-1>`
  / `<Key-Escape>` bindings on the same canvas pre-empts the generic ones for
  exactly those events, leaving Motion/Enter/FocusIn (context switching,
  mousex_snap updates) untouched. House precedents: the hi_descend
  more-specific key binding (xschem.tcl:13913-13916) and the addpin/addlabel
  `.drw <Key-Escape>` slot (xschem.tcl:10780-10791, 11116-11121) — the Esc
  slot is SHARED with those forms, which is why the mode must save the
  previous binding strings and restore them VERBATIM (empty string = no
  binding) instead of unconditionally clearing.

Fixture / test surface:
- Committed cell `sky130A/xschem_libs/sky130_tests/test_nfet_final/`:
  schematic (wires: D net `N 420 -330 600 -330`, G net `N 380 -330 250 -330`,
  GND net `N 250 -270 600 -270`; instances: M1 at 400,-300 (subcircuit —
  non-source), V1 vsource at 600,-300, V2 vsource at 250,-300, lab_wire lD at
  500,-330, lG at 300,-330) + `ngspice_state1/test_nfet_final.state`
  (op enabled, outputs `{name id expr -i(v1) save 1 plot 0}`, rundir {}).
- Symbol type tokens: `type=vsource`
  (xschem_libs_newsym/devices/vsource/symbol/vsource.sym:23), `type=ammeter`
  (…/ammeter/symbol/ammeter.sym:23).
- Harness idioms to copy (with an origin comment, the item-07 precedent) from
  tests/headless/test_ase_window.tcl: `check`/`check_true` (:41-46),
  `main_ready` (:50-59), `tv_find` (:90-95), `send_return` (:155-173),
  `menu_save_state` (:180-195), the scratch `library.defs` registry
  (:229-236), the W4 nudge + self-SKIP raise pattern (:734-762).
  From tests/headless/test_ase_final.tcl: the committed-tree DEFINEs +
  `::SKYWATER_MODELS` resolution (:53-64) and the hermetic-rundir fixture
  shaping through the public schema (:96-97, decision D7 there).
- Dialog widget paths (item 07, all verified): Choose Analyses
  `$top.chana` (radios `$top.chana.types.op` …, `$top.chana.enable` on var
  `::ase::ui::dlg($key,anen)`, OK `$top.chana.btns.proceed`,
  src/ase_window.tcl:1145-1253); Save-As `$top.saveas` (`.lib` combobox,
  `.cell`/`.view` entries prefilled, `.btns.proceed`, :1865-1944, worker
  `do_save_state_as` :1955-1988 creates a missing view via
  `library_new_view`); Add Output `$top.edout` (see above).

## Scout decisions (binding — implement as written; deviations must be
declared in your final report with a one-line reason each)

- **D1 — click infra**: Tk more-specific bindings on the design window's
  canvas (`set cv [xschem get current_win_path]` right after a successful
  `design_window`): seize `<ButtonPress-1>` → `sod_click`, `<ButtonRelease-1>`
  → a bare `break` (a lone release must not reach the C callback — the press
  it pairs with was swallowed), `<Key-Escape>` → `sod_end`. Save the previous
  binding STRING of all three (`bind $cv <ButtonPress-1>` etc.) at entry and
  restore verbatim at exit — this composes with the addpin/addlabel shared
  Esc slot for free. Every bind script ends `; break`. Coordinates come from
  `xschem get mousex_snap`/`mousey_snap` (Motion still flows to C). Hit test
  via `xschem select_at $x $y` (also gives Cadence-like click feedback and a
  replayable action-log line); net resolution via
  `dict get [xschem flylines at $x $y] net`. NO new C subcommand, no
  callback.c hook — this is the smallest honest hook and it is fully
  restorable.
- **D2 — v1 terminal-current scope (the honest restriction, explicitly
  allowed by the item)**: only SOURCE-class instances queue currents — symbol
  type ∈ {`vsource`, `ammeter`} → `i(<instname, lowercased>)`. A click on any
  other instance that does not resolve to a net (e.g. M1) reports
  `ciw_echo "ase: v1 queues source currents only — click a wire, a net label
  or a voltage source/ammeter"` and queues NOTHING. Rationale: ngspice
  per-terminal currents of non-source devices need
  `.options savecurrents` + `@m.x<inst>.<subdev>[id]` names that depend on
  subcircuit internals invisible to the schematic click. Pin-level hit
  precision is deliberately NOT needed for v1: a source has exactly one
  branch current, so instance-level granularity is exact for the supported
  class. Document this in the receipt AND the spec note (see below).
- **D3 — expression case**: lowercase the generated token —
  `v([string tolower $net])`, `i([string tolower $inst])` — because ngspice
  echoes `print` expressions lowercased and `result_probe` matches the expr
  literally (the committed fixture's `-i(v1)` is already lowercase for the
  same reason).
- **D4 — classification order** in `sod_click`: (a) select_at miss → return;
  (b) hit is an `instance` whose `cell::type` ∈ {vsource, ammeter} → current;
  (c) otherwise `flylines at` net non-empty → voltage (this makes wires AND
  net labels AND labeled pins work uniformly); (d) otherwise the D2 notice.
- **D5 — flavors**: To Be Saved entry → `{save 1 plot 0}`; To Be Plotted →
  `{save 1 plot 1}` (a plot-only row would be DEAD: render_deck emits
  `.save`/`print` only for `save 1` — src/ase.tcl:594-598, 614-618 — and
  ADE plots imply saving). From-Design button → the dialog's current
  Plot/Save checkbox values with save coerced to 1 when both are 0.
- **D6 — queueing + dedupe**: exact-string match on the `expr` key. Existing
  row → OR the flavor's save/plot into it (no duplicate row; unchanged row →
  `ciw_echo` "already queued" notice, no state write). New row →
  `[dict create name {} expr $e plot $p save $s]` appended. Every state write
  goes `ase::session_update` + `ase::ui::populate` (the delete_selection
  idiom) so the row is visible in the Outputs pane IMMEDIATELY (the pane may
  be behind the design window — that is fine). Note `i(v1)` does NOT merge
  into the committed `-i(v1)` row (different strings — correct and honest).
- **D7 — pure helpers** (Tk-free, headless-testable, the item-06 P-leg
  pattern): `ase::ui::sod_expr {kind token}` → the lowercased
  `v(...)`/`i(...)` string; `ase::ui::sod_merge {outputs expr flavor}` →
  returns `{newoutputs status}` with status ∈ {added merged nochange}.
  `sod_click` composes them.
- **D8 — mode lifecycle**: namespace `variable sod; array set sod {}` records
  per active mode: `sod(active)` = key (ONE mode globally — entering while
  another is active cleanly ends the previous one first), `sod($key,canvas)`,
  `sod($key,flavor)`, `sod($key,prevpress)`, `sod($key,prevrel)`,
  `sod($key,prevesc)`. Entry proc `ase::ui::select_on_design {key flavor}`:
  (1) `design_window $key` — on 0 report + no mode; (2) seize bindings per
  D1; (3) `ciw_echo` instruction line ("click wires/net labels for voltages,
  sources for currents; ESC ends"). Exit proc `ase::ui::sod_end {key}`:
  restore the three bindings verbatim (catch{} — the canvas may be dead),
  clear sod records, `ciw_echo` a "N output(s) queued" summary, then return
  focus to the ASE window via `raise_activate_toplevel` + `focus` (the
  receipts/05 WSLg idiom — bare raise is a no-op under Weston).
  `ase::ui::close` (src/ase_window.tcl:208-229) must call `sod_end` when
  `sod(active)` is this key (binding-leak guard).
- **D9 — testability shape**: `sod_click {key {x {}} {y {}}}` — empty x/y
  reads mousex_snap/mousey_snap (the product binding calls it bare); tests
  call it with explicit schematic coordinates (replayable, deterministic).
  At least ONE leg must drive the REAL generated event sequence on the canvas
  (gesture-test-full-sequence lesson): generate `<Motion>` at the target
  pixel FIRST (that is what refreshes mousex_snap), then
  `<ButtonPress-1>`/`<ButtonRelease-1>`. Pixel = `(wx + xorigin)/zoom`
  rounded to int, after `xschem zoom_full`; skip the leg with a printed
  SKIPPED line if the computed pixel falls outside the mapped canvas
  (WSLg geometry class).
- **D10 — whole-flow hermeticity**: the WF legs run on a SCRATCH CLONE:
  `file copy` the committed `test_nfet_final` cell dir into
  `$scratch/sky130_tests/`, DEFINE `sky130_tests` → the clone,
  `sky130_fd_pr`/`devices` → the real repo trees, set `::SKYWATER_MODELS`
  (test_ase_final idiom). Before any session opens, rewrite the CLONE's
  state file rundir to `$scratch/run` via `ase::state_load`/`state_save`
  (public schema, the test_ase_final D7 precedent — fixture shaping, not a
  flow workaround; the committed tree is never written). Save-As targets view
  `ngspice_scratch1` inside the clone. Scratch dir `_ase_interact_[pid]`
  under [pwd], deleted in cleanup.
- **D11 — session sequencing in the test**: run the I-legs (mode) first on a
  session of the clone's ngspice_state1, then `Close` WITHOUT saving (close
  discards by contract) so the WF legs re-open a PRISTINE session on the same
  view. Do not interleave.
- **D12 — spec edit + staging rule (deviation from the item detail,
  pre-authorized by the scout — copy this justification into your report)**:
  add the v1 scope note to `doc/claude/specs/ase_l.md` (UI v2 section, at the
  `-->` action-strip bullet or as a short "Select On Design v1 scope"
  paragraph: wires/net labels → `v(<net>)`; source-class instances
  (vsource/ammeter) → `i(<inst>)`; per-terminal currents of other devices
  deferred — ngspice needs savecurrents + `@dev[current]` subckt-internal
  names). BUT DO **NOT** STAGE the spec file: it is dirty with the driver's
  UNCOMMITTED round-2 "UI v2" contract (96 foreign lines) — staging it would
  sweep driver content into your commit, which the hygiene lens will fail.
  The driver's ledger commit carries the spec (the item-04→2d838cbe
  precedent). Your receipt/report must state: spec edited in working tree,
  deliberately left unstaged, reason as above.

## Deliverables (product)

All in `src/ase_window.tcl` (namespace `ase::ui`, TIP-278 discipline —
`variable` declarations, absolute names in bind scripts):
1. `variable sod` state + `select_on_design {key flavor}` + `sod_end {key}`
   per D1/D8.
2. `sod_click {key {x {}} {y {}}}` per D4/D9 + pure helpers `sod_expr`,
   `sod_merge` per D7, queue write per D6.
3. Menu rewiring: the two Select On Design entries →
   `[list ase::ui::select_on_design $key {save 1 plot 0}]` resp.
   `{save 1 plot 1}`; delete the `TODO(item08)` comment.
4. `output_editor`: new button `$w.fromdes` (text "From Design…",
   themed) gridded at a deterministic path (e.g. row 2/3 column 0 — rows
   0-4 are taken per the anchor above; do not disturb existing field paths —
   test_ase_dialogs G10 asserts `$top.edout` + title); command
   `ase::ui::output_editor_from_design {key}`: read
   `edchk($key,plot)`/`edchk($key,save)` → flavor per D5, then
   `output_editor_cancel` (typed name/expr are DISCARDED — choose-from-design
   replaces manual entry; note in the receipt), then `select_on_design`.
5. `ase::ui::close`: end an active mode for this key (D8).
6. Remove `ase::ui::todo_stub`. After your change
   `grep -n "todo_stub\|TODO(item08)" src/*.tcl` must return NOTHING.
7. User-facing messages via `ciw_echo` only (RUNBOOK).

## Deliverables (spec, working tree only — D12)

`doc/claude/specs/ase_l.md`: the v1 scope note. EDIT, do NOT stage.

## Test: NEW `tests/headless/test_ase_interact.tcl`

Auto-discovered by full_audit.sh (do NOT touch tests/run_regression.tcl —
pre-batch dirty). Header comment: purpose, leg map, standalone repro line
(`./src/xschem --pipe -q --nolog --script tests/headless/test_ase_interact.tcl`
from repo root; GUI legs need DISPLAY). Copy the harness helpers with origin
comments. DISPLAY-guarded GUI block (`[info exists ::has_x] &&
[info commands winfo] ne {}`), `main_ready` gate before design-window legs,
`auto_execok ngspice` gate around the run leg (SKIPPED line when absent),
scratch cleanup + `RESULT: ALL PASS (N checks)` / exit-code protocol
(the test_ase_window pattern verbatim).

Headless legs (run without DISPLAY too):
- `H1 sod_expr voltage lowercases the net` — `[ase::ui::sod_expr voltage D]`
  → `v(d)`; `H1 sod_expr current lowercases the source` → `i(v1)`.
- `H2 sod_merge appends a new row` (status added, row
  `{name {} expr v(d) plot 0 save 1}`), `H2 sod_merge ORs flags into an
  existing row` (plot flavor onto a save-only row → merged, single row,
  plot 1 save 1), `H2 sod_merge identical re-queue is nochange` (outputs
  list returned unchanged), `H2 sod_merge leaves other rows intact`.

GUI I-legs (mode; on the clone session, D10/D11 — assert against
`ase::state_get [ase::session_state $key] outputs` AND the pane):
- `I1 To Be Saved menu enters the mode` — invoke
  `$top.mb.outputs.saved` entry {Select On Design}; assert
  `[file normalize [xschem get schname]]` == the clone schematic path and
  `bind $cv <ButtonPress-1>` non-empty (capture the pre-mode values of all
  three bindings first).
- `I2 real click gesture queues v(g)` — the D9 real-event leg at world
  (340,-330) (G-net wire, clear of the lG label at 300,-330): Motion +
  Press-1 + Release-1 at the computed pixel; outputs gain
  `{name {} expr v(g) plot 0 save 1}`.
- `I3 direct wire click queues v(d)` — `ase::ui::sod_click $key 550 -330`;
  row appended; `I3 row visible in the Outputs pane immediately` —
  `tv_find $top.body.outs.tv name v(d)` non-empty (populate ran — sabotage-S3
  target).
- `I4 net-label click dedupes` — `sod_click $key 500 -330` (the lD label) →
  outputs UNCHANGED (nochange path).
- `I5 vsource click queues i(v1)` — `sod_click $key 600 -300` → row
  `{name {} expr i(v1) plot 0 save 1}` (distinct from the committed
  `-i(v1)` row — assert both exist).
- `I6 non-source click queues nothing` — `sod_click $key 400 -300` (M1) →
  outputs unchanged.
- `I7 ESC ends the mode via the REAL key` — focus-gated generate of
  `<Key-Escape>` on the canvas, send_return-style retry loop with
  done-condition "mode inactive" (e.g. the ButtonPress-1 binding reverted);
  then: `I7 ButtonPress-1 binding restored verbatim`,
  `I7 ButtonRelease-1 binding restored`, `I7 Key-Escape binding restored`,
  `I7 generic ButtonPress binding untouched` (string-equal to its pre-mode
  value — the "must not corrupt normal editing bindings" gate). ASE-window
  raise after ESC: assert with the W4 nudge/self-SKIP pattern (product
  regression fails every attempt; a WSLg stackorder stall self-SKIPs).
- `I8 To Be Plotted flavor merges plot into v(d)` — enter via the plotted
  menu entry, `sod_click $key 550 -330` → the v(d) row now plot 1 save 1,
  still ONE v(d) row; end mode (sod_end direct is fine here — the real-ESC
  path is I7's).
- `I9 From Design button` — open `$top.strip.out` → `$top.edout` exists;
  invoke `$top.edout.fromdes` → dialog destroyed AND mode active; sod_end.
- `I10 close ends an active mode` — re-enter mode, `ase::ui::close $key` →
  canvas bindings restored (no leak). (Session gone — reopen happens in WF.)

GUI WF legs (the ROUND GATE — fresh session per D11, every step through the
product path):
- `WF open state` — `ase::open_state sky130_tests test_nfet_final
  ngspice_state1` → 1, window exists, title
  `Analog Sim Environment test_nfet_final`.
- `WF Choose Analyses op enabled` — menu Analyses invoke "Choose…" →
  `$top.chana` exists, `dlg($key,antype)` == op, `dlg($key,anen)` == 1
  (committed state), `$top.chana.btns.proceed` invoke → dialog gone, state
  op row still `enabled 1`.
- `WF --> dialog adds v(d)` — `$top.strip.out` invoke → `$top.edout`; insert
  name `vd`, expr `v(d)`; set save checkbox var
  `::ase::ui::edchk($key,save)` 1 (widget invoke or var set — the
  checkbutton var is product surface); proceed via `$top.edout.btns.proceed`
  invoke; row in state + pane (`tv_find … name vd`).
- `WF Netlist and Run` (main_ready + ngspice gates) — menu
  `$top.mb.sim invoke {Netlist and Run}`; run_id integer;
  `WF log toplevel appears` — `winfo exists $top.logwin`; `ase::wait` → 
  `WF exit 0`; `WF status Ready` — `.status.stat` text `Status: Ready` and
  background Green; `WF id Value ≈ 409.7 µA` — id row Value cell,
  `abs(v*1e6 - 409.68) < 1.0`; `WF vd Value ≈ 1.0` — vd row Value cell
  `abs(v - 1.0) < 1e-3` (Vds=1.0 — proves the ADDED output flowed through
  deck → print → result_probe → Value fill).
- `WF Save State to scratch view` — menu_save_state VARIANT: invoke Session >
  Save State, set `$top.saveas.view` to `ngspice_scratch1`, proceed →
  `WF scratch view created` — clone dir
  `sky130_tests/test_nfet_final/ngspice_scratch1/test_nfet_final.state`
  exists. Snapshot `variables`/`analyses`/`outputs` of the session state NOW.
- `WF close` — menu Close → toplevel destroyed.
- `WF reopen scratch view` — `ase::open_state sky130_tests test_nfet_final
  ngspice_scratch1` → 1, NEW window; `WF variables identical`,
  `WF analyses identical`, `WF outputs identical` (string-compare the three
  state lists against the snapshot); spot-check the pane (`tv_find` vd row).
- Close + cleanup.

Self-SKIP policy (item text): only legs WSLg physically cannot do may
self-SKIP (main_ready geometry, W4-class stackorder stall, off-canvas pixel,
ngspice absent) — each with a printed SKIPPED line; justify every SKIP that
actually fired in your report. The WF Value/state legs themselves must NOT
be skippable when DISPLAY + ngspice are present.

## Regression obligations

- `tests/headless/test_ase_core.tcl` (45), `test_ase_view.tcl` (36),
  `test_ase_window.tcl` (144 GUI/31 headless), `test_ase_dialogs.tcl` (73),
  `test_ase_final.tcl` (28) must stay GREEN and UNTOUCHED. Re-run all five
  after your change (DISPLAY for the GUI ones; single flaky FAIL → rerun
  first, receipts/06-07 precedent).
- `tests/headless/full_audit.sh` (background, from repo root): FAIL set must
  be a subset of the PLAN.md baseline:
  test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
  test_cadence_window_hop_log, test_ciw, test_crossview_paste,
  test_fluid_editing, test_hi_descend, test_launch_context,
  test_lib_manager_gui, test_lib_sweep, test_palette, test_phase3_mints,
  test_pin_type_edit, test_reopen_readonly, test_select_at,
  test_selflog_output, test_verb_noun_copy_move, test_wire_split,
  test_wire_vertex_grab; TIMEOUT test_key_graph_context. Known WSLg flakes
  (pass on direct rerun ⇒ not regressions): test_deselect_mode,
  test_hover_highlight, test_ase_window-inside-parallel-audit,
  test_close_window_restores_prev_tab.

## Sabotage plan (run post-commit; each: `git diff` confirms the tree holds
NOTHING but the sabotage, run the test, then targeted
`git checkout -- src/ase_window.tcl`, clean re-run green)

| # | Sabotage (src/ase_window.tcl) | Expected EXACT failures |
|---|---|---|
| S1 | in `sod_click`, make the voltage arm (D4 step c) return WITHOUT queueing | I2 (v(g) row), I3 both checks, I8 (plot merge — its target row never existed); I5/I6 (current/notice) and all H/WF legs stay green |
| S2 | in `sod_end`, skip restoring the saved `<ButtonPress-1>` binding (keep the other two restores) | exactly `I7 ButtonPress-1 binding restored verbatim` (+ the I10 leak check if it asserts the same binding); all other I7 restore checks stay green |
| S3 | in the D6 queue write, drop the `ase::ui::populate` call (keep `session_update`) | exactly `I3 row visible in the Outputs pane immediately` (the state check right before it stays green — the differential proof) |

Predicted-vs-observed mismatches: record honestly per the receipts/07 S2
protocol (finer granularity inside the targeted blocks is acceptable; misses
OUTSIDE them are not).

## Commit (ONE feature commit)

Stage EXACTLY:
- `src/ase_window.tcl`
- `tests/headless/test_ase_interact.tcl`

Do NOT stage: `doc/claude/specs/ase_l.md` (D12 — edited, left for the
driver), `doc/claude/ase_l_batch/PLAN.md`, any pre-batch dirty tracked file
(`doc/claude/specs/sky130_workarea.md`, `sky130A/xschem_libs/library.defs`,
`src/ciw.tcl`, `tests/headless/test_sky130a_libmgr.tcl`,
`tests/run_regression.tcl`,
`xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym`,
`xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`),
any `_nhangle_*`/`_allm_*`/scratch junk. Message: normal prose, e.g.
`feat(ase): Select On Design click mode + whole-flow acceptance — wire/source
clicks queue outputs, ESC restores bindings`, with the repo's Co-Authored-By
trailer. NEVER push.

Leftover scratch dirs from aborted runs (`_ase_interact_*`) must be removed
before you finish (receipts/06 hygiene precedent).

## Report

Deliverables status, check counts (headless/GUI split), sabotage table with
observed exact-failure sets, every declared deviation (D12 spec-unstaged MUST
be listed), every SKIP that fired and why, full_audit verdict vs baseline.
This item is the ROUND-2 ACCEPTANCE GATE: if the WF leg cannot pass without
in-test workarounds, report the item as FAILED — do not paper over it.

## RUNBOOK policies (copied verbatim — non-negotiable)

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
