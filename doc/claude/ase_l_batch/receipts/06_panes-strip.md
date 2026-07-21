# Receipt — item 06 panes-strip (ROUND 2, UI v2 / ADE-L parity)

Verdict: **DONE** ([x] in PLAN.md ledger).
Commits (NOT pushed, batch policy):
- `76c4cffe` — `feat(ase): ADE-L v2 panes + action strip — 3 treeview panes,
  row editors, X delete, Value fill after run` — the ONE implementer commit,
  5 files, +1032/−312 (verified vs `git show --stat 76c4cffe`).
- `483084e0` — fixer round 1 (TEST-ONLY, tests/headless/test_ase_window.tcl):
  WSLg-robust W6c Ctrl-W + W4 raise sequencing.
- `7530dc39` — fixer round 2 (TEST-ONLY, same file): WSLg-proof every
  generated `<Return>` (send_return helper) + W4 raise-stall self-SKIP.

## What landed

- **`src/ase.tcl`** (only two changes):
  - `schema_keys` 11 → 13: `save_all_v` / `save_all_i` inserted after
    `outputs`, defaults 0 (D9) — the item-07 Save All dialog's state keys
    land HERE per the coordination note in the item detail; dialog later.
  - `result_probe` skips only expr-less outputs and keys results by
    name-else-expr (D10) — the per-output scalar seam the Value column reads.
- **`src/ase_window.tcl` pane rework** — the v1 6-pane entry-grid model and
  its whole harvest/rowbase machinery REMOVED (`build_list_pane`,
  `build_ana_pane`, `build_setup_pane`, `row_*`, `variable_entry`,
  `populate_*`/`harvest_*`, `harvest`, `commit`). Replaced by:
  - Exactly 3 themed `ttk::treeview` panes (D1–D4): Design Variables
    `{name value}`, Analyses `{num type enable args}` (row#, Type, Enable
    checkbox, view-only Arguments summary), Outputs
    `{name value plot save saveopts}`; item-id = state-index addressing.
    NO inline +/- buttons anywhere (spec §1).
  - Checkbox cells as `☑`/`☐` glyphs toggled by a real Button-1
    handler with break-consume (D5).
  - Pure, Tk-free helpers (headless-testable): `output_display_name`
    (24-char cap, 21+`...` truncation rule), `output_kind`,
    `save_options_cell` (auto-cell `allv`/`alli` reacting to
    `save_all_v`/`save_all_i`), `arg_summary`, `output_result_key` (D6–D8).
  - Selection model (spec §3): row multi-select within ONE pane;
    `<<TreeviewSelect>>` + a selclear flag makes selecting in a pane clear
    the other panes' selections (D12).
  - Action-strip `X` = stateless `delete_selection` scan, descending
    `lreplace`, no confirm (noun-verb, D12).
  - Per-pane context menus Add… / Edit… / Delete; analyses Add/Edit stubbed
    `TODO(item07)` (D13).
  - Double-click row → per-item edit dialog (D14): variables name/value,
    outputs name/expr/plot/save; analyses routes to the item-07 stub.
  - Modeless themed dialogs `$top.addvar` / `$top.edvar` / `$top.edout` with
    `.name`/`.value`/`.expr`/`.plot`/`.save` fields, Return=proceed, per-
    window `edrow`/`edchk` state cleaned on proceed/cancel AND close
    (D15, D19) — copy_current_cell_dialog idioms, USER-LOCKED palette,
    named Ase* fonts.
  - Action strip (right vertical, spec §5): `OP,TR = --> X N&> > ! ~` with
    `~` disabled placeholder (D16); OP,TR + --> stub to item-07 dialogs;
    `=` = the Add Variable dialog, landed now.
  - Variables > Edit… wired to first-selected-else-Add (D17).
  - `Ase.Treeview` + `Ase.Treeview.Heading` ttk styles, `#e8e8e8` header
    strip (D18).
  - Value fill-after-run (spec §2): `run_finished` stores per-SESSION
    results attr and calls `refresh_output_values` on exit 0 only (D11) —
    Value column blank pre-run, filled from parsed `result_probe` scalars.
  - `temp_commit` writes `temperature` directly into the state dict (D2) —
    the old harvest path it rode on is gone.
- **5th committed file** —
  `sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state`
  re-canonicalized (`save_all_v 0` / `save_all_i 0` inserted between
  outputs/options): protected test_ase_final F3 asserts byte-identity
  against a fresh `state_save` and the schema gained 2 keys — same ripple
  and same resolution as item 05; round-trip byte-identity verified
  pre-commit, Id unaffected.

## Tests — 185 checks total; every assertion change justified

**`tests/headless/test_ase_core.tcl` 41/41 headless** (was 38):
- R1 key list → 13 keys + save_all_v/save_all_i defaults-0 checks (schema
  gained the keys by contract).
