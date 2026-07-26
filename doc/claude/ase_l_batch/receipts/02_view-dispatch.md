# Receipt — item 02 view-dispatch

Verdict: **DONE** ([x] in PLAN.md ledger).
Commit: `307eaa64c3614e` — `feat(ase): make ngspice_state1 a first-class view
(dispatch + creation)`. NOT pushed (batch policy).

## What landed

`ngspice_state1` is a first-class view. Enumeration/resolution
(`cell_views` / `cellview_resolve` / `cellview_path`) already discovered
`<cell>/ngspice_state1/<cell>.state` — confirmed by probe, untouched.
What changed (6 files, +361/−15):

- **Dispatch seam** — `libmgr::view_handler {view {path {}}}`
  (src/library_manager.tcl): datafile extension is AUTHORITATIVE when the
  resolved path is known (`.state` → `ase::open_state`, else `editor`);
  `ngspice_state*` name glob decides when no path is given (D2). This proc is
  the named item-02/03 seam. `libmgr::open_view` diverts non-editor views
  before the xschem-load arms — no action-log line, no
  `after 120 force_window_repaint` (D4); `libmgr::open_view_ro` diverts to the
  plain open BEFORE `xschem set readonly 1`, so the current schematic window
  is never wrongly marked read-only (D3; the v0 viewer is already read-only).
- **Creation** — `newview_dialog` combobox gains `ngspice_state1` (D5);
  `library_new_view` (src/library_defs.tcl) seeds `ngspice_state*` views via
  `ase::state_save` of `ase::state_default` with
  `design {lib <lib> cell <cell> view schematic}` — NEVER an empty file;
  `saveform::resolve_target` maps `ngspice_state*` → `.state`, prefill uses
  the type as the canonical view name (src/save_as_form.tcl).
- **Descend routing** (src/xschem.tcl) — `hi_descend_enum_views` types
  `.state` files as `ngspice_state`; `hi_descend_do` intercepts state rows
  before the target switch and routes to `ase::open_state` (target/iter/mode
  meaningless, intercepted before any window opens); `hi_descend_finish`
  refuses non-schematic/symbol vtypes outright with a `ciw_echo` error
  (belt-and-suspenders, D1 = route-not-refuse at the shared entry).
- **`ase::open_state` v0** (src/ase.tcl) — read-only `textwindow` on the
  .state file + `ciw_echo` notice, `has_x`-guarded; the single Tk-guarded GUI
  seam of ase.tcl (header carve-out amended). NAME + SIGNATURE
  `ase::open_state <lib> <cell> <view>` are the item-03 contract — item 03
  replaces only the body.
- **Confirmed no-change surfaces** (D7): cell_views / cellview_resolve /
  cellview_path, `libmgr::tracked_views` / `git_target` (view-name agnostic,
  V11 confirms with a real git repo), full_audit.sh, run_regression.tcl
  (pre-batch dirty, never staged).

## Test

`tests/headless/test_ase_view.tcl` — **36 checks total**: 32 headless
(V1–V11: discovery, seed validity + byte-stability, dispatch-table unit
checks incl. path-authoritative legs, open_state return codes, descend
enum/routing/refuse, save-as mapping, git plumbing) + GUI legs G1–G3
(real View-pane double-click, Open-read-only divert with `readonly`
unchanged, newview combobox values). 36/36 under DISPLAY; 32/32 headless
printing `gui legs skipped (no DISPLAY)` (deliberately NOT the full-audit
SKIP strings). `test_ase_core` still 33/33 (ase.tcl was touched).

## Sabotage table

| # | Sabotage | Target check(s) | Result |
|---|----------|-----------------|--------|
| S1 | library_manager.tcl: view_handler returns `editor` for the ngspice_state* glob AND the .state path leg | V5 dispatch-table unit checks | failed EXACTLY the 2 V5 legs |
| S2 | library_defs.tcl: library_new_view state branch reverted to `library_write_empty_cellfile` | V3 design lib/cell/view + V4 byte-stability | failed EXACTLY 3 V3 design legs + V4 |
| S3 | xschem.tcl: `.state → ngspice_state` enum mapping dropped, old binary expr restored | V7 enum type + V8 routing | failed EXACTLY V7 + 4 V8 routing legs; V9 stayed green (finish guard independent) |

