# Item 06 panes-strip — implementation prompt (ROUND 2, UI v2 / ADE-L parity)

Scout verdict: PROCEED (anchors re-verified from source 2026-07-21; no
spec/code contradiction found).

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. You are
the IMPLEMENTER: execute this prompt end-to-end — code, tests,
sabotage-verify, ONE commit with the explicit file list in section 10. Do not
start item 07/08 work (Choose Analyses / Setup / Save All / Load-Save-State
dialogs, Select On Design): those stay `TODO(item07)`/`TODO(item08)` stubs.

## 1. Mission

Replace the v1 pane grid of the ASE-L session window with the ADE-L v2 pane
model (spec `doc/claude/specs/ase_l.md`, sections "Panes" :178-192 and
"Action strip" :194-205 — AUTHORITATIVE): exactly 3 panes (Design Variables,
Analyses, Outputs) as themed column tables, NO inline +/- buttons, row
multi-select within one pane, per-pane context menus, double-click row
editors (variables + outputs land NOW), the right vertical action strip, the
Outputs Value column filled after a successful run, Save Options auto-cells
backed by new state keys `save_all_v`/`save_all_i`. Item-05 chrome
(title/toolbar-temp/status bar/palette/fonts/menu-tree/log toplevel, commit
6230ca56) must not regress; neither may the run pipeline (W5-W7 flows).

Read first, in order:
1. `doc/claude/ase_l_batch/RUNBOOK.md` (policies — copied verbatim in §11)
2. `doc/claude/specs/ase_l.md` :155-247 (whole UI v2 section; Panes :178-192,
   Action strip :194-205, Menu tree :207-231, Dialog style :244-247)
3. `doc/claude/ase_l_batch/receipts/05_ui-shell.md` (what v2 chrome shipped;
   note the "Corrected/confirmed anchors worth keeping" list — the WSLg raise
   idiom, `::open` shadowing inside `ase::ui`, and the protected-fixture
   byte-identity ripple all apply to THIS item)
4. `references/copy_current_cell_dialog.tcl` (dialog idioms: named fonts,
   `catch {destroy $w}` reuse, Return=proceed :127-131, per-window state
   arrays cleaned in the cancel proc :238-244; the dialog is MODELESS — no
   grab/tkwait — which is what makes it test-drivable; copy that)
5. `src/ase_window.tcl` (1046 lines) + `src/ase.tcl` (638 lines) in full

## 2. Corrected anchors (re-verified from source 2026-07-21)