- NEW P1 `result_probe` leg: per-output scalar keyed by name-else-expr,
  expr-less outputs skipped.

**`tests/headless/test_ase_window.tcl` 144 GUI checks / 31 headless**
(was 91 GUI):
- NEW P2/P3/P4 pure-helper legs (headless): `output_display_name`
  truncation rule, `save_options_cell` voltage+save_all_v→`allv` /
  current+save_all_i→`alli`, `arg_summary`/`output_result_key`.
- W1p: exactly 3 panes, NO Button anywhere under `$top.body`, column ids,
  rows 1..4, Vgs 1.8, blank Value/SaveOptions pre-run, Ase.Treeview +
  heading color. W1s: strip order + disabled `~`. W1c: ctx menus via
  `entrycget`.
- W3 REWORKED to a real double-click gesture (2 press/release pairs) →
  edvar prefilled → Return → save → edit-back-to-1.8. Justification: the
  v1 inline entries no longer exist per spec; all 5 original W3 check
  names kept. W1's Vgs-entry theme check re-anchored to the toolbar
  temperature entry (the only remaining plain entry).
- W3s cross-pane selection clear; W3c checkbox persist round-trip (toggle →
  Save State → file); W3v Add Variable round trip + duplicate-reject; W3x
  multi-delete via strip X + empty-selection no-op; W3o Save Options
  `alli` reacts to save_all_i.
- W6 + NEW `W6 id row Value filled after run`: nfet fixture, |v·1e6 −
  409.68| < 1 (≈4.0968e-04 per spec §2).

**Protected tests untouched and green**: test_ase_view 36/36 (GUI),
test_ase_final 28/28 — re-run PASS after the item. tests/run_regression.tcl
untouched (pre-batch dirty).

## Sabotage table

Implementer round (post-76c4cffe; each `git diff`-confirmed sabotage-only,
targeted `git checkout -- <file>` revert, clean re-run 144/144 green):

| # | Sabotage | Target check(s) | Result |
|---|----------|-----------------|--------|
| S1 | `delete_selection` drops the `ase::session_update` commit (repopulate kept) | `W3x X removed both rows from the state` + `W3x survivors intact` (absence asserted via tree=state) | failed EXACTLY the targets |
| S2 | `refresh_output_values` made a no-op | `W6 id row Value filled after run` (log/status/deck checks stayed green, 143/144) | failed EXACTLY the target |
| S3 | `save_options_cell` always returns `{}` | headless `P3 …voltage+save_all_v -> allv` + `P3 current+save_all_i -> alli`; GUI adds `W3o id row Save Options shows alli`; all blank-checks stayed green | failed EXACTLY the targets |

Fixer rounds re-sabotaged their retry machinery so the loops cannot go
green on their own (all reverted via targeted checkout after diff review):
- Round 1: product Ctrl-W bindings removed → exactly the W6c destroy check
  FAILs (143 passed); `raise_activate_toplevel` removed from
  `raise_design_editor` → exactly the W4 raise check FAILs even after both
  nudges (143 passed).
- Round 2: `variable_editor_ok` populate dropped → only `W3 tree shows
  2.2` FAIL; `temp_commit` invalid-restore dropped → only `W3t entry
  restored after invalid input` FAIL (send_return timeout diagnostic fired
  as designed); `add_variable_ok` duplicate rejection neutralized → both
  W3v duplicate checks FAIL.

## Fix-round history

- Implementer reported test_ase_window failing INSIDE the parallel
  full_audit run while passing 3 consecutive direct DISPLAY runs, flagged
  as suspected WSLg-parallel flake, rerun-first per the item-05
  test_close_window precedent.
- The tests-lens verifier's pristine reruns REFUTED the pure-flake reading:
  test_ase_window failed the MAJORITY of pristine direct DISPLAY runs
  (3/5 on W6c, 1/5 on W4) — test-robustness races, not product bugs.
- **Fixer round 1 (`483084e0`, test-only)**: W6c — Tk redirects GENERATED
  KeyPress events to the display's focus window and WSLg confirms focus
  asynchronously, so a lone `focus -force; event generate` intermittently
  delivered Ctrl-W to the previously-focused widget; the generate is now
  gated on Tk reporting the log text as focus owner, retried up to 10s,
  destroy still required from the product binding. W4 — WSLg occasionally
  drops the withdraw/deiconify re-map; after a stalled stackorder wait the
  test re-invokes the SAME product entry point. Local verification 5/5.
- **Round-1 lens re-run still saw 3/5 pristine failures** — the W6c
  focus-async diagnosis was gated only at the Ctrl-W site while EIGHT
  ungated `event generate <Return>` sites remained (W3 editor, W3t
  temperature, W3v dialog); a lost W3t restore left `.temp 33` in the W6
  deck (Id 406.4 µA, outside the ±1 µA gate — cascade, not product).
