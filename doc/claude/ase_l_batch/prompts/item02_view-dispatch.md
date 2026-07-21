# Item 02 — view-dispatch (P2 of doc/claude/specs/ase_l.md)

You are the IMPLEMENTER. Repo: /home/qflow/dev/xschem/claude_1/xschem, branch
fluid-editing. Read doc/claude/ase_l_batch/RUNBOOK.md and the spec
doc/claude/specs/ase_l.md first. Item 01 landed (commit 20cc4df9): src/ase.tcl
provides ase::state_default / state_load / state_save / backends /
backend::ngspice::* / netlist / run / wait — read it; its procs are your
contract. Its test is tests/headless/test_ase_core.tcl (copy its harness
idioms: check/check_true procs, scratch `_ase_view_[pid]` dir under cwd,
scratch library.defs + `set ::XSCHEM_LIBRARY_DEFS` +
`set ::library_registry_defs_only 1`, final `RESULT: ALL PASS (N checks)` /
`RESULT: <n> FAILED` banner + `exit`).

## Goal

Make `ngspice_state1` a first-class view: enumerated and resolved by the
existing machinery (confirmed — no change), dispatched to ASE instead of the
schematic/symbol editor at every open path (LibMgr double-click, both ctx-menu
Opens, Open read-only, hi_descend), and creatable (LibMgr New-view dialog +
library_new_view seeding a VALID serialized default state — never an empty
file). Ship `ase::open_state` v0 (read-only textwindow + ciw_echo notice);
item 03 replaces its body — the NAME AND SIGNATURE `ase::open_state <lib>
<cell> <view>` are the item-03 contract, keep them stable.

## Verified anchors (scout re-checked 2026-07-20; all target files git-clean)

- src/library_defs.tcl:
  - `cellview_resolve` :209 (glob fallback :222), `cellview_path` :235,
    `cell_views` :261 — **NO CHANGE**. Scout probe (headless, scratch lib with
    `<cell>/ngspice_state1/<cell>.state`): `xschem cell_views` lists
    `ngspice_state1`; `xschem cellview_path lib/cell ngspice_state1` returns
    the .state file. Discovery/resolution work as-is.
  - `library_write_empty_cellfile` :569; `library_new_view` :701 with the
    seed call at :709 — CHANGE (creation seeding, below).
- src/library_manager.tcl:
  - `libmgr::open_view` :432 — the single funnel: double-click binds :136
    (cell pane) and :137 (view pane), ctx-menu Opens :183 and :199,
    `libmgr::open_view_ro` :558. CHANGE (dispatch + ro divert).
  - `libmgr::ctx_new_view` :1146 → `do_new_view` :1154 → library_new_view;
    `newview_dialog` :1204, editor-type combobox :1214. CHANGE (combobox).
  - `libmgr::tracked_views` :333, `libmgr::git_target` :627 — **NO CHANGE**:
    both walk cellview_path/glob output, view-name agnostic (verified by
    reading; test V11 confirms with a real git repo).
- src/xschem.tcl (clean, NOT in the pre-batch dirty list):
  - `hi_descend_enum_views` proc :5682, type-inference line :5697
    (`.sch → schematic else symbol`) — CHANGE (`.state → ngspice_state`).
  - `hi_descend_do` :5870 (shared dialog+scripted entry; target switch at
    :5881) — CHANGE (routing intercept, decision D1).
  - `hi_descend_finish` proc :5762, binary branch :5764 — CHANGE (defensive
    refuse, D1).
  - `textwindow {filename {ro {}}}` :11628 — non-empty `ro` arg omits the
    Save button (that is the "read-only" textwindow).
  - source order (:14067-14112): library_defs → library_manager →
    save_as_form → ase.tcl → … → ciw.tcl. All calls are runtime, order is
    fine.
- src/save_as_form.tcl: `saveform::resolve_target` ext mapping :47,
  `saveform::prefill` canonical view name :71 — CHANGE (type mapping).
  Note: C only ever passes type schematic|symbol today; this is the
  spec-mandated future-proofing — test resolve_target directly (headless).
- src/ase.tcl — CHANGE: add `ase::open_state` (D6) and amend the file-header
  "NO Tk anywhere" claim to carve out open_state as the single Tk-GUARDED GUI
  seam.