| Anchor | True location |
|---|---|
| spec "Panes (ONLY these three)" | doc/claude/specs/ase_l.md:178-192 |
| spec "Action strip" | ase_l.md:194-205 |
| spec "Menu tree (v2)" (Variables > Edit…) | ase_l.md:207-231 (:219) |
| spec "Dialog style" | ase_l.md:244-247 |
| `ase::ui` namespace vars (panes dict :67-71, anaargs :64-65, rowbase/rowchk/lastrow/anaen :59-62) | src/ase_window.tcl:42-72 |
| `ase::theme` / `ase::ui::apply_theme` | src/ase_window.tcl:81-97 / :103-127 |
| `ase::ui::open` / `close` (per-key array cleanup :180-183) | src/ase_window.tcl:140-158 / :164-185 |
| `ase::ui::build` (v1 2x3 pane grid to REPLACE :320-338; Variables Edit… item-06 stub :232-236; toolbar :289-298; status bar :300-318) | src/ase_window.tcl:189-344 |
| v1 pane machinery to REMOVE: `build_list_pane` (+/- buttons :352-356), `build_ana_pane`, `build_setup_pane`, `row_indices`/`row_build`/`row_add`/`row_del`, `variable_entry` | src/ase_window.tcl:346-357 / :359-376 / :378-389 / :391-459 / :462-470 |
| v1 populate/harvest to REWORK: `populate_list_pane`/`harvest_list_pane`/`populate_ana`/`harvest_ana`/`populate`/`harvest`/`commit`/`temp_commit` | src/ase_window.tcl:474-488 / :490-517 / :519-548 / :550-571 / :573-591 / :595-612 / :615-620 / :624-637 |
| `refresh_title`/`refresh_status`/`status_text`/`session_changed` (keep) | src/ase_window.tcl:655-663 / :667-678 / :682-692 / :697-700 |
| `todo_stub` | src/ase_window.tcl:718-720 |
| `set_status` / log machinery (keep) | src/ase_window.tcl:792-805 / :810-934 |
| `run_finished` (Value-fill hook site) / `run_started` / `do_run` / `do_run_existing` / `do_stop` | src/ase_window.tcl:951-965 / :969-975 / :978-1002 / :1007-1014 / :1021-1033 |
| `ase::schema_keys` / `ase::state_default` | src/ase.tcl:26-27 / :65-78 |
| `ase::state_serialize` (emits only present keys, canonical order) | src/ase.tcl:105-121 |
| session model; `session_setattr`/`getattr` (reserved names path/state/saved only) | src/ase.tcl:362-486 (:476-486) |
| `ase::last_result` / `ase::run_done` (results parse :329-333, callback at #0 :338) | src/ase.tcl:356-360 / :319-339 |
| `ase::backend::ngspice::result_probe` (name-skip line :620 = the extension point) | src/ase.tcl:617-628 |
| `render_deck` (reads only known keys — save_all deck mapping is item 07, DO NOT touch) | src/ase.tcl:537-597 |
| ttk::treeview precedent (per-row font tags; `-columns … -show headings`; `<<TreeviewSelect>>` suppress-flag idiom) | src/library_manager.tcl:94-135 (:101, :133-135) / :757 |
| test_ase_view G1 double-click idiom (Tk REFUSES `event generate <Double-1>` — replay two press/release pairs at the row bbox) | tests/headless/test_ase_view.tcl:166-187 |
| test_ase_view contracts this item must keep: `ase::ui::window_for`, `ase::ui::close` | tests/headless/test_ase_view.tcl:26-33, :188, :201 |
| test_ase_core R1 (11→13 keys) / D1 golden deck / D4 temp legs | tests/headless/test_ase_core.tcl:88-100 / :146-183 / :199-214 |
| test_ase_window legs to REWORK: W1 pane/entry checks :229-241, W3 (variable_entry + Return) :288-309, W3t :311-347, W6 :405-430, W7 revert :467-495 | tests/headless/test_ase_window.tcl |
| test_ase_final F3 byte-identity of the committed fixture (PROTECTED — do not edit the test; re-canonicalize the FIXTURE) | tests/headless/test_ase_final.tcl:75-79 |
| committed state fixture (11 lines, gains `save_all_v 0` + `save_all_i 0`) | sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state |
| ase.tcl/ase_window.tcl source site + ship listing (NO changes needed) | src/xschem.tcl:14106-14108; src/Makefile.in:22 |

`ase_window.tcl` is sourced UNCONDITIONALLY (xschem.tcl:14106-14108), so pure
procs defined there are callable headless — design the classification/format
helpers (D6-D8 below) Tk-free so headless checks can drive them directly.

## 3. Scout decisions (each binding; one-line justification)

D1 **Pane widget = ttk::treeview** (`-show headings -selectmode extended`),
one per pane: native columns/headings, native row multi-select, item-id
addressing for double-click/checkbox cells — the in-repo precedent is
library_manager.tcl:101/:757, and hand-rolled entry-grid selection would
re-implement all of that badly. Rows are NOT edited inline (spec: dialogs);
the treeview is a pure VIEW of the session state.

D2 **Harvest model dies for panes**: every pane mutation (checkbox toggle,
dialog OK, delete) directly mutates the session dict (`ase::session_state` →
edit → `ase::session_update`) and repopulates the affected pane; the v1
harvest/rowbase machinery (ase_window.tcl:391-571, :595-620) is REMOVED —
treeviews have nothing to harvest, and dialogs merge their fields over the
row's ORIGINAL dict (`dict set`/`dict merge` on the original row) so unknown
per-row keys are preserved exactly as rowbase used to. `temp_commit` is
reworked to `dict set st temperature $v` + `session_update` directly (the
whole-window `harvest` proc goes away). Toolbar/status/title machinery
untouched.

D3 **Only 3 panes; models/options/setup panes REMOVED**: spec :178 says ONLY
these three; models editing = Setup > Model Files (item-07 stub), options =
Simulation > Options… (item-07 stub), rundir/simulator stay state-only until
item 07 (simulator already shows in the status bar). Layout: `$top.body`
grid — col 0 `$top.body.vars` (labelframe `Design Variables`, rowspan 2),
col 1 `$top.body.ana` (labelframe `Analyses`) over `$top.body.outs`
(labelframe `Outputs`); keep labelframes (the dark-red accent title checks
target them). Trees at `$top.body.vars.tv`, `$top.body.ana.tv`,
`$top.body.outs.tv` (deterministic names for tests) + vertical scrollbars.

D4 **Columns**: variables `-columns {name value}` headings Name/Value;
analyses `-columns {num type enable args}` headings #/Type/Enable/Arguments
(num = 1-based row number, the spec's "row-numbered"); outputs
`-columns {name value plot save saveopts}` headings
Name/Value/Plot/Save/{Save Options}. Item ids = the row's 0-based index into
the state list (`$tv insert {} end -id $i -values …`) — deterministic
row→state addressing for toggles/editors/deletes; repopulate after every
mutation keeps ids dense.

D5 **Checkbox cells = unicode glyphs** `☑` (checked) / `☐`
(unchecked) written as backslash-u escapes (file stays ASCII, the D14
idiom from item 05): a `<Button-1>` binding resolves `identify column/row`,
and a click on an Enable/Plot/Save cell flips the flag in the row's state
dict (`dict set row enabled|plot|save 0/1`, preserving all other keys) +
`session_update` + repopulate — real ttk checkbuttons cannot live in
treeview cells, and glyph cells are the standard Tk answer; string-compare
tests stay deterministic even if WSLg renders tofu.

D6 **Outputs Name cell** (spec :186-188): pure helper
`ase::ui::output_display_name {row}` → `name` if present and non-empty, else
`expr` truncated deterministically: whole expr when ≤ 24 chars, else first
21 chars + `...` (ASCII dots) — "as much as fits" needs a fixed testable
rule, and column autosizing is not deterministic across DPI.

D7 **Save Options cell** (spec :188): pure helpers
`ase::ui::output_kind {expr}` → `voltage` (expr, after stripping leading
whitespace/`-`, matches case-insensitive `v(`), `current` (`i(` or `@` —
ngspice terminal-current form), else `other`; and
`ase::ui::save_options_cell {state row}` → `allv` iff kind==voltage and
`save_all_v`==1, `alli` iff kind==current and `save_all_i`==1, else `{}` —
the smallest classifier the spec's two auto-cells need; anything smarter is
item-07 Save All territory.

D8 **Analyses Arguments summary**: pure helper `ase::ui::arg_summary {row}` →
the row's args in `anaargs` order (dc: source start stop step; ac: points
start stop dec; tran: step stop) as `key=value` joined by single spaces
(e.g. `source=V2 start=0 stop=1.8 step=0.01`), unknown extra keys appended
in dict order; enabled/type excluded — one deterministic line, view-only per
spec. Keep the `anaargs` dict; the analyses pane shows the state's
`analyses` list VERBATIM (state_default seeds op/dc/ac/tran, so 4 rows
out of the box); deleted analysis rows are really removed from the list
(render_deck copes — it iterates whatever entries exist; Choose Analyses
re-adds in item 07).

D9 **State keys `save_all_v`/`save_all_i`** (defaults 0) land in
`ase::schema_keys` after `outputs` (before `options`) and in
`state_default` — they modify output-saving semantics so they group with
outputs; item 07's Save All dialog will write them, item 06 only displays
their effect. NO render_deck change (deck mapping allv→`.save all`,
alli→`.options savecurrents` is explicitly item 07 per PLAN.md).
**RIPPLE (mandatory, same as item 05's [b])**: `state_load` merges over the
new defaults, so protected test_ase_final F3's load→save byte-identity
breaks unless the committed fixture
`sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state`
is re-canonicalized in the SAME commit — insert lines `save_all_v 0` and
`save_all_i 0` between the `outputs …` and `options …` lines (exactly what
a fresh `ase::state_save` writes; verify by round-tripping before you
commit). test_ase_view V3/V4 are safe (both compare sides use the new saver
at runtime). NEVER edit test_ase_final.tcl or test_ase_view.tcl.

D10 **result_probe extension** (per-output scalars for unnamed outputs):
src/ase.tcl:620 currently skips outputs without `name`; change to skip only
when `expr` is missing, and key the results dict by `name` when present and
non-empty, else by `expr` — backward compatible (test_ase_final F10 reads
key `id`), and the v2 Outputs pane needs a value for unnamed rows.

D11 **Value column fill** (spec :183-185, USER-LOCKED): per-SESSION, not
global — `run_finished` (ase_window.tcl:951) additionally stores
`ase::session_setattr $key results [ase::last_result]` and calls the new
`ase::ui::refresh_output_values $key`; `populate`'s outputs pass fills Value
from the session `results` attr (row lookup: name if named else expr),
blank when the attr is absent/has no entry — a global last_result would
bleed session A's numbers into session B, and storing per session keeps
"blank pre-run" true across repopulates. Values are display-only (never
serialized to the state file).

D12 **Selection model** (spec :189-192): all trees `-selectmode extended`;
one `<<TreeviewSelect>>` handler per tree clears the OTHER two panes'
selections, guarded by a `selclear` suppress flag (the
libmgr::suppress_select idiom, library_manager.tcl:133-135) and a
`[$tv selection] ne {}` test — clearing an empty selection re-fires nothing,
so the flag+test pair kills the recursion. The strip `X` /
`ase::ui::delete_selection {key}` SCANS the three trees for the non-empty
selection (stateless — no last-focused bookkeeping to corrupt), deletes
those indices from the pane's state list in DESCENDING order, commits,
repopulates; no confirm dialog anywhere in the path; empty selection →
`ciw_echo "ase: nothing selected"`.

D13 **Context menus**: one `menu $top.body.<pane>.ctx -tearoff 0` per pane
with exactly Add… / Edit… / Delete; `<Button-3>` on the tree does
`tk_popup` at the pointer. Wiring — variables: Add…=`add_variable_dialog`,
Edit…=variable editor on the FIRST selected row, Delete=`delete_selection`;
outputs: Add…=output editor with blank prefill, Edit…=output editor on
first selected, Delete=`delete_selection`; analyses: Add…/Edit… =
`todo_stub {Choose Analyses} 07` (comment: `TODO(item07)` route with the
row preselected), Delete=`delete_selection` (real). Menus are checkable by
entrycget without posting — tests never post them.

D14 **Double-click** (spec :190-191): `bind $tv <Double-1>` (binding is
legal; only event GENERATE of `<Double-1>` is refused — tests replay two
press/release pairs, the test_ase_view G1 idiom). Variables → per-row
editor dialog (name/value); outputs → per-row editor (name/expr/plot/save);
analyses → `todo_stub {Choose Analyses} 07` (`TODO(item07)`: preselect the
double-clicked analysis when 07 lands).

D15 **Dialogs** (all follow references/copy_current_cell_dialog.tcl +
`ase::theme`): MODELESS toplevels, children of the session window,
deterministic names `$top.addvar` / `$top.edvar` / `$top.edout`;
`catch {destroy $w}` before create (reuse); labels AseLabelFont, entries
AseEntryFont white, `apply_theme` on the dialog; buttons
`$w.btns.proceed` (`OK`) / `$w.btns.cancel`; `<Return>` on every entry =
proceed; the row index being edited lives in a namespace array
(`edrow($key)` style) cleaned on proceed/cancel AND in `ase::ui::close`.
Fields — addvar: `.name` `.value` entries (blank); proceed: name must be
non-empty and NOT already a variable name (else `ciw_echo … error`, dialog
stays up) → append `{name N value V}` to `variables`, commit, repopulate,
destroy. edvar: same fields prefilled; proceed merges name/value over the
ORIGINAL row dict. edout: `.name` `.expr` entries + `.plot` `.save`
checkbuttons; expr must be non-empty; proceed merges name/expr/plot/save
over the original row (blank name = unnamed output — allowed); blank-prefill
variant doubles as outputs Add…. File I/O inside `ase::ui` must use
`::open` (item-05 lesson: bare `open` is shadowed by `ase::ui::open`).

D16 **Action strip**: `frame $top.strip` packed `-side right -fill y`
(after toolbar+status are packed, before `$top.body` — the item-05 packing
lesson), buttons stacked top-down with deterministic names and TEXT labels
(spec offers unicode ▶ ■ as optional; text placeholders are what the spec
line :194 actually specifies and they are ASCII-deterministic for tests):
`$top.strip.ana` `OP,TR` → `todo_stub {Choose Analyses} 07`;
`$top.strip.var` `=` → `add_variable_dialog` (lands NOW);
`$top.strip.out` `-->` → `todo_stub {Setup Outputs} 07`;
`$top.strip.del` `X` → `delete_selection`;
`$top.strip.netrun` `N&>` → `do_run`;
`$top.strip.run` `>` → `do_run_existing`;
`$top.strip.stop` `!` → `do_stop`;
`$top.strip.plot` `~` → `-state disabled` (deferred placeholder).

D17 **Variables > Edit… menu entry** (item-06 TODO at ase_window.tcl:232-236)
is wired NOW: variable editor on the first selected variables row, or the
Add Variable dialog when nothing is selected — the honest minimal reading of
spec :219 within this item's scope (the full ADE variables editor is not
specced anywhere). All other menu stubs stay as item 05 left them.

D18 **Theme for treeviews**: `ase::theme` additionally configures (once)
`ttk::style configure Ase.Treeview -font AseEntryFont -background #ffffff
-fieldbackground #ffffff -rowheight [expr {[font metrics AseEntryFont
-linespace] + 4}]` and `Ase.Treeview.Heading -font AseLabelFont -background
#e8e8e8` (the USER-LOCKED header-strip color finally gets a real header
strip); trees are created with `-style Ase.Treeview`; `apply_theme` gains a
`Treeview` class branch that (re)applies `-style Ase.Treeview` — style-based
because ttk widgets ignore `-background`/`-font` configure.

D19 **Contract removals**: `ase::ui::variable_entry` is DELETED (its only
consumers are the two test_ase_window sites being reworked — verified by
grep); the `panes`/`rowbase`/`rowchk`/`lastrow`/`anaen` namespace vars are
replaced by the new bookkeeping (whatever you add — selclear flag, edrow —
must be cleaned per-key in `ase::ui::close`, extending :180-183).
`window_for`, `close`, `open_state`, `status_text`, `set_status`,
`revert_state`, `log_*`, `do_*` keep their names/signatures (test_ase_view
G-legs + test_ase_window use them).

## 4. Deliverables — src/ase.tcl

1. `save_all_v` + `save_all_i` in `schema_keys` (after `outputs`) and
   `state_default` (both 0) per D9.
2. `result_probe` unnamed-output keying per D10 (skip only when `expr`
   missing; key = non-empty `name` else `expr`).
3. Nothing else — state I/O, session model, run pipeline, render_deck are
   stable contracts (deck mapping of save_all_* is item 07).

## 5. Deliverables — src/ase_window.tcl

1. Pane rework per D1-D5, D8, D18: 3 treeview panes, v1 pane machinery
   removed (build_list_pane/build_ana_pane/build_setup_pane, row_*,
   variable_entry, populate_list_pane/harvest_list_pane/populate_ana/
   harvest_ana, harvest, commit), `populate` reworked to fill the trees +
   toolbar temp + title/status, `temp_commit` per D2. NO inline +/- buttons
   anywhere.
2. Value column per D11 (`refresh_output_values`, session `results` attr,
   run_finished hook); Name + Save Options cells per D6/D7 (pure helpers
   `output_display_name`, `output_kind`, `save_options_cell`, `arg_summary`
   — Tk-free, headless-callable).
3. Selection model + `delete_selection` per D12; context menus per D13;
   double-click editors per D14; dialogs per D15; action strip per D16;
   Variables > Edit… per D17.
4. `close` cleans every new per-key record per D19.

## 6. Deliverables — committed fixture

Re-canonicalize
`sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state`
per D9 (insert `save_all_v 0` + `save_all_i 0` between `outputs` and
`options`; verify byte-identity against a fresh `state_load`→`state_save`
round trip before committing).

## 7. Tests (justify every assertion change in the receipt)

### tests/headless/test_ase_core.tcl
- R1: "R1 default has exactly the 13 schema keys" (list gains
  save_all_v/save_all_i) + NEW "R1 save_all_v and save_all_i default 0".
- NEW result_probe leg (place after D4): synthetic logtext
  `-i(v1) = 4.096837e-04` + a state whose outputs = `{{expr -i(v1) save 1}}`
  (NO name) → "P1 result_probe keys unnamed outputs by expr"; named output
  still keyed by name → "P1 named output still keyed by name".
- Everything else untouched (R2/R4 byte-stability: both sides use the new
  saver; D1 golden deck unaffected — render_deck unchanged).

### tests/headless/test_ase_window.tcl
Headless additions (pure helpers, run without DISPLAY):
- "P2 output_display_name prefers the user name" (`{name id expr -i(v1)}` →
  `id`); "P2 unnamed short expr shown whole"; "P2 unnamed long expr
  truncated to 21+..." (feed a >24-char expr, assert length 24 + `...`
  suffix).
