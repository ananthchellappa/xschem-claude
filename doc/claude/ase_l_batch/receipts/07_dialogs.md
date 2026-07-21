# Receipt — item 07 dialogs (ROUND 2, UI v2 / ADE-L parity)

Verdict: **DONE** ([x] in PLAN.md ledger).
Commit (NOT pushed, batch policy):
- `0c54ed28` — `feat(ase): ADE-L v2 dialogs — Choose Analyses, Design/Model
  Files, Save All, Load/Save State, Sim Options` — the ONE implementer
  commit, 6 files, +1719/−41 (verified vs `git show --stat 0c54ed28`).
  No fixer commits: zero fix rounds were needed.

## What landed

All nine `TODO(item07)` stub sites in `src/ase_window.tcl` replaced with
real modeless themed dialogs (copy_current_cell_dialog idioms, USER-LOCKED
palette, named Ase* fonts; D-numbers = the scout micro-decisions in
prompts/item07_dialogs.md):

- **Choose Analyses** `ase::ui::choose_analyses`: top op/dc/ac/tran radio
  section + bottom per-type form (Enable + quick fields: DC
  source/start/stop/step, AC points/start/stop, TRAN step/stop), OK-time
  validation of enabled analyses (D6), `Options…` extra-key editor
  (`$top.chana.x`) writing into the row dict with immediate commit (D5;
  extra-key deck emission stays deferred). Preselect contract wired from
  ALL four item-06 routes: Analyses menu, `OP,TR` strip button, analyses
  ctx Add…/Edit…, analyses double-click (row's type preselected).
- **Setup > Design** `design_dialog`: Library/Cell/View type-to-filter
  ttk::comboboxes; View list restricted to schematic views (datafile
  `.sch`) once Cell chosen; writes state `design`.
- **Setup > Model Files** + **Simulation > Options**: ONE shared
  two-column list-dialog engine (`listdlg_*`) over `models`/`options`:
  ctx-menu Add…/Edit…/Delete + dialog-LOCAL `<Delete>` key (D1 — scout
  chose dialog-local delete over extending the pane selection model; row
  editors `$top.modrow`/`$top.optrow`; immediate commits per D15).
- **Outputs > Save All**: dialog-backed all-voltages / all-terminal-
  currents checkboxes writing `save_all_v`/`save_all_i` (keys landed in
  item 06, defaults 0); Levels field present but DISABLED (inert v1, no
  state key — D11). Outputs-pane Save Options column reacts via the
  item-06 `save_options_cell` logic.
- **Session > Load State**: mkinst-style (create_instance browser
  precedent) 3-column library browser filtered to `.state` views;
  content-import worker `do_load_state_from` loads into THIS session
  (D10) behind a dirty-discard confirm.
- **Session > Save State**: always Save-As — Library dropdown + editable
  Cell/View entries prefilled with current; confirmation predicate
  `save_as_needs_confirm` = readonly-opened attr OR unwritable file,
  same-target only (D8); worker `do_save_state_as` with three arms:
  own-view overwrite / new-view via `library_new_view` (item-02 creation
  path) / existing-other-view (D9/D13).
- **Shared** modeless `ase::ui::confirm`; strip `-->` = the item-06
  output_editor in Add flavor (D3).

`src/ase.tcl`:
- `ase::open_state` gained a trailing optional `{ro 0}` arg; sets session
  attr `readonly` on EVERY open (D7) — the Save-As confirm predicate's
  input.
- `render_deck`: `save_all_i` → `.options savecurrents` (emitted after
  the options loop), `save_all_v` → `.save all` (before the per-output
  `.save`s). D1 golden deck stays byte-identical when both flags are 0.
- NO `schema_keys` change (landmine 1: schema growth would ripple into
  the protected test_ase_final byte-identity fixture — deliberately
  avoided; Save All rides the item-06 keys).

`src/library_manager.tcl`: `open_view_ro`'s state-view branch now calls
`ase::open_state $lib $cell $view 1` directly + a status line (no new
`do_*` proc).

`todo_stub` proc KEPT — 2 remaining callers are item-08's (Select On
Design entry points). `grep "TODO(item07)" src/*.tcl` returns empty.