- tests/headless/full_audit.sh — **DO NOT EDIT**: it auto-discovers
  test_*.tcl; the default invocation (`--pipe -q --nolog --script`, no
  --nogui) is exactly what test_ase_view needs (GUI legs run when DISPLAY is
  set, self-SKIP otherwise).

## Scout decisions (binding)

- **D1 descend routing — route, not refuse (plus a belt-and-suspenders
  refuse).** Intercept in `hi_descend_do` right after the
  `hi_descend_pick_view` row check (before the `switch -- $target` at :5881):
  if `[lindex $row 1] eq {ngspice_state}`, derive lib/cell the same way the
  enum does (:5691-5693: `set rel [rel_sym_path [abs_sym_path
  [hi_descend_inst_sym $instname]]]` + `regexp {^([^/]+)/([^/]+)$}`; on regexp
  miss ciw_echo error + return 0 — cannot happen for rows the enum built, they
  only arise on the OA branch) and `return [ase::open_state $lib $cell
  [lindex $row 0]]`, ignoring target/iter/mode (meaningless for a state
  view). Rationale: the shared entry covers dialog + scripted + all three
  targets BEFORE `hi_descend_newwin` opens a window that would be orphaned.
  ADDITIONALLY, at the top of `hi_descend_finish`: `if {$vtype ni {schematic
  symbol}} { ciw_echo "hi_descend: view type '$vtype' does not descend; open
  it from the Library Manager" error; return 0 }` so no future caller can fall
  into the binary descend (the anchor's literal requirement).
- **D2 dispatch key — datafile extension authoritative, name glob fallback.**
  `proc libmgr::view_handler {view {path {}}}` returns the handler token:
  when `$path` is non-empty, `.state` → `ase::open_state`, `.sch`/`.sym` →
  `editor`; otherwise (no path) `ngspice_state*` name glob → `ase::open_state`,
  else `editor`. Rationale: the codebase doctrine is that a view's editor type
  comes from its `<cell>.<ext>` datafile, not its label
  (library_defs.tcl:217-219); extension-first makes BOTH mismatch directions
  safe (a view named `mystate` holding a .state never reaches `xschem load`; a
  view named `ngspice_state1` holding a .sch still opens in the editor). The
  no-path form exists for the unit check and returns exactly what the item
  demands (`ngspice_state1`→ase::open_state, schematic/symbol→editor).
- **D3 open_view_ro divert.** In `open_view_ro`, after `lassign $lcv`, look up
  the handler (resolve the path first, same as open_view, or just pass the
  view name); if not `editor`, call `libmgr::open_view` and RETURN before the
  `xschem set readonly 1` + its log_action line — those would wrongly mark the
  CURRENT schematic window read-only. The v0 viewer is already read-only.
- **D4 logging.** The ase arm of open_view logs NO action line (read-only
  viewer, same allowlist doctrine as do_history*/do_show_checkouts) and must
  skip the `xschem load` block, its log_action lines, AND the trailing
  `after 120 force_window_repaint` (no editor window was touched). Editor
  arms byte-identical to today. No new `libmgr::do_*` proc (keeps
  test_selflog_grep_guard's closure scan untouched).
- **D5 creation type token.** newview_dialog combobox values become
  `{schematic symbol ngspice_state1}` (exact new value `ngspice_state1`).
  `library_new_view` and `saveform::resolve_target` match
  `[string match ngspice_state* $type]` (forward-compat: ngspice_state2…).
  library_new_view's state branch writes `<cell>.state` via
  `ase::state_save` of `[ase::state_default]` with
  `design {lib $lib cell $cell view schematic}` set unconditionally (cell
  existence already guarded at :705; if the schematic view arrives later,
  ase::netlist errors cleanly — acceptable). NEVER an empty file. Update the
  :699 doc comment (types are no longer just schematic|symbol) and the :1203
  dialog comment. `do_new_view` :1154 needs no change (type flows through;
  its existing log_action line replays correctly).
- **D6 ase::open_state v0 contract** (in src/ase.tcl):
  `proc ase::open_state {lib cell view}` — resolve
  `[xschem cellview_path $lib/$cell $view]`; empty → ciw_echo error
  (has_x-guarded, item-01 idiom `[info exists ::has_x] && [info commands
  ::ciw_echo] ne {}`) + `return 0`. Under X (`[info exists ::has_x]`):
  `textwindow $path ro` + ciw_echo notice that the full ASE-L window arrives
  in a later phase; headless: no Tk call at all. `return 1`. Comment it as
  the single Tk-guarded GUI seam of ase.tcl and note the body is replaced by
  item 03 (name+signature stable).
- **D7 confirmed no-change surfaces** (do not touch): cell_views /
  cellview_resolve / cellview_path (probe-verified), tracked_views /
  git_target, full_audit.sh, tests/run_regression.tcl (pre-batch dirty —
  NEVER staged).

## Deliverables (exact)

1. src/library_manager.tcl — `libmgr::view_handler` (D2, placed near
   open_view with a comment naming it the item-02/03 dispatch seam); dispatch
   in `open_view` after the `$f` resolution + its "no view" status error,
   before the load arms: handler ≠ editor → `return [$handler $lib $cell
   $view]` (D4); `open_view_ro` divert (D3); newview_dialog combobox value
   (D5).
2. src/library_defs.tcl — library_new_view state-type branch (D5).
3. src/xschem.tcl — enum `.state → ngspice_state` at :5697 (keep the
   one-line expr readable: extension switch or nested expr, your call);
   hi_descend_do intercept + hi_descend_finish refuse (D1).
4. src/save_as_form.tcl — resolve_target: `ngspice_state*` type → ext
   `state` (:47); prefill: state type → `set view $type` (:71).
5. src/ase.tcl — `ase::open_state` v0 (D6) + header amendment.
6. tests/headless/test_ase_view.tcl — below.

## Test: tests/headless/test_ase_view.tcl

Runs via full_audit's DEFAULT arm (`--pipe -q --nolog --script`, cwd = repo
root; do NOT add it to any list in full_audit.sh). Headless legs always run;
GUI legs guarded by `[info exists ::has_x]` (and `[info commands winfo] ne
{}`), printing `gui legs skipped (no DISPLAY)` — do NOT use the strings
"RESULT: SKIP" or "skipped: no X" for a partial skip (full_audit would
classify the whole test SKIP). Standalone repro:
`cd /home/qflow/dev/xschem/claude_1/xschem && ./src/xschem --pipe -q --nolog
--script tests/headless/test_ase_view.tcl` (add DISPLAY for the GUI legs).

Fixture (test_ase_core precedent): scratch `_ase_view_[pid]` under cwd;
scratch library.defs DEFINEs `aseviewlib` → scratch dir; set
`::XSCHEM_LIBRARY_DEFS` + `::library_registry_defs_only 1` FIRST. Build cell
`vcell` via the real backends: `library_new_cell aseviewlib vcell schematic`,
`library_new_view aseviewlib vcell symbol symbol`, then the code under test
`library_new_view aseviewlib vcell ngspice_state1 ngspice_state1`. For the
descend legs write a parent sch (6-record header + `C {aseviewlib/vcell} 100
-100 0 0 {name=X1}`) into the scratch lib and `xschem load` it.

Named checks (headless):
- V1 `xschem cell_views aseviewlib vcell` contains ngspice_state1 (and
  schematic, symbol).
- V2 `xschem cellview_path aseviewlib/vcell ngspice_state1` ends
  `ngspice_state1/vcell.state`.
- V3 seeded file loads via `ase::state_load` → `version 1`,
  `simulator ngspice`, `design {lib aseviewlib cell vcell view schematic}`
  (order-insensitive dict compare on design).
- V4 seeded file non-empty AND `ase::state_save` of its load is byte-stable
  (read file, save the loaded dict to a second path, compare contents).
- V5 dispatch unit (no Tk): `libmgr::view_handler ngspice_state1` →
  `ase::open_state`; `schematic` → `editor`; `symbol` → `editor`;
  path-authoritative legs: `view_handler mystate /x/c/mystate/c.state` →
  `ase::open_state`, `view_handler ngspice_state1 /x/c/ngspice_state1/c.sch`
  → `editor`.
- V6 `ase::open_state aseviewlib vcell ngspice_state1` headless → 1 (no Tk
  side effects); `ase::open_state aseviewlib vcell nosuchview` → 0, no error
  thrown.
- V7 `hi_descend_enum_views X1` (parent loaded) has row
  `{ngspice_state1 ngspice_state <abs .state path>}`.
- V8 routing: `rename ::ase::open_state ::ase::open_state_real`; recorder
  proc captures args, returns 1; `hi_descend_do X1 ngspice_state1 {} current
  1 readonly` → 1 and recorder got `{aseviewlib vcell ngspice_state1}`; also
  `target=new_window` routes to the recorder (headless proves no window
  machinery ran: currsch unchanged, recorder hit); restore with
  `rename` immediately (and in a catch guard so a failed leg can't poison
  later legs).
- V9 `hi_descend_finish X1 ngspice_state /any/path 1 readonly` → 0 and
  `xschem get currsch` unchanged.
- V10 `saveform::resolve_target aseviewlib vcell ngspice_state1
  ngspice_state1` ends `ngspice_state1/vcell.state`; type schematic still
  ends `.sch` (no regression).
- V11 (skip silently if `[auto_execok git]` empty): `git init` the scratch
  lib, add+commit the state file (git -C, user.name/email -c overrides),
  `libmgr::tracked_views aseviewlib vcell` has ngspice_state1;
  `libmgr::git_target aseviewlib vcell ngspice_state1` returns the repo root
  + one pathspec.

Named checks (GUI, DISPLAY-guarded):
- G1 real double-click: `library_manager`; `libmgr::refresh_after aseviewlib
  vcell ngspice_state1`; `update`; `event generate .libmgr.pw.view.lb
  <Double-1>`; `update` → a toplevel exists whose `wm title` equals the
  .state path (textwindow); destroy it. (The Double-1 BINDING is the surface
  under test — gesture-test-full-sequence lesson; open_view reads the
  selection, not event coords, so a coordinate-free Double-1 on the pane is
  the faithful sequence.)
- G2 `libmgr::open_view_ro` with the state view selected → viewer toplevel
  appears AND `xschem get readonly` is unchanged (0) on the current window;
  destroy viewer.
- G3 newview combobox: schedule `after 300 {catch {set ::g3_values
  [.libmgr.nv2.type cget -values]}; set ::libmgr::dlg_done 0}` then call
  `libmgr::newview_dialog aseviewlib vcell`; assert ngspice_state1 in
  $::g3_values.
- Close .libmgr at the end; scratch cleanup `file delete -force` always.

## Sabotage-verify (≥2; run each, confirm EXACTLY the target check(s) fail,
`git diff <file>` shows only the sabotage, targeted `git checkout -- <file>`,
clean re-run green)

