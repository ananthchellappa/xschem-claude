# Receipt — item 05 ui-shell (ROUND 2, UI v2 / ADE-L parity)

Verdict: **DONE** ([x] in PLAN.md ledger).
Commit: `6230ca560c1d1fe68a2dc2857d4fe540544b15b8` — `feat(ase): ADE-L parity
chrome — v2 menus, temp/.temp, log window, Design Window raise fix`. NOT
pushed (batch policy). ONE commit, 5 files, +735/−160 (verified vs
`git show --stat 6230ca56`).

## What landed

- **`src/ase.tcl`** — `temperature` in `schema_keys` (after `rundir`, D1) +
  `state_default` 27; `render_deck` always emits `.temp <T>` after the
  `.options` loop / before `.save` (D2), clean
  `ase: temperature must be numeric` error on garbage; `ase::run_deck`
  factored out of `ase::run` (behavior unchanged) + new `ase::run_existing`
  (D8): runs the EXISTING `<rundir>/<cell>.spice` — no re-netlist, no
  current-schematic guard (works with the design window closed), clean
  "run Simulation > Netlist > Recreate first" error when the artifact is
  absent.
- **`src/ase_window.tcl` chrome rework** —
  - Title `Analog Sim Environment <design cell>` + ` *` dirty marker kept
    (D4; falls back to the session cell when `design` is empty). Window NAME
    stays `.ase<N>`; allocator/notify untouched.
  - Toolbar temperature entry + `°C` label; commit-time numeric validation
    (D3): garbage restores the entry from state + `ciw_echo`, harvest guarded
    so no pane commit can ever store a half-typed value.
  - Bottom status bar `<win#> | Status: <S> | T=<T> C | Simulator: <sim> |
    State: <view>` as per-segment labels + `status_text`/`refresh_status`
    (D6); `set_status` keeps its 4 API states mapping to orange Running /
    Green Ready / red Error / themed-panel Ready (D5). v1 bottom button bar
    REMOVED (D11) — invocation paths are the Simulation menu until the
    item-06 action strip.
  - Menu tree v2 VERBATIM from spec: Launch + Tools disabled cascades;
    Session = Design Window / Load State / Save State / Close (D7: wired to
    the EXISTING procs + `TODO(item07)` for the dialog upgrades — stubbing
    would have regressed working save/load; NO Revert menu entry, the proc
    survives for W7); Setup/Analyses/Variables/Outputs stubs via
    `ase::ui::todo_stub` with `TODO(item06/07/08)` (D9); Simulation =
    Netlist > Recreate/Display + Netlist and Run + Run (`run_existing`) +
    Stop + Log + Options stub; Results present-but-disabled incl. the
    Annotate submenu (D10).
  - Log pane REMOVED; run opens a live-follow log toplevel `$top.logwin`
    (child of the session window, reuses the v1 `execute(data,$id)` trace
    machinery; Ctrl-W / Ctrl-Shift-W close via toplevel bindtags;
    Simulation > Log raises-or-recreates from the live execute buffer with
    loglen resync, else the backend log file) (D12).
  - `ase::theme` + `ase::ui::apply_theme` centralize the USER-LOCKED palette
    (panels `#f2f2f2`, tables/entries `#ffffff`, headers `#e8e8e8`, accent
    `#8b0000`) + named fonts AseLabelFont (Arial 10 bold) / AseEntryFont
    (Arial 13) / AseMonoFont (Courier 13) + `option add
    *TCombobox*Listbox.font`; applied at build/populate/row_add/log-open —
    no stock-Tk leftovers (D13). **Carve-out (document per prompt):
    `textwindow` (Netlist > Display) stays stock — it is SHARED infra;
    retheming it would restyle every non-ASE use.**
- **BUGFIX Session > Design Window (§4, scout-reproduced)** — root cause: the
  fresh-open arm's `xschem load -gui` reuses the pristine untitled MAIN
  window but never deiconified/raised/focused it, so with ASE/LibMgr/CIW
  stacked above nothing visibly happened; v1's W4 asserted only schname +
  window list (green-but-hollow on visibility). Fix: raise sequence factored
  into `ase::ui::raise_design_editor`, called by the already-open arm AND
  re-called after the fresh `xschem load -gui` arm;
  `after 120 force_window_repaint` kept (WSLg issue 0052).