## Tests — 262 checks total (201 GUI + 61 headless)

**NEW `tests/headless/test_ase_dialogs.tcl` 73 checks** (auto-discovered
by full_audit.sh; run_regression.tcl untouched — pre-batch dirty). The
item-06 `send_return` + tv helpers copied verbatim with an origin
comment. 16 headless: H1 open_state ro-attr (D7), H2 needs_confirm all
4 arms incl. a 0444-file leg, H3 do_save_state_as view creation, H4
content import + dirty flag. 57 GUI legs G1..G12: each dialog opens +
round-trips its state key, Setup>Design view-filter shows ONLY schematic
views, Load State browser filter shows ONLY state views, Save-As creates
a new view dir, read-only overwrite confirm gate (file-not-yet-written
probe), `-->` and `OP,TR` strip buttons open the REAL dialogs,
no-stub scan.

**`tests/headless/test_ase_core.tcl` 45/45 headless** (was 41): +4 D5
blanket-save legs — `.save all` renders from save_all_v (and precedes
the per-output `.save`), `.options savecurrents` from save_all_i.

**`tests/headless/test_ase_window.tcl` 144/144 GUI**: ONLY change = a
`menu_save_state` helper + the 7 Save State menu call sites (labels and
check names unchanged). Justification: the menu entry now opens the
Save-As dialog whose prefilled same-target OK is exactly the old
save — the helper drives that dialog through the real event path.

**Protected tests untouched and green**: test_ase_view 36/36,
test_ase_final 28/28 (re-run after the item). checksTotal 262 =
73 + 45 + 144 (+64 protected re-run, not counted).

## Sabotage table

Each `git diff`-confirmed sabotage-only tree, targeted
`git checkout -- <file>` revert, clean re-runs green (45/45, 73/73):

| # | Sabotage | Target check(s) | Result |
|---|----------|-----------------|--------|
| S1 | deleted the save_all_v → `.save all` emission in `ase::backend::ngspice::render_deck` (src/ase.tcl) | test_ase_core `D5 save_all_v renders .save all` + `D5 .save all precedes the per-output .save` | failed EXACTLY the targets |
| S2 | `do_save_state_as` skips the `library_new_view` arm (src/ase_window.tcl, returns 0 when view unresolved) | test_ase_dialogs H3 create block (3 checks) + G7 create legs (2 checks) | failed exactly the 5 checks inside the two TARGETED behavior blocks (prompt predicted 2 — see note) |
| S3 | dropped the `ase::session_update` commit from `chana_ok` (src/ase_window.tcl) | `G2 Choose Analyses round-trips dc quick fields` + `G2 Arguments summary shows the fields` (G1 open/preselect legs stayed green) | failed EXACTLY the targets |

S2 note (recorded per protocol): observed fail set was 5 checks vs the
prompt's predicted 2 — but all 5 sit inside the two behavior blocks the
sabotage targets (H3 worker creation + G7 Save-As-creates-view);
everything else stayed green, so the sabotage still proves exactly the
intended coverage, just at finer check granularity than predicted.

## Fix-round history

None. Zero fixer rounds consumed; all 3 verifier lenses came back clean
on the first pass — the outstanding-problems list was verified EMPTY at
ledger time.

Flake note (rerun-first classification, receipts/06 precedent): 2 of 4
direct test_ase_window DISPLAY runs during implementation had a single
FAIL (one confirmed `W6c Ctrl-W destroyed the log window` — the known
WSLg focus-stall class from receipts/06), followed by 2 consecutive
clean 144/144 runs. Not a regression.