- "P3 output_kind v(net) -> voltage", "P3 output_kind -i(v1) -> current",
  "P3 save_options_cell voltage+save_all_v -> allv", "P3 current+save_all_i
  -> alli", "P3 blanket off -> blank".
- "P4 arg_summary dc row" (`{type dc enabled 0 source V2 start 0 stop 1.8
  step 0.01}` → `source=V2 start=0 stop=1.8 step=0.01`).
GUI legs (same fixture/DISPLAY-guard structure; W1/W3 REWORKED because the
v1 entry-grid widgets they asserted no longer exist — that is the justified
v2 change; keep W1 chrome/title/theme checks, W1m, W2, W3t, W4, W5, W8 as
they are, only re-anchoring what points at dead widgets):
- W1p (new pane leg): "W1p exactly the three v2 panes" (vars/ana/outs
  labelframes exist, `$top.body.mods`/`.opts`/`.setup` do NOT);
  "W1p no inline add/del buttons" (no `*.btns.add` anywhere under $top.body);
  "W1p variables columns" (`$top.body.vars.tv cget -columns` = `name value`);
  "W1p analyses columns" (= `num type enable args`); "W1p outputs columns"
  (= `name value plot save saveopts`); "W1p analyses rows numbered 1..4"
  (num cells of the 4 seeded analyses); "W1p Vgs row shows 1.8";
  "W1p id output row Value blank pre-run"; "W1p id Save Options blank while
  blankets off"; "W1p treeview themed" (style Ase.Treeview + heading style
  exists).