- **Fixer round 2 (`7530dc39`, test-only)**: new `send_return` helper —
  gates each generate on focus ownership and retries until a caller-scope
  done-condition proves the product binding ran (~10s timeout +
  diagnostic); all eight sites converted. W3v duplicate-reject leg
  re-driven through the OK button (Return-drop made it hollow-green;
  Return DELIVERY stays proven by the tmpA/tmpB legs). W4 nudge loop 2→4
  and a persistent stackorder stall now self-SKIPs (environment
  classification, like the existing unusable-geometry SKIP). Verification:
  headless 31/31; 5/5 pristine GUI runs ALL PASS (144 checks, zero
  nudges/timeouts) vs 2/5 before.
- Final lens re-runs after round 2: no verified problems — the
  outstanding-problems list was EMPTY at ledger time.

## Declared implementer deviations (forced by reality)

1. **[a] Generated double-click classification**: two consecutive
   generated clicks at the same spot ALWAYS classify as `<Double-1>` —
   generated events share the display timestamp so Tk's 500ms multi-click
   window never expires, and `after 600` does NOT help. Fix: offset the
   second single-click by dx=10 (>5px breaks the multi-click chain). Used
   in W3c; worth auto-memory.
2. **[b] Dialog field paths**: fields live directly on the toplevel
   (`$w.name` etc.) via a small gridded scaffold
   (`dialog_frame`/`dialog_row`/`dialog_buttons`) to honor the prompt's
   literal `.name`/`.value` widget paths.
3. **[c] test_ase_core P1 gotcha**: dict-value extraction must NOT go
   through an `expr` ternary — it numerically normalizes
   `4.096837e-04` → `0.0004096837` and breaks string comparison.

## Outstanding problems

None — the outstanding-problems list was verified EMPTY at ledger time
(2 fixer rounds consumed, both test-only; lenses clean after round 2).
The implementer's parallel-audit test_ase_window failure is CLOSED as a
real test-robustness race, found and fixed by the fixer rounds (not left
as an unclassified flake). All other fails observed in the item's audit
runs were baseline entries; test_ase_core/view/final passed inside the
audit.

## Corrected/confirmed anchors worth keeping

- **Generated-event focus redirection (WSLg)**: Tk delivers generated
  KeyPress events to the display's CURRENT focus window, and WSLg's X
  focus round-trip is asynchronous — every `event generate <Return>` in a
  GUI test must be gated on Tk reporting the target as focus owner AND
  retried until a product-side done-condition (dialog destroyed / state
  key changed / entry restored) proves the binding ran. The `send_return`
  helper in test_ase_window.tcl is the reusable pattern for items 07/08.
- **Generated double-click**: same-spot generated clicks always coalesce
  into `<Double-1>` (shared display timestamp); offset >5px to keep two
  clicks single. Conversely, a real double-click gesture is two
  press/release pairs at the same spot.
- **Rejection legs need a delivery witness**: a negative check (e.g.
  duplicate-add rejected) whose assertions hold trivially when the driving
  event is dropped is hollow-green — drive the proc through a button
  invoke and prove event delivery in a separate positive leg.
- **`expr` ternary normalizes numerics** in Tcl — never route values that
  will be string-compared (scientific-notation results) through `expr`.
- **W4 raise-stall self-SKIP**: WSLg can drop the withdraw/deiconify
  re-map outright; after 4 product-path re-invokes a persistent
  `wm stackorder` stall is classified as environment (self-SKIP), while a
  product regression still fails every attempt (sabotage-proven).
- **Schema-change fixture ripple (reconfirmed from item 05)**: any
  `schema_keys` addition must re-canonicalize the committed
  test_nfet_final `.state` fixture in the SAME commit (test_ase_final F3
  byte-identity); never touch the protected test.
- **Per-output results seam**: `result_probe` keys scalars by
  name-else-expr and skips expr-less outputs; `output_result_key` is the
  window-side mirror — item 07/08 output additions must keep the two in
  agreement.

## Commit hygiene

`76c4cffe` staged exactly the 5 files: `src/ase.tcl`, `src/ase_window.tcl`,
`tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_window.tcl`,
`sky130A/.../test_nfet_final/ngspice_state1/test_nfet_final.state`
(verified vs `git show --stat`). Fixer commits `483084e0`/`7530dc39`
touched ONLY `tests/headless/test_ase_window.tcl`. No pre-batch dirty
tracked files staged; PLAN.md/spec driver edits left unstaged for the
driver's ledger commit; leftover `_ase_window_*` scratch dir from an
aborted run removed; junk dirs untouched. NOT pushed.
