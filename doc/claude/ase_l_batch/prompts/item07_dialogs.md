# Item 07 — dialogs (ROUND 2, UI v2 / ADE-L parity) — implementation prompt

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch `fluid-editing`. NEVER push.
Authoritative contract: spec section "UI v2 — ADE-L parity rework" in
doc/claude/specs/ase_l.md (Menu tree v2 :207-232, Choose Analyses dialog
:238-243, Dialog style :244-247, Action strip :194-205 — line numbers verified
2026-07-21). Item detail: PLAN.md "### 07 dialogs" (:117-147).
Receipts to skim first: receipts/05_ui-shell.md + receipts/06_panes-strip.md
("Corrected/confirmed anchors worth keeping" sections are load-bearing).

Mission: replace EVERY `TODO(item07)` stub in src/ase_window.tcl with the real
dialog, add the allv/alli deck mapping to the ngspice backend, thread the
LibMgr "Open (read-only)" flag into ASE sessions, and prove all of it with
named tests + exact-target sabotages. ONE implementation commit.

## Verified anchors (2026-07-21 — all re-checked from source this session)

Stubs to replace (src/ase_window.tcl):
- :222-228  Session menu — Load State / Save State wired to the v1 procs,
            `TODO(item07)` comment at :222 (menu labels asserted by W1m at
            tests/headless/test_ase_window.tcl:414-415 — labels MUST NOT change).
- :234-238  Setup > Design… + Model Files… → `todo_stub` (TODO at :234).
- :242-244  Analyses > Choose… → `todo_stub`.
- :266-268  Outputs > Save All… → `todo_stub`.
- :284-286  Simulation > Options… → `todo_stub`.
- :341-342  action strip `OP,TR` ($top.strip.ana) → `todo_stub {Choose Analyses} 07`.
- :345-346  action strip `-->`  ($top.strip.out) → `todo_stub {Setup Outputs} 07`.
- :426-431  analyses pane ctx Add…/Edit… → `todo_stub` (TODO at :426).
- :508,:520 `pane_dblclick` ana arm → `todo_stub` (TODO comment at :508).

Existing machinery to reuse (src/ase_window.tcl):
- `ase::theme` :84-109 (locked palette + named fonts), `ase::ui::apply_theme`
  :115-143. USER-LOCKED palette: panels #f2f2f2, tables/entries #ffffff,
  headers #e8e8e8, accent #8b0000; fonts AseLabelFont/AseEntryFont/AseMonoFont.
- dialog scaffold `dialog_frame`/`dialog_row`/`dialog_buttons` :742-765
  (fields live at deterministic paths `$w.<name>` — keep this property).
- item-06 dialogs precedent (modeless, Return=proceed, per-key records):
  `add_variable_dialog` :770-809, `variable_editor` :813-869,
  `output_editor` :875-954 (Add flavor = idx -1, title "Add Output").
- `ase::ui::close` :180-199 — per-key cleanup (`array unset edrow $key,*`,
  `array unset edchk $key,*` at :196-197). Extend for every new per-key record.
- namespace vars :47-75 (`anaargs` :63-64: dc {source start stop step},
  ac {points start stop dec}, tran {step stop}; `panekeys` :66).
- `populate` :643-689, `save_options_cell` :602-611 (reads save_all_v/save_all_i),
  `delete_selection` :536-559 (main-pane X — do NOT extend it, see D1),
  `pane_ctx_post` :524-530, `session_changed` notify :1057-1060,
  `design_cell_name` :1003, `refresh_title` :1015, `save_state`/`load_state`
  /`revert_state` :1064-1074, `todo_stub` :1078-1080.

Core (src/ase.tcl):
- `schema_keys` :28-30 (13 keys — item 07 must NOT add any: see LANDMINE 1).
- `state_default` :68-83, `state_serialize` :110, `state_save` :129,
  `state_load` :89-103.
- session procs: `session_open` :393, `session_state` :412, `session_update`
  :420, `session_dirty` :430, `session_save` :440, `session_load` :452,
  `session_close` :473, `session_setattr`/`session_getattr` :481-491.
- `ase::open_state` :505-531 — signature extension point (D7). The name +
  3-arg call shape are a stable contract; a TRAILING OPTIONAL arg is allowed.
- ngspice `render_deck` :542-602: options loop :556-565, `.temp` block
  :566-573, per-output `.save` loop :574-578, `.control` :579-599.
  Insertion points for D12 are between :565/:566 (alli) and just before the
  `.save` loop at :574 (allv).