- W1s (strip): "W1s strip buttons in order" (children of `$top.strip` →
  labels `OP,TR = --> X N&> > ! ~`); "W1s plot placeholder disabled".
- W1c (context menus): each pane's ctx menu entries = `Add… Edit… Delete`
  (entrycget, no posting).
- W3 rework (dialog editing replaces the dead inline-entry leg): replay
  double-click on the Vgs row (two press/release pairs at the row bbox —
  test_ase_view G1 idiom) → "W3 double-click opens the variable editor"
  (`$top.edvar` exists); "W3 editor prefilled" (name entry `Vgs`, value
  `1.8`); set value 2.2, `event generate … <Return>` → "W3 commit dirties
  the session", "W3 tree shows 2.2"; menu Save State → file contains
  `{name Vgs value 2.2}` (keep the existing named check); then edit BACK to
  1.8 + Save (restores the fixture for the run legs — W6's Value assertion
  needs Vgs=1.8).
- W3s (selection): select the Vgs row, then a row in outputs → "W3s
  selecting in outputs clears the variables selection".
- W3c (checkbox): real `<Button-1>` at the dc row's Enable cell bbox
  (`$tv bbox <item> enable`) → "W3c click toggles dc enabled in state" (=1);
  Save State → "W3c save persists the toggle" (file match); click again +
  Save → restored (op-only for the run legs).
