# Legacy raw-switch key inventory — issue 0068 definitive sweep

**Date:** 2026-07-19 (Refactor B bug-fix batch item 8, "issue-0068-sweep").
**Deliverable class:** DOCS ONLY — no code changed, no tests run.
**Issue:** `doc/claude/issues/0068-unmigrated-legacy-switch-keys-not-logged.md` (carries the
(iv)/(v) headline lists; this doc carries the full table).
**Surface:** `src/callback.c` `handle_key_press` (starts :4863). Registry dispatch gate at
:4890-4900 (`key_chord_has_binding` → `dispatch_input_action`; a dispatched chord RETURNS
before the switch). Legacy `switch (key)` opens at :4903, `default:` at :6529. Every `case`
arm between those lines is inventoried below, one row per `state`/`rstate` branch.
Line numbers are as of commit 9febeaa6 (they WILL drift — re-verify before citing onward).

## Headline counts

- **Class (iv) — unlogged mutations: N = 5** (3 schematic-state, 2 semantic-config).
- **Class (v) — readonly-ungated schematic mutations: M = 0.** Every sch-mutating arm has a
  `readonly_block()` in the arm ("key") or a gate in the callee/boundary ("core"). The last
  known (v) — Ctrl+`#` silent read-only rename — was closed by Refactor B atom 26
  (callback.c:6467-6479). The two unlogged cfg toggles (Ctrl+Shift+V, `:`) are not (v):
  they never write the read-only file, so a readonly gate is moot there.

## Classification legend (from the item-8 prompt)

- **(i)** covered by a core self-log or the gesture-drop funnel
  (`end_move_copy_logged` callback.c:1604 / `log_placed_instance` callback.c:1572 /
  actions.c drop logs / a self-logging core).
- **(ii)** logs at the key site (`log_action` inline in the case arm).
- **(iii)** routes through a logged verb (`perform_action(...)` or a self-logging
  scheduler branch reached via `tcleval("xschem ...")`).
- **(iv)** UNLOGGED gap — mutating, no line anywhere. The 0068 list.
- **(v)** readonly-UNGATED — sch-mutating arm with no `readonly_block()` and no gate in the
  callee (the 0126/0128 bug class). A row can be both (iv) and (v).
- **n/a** non-mutating (zoom/pan/selection/viewer/dialog-open-only/UI toggle/session op),
  recorded with a one-word reason so the sweep is provably complete.
- **dormant-shadowed** — the case arm is unreachable because an exact-chord
  `keybindings.csv` row dispatches first; evidence = the csv row.

Columns: Mutates ∈ {sch, cfg, no}; RO-gate ∈ {key, core, none, n/a}; Action ∈
{route-via-audit-§32, stay-raw-add-selflog, stay-raw-document, gate-only, none}.

## Funnel / core self-log evidence base (re-verified 2026-07-19)

- `end_move_copy_logged` callback.c:1604 — move/copy drop → `xschem move_objects/
  copy_objects dx dy ...` (:1776-1780); paste/merge drop → `xschem paste dx dy [...]
  [-file {src}]` (:1678-1681, source recorded by paste.c:384-388 `merge_source`);
  PLACE_SYMBOL drop → `log_placed_instance` (:1725-1727) → `xschem instance name x y rot
  flip prop` (:1572-1596); START_SYMPIN drop → `xschem add_symbol_pin ...` or
  `log_placed_instance` (:1683-1724); PLACE_TEXT drop → `xschem text ...` (:1729-1746).
- Gesture-insert drop self-logs in actions.c: `new_wire` (fn :4294; logs :4313-4354),
  `new_arc` (:4449; log :4476), `new_line` (:4513; logs :4529-4566), `new_rect` (:4589;
  log :4607), `new_polygon` (:4633; log :4700). Receipts 06/26/30/25.
- Core self-logs: `make_symbol` save.c:3336 (receipt 22); `create_sch_from_sym` →
  `xschem make_sch` save.c:5510 (receipt 23); `descend_schematic` actions.c:3614-3615
  (receipt 14); `descend_symbol` save.c:5679-5680 (receipt 15); `go_back`
  actions.c:3770-3771 (receipt 16); `saveas` actions.c:679 (receipt 19); `ask_new_file`
  dialog loads actions.c:728/:740; scheduler `load -gui` branch scheduler.c:6128;
  scheduler `load_new_window` branch scheduler.c:6256; editprop committed-edit lines
  editprop.c:1681-1683 `log_prop_edit_replayable` (receipt 29, 0063 atom 10).