Each: `git diff` confirmed sabotage-only, targeted `git checkout -- <file>`
revert, clean re-run green; tree byte-identical to the commit afterwards.

## Audit / fix rounds

- full_audit: persistent fails a STRICT SUBSET of the PLAN.md baseline
  (baseline entries test_altf5_ciw, test_cadence_window_hop_log,
  test_palette, test_key_graph_context happened to pass this run); wireedit
  pseudo-target PASS; test_ase_view + test_ase_core PASS inside the audit.
  Three transient WSLg flakes (test_add_wire_label "X connection broken",
  test_alt_transform_group_0116 core-dump timeout, test_graph_context
  wheel-zoom) each PASSED on individual re-run → zero new fails.
- Verifier lenses (hygiene/tests/spec) returned no problems — **no fixer
  rounds were needed** (outstanding-problems list empty at ledger time).
- Declared implementer deviations (all benign, documented):
  1. full_audit run as 9 sequential explicit-args chunks + wireedit
     pseudo-target instead of one background run (tool 10-min foreground cap);
     same script/flags/classification.
  2. G1 replays the double-click as two real ButtonPress/ButtonRelease-1
     pairs at the row bbox center — Tk hard-rejects
     `event generate <Double-1>` ("Double, Triple, or Quadruple modifier not
     allowed"); Tk's click-count machinery fires the shipping `<Double-1>`
     binding (gesture-test-full-sequence lesson holds).
  3. Sabotage runs executed headless (`env -u DISPLAY`) for exact fail-set
     attribution, and after the single commit (the prescribed git-checkout
     revert flow requires the committed baseline).

## Outstanding problems

None — verified clean (empty outstanding-problems list at ledger time).

## Corrected/confirmed anchors worth keeping

- `libmgr::open_view` library_manager.tcl:432 is the single open funnel
  (dbl-click :136 cell / :137 view pane, ctx-menu Opens :183/:199,
  `open_view_ro` :558); `newview_dialog` :1204 with combobox :1214;
  `tracked_views` :333, `git_target` :627 (view-agnostic, no change).
- xschem.tcl descend anchors drifted from the PLAN sketch:
  `hi_descend_enum_views` proc :5682 (type-inference line :5697),
  **`hi_descend_do` :5870 with the target switch at :5881 is the right
  intercept point** (shared dialog+scripted entry, before any window opens —
  not `hi_descend_finish` :5762/:5764, which now only carries the defensive
  refuse); lib/cell derivation idiom at :5691-5693.
- `textwindow {filename {ro {}}}` xschem.tcl:11628 — non-empty `ro` arg is
  what makes it read-only (omits Save).
- `library_new_view` library_defs.tcl:701 (seed call :709,
  `library_write_empty_cellfile` :569); `saveform::resolve_target` ext map
  save_as_form.tcl:47, prefill canonical view name :71 — C only ever passes
  type schematic|symbol today, so resolve_target is tested directly.
- Codebase doctrine reaffirmed: a view's editor type comes from its
  `<cell>.<ext>` datafile, not its label (library_defs.tcl:217-219) —
  extension-first dispatch makes both mismatch directions safe.
- Item-03 contract: `ase::open_state {lib cell view}` name + signature stable;
  body (v0 textwindow viewer) is what item 03 replaces. Dispatch from LibMgr
  and hi_descend already lands there — item 03 needs no dispatch work.

## Commit hygiene

Staged exactly the prescribed 6 files: `src/library_manager.tcl`,
`src/library_defs.tcl`, `src/xschem.tcl`, `src/save_as_form.tcl`,
`src/ase.tcl`, `tests/headless/test_ase_view.tcl` (verified against
`git show --stat 307eaa64`). No pre-batch dirty tracked files, no generated
files, no scratch leftovers. Not pushed.