LibMgr / view machinery:
- `libmgr::view_handler` src/library_manager.tcl:440-447; `open_view` :452-496;
  `open_view_ro` :584-599 (state-view divert branch :588-594 — the D7 edit
  site); `lib_names` :537-541; `refresh_after` :546-579 (headless-guarded at
  :552); `newview_dialog` :1238 (type combobox :1248 already lists
  ngspice_state1 — no change needed).
- `library_new_view` src/library_defs.tcl:703-723 (the item-02 creation path;
  ngspice_state* arm seeds a VALID default state at :711-718). Cell must
  already exist (:707) — basis of D9. `library_new_cell` :579-589 creates
  sch/sym views only. `cell_views` :261-273, `cellview_resolve` :209-230
  (any-`<cell>.*` fallback :220-224), `cellview_path` :235-238.
- Tcl-visible C subcommands (src/scheduler.c): `libraries` :6466,
  `lib_cells` :6482, `cell_views` :2277, `cellview_path` :2268,
  `allocate_window_number` :1592.

Dialog-style references:
- references/copy_current_cell_dialog.tcl (repo ROOT — the PLAN's
  "references/…" path is relative to the repo root, not doc/claude/):
  named-font creation :32-42, type-to-filter combobox `filter_combo` :136-161
  + `<<ComboboxSelected>>` :163-167, valid-value resolution :169-179,
  Return=proceed :127-131, per-window arrays cleaned on destroy :238-244.
- src/create_instance.tcl `mkinst::` browser precedent: 3-column
  Library/Cell/View toplevel :288-335, `-exportselection 0` listboxes :305,
  view filter `symbol_views` :379-386 (filter by cellview_path extension —
  mirror it for `.state` / `.sch`), selection restore :418-448.

Tests:
- tests/headless/test_ase_window.tcl: `send_return` helper :155-173 (MUST be
  reused for every generated Return — copy it verbatim into the new file with
  an origin comment); `tv_bbox`/`tv_dblclick`/`tv_cell_click` :99-140;
  fixture block (scratch lib + library.defs + state seeding through the real
  backends) :175-239; GUI guard `[info exists ::has_x] && [info commands
  winfo] ne {}` :354; Save State menu-invoke sites to update: :500, :515,
  :531, :549, :579, :589, :656; W1m Session-labels check :414-415.
- tests/headless/test_ase_core.tcl: D1 golden deck :148-180 (save_all_* are 0
  there — D1 must stay byte-identical), D4 temperature legs :201-216.
- tests/headless/full_audit.sh: auto-discovery `ls test_*.tcl` :100; default
  arm `--pipe -q --nolog --script` :130 (new test needs NO special-casing).
  Do NOT touch tests/run_regression.tcl (pre-batch dirty).

## Scout decisions (each binding; justification one line)

- **D1 Model Files delete is dialog-local** (ctx-menu Delete + a Delete-key
  binding on its treeview); the main action-strip X keeps scanning ONLY the
  three panes — cross-toplevel selection coupling would break the enforced
  single-pane model and dangle when the dialog dies.
- **D2 Tests**: NEW tests/headless/test_ase_dialogs.tcl (auto-discovered, no
  runner edits) for dialog legs; deck-mapping legs extend test_ase_core.tcl
  (headless, named D5); test_ase_window.tcl gets ONLY the Save-State-menu
  driver update (its menu entry now opens a dialog) — helpers are copied, not
  shared-sourced, because every test is its own process.
- **D3 `-->` opens `ase::ui::output_editor $key -1`** (the Add Output dialog
  IS the v1 "Setup Outputs" dialog: name optional + expression + Plot/Save);
  the choose-from-design button is item 08 by plan.
- **D4 Choose Analyses commits only the currently-shown analysis on OK**;
  switching the top radio repopulates the bottom form from state (discards
  in-form edits of the previous type) — deterministic, no hidden multi-type
  writes; pane Enable checkboxes already cover bulk enabling.
- **D5 Choose Analyses "Options…" button** = per-analysis extra name/value
  editor writing EXTRA keys into that analysis row's dict (they round-trip
  and show in the Arguments summary via arg_summary's unknown-key arm);
  extra-key deck emission stays deferred — document in the dialog comment.