- `standalone_group_transform` callback.c:4813 routes every standalone Alt-R/Alt-F apply
  through `perform_action`: "rotate" :4832 / "flip" :4846 (group, pivot form) /
  "rotate_in_place" :4858 / "flip_in_place" :4859 (single object).

## The table

Walked top-to-bottom; every `case` label from the :4903-:6529 grep appears exactly once
here or in the "fully migrated" list below.

| # | Chord | case:line | Effect (callee) | Mutates | RO-gate | Class | Evidence | Action |
|---|-------|-----------|-----------------|---------|---------|-------|----------|--------|
| 1 | `0`..`4` plain | :4904-4913 | `logic_set()` set/toggle net logic level | sch (session logic annotation: bus-hilight hash XINSERT + `propagate_logic`, hilight.c:2309-2369; drives redraw + gaw sync) | key :4911 | **(iv)** | hilight.c has ZERO `log_action`; scheduler twin `logic_set_net` (scheduler.c:6412-6420) is silent too | stay-raw-add-selflog (a log inside `logic_set` would cover key + verb) |
| 2 | `Ctrl+0`..`4` | :4915-4929 | layer pick via `tclvareval("xschem set rectcolor N")` | cfg (layer cursor); sch iff selection (`change_layer` recolors) | core (scheduler_readonly_reject, scheduler.c:10116) | (iii) | scheduler.c:10103-10119: bare pick deliberately nolog (issue 0066); with selection logs `xschem set rectcolor %d` :10118 | none |
| 3 | `5` plain | :4932-4938 | `only_probes` toggle | cfg | n/a | n/a | UI toggle | none |
| 4 | `Ctrl+5`..`9` | :4939-4957 | layer pick (same as row 2) | cfg / sch-iff-sel | core | (iii) | scheduler.c:10103-10119 | none |
| 5 | `a` plain | :4960-4974 | okcancel → save current sch + `make_symbol()` | sch (writes generated .sym; pre-save gated `!xctx->readonly` :4971) | key-partial :4971 + dialog | (i) | save.c:3336 `xschem make_symbol`; receipt 22; case comment :4969-4970 | none |
| 6 | `Ctrl+a` | :4975-4977 | `select_all()` | no | n/a | n/a | selection | none |
| 7 | `b` plain | :4986-4991 | `merge_file(0,"")` merge dialog → STARTMERGE gesture | sch at drop | key :4988 | (i) | drop funnel `xschem paste dx dy ... -file {src}` callback.c:1678-1681 + paste.c:384-388 | none |
| 8 | `Ctrl+b` | :4992-5004 | `sym_txt` toggle | cfg | n/a | n/a | UI toggle | none |
| 9 | `Alt+b` (family) | :5005-5011 | `hide_symbols` cycle | cfg | n/a | n/a | UI toggle | none |
| 10 | `c` plain | :5025-5040 | duplicate: `copy_objects(START)` or arm MENUSTARTCOPY | sch at drop | key :5027 | (i) | funnel callback.c:1604 | none |
| 11 | `Ctrl+c` | :5042-5051 | clipboard copy `save_selection(2)` | no (clipboard) | n/a | (ii) | `log_action("xschem copy")` :5049; receipt 13 | none |
| 12 | `Alt+c` (family) | :5053-5065 | duplicate w/ connect_by_kissing | sch at drop | key :5055 | (i) | funnel :1604 | none |
| 13 | `Shift+C` plain | :5069-5081 | `new_arc(PLACE,180)` arc gesture | sch at drop | key :5071 | (i) | actions.c:4476; receipt 26 | none |
| 14 | `Ctrl+Shift+C` | :5082-5094 | `new_arc(PLACE,360)` circle | sch at drop | key :5084 | (i) | actions.c:4476 | none |
| 15 | `Ctrl+d` | :5101-5104 | `delete_files()` file-manager dialog (actions.c:2341) | no (disk files, not schematic) | n/a | n/a | dialog | stay-raw-document |
| 16 | `Shift+D` plain | :5108-5121 | unselect-by-area arm | no | n/a | n/a | selection | none |
| 17 | `e` plain | :5125-5128 | `descend_schematic()` | no (hierarchy nav, replay-relevant) | n/a | (i) | actions.c:3614-3615; receipt 14 | none |
| 18 | `Ctrl+e` | :5129-5132 | `go_back(1)` | no (nav) | n/a | (i) | actions.c:3770-3771; receipt 16 | none |
| 19 | `Alt+e` (family) | :5133-5139 | `open_sub_schematic` new window | no | n/a | n/a | window-open | none |
| 20 | `Alt+Shift+E` (family) | :5143-5148 | schematic in new process | no | n/a | n/a | window-open | none |
| 21 | `Ctrl+f` | :5154-5158 | `property_search` dialog | no (dialog-open) | n/a | n/a | dialog | none |
| 22 | `Alt+f` mid-gesture (family) | :5163-5166 | FLIP during STARTMOVE/STARTCOPY | sch at drop | key :5160 | (i) | funnel rot/flip capture :1604/:1747+ | none |
| 23 | `Alt+f` standalone | :5179 | `standalone_group_transform(FLIP)` | sch | core | (iii) | callback.c:4846 ("flip") / :4859 ("flip_in_place") | none |
| 24 | `Alt+f` arming (no sel) | :5169-5173 | MENUSTART arm | no | n/a | n/a | arming | none |
| 25 | `Shift+F` mid-gesture | :5188-5189 | FLIP during move/copy | sch at drop | key :5187 | (i) | funnel | none |
| 26 | `Shift+F` arming | :5192-5196 | arm | no | n/a | n/a | arming | none |
| 27 | `Shift+F` standalone | :5206-5210 | `perform_action("flip", pivot)` | sch | core | (iii) | :5210 (Refactor B atom 7) | none |
| 28 | `Ctrl+F` | :5214-5218 | zoom to selection | no | n/a | n/a | zoom | none |
| 29 | `Ctrl+h` | :5228-5233 | `launcher()` open URL/doc | no | n/a | n/a | viewer | none |
| 30 | `h` plain | :5234-5252 | `constr_mv` horizontal toggle + rubber refresh | cfg (gesture modifier; drop logs effective coords) | n/a | n/a | UI toggle | none |
| 31 | `i` plain | :5262-5265 | `descend_symbol()` | no (nav) | n/a | (i) | save.c:5679-5680; receipt 15 | none |
| 32 | `Ctrl+i` | :5266-5274 | insert-symbol chooser dialog | sch at placement drop | key :5267 + symbol_view_block :5268 | (i) | funnel `log_placed_instance` :1572 via PLACE_SYMBOL :1725-1727 | none |
| 33 | `Alt+i` (family) | :5275-5280 | symbol in new window | no | n/a | n/a | window-open | none |
| 34 | `Shift+I` plain | :5284-5293 | `start_place_symbol()` / chooser | sch at drop | key :5286 + view block :5287 | (i) | funnel :1572 | none |
| 35 | `Alt+Shift+I` (family) | :5294-5299 | symbol in new process | no | n/a | n/a | window-open | none |
| 36 | `Ctrl+Alt+j` (family) | :5308-5310 | `print_hilight_net(3)` list w/ bus expansion | no | n/a | n/a | viewer (receipt 21 mode split); family chord ratified stay-in-C, comment :5302-5307 | none |
| 37 | `Alt+Shift+J` (family) | :5314-5318 | `print_hilight_net(2)` create i-prefixed labels from hilight nets | sch | key :5316 | **(iv)** partial-funnel | receipt 21: the routed inner `xschem merge` DROP funnel-logs, the initiating verb line is missing; hilight.c:4060 has no log | stay-raw-add-selflog (blocked on interp-visible suppress-scope, batch defer note) |
| 38 | `l` plain | :5335-5350 | start_line gesture | sch at drop | key :5338 | **dormant-shadowed** | keybindings.csv `key,108,0,canvas,edit.add_wire_label,1` dispatches first (case comment :5331-5334); if un-bound, drop self-logs actions.c:4529-4566 → (i) | none |
| 39 | `Ctrl+l` | :5351-5353 | `create_sch_from_sym()` | sch (writes new .sch) | core (dialogs; readonly-irrelevant target file) | (i) | save.c:5510 `xschem make_sch` (comment names the Ctrl+L handler); receipt 23 | none |
| 40 | `Alt+l` (family) | :5355-5357 | `addlabel::open` Add-Wire-Label form (0122) | sch at form drop | key :5356 | (i) | form drop places `lab_pin` instances → placement funnel; receipt 27 | none |
| 41 | `Alt+Shift+L` (family) | :5366-5368 | `place_net_label(0)` lab_wire | sch at drop | key :5367 | (i) | funnel :1572; receipt 28 | none |
| 42 | `m` plain | :5377-5415 | connected stretch (cadence) / move pickup or verb-noun arm | sch at drop | key :5382 | (i) | funnel :1604 | none |
| 43 | `Ctrl+m` | :5417-5432 | move stretching attached nets | sch at drop | key :5422 | (i) | funnel | none |
| 44 | `Alt+m` (family) | :5434-5446 | move adding kissing wires | sch at drop | key :5435 | (i) | funnel | none |
| 45 | `Shift+M` plain | :5451-5479 | rigid move (cadence) / move+kissing | sch at drop | key :5452 | (i) | funnel | none |
| 46 | `Ctrl+Shift+M` | :5481-5493 | move + stretch + kissing | sch at drop | key :5482 | (i) | funnel | none |
| 47 | `Shift+N` plain | :5502-5559 | current-level netlist | no (netlist output file) | n/a | (ii) | `log_action("xschem netlist -erc -nohier")` :5540 (0071 atom 14 anatomy in the comment) | none |
| 48 | `Ctrl+Shift+N` | :5560-5564 | `tcleval("xschem clear symbol")` → `clear_schematic()` | sch (empties window to blank symbol) | key :5562 | **(iv)** | scheduler `clear` branch scheduler.c:2481-2492 calls `clear_schematic(cancel,symbol)` with NO `log_action` — for the key AND every menu caller. NEW find of this sweep | stay-raw-add-selflog at the scheduler `clear` branch (covers menu too) |
| 49 | `Alt+o` (family) | :5568-5573 | `ask_new_file(1)` open-in-new-window dialog | no (context change) | n/a | (i) | actions.c:740 `xschem load_new_window {f}` (dialog path) | none |
| 50 | `Ctrl+o` | :5574-5584 | `ask_new_file(0)` or `file_chooser` | no (context) | n/a | (i)/(iii) | actions.c:728 (dialog path); file_chooser resolves via scheduler `load -gui` → scheduler.c:6128 | none |
| 51 | `Ctrl+O` | :5588-5596 | reopen most recent (`xschem load -gui -lastopened` / `load_new_window -lastopened`) | no (context) | n/a | (iii) | scheduler.c:6128 (`load -gui`) / :6256 (`load_new_window`) log the resolved file | none |
| 52 | `Ctrl+p` | :5604-5607 | `place_net_label(2)` input port | sch at drop | key :5605 | (i) | funnel :1572; receipt 28 | none |
| 53 | `Ctrl+Shift+P` | :5613-5616 | `place_net_label(3)` output port | sch at drop | key :5614 | (i) | funnel; receipt 28 | none |
| 54 | `Ctrl+q` | :5620-5626 | `quit_xschem` | no | n/a | n/a | session | none |
| 55 | `q` plain | :5627-5636 | `edit_property(0)` dialog | sch on commit | core (form opens as viewer on read-only, issue 0051, comment :5629-5634) | (i) | editprop.c:1681-1683 (`setprop`/`set sch<X>prop`/`apply_properties` lines); receipt 29 | none |
| 56 | `Alt+q` (family) | :5637-5650 | `edit_file` external editor on the .sch/.sym file | no (out-of-band disk edit, "DANGER" by design) | none (moot in-session) | n/a | external editor | stay-raw-document |
| 57 | `Shift+Q` plain | :5654-5657 | `edit_property(1)` edit in text editor | sch on commit | key :5656 | (i) | editprop.c:1683; receipt 29 | none |
| 58 | `Ctrl+Shift+Q` | :5659-5661 | `edit_property(2)` view attributes | no | n/a | n/a | viewer (x==2 excluded from log, editprop.c:1681 comment) | none |
| 59 | `r` plain | :5665-5678 | `new_rect` gesture | sch at drop | key :5668 | (i) | actions.c:4607; receipt 25 | none |
| 60 | `Ctrl+r` (cadence) | :5679-5691 | simulate | no | n/a | n/a | sim-launch | none |
| 61 | `Alt+r` mid-gesture (family) | :5697-5700 | ROTATE during move/copy | sch at drop | key :5693 | (i) | funnel | none |
| 62 | `Alt+r` standalone | :5711 | `standalone_group_transform(ROTATE)` | sch | core | (iii) | callback.c:4832 / :4858 | none |
| 63 | `Alt+r` arming | :5703-5707 | arm | no | n/a | n/a | arming | none |
| 64 | `Shift+R` mid-gesture | :5720-5721 | ROTATE | sch at drop | key :5719 | (i) | funnel | none |
| 65 | `Shift+R` arming | :5724-5731 | arm | no | n/a | n/a | arming | none |
| 66 | `Shift+R` standalone | :5741-5745 | `perform_action("rotate", pivot)` | sch | core | (iii) | :5745 (atom 6) | none |
| 67 | `s` plain (!cadence) | :5753-5765 | simulate | no | n/a | n/a | sim-launch | none |
| 68 | `s` plain (cadence) | :5767-5770 | `snapped_wire()` immediate pin-snapped wire | sch | key :5769 | (i) | snapped_wire (callback.c:2471) → `new_wire(PLACE…PLACE\|END)` → actions.c:4313-4354; receipt 06 | none |
| 69 | `Ctrl+s` | :5772-5786 | save (untitled → saveas) | no (disk write) | core (log gated `!readonly`) | (ii)/(i) | :5785 `xschem save`; saveas path actions.c:679; receipts 18/19 | none |
| 70 | `Alt+s` (family) | :5789-5803 | reload from disk (okcancel) | sch (content replaced) | n/a | (ii) | :5802 `xschem reload`; receipt 20 | none |
| 71 | `Ctrl+Alt+s` (family) | :5806-5809 | saveas SYMBOL | no (disk) | n/a | (i) | actions.c:679; receipt 19 | none |
| 72 | `Shift+S` plain | :5813-5827 | change_elem_order via boundary | sch | key :5825 + core | (iii) | :5827 (atom 21, av[2]="-1") | none |
| 73 | `Ctrl+Shift+S` | :5829-5832 | saveas SCHEMATIC | no (disk) | n/a | (i) | actions.c:679 | none |
| 74 | `t` plain | :5836-5848 | `place_text` + move gesture | sch at drop | key :5838 | (i) | PLACE_TEXT drop `xschem text ...` callback.c:1729-1746; receipt 24 | none |
| 75 | `Ctrl+t` | :5849-5862 | `new_schematic("create")` new tab/window | no (new empty window) | n/a | n/a | window-open | none |
| 76 | `Ctrl+T` | :5868-5876 | reopen last closed (`xschem load -gui -lastclosed` / `load_new_window -lastclosed`) | no (context) | n/a | (iii) | scheduler.c:6128 / :6256 | none |
| 77 | `Alt+u` (family) | :5885-5893 | align-to-grid via boundary | sch | core (scheduler_readonly_reject) | (iii) | :5893 (atom 2); comment :5887-5892 | none |
| 78 | `Ctrl+u` | :5895-5897 | `unselect_attached_floaters` | no | n/a | n/a | selection | none |
| 79 | `v` plain | :5906-5924 | `constr_mv` vertical toggle | cfg (gesture modifier) | n/a | n/a | UI toggle | none |
| 80 | `Ctrl+v` | :5925-5929 | `merge_file(2,".sch")` clipboard paste gesture | sch at drop | key :5927 | (i) | funnel `xschem paste dx dy ...` :1678-1681 (clip_file source ⇒ no -file rider) | none |
| 81 | `Alt+v` mid-gesture (family) | :5934-5945 | R+R+F vertical flip during move/copy | sch at drop | key :5931 | (i) | funnel | none |
| 82 | `Alt+v` arming | :5948-5952 | arm | no | n/a | n/a | arming | none |
| 83 | `Alt+v` standalone | :5961 | `perform_action("flipv_in_place")` | sch | core | (iii) | :5961 (atom 5; no group form — whole apply crosses the boundary) | none |
| 84 | `Shift+V` mid-gesture | :5970-5979 | R+R+F | sch at drop | key :5969 | (i) | funnel | none |
| 85 | `Shift+V` arming | :5982-5986 | arm | no | n/a | n/a | arming | none |
| 86 | `Shift+V` standalone | :5997-6001 | `perform_action("flipv", pivot)` | sch | core | (iii) | :6001 (atom 8) | none |
| 87 | `Ctrl+Shift+V` | :6005-6010 | `netlist_type` cycle (1..6) | cfg (netlist semantics — changes output format + ignore-greying) | none (moot — no file write) | **(iv)** | no log anywhere; prompt seed row | stay-raw-document |
| 88 | `w` plain | :6014-6031 | `start_wire` gesture | sch at drop | key :6017 | (i) | actions.c:4313-4354; receipt 06 | none |
| 89 | `Ctrl+w` | :6032-6041 | `close_schematic_window` | no | n/a | n/a | session | none |
| 90 | `Shift+W` (!cadence) | :6045-6049 | `snapped_wire()` | sch | key :6047 | (i) | receipt 06 (same as row 68) | none |
| 91 | `x` plain | :6053-6055 | `new_xschem_process` | no | n/a | n/a | session | none |
| 92 | `Alt+x` (family) | :6056-6063 | `draw_crosshair` toggle | cfg | n/a | n/a | UI toggle | none |
| 93 | `Ctrl+x` | :6064-6079 | cut (`save_selection(2)` + `delete(1)`) | sch | key :6066 | (ii) | `log_action("xschem cut")` :6077; receipt 12 | none |
| 94 | `Shift+X` plain | :6083-6085 | `hilight_net_pin_mismatches` | no (hilight) | n/a | n/a | hilight | none |
| 95 | `Ctrl+Shift+X` | :6086-6088 | `create_plot_cmd` xplot file | no (tool output) | n/a | n/a | export | none |
| 96 | `z` plain | :6096-6099 | `zoom_rectangle(START)` | no | n/a | n/a | zoom | none |
| 97 | `Alt+z` (family, cadence) | :6103-6114 | `snap_cursor` toggle | cfg | n/a | n/a | UI toggle | none |
| 98 | `Space` | :6121-6130 | FALLBACK: cycle manhattan corner / drag-pan | no | n/a | n/a | fallback — registry `edit.add_pin_stubs` (csv row `key,32,0`) dispatches first and DECLINES into this case by design (comment :6122-6128); pan end logs via `log_pan_end` | none |
| 99 | `_` | :6132-6143 | `change_lw` toggle | cfg | n/a | n/a | UI toggle | none |
| 100 | `Ctrl+$` | :6153-6162 | `draw_window` toggle | cfg | n/a | n/a | UI toggle | none |
| 101 | `Ctrl+=` | :6169-6193 | fill-pattern cycle | cfg | n/a | n/a | UI toggle | none |
| 102 | `Ctrl++` | :6197-6201 | linewidth + | cfg | n/a | n/a | UI toggle | none |
| 103 | `Ctrl+-` | :6205-6210 | linewidth - | cfg | n/a | n/a | UI toggle | none |
| 104 | `Alt+-` (family) | :6211-6213 | `input_line` linewidth dialog | no | n/a | n/a | dialog | none |
| 105 | `Return` | :6217-6219 | close polygon `new_polygon(ADD\|END)` | sch | gesture-gated (polygon START was gated) | (i) | actions.c:4700 `xschem polygon x1 y1 ...` | none |
| 106 | `Escape` | :6222-6237 | `abort_operation` + redraw | no (abort) | n/a | n/a | abort | none |
| 107 | `Delete` | :6239-6252 | delete selection | sch | key :6242 | (ii) | `log_action("xschem delete")` :6250 | none |
| 108 | `Ctrl+Tab` | :6255-6262 | tab switch | no | n/a | n/a | session | none |
| 109 | `Shift+Tab`/`Ctrl+Shift+Tab` (win32) | :6263-6278 | tab switch | no | n/a | n/a | session | none |
| 110 | `Shift+ISO_Left_Tab` chords (unix) | :6281-6297 | tab switch | no | n/a | n/a | session | none |
| 111 | `Ctrl+Right` / `Ctrl+Left` | :6304-6310 / :6325-6331 | tab switch | no | n/a | n/a | session | none |
| 112 | modified `Right`/`Left`/`Down`/`Up` (plain chords are registry scroll actions) | :6311-6319 / :6332-6340 / :6343-6354 / :6356-6366 | pan | no | n/a | n/a | pan | none |
| 113 | `BackSpace` plain | :6368-6371 | `go_back(1)` | no (nav) | n/a | (i) | actions.c:3770-3771; receipt 16 | none |
| 114 | `Print` (unix+cairo) | :6374-6378 | GRABSCREEN arm | no | n/a | n/a | screenshot | none |
| 115 | `Shift+Insert` | :6382-6390 | insert-symbol dialog | sch at drop | key :6383 + view block :6384 | (i) | funnel :1572 | none |
| 116 | `Insert` (other mods) | :6391-6400 | `start_place_symbol` / chooser | sch at drop | key :6393 + view block :6394 | (i) | funnel :1572 | none |
| 117 | `*` / `Ctrl+*` / `Alt+*` | :6404-6415 | ps / xpm / svg export | no | n/a | n/a | export (3 arms) | none |
| 118 | `&` | :6418-6425 | trim_wires via boundary | sch | core (scheduler_readonly_reject) | (iii) | :6424; comment :6420-6423 | none |
| 119 | `\` | :6428-6431 | fullscreen toggle | no | n/a | n/a | UI toggle (window state) | none |
| 120 | `>` | :6434-6439 | single-layer draw cursor | cfg | n/a | n/a | UI toggle | none |
| 121 | `<` | :6441-6445 | single-layer off | cfg | n/a | n/a | UI toggle | none |
| 122 | `?` | :6447-6450 | help window | no | n/a | n/a | viewer | none |
| 123 | `/` (XK_slash) | :6451-6454 | `show_bindkeys` | no | n/a | n/a | viewer | none |
| 124 | `:` | :6456-6465 | `flat_netlist` toggle | cfg (netlist semantics — flat vs hierarchical SPICE output) | none (moot) | **(iv)** | no log anywhere | stay-raw-document |
| 125 | `Ctrl+#` | :6468-6479 | rename duplicate refdes via boundary | sch | core (gained in atom 26 — closed the last (v)) | (iii) | :6478 `perform_action("check_unique_names", av[2]="1")`; receipt 01, audit §46 | none |
| 126 | `#` plain | :6480-6486 | `check_unique_names(0)` highlight duplicates | no (hilight) | n/a | (ii) | `log_action("xschem check_unique_names 0")` :6485 (atom 26 asymmetric split) | none |
| 127 | `;` / `~` / `\|` | :6489-6502 | dead testmode arms (`if(0 && ...)`) | no | n/a | n/a | dead (3 cases) | none |
| 128 | `Ctrl+!` | :6513-6521 | break_wires remove-flag via boundary | sch | key :6514-6515 + core | (iii) | :6519 (`av[2]="1"`, atom 9) | none |
| 129 | `!` plain | :6522-6526 | break_wires via boundary | sch | key :6523-6524 + core | (iii) | :6525 | none |
| 130 | `default:` | :6529 | no-op | no | n/a | n/a | no-op | none |