Audit: the implementer's full_audit.sh was still in flight at their
forced-report time (~120/230). The ledger-time read of that same log
(scratchpad full_audit_item07.log, terminated without SUMMARY after 203
of 215 discovered tests, alphabetical cutoff at test_sympin_drop_log):
191 PASS / 12 FAIL, every FAIL a STRICT SUBSET of the baseline list
(cadence_descend_newwin_ro, cadence_drag, ciw, crossview_paste,
hi_descend, lib_manager_gui, lib_sweep, phase3_mints, pin_type_edit,
reopen_readonly, select_at, selflog_output); several baseline flakes
even PASSED this run (altf5_ciw, cadence_window_hop_log, fluid_editing,
key_graph_context, launch_context, palette); test_ase_core / _dialogs /
_final / _view / _window ALL PASSED inside the audit. The tests-lens
verifier ran its own audit and reported no problems.

## Declared implementer deviations (forced by reality)

1. **H4/G9 import fixture** uses a backend-seeded `ngspice_stateB`
   instead of the prompt's worker-created state2 — otherwise the S2
   sabotage cascades into an aborted harness instead of exact-target
   fails.
2. **`tv_dblclick_cell` local helper**: a row-CENTER generated
   double-click can land on the Enable checkbox cell (whose Button-1
   handler break-consumes) — aim at the type cell instead.
3. **G4/G6 delete legs** drive the ctx-menu Delete entry, not a
   generated `<Delete>` key: same WSLg focus-redirection landmine as
   `<Return>`; same handler either way; the product `<Delete>` binding
   still ships.
4. **G3 title check is a prefix match** — the session is legitimately
   dirty at that point (` *` suffix).
5. **Choose Analyses Options editor**: Return on the name/value pair =
   Add (that pair's proceed); dialog OK commits the set — within the
   spec's "minimal form OK".
6. S2's 5-vs-2 fail-set granularity (see sabotage table note).

## Outstanding problems

None — the outstanding-problems list was verified EMPTY at ledger time
(no fixer rounds needed; lenses clean first pass).

## Corrected/confirmed anchors worth keeping

- **Generated `<Delete>` = same WSLg landmine as `<Return>`**: any
  generated key event is focus-redirected; when a ctx-menu entry shares
  the handler, drive the menu entry and keep the key binding as shipped
  product (delivery already witnessed by the send_return-gated legs).
- **Treeview cell-targeted double-click**: aim generated double-clicks
  at a SPECIFIC column's cell — row-center can hit a checkbox cell whose
  Button-1 handler break-consumes the sequence (`tv_dblclick_cell`).
- **Sabotage fixtures must not depend on the sabotaged path**: seed
  auxiliary fixtures via the backend (state I/O), not via the worker
  under sabotage, or the harness aborts instead of failing exact targets.
- **Dirty-title assertions**: prefix-match titles in legs that run after
  state mutations — the `*` dirty marker is legitimate there.
- **`ase::open_state` contract (item-08 relevant)**: now
  `ase::open_state <lib> <cell> <view> ?ro?`; sets session attr
  `readonly` on every open; libmgr `open_view_ro` passes 1 directly.
- **Deck emission order**: `.save all` before per-output `.save`s,
  `.options savecurrents` after the options loop; golden deck
  byte-identical with both flags 0 — item-08 deck asserts can rely on
  this ordering.
- **`todo_stub` still exists** with exactly 2 callers, both item-08's
  Select On Design entry points — item 08 removes it.

## Commit hygiene

`0c54ed28` staged exactly the 6 files: `src/ase.tcl`,
`src/ase_window.tcl`, `src/library_manager.tcl`,
`tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_window.tcl`,
`tests/headless/test_ase_dialogs.tcl` (verified vs `git show --stat`).
No pre-batch dirty tracked files staged; PLAN.md/receipt edits left
unstaged for the driver's single ledger commit. NOT pushed.