- **D6 OK-time validation**: an analysis being saved with Enable=1 must have
  every quick field non-empty (dc: source/start/stop/step; ac:
  points/start/stop; tran: step/stop; op: none) — reject with ciw_echo and
  keep the dialog up; prevents render_deck's `dict get` blowing up at run.
- **D7 read-only threading**: `ase::open_state` gains a trailing optional
  `{ro 0}` arg that sets session attr `readonly` (EVERY open sets it — last
  open wins, a later plain open upgrades to editable); `libmgr::open_view_ro`'s
  state-view divert branch (library_manager.tcl:591-594) calls
  `ase::open_state $lib $cell $view 1` directly instead of `libmgr::open_view`
  (it already holds lib/cell/view + the handler check). The RO flag affects
  ONLY the Save-As confirm in v1 (no edit blocking — not in spec).
- **D8 confirm seam**: pure predicate `ase::ui::save_as_needs_confirm $key
  $lib $cell $view` → 1 iff target resolves to the session's own state-file
  path AND (session attr readonly==1 OR `![file writable <path>]` — the
  LibMgr git-checkout discipline leaves non-checked-out files unwritable);
  confirms are MODELESS themed toplevels (`ase::ui::confirm`), NOT
  tk_messageBox, so the full GUI path stays test-drivable (the item-06
  modeless doctrine, ase_window.tcl:733-737).
- **D9 Save-As targets an existing cell**: a new VIEW is created via
  `library_new_view $lib $cell $view ngspice_state1` then the seeded file is
  overwritten with the session's serialization; a nonexistent cell → clean
  `ciw_echo … error` (spec requires new-view creation only; library_new_cell
  makes sch/sym views, so auto-creating cells would invent behavior).