- S1 src/library_manager.tcl: make view_handler return `editor` for the
  ngspice_state* glob AND .state path leg → V5 fails (and G1 under DISPLAY);
  V1-V4 stay green (proves dispatch is the code under test, not discovery).
- S2 src/library_defs.tcl: revert the state branch of library_new_view to
  `library_write_empty_cellfile` → V3 fails (dict invalid/design wrong)
  and V4's non-empty/byte-stable leg fails; V1/V2 stay green.
- S3 src/xschem.tcl: drop the `.state → ngspice_state` mapping (force old
  binary expr) → V7 fails (type reads symbol) and V8 fails (no routing);
  V9 stays green (finish guard is independent).

## Definition of done

- All new checks pass headless from repo root; GUI legs pass under DISPLAY
  (run both ways if DISPLAY available).
- `tests/headless/full_audit.sh` — result compares LIST-EQUAL to the baseline
  in PLAN.md preflight (those fails are tolerated; any NEW fail/timeout is
  yours). test_ase_core must still pass (ase.tcl was touched).
- ONE commit, staging EXPLICITLY and ONLY:
  `src/library_manager.tcl src/library_defs.tcl src/xschem.tcl
  src/save_as_form.tcl src/ase.tcl tests/headless/test_ase_view.tcl`
  (`git add` that list; never -A/-a; verify with `git status --porcelain`
  that no pre-batch dirty file — doc/claude/specs/sky130_workarea.md,
  sky130A/xschem_libs/library.defs, src/ciw.tcl,
  tests/headless/test_sky130a_libmgr.tcl, tests/run_regression.tcl, the two
  SANDBOX files — is staged). Commit message: normal prose + the repo's
  Co-Authored-By trailer. NEVER push.

## RUNBOOK policies (verbatim, non-negotiable)

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
