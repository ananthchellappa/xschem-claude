# Item 05 ui-shell — implementation prompt (ROUND 2, UI v2 / ADE-L parity)

Scout verdict: PROCEED (anchors re-verified from source 2026-07-21; Design
Window bug REPRODUCED and root-caused — see section 4).

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. You are
the IMPLEMENTER: execute this prompt end-to-end — code, tests,
sabotage-verify, ONE commit with the explicit file list in section 10. Do not
start item 06-08 work (panes/action-strip/dialogs): keep the existing v1 pane
code working under the new chrome.

## 1. Mission

Rework the ASE-L session-window CHROME (`src/ase_window.tcl`) to the
authoritative UI contract: spec section "UI v2 — ADE-L parity rework" in
`doc/claude/specs/ase_l.md` (lines 155-247; window chrome 161-176, menu tree
v2 207-231, log window 233-236, dialog style 244-247). Plus: temperature →
`.temp` in the deck (`src/ase.tcl`), the Session > Design Window bugfix, and
test updates. Functionality shipped in v1 (commits 20cc4df9, 307eaa64,
5f94d6d6, c8d539c0) must not regress.

Read first, in order:
1. `doc/claude/ase_l_batch/RUNBOOK.md` (policies — copied verbatim in §11)
2. `doc/claude/specs/ase_l.md` — the "UI v2 — ADE-L parity rework" section
3. `references/copy_current_cell_dialog.tcl` (named-font + dialog idioms;
   note line 76-81: `ttk::combobox ... -font <namedfont>` works directly)
4. `doc/claude/ase_l_batch/receipts/03_ase-window.md` (what v1 shipped)
5. `src/ase_window.tcl` (711 lines) + `src/ase.tcl` (589 lines) in full

## 2. Corrected anchors (re-verified from source 2026-07-21)