## Fully migrated cases (exist only as comments; evidence = the comment)

- `A` :4980-4983 (view.toggle_show_netlist; Ctrl branch was a no-op)
- `B` :5014-5016 (prop.edit_header_license_text)
- `g`/`G` :5221-5225 (snap actions + hilight.send_to_waveform; ship UNBOUND, user-bindable)
- `H` :5257-5259 (attach_net_labels / make_schematic_and_symbol)
- `k` :5321-5325, `K` :5327-5329 (hilight family, Tcl-backed idle rows)
- `n` :5496-5499 (toolbar.netlist / file.clear_schematic)
- `U` :5901-5903 (edit.redo)
- `y` :6091-6092 (edit.toggle_stretch)
- `Z` :6117-6119 (view.zoom_in)
- `%` :6145-6147 (view.toggle_draw_grid, ships unbound)

In-case branch migrations (case remains for its other chords; recorded in the rows above):
`f` plain :5152-5153, `h` Alt :5253-5254, `j` plain/Ctrl/Alt :5302-5307, `l` plain
(dormant-shadowed row 38), `L` plain :5361-5365, `O` plain :5597-5598, `p` plain
:5601-5603, `P` plain :5611-5612, `T` plain :5866-5867, `u` plain :5881-5884, `d` plain
:5097-5100, `$` plain :6149-6152, `=` plain :6165-6168, `z` Ctrl :6100-6102, Space
default-action :6121-6128, plain arrows :6299-6303/:6322-6324/:6343-6346/:6356-6358.