- W3v (add-variable round trip): `$top.strip.var invoke` → "W3v = opens the
  Add Variable dialog"; fill name `tmpA` value `0.5`, Return → "W3v tmpA in
  the tree", "W3v tmpA in the session state"; repeat for `tmpB`; duplicate
  add of `tmpA` → "W3v duplicate name rejected" (state unchanged, dialog
  still up → cancel it).
- W3x (X deletes multi-selection): `$tv selection set` on the tmpA+tmpB
  items, `$top.strip.del invoke` → "W3x X removed both rows from the state",
  "W3x survivors intact" (Vgs+Vds remain); Save State (fixture back to
  canonical); "W3x X with empty selection is a clean no-op".
- W3o (Save Options reacts): `dict set st save_all_i 1` via session_update +
  `ase::ui::populate` → "W3o id row Save Options shows alli"; unset back
  to 0 + repopulate → blank again.
- W6 (run leg additions, after the existing checks): "W6 id row Value
  filled after run" — read the id row's value cell, parse as double,
  `abs($v*1e6 - 409.68) < 1.0` (the F10 idiom; Vgs restored to 1.8 by W3).
- W7: replace the `ase::ui::revert_state` tail (kept proc) usage as-is; only
  re-anchor if a dead widget is referenced (scout found none — W7 touches
  session procs + status only).