| Anchor | True location |
|---|---|
| spec "UI v2 — ADE-L parity rework" | doc/claude/specs/ase_l.md:155-247 |
| spec "Window chrome" | ase_l.md:161-176 |
| spec "Menu tree (v2)" | ase_l.md:207-231 |
| spec "Log window (not a pane)" | ase_l.md:233-236 |
| `ase::ui::build` (menubar/bar/log-pane/panes) | src/ase_window.tcl:121-183 (menubar 122-141, bottom bar 145-154, log pane 156-162) |
| `ase::ui::design_window` + `design_path` | src/ase_window.tcl:505-535 / :487-499 (fresh-open arm :526-534 = THE BUG) |
| `ase::ui::refresh_title` / `session_changed` | src/ase_window.tcl:453-462 / :467-469 |
| `ase::ui::set_status` | src/ase_window.tcl:541-553 |
| log machinery (clear/append/trace) | src/ase_window.tcl:557-610 |
| `do_netlist`/`run_finished`/`do_run`/`do_stop`/`view_netlist`/`view_log` | src/ase_window.tcl:614-711 |
| `ase::schema_keys` | src/ase.tcl:25-26 |
| `ase::state_default` | src/ase.tcl:64-76 |
| `ase::backend::ngspice::render_deck` | src/ase.tcl:496-548 (.options loop :510-519, .save loop :520-524) |
| `ase::netlist` / `ase::run` | src/ase.tcl:188-223 / :233-273 |
| `execute` / `execute_fileevent` / `execute_wait` / `kill_running_cmds` | src/xschem.tcl:352 / :242 / :328 / :401 |
| `set_simulate_button` | src/xschem.tcl:13662 (spec's 13633 DRIFTED) |
| `force_window_repaint` | src/xschem.tcl:5495 |
| `notify_window_active` proc / CIW bind / LibMgr bind | src/ciw.tcl:129 / src/ciw.tcl:106 / src/library_manager.tcl:79 |
| `libmgr::open_view` (load-routing precedent) | src/library_manager.tcl:452-496 (spec's 432 DRIFTED; `-gui` arm :480-489, deferred repaint :494) |
| `xschem windows` entry format | src/scheduler.c:11699 — `{win_path top_path group xwindow current_name number}`, index 4 = current name (handler's assumption CORRECT) |
| `xschem activate_window` | src/scheduler.c:1573-1578 |
| ship/source lines (NO changes needed) | src/xschem.tcl:14106+14108 source ase.tcl/ase_window.tcl; src/Makefile.in:22 ships both |
| test golden deck D1 | tests/headless/test_ase_core.tcl:144-175 (expected_deck :154-171); R1 key-count :87-98 |
| test_ase_window GUI legs | tests/headless/test_ase_window.tcl (W1 :199-213, W3 :226-245, W4 :252-261, W5 :263-272, W6 :279-297, W7 :299-325, W8 :329-333) |

`tests/headless/test_ase_view.tcl` and `tests/headless/test_ase_final.tcl`
were checked by the scout: V3/V4 load→save and F8 pattern checks are robust to
the new `temperature` key and `.temp` line (the committed test_nfet_final
state has no temperature key → default 27 = ngspice's own default, Id
unchanged; test_ase_view never asserts the window title). DO NOT edit those
two files; they must stay green.

## 3. Scout decisions (each binding; one-line justification)

D1 **`temperature` schema position**: insert `temperature` into
`ase::schema_keys` after `rundir` (before `models`) and into `state_default`
as `temperature 27` — groups session scalars; R1 compares `lsort`ed keys so
position only affects serialization order, which is self-consistent
(byte-stability R4/V4 unaffected: both sides of the compare are written by the
new saver).

D2 **`.temp` emission**: `render_deck` always emits `.temp <T>` with
`set T [ase::state_get $state temperature 27]`, placed after the `.options`
loop and before the `.save` loop; non-numeric T (`![string is double -strict]`)
→ `return -code error "ase: temperature must be numeric: '$T'"` — always-emit
is deterministic and testable; erroring on garbage is honest (the GUI validates
at commit so the UI path never hits it).

D3 **temperature entry validation**: commit-time (Return/FocusOut on the
toolbar entry): `string is double -strict` → harvest into the state; else
restore the entry text from the current state + `ciw_echo "ase: temperature
must be numeric"` and do NOT touch the state — simplest validation that can
never store garbage.

D4 **v2 title keeps the dirty marker**: title =
`Analog Sim Environment <design cell>` (+ ` *` when dirty); design cell from
`state design.cell`, falling back to the session's cell (meta) when design is
empty — the spec's title has no number, but nothing supersedes the dirty
marker and losing it would regress v1 UX. Window NAME stays `.ase<N>` and
`allocate_window_number` + `notify_window_active` are untouched (the win# now
shows in the status bar).

D5 **status text mapping**: `set_status` keeps its 4 API states; presentation
= status-bar Status segment text Ready(idle)/Running(running)/Ready(ok)/
Error(fail) with the v1 background colors preserved (default/orange/Green/red)
— tests keep asserting colors, users read Cadence-style words.

D6 **status bar structure**: `$top.status` frame packed bottom, one label per
segment with deterministic names — `$top.status.win` (the window number),
`.stat`, `.temp` (`T=<T> C`), `.sim` (`Simulator: <sim>`), `.state`
(`State: <view>`) — separated by literal ` | ` labels; only `.stat` gets the
status background color. Add `proc ase::ui::status_text {key}` returning the
assembled `<win#> | Status: <S> | T=<T> C | Simulator: <sim> | State: <view>`
string for tests. Refresh proc `ase::ui::refresh_status` called from
`populate`, `set_status`, and `session_changed` (extending session_changed is
safe: it only configures labels, never destroys widgets — the :19-21 comment's
constraint is about pane repopulation).

D7 **Session > Save State / Load State wiring**: the item detail's two
directives conflict for these entries ("wire everything that already has a
proc" vs "item-07 dialogs get stubs"); resolution = wire to the EXISTING procs
(`save_state` → `ase::session_save`, `load_state` → reload-from-disk +
populate) with a `TODO(item07)` comment noting the Save-As/browser dialog
upgrade — stubbing would regress working save/load for a whole item-cycle and
gut test W3. Session menu entries verbatim: Design Window, Load State,
Save State, Close (NO Revert entry — v2 tree is verbatim; keep the
`ase::ui::revert_state` PROC, W7 calls it directly).

D8 **Run (existing netlist) semantics**: skip `xschem netlist`, read the
existing `<rundir>/<cell>.spice`, re-render the deck from the state, run —
implemented by factoring the post-netlist body of `ase::run` into
`ase::run_deck <state> <netlistfile> ?callback?` and adding
`ase::run_existing <state> ?callback?` (clean error when the netlist artifact
is absent: "run Simulation > Netlist > Recreate first"). This matches ADE-L
(Run applies current analyses but does not re-netlist) and lets hand-edits to
the circuit netlist survive; it also needs NO current-schematic guard (no
netlisting), so it works with the design window closed.

D9 **menu stubs**: one generic `proc ase::ui::todo_stub {what item}` →
`ciw_echo "ase: '$what' dialog lands in item $item"`; each stubbed menu entry
site carries a `TODO(item06)`/`TODO(item07)`/`TODO(item08)` comment matching
where PLAN.md lands it (Variables > Edit… = item06; Setup Design/Model Files,
Analyses Choose…, Outputs Save All…, Simulation Options…, the Save/Load-State
dialog upgrades = item07; Outputs To Be Saved/Plotted > Select On Design =
item08).

D10 **Launch/Tools/Results**: Launch and Tools = cascade entries present but
`-state disabled` (placeholder/deferred, an empty posting menu looks broken);
Results = ENABLED cascade whose 3 entries are disabled — spec says its
"entries may exist disabled": `Direct Plot` (disabled) + `Annotate` cascade →
`Operating Point info`, `DC Node Voltages` (both disabled).

D11 **v1 bottom button bar removed**: `$top.bar` (Netlist/Run/Stop buttons +
status label) is replaced by the status bar; invocation paths are the
Simulation menu (the action strip arrives in item 06). Tests drive the menu
entries instead of the dead buttons.

D12 **log window**: child toplevel `toplevel $top.logwin` (dies with the
session window; NOT a child of `.` so test helpers globbing `.ase*` children
of `.` don't see it), title `Simulation Log — <design cell>`, themed, one
read-only text `$top.logwin.t` + scrollbar; `bind $top.logwin <Control-w>`
(and `<Control-W>`) destroys it — bindtags make the binding fire from any
child. `do_run` opens/raises+clears it and attaches the existing trace
machinery (retarget `log_clear`/`log_append` from `$top.log.t` to
`$top.logwin.t`; the existing `winfo exists` guards already cover
closed-mid-run). Simulation > Log: raise if open, else create and fill from
the backend's `log_file` (the `view_log` resolution idiom) — or from the live
`execute(data,$id)` buffer when a run is in flight.

D13 **theme**: `proc ase::theme {?name?}` — creates named fonts once
(`lsearch [font names]` guard, the reference-file idiom): `AseLabelFont`
Arial 10 bold, `AseEntryFont` Arial 13, `AseMonoFont` Courier 13; does
`option add *TCombobox*Listbox.font AseEntryFont`; configures ttk style
`Ase.TCombobox` (`-fieldbackground white`); returns the palette dict (or one
color): `panel #f2f2f2`, `table #ffffff`, `header #e8e8e8`, `accent #8b0000`
(USER-LOCKED first three; "dark-red" hex is the scout's pick = X11 DarkRed).
`proc ase::ui::apply_theme {w}` walks `winfo children` recursively switching
on `winfo class`: Toplevel/Frame/Labelframe/Menu/Button/Label/Checkbutton →
`-background` panel + `-font AseLabelFont` (where the option exists);
Labelframe additionally `-foreground #8b0000`; Entry → white bg +
AseEntryFont; Text → white bg + AseMonoFont (log/netlist are the only Texts);
TCombobox → `-font AseEntryFont -style Ase.TCombobox`; Scrollbar →
`-background` panel. Called at the end of `build`, `populate` (rows are
rebuilt there), `row_add`, and log-window creation — every ASE widget themed,
no stock-Tk leftovers. `textwindow` (Netlist > Display) stays stock: it is
SHARED infra, retheming it would restyle every non-ASE use (document this in
the receipt).

D14 **degree label**: the toolbar label text is the Tcl escape
`"\u00b0C"` (backslash-u escape written literally in the source, never the
raw UTF-8 byte pair — ase_window.tcl stays ASCII, matching its existing
backslash-u2014 title idiom).

## 4. BUGFIX Session > Design Window (REPRODUCED + root-caused)

Repro (scout, 2026-07-21, WSLg DISPLAY=:0, script mirroring the test fixture):
open the ASE window (`.ase4`), `raise`+focus it, invoke the real menu entry
`Session > Design Window` with the design NOT loaded anywhere. Result:

```
post: schname    = .../nfet_clean.sch      (design DID load — into ".")
post: stackorder = . .ase4                 (ASE window still ON TOP)
post: focus      = .ase4
BUG REPRODUCED: design loaded into main window but ASE window still ABOVE it
```

Root cause: the fresh-open arm (src/ase_window.tcl:526-534) runs
`xschem load -gui $dpath`; load-routing reuses the pristine untitled MAIN
window (the standard cadence_style_rc launch state), the design loads there,
but the arm never deiconifies/raises/focuses that toplevel — unlike the
already-open arm (:511-524) which does. With ASE/LibMgr/CIW stacked above the
main window, nothing visibly happens. v1's W4 test asserted only `schname` +
the window list — green-but-hollow on visibility.

Fix contract:
- Factor the raise sequence (`xschem new_schematic switch <win_path>`,
  `wm deiconify` / `raise` / `focus` on top_path mapping `{}` → `.`,
  `xschem activate_window [winfo id $tp]`) into a helper, e.g.
  `ase::ui::raise_design_editor {dpath}` that scans `xschem windows` for
  index-4 == `$dpath` and returns 1/0.
- `design_window` = resolve path → try helper → if 0: the existing gated
  `xschem load -gui` block, then call the helper AGAIN (the design now lives
  in the reused untitled window or a routed new window — the re-scan finds
  either), keep `after 120 [list force_window_repaint ...]` (WSLg issue 0052).
- Regression check W4-raise (below) asserts stacking, mirroring the repro.

## 5. Deliverables — src/ase.tcl

1. `temperature` in `schema_keys` (after `rundir`) + `state_default`
   (`temperature 27`) per D1.
2. `render_deck`: `.temp` emission per D2.
3. `ase::run_deck` factored out of `ase::run` + new `ase::run_existing` per
   D8 (`ase::run` behavior byte-identical to before; `run_existing` performs
   the same deck-write/execute path minus `xschem netlist`).
4. Nothing else — state I/O, session model, `open_state` contract, backend
   registry are all stable contracts.

## 6. Deliverables — src/ase_window.tcl

1. **Title** per D4; `refresh_title` reworked; window name `.ase<N>`,
   allocator, FocusIn/notify unchanged.
2. **Toolbar** `$top.tb` under the menubar: numeric entry `$top.tb.temp`
   (state key `temperature`, shows current value, commit on Return/FocusOut
   with D3 validation, participates in `harvest`) + the D14 degree label.
3. **Status bar** per D5/D6 replacing `$top.bar`; `set_status` retargeted;
   `refresh_status`; `status_text` accessor; `session_changed` → title +
   status refresh.
4. **Menu tree v2 VERBATIM** (spec ase_l.md:207-231), cascades in order:
   Launch (disabled, D10) | Session: Design Window, Load State, Save State,
   Close (D7) | Setup: Design…, Model Files… (stubs, D9) | Analyses: Choose…
   (stub) | Variables: Edit… (stub, item06) | Outputs: To Be Saved > Select
   On Design, To Be Plotted > Select On Design (stubs, item08), Save All…
   (stub) | Simulation: Netlist > Recreate, Netlist > Display, Netlist and
   Run, Run, Stop, Log, Options… (stub) | Results (D10) | Tools (disabled).
   Wiring: Recreate → `ase::netlist` on the session state (report via
   `ciw_echo`, no viewer); Display → the existing `view_netlist` body;
   Netlist and Run → existing `do_run`; Run → NEW `do_run_existing` calling
   `ase::run_existing` (same log-window + trace + status flow as `do_run`,
   no current-schematic guard); Stop → existing `do_stop`; Log → D12 reopen.
5. **Log pane REMOVED** (`$top.log*` gone from `build`); log toplevel +
   Ctrl-W + Simulation > Log per D12; `do_run`/`run_finished` retargeted.
6. **Design Window fix** per §4.
7. **Theme** per D13 applied everywhere (including the kept v1 panes and the
   new toolbar/status/log widgets); keep all v1 pane/harvest/commit code
   working otherwise (do NOT start the item-06 3-pane rework).
8. Keep `ase::ui::variable_entry`, `revert_state`, `window_for`, `close`
   contracts (tests use them).

## 7. Tests

### tests/headless/test_ase_core.tcl (justify every change in the receipt)
- R1: key list gains `temperature` (11 keys) + new check
  `R1 temperature default 27`.
- D1 golden deck: insert line `.temp 27` between `.options savecurrents` and
  `.save -i(v1)` (position = D2).
- NEW D4 checks: `D4 custom temperature renders .temp 33.5`
  (`dict set st temperature 33.5` → `regexp -line {^\.temp 33\.5$}`);
  `D4 non-numeric temperature errors cleanly` (catch on render);
  `D4 missing temperature key still emits .temp 27` (bare dict without the
  key → `.temp 27`).
- Everything else untouched (R2/R4 byte-stability provably unaffected: both
  compare sides use the new saver).

### tests/headless/test_ase_window.tcl (justify every change in the receipt)
Headless additions:
- `T1 run_existing errors without a netlist artifact` (catch, fresh rundir).
Updated/new GUI legs (same fixture, same DISPLAY-guard/self-SKIP structure):
- W1: title check → exactly `Analog Sim Environment nfet_clean`; keep
  `.ase<N>` name check; NEW `W1 no log pane in the session window`
  (`![winfo exists $top.log]`); NEW `W1 temperature entry shows 27`;
  NEW theme checks: `W1 toplevel panel background #f2f2f2`,
  `W1 Vgs entry white + AseEntryFont`, `W1 pane title dark-red accent`
  (`[$top.body.vars cget -foreground]`), `W1 named fonts exist`
  (AseLabelFont/AseEntryFont/AseMonoFont ∈ `font names`).
- NEW W1m menu-tree leg: the 9 cascade labels in order; Launch + Tools
  cascade entries disabled; Results entries `Direct Plot` + Annotate submenu
  entries disabled; Simulation menu contains Netlist cascade
  (Recreate/Display) + `Netlist and Run`/`Run`/`Stop`/`Log`/`Options…`
  (iterate `$m index end` + `entrycget -label/-state`).
- W2 unchanged (re-open raises, no number consumed).
- W3: unchanged mechanics via `$top.mb.session invoke {Save State}` (D7 keeps
  it working); ADD temperature round-trip: focus `$top.tb.temp`, set `33`,
  Return → dirty + `status_text` contains `T=33 C`; Save State → file
  contains `temperature 33`; non-numeric `abc` + Return → state keeps 33,
  entry restored (validation leg); restore 27 + save.
- W4: keep both v1 checks; NEW `W4 design toplevel raised above the ASE
  window` — after invoke, re-scan `xschem windows` for the design, map its
  top_path (`{}`→`.`), retry-loop (≤50 × update+50ms) until
  `lsearch [wm stackorder .] <design_top>` >
  `lsearch [wm stackorder .] $top`; this is the §4 regression gate.
- W5: drive `$top.mb.sim.netlist invoke Recreate` → netlist file exists
  (no viewer asserted); then `invoke Display` → titled textwindow with XM1
  (v1 W5 body reused).
- W6: run via `$top.mb.sim invoke {Netlist and Run}`; NEW
  `W6 log toplevel appears` (`winfo exists $top.logwin`); log-content checks
  read `$top.logwin.t` (Data Rows banner, `-i(v1)` line); status checks
  read the new widget (`$top.status.stat` background orange→Green, text
  Running→Ready); keep the log-file check; NEW `W6 deck contains .temp 27`
  (read `<rundir>/nfet_clean_ase.spice`).
- NEW W6b Run-existing leg: append a sentinel comment line (e.g.
  `* HAND_EDIT_SENTINEL`) to `<rundir>/nfet_clean.spice`; `$top.mb.sim
  invoke Run`; wait → `W6b netlist artifact still carries the sentinel`
  (not re-netlisted) AND `W6b deck carries the sentinel` (deck rendered from
  the hand-edited netlist) — the must-NOT-re-netlist proof.
- NEW W6c log-window keys: `focus -force $top.logwin.t`,
  `event generate $top.logwin.t <Control-w>` (FULL Tk sequence) →
  destroyed; `$top.mb.sim invoke Log` → reopened showing the log file
  content.
- W7: Stop leg driven via `$top.mb.sim invoke Stop` after
  `invoke {Netlist and Run}`; status red on the new widget; rest unchanged.
- W8 unchanged.
DO NOT touch tests/run_regression.tcl (pre-batch dirty; full_audit
auto-discovers). DO NOT edit test_ase_view.tcl / test_ase_final.tcl (§2).

## 8. Sabotage plan (≥2 required; run all three)

Commit first, then per sabotage: apply, run, confirm EXACTLY the target
check(s) fail, `git diff` the file to confirm it holds nothing but the
sabotage, targeted `git checkout -- <file>`, clean re-run green.

- S1 (ase.tcl): delete the `.temp` emission in `render_deck` → fails exactly
  the .temp family: test_ase_core `D1 golden deck` + all `D4 *` +
  test_ase_window `W6 deck contains .temp 27` (headless attribution:
  `env -u DISPLAY` for the core checks).
- S2 (ase_window.tcl): remove the post-load `raise_design_editor` call in
  `design_window` (revert to v1 fresh-open behavior) → fails EXACTLY
  `W4 design toplevel raised above the ASE window`; the two v1 W4 checks must
  stay green (that asymmetry is the proof this was the hollow spot).
- S3 (ase_window.tcl): skip the Entry branch in `apply_theme` → fails exactly
  `W1 Vgs entry white + AseEntryFont` (other theme checks stay green).

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
test_ase_core / test_ase_view / test_ase_window / test_ase_final are NOT
baseline fails and must PASS.

## 10. Commit (ONE)

Stage EXACTLY these four files (explicit `git add` of each path, nothing
else):
- `src/ase.tcl`
- `src/ase_window.tcl`
- `tests/headless/test_ase_core.tcl`
- `tests/headless/test_ase_window.tcl`

No Makefile/xschem.tcl changes are needed (both tcl files already shipped +
sourced — §2). NEVER stage the pre-batch dirty tracked files:
`doc/claude/specs/sky130_workarea.md`, `sky130A/xschem_libs/library.defs`,
`src/ciw.tcl`, `tests/headless/test_sky130a_libmgr.tcl`,
`tests/run_regression.tcl`,
`xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym`,
`xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`
— nor any `_nhangle_*`/`_allm_*`/junk dirs, nor generated files
(src/Makefile, src/xschem_subcommands.txt). Message: normal prose, e.g.
`feat(ase): ADE-L parity chrome — v2 menus, temp/.temp, log window, Design
Window raise fix`, with the repo's Co-Authored-By trailer.

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

Record: every assertion change in test_ase_core/test_ase_window with its
justification (§7 gives them); the §4 repro + fix; D7's wiring-conflict
resolution; D13's textwindow carve-out; the sabotage table; audit list vs
baseline.
