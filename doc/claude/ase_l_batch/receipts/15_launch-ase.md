# Receipt — item 15 launch-ase (round-4)

Verdict: **DONE** [x]. One feature commit (NOT pushed):
- `4112e1c9` feat(ase): Tools > Launch ASE-L — fresh untitled session for the
  current schematic. Exactly 6 files staged explicitly, no pre-batch dirty
  tracked file swept in (both rc files verified clean before staging, as the
  prompt required — they were last touched by item 09 at 05b2a708):
  - `src/ase.tcl`               +108/-2
  - `src/ase_window.tcl`        +2/-1
  - `src/xschem.tcl`            +1  (Tools menu entry)
  - `sky130A/cadence_style_rc`  +4
  - `gf180mcuD/cadence_style_rc`+7
  - `tests/headless/test_ase_launch.tcl` +238 NEW

Outstanding problems: **none** (empty problem list at ledger time; working tree
clean at HEAD for all 6 committed files). No fixer rounds.

Ledger-agent re-verification: headless legs re-run green this session (22/22,
`RESULT: ALL PASS`); commit `--stat` matches the 6-file claim; every helper the
launcher leans on exists (`schematic_cellview` library_defs.tcl:317,
`ase::session_getattr` ase.tcl:581, `ase::ui::window_for` ase_window.tcl:189,
`ase::session_key` ase.tcl:469, `ase::state_get` ase.tcl:50).

## What landed

Per PLAN item 15 deliverables 1-5, all pure Tcl (no C, no generated-file edits):

- **D1 — per-tech default models global.** `set_ne ASE_DEFAULT_MODELS {}` at
  ase.tcl:121 (empty in stock xschem). `ase::state_default` (ase.tcl:125) now
  reads it behind an `info exists` guard:
  `models [expr {[info exists ::ASE_DEFAULT_MODELS] ? $::ASE_DEFAULT_MODELS : {}}]`
  — byte-identical `{}` when unset, so all existing ASE tests are unaffected and
  item-02 newview seeding (via `library_new_view` → `state_default`) auto-inherits
  the tech default. Workarea rcs set it in the portable `$::VAR` form resolved at
  deck time by `ase::expand_path`:
  - `sky130A/cadence_style_rc:35` → `sky130.lib.spice` section `tt` via
    `$::SKYWATER_MODELS`.
  - `gf180mcuD/cadence_style_rc:41` → `sm141064.ngspice` section `typical` via
    `$::180MCU_MODELS` (verified the digit-leading `$::180MCU_MODELS` var name
    substitutes correctly). The rc carries an honest NOTE that a full gf180 run
    ALSO needs `design.ngspice`'s global-switch `.params` — an `.include`, not a
    `.lib` section, so outside this v1 models list; a scout-determined, documented
    default rather than a silent guess.
- **D2 — path→design resolver.** `ase::design_of_path {abspath}` (ase.tcl:641)
  reverses an abs cellview path to `{lib cell view}` by reusing
  `schematic_cellview` (library_defs.tcl) for library-root matching; `.sch`-only
  extension guard up front, clean `-code error` on non-schematic / outside-library
  / empty-path. `ase::design_of_current` (ase.tcl:660) wraps it around
  `xschem get schname`, reporting the honest error via `ciw_echo` and returning
  `{}` on a symbol/unsaved/foreign view.
- **D3 — Tools > Launch ASE-L.** Menu entry at `src/xschem.tcl:14667`, inserted
  between "Net highlight styles..." and the following separator in the per-window
  `.menubar.tools` build. New procs:
  - `ase::session_for_design {lib cell view}` (ase.tcl:672) — finds an existing
    session keyed on the design (raise-not-duplicate lookup).
  - `ase::new_session {lib cell schview}` (ase.tcl:692) — registers a BLANK
    untitled session (`path {}`, `state`=`state_default` carrying the tech models +
    empty vars/analyses/outputs, `saved == state` so NOT dirty until edited,
    `untitled 1`, `metaview (unsaved)`, `saveview ngspice_state1`). Distinct from
    `open_state`'s file-load path.
  - `ase::launch_for_current` (ase.tcl:709) — resolve design → raise existing
    session (under X: deiconify/raise/focus via `window_for`) or create+open a
    fresh one; all Tk behind the `has_x` guard, returns the session key (or `{}`
    when the current view is not a schematic).
- **D4 — untitled title/status + Save-As.** `ase_window.tcl` `refresh_title`
  appends `" (unsaved)"` iff the `untitled` attr is set (no-op for from-file
  sessions); Save-As View field prefills from `session_getattr saveview` (defaults
  to `$mview`, unchanged for from-file sessions), so an untitled session's Save
  State lands as an `ngspice_state1` view via the item-02/07 creation path.
- **D5 — tests.** `tests/headless/test_ase_launch.tcl` (NEW, auto-discovered by
  full_audit.sh; NOT registered in the pre-batch-dirty run_regression.tcl).

## Tests

`tests/headless/test_ase_launch.tcl` — **22 checks headless, 38 with the GUI
legs**. Headless arm re-run green by the ledger agent this session
(`RESULT: ALL PASS (22 checks)`, GUI legs self-SKIP without DISPLAY).

- **L1-L3** resolver: `.sch` path → `{lib cell view}`; `.sym` path throws;
  outside-library path throws.