- **5th committed file (deviation, justified)** —
  `sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state`
  re-canonicalized (one inserted line `temperature 27`): protected
  test_ase_final F3 asserts BYTE-IDENTITY of the committed fixture against a
  fresh `state_save`, and the schema gained a key; editing the protected
  test was forbidden, so the fixture follows the new canonical schema
  (F1/F2/F10 unchanged; Id unaffected — 27 is ngspice's default).

## Tests — 129 checks total; every assertion change justified

**`tests/headless/test_ase_core.tcl` 38/38 headless (was 33)**:
- R1 key list → 11 keys + NEW `R1 temperature default 27` — schema gained
  the key by contract.
- D1 golden deck: line `.temp 27` inserted between `.options savecurrents`
  and `.save -i(v1)` — the deck legitimately changed (D2 placement).
- NEW D4 legs: custom `.temp 33.5`, non-numeric errors cleanly, missing key
  still emits `.temp 27`.
- R2/R4 byte-stability untouched (both compare sides use the new saver).

**`tests/headless/test_ase_window.tcl` 91 checks green under WSLg DISPLAY
(was 53)**:
- W1 title → exactly `Analog Sim Environment nfet_clean` (spec v2 title);
  NEW no-log-pane check (`$top.log` gone — pane removed by contract); NEW
  temperature-entry-shows-27; NEW theme checks (panel bg, entry
  white+AseEntryFont, dark-red pane-title accent, named fonts exist).
- NEW W1m menu-tree leg: 9 cascade labels in order + disabled states
  (Launch/Tools/Results entries).
- W3 mechanics kept via menu invoke (D7 kept Save State working); NEW W3t
  temperature round-trip + non-numeric validation via REAL Return events
  (deviation [d]: named W3t rather than W3).
- W4 keeps BOTH v1 checks (current schematic + window list) + NEW stacking
  regression gate `W4 design toplevel raised above the ASE window` with a
  retry loop — the §4 bugfix gate.
- W5/W6/W7 re-driven through the Simulation menu entries (v1 buttons removed
  per D11); W6 reads `$top.logwin.t` + NEW `W6 deck contains .temp 27`.
- NEW W6b hand-edit-sentinel leg: sentinel appended to the netlist artifact
  survives menu Run AND appears in the deck — the must-NOT-re-netlist proof.
- NEW W6c: Ctrl-W (full Tk sequence) destroys the log toplevel; Simulation >
  Log reopens it on the log file.
- NEW headless T1: `run_existing` errors cleanly without a netlist artifact.

**Protected tests untouched and green**: test_ase_view 36/36,
test_ase_final 28/28. tests/run_regression.tcl untouched (pre-batch dirty).

## Sabotage table (run post-commit; each `git diff`-confirmed sabotage-only,
targeted `git checkout -- <file>` revert, clean re-runs green 38/38 + 91/91)

| # | Sabotage | Target check(s) | Result |
|---|----------|-----------------|--------|
| S1 | deleted the `.temp` emission block in `ase::backend::ngspice::render_deck` (src/ase.tcl) | test_ase_core `D1 golden deck` + all 4 `D4 *` legs (env -u DISPLAY: 5 FAILED/33 passed); test_ase_window `W6 deck contains .temp 27` (DISPLAY: 1 FAILED/90) | failed EXACTLY the targets |
| S2 | removed the post-load `ase::ui::raise_design_editor` call in `design_window` (src/ase_window.tcl — revert to v1 fresh-open behavior) | `W4 design toplevel raised above the ASE window` (1 FAILED/90); both v1 W4 checks STAYED GREEN — proves the new check covers the previously hollow spot | failed EXACTLY the target |
| S3 | removed the Entry branch from `ase::ui::apply_theme` (src/ase_window.tcl) | `W1 Vgs entry white + AseEntryFont` (1 FAILED/90); all other theme checks stayed green | failed EXACTLY the target |

## Audit / fix rounds

- Audit-log caveat, recorded honestly: the implementer's background
  full_audit was still in flight at forced-report time (18/… all-pass
  observed); its on-disk log (`full_audit_item05.log`) and the tests-lens
  verifier's rerun log (`verify_full_audit.log`) were BOTH cut short when
  their sessions ended (33 resp. 36 of ~230 tests). Within the overlap, the
  implementer's run showed one non-baseline FAIL
  (`test_close_window_restores_prev_tab`) which PASSED in the verifier's
  rerun (flake); every other observed result was baseline-consistent and all
  4 test_ase_* PASSED inside both attempts.
- **Ledger re-ran `tests/headless/full_audit.sh`** (2026-07-21, background;
  log `…/scratchpad/ledger_full_audit_item05.log` in the session scratchpad)
  to close that gap, but the ledger was ALSO forced to report before it
  finished — at 84/214 tests: all 4 test_ase_* PASS inside this run;
  `test_close_window_restores_prev_tab` PASSED (confirming the flake);
  fails observed so far = 7 baseline entries (altf5_ciw,
  cadence_descend_newwin_ro, cadence_drag, ciw, crossview_paste,
  fluid_editing, hi_descend) PLUS `test_deselect_mode` and
  `test_hover_highlight`, which are NOT in the baseline list. Both are pure
  editor gesture tests of the known WSLg geometry-flake class (item 05
  touched only src/ase.tcl / src/ase_window.tcl / ASE tests — no editor C
  code, no non-ASE bindings), so flake is the likely reading, NOT verified.
  **DRIVER ACTION before the final report: read the completed log
  (SUMMARY line at the end) and rerun test_deselect_mode +
  test_hover_highlight individually to classify flake-vs-real.**