## Numeric verb-noun (context-menu pick) surface — summary only

The context-menu / verb-noun pick dispatch (callback.c:3147-3327) is ALREADY
class-complete in code: the `ctxmenu_log_cmd[]` classification table (:3147) assigns each
pick a replay command, a `#` marker, or NULL(=nothing), and the record-after-evaluation
emit at :3325-3327 (`if(logcmd && !actionlog_cmd_logged) log_action(...)`) dedups against
core self-logs. Receipt 12 has the pick-7 dedup web; receipt 29 covers pick 11. No
per-pick re-derivation here.

## keybindings.csv / actions.csv cross-reference

- Shadowing: exactly one truly shadowed case arm survives — `l` plain (row 38,
  dormant-shadowed). `Space` (row 98) is a designed decline-fallback, not dormant.
  All other bound chords have had their case arms deleted (the comment list above).
- Orphan accels (actions.csv `accel` display string with neither a keybindings.csv row
  nor a case arm): `Alt+G` (`hilight.send_selected_net_pins_to_viewer`) — deliberate,
  ships unbound (g/G comment :5221-5225). Cosmetic display mismatch: `view.zoom_box`
  shows accel "Z" but the zoom-box key is lowercase `z` (row 96); `Z` is bound to
  view.zoom_in. Accels are display-only (actions.csv header: "NOT bound here").