DO NOT touch tests/run_regression.tcl (pre-batch dirty; full_audit
auto-discovers). DO NOT edit test_ase_view.tcl / test_ase_final.tcl
(protected; D9 keeps them green via the fixture re-canonicalization).

## 8. Sabotage plan (≥2 required; run all three)

Commit first, then per sabotage: apply, run, confirm EXACTLY the target
check(s) fail, `git diff` the file to confirm it holds nothing but the
sabotage, targeted `git checkout -- <file>`, clean re-run green.

- S1 (src/ase_window.tcl): in `delete_selection`, drop the
  `ase::session_update` commit (delete still repopulates) → fails EXACTLY
  the W3x state checks ("W3x X removed both rows from the state" + its
  survivor sibling if it asserts absence via state); every other leg green.
- S2 (src/ase_window.tcl): make `refresh_output_values` a no-op (or remove
  its run_finished call) → fails EXACTLY "W6 id row Value filled after run"
  (log/status/deck checks stay green — proves the Value fill is real, not a
  side effect of the run).
- S3 (src/ase_window.tcl): make `save_options_cell` always return `{}` →
  fails EXACTLY "P3 … -> allv", "P3 … -> alli" (headless) + "W3o id row
  Save Options shows alli" (GUI); the "blank" checks stay green.