- Verifier lenses (hygiene/tests/spec) returned no verified problems —
  **no fixer rounds** (outstanding-problems list empty at ledger time).
- Declared implementer deviations (all forced by reality):
  1. **[a] Raise contract**: the prompt's bare `wm deiconify`/`raise`/
     `focus` sequence is a NO-OP under WSLg/Weston (probed: `wm stackorder`
     never changes) — used the shared `raise_activate_toplevel` helper
     instead (withdraw/deiconify re-map, the documented issue-0054 idiom
     LibMgr/CIW already use); W4's retry loop extended to 100×50ms because
     the re-map takes ~2 s to appear in `wm stackorder`.
  2. **[b]** 5th committed file — the state-fixture re-canonicalization
     (see What landed).
  3. **[c]** Bugfix found by test: bare `open` inside `namespace eval
     ase::ui` resolves to `ase::ui::open` (the window-open proc) —
     `show_log` must use `::open`.
  4. **[d]** Temperature W3 legs named `W3t`.

## Outstanding problems

None VERIFIED (empty outstanding-problems list at ledger time; the
tests-lens verifier re-ran full_audit per RUNBOOK and reported clean).
One open bookkeeping caveat, not a verified problem: no single COMPLETE
post-item-05 full_audit log exists on disk (implementer, verifier and
ledger runs were each cut short by forced session ends); the ledger's
in-flight run showed 2 unclassified non-baseline FAILs
(test_deselect_mode, test_hover_highlight — WSLg-flake-suspect, unrelated
to item-05 code paths). Driver: read the completed
ledger_full_audit_item05.log + rerun those two tests before the final
report.

## Corrected/confirmed anchors worth keeping

- **WSLg raise idiom**: bare `wm deiconify` + `raise` + `focus` does NOT
  restack a toplevel under WSLg/Weston; the working idiom is
  `raise_activate_toplevel` (withdraw/deiconify re-map, issue 0054) — and
  even then `wm stackorder` reflects the re-map only after ~2 s, so stacking
  tests must retry-poll (W4 uses 100×50ms).
- **Tcl namespace shadowing**: inside `namespace eval ase::ui`, bare `open`
  resolves to a proc named `ase::ui::open` when one exists — shadowed
  builtins need explicit `::open` (bit `show_log`).
- **Protected-fixture byte-identity ripple**: any state-schema change
  ripples into committed `.state` fixtures that protected tests assert
  byte-identical (test_ase_final F3) — re-canonicalize the fixture with the
  new saver in the SAME commit; never touch the protected test.
- **D7 conflict resolution** (item-detail directives collided): Session >
  Save/Load State wired to the EXISTING procs; the Save-As/browser dialog
  upgrade is item 07 (`TODO(item07)` at the sites). Revert menu entry
  dropped (v2 tree is verbatim) but `ase::ui::revert_state` proc kept for
  W7/item 07.
- **D8 Run-existing**: needs no current-schematic guard because it never
  netlists — by design it works with the design window closed, and hand
  edits to `<rundir>/<cell>.spice` survive (W6b sentinel proves it).
- **D13 carve-out**: `textwindow` is shared infra and stays stock-Tk —
  retheming it would restyle every non-ASE use; items 06-08 must not
  "fix" this.
- **Log window parenting**: `$top.logwin` is a child of the SESSION toplevel
  (dies with it; not a child of `.` so `.ase*`-globbing helpers don't see
  it); Ctrl-W fires from any child via toplevel bindtags.
- **test_close_window_restores_prev_tab** can flake FAIL in one audit run
  and pass the next (seen implementer-run FAIL → verifier + ledger runs
  PASS); it is NOT in the PLAN.md baseline — treat a solitary FAIL there as
  rerun-first, not as an instant stop condition.

## Commit hygiene

Staged exactly the 5 files: `src/ase.tcl`, `src/ase_window.tcl`,
`tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_window.tcl`,
`sky130A/xschem_libs/sky130_tests/test_nfet_final/ngspice_state1/test_nfet_final.state`
(verified vs `git show --stat 6230ca56`). No pre-batch dirty tracked files
staged (PLAN.md preflight list respected; PLAN.md/spec driver edits left
unstaged for the driver's ledger commit), no generated files, no junk dirs.
NOT pushed.

## Driver resolution of the audit caveat (post-item, 2026-07-21)

test_deselect_mode + test_hover_highlight re-run 2x each directly: PASS all 4
runs — WSLg flakes confirmed, NOT item-05 regressions. test_ase_{core,view,
window,final} re-run: all PASS. Caveat closed; item 06 launched on this basis.