- Family chords (SET_MODMASK = Alt-or-Super, `EQUAL_MODMASK` arms) are ratified
  stay-in-C: the exact-chord binding table cannot express Alt-or-Super
  (comments callback.c:4044-4048, :5302-5307). Marked "(family)" in the table.

## Class (iv) — THE 0068 LIST (N = 5)

Schematic-state (3):
1. **`0`..`4` plain → `logic_set()`** (row 1) — set/toggle net logic-level annotation;
   readonly-gated at the key; no log in hilight.c; scheduler twin `logic_set_net` silent
   too. Recommendation: self-log inside `logic_set` (covers key + verb).
2. **`Alt+Shift+J` → `print_hilight_net(2)`** (row 37) — creates i-prefixed net labels;
   partial-funnel (inner merge drop logs, initiating verb doesn't); receipt 21.
   Blocked on the interp-visible suppress-scope pattern (batch defer).
3. **`Ctrl+Shift+N` → `xschem clear symbol`** (row 48) — empties the window;
   the scheduler `clear` branch (scheduler.c:2481) logs nothing for ANY caller
   (key or menu). NEW find of this sweep. Recommendation: branch self-log.

Semantic-config (2):
4. **`Ctrl+Shift+V` netlist_type cycle** (row 87) — stay-raw-document.
5. **`:` flat_netlist toggle** (row 124) — stay-raw-document.

## Class (v) — readonly-ungated (M = 0)

None. See "Headline counts" for the rationale; last (v) closed by atom 26.

## Completeness check

Every case label produced by
`grep -n "case '\|case XK_\|default:" src/callback.c` bounded to :4903-:6529
(82 labels incl. `default:`) appears in the table exactly once (multi-label fallthrough groups
`0`-`4`, `5`-`9`, `;`/`~`/`|`, arrows, Tab family are single rows covering all their
labels) or in the fully-migrated comment list.