## 9. Audit

Run `tests/headless/full_audit.sh` (DISPLAY=WSLg). Tolerated fails = EXACTLY
this baseline list (LIST EQUALITY; SKIPs fine; any NEW fail blocks):
FAIL: test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
test_cadence_window_hop_log, test_ciw, test_crossview_paste,
test_fluid_editing, test_hi_descend, test_launch_context,
test_lib_manager_gui, test_lib_sweep, test_palette, test_phase3_mints,
test_pin_type_edit, test_reopen_readonly, test_select_at,
test_selflog_output, test_verb_noun_copy_move, test_wire_split,
test_wire_vertex_grab. TIMEOUT: test_key_graph_context.
Known WSLg flakes that are NOT regressions if they pass on a direct re-run:
test_deselect_mode, test_hover_highlight (also test_close_window_restores_
prev_tab flaked once in item 05 — rerun-first). test_ase_core /
test_ase_view / test_ase_window / test_ase_final are NOT baseline fails and
must PASS.

## 10. Commit (ONE)

Stage EXACTLY these five files (explicit `git add` of each path, nothing
else):
- `src/ase.tcl`
- `src/ase_window.tcl`
- `tests/headless/test_ase_core.tcl`
- `tests/headless/test_ase_window.tcl`
- `sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state`

No Makefile/xschem.tcl changes are needed (§2 last row). NEVER stage the
pre-batch dirty tracked files: `doc/claude/specs/sky130_workarea.md`,
`sky130A/xschem_libs/library.defs`, `src/ciw.tcl`,
`tests/headless/test_sky130a_libmgr.tcl`, `tests/run_regression.tcl`,
`xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym`,
`xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`
— nor any `_nhangle_*`/`_allm_*`/junk dirs, nor generated files
(src/Makefile, src/xschem_subcommands.txt). Message: normal prose, e.g.
`feat(ase): ADE-L v2 panes + action strip — 3 treeview panes, row editors,
X delete, Value fill after run`, with the repo's Co-Authored-By trailer.

## 11. RUNBOOK policy block (verbatim, non-negotiable)

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

## 12. Receipt notes for the ledger

Record: every assertion change/removal in test_ase_core/test_ase_window with
its justification (§7 gives them — the W1/W3 rework is driven by the v1
widgets ceasing to exist per spec); the D9 fixture re-canonicalization (5th
file, the item-05 [b] precedent); D17's minimal Variables>Edit… reading;
D19's contract removals; the sabotage table; audit list vs baseline.