- **L4-L5** `state_default` models honor `::ASE_DEFAULT_MODELS` (set → present;
  unset → `{}`, no throw) — the info-exists guard both ways.
- **L6** launch registers a fresh untitled session: models == default, vars/outputs
  empty, NOT dirty, design bound to the schematic.
- **L7** raise-not-duplicate: second launch returns the SAME key, creates no new
  session; edit-then-relaunch PRESERVES the edit and keeps the session dirty
  (strengthened past the prompt's bare-recreate check — see deviation).
- **L8** symbol current view → launch returns `{}`, registers nothing.
- **G1-G2** (GUI, DISPLAY-guarded, real Tools menu invoke): exactly one `.ase`
  toplevel with sky130 default models + 4 state_default analyses rows + empty
  vars/outputs panes + `(unsaved)` title/status; second invoke raises, no
  duplicate window/session.

Implementer's full_audit: 199 pass / 19 fail / 1 timeout / 1 skip, WIREEDIT PASS.
All fails a subset of the PLAN baseline EXCEPT three confirmed WSLg flakes, all
unrelated to the change and all green on direct re-run:
- `test_ase_view` — WSLg focus flake in its double-click GUI legs; passes 36/36
  direct. The `state_default` change is byte-identical when
  `::ASE_DEFAULT_MODELS` is unset (repo rc leaves it unset in a plain audit).
- `test_remap` — WSLg focus flake (`event generate` on `.drw` not landing);
  passes direct; unrelated to menu/ase changes.
- `test_ase_window` — TIMEOUT only at the implementer's tightened
  `AUDIT_TIMEOUT=90s`; passes standalone 155/155 within the default timeout.

All nine protected ASE/wave suites
(test_ase_{core,view,window,dialogs,final,interact,plot,persist},
test_wave_viewer) pass standalone. LibMgr `open_state` file-load path and item-02
view creation are untouched (new_session is a separate blank-session entry;
state_default is byte-identical when the global is unset).

## Sabotage table (three; each failed EXACTLY its target, then reverted)

| # | Sabotage | Target | Failed exactly? |
|---|----------|--------|-----------------|
| S1 | `state_default` models default reverted to `{}` (src/ase.tcl) | L4 + L6 default-models checks (state_default/session models == `::ASE_DEFAULT_MODELS`); G1 models under X. L5 (unset arm) stayed green | yes |
| S2 | drop the `.sch` extension guard in `design_of_path` (src/ase.tcl) | L2 + L8 symbol-rejection checks (symbol path must throw / launch must return `{}` and register nothing). L1/L3 green | yes |
| S3 | remove the `session_for_design` raise arm (always `new_session`) (src/ase.tcl) | L7 raise-preserves-edit (edit survives relaunch, session stays dirty) + G2 duplicate-window under X. L6/G1 green | yes |

Revert mechanism (documented deviation, same guarantee): no committed baseline
existed at sabotage time, so reverts were precise reverse-Edits verified
sabotage-free by grep + diff-stat + green re-run, rather than
`git checkout -- <file>` per the receipt-02 commit-first flow.

## Fix-round history

None — single feature commit, no verifier-raised problems, no fixer commits.

## Implementer deviations (accepted)

- **L7 strengthened past the prompt.** The untitled session key is DETERMINISTIC
  (`session_key lib cell (unsaved)`), so a bare re-`new_session` overwrites the
  same key — key-identity + session-count alone cannot distinguish raise from
  recreate headless. L7 adds an edit-then-relaunch SURVIVAL check so S3 (drop the
  raise arm) is catchable headless. Documented.
- **Sabotage revert via reverse-Edit** rather than `git checkout -- <file>` (no
  committed baseline at sabotage time); each verified sabotage-only before/after.

## Corrected anchors worth keeping (verified at 4112e1c9)

- Tools menu entry site: `src/xschem.tcl:14667` (`.menubar.tools add command`,
  after "Net highlight styles..." / before the separator — the ~14665-14667
  prompt anchor held).
- `ase::state_default` now at `src/ase.tcl:125` (shifted by the `set_ne
  ASE_DEFAULT_MODELS {}` insert at :121); the models line is the only change
  inside it. Launcher procs: `design_of_path` :641, `design_of_current` :660,
  `session_for_design` :672, `new_session` :692, `launch_for_current` :709.
- rc default-models lines: `sky130A/cadence_style_rc:35`,
  `gf180mcuD/cadence_style_rc:41` (both in the portable braced `$::VAR` form,
  resolved at deck time by `ase::expand_path`; both files clean pre-stage).
- The `state_default` default-models edit is **byte-identical to before whenever
  `::ASE_DEFAULT_MODELS` is unset** — the reason every pre-existing ASE test and
  the item-02 newview seed path are unaffected, and why a plain (non-workarea)
  audit sees no behavior change.
- An untitled launch is **NOT dirty** (`saved == state` in `new_session`) — so
  item-16's close-prompt must NOT fire on an untouched launch; the dirty baseline
  is the initial default state.
- gf180 caveat: `sm141064.ngspice` + `typical` is the models `.lib`, but a real
  gf180 op sim ALSO needs `design.ngspice`'s global-switch `.params`
  (`sw_stat_global`, `mc_skew`, …) — an `.include`, outside the v1 `models` list;
  noted in gf180mcuD/cadence_style_rc for a future `includes` seed.