- **D10 Load State = content import into THIS session**: replace the session's
  in-memory state with the chosen file's loaded dict (`state_load` → merge
  over defaults) via `session_update`; path/key/meta stay untouched, so the
  dirty marker appears (contents now differ from the session's own file) —
  no session retargeting, no key juggling. Dirty session → confirm first.
- **D11 Save All levels field is present-but-DISABLED, backed by NO state
  key** — any schema_keys addition ripples into the protected test_ase_final
  F3 byte-identity fixture (items 05/06 lesson); inert is sanctioned by the
  item detail ("may be inert v1").
- **D12 deck mapping**: `save_all_i==1` → emit `.options savecurrents`
  immediately after the options loop (before `.temp`); `save_all_v==1` →
  emit `.save all` immediately before the per-output `.save` loop. Emit
  unconditionally when the flag is 1 (a duplicate `.options savecurrents`
  from an explicit options row is harmless to ngspice — document inline).
  D1 golden deck unchanged (both flags 0 in the fixture).
- **D13 overwriting a DIFFERENT existing view needs no confirm** in v1 —
  the spec's only confirm trigger is read-only + same-target; document.
- **D14 all new dialogs**: modeless (no grab/tkwait), themed via apply_theme,
  deterministic widget paths (listed per dialog below), per-key records in
  ONE new namespace array `dlg` (`dlg($key,…)`) cleaned on dialog
  proceed/cancel AND in `ase::ui::close` (add `array unset dlg $key,*`
  beside :196-197).
- **D15 Model Files + Simulation Options mutations commit immediately**
  (`session_update` per add/edit/delete, like the pane checkbox cells) —
  keeps the dirty marker live, nothing to harvest.

## Deliverables

### 1. src/ase.tcl
- `ase::open_state {lib cell view {ro 0}}`: after a successful
  `session_open`, `ase::session_setattr $key readonly $ro` (both the fresh
  and the raise arm — every open sets it). Update the contract comment.
- `render_deck` (ngspice): the two D12 emissions, with the `ase::state_get
  $state save_all_i 0` / `save_all_v 0` guards (`eq {1}` — the toggle_flag
  idiom). No other core change. NO schema_keys change (LANDMINE 1).

### 2. src/library_manager.tcl
- `open_view_ro` divert branch (:588-594): replace `libmgr::open_view` with
  a direct RO dispatch — resolve handler as today; when it is not `editor`,
  call `ase::open_state $lib $cell $view 1` and set
  `libmgr::status "opened $lib/$cell/$view read-only"`; update the comment
  (the "v0 viewer is already read-only" rationale is stale since item 03).
  No do_* proc added (keeps test_selflog_grep_guard's closure scan quiet).

### 3. src/ase_window.tcl — the seven dialogs
Common: build with dialog_frame/dialog_row/dialog_buttons where the shape
fits; `bind <Return>` on every entry = proceed; `ase::ui::apply_theme $w`
last; guard every entry proc with `if {![dict exists $wins $key]} return`.

**(a) Choose Analyses — `ase::ui::choose_analyses {key {type {}}}`**,
toplevel `$top.chana`, title `Choose Analyses`:
- top section frame `$top.chana.types`: radiobuttons `.op .dc .ac .tran`
  (labels op/dc/ac/tran) on variable `::ase::ui::dlg($key,antype)`; radio
  change → `ase::ui::chana_show $key` (repopulate bottom form from state —
  D4 discard semantics).
- bottom per-analysis form: Enable checkbutton `$top.chana.enable`
  (variable `dlg($key,anen)`) + quick-field entries at `$top.chana.<field>`
  (dc: source/start/stop/step; ac: points/start/stop; tran: step/stop; op:
  none — rebuild the field rows on type switch, deterministic names).
- `Options…` button `$top.chana.opts` → D5 extra-key editor (toplevel
  `$top.chana.x`: treeview or entry-pair rows name/value of the row's keys
  beyond type/enabled/quick fields; Add/Delete; OK merges back — minimal
  form OK, keep it small and modeless).
- OK (`$top.chana.btns.proceed` + Return): D6 validation, then edit the
  FIRST state row of the shown type — merge over the ORIGINAL row dict
  (preserve unknown keys), empty quick field deletes the key, non-empty sets
  it, `enabled` from the checkbutton; if no row of that type exists, append
  a fresh one; `session_update` + `populate` + destroy. Cancel destroys.
- preselect contract: `$type` {} → `op`; callers: menu Analyses>Choose…
  (no arg), strip `OP,TR` (no arg), ana ctx Add… (no arg), ana ctx Edit…
  (first selected row's type), `pane_dblclick` ana arm (that row's type).
  Multiple same-type rows: the dialog addresses the FIRST; extras remain
  X-deletable in the pane (document inline).

**(b) Setup > Design — `ase::ui::design_dialog {key}`**, toplevel
`$top.design`: ttk::comboboxes `$top.design.lib` / `.cell` / `.view`
(type-to-filter on KeyRelease per the copy_current_cell idiom, style
Ase.TCombobox). lib values = `libmgr::lib_names`; choosing lib fills cell
values = `xschem lib_cells $lib`; choosing cell fills view values with ONLY
schematic views: views of `xschem cell_views $lib $cell` whose
`xschem cellview_path $lib/$cell $v` ends in `.sch` (mirror
mkinst::symbol_views). Prefill from state `design`. OK validates all three
non-empty + view in the filtered list, writes
`dict set st design [list lib $l cell $c view $v]`, `session_update` +
`populate` (title/status react), destroy.

**(c) Setup > Model Files — `ase::ui::model_files_dialog {key}`**, toplevel
`$top.models`: themed treeview `$top.models.tv` columns {file section}
(headings File / Section), one row per `models` entry; ctx menu
`$top.models.ctx` Add… / Edit… / Delete (+ `bind $top.models.tv <Delete>`
→ same delete — D1 dialog-local); Add/Edit open row editor `$top.modrow`
(entries `.file` / `.section`, Return=proceed) merging over the original
row dict; every mutation commits immediately (D15). Close button.

**(d) Outputs > Save All — `ase::ui::save_all_dialog {key}`**, toplevel
`$top.saveall`: checkbuttons `.allv` ("Save all voltages") /
`.alli` ("Save all terminal currents") on `dlg($key,allv)`/`dlg($key,alli)`
prefilled from state; DISABLED entry `.levels` (D11, no state backing); OK
writes `save_all_v`/`save_all_i` (0/1), `session_update` + `populate`
(Save Options column reacts via save_options_cell), destroy.

**(e) Session > Load State — `ase::ui::load_state_dialog {key}`**, toplevel
`$top.loadst`, the mkinst 3-column browser shape: listboxes
`$top.loadst.pw.lib.lb` / `.cell.lb` / `.view.lb` (`-exportselection 0`),
View column lists ONLY simulation-state views (`cellview_path` → `.state`);
status label; OK `$top.loadst.b.ok` + Cancel. OK resolves the target state
file; if `ase::session_dirty $key` → `ase::ui::confirm` ("Discard unsaved
edits…?") gating `ase::ui::do_load_state_from $key $path`; else call it
directly. Worker (testable, no Tk beyond populate): `state_load $path` →
`session_update` → `populate` (D10).

**(f) Session > Save State — `ase::ui::save_state_dialog {key}`**, toplevel
`$top.saveas`: Library ttk::combobox `$top.saveas.lib` (type-to-filter,
values lib_names) + plain entries `.cell` / `.view`, ALL prefilled from the
session meta {lib cell view}; OK (`.btns.proceed` + Return):
`save_as_needs_confirm` (D8) → `ase::ui::confirm` gating
`ase::ui::do_save_state_as $key $l $c $v`, else call directly. Worker:
- target == own view → `ase::session_save $key` (clears dirty).
- target view missing → `library_new_view $l $c $v ngspice_state1` (catch →
  ciw_echo error, incl. the D9 nonexistent-cell case), then `ase::state_save
  [xschem cellview_path $l/$c $v] [ase::session_state $key]`.
- target = different existing view → plain `ase::state_save` overwrite (D13).
- on success: `catch {libmgr::refresh_after $l $c $v}` (headless-safe) +
  ciw_echo notice; destroy the dialog.

**(g) Simulation > Options — `ase::ui::sim_options_dialog {key}`**, toplevel
`$top.simopt`: same shape as (c) on state `options` — treeview
`$top.simopt.tv` columns {name value}, ctx Add…/Edit…/Delete + Delete key,
row editor `$top.optrow` (entries `.name` / `.value`), immediate commit
(D15). Note in a comment: render_deck semantics value 0=skip, 1=bare
`.options name`, else `name=value` (ase.tcl:556-565).

**(h) shared confirm — `ase::ui::confirm {key title msg oncmd}`**: modeless
toplevel `$top.confirm` (label `.msg` -font AseLabelFont + buttons
`.btns.proceed`/`.btns.cancel`, Return=proceed), destroys itself then
`uplevel #0 $oncmd` on proceed; themed; re-open replaces (catch destroy).

**(i) rewiring** (replace every stub listed in the anchors): Session menu
Load State → `load_state_dialog`, Save State → `save_state_dialog` (menu
LABELS unchanged); Setup menu → (b)/(c); Analyses > Choose… → (a); Outputs
> Save All… → (d); Simulation > Options… → (g); strip `OP,TR` → (a); strip
`-->` → `output_editor $key -1` (D3); ana ctx Add…/Edit… + `pane_dblclick`
ana arm → (a) with the D4/D6 preselect contract. Delete `todo_stub` ONLY if
no caller remains (item-08 stubs at :257-263 still use it — keep the proc).
Keep `ase::ui::save_state`/`load_state`/`revert_state` procs (workers/W7).
Update the file-top comment block for the new dialog layer.

### 4. Tests

**tests/headless/test_ase_core.tcl — new D5 block** (after D4, :216):
- `D5 save_all_v renders .save all` — nfet state + `dict set st save_all_v 1`
  → `regexp -line {^\.save all$}`.
- `D5 .save all precedes the per-output .save` — string-first ordering check.
- `D5 save_all_i renders .options savecurrents` — state WITHOUT the explicit
  savecurrents options row (`dict set st options {}` first) + save_all_i 1.
- `D5 blankets off leave no blanket lines` — default state: no `.save all`;
  options {} + save_all_i 0: no `.options savecurrents`.
D1 golden must remain byte-identical — do not touch it.

**tests/headless/test_ase_window.tcl — minimal update**: add a driver helper
`proc menu_save_state {top}` = invoke Session>Save State, wait for
`$top.saveas`, `$top.saveas.btns.proceed invoke`, wait for the dialog to
die; replace the seven `$top.mb.session invoke {Save State}` sites (:500,
:515, :531, :549, :579, :589, :656). Check NAMES stay identical (receipt
must justify this as the only change: the menu entry now opens the Save-As
dialog whose prefilled same-target OK is the old save). No other edits.

**tests/headless/test_ase_dialogs.tcl — NEW, auto-discovered.** Skeleton =
test_ase_window.tcl: check/check_true, `main_ready`-free (no main-window
legs needed), `send_return` + tv helpers copied verbatim (origin comment),
scratch fixture `_ase_dialogs_[pid]` with the same aselib/nfet_clean +
library.defs + `library_new_view … ngspice_state1` seeding (:175-239
pattern), cleanup + `RESULT: ALL PASS (N checks)` / `RESULT: n FAILED`
trailer, whole body in the `catch {…} bigerr` harness. GUI legs behind the
`::has_x && winfo` guard, banner `gui legs skipped (no DISPLAY)` (audit
counts the headless legs as the PASS body — headless legs must run first,
exactly like test_ase_window).

Headless legs:
- `H1 ro-open sets the session readonly attr` — `ase::open_state … 1` →
  getattr readonly == 1; `H1 plain reopen clears it` → open_state (3-arg) →
  0.
- `H2 needs_confirm: readonly + same target` — setattr readonly 1 →
  save_as_needs_confirm same-lcv == 1; `H2 plain same target` == 0;
  `H2 unwritable file same target` — `file attributes $spath -permissions
  0444` → 1 (restore 0644 after); `H2 different target` == 0 even readonly.
- `H3 do_save_state_as creates a new view dir` — worker to view
  `ngspice_state2` → `cellview_path` resolves, `cell_views` lists it, file
  content == `[ase::state_serialize [ase::session_state $key]]\n`.
- `H4 do_load_state_from imports content + dirty` — edit the state2 file
  (different Vgs), worker → session variables match state2, session_dirty 1.
GUI legs (each dialog: opens + round-trips its state key):
- `G1 menu Choose Analyses opens the dialog` ($top.chana exists);
  `G1 OP,TR strip opens Choose Analyses`; `G1 dbl-click dc row preselects
  dc` (tv_dblclick row 1 of ana pane → `dlg($key,antype)` eq dc).
- `G2 Choose Analyses round-trips dc quick fields` — set source V2, start 0,
  stop 1.8, step 0.01, Enable on, proceed (send_return on a field with a
  state-observing done-condition, or `.btns.proceed invoke` — rejection legs
  MUST use button invoke, see LANDMINE 4) → state dc row enabled 1 + fields;
  `G2 Arguments summary shows the fields` (pane cell). `G2b enabled tran
  with blank step rejected` — dialog survives, state unchanged (button
  invoke, delivery witness proven by G2).
- `G3 Setup Design opens + view list filtered to schematic views` —
  `$top.design.view` values == {schematic} for nfet_clean (which also HAS
  ngspice_state* views — the filter proof); `G3 design round-trips` — OK →
  state design view schematic, title still `Analog Sim Environment
  nfet_clean`.
- `G4 Model Files lists the state models`; `G4 add round-trips` (ctx or
  direct row-editor path → models grew with {file … section tt2});
  `G4 delete removes the row` (Delete key or ctx Delete).
- `G5 Save All writes save_all_i` — toggle alli, OK → state 1;
  `G5 Save Options column reacts` (outs pane saveopts cell of the id row eq
  alli); `G5 deck gains .options savecurrents` (call the render hook
  directly on the session state); `G5 levels entry disabled`.
- `G6 Sim Options round-trips a name/value row` (add → state options
  contains it; delete leg optional but preferred).
- `G7 Save-As dialog prefilled with current lcv`; `G7 Save-As creates a new
  view dir` (edit view → ngspice_state3, proceed → dir + file + cell_views);
  `G7 same-target OK saves clean` (dirty the session, proceed with prefill →
  session_dirty 0).
- `G8 read-only same-target confirm path` — setattr readonly 1, open
  Save-As, proceed → `$top.confirm` exists AND the file is not yet written
  (mtime/content probe); `.btns.proceed invoke` on the confirm → written +
  clean; then setattr readonly 0.
- `G9 Load State browser filtered to state views` — view column of
  nfet_clean lists only ngspice_state* entries (no schematic);
  `G9 load imports + dirty` (pick the differing state2 → variables changed,
  dirty 1, panes repopulated); `G9 dirty prompt appears first` (dirty
  session → OK → `$top.confirm`; proceed → loaded).
- `G10 --> strip opens the Add Output dialog` — `$top.strip.out invoke` →
  `$top.edout` exists, `wm title` == `Add Output`.
- `G11 no item-07 todo stubs remain` — for each rewired menu entry, its
  `-command` (entrycget) does not contain `todo_stub` (item-08 Outputs
  Select-On-Design entries excluded).

Run commands (repo root; the build is `cd src && make`):
- headless: `env -u DISPLAY ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl`
- GUI: `./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl`
- same for test_ase_core / test_ase_window; then `tests/headless/full_audit.sh`
  (compare against the PLAN.md baseline fail list — LIST EQUALITY; the known
  WSLg rerun-first flakes per the item brief; test_ase_* must PASS).
Protected: test_ase_view.tcl + test_ase_final.tcl — do not edit, re-run both.

## Landmines (from receipts 05/06 — violations WILL be caught by verifiers)

1. **NO new schema_keys** — any state-schema key addition forces
   re-canonicalizing the committed test_nfet_final `.state` fixture
   (protected test_ase_final F3 byte-identity). Item 07 needs none (D11).
   If you believe you need one, you have mis-read a deliverable — re-read.
2. Bare `open` inside `namespace eval ase::ui` resolves to `ase::ui::open`
   — file reads/writes in ui procs must use `::open`.
3. Never route values that get string-compared through `expr` ternaries
   (numeric normalization: 4.096837e-04 → 0.0004096837).
4. WSLg generated-event discipline: every generated `<Return>` goes through
   `send_return` with a product-side done-condition; rejection legs drive
   the OK button (`invoke`) — a dropped Return makes a negative check
   hollow-green. Generated same-spot double clicks: two press/release pairs
   (tv_dblclick); two SINGLE clicks need a >5px offset.
5. Menu labels asserted by W1m (`{Design Window} {Load State} {Save State}
   -- Close`, cascade order, disabled states) must not change.
6. `ciw_echo` only under catch (headless has no CIW); user-facing messages
   via ciw_echo, never puts/statusbar.
7. TIP-278: `variable` declarations / absolute names in every new proc;
   listboxes `-exportselection 0`; unicode as `\uXXXX` escapes (files stay
   ASCII); C89 rules do not apply (pure Tcl item), Windows: no new
   subprocess paths are added.
8. The shared `textwindow` stays stock-Tk (item-05 carve-out) — do not
   theme it.

## Sabotage plan (run post-commit; each must fail EXACTLY its target)

- S1: delete the `save_all_v` → `.save all` emission in
  `ase::backend::ngspice::render_deck` (src/ase.tcl) → test_ase_core
  `D5 save_all_v renders .save all` + ordering leg FAIL (headless run);
  test_ase_dialogs G5 deck leg unaffected (it targets alli) — everything
  else green.
- S2: make `ase::ui::do_save_state_as` skip the `library_new_view` arm
  (write only when the view already resolves) → exactly
  `H3 do_save_state_as creates a new view dir` + `G7 Save-As creates a new
  view dir` FAIL.
- S3: drop the `session_update` commit from the Choose Analyses OK path →
  exactly the `G2` round-trip legs (state + Arguments summary) FAIL; G1
  open/preselect legs stay green.
Protocol: `git diff` confirms the file holds nothing but the sabotage →
run → targeted `git checkout -- <file>` → clean re-run green. Record the
table (sabotage | target | observed fail count) for the receipt.

## Commit

ONE commit, staged file list EXACTLY:
- src/ase.tcl
- src/ase_window.tcl
- src/library_manager.tcl
- tests/headless/test_ase_core.tcl
- tests/headless/test_ase_window.tcl
- tests/headless/test_ase_dialogs.tcl   (new)
No state-fixture change (no schema change → no ripple). NEVER stage the
pre-batch dirty files: doc/claude/specs/sky130_workarea.md,
sky130A/xschem_libs/library.defs, src/ciw.tcl,
tests/headless/test_sky130a_libmgr.tcl, tests/run_regression.tcl,
xschem_libs_newsym/SANDBOX/… (both). Message shape:
`feat(ase): ADE-L v2 dialogs — Choose Analyses, Design/Model Files,
Save All, Load/Save State, Sim Options` + prose body + the repo's
Co-Authored-By trailer.

## RUNBOOK policy block (verbatim from doc/claude/ase_l_batch/RUNBOOK.md)

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

## Definition of done

1. All nine stub sites rewired to real dialogs; `grep -n "TODO(item07)"
   src/*.tcl` returns nothing.
2. test_ase_dialogs.tcl green headless AND under DISPLAY; test_ase_core +
   test_ase_window green (core headless, window under DISPLAY);
   test_ase_view + test_ase_final untouched and green.
3. full_audit.sh fails are a subset of the PLAN.md baseline (rerun-first for
   the known WSLg flakes).
4. 3 sabotages executed per protocol, table recorded.
5. ONE commit with exactly the six files above.
